#!/bin/bash
#
# Nephio Phase-0 Infrastructure Smoke Check
# Validates that Nephio base infrastructure is ready for intent pipeline
#
# Exit codes:
#   0 = All required checks pass
#   1 = kubectl cluster-info failed
#   2 = porch-system pods not ready
#   3 = Porch API resources unavailable
#   4 = Unexpected error

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly TIMEOUT_PODS=30
readonly TIMEOUT_API=10

# Status tracking
declare -A CHECK_STATUS
declare -A CHECK_MESSAGE

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*" >&2
}

# Error handler
error_exit() {
    local exit_code=${1:-4}
    local message=${2:-"Unexpected error occurred"}
    log_error "$message"
    exit "$exit_code"
}

# Validation functions
check_kubectl_cluster() {
    local check_name="kubectl-cluster"
    log_info "Checking kubectl cluster connectivity..."
    
    if ! timeout 10 kubectl cluster-info >/dev/null 2>&1; then
        CHECK_STATUS["$check_name"]="FAIL"
        CHECK_MESSAGE["$check_name"]="kubectl cluster-info failed or timeout"
        return 1
    fi
    
    # Get cluster info for summary
    local cluster_info
    cluster_info=$(kubectl cluster-info 2>/dev/null | head -1 | grep -o 'https://[^[:space:]]*' || echo "unknown")
    
    CHECK_STATUS["$check_name"]="PASS"
    CHECK_MESSAGE["$check_name"]="Connected to $cluster_info"
    return 0
}

check_porch_pods() {
    local check_name="porch-pods"
    log_info "Checking porch-system pods..."
    
    # Check if namespace exists
    if ! kubectl get namespace porch-system >/dev/null 2>&1; then
        CHECK_STATUS["$check_name"]="FAIL"
        CHECK_MESSAGE["$check_name"]="porch-system namespace not found"
        return 2
    fi
    
    # Required pods in porch-system
    local required_pods=("porch-controllers" "porch-server" "function-runner")
    local not_ready_pods=()
    
    for pod_prefix in "${required_pods[@]}"; do
        local pod_count
        pod_count=$(kubectl get pods -n porch-system --field-selector=status.phase=Running 2>/dev/null | \
                   grep "^$pod_prefix" | grep -c "Running" || echo "0")
        
        if [[ "$pod_count" -eq 0 ]]; then
            not_ready_pods+=("$pod_prefix")
        fi
    done
    
    if [[ ${#not_ready_pods[@]} -gt 0 ]]; then
        CHECK_STATUS["$check_name"]="FAIL"
        CHECK_MESSAGE["$check_name"]="Not running: ${not_ready_pods[*]}"
        return 2
    fi
    
    # Get running pod count for summary
    local total_running
    total_running=$(kubectl get pods -n porch-system --field-selector=status.phase=Running 2>/dev/null | \
                   grep -c Running || echo "0")
    
    CHECK_STATUS["$check_name"]="PASS"
    CHECK_MESSAGE["$check_name"]="All required pods running ($total_running total)"
    return 0
}

check_porch_api() {
    local check_name="porch-api"
    log_info "Checking Porch API resources..."
    
    # Required API resources
    local api_resources=("repositories.porch.kpt.dev" "packagerevisions.porch.kpt.dev" "packagevariants.config.porch.kpt.dev")
    local missing_resources=()
    
    for resource in "${api_resources[@]}"; do
        if ! timeout "$TIMEOUT_API" kubectl api-resources --api-group="${resource##*.}" 2>/dev/null | \
             grep -q "${resource%%.*}"; then
            missing_resources+=("$resource")
        fi
    done
    
    if [[ ${#missing_resources[@]} -gt 0 ]]; then
        CHECK_STATUS["$check_name"]="FAIL"
        CHECK_MESSAGE["$check_name"]="Missing APIs: ${missing_resources[*]}"
        return 3
    fi
    
    CHECK_STATUS["$check_name"]="PASS"
    CHECK_MESSAGE["$check_name"]="All Porch APIs available"
    return 0
}

check_config_management() {
    local check_name="config-mgmt"
    log_info "Checking config-management-system (informational)..."
    
    # This is informational only - not required for pipeline
    if ! kubectl get namespace config-management-system >/dev/null 2>&1; then
        CHECK_STATUS["$check_name"]="INFO"
        CHECK_MESSAGE["$check_name"]="Namespace not present (optional)"
        return 0
    fi
    
    local running_pods
    running_pods=$(kubectl get pods -n config-management-system --field-selector=status.phase=Running 2>/dev/null | \
                   grep -c Running || echo "0")
    
    if [[ "$running_pods" -gt 0 ]]; then
        CHECK_STATUS["$check_name"]="INFO"
        CHECK_MESSAGE["$check_name"]="$running_pods pods running"
    else
        CHECK_STATUS["$check_name"]="INFO"
        CHECK_MESSAGE["$check_name"]="No pods running"
    fi
    
    return 0
}

print_summary() {
    echo
    echo "=================================================================================="
    echo "  Nephio Phase-0 Infrastructure Status"
    echo "=================================================================================="
    printf "%-20s %-8s %-50s\n" "COMPONENT" "STATUS" "MESSAGE"
    echo "----------------------------------------------------------------------------------"
    
    local overall_status="PASS"
    
    for check in "kubectl-cluster" "porch-pods" "porch-api" "config-mgmt"; do
        local status="${CHECK_STATUS[$check]:-UNKNOWN}"
        local message="${CHECK_MESSAGE[$check]:-No information}"
        
        # Determine color and overall status
        local color="$NC"
        case "$status" in
            "PASS") color="$GREEN" ;;
            "FAIL") 
                color="$RED"
                overall_status="FAIL"
                ;;
            "INFO") color="$BLUE" ;;
            *) color="$YELLOW" ;;
        esac
        
        printf "%-20s ${color}%-8s${NC} %-50s\n" "$check" "$status" "$message"
    done
    
    echo "=================================================================================="
    
    if [[ "$overall_status" == "PASS" ]]; then
        echo -e "${GREEN}✓ Nephio Phase-0 infrastructure is ready for intent pipeline${NC}"
        echo
        return 0
    else
        echo -e "${RED}✗ Nephio Phase-0 infrastructure has issues - see failures above${NC}"
        echo
        return 1
    fi
}

main() {
    echo "Starting Nephio Phase-0 smoke check..."
    echo
    
    # Initialize status tracking
    CHECK_STATUS=()
    CHECK_MESSAGE=()
    
    # Run all checks (continue on failure to gather all info)
    local exit_code=0
    
    check_kubectl_cluster || exit_code=1
    check_porch_pods || exit_code=2
    check_porch_api || exit_code=3
    check_config_management || true  # Informational only
    
    # Print summary and determine final exit code
    if ! print_summary; then
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All required checks passed"
    else
        log_error "Some checks failed - see summary above"
    fi
    
    exit "$exit_code"
}

# Help function
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Validates Nephio Phase-0 base infrastructure readiness.

OPTIONS:
    -h, --help    Show this help message

CHECKS:
    kubectl-cluster    Verify kubectl can connect to cluster
    porch-pods        Ensure porch-system pods are running
    porch-api         Validate Porch API resources are available
    config-mgmt       Check config-management-system (informational)

EXIT CODES:
    0    All required checks pass
    1    kubectl cluster-info failed
    2    porch-system pods not ready
    3    Porch API resources unavailable
    4    Unexpected error

EXAMPLES:
    $SCRIPT_NAME                # Run all checks
    make p0-check              # Run via Makefile target

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error_exit 4 "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Trap errors
trap 'error_exit 4 "Script interrupted"' INT TERM

# Run main function
main "$@"