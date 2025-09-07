#!/bin/bash
# Supply Chain Security Precheck Gate for Nephio Intent-to-O2 Demo
# Validates security compliance before publish-edge target execution with enhanced security reporting integration

set -euo pipefail

# Configuration defaults (can be overridden via environment)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PRECHECK_CONFIG="${PROJECT_ROOT}/.precheck.conf"

# Load configuration if exists
if [[ -f "${PRECHECK_CONFIG}" ]]; then
    # shellcheck disable=SC1090
    source "${PRECHECK_CONFIG}"
fi

# Configuration variables with defaults
readonly MAX_CHANGE_SIZE_LINES="${MAX_CHANGE_SIZE_LINES:-500}"
readonly MAX_CHANGE_SIZE_FILES="${MAX_CHANGE_SIZE_FILES:-20}"
readonly ALLOWED_REGISTRIES="${ALLOWED_REGISTRIES:-gcr.io,ghcr.io,registry.k8s.io,docker.io/library,quay.io,docker.io/nephio,docker.io/oransc}"
readonly STRICT_MODE="${STRICT_MODE:-false}"
readonly COSIGN_REQUIRED="${COSIGN_REQUIRED:-false}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-true}"
readonly ENABLE_SECURITY_REPORT_INTEGRATION="${ENABLE_SECURITY_REPORT_INTEGRATION:-true}"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_VALIDATION_FAILED=1
readonly EXIT_CHANGE_SIZE_EXCEEDED=2
readonly EXIT_REGISTRY_VIOLATION=3
readonly EXIT_SIGNATURE_MISSING=4
readonly EXIT_DEPENDENCY_MISSING=5
readonly EXIT_KPT_RENDER_FAILED=6
readonly EXIT_SECURITY_REPORT_FAILED=7

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# JSON logging support
log_json() {
    local level="$1"
    local message="$2"
    local extra="${3:-}"
    
    if [[ "${LOG_LEVEL}" == "JSON" ]]; then
        jq -n --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
              --arg level "${level}" \
              --arg message "${message}" \
              --arg extra "${extra}" \
              '{timestamp: $timestamp, level: $level, message: $message, extra: $extra}'
    fi
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
    log_json "INFO" "$1" "${2:-}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
    log_json "WARN" "$1" "${2:-}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    log_json "ERROR" "$1" "${2:-}"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" >&2
    log_json "PASS" "$1" "${2:-}"
}

log_header() {
    echo -e "${CYAN}${1}${NC}" >&2
    echo -e "${CYAN}$(printf '%*s' ${#1} '' | tr ' ' '=')${NC}" >&2
}

# Dependency checks
check_dependencies() {
    log_header "Dependency Check"
    
    local deps=(
        "kubeconform:https://github.com/yannh/kubeconform"
        "kpt:https://kpt.dev/installation/"
        "git:standard package"
        "jq:standard package"
    )
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        local cmd="${dep%%:*}"
        local url="${dep##*:}"
        
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_deps+=("${cmd} (${url})")
        fi
    done
    
    if [[ "${#missing_deps[@]}" -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}"
        done
        return ${EXIT_DEPENDENCY_MISSING}
    fi
    
    # Check optional cosign dependency
    if [[ "${COSIGN_REQUIRED}" == "true" ]] && ! command -v cosign >/dev/null 2>&1; then
        log_error "cosign is required but not found (install: https://docs.sigstore.dev/cosign/installation/)"
        return ${EXIT_DEPENDENCY_MISSING}
    fi
    
    log_success "All required dependencies present"
}

# Change size validation
validate_change_size() {
    log_header "Change Size Validation"
    
    local base_branch
    base_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    
    if ! git rev-parse "origin/${base_branch}" >/dev/null 2>&1; then
        base_branch="HEAD~1"
        log_warn "Could not find origin/${base_branch}, using HEAD~1 for diff"
    fi
    
    local diff_stats
    diff_stats=$(git diff --stat "${base_branch}...HEAD" 2>/dev/null || git diff --stat HEAD~1)
    
    if [[ -z "${diff_stats}" ]]; then
        log_success "No changes detected in current branch"
        return 0
    fi
    
    # Extract change statistics
    local files_changed lines_changed
    files_changed=$(echo "${diff_stats}" | tail -n1 | grep -o '[0-9]\+ file' | head -1 | grep -o '[0-9]\+' || echo "0")
    lines_changed=$(echo "${diff_stats}" | tail -n1 | grep -o '[0-9]\+ insertion\|[0-9]\+ deletion' | \
                   awk '{sum += $1} END {print sum+0}')
    
    log_info "Change statistics: ${files_changed} files, ${lines_changed} lines"
    
    # Check thresholds
    local violations=()
    if [[ "${files_changed}" -gt "${MAX_CHANGE_SIZE_FILES}" ]]; then
        violations+=("Files changed (${files_changed}) exceeds limit (${MAX_CHANGE_SIZE_FILES})")
    fi
    
    if [[ "${lines_changed}" -gt "${MAX_CHANGE_SIZE_LINES}" ]]; then
        violations+=("Lines changed (${lines_changed}) exceeds limit (${MAX_CHANGE_SIZE_LINES})")
    fi
    
    if [[ "${#violations[@]}" -gt 0 ]]; then
        log_error "Change size validation failed:"
        for violation in "${violations[@]}"; do
            echo "  - ${violation}"
        done
        log_info "To override, set MAX_CHANGE_SIZE_LINES and/or MAX_CHANGE_SIZE_FILES in ${PRECHECK_CONFIG}"
        return ${EXIT_CHANGE_SIZE_EXCEEDED}
    fi
    
    log_success "Change size within acceptable limits"
}

# YAML validation using kubeconform
validate_yaml_manifests() {
    log_header "YAML Manifest Validation"
    
    local target_dirs=(
        "${PROJECT_ROOT}/packages/intent-to-krm"
        "${PROJECT_ROOT}/packages/intent-to-krm/dist/edge1"
    )
    
    local schema_locations=(
        "${PROJECT_ROOT}/packages/intent-to-krm/schemas"
        "default"
        "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master"
    )
    
    local validation_failed=false
    
    for dir in "${target_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_warn "Directory ${dir} not found, skipping YAML validation"
            continue
        fi
        
        log_info "Validating YAML files in ${dir}"
        
        local yaml_files
        yaml_files=$(find "${dir}" -name "*.yaml" -o -name "*.yml" | grep -v '/schemas/' || true)
        
        if [[ -z "${yaml_files}" ]]; then
            log_warn "No YAML files found in ${dir}"
            continue
        fi
        
        # Build schema location arguments
        local schema_args=()
        for schema_loc in "${schema_locations[@]}"; do
            schema_args+=("-schema-location" "${schema_loc}")
        done
        
        # Run kubeconform validation with ignore for custom resources
        local kubeconform_output
        if kubeconform_output=$(kubeconform "${schema_args[@]}" -summary -skip=CustomResourceDefinition,RANBundle,CNBundle,TNBundle,Kustomization ${yaml_files} 2>&1); then
            log_success "YAML validation passed for ${dir}"
        else
            # Check if the only failures are due to missing CRD schemas
            local error_count
            error_count=$(echo "${kubeconform_output}" | grep -c "failed validation" || echo "0")
            local schema_error_count
            schema_error_count=$(echo "${kubeconform_output}" | grep -c "could not find schema" || echo "0")
            
            if [[ "${error_count}" -eq "${schema_error_count}" ]]; then
                log_warn "YAML validation found missing schemas for custom resources (expected) in ${dir}"
            else
                log_error "YAML validation failed for ${dir}"
                echo "${kubeconform_output}"
                validation_failed=true
            fi
        fi
    done
    
    if [[ "${validation_failed}" == "true" ]]; then
        return ${EXIT_VALIDATION_FAILED}
    fi
}

# Extract and validate container images
validate_container_images() {
    log_header "Container Image Validation"
    
    local target_dirs=(
        "${PROJECT_ROOT}/packages/intent-to-krm/dist/edge1"
        "${PROJECT_ROOT}/manifests"
        "${PROJECT_ROOT}/guardrails"
    )
    
    local images=()
    local registry_violations=()
    local signature_issues=()
    
    # Extract images from YAML files
    for dir in "${target_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            continue
        fi
        
        local found_images
        found_images=$(find "${dir}" -name "*.yaml" -o -name "*.yml" | \
                      xargs grep -h "image:" 2>/dev/null | \
                      sed -n 's/.*image: *\([^[:space:]]*\).*/\1/p' | \
                      sort -u || true)
        
        if [[ -n "${found_images}" ]]; then
            while IFS= read -r image; do
                images+=("${image}")
            done <<< "${found_images}"
        fi
    done
    
    if [[ "${#images[@]}" -eq 0 ]]; then
        log_info "No container images found to validate"
        return 0
    fi
    
    log_info "Found ${#images[@]} unique container images to validate"
    
    # Convert allowed registries to array
    IFS=',' read -ra allowed_registries <<< "${ALLOWED_REGISTRIES}"
    
    for image in "${images[@]}"; do
        # Skip empty or comment lines
        if [[ -z "${image}" || "${image}" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Remove quotes and clean up
        image=$(echo "${image}" | tr -d '"' | tr -d "'" | xargs)
        
        log_info "Validating image: ${image}"
        
        # Check registry allowlist
        local registry_allowed=false
        for allowed_registry in "${allowed_registries[@]}"; do
            if [[ "${image}" =~ ^${allowed_registry}/ ]] || [[ "${image}" == "${allowed_registry}/"* ]]; then
                registry_allowed=true
                break
            fi
            # Handle docker.io/library special case
            if [[ "${allowed_registry}" == "docker.io/library" ]] && [[ "${image}" =~ ^[^/]+$ ]]; then
                registry_allowed=true
                break
            fi
        done
        
        if [[ "${registry_allowed}" != "true" ]]; then
            registry_violations+=("${image}")
            continue
        fi
        
        # Check image signature with cosign if available and required
        if command -v cosign >/dev/null 2>&1; then
            if cosign verify "${image}" >/dev/null 2>&1; then
                log_success "Image signature verified: ${image}"
            else
                if [[ "${COSIGN_REQUIRED}" == "true" ]]; then
                    signature_issues+=("${image}")
                else
                    log_warn "Image signature not found (allowed): ${image}"
                fi
            fi
        fi
    done
    
    # Report violations
    local validation_failed=false
    
    if [[ "${#registry_violations[@]}" -gt 0 ]]; then
        log_error "Registry allowlist violations found:"
        for violation in "${registry_violations[@]}"; do
            echo "  - ${violation}"
        done
        echo "Allowed registries: ${ALLOWED_REGISTRIES}"
        validation_failed=true
    fi
    
    if [[ "${#signature_issues[@]}" -gt 0 ]]; then
        log_error "Missing required image signatures:"
        for issue in "${signature_issues[@]}"; do
            echo "  - ${issue}"
        done
        validation_failed=true
    fi
    
    if [[ "${validation_failed}" == "true" ]]; then
        return ${EXIT_REGISTRY_VIOLATION}
    fi
    
    log_success "All container images passed validation"
}

# kpt function validation
validate_kpt_structure() {
    log_header "KPT Package Validation"
    
    local kpt_package_dir="${PROJECT_ROOT}/packages/intent-to-krm"
    
    if [[ ! -f "${kpt_package_dir}/Kptfile" ]]; then
        log_warn "No Kptfile found in ${kpt_package_dir}, skipping kpt validation"
        return 0
    fi
    
    log_info "Validating kpt package structure"
    
    # Validate Kptfile syntax
    if ! kpt pkg validate "${kpt_package_dir}" >/dev/null 2>&1; then
        log_error "kpt package validation failed"
        log_info "Run 'kpt pkg validate ${kpt_package_dir}' for detailed error information"
        return ${EXIT_KPT_RENDER_FAILED}
    fi
    
    # Check if function images are in allowlist
    local function_images
    function_images=$(grep -E "^\s*-\s+image:" "${kpt_package_dir}/Kptfile" | sed 's/.*image:\s*\([^[:space:]]*\).*/\1/' || true)
    
    if [[ -n "${function_images}" ]]; then
        # Convert allowed registries to array
        IFS=',' read -ra allowed_registries <<< "${ALLOWED_REGISTRIES}"
        
        while IFS= read -r image; do
            if [[ -z "${image}" ]]; then
                continue
            fi
            
            log_info "Checking kpt function image: ${image}"
            
            # Check if it's a local image (no registry prefix) - allow for development
            if [[ "${image}" != *"/"* ]]; then
                log_warn "kpt function uses local image (development mode): ${image}"
                continue
            fi
            
            # Check registry allowlist for function images
            local registry_allowed=false
            for allowed_registry in "${allowed_registries[@]}"; do
                if [[ "${image}" =~ ^${allowed_registry}/ ]]; then
                    registry_allowed=true
                    break
                fi
            done
            
            if [[ "${registry_allowed}" != "true" ]]; then
                log_error "kpt function image not in registry allowlist: ${image}"
                return ${EXIT_REGISTRY_VIOLATION}
            fi
        done <<< "${function_images}"
    fi
    
    log_success "kpt package structure validation passed"
}

# Integration with comprehensive security report
run_security_report_integration() {
    log_header "Security Report Integration"
    
    if [[ "${ENABLE_SECURITY_REPORT_INTEGRATION}" != "true" ]]; then
        log_info "Security report integration disabled"
        return 0
    fi
    
    if [[ ! -f "${SCRIPT_DIR}/security_report.sh" ]]; then
        log_warn "Security report script not found, skipping integration"
        return 0
    fi
    
    log_info "Running comprehensive security report as part of precheck"
    
    # Run security report in development mode to avoid blocking precheck
    local security_env_vars=""
    if [[ "${ALLOW_UNSIGNED}" == "true" ]]; then
        security_env_vars="ALLOW_UNSIGNED=true SECURITY_POLICY_LEVEL=permissive"
    fi
    
    if eval "${security_env_vars} ${SCRIPT_DIR}/security_report.sh" >/dev/null 2>&1; then
        log_success "Comprehensive security report completed successfully"
        
        # Check if reports directory exists and has the latest report
        local reports_dir="${PROJECT_ROOT}/reports"
        if [[ -f "${reports_dir}/security-latest.json" ]]; then
            local compliance_score
            compliance_score=$(jq -r '.security_report.summary.policy_compliance_score // 0' "${reports_dir}/security-latest.json" 2>/dev/null || echo "0")
            
            log_info "Security compliance score: ${compliance_score}/100"
            
            # In precheck, we use a lower threshold to avoid blocking development
            local threshold=50
            if [[ "${STRICT_MODE}" == "true" ]]; then
                threshold=80
            fi
            
            if [[ "${compliance_score}" -lt "${threshold}" ]]; then
                log_warn "Security compliance score (${compliance_score}) below precheck threshold (${threshold})"
                log_info "Run 'make security-report' for detailed security analysis"
                
                if [[ "${STRICT_MODE}" == "true" ]]; then
                    return ${EXIT_SECURITY_REPORT_FAILED}
                fi
            else
                log_success "Security compliance score meets precheck requirements"
            fi
        else
            log_warn "Security report file not found, continuing precheck"
        fi
    else
        log_warn "Security report generation failed, continuing precheck"
        log_info "Run 'make security-report' manually for detailed security analysis"
    fi
}

# Generate summary report
generate_summary() {
    local start_time="$1"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "==============================================="
    echo "    SUPPLY CHAIN SECURITY PRECHECK SUMMARY"
    echo "==============================================="
    echo "Duration: ${duration}s"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Git commit: $(git rev-parse --short HEAD)"
    echo "Branch: $(git branch --show-current)"
    echo "Configuration:"
    echo "  STRICT_MODE: ${STRICT_MODE}"
    echo "  COSIGN_REQUIRED: ${COSIGN_REQUIRED}"  
    echo "  ALLOW_UNSIGNED: ${ALLOW_UNSIGNED}"
    echo "  SECURITY_INTEGRATION: ${ENABLE_SECURITY_REPORT_INTEGRATION}"
    echo ""
    
    # Create JSON summary if requested
    if [[ "${LOG_LEVEL}" == "JSON" ]]; then
        mkdir -p "${PROJECT_ROOT}/artifacts"
        jq -n --arg duration "${duration}" \
              --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
              --arg commit "$(git rev-parse --short HEAD)" \
              --arg branch "$(git branch --show-current)" \
              --arg strict_mode "${STRICT_MODE}" \
              --arg cosign_required "${COSIGN_REQUIRED}" \
              --arg allow_unsigned "${ALLOW_UNSIGNED}" \
              --arg security_integration "${ENABLE_SECURITY_REPORT_INTEGRATION}" \
              '{
                precheck_summary: {
                  duration: $duration,
                  timestamp: $timestamp,
                  git: {
                    commit: $commit,
                    branch: $branch
                  },
                  configuration: {
                    strict_mode: ($strict_mode | test("true")),
                    cosign_required: ($cosign_required | test("true")),
                    allow_unsigned: ($allow_unsigned | test("true")),
                    security_integration: ($security_integration | test("true"))
                  }
                }
              }' > "${PROJECT_ROOT}/artifacts/precheck-summary.json"
    fi
}

# Main execution
main() {
    local start_time
    start_time=$(date +%s)
    
    log_header "Supply Chain Security Precheck with Enhanced Reporting"
    log_info "Project root: ${PROJECT_ROOT}"
    log_info "Configuration: STRICT_MODE=${STRICT_MODE}, COSIGN_REQUIRED=${COSIGN_REQUIRED}, ALLOW_UNSIGNED=${ALLOW_UNSIGNED}"
    log_info "Security report integration: ${ENABLE_SECURITY_REPORT_INTEGRATION}"
    
    # Ensure artifacts and reports directories exist
    mkdir -p "${PROJECT_ROOT}/artifacts" "${PROJECT_ROOT}/reports"
    
    # Run all validation steps
    local exit_code=0
    
    check_dependencies || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Dependency check failed"
        generate_summary "${start_time}"
        exit ${exit_code}
    fi
    
    validate_change_size || exit_code=$?
    if [[ ${exit_code} -ne 0 ]] && [[ "${STRICT_MODE}" == "true" ]]; then
        log_error "Change size validation failed (STRICT_MODE=true)"
        generate_summary "${start_time}"
        exit ${exit_code}
    elif [[ ${exit_code} -ne 0 ]]; then
        log_warn "Change size validation failed but continuing (STRICT_MODE=false)"
        exit_code=0
    fi
    
    validate_yaml_manifests || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "YAML manifest validation failed"
        generate_summary "${start_time}"
        exit ${exit_code}
    fi
    
    validate_container_images || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Container image validation failed"
        generate_summary "${start_time}"
        exit ${exit_code}
    fi
    
    validate_kpt_structure || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "kpt package structure validation failed"
        generate_summary "${start_time}"
        exit ${exit_code}
    fi
    
    # Run security report integration (non-blocking in most cases)
    run_security_report_integration || {
        local security_exit_code=$?
        if [[ "${STRICT_MODE}" == "true" ]]; then
            exit_code=${security_exit_code}
        else
            log_warn "Security report integration failed but continuing (STRICT_MODE=false)"
        fi
    }
    
    generate_summary "${start_time}"
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "All precheck validations passed - ready for publish-edge"
        log_info "For comprehensive security analysis, run: make security-report"
    else
        log_error "Precheck failed - review errors above"
    fi
    
    return ${exit_code}
}

# Handle help and version flags
case "${1:-}" in
    -h|--help)
        cat << 'EOF'
Supply Chain Security Precheck Gate with Enhanced Security Reporting

USAGE:
    ./scripts/precheck.sh [OPTIONS]

DESCRIPTION:
    Enhanced precheck gate that validates supply chain security before executing 
    make publish-edge. Includes comprehensive security report integration and 
    improved validation capabilities.

    Validates:
    - Change size limits
    - YAML manifest structure  
    - Container registry allowlist
    - Image signature verification
    - KPT package structure
    - Security policy compliance

OPTIONS:
    -h, --help      Show this help message
    --version       Show version information

CONFIGURATION:
    Set environment variables or create .precheck.conf in project root:

    MAX_CHANGE_SIZE_LINES=500                    Maximum lines changed threshold
    MAX_CHANGE_SIZE_FILES=20                     Maximum files changed threshold
    ALLOWED_REGISTRIES=gcr.io,ghcr.io           Comma-separated allowed registries  
    STRICT_MODE=false                            Fail on any validation warning
    COSIGN_REQUIRED=false                        Require cosign signature verification
    ALLOW_UNSIGNED=true                          Allow unsigned images (development)
    ENABLE_SECURITY_REPORT_INTEGRATION=true     Run comprehensive security report
    LOG_LEVEL=INFO                               Set to JSON for machine-readable logs

EXIT CODES:
    0   Success - ready for deployment
    1   General validation failure
    2   Change size exceeded limits
    3   Registry allowlist violation  
    4   Missing required signatures
    5   Missing dependencies
    6   KPT package validation failed
    7   Security report integration failed

EXAMPLES:
    # Basic precheck
    ./scripts/precheck.sh

    # Strict mode with cosign required
    STRICT_MODE=true COSIGN_REQUIRED=true ./scripts/precheck.sh

    # Development mode with security integration
    ALLOW_UNSIGNED=true ENABLE_SECURITY_REPORT_INTEGRATION=true ./scripts/precheck.sh

    # Production mode
    STRICT_MODE=true COSIGN_REQUIRED=true ALLOW_UNSIGNED=false ./scripts/precheck.sh

    # JSON logging for CI/CD
    LOG_LEVEL=JSON ./scripts/precheck.sh > precheck.json

INTEGRATION:
    This precheck integrates with the comprehensive security report system:
    - Runs security analysis as part of precheck validation
    - Generates compliance scores and detailed findings
    - Provides actionable recommendations
    - Supports both development and production security postures

    For full security analysis, run: make security-report
EOF
        exit 0
        ;;
    --version)
        echo "Supply Chain Security Precheck Gate v2.0.0 with Enhanced Security Reporting"
        echo "Part of Nephio Intent-to-O2 Demo Pipeline"
        exit 0
        ;;
esac

# Execute main function
main "$@"