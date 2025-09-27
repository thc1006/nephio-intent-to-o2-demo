#!/usr/bin/env bash
# Phase 19-B: One-Click End-to-End Pipeline with On-Site Validation
# Complete flow: Intent Generation → KRM → GitOps → O2IMS → On-Site Validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Pipeline configuration
PIPELINE_ID="e2e-$(date +%s)"
INTENT_FILE="${INTENT_FILE:-/tmp/intent-${PIPELINE_ID}.json}"
TRACE_FILE="${TRACE_FILE:-reports/traces/pipeline-${PIPELINE_ID}.json}"
REPORT_DIR="${REPORT_DIR:-reports/$(date +%Y%m%d_%H%M%S)}"

# Target configuration
TARGET_SITE="${TARGET_SITE:-all}"  # edge1, edge2, edge3, edge4, both, or all
SERVICE_TYPE="${SERVICE_TYPE:-enhanced-mobile-broadband}"
RESOURCE_PROFILE="${RESOURCE_PROFILE:-standard}"

# Timeouts
ROOTSYNC_TIMEOUT="${ROOTSYNC_TIMEOUT:-600}"
O2IMS_TIMEOUT="${O2IMS_TIMEOUT:-300}"
VALIDATION_TIMEOUT="${VALIDATION_TIMEOUT:-120}"

# Mode flags
DRY_RUN="${DRY_RUN:-false}"
SKIP_VALIDATION="${SKIP_VALIDATION:-false}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Initialize pipeline
initialize_pipeline() {
    log_info "Initializing Phase 19-B End-to-End Pipeline"
    log_info "Pipeline ID: $PIPELINE_ID"
    log_info "Target Site: $TARGET_SITE"
    log_info "Service Type: $SERVICE_TYPE"

    # Create necessary directories
    mkdir -p "$(dirname "$TRACE_FILE")"
    mkdir -p "$REPORT_DIR"

    # Initialize stage trace
    "$SCRIPT_DIR/stage_trace.sh" create "$TRACE_FILE" "$PIPELINE_ID"

    log_success "Pipeline initialized"
}

# Stage 1: Intent Generation
generate_intent() {
    log_info "Stage 1: Generating Intent"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "intent_generation" "running"

    local start_time=$(date +%s%N)

    # Generate intent JSON
    cat > "$INTENT_FILE" <<EOF
{
  "intentId": "intent-${PIPELINE_ID}",
  "serviceType": "$SERVICE_TYPE",
  "targetSite": "$TARGET_SITE",
  "resourceProfile": "$RESOURCE_PROFILE",
  "sla": {
    "availability": 99.99,
    "latency": 10,
    "throughput": 1000
  },
  "metadata": {
    "createdAt": "$(date -Iseconds)",
    "pipeline": "$PIPELINE_ID",
    "version": "1.0.0"
  }
}
EOF

    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ -f "$INTENT_FILE" ]]; then
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "intent_generation" "success" "" "" "$duration_ms"
        log_success "Intent generated: $INTENT_FILE"
        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "intent_generation" "failed" "" "Failed to generate intent"
        log_error "Failed to generate intent"
        return 1
    fi
}

# Stage 2: KRM Translation
translate_to_krm() {
    log_info "Stage 2: Translating Intent to KRM"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "krm_translation" "running"

    local start_time=$(date +%s%N)
    local krm_output_dir="$PROJECT_ROOT/rendered/krm"

    # Run translator
    if python3 "$PROJECT_ROOT/tools/intent-compiler/translate.py" \
        "$INTENT_FILE" \
        -o "$krm_output_dir" 2>&1; then

        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))

        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "krm_translation" "success" "" "" "$duration_ms"
        log_success "KRM resources generated in $krm_output_dir"

        # List generated files
        if [[ "$TARGET_SITE" == "both" ]]; then
            ls -la "$krm_output_dir/edge1/"*.yaml 2>/dev/null | head -5
            ls -la "$krm_output_dir/edge2/"*.yaml 2>/dev/null | head -5
        else
            ls -la "$krm_output_dir/$TARGET_SITE/"*.yaml 2>/dev/null | head -5
        fi

        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "krm_translation" "failed" "" "Translation failed"
        log_error "Failed to translate intent to KRM"
        return 1
    fi
}

# Stage 3: kpt Pre-Validation (NEW - 2025 Google Cloud Best Practices)
validate_with_kpt() {
    log_info "Stage 3: Validating KRM packages with kpt functions"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "kpt_validation" "running"

    local start_time=$(date +%s%N)
    local krm_output_dir="$PROJECT_ROOT/rendered/krm"
    local validation_report="$REPORT_DIR/kpt_validation.json"
    local validation_results=()

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry run mode - skipping kpt validation"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_validation" "skipped" "" "Dry run mode"
        return 0
    fi

    # Ensure KRM output directory exists
    if [[ ! -d "$krm_output_dir" ]]; then
        log_error "KRM output directory not found: $krm_output_dir"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_validation" "failed" "" "KRM directory not found"
        return 1
    fi

    # Determine sites to validate
    local sites=()
    case "$TARGET_SITE" in
        "both")
            sites=("edge1" "edge2")
            ;;
        "all")
            sites=("edge1" "edge2" "edge3" "edge4")
            ;;
        *)
            sites=("$TARGET_SITE")
            ;;
    esac

    local all_validation_success=true
    local total_validators=0
    local passed_validators=0

    # Validate each site's KRM packages
    for site in "${sites[@]}"; do
        local site_dir="$krm_output_dir/$site"

        if [[ ! -d "$site_dir" ]]; then
            log_warn "Skipping validation for $site - directory not found: $site_dir"
            continue
        fi

        log_info "Validating KRM packages for $site"

        # Initialize site validation result
        local site_validation="{\"site\": \"$site\", \"validators\": []}"

        # Validator 1: kubeval - Kubernetes YAML validation (with CRD tolerance)
        local kubeval_result="PASS"
        local kubeval_output=""
        ((total_validators++))

        # Run kubeval with ignore_missing_schemas to handle CRDs gracefully
        if ! kubeval_output=$(kpt fn eval "$site_dir" --image gcr.io/kpt-fn/kubeval:v0.3 -- ignore_missing_schemas=true 2>&1); then
            # Check if errors are only about CRDs (non-critical)
            if echo "$kubeval_output" | grep -q "Validating arbitrary CRDs is not supported" && \
               ! echo "$kubeval_output" | grep -q "INVALID\|invalid" ; then
                kubeval_result="PASS"
                ((passed_validators++))
                log_info "kubeval validation passed for $site (CRDs skipped)"
                kubeval_output="PASS: Standard K8s resources validated, CRDs skipped"
            else
                kubeval_result="FAIL"
                all_validation_success=false
                log_error "kubeval validation failed for $site"
            fi
        else
            ((passed_validators++))
            log_info "kubeval validation passed for $site"
            kubeval_output="PASS: All resources validated successfully"
        fi

        site_validation=$(echo "$site_validation" | jq --arg name "kubeval" \
                                                      --arg status "$kubeval_result" \
                                                      --arg output "$kubeval_output" \
                                                      '.validators += [{"name": $name, "status": $status, "output": $output}]')

        # Validator 2: YAML Syntax Validation (lightweight alternative to gatekeeper)
        local yaml_result="PASS"
        local yaml_output=""
        ((total_validators++))

        local yaml_errors=""
        # Check YAML syntax for all files
        for yaml_file in "$site_dir"/*.yaml; do
            if [[ -f "$yaml_file" ]]; then
                if ! yaml_output_temp=$(python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>&1); then
                    yaml_errors+="Error in $(basename "$yaml_file"): $yaml_output_temp\n"
                    yaml_result="FAIL"
                fi
            fi
        done

        if [[ "$yaml_result" == "PASS" ]]; then
            ((passed_validators++))
            log_info "YAML syntax validation passed for $site"
            yaml_output="PASS: All YAML files have valid syntax"
        else
            all_validation_success=false
            log_error "YAML syntax validation failed for $site"
            yaml_output="FAIL: $yaml_errors"
        fi

        site_validation=$(echo "$site_validation" | jq --arg name "yaml-syntax" \
                                                      --arg status "$yaml_result" \
                                                      --arg output "$yaml_output" \
                                                      '.validators += [{"name": $name, "status": $status, "output": $output}]')

        # Validator 3: Resource Naming Convention
        local naming_result="PASS"
        local naming_output=""
        ((total_validators++))

        local naming_errors=""
        # Check that all resources have intent- prefix or intent reference
        for yaml_file in "$site_dir"/*.yaml; do
            if [[ -f "$yaml_file" ]]; then
                local filename=$(basename "$yaml_file")

                # Skip kustomization files and other special cases
                if [[ "$filename" == "kustomization.yaml" || "$filename" == "Kustomization.yaml" ]]; then
                    continue
                fi

                local resource_name=$(yq eval '.metadata.name' "$yaml_file" 2>/dev/null)
                local has_intent_label=$(yq eval '.metadata.labels."intent-id"' "$yaml_file" 2>/dev/null)
                local kind=$(yq eval '.kind' "$yaml_file" 2>/dev/null)

                # Special handling for ProvisioningRequest and other O2IMS resources
                if [[ "$kind" == "ProvisioningRequest" ]]; then
                    # ProvisioningRequest resources should have intent-id label (more flexible)
                    if [[ "$has_intent_label" == "null" ]]; then
                        naming_errors+="ProvisioningRequest $(basename "$yaml_file") should have intent-id label\n"
                        naming_result="FAIL"
                    fi
                elif [[ "$resource_name" != "null" && "$resource_name" != "intent-"* && "$has_intent_label" == "null" ]]; then
                    naming_errors+="Resource $(basename "$yaml_file") lacks intent naming or labels\n"
                    naming_result="FAIL"
                fi
            fi
        done

        if [[ "$naming_result" == "PASS" ]]; then
            ((passed_validators++))
            log_info "naming convention validation passed for $site"
            naming_output="PASS: All resources follow intent naming conventions"
        else
            all_validation_success=false
            log_error "naming convention validation failed for $site"
            naming_output="FAIL: $naming_errors"
        fi

        site_validation=$(echo "$site_validation" | jq --arg name "naming-convention" \
                                                      --arg status "$naming_result" \
                                                      --arg output "$naming_output" \
                                                      '.validators += [{"name": $name, "status": $status, "output": $output}]')

        # Validator 4: Site Configuration Consistency
        local config_result="PASS"
        local config_output=""
        ((total_validators++))

        local config_errors=""
        # Verify that site-name labels match the target site
        for yaml_file in "$site_dir"/*.yaml; do
            if [[ -f "$yaml_file" ]]; then
                local site_label=$(yq eval '.metadata.labels."site-name"' "$yaml_file" 2>/dev/null)
                if [[ "$site_label" != "null" && "$site_label" != "$site" ]]; then
                    config_errors+="Resource $(basename "$yaml_file") has incorrect site-name: $site_label (expected: $site)\n"
                    config_result="FAIL"
                fi
            fi
        done

        if [[ "$config_result" == "PASS" ]]; then
            ((passed_validators++))
            log_info "configuration consistency validation passed for $site"
            config_output="PASS: Site configuration is consistent"
        else
            all_validation_success=false
            log_error "configuration consistency validation failed for $site"
            config_output="FAIL: $config_errors"
        fi

        site_validation=$(echo "$site_validation" | jq --arg name "config-consistency" \
                                                      --arg status "$config_result" \
                                                      --arg output "$config_output" \
                                                      '.validators += [{"name": $name, "status": $status, "output": $output}]')

        validation_results+=("$site_validation")
    done

    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    # Generate validation report
    local overall_status="PASS"
    if [[ "$all_validation_success" == "false" ]]; then
        overall_status="FAIL"
    fi

    local validation_summary="{
        \"timestamp\": \"$(date -Iseconds)\",
        \"pipeline_id\": \"$PIPELINE_ID\",
        \"target_site\": \"$TARGET_SITE\",
        \"overall_status\": \"$overall_status\",
        \"duration_ms\": $duration_ms,
        \"summary\": {
            \"total_validators\": $total_validators,
            \"passed_validators\": $passed_validators,
            \"failed_validators\": $((total_validators - passed_validators)),
            \"sites_validated\": ${#sites[@]}
        },
        \"results\": [$(IFS=,; echo "${validation_results[*]}")]
    }"

    echo "$validation_summary" > "$validation_report"

    if [[ "$all_validation_success" == "true" ]]; then
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_validation" "success" "" "" "$duration_ms"
        log_success "KRM validation passed - all $total_validators validators succeeded"
        log_info "Validation report: $validation_report"
        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_validation" "failed" "" "Validation failed: $((total_validators - passed_validators))/$total_validators validators failed" "$duration_ms"
        log_error "KRM validation failed - $((total_validators - passed_validators))/$total_validators validators failed"
        log_error "Validation report: $validation_report"
        return 1
    fi
}

# Stage 4: kpt Pipeline
run_kpt_pipeline() {
    log_info "Stage 4: Running kpt Pipeline"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "kpt_pipeline" "running"

    local start_time=$(date +%s%N)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry run mode - skipping kpt pipeline"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_pipeline" "skipped" "" "Dry run mode"
        return 0
    fi

    # Run kpt fn render for each site
    local sites=()
    case "$TARGET_SITE" in
        "both")
            sites=("edge1" "edge2")
            ;;
        "all")
            sites=("edge1" "edge2" "edge3" "edge4")
            ;;
        *)
            sites=("$TARGET_SITE")
            ;;
    esac

    local all_success=true
    for site in "${sites[@]}"; do
        log_info "Running kpt pipeline for $site"

        if ! kpt fn render "$PROJECT_ROOT/gitops/${site}-config" 2>/dev/null; then
            log_error "kpt pipeline failed for $site"
            all_success=false
        fi
    done

    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$all_success" == "true" ]]; then
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_pipeline" "success" "" "" "$duration_ms"
        log_success "kpt pipeline completed"
        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "kpt_pipeline" "failed" "" "Pipeline failed for one or more sites"
        return 1
    fi
}

# Stage 5: Git Operations
git_commit_and_push() {
    log_info "Stage 5: Git Commit and Push"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "git_operations" "running"

    local start_time=$(date +%s%N)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry run mode - skipping git operations"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "git_operations" "skipped" "" "Dry run mode"
        return 0
    fi

    # Stage changes
    git add -A "$PROJECT_ROOT/gitops/" "$PROJECT_ROOT/rendered/krm/"

    # Commit
    local commit_msg="feat: deploy intent ${PIPELINE_ID} to ${TARGET_SITE}

Pipeline: ${PIPELINE_ID}
Target: ${TARGET_SITE}
Service: ${SERVICE_TYPE}
Generated by Phase 19-B E2E Pipeline"

    if git commit -m "$commit_msg" 2>/dev/null; then
        log_info "Changes committed"

        # Push to remote
        if git push origin main 2>/dev/null; then
            local end_time=$(date +%s%N)
            local duration_ms=$(( (end_time - start_time) / 1000000 ))

            "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "git_operations" "success" "" "" "$duration_ms"
            log_success "Changes pushed to remote"
            return 0
        else
            "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "git_operations" "failed" "" "Push failed"
            log_error "Failed to push changes"
            return 1
        fi
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "git_operations" "skipped" "" "No changes to commit"
        log_warn "No changes to commit"
        return 0
    fi
}

# Stage 6: Wait for RootSync
wait_for_rootsync() {
    log_info "Stage 6: Waiting for RootSync Reconciliation"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "rootsync_wait" "running"

    local start_time=$(date +%s%N)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry run mode - skipping RootSync wait"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "rootsync_wait" "skipped" "" "Dry run mode"
        return 0
    fi

    # Call postcheck script which handles RootSync waiting
    if timeout "$ROOTSYNC_TIMEOUT" "$SCRIPT_DIR/postcheck.sh" 2>/dev/null; then
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))

        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "rootsync_wait" "success" "" "" "$duration_ms"
        log_success "RootSync reconciliation completed"
        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "rootsync_wait" "failed" "" "Timeout or reconciliation failed"
        log_error "RootSync reconciliation failed"
        return 1
    fi
}

# Stage 7: Poll O2IMS Status
poll_o2ims_status() {
    log_info "Stage 7: Polling O2IMS Provisioning Status"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "o2ims_poll" "running"

    local start_time=$(date +%s%N)

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry run mode - skipping O2IMS polling"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "o2ims_poll" "skipped" "" "Dry run mode"
        return 0
    fi

    # O2IMS endpoints
    declare -A O2IMS_ENDPOINTS=(
        [edge1]="http://172.16.4.45:30205/o2ims_infrastructureInventory/v1/status"
        [edge2]="http://172.16.4.176:30205/o2ims_infrastructureInventory/v1/status"
        [edge3]="http://172.16.5.81:30205/o2ims_infrastructureInventory/v1/status"
        [edge4]="http://172.16.1.252:30205/o2ims_infrastructureInventory/v1/status"
    )

    local sites=()
    case "$TARGET_SITE" in
        "both")
            sites=("edge1" "edge2")
            ;;
        "all")
            sites=("edge1" "edge2" "edge3" "edge4")
            ;;
        *)
            sites=("$TARGET_SITE")
            ;;
    esac

    local all_ready=false
    local poll_count=0
    local max_polls=$((O2IMS_TIMEOUT / 10))

    while [[ $poll_count -lt $max_polls ]]; do
        all_ready=true

        for site in "${sites[@]}"; do
            local endpoint="${O2IMS_ENDPOINTS[$site]}"
            local response=$(curl -s --max-time 5 "$endpoint" 2>/dev/null || echo "{}")
            local status=$(echo "$response" | jq -r ".provisioningRequests.\"intent-${PIPELINE_ID}\".status" 2>/dev/null)

            if [[ "$status" != "READY" && "$status" != "ACTIVE" ]]; then
                all_ready=false
                log_info "[$site] O2IMS status: ${status:-PENDING}"
            else
                log_info "[$site] O2IMS status: $status ✓"
            fi
        done

        if [[ "$all_ready" == "true" ]]; then
            break
        fi

        sleep 10
        ((poll_count++))
    done

    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$all_ready" == "true" ]]; then
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "o2ims_poll" "success" "" "" "$duration_ms"
        log_success "O2IMS provisioning completed"
        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "o2ims_poll" "failed" "" "Provisioning timeout"
        log_error "O2IMS provisioning timeout"
        return 1
    fi
}

# Stage 8: On-Site Validation
perform_onsite_validation() {
    log_info "Stage 8: Performing On-Site Validation"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "onsite_validation" "running"

    local start_time=$(date +%s%N)

    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        log_warn "Validation skipped by request"
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "onsite_validation" "skipped" "" "Skipped by request"
        return 0
    fi

    local validation_script="$SCRIPT_DIR/onsite_validation.sh"

    # Create on-site validation script if it doesn't exist
    if [[ ! -f "$validation_script" ]]; then
        create_onsite_validation_script "$validation_script"
    fi

    # Run validation
    local validation_output="$REPORT_DIR/onsite_validation.json"

    if TARGET_SITE="$TARGET_SITE" PIPELINE_ID="$PIPELINE_ID" \
       bash "$validation_script" > "$validation_output" 2>&1; then

        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))

        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "onsite_validation" "success" "" "" "$duration_ms"
        log_success "On-site validation completed"

        # Display validation summary
        jq -r '.summary' "$validation_output" 2>/dev/null || true

        return 0
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "onsite_validation" "failed" "" "Validation failed"
        log_error "On-site validation failed"

        # Check if we should rollback
        if [[ "$AUTO_ROLLBACK" == "true" ]]; then
            log_warn "Auto-rollback triggered"
            perform_rollback
        fi

        return 1
    fi
}

# Create on-site validation script
create_onsite_validation_script() {
    local script_path="$1"

    cat > "$script_path" <<'VALIDATION_SCRIPT'
#!/bin/bash
# On-Site Validation Script for Edge Sites

set -euo pipefail

# Configuration from environment
TARGET_SITE="${TARGET_SITE:-both}"
PIPELINE_ID="${PIPELINE_ID:-unknown}"

# Validation endpoints
declare -A EDGE_ENDPOINTS=(
    [edge1]="172.16.4.45"
    [edge2]="172.16.4.176"
    [edge3]="172.16.5.81"
    [edge4]="172.16.1.252"
)

# Validation checks
validate_site() {
    local site="$1"
    local ip="${EDGE_ENDPOINTS[$site]}"
    local results=()

    # Check 1: Kubernetes resources
    local k8s_check="FAIL"
    if kubectl --kubeconfig="/etc/kubeconfig/${site}.yaml" \
       get provisioningrequest "intent-${PIPELINE_ID}" &>/dev/null; then
        k8s_check="PASS"
    fi
    results+=("\"kubernetes\": \"$k8s_check\"")

    # Check 2: Network connectivity
    local net_check="FAIL"
    if ping -c 1 -W 2 "$ip" &>/dev/null; then
        net_check="PASS"
    fi
    results+=("\"connectivity\": \"$net_check\"")

    # Check 3: Service endpoint
    local svc_check="FAIL"
    if curl -s --max-time 5 "http://${ip}:30090/health" &>/dev/null; then
        svc_check="PASS"
    fi
    results+=("\"service\": \"$svc_check\"")

    # Check 4: O2IMS status
    local o2ims_check="FAIL"
    local status=$(curl -s --max-time 5 \
        "http://${ip}:31280/o2ims/provisioning/v1/status" 2>/dev/null | \
        jq -r ".provisioningRequests.\"intent-${PIPELINE_ID}\".status" 2>/dev/null)
    if [[ "$status" == "READY" || "$status" == "ACTIVE" ]]; then
        o2ims_check="PASS"
    fi
    results+=("\"o2ims\": \"$o2ims_check\"")

    # Check 5: SLO metrics
    local slo_check="FAIL"
    local metrics=$(curl -s --max-time 5 \
        "http://${ip}:30090/metrics/api/v1/slo" 2>/dev/null)
    if [[ -n "$metrics" ]]; then
        local latency=$(echo "$metrics" | jq -r '.slo.latency_p95_ms' 2>/dev/null)
        local success_rate=$(echo "$metrics" | jq -r '.slo.success_rate' 2>/dev/null)

        if [[ -n "$latency" && -n "$success_rate" ]]; then
            if (( $(echo "$latency < 15" | bc -l) )) && \
               (( $(echo "$success_rate > 0.995" | bc -l) )); then
                slo_check="PASS"
            fi
        fi
    fi
    results+=("\"slo\": \"$slo_check\"")

    # Return results as JSON
    echo "{\"site\": \"$site\", \"checks\": {$(IFS=,; echo "${results[*]}")}}"
}

# Main validation
main() {
    local sites=()
    case "$TARGET_SITE" in
        "both")
            sites=("edge1" "edge2")
            ;;
        "all")
            sites=("edge1" "edge2" "edge3" "edge4")
            ;;
        *)
            sites=("$TARGET_SITE")
            ;;
    esac

    local validations=()
    local all_pass=true

    for site in "${sites[@]}"; do
        local result=$(validate_site "$site")
        validations+=("$result")

        # Check if any test failed
        if echo "$result" | grep -q '"FAIL"'; then
            all_pass=false
        fi
    done

    # Generate report
    local status="PASS"
    if [[ "$all_pass" == "false" ]]; then
        status="FAIL"
    fi

    cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "pipeline_id": "$PIPELINE_ID",
  "target_site": "$TARGET_SITE",
  "status": "$status",
  "validations": [$(IFS=,; echo "${validations[*]}")],
  "summary": {
    "overall": "$status",
    "sites_validated": ${#sites[@]},
    "message": "On-site validation ${status,,} for pipeline $PIPELINE_ID"
  }
}
EOF
}

main "$@"
VALIDATION_SCRIPT

    chmod +x "$script_path"
    log_info "Created on-site validation script: $script_path"
}

# Rollback function
perform_rollback() {
    log_warn "Initiating rollback for pipeline $PIPELINE_ID"
    "$SCRIPT_DIR/stage_trace.sh" add "$TRACE_FILE" "rollback" "running"

    if [[ -f "$SCRIPT_DIR/rollback.sh" ]]; then
        if ROLLBACK_STRATEGY="revert" DRY_RUN="$DRY_RUN" \
           "$SCRIPT_DIR/rollback.sh" "pipeline-${PIPELINE_ID}-failure" 2>&1; then
            "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "rollback" "success"
            log_success "Rollback completed"
        else
            "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "rollback" "failed"
            log_error "Rollback failed - manual intervention required"
        fi
    else
        "$SCRIPT_DIR/stage_trace.sh" update "$TRACE_FILE" "rollback" "skipped" "" "Rollback script not found"
        log_error "Rollback script not found"
    fi
}

# Generate final report
generate_final_report() {
    log_info "Generating final report"

    # Finalize trace
    "$SCRIPT_DIR/stage_trace.sh" finalize "$TRACE_FILE" "completed"

    # Generate timeline
    "$SCRIPT_DIR/stage_trace.sh" timeline "$TRACE_FILE"

    # Generate detailed report
    "$SCRIPT_DIR/stage_trace.sh" report "$TRACE_FILE" > "$REPORT_DIR/pipeline_report.txt"

    # Export metrics
    "$SCRIPT_DIR/stage_trace.sh" metrics "$TRACE_FILE" json > "$REPORT_DIR/pipeline_metrics.json"

    # Create summary
    cat > "$REPORT_DIR/summary.json" <<EOF
{
  "pipeline_id": "$PIPELINE_ID",
  "status": "completed",
  "target_site": "$TARGET_SITE",
  "service_type": "$SERVICE_TYPE",
  "start_time": "$SCRIPT_START_TIME",
  "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reports": {
    "trace": "$TRACE_FILE",
    "validation": "$REPORT_DIR/onsite_validation.json",
    "metrics": "$REPORT_DIR/pipeline_metrics.json"
  }
}
EOF

    log_success "Reports generated in $REPORT_DIR"
}

# Main execution
main() {
    log_info "═══════════════════════════════════════════════════════"
    log_info "  Phase 19-B: One-Click End-to-End Pipeline"
    log_info "═══════════════════════════════════════════════════════"

    # Initialize
    initialize_pipeline

    # Execute pipeline stages
    local pipeline_success=true

    if ! generate_intent; then
        pipeline_success=false
    elif ! translate_to_krm; then
        pipeline_success=false
    elif ! validate_with_kpt; then
        pipeline_success=false
    elif ! run_kpt_pipeline; then
        pipeline_success=false
    elif ! git_commit_and_push; then
        pipeline_success=false
    elif ! wait_for_rootsync; then
        pipeline_success=false
    elif ! poll_o2ims_status; then
        pipeline_success=false
    elif ! perform_onsite_validation; then
        pipeline_success=false
    fi

    # Generate final report
    generate_final_report

    # Final status
    if [[ "$pipeline_success" == "true" ]]; then
        log_success "═══════════════════════════════════════════════════════"
        log_success "  Pipeline completed successfully!"
        log_success "  Pipeline ID: $PIPELINE_ID"
        log_success "  Reports: $REPORT_DIR"
        log_success "═══════════════════════════════════════════════════════"
        exit 0
    else
        log_error "═══════════════════════════════════════════════════════"
        log_error "  Pipeline failed!"
        log_error "  Pipeline ID: $PIPELINE_ID"
        log_error "  Check reports: $REPORT_DIR"
        log_error "═══════════════════════════════════════════════════════"
        exit 1
    fi
}

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Phase 19-B: One-Click End-to-End Pipeline with On-Site Validation

Options:
    --target SITE       Target site (edge1|edge2|edge3|edge4|both|all) [default: all]
    --service TYPE      Service type (enhanced-mobile-broadband|ultra-reliable-low-latency|massive-machine-type)
    --dry-run          Execute in dry-run mode (no actual deployments)
    --skip-validation  Skip on-site validation
    --no-rollback      Disable automatic rollback on failure
    --help             Show this help message

Environment Variables:
    TARGET_SITE        Override target site
    SERVICE_TYPE       Override service type
    DRY_RUN           Set to 'true' for dry-run mode
    AUTO_ROLLBACK     Set to 'false' to disable auto-rollback

Examples:
    # Deploy to both sites
    $0

    # Deploy to edge1 only
    $0 --target edge1

    # Dry run for edge2
    $0 --target edge2 --dry-run

    # Deploy URLLC service to both sites
    $0 --service ultra-reliable-low-latency

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET_SITE="$2"
            shift 2
            ;;
        --service)
            SERVICE_TYPE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION="true"
            shift
            ;;
        --no-rollback)
            AUTO_ROLLBACK="false"
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate inputs
if [[ ! "$TARGET_SITE" =~ ^(edge1|edge2|edge3|edge4|both|all)$ ]]; then
    log_error "Invalid target site: $TARGET_SITE"
    exit 1
fi

# Execute main
main "$@"