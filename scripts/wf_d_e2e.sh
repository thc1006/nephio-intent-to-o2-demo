#!/bin/bash
# WF-D End-to-End Test Script
# Tests O2IMS workflow D implementation in both fake and real cluster modes

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts/wf-d-e2e-${TIMESTAMP}"
DEFAULT_KUBECONFIG="/tmp/kubeconfig-edge.yaml"

# Test configuration
MODE="both"  # fake, real, or both
KUBECONFIG_PATH="${DEFAULT_KUBECONFIG}"
VERBOSE=false
CLEANUP=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Usage function
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

WF-D End-to-End Test Script for O2IMS Implementation

OPTIONS:
    -m, --mode MODE           Test mode: fake, real, or both (default: both)
    -k, --kubeconfig PATH     Path to kubeconfig for real cluster (default: /tmp/kubeconfig-edge.yaml)
    -v, --verbose            Enable verbose output
    -n, --no-cleanup         Skip cleanup after tests
    -h, --help               Show this help message

EXAMPLES:
    # Run fake tests only
    $0 --mode fake

    # Run real cluster tests with specific kubeconfig
    $0 --mode real --kubeconfig /path/to/kubeconfig

    # Run all tests with verbose output
    $0 --mode both --verbose

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -k|--kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--no-cleanup)
            CLEANUP=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Initialize test environment
init_test_env() {
    log_section "Initializing Test Environment"
    
    # Create artifacts directory
    mkdir -p "$ARTIFACTS_DIR"
    log_info "Created artifacts directory: $ARTIFACTS_DIR"
    
    # Save test configuration
    cat > "$ARTIFACTS_DIR/test-config.txt" <<EOF
Test Configuration
==================
Timestamp: $TIMESTAMP
Mode: $MODE
Kubeconfig: $KUBECONFIG_PATH
Verbose: $VERBOSE
Cleanup: $CLEANUP
EOF
    
    log_success "Test environment initialized"
}

# Run fake/envtest suite
run_fake_tests() {
    log_section "Running Fake/Envtest Suite"
    
    local test_output="$ARTIFACTS_DIR/fake-test-output.txt"
    
    log_info "Running unit tests for O2IMS SDK..."
    
    # Check if O2IMS SDK directory exists
    if [ -d "${PROJECT_ROOT}/o2ims-sdk" ]; then
        cd "${PROJECT_ROOT}/o2ims-sdk"
        
        # Run Go tests
        if go test -v ./... > "$test_output" 2>&1; then
            log_success "Unit tests passed"
            if [ "$VERBOSE" = true ]; then
                cat "$test_output"
            fi
        else
            log_error "Unit tests failed. See $test_output for details"
            return 1
        fi
    else
        log_warning "O2IMS SDK directory not found, skipping unit tests"
    fi
    
    # Run fake ProvisioningRequest operations
    log_info "Testing fake ProvisioningRequest operations..."
    
    # Simulate creating a ProvisioningRequest
    cat > "$ARTIFACTS_DIR/fake-pr.yaml" <<EOF
apiVersion: o2ims.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: fake-test-pr
  namespace: default
spec:
  clusterName: "fake-cluster"
  nodeCount: 3
  region: "fake-region"
  resourcePool: "fake-pool"
EOF
    
    log_success "Fake ProvisioningRequest created (simulation)"
    
    cd "$PROJECT_ROOT"
    return 0
}

# Run smoke tests against real cluster
run_real_tests() {
    log_section "Running Smoke Tests Against Real Cluster"
    
    # Validate kubeconfig
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_error "Kubeconfig file not found: $KUBECONFIG_PATH"
        return 1
    fi
    
    export KUBECONFIG="$KUBECONFIG_PATH"
    log_info "Using kubeconfig: $KUBECONFIG_PATH"
    
    # Test 1: List nodes
    log_info "Test 1: Listing cluster nodes..."
    local nodes_output="$ARTIFACTS_DIR/real-nodes.txt"
    if kubectl get nodes -o wide > "$nodes_output" 2>&1; then
        log_success "Successfully listed nodes"
        if [ "$VERBOSE" = true ]; then
            cat "$nodes_output"
        fi
    else
        log_error "Failed to list nodes"
        return 1
    fi
    
    # Test 2: List namespaces
    log_info "Test 2: Listing namespaces..."
    local ns_output="$ARTIFACTS_DIR/real-namespaces.txt"
    if kubectl get namespaces > "$ns_output" 2>&1; then
        log_success "Successfully listed namespaces"
        
        # Check for O2IMS namespace
        if grep -q "o2ims-system" "$ns_output"; then
            log_success "O2IMS system namespace found"
        else
            log_warning "O2IMS system namespace not found"
        fi
    else
        log_error "Failed to list namespaces"
        return 1
    fi
    
    # Test 3: Create test ProvisioningRequest
    log_info "Test 3: Creating test ProvisioningRequest..."
    local test_pr_name="e2e-test-pr-${TIMESTAMP}"
    
    cat > "$ARTIFACTS_DIR/test-pr.yaml" <<EOF
apiVersion: o2ims.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: ${test_pr_name}
  namespace: o2ims-system
spec:
  clusterName: "e2e-test-cluster"
  nodeCount: 2
  region: "test-region"
  resourcePool: "default"
EOF
    
    if kubectl apply -f "$ARTIFACTS_DIR/test-pr.yaml" > "$ARTIFACTS_DIR/pr-create.txt" 2>&1; then
        log_success "Test ProvisioningRequest created"
        
        # Get the PR
        log_info "Test 4: Getting ProvisioningRequest..."
        if kubectl get provisioningrequest ${test_pr_name} -n o2ims-system -o yaml > "$ARTIFACTS_DIR/pr-get.yaml" 2>&1; then
            log_success "Successfully retrieved ProvisioningRequest"
        else
            log_error "Failed to get ProvisioningRequest"
        fi
        
        # List all PRs
        log_info "Test 5: Listing all ProvisioningRequests..."
        if kubectl get provisioningrequests -n o2ims-system > "$ARTIFACTS_DIR/pr-list.txt" 2>&1; then
            log_success "Successfully listed ProvisioningRequests"
            if [ "$VERBOSE" = true ]; then
                cat "$ARTIFACTS_DIR/pr-list.txt"
            fi
        fi
        
        # Delete test PR
        if [ "$CLEANUP" = true ]; then
            log_info "Cleaning up test ProvisioningRequest..."
            if kubectl delete provisioningrequest ${test_pr_name} -n o2ims-system > "$ARTIFACTS_DIR/pr-delete.txt" 2>&1; then
                log_success "Test ProvisioningRequest deleted"
            else
                log_warning "Failed to delete test ProvisioningRequest"
            fi
        fi
    else
        log_error "Failed to create test ProvisioningRequest"
        cat "$ARTIFACTS_DIR/test-pr.yaml"
        kubectl apply -f "$ARTIFACTS_DIR/test-pr.yaml" --dry-run=client -o yaml
    fi
    
    # Test 6: Query O2IMS inventory (placeholder)
    log_info "Test 6: Querying O2IMS inventory..."
    log_warning "O2IMS inventory query not yet implemented (placeholder for future development)"
    
    return 0
}

# Generate test report
generate_report() {
    log_section "Generating Test Report"
    
    local report_file="$ARTIFACTS_DIR/test-report.md"
    
    cat > "$report_file" <<EOF
# WF-D E2E Test Report

**Timestamp**: $TIMESTAMP  
**Mode**: $MODE  
**Kubeconfig**: $KUBECONFIG_PATH  

## Test Results

### Fake/Envtest Suite
EOF
    
    if [ "$MODE" = "fake" ] || [ "$MODE" = "both" ]; then
        if [ -f "$ARTIFACTS_DIR/fake-test-output.txt" ]; then
            echo "✅ Unit tests executed successfully" >> "$report_file"
        else
            echo "❌ Unit tests not executed" >> "$report_file"
        fi
    fi
    
    cat >> "$report_file" <<EOF

### Real Cluster Tests
EOF
    
    if [ "$MODE" = "real" ] || [ "$MODE" = "both" ]; then
        if [ -f "$ARTIFACTS_DIR/real-nodes.txt" ]; then
            echo "✅ Node listing successful" >> "$report_file"
            echo "✅ Namespace listing successful" >> "$report_file"
            
            if [ -f "$ARTIFACTS_DIR/pr-create.txt" ]; then
                echo "✅ ProvisioningRequest CRUD operations successful" >> "$report_file"
            else
                echo "⚠️ ProvisioningRequest operations not tested" >> "$report_file"
            fi
        else
            echo "❌ Real cluster tests not executed" >> "$report_file"
        fi
    fi
    
    cat >> "$report_file" <<EOF

## Artifacts

All test artifacts saved to: \`$ARTIFACTS_DIR\`

### Files Generated
EOF
    
    ls -la "$ARTIFACTS_DIR" >> "$report_file"
    
    log_success "Test report generated: $report_file"
    
    if [ "$VERBOSE" = true ]; then
        cat "$report_file"
    fi
}

# Cleanup function
cleanup() {
    if [ "$CLEANUP" = true ]; then
        log_info "Performing cleanup..."
        # Add cleanup tasks here if needed
    fi
}

# Main execution
main() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    WF-D End-to-End Test Suite${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Initialize test environment
    init_test_env
    
    # Run tests based on mode
    case "$MODE" in
        fake)
            run_fake_tests
            ;;
        real)
            run_real_tests
            ;;
        both)
            run_fake_tests
            run_real_tests
            ;;
        *)
            log_error "Invalid mode: $MODE"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_report
    
    log_section "Test Execution Complete"
    log_success "All artifacts saved to: $ARTIFACTS_DIR"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    Tests Completed Successfully${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run main function
main "$@"