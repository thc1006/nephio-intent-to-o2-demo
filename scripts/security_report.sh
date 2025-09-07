#!/bin/bash
# Comprehensive Security Report Generator for Nephio Intent-to-O2 Demo
# Validates supply chain security with kubeconform, cosign verification, and policy compliance

set -euo pipefail

# Configuration defaults (can be overridden via environment)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SECURITY_CONFIG="${PROJECT_ROOT}/.security.conf"
readonly REPORTS_DIR="${PROJECT_ROOT}/reports"
readonly TIMESTAMP=$(date +%Y%m%d)
readonly REPORT_FILE="${REPORTS_DIR}/security-${TIMESTAMP}.json"

# Load configuration if exists
if [[ -f "${SECURITY_CONFIG}" ]]; then
    # shellcheck disable=SC1090
    source "${SECURITY_CONFIG}"
fi

# Configuration variables with defaults
readonly ALLOWED_REGISTRIES="${ALLOWED_REGISTRIES:-gcr.io,ghcr.io,registry.k8s.io,docker.io/library,quay.io,docker.io/nephio,docker.io/oransc}"
readonly ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-false}"
readonly SECURITY_POLICY_LEVEL="${SECURITY_POLICY_LEVEL:-strict}"
readonly COSIGN_TIMEOUT="${COSIGN_TIMEOUT:-30}"
readonly PARALLEL_SCANS="${PARALLEL_SCANS:-4}"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_VALIDATION_FAILED=1
readonly EXIT_SIGNATURE_MISSING=2
readonly EXIT_REGISTRY_VIOLATION=3
readonly EXIT_DEPENDENCY_MISSING=4
readonly EXIT_REPORT_GENERATION_FAILED=5

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global variables for report aggregation
declare -a KUBECONFORM_RESULTS=()
declare -a COSIGN_RESULTS=()
declare -a REGISTRY_VIOLATIONS=()
declare -a SIGNATURE_ISSUES=()
declare -a POLICY_COMPLIANCE_RESULTS=()

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" >&2
}

log_header() {
    echo -e "${CYAN}${1}${NC}" >&2
    echo -e "${CYAN}$(printf '%*s' ${#1} '' | tr ' ' '=')${NC}" >&2
}

# Dependency checks
check_dependencies() {
    log_header "Checking Dependencies"
    
    local deps=(
        "kubeconform:https://github.com/yannh/kubeconform"
        "jq:standard package"
        "curl:standard package"
        "find:standard package"
        "grep:standard package"
    )
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        local cmd="${dep%%:*}"
        local url="${dep##*:}"
        
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_deps+=("${cmd} (${url})")
        fi
    done
    
    # Check optional cosign dependency
    if ! command -v cosign >/dev/null 2>&1; then
        log_warn "cosign not found - signature verification will be skipped"
        log_info "Install cosign: https://docs.sigstore.dev/cosign/system_config/installation/"
    else
        log_success "cosign found: $(cosign version --short 2>/dev/null || echo 'unknown version')"
    fi
    
    if [[ "${#missing_deps[@]}" -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}"
        done
        return ${EXIT_DEPENDENCY_MISSING}
    fi
    
    log_success "All required dependencies present"
}

# Install cosign if not present (for CI environments)
install_cosign_if_needed() {
    if ! command -v cosign >/dev/null 2>&1; then
        if [[ "${CI:-false}" == "true" ]] || [[ "${AUTO_INSTALL_COSIGN:-false}" == "true" ]]; then
            log_info "Installing cosign for CI/automated environment..."
            
            local cosign_version="${COSIGN_VERSION:-v2.2.1}"
            local cosign_url="https://github.com/sigstore/cosign/releases/download/${cosign_version}/cosign-linux-amd64"
            
            curl -fsSL "${cosign_url}" -o /tmp/cosign
            chmod +x /tmp/cosign
            sudo mv /tmp/cosign /usr/local/bin/cosign 2>/dev/null || mv /tmp/cosign "${HOME}/.local/bin/cosign" 2>/dev/null || {
                log_error "Failed to install cosign"
                return ${EXIT_DEPENDENCY_MISSING}
            }
            
            log_success "cosign installed: $(cosign version --short)"
        fi
    fi
}

# Kubeconform validation for all YAML manifests
validate_yaml_manifests() {
    log_header "Kubeconform YAML Validation"
    
    local target_dirs=(
        "${PROJECT_ROOT}/packages"
        "${PROJECT_ROOT}/samples"
        "${PROJECT_ROOT}/guardrails"
        "${PROJECT_ROOT}/manifests"
    )
    
    local schema_locations=(
        "default"
        "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master"
    )
    
    local total_files=0
    local valid_files=0
    local invalid_files=0
    local warnings=0
    
    for dir in "${target_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_warn "Directory ${dir} not found, skipping"
            continue
        fi
        
        log_info "Validating YAML files in ${dir}"
        
        local yaml_files
        yaml_files=$(find "${dir}" -name "*.yaml" -o -name "*.yml" | grep -v '/schemas/' | head -50 || true)
        
        if [[ -z "${yaml_files}" ]]; then
            log_warn "No YAML files found in ${dir}"
            continue
        fi
        
        # Build schema location arguments
        local schema_args=()
        for schema_loc in "${schema_locations[@]}"; do
            schema_args+=("-schema-location" "${schema_loc}")
        done
        
        # Process files in batches to avoid command line length limits
        while IFS= read -r yaml_file; do
            if [[ -z "${yaml_file}" ]]; then
                continue
            fi
            
            ((total_files++))
            
            local validation_result
            local validation_output
            if validation_output=$(kubeconform "${schema_args[@]}" -summary -skip=CustomResourceDefinition,RANBundle,CNBundle,TNBundle,Kustomization "${yaml_file}" 2>&1); then
                ((valid_files++))
                KUBECONFORM_RESULTS+=("{\"file\":\"${yaml_file#$PROJECT_ROOT/}\",\"status\":\"valid\",\"message\":\"passed validation\"}")
            else
                # Check if it's a schema issue (warning) or validation error
                if echo "${validation_output}" | grep -q "could not find schema"; then
                    ((warnings++))
                    KUBECONFORM_RESULTS+=("{\"file\":\"${yaml_file#$PROJECT_ROOT/}\",\"status\":\"warning\",\"message\":\"schema not found - custom resource\"}")
                else
                    ((invalid_files++))
                    local error_msg
                    error_msg=$(echo "${validation_output}" | head -1 | sed 's/"/\\"/g')
                    KUBECONFORM_RESULTS+=("{\"file\":\"${yaml_file#$PROJECT_ROOT/}\",\"status\":\"invalid\",\"message\":\"${error_msg}\"}")
                fi
            fi
        done <<< "${yaml_files}"
    done
    
    log_info "Kubeconform validation summary:"
    log_info "  Total files: ${total_files}"
    log_info "  Valid: ${valid_files}"
    log_info "  Invalid: ${invalid_files}"
    log_info "  Warnings: ${warnings}"
    
    if [[ ${invalid_files} -gt 0 ]]; then
        log_error "Found ${invalid_files} invalid YAML files"
        return ${EXIT_VALIDATION_FAILED}
    else
        log_success "All YAML files passed validation (${warnings} warnings for custom resources)"
    fi
}

# Extract container images from YAML manifests
extract_container_images() {
    local target_dirs=(
        "${PROJECT_ROOT}/packages"
        "${PROJECT_ROOT}/samples"
        "${PROJECT_ROOT}/guardrails"
        "${PROJECT_ROOT}/manifests"
    )
    
    local images=()
    
    for dir in "${target_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            continue
        fi
        
        local found_images
        found_images=$(find "${dir}" -name "*.yaml" -o -name "*.yml" | \
                      xargs grep -h "image:" 2>/dev/null | \
                      sed -n 's/.*image: *['"'"'"]?\([^'"'"'"][^[:space:]]*\)['"'"'"]?.*/\1/p' | \
                      sort -u || true)
        
        if [[ -n "${found_images}" ]]; then
            while IFS= read -r image; do
                if [[ -n "${image}" && ! "${image}" =~ ^[[:space:]]*# ]]; then
                    images+=("${image}")
                fi
            done <<< "${found_images}"
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${images[@]}" | sort -u
}

# Validate registry allowlist
validate_registry_allowlist() {
    log_header "Registry Allowlist Validation"
    
    local images
    readarray -t images < <(extract_container_images)
    
    if [[ "${#images[@]}" -eq 0 ]]; then
        log_info "No container images found to validate"
        return 0
    fi
    
    log_info "Found ${#images[@]} unique container images to validate"
    
    # Convert allowed registries to array
    IFS=',' read -ra allowed_registries <<< "${ALLOWED_REGISTRIES}"
    
    local violations=0
    
    for image in "${images[@]}"; do
        # Skip empty lines
        if [[ -z "${image}" ]]; then
            continue
        fi
        
        log_info "Checking registry for: ${image}"
        
        # Check registry allowlist
        local registry_allowed=false
        for allowed_registry in "${allowed_registries[@]}"; do
            if [[ "${image}" =~ ^${allowed_registry}/ ]]; then
                registry_allowed=true
                break
            fi
            # Handle docker.io/library special case and unqualified images
            if [[ "${allowed_registry}" == "docker.io/library" && "${image}" =~ ^[^/]+$ ]]; then
                registry_allowed=true
                break
            fi
            # Handle docker.io default registry
            if [[ "${allowed_registry}" == "docker.io" && "${image}" =~ ^[^/]+/[^/]+$ ]]; then
                registry_allowed=true
                break
            fi
        done
        
        if [[ "${registry_allowed}" == "true" ]]; then
            log_success "Registry allowed: ${image}"
        else
            log_error "Registry not allowed: ${image}"
            REGISTRY_VIOLATIONS+=("${image}")
            ((violations++))
        fi
    done
    
    if [[ ${violations} -gt 0 ]]; then
        log_error "Found ${violations} registry violations"
        log_info "Allowed registries: ${ALLOWED_REGISTRIES}"
        return ${EXIT_REGISTRY_VIOLATION}
    else
        log_success "All container images from allowed registries"
    fi
}

# Cosign signature verification
verify_image_signatures() {
    log_header "Container Image Signature Verification"
    
    if ! command -v cosign >/dev/null 2>&1; then
        log_warn "cosign not available - skipping signature verification"
        return 0
    fi
    
    local images
    readarray -t images < <(extract_container_images)
    
    if [[ "${#images[@]}" -eq 0 ]]; then
        log_info "No container images found to verify"
        return 0
    fi
    
    log_info "Verifying signatures for ${#images[@]} container images"
    
    local signed_count=0
    local unsigned_count=0
    local verification_errors=0
    
    # Process images in parallel batches
    local batch_size=${PARALLEL_SCANS}
    local current_batch=0
    local pids=()
    
    for image in "${images[@]}"; do
        if [[ -z "${image}" ]]; then
            continue
        fi
        
        # Start background verification
        {
            verify_single_image_signature "${image}"
        } &
        pids+=($!)
        
        ((current_batch++))
        
        # Wait for batch to complete
        if [[ ${current_batch} -ge ${batch_size} ]]; then
            for pid in "${pids[@]}"; do
                wait "${pid}"
            done
            pids=()
            current_batch=0
        fi
    done
    
    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait "${pid}"
    done
    
    # Count results
    for result in "${COSIGN_RESULTS[@]}"; do
        local status
        status=$(echo "${result}" | jq -r '.status')
        case "${status}" in
            "signed")
                ((signed_count++))
                ;;
            "unsigned")
                ((unsigned_count++))
                ;;
            "error")
                ((verification_errors++))
                ;;
        esac
    done
    
    log_info "Signature verification summary:"
    log_info "  Signed: ${signed_count}"
    log_info "  Unsigned: ${unsigned_count}"
    log_info "  Errors: ${verification_errors}"
    
    if [[ "${ALLOW_UNSIGNED}" != "true" && ${unsigned_count} -gt 0 ]]; then
        log_error "Found ${unsigned_count} unsigned images (ALLOW_UNSIGNED=false)"
        return ${EXIT_SIGNATURE_MISSING}
    elif [[ ${unsigned_count} -gt 0 ]]; then
        log_warn "Found ${unsigned_count} unsigned images (allowed in development)"
    fi
    
    if [[ ${verification_errors} -gt 0 ]]; then
        log_warn "Found ${verification_errors} verification errors"
    fi
    
    log_success "Image signature verification completed"
}

# Verify single image signature (called in background)
verify_single_image_signature() {
    local image="$1"
    local result_file="/tmp/cosign_${image//\//_}_${RANDOM}.json"
    
    # Attempt signature verification with timeout
    if timeout "${COSIGN_TIMEOUT}" cosign verify "${image}" >/dev/null 2>&1; then
        local result="{\"image\":\"${image}\",\"status\":\"signed\",\"message\":\"signature verified\"}"
        echo "${result}" >> "${result_file}"
        COSIGN_RESULTS+=("${result}")
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 124 ]]; then
            local result="{\"image\":\"${image}\",\"status\":\"error\",\"message\":\"verification timeout\"}"
            echo "${result}" >> "${result_file}"
            COSIGN_RESULTS+=("${result}")
        else
            local result="{\"image\":\"${image}\",\"status\":\"unsigned\",\"message\":\"no signature found\"}"
            echo "${result}" >> "${result_file}"
            COSIGN_RESULTS+=("${result}")
            SIGNATURE_ISSUES+=("${image}")
        fi
    fi
    
    # Cleanup temp file
    rm -f "${result_file}"
}

# Policy compliance assessment
assess_policy_compliance() {
    log_header "Security Policy Compliance Assessment"
    
    local compliance_score=100
    local violations=()
    
    # Check for unsigned images in production contexts
    if [[ "${#SIGNATURE_ISSUES[@]}" -gt 0 && "${SECURITY_POLICY_LEVEL}" == "strict" ]]; then
        compliance_score=$((compliance_score - 30))
        violations+=("Unsigned images in strict security policy mode")
    fi
    
    # Check for registry violations
    if [[ "${#REGISTRY_VIOLATIONS[@]}" -gt 0 ]]; then
        compliance_score=$((compliance_score - 40))
        violations+=("Images from non-allowed registries")
    fi
    
    # Check for invalid YAML files
    local invalid_yaml_count
    invalid_yaml_count=$(printf '%s\n' "${KUBECONFORM_RESULTS[@]}" | jq -r 'select(.status=="invalid")' | wc -l)
    if [[ ${invalid_yaml_count} -gt 0 ]]; then
        compliance_score=$((compliance_score - 20))
        violations+=("Invalid Kubernetes manifests")
    fi
    
    # Determine compliance level
    local compliance_level
    if [[ ${compliance_score} -ge 90 ]]; then
        compliance_level="excellent"
    elif [[ ${compliance_score} -ge 75 ]]; then
        compliance_level="good"
    elif [[ ${compliance_score} -ge 60 ]]; then
        compliance_level="acceptable"
    else
        compliance_level="poor"
    fi
    
    POLICY_COMPLIANCE_RESULTS=(
        "{\"score\":${compliance_score},\"level\":\"${compliance_level}\",\"violations\":[$(printf '"%s",' "${violations[@]}" | sed 's/,$//')],\"total_violations\":${#violations[@]}}"
    )
    
    log_info "Policy compliance assessment:"
    log_info "  Score: ${compliance_score}/100"
    log_info "  Level: ${compliance_level}"
    log_info "  Violations: ${#violations[@]}"
    
    if [[ ${compliance_score} -lt 60 ]]; then
        log_error "Security policy compliance below acceptable threshold"
        return ${EXIT_VALIDATION_FAILED}
    else
        log_success "Security policy compliance: ${compliance_level}"
    fi
}

# Generate recommendations based on findings
generate_recommendations() {
    local recommendations=()
    
    if [[ "${#SIGNATURE_ISSUES[@]}" -gt 0 ]]; then
        recommendations+=("Sign all container images with cosign for production deployment")
        recommendations+=("Implement automated image signing in CI/CD pipeline")
    fi
    
    if [[ "${#REGISTRY_VIOLATIONS[@]}" -gt 0 ]]; then
        recommendations+=("Use only approved container registries: ${ALLOWED_REGISTRIES}")
        recommendations+=("Implement registry allowlist policy enforcement")
    fi
    
    local invalid_yaml_count
    invalid_yaml_count=$(printf '%s\n' "${KUBECONFORM_RESULTS[@]}" | jq -r 'select(.status=="invalid")' | wc -l)
    if [[ ${invalid_yaml_count} -gt 0 ]]; then
        recommendations+=("Fix Kubernetes manifest validation errors")
        recommendations+=("Implement pre-commit hooks for YAML validation")
    fi
    
    # General security recommendations
    recommendations+=("Regularly update base container images")
    recommendations+=("Implement vulnerability scanning in CI/CD pipeline")
    recommendations+=("Enable audit logging for all Kubernetes API access")
    recommendations+=("Implement certificate rotation policy")
    recommendations+=("Set up monitoring for security policy violations")
    
    printf '%s\n' "${recommendations[@]}"
}

# Generate comprehensive JSON report
generate_json_report() {
    log_header "Generating Security Report"
    
    mkdir -p "${REPORTS_DIR}"
    
    local total_images
    total_images=$(extract_container_images | wc -l)
    
    local kubeconform_json="[]"
    if [[ "${#KUBECONFORM_RESULTS[@]}" -gt 0 ]]; then
        kubeconform_json="[$(printf '%s,' "${KUBECONFORM_RESULTS[@]}" | sed 's/,$//')]"
    fi
    
    local cosign_json="[]"
    if [[ "${#COSIGN_RESULTS[@]}" -gt 0 ]]; then
        cosign_json="[$(printf '%s,' "${COSIGN_RESULTS[@]}" | sed 's/,$//')]"
    fi
    
    local policy_compliance_json="{}"
    if [[ "${#POLICY_COMPLIANCE_RESULTS[@]}" -gt 0 ]]; then
        policy_compliance_json="${POLICY_COMPLIANCE_RESULTS[0]}"
    fi
    
    local recommendations_json
    recommendations_json=$(generate_recommendations | jq -R . | jq -s .)
    
    local git_commit
    git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    local git_branch
    git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    # Generate comprehensive JSON report
    jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg version "1.0.0" \
        --arg project_root "${PROJECT_ROOT}" \
        --arg git_commit "${git_commit}" \
        --arg git_branch "${git_branch}" \
        --arg security_policy_level "${SECURITY_POLICY_LEVEL}" \
        --arg allow_unsigned "${ALLOW_UNSIGNED}" \
        --arg allowed_registries "${ALLOWED_REGISTRIES}" \
        --argjson total_images "${total_images}" \
        --argjson registry_violations "$(printf '%s\n' "${REGISTRY_VIOLATIONS[@]}" 2>/dev/null | jq -R . | jq -s . || echo '[]')" \
        --argjson signature_issues "$(printf '%s\n' "${SIGNATURE_ISSUES[@]}" 2>/dev/null | jq -R . | jq -s . || echo '[]')" \
        --argjson kubeconform_results "${kubeconform_json}" \
        --argjson cosign_results "${cosign_json}" \
        --argjson policy_compliance "${policy_compliance_json}" \
        --argjson recommendations "${recommendations_json}" \
        '{
            security_report: {
                metadata: {
                    timestamp: $timestamp,
                    version: $version,
                    project_root: $project_root,
                    git: {
                        commit: $git_commit,
                        branch: $git_branch
                    }
                },
                configuration: {
                    security_policy_level: $security_policy_level,
                    allow_unsigned: ($allow_unsigned | test("true")),
                    allowed_registries: ($allowed_registries | split(","))
                },
                summary: {
                    total_images: $total_images,
                    registry_violations: ($registry_violations | length),
                    signature_issues: ($signature_issues | length),
                    kubeconform_files: ($kubeconform_results | length),
                    policy_compliance_score: $policy_compliance.score
                },
                findings: {
                    kubeconform_validation: $kubeconform_results,
                    image_signature_verification: $cosign_results,
                    registry_allowlist_violations: $registry_violations,
                    policy_compliance: $policy_compliance
                },
                recommendations: $recommendations
            }
        }' > "${REPORT_FILE}"
    
    if [[ $? -eq 0 ]]; then
        log_success "Security report generated: ${REPORT_FILE}"
        
        # Create symlink to latest report
        ln -sf "security-${TIMESTAMP}.json" "${REPORTS_DIR}/security-latest.json"
        
        # Display summary
        echo ""
        log_header "Security Report Summary"
        jq -r '.security_report.summary | to_entries[] | "  \(.key | gsub("_"; " ") | ascii_upcase): \(.value)"' "${REPORT_FILE}"
        echo ""
        
        return 0
    else
        log_error "Failed to generate security report"
        return ${EXIT_REPORT_GENERATION_FAILED}
    fi
}

# Main execution
main() {
    local start_time
    start_time=$(date +%s)
    
    log_header "Nephio Intent-to-O2 Demo Security Report"
    log_info "Project root: ${PROJECT_ROOT}"
    log_info "Report file: ${REPORT_FILE}"
    log_info "Security policy level: ${SECURITY_POLICY_LEVEL}"
    log_info "Allow unsigned images: ${ALLOW_UNSIGNED}"
    log_info "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    # Run all security checks
    local exit_code=0
    
    check_dependencies || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Dependency check failed"
        exit ${exit_code}
    fi
    
    install_cosign_if_needed || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Failed to install cosign"
        exit ${exit_code}
    fi
    
    validate_yaml_manifests || exit_code=$?
    # Continue on YAML validation failures for comprehensive reporting
    
    validate_registry_allowlist || {
        local registry_exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            exit_code=${registry_exit_code}
        fi
    }
    
    verify_image_signatures || {
        local signature_exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            exit_code=${signature_exit_code}
        fi
    }
    
    assess_policy_compliance || {
        local compliance_exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            exit_code=${compliance_exit_code}
        fi
    }
    
    generate_json_report || {
        log_error "Report generation failed"
        exit ${EXIT_REPORT_GENERATION_FAILED}
    }
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "Security report completed in ${duration}s"
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "All security checks passed"
    else
        log_error "Security checks failed (exit code: ${exit_code})"
        log_info "Review the detailed report: ${REPORT_FILE}"
    fi
    
    return ${exit_code}
}

# Handle help and version flags
case "${1:-}" in
    -h|--help)
        cat << 'EOF'
Comprehensive Security Report Generator

USAGE:
    ./scripts/security_report.sh [OPTIONS]

DESCRIPTION:
    Generates comprehensive security reports for the Nephio Intent-to-O2 demo
    including kubeconform validation, cosign signature verification, registry
    allowlist checking, and policy compliance assessment.

OPTIONS:
    -h, --help      Show this help message
    --version       Show version information

CONFIGURATION:
    Set environment variables or create .security.conf in project root:

    ALLOWED_REGISTRIES=gcr.io,ghcr.io     Comma-separated allowed registries
    ALLOW_UNSIGNED=false                  Allow unsigned images (dev mode)
    SECURITY_POLICY_LEVEL=strict          Security enforcement level
    COSIGN_TIMEOUT=30                     Cosign verification timeout (seconds)
    PARALLEL_SCANS=4                      Parallel image scans
    AUTO_INSTALL_COSIGN=false             Auto-install cosign in CI

EXIT CODES:
    0   Success
    1   Validation failed
    2   Signature missing
    3   Registry violation
    4   Dependencies missing
    5   Report generation failed

EXAMPLES:
    # Basic usage
    ./scripts/security_report.sh

    # Development mode (allow unsigned)
    ALLOW_UNSIGNED=true ./scripts/security_report.sh

    # Strict production mode
    SECURITY_POLICY_LEVEL=strict ./scripts/security_report.sh

    # CI mode with auto-install
    AUTO_INSTALL_COSIGN=true ./scripts/security_report.sh
EOF
        exit 0
        ;;
    --version)
        echo "Comprehensive Security Report Generator v1.0.0"
        echo "Part of Nephio Intent-to-O2 Demo Pipeline"
        exit 0
        ;;
esac

# Execute main function
main "$@"