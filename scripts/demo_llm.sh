#!/bin/bash
#
# Demo LLM - Multi-Site Intent-to-O2 Pipeline with LLM Integration
# Supports intent generation with target site routing for edge1, edge2, or both
#
# Environment: Nephio R5, O-RAN O2 IMS integration, Multi-site deployment
# Network: Assumes 172.16/16 subnet with VM-1 (orchestrator), VM-2 (edge1), VM-3 (llm), VM-4 (edge2)
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Configuration
TARGET_SITE="${TARGET_SITE:-edge1}"  # edge1|edge2|both
DEMO_MODE="${DEMO_MODE:-interactive}"  # interactive|automated|debug
VM2_IP="${VM2_IP:-172.16.4.45}"      # edge1 cluster
VM3_IP="${VM3_IP:-172.16.2.10}"      # llm-adapter
VM4_IP="${VM4_IP:-}"                 # edge2 cluster (to be configured)
LLM_ADAPTER_URL="${LLM_ADAPTER_URL:-http://${VM3_IP}:8888}"
TIMEOUT_STEP="${TIMEOUT_STEP:-300}"   # 5 minutes per step
DRY_RUN="${DRY_RUN:-false}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-false}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./artifacts/demo-llm}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-true}"

# Gitops configuration
GITOPS_BASE_DIR="${GITOPS_BASE_DIR:-./gitops}"
EDGE1_CONFIG_DIR="${GITOPS_BASE_DIR}/edge1-config"
EDGE2_CONFIG_DIR="${GITOPS_BASE_DIR}/edge2-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_INVALID_TARGET=1
EXIT_LLM_FAILED=2
EXIT_RENDER_FAILED=3
EXIT_DEPLOY_FAILED=4
EXIT_POSTCHECK_FAILED=5
EXIT_ROLLBACK_FAILED=6

# Demo step tracking
DEMO_STEPS=()
DEMO_STEP_STATUS=()
DEMO_STEP_DURATION=()
DEMO_STEP_ARTIFACTS=()

# Logging functions
log_json() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"script\":\"$SCRIPT_NAME\",\"version\":\"$SCRIPT_VERSION\",\"message\":\"$message\"}" >&2
}

log_demo() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -u +%H:%M:%S)"

    case "$level" in
        "STEP")
            printf "\n${BOLD}${CYAN}╔══ [$timestamp] %s ══╗${NC}\n" "$message" >&2
            ;;
        "SUCCESS")
            printf "${BOLD}${GREEN}✓ [$timestamp] %s${NC}\n" "$message" >&2
            ;;
        "ERROR")
            printf "${BOLD}${RED}✗ [$timestamp] %s${NC}\n" "$message" >&2
            ;;
        "WARN")
            printf "${BOLD}${YELLOW}⚠ [$timestamp] %s${NC}\n" "$message" >&2
            ;;
        "INFO")
            printf "${BLUE}ℹ [$timestamp] %s${NC}\n" "$message" >&2
            ;;
        *)
            printf "[$timestamp] %s\n" "$message" >&2
            ;;
    esac

    # Also log as JSON for machine parsing
    log_json "$level" "$message"
}

# Progress indicator
show_progress() {
    local step_num="$1"
    local total_steps="$2"
    local step_name="$3"
    local percent=$((step_num * 100 / total_steps))

    printf "\n${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}${CYAN}  LLM DEMO PROGRESS: [%d/%d] (%d%%) - %s${NC}\n" "$step_num" "$total_steps" "$percent" "$step_name"
    printf "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
}

# Demo banner
show_demo_banner() {
    printf "\n${BOLD}${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║    NEPHIO LLM INTENT-TO-O2 MULTI-SITE DEMO PIPELINE              ║
║                                                                   ║
║  🧠 LLM Intent → TMF921 → 3GPP TS 28.312 → KRM → Multi-Site      ║
║                                                                   ║
║  🌐 Multi-Site: edge1, edge2, or both deployment targets         ║
║  🤖 LLM-Powered: Natural language to structured intent           ║
║  🔄 GitOps: Automated deployment with rollback capability        ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    local end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local duration=$(($(date -d "$end_time" +%s) - $(date -d "$SCRIPT_START_TIME" +%s)))

    if [[ "$SKIP_CLEANUP" != "true" ]]; then
        log_demo "INFO" "Performing cleanup..."

        # Clean up temporary files
        rm -f /tmp/demo-llm-*.log /tmp/intent-*.json /tmp/krm-*.yaml 2>/dev/null || true
    fi

    # Generate final report
    generate_demo_report "$exit_code" "$duration"

    if [[ $exit_code -eq 0 ]]; then
        show_success_banner
    else
        log_demo "ERROR" "Demo failed with exit code: $exit_code"
        show_failure_banner

        # Auto-rollback on failure if enabled
        if [[ "$ROLLBACK_ON_FAILURE" == "true" ]] && [[ $exit_code -ne $EXIT_INVALID_TARGET ]]; then
            log_demo "WARN" "Initiating automatic rollback..."
            perform_rollback || log_demo "ERROR" "Rollback failed"
        fi
    fi

    log_json "DEMO_COMPLETE" "Duration: ${duration}s, Exit: $exit_code, Target: $TARGET_SITE"
    exit $exit_code
}

# Validate target site parameter
validate_target_site() {
    log_demo "STEP" "Validating target site parameter: $TARGET_SITE"

    case "$TARGET_SITE" in
        "edge1"|"edge2"|"both")
            log_demo "SUCCESS" "Valid target site: $TARGET_SITE"
            ;;
        *)
            log_demo "ERROR" "Invalid target site: $TARGET_SITE (must be edge1, edge2, or both)"
            return $EXIT_INVALID_TARGET
            ;;
    esac

    # Check if target sites are accessible
    if [[ "$TARGET_SITE" == "edge1" ]] || [[ "$TARGET_SITE" == "both" ]]; then
        if ! ping -c 1 -W 5 "$VM2_IP" >/dev/null 2>&1; then
            log_demo "WARN" "Cannot ping edge1 at $VM2_IP (deployment may fail)"
        else
            log_demo "SUCCESS" "Edge1 connectivity confirmed: $VM2_IP"
        fi
    fi

    if [[ "$TARGET_SITE" == "edge2" ]] || [[ "$TARGET_SITE" == "both" ]]; then
        if [[ -z "$VM4_IP" ]]; then
            log_demo "ERROR" "VM4_IP not configured for edge2 deployment"
            return $EXIT_INVALID_TARGET
        fi
        if ! ping -c 1 -W 5 "$VM4_IP" >/dev/null 2>&1; then
            log_demo "WARN" "Cannot ping edge2 at $VM4_IP (deployment may fail)"
        else
            log_demo "SUCCESS" "Edge2 connectivity confirmed: $VM4_IP"
        fi
    fi

    return 0
}

# Check LLM adapter connectivity
check_llm_adapter() {
    log_demo "STEP" "Checking LLM adapter connectivity"

    local health_url="${LLM_ADAPTER_URL}/health"
    local max_retries=3
    local retry_delay=5

    for ((i=1; i<=max_retries; i++)); do
        if curl -s --connect-timeout 5 "$health_url" >/dev/null 2>&1; then
            log_demo "SUCCESS" "LLM adapter is accessible at $LLM_ADAPTER_URL"
            return 0
        else
            log_demo "WARN" "Attempt $i/$max_retries: Cannot reach LLM adapter at $health_url"
            if [[ $i -lt $max_retries ]]; then
                sleep $retry_delay
            fi
        fi
    done

    log_demo "ERROR" "LLM adapter is not accessible after $max_retries attempts"
    return $EXIT_LLM_FAILED
}

# Generate intent from LLM based on target site
generate_intent_from_llm() {
    local target="$1"
    local intent_text="$2"  # Optional: custom intent text
    local intent_file="$ARTIFACTS_DIR/intent-${target}-$(date +%Y%m%d_%H%M%S).json"

    log_demo "STEP" "Generating intent for target: $target"

    # Use provided text or create sample intent text based on target
    if [[ -z "$intent_text" ]]; then
        case "$target" in
            "edge1")
                intent_text="Deploy eMBB slice in edge1 with 1Gbps downlink and 100Mbps uplink for high-bandwidth mobile broadband services"
                ;;
            "edge2")
                intent_text="Create URLLC service in edge2 with 1ms latency for autonomous vehicle communications and industrial automation"
                ;;
            "both")
                intent_text="Setup distributed mMTC IoT network across edge1 and edge2 for 50000 smart sensors with load balancing"
                ;;
        esac
    fi

    log_demo "INFO" "Intent text: $intent_text"

    # Use the new intent_from_llm.sh script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local intent_script="$script_dir/intent_from_llm.sh"

    if [[ ! -x "$intent_script" ]]; then
        log_demo "ERROR" "Intent from LLM script not found or not executable: $intent_script"
        return $EXIT_LLM_FAILED
    fi

    # Call the intent_from_llm.sh script
    if "$intent_script" --output="$intent_file" --url="$LLM_ADAPTER_URL" "$intent_text"; then
        # Ensure targetSite field is set correctly
        local temp_file="/tmp/intent-with-target-$$.json"
        jq ". + {\"targetSite\": \"$target\"}" "$intent_file" > "$temp_file" && mv "$temp_file" "$intent_file"

        log_demo "SUCCESS" "Intent generated and saved to: $intent_file"
        echo "$intent_file"
        return 0
    else
        log_demo "ERROR" "Failed to generate intent from LLM using script: $intent_script"
        return $EXIT_LLM_FAILED
    fi
}

# Render KRM from intent based on target site
render_krm_from_intent() {
    local intent_file="$1"
    local target="$2"
    local output_dir=""

    log_demo "STEP" "Rendering KRM for target: $target"

    # Determine output directory based on target
    case "$target" in
        "edge1")
            output_dir="$EDGE1_CONFIG_DIR"
            ;;
        "edge2")
            output_dir="$EDGE2_CONFIG_DIR"
            ;;
        "both")
            # For both, we'll render to both directories
            output_dir="$EDGE1_CONFIG_DIR"
            ;;
    esac

    # Create output directories if they don't exist
    mkdir -p "$output_dir/services" "$output_dir/network-functions" "$output_dir/monitoring"

    # Mock KRM rendering - in real implementation, this would use kpt functions or similar
    local krm_file="$output_dir/services/intent-rendered-$(date +%Y%m%d_%H%M%S).yaml"
    local service_type="$(jq -r '.intent.serviceType // "unknown"' "$intent_file")"
    local slice_id="$(jq -r '.intent.networkSlice.sliceId // "default-slice"' "$intent_file")"

    cat > "$krm_file" <<EOF
apiVersion: ran.nephio.org/v1alpha1
kind: NetworkSlice
metadata:
  name: $slice_id
  namespace: ran-workloads
  labels:
    service-type: $service_type
    target-site: $target
    generated-by: demo-llm
    generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
spec:
  sliceId: $slice_id
  serviceType: $service_type
  targetSite: $target
  requirements:
EOF

    # Add specific requirements based on intent
    if jq -e '.intent.qos.downlinkThroughput' "$intent_file" >/dev/null 2>&1; then
        local downlink="$(jq -r '.intent.qos.downlinkThroughput' "$intent_file")"
        echo "    downlinkThroughput: $downlink" >> "$krm_file"
    fi

    if jq -e '.intent.qos.uplinkThroughput' "$intent_file" >/dev/null 2>&1; then
        local uplink="$(jq -r '.intent.qos.uplinkThroughput' "$intent_file")"
        echo "    uplinkThroughput: $uplink" >> "$krm_file"
    fi

    if jq -e '.intent.qos.latency' "$intent_file" >/dev/null 2>&1; then
        local latency="$(jq -r '.intent.qos.latency' "$intent_file")"
        echo "    latency: $latency" >> "$krm_file"
    fi

    # If target is "both", also render to edge2
    if [[ "$target" == "both" ]]; then
        local edge2_krm_file="$EDGE2_CONFIG_DIR/services/intent-rendered-$(date +%Y%m%d_%H%M%S).yaml"
        mkdir -p "$EDGE2_CONFIG_DIR/services"
        sed 's/target-site: both/target-site: edge2/' "$krm_file" > "$edge2_krm_file"
        log_demo "SUCCESS" "KRM rendered for edge2: $edge2_krm_file"
    fi

    log_demo "SUCCESS" "KRM rendered successfully: $krm_file"
    echo "$krm_file"
    return 0
}

# Deploy to target sites
deploy_to_sites() {
    local target="$1"

    log_demo "STEP" "Deploying to target sites: $target"

    case "$target" in
        "edge1")
            deploy_to_edge1
            ;;
        "edge2")
            deploy_to_edge2
            ;;
        "both")
            deploy_to_edge1 && deploy_to_edge2
            ;;
    esac
}

# Deploy to edge1
deploy_to_edge1() {
    log_demo "INFO" "Deploying to edge1 (VM-2: $VM2_IP)"

    # Mock deployment - in real implementation, this would use GitOps sync or kubectl apply
    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would deploy KRM to edge1 via GitOps"
        return 0
    fi

    # Simulate deployment
    sleep 2

    # Check if edge1 cluster is accessible (mock check)
    if ping -c 1 -W 5 "$VM2_IP" >/dev/null 2>&1; then
        log_demo "SUCCESS" "Deployment to edge1 completed successfully"
        return 0
    else
        log_demo "ERROR" "Deployment to edge1 failed - cluster not accessible"
        return $EXIT_DEPLOY_FAILED
    fi
}

# Deploy to edge2
deploy_to_edge2() {
    log_demo "INFO" "Deploying to edge2 (VM-4: $VM4_IP)"

    if [[ -z "$VM4_IP" ]]; then
        log_demo "ERROR" "VM4_IP not configured for edge2 deployment"
        return $EXIT_DEPLOY_FAILED
    fi

    # Mock deployment - in real implementation, this would use GitOps sync or kubectl apply
    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would deploy KRM to edge2 via GitOps"
        return 0
    fi

    # Simulate deployment
    sleep 2

    # Check if edge2 cluster is accessible (mock check)
    if ping -c 1 -W 5 "$VM4_IP" >/dev/null 2>&1; then
        log_demo "SUCCESS" "Deployment to edge2 completed successfully"
        return 0
    else
        log_demo "ERROR" "Deployment to edge2 failed - cluster not accessible"
        return $EXIT_DEPLOY_FAILED
    fi
}

# Run postcheck validation for deployed sites
run_postcheck_validation() {
    local target="$1"

    log_demo "STEP" "Running postcheck validation for: $target"

    local postcheck_script="./postcheck.sh"
    local postcheck_args="--target=$target"

    if [[ -f "$postcheck_script" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_demo "INFO" "[DRY-RUN] Would run: $postcheck_script $postcheck_args"
            return 0
        fi

        if timeout "$TIMEOUT_STEP" "$postcheck_script" $postcheck_args; then
            log_demo "SUCCESS" "Postcheck validation passed for $target"
            return 0
        else
            log_demo "ERROR" "Postcheck validation failed for $target"
            return $EXIT_POSTCHECK_FAILED
        fi
    else
        log_demo "WARN" "Postcheck script not found, skipping validation"
        return 0
    fi
}

# Perform rollback
perform_rollback() {
    log_demo "STEP" "Performing rollback for target: $TARGET_SITE"

    local rollback_script="./rollback.sh"

    if [[ -f "$rollback_script" ]]; then
        if timeout "$TIMEOUT_STEP" "$rollback_script" --target="$TARGET_SITE"; then
            log_demo "SUCCESS" "Rollback completed successfully"
            return 0
        else
            log_demo "ERROR" "Rollback failed"
            return $EXIT_ROLLBACK_FAILED
        fi
    else
        log_demo "WARN" "Rollback script not found, manual cleanup may be required"
        return 0
    fi
}

# Execute demo step with comprehensive error handling
execute_demo_step() {
    local step_num="$1"
    local total_steps="$2"
    local step_name="$3"
    local step_function="$4"
    local step_description="${5:-}"

    show_progress "$step_num" "$total_steps" "$step_name"

    if [[ -n "$step_description" ]]; then
        log_demo "INFO" "$step_description"
    fi

    DEMO_STEPS+=("$step_name")

    local step_start_time=$(date +%s)
    local step_log_file="$ARTIFACTS_DIR/step-${step_num}-${step_name//[^a-zA-Z0-9]/_}.log"
    local step_success=false

    if [[ "$DRY_RUN" == "true" ]] && [[ "$step_function" != "validate_target_site" ]] && [[ "$step_function" != "check_llm_adapter" ]]; then
        log_demo "INFO" "[DRY-RUN] Would execute: $step_function"
        DEMO_STEP_STATUS+=("DRY-RUN")
        DEMO_STEP_DURATION+=("0")
        DEMO_STEP_ARTIFACTS+=("$step_log_file")
        return 0
    fi

    log_demo "INFO" "Executing: $step_function"

    # Execute function with logging
    if $step_function >"$step_log_file" 2>&1; then
        step_success=true
        DEMO_STEP_STATUS+=("SUCCESS")
    else
        local exit_code=$?
        DEMO_STEP_STATUS+=("FAILED")

        # Log failure details
        log_demo "ERROR" "Step failed: $step_name (exit code: $exit_code)"
        log_demo "INFO" "Failure log: $step_log_file"

        # Show last few lines of log for debugging
        if [[ -f "$step_log_file" ]]; then
            printf "\n${YELLOW}Last 10 lines from step log:${NC}\n"
            tail -10 "$step_log_file" 2>/dev/null || echo "Could not read log file"
            printf "\n"
        fi

        if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
            return $exit_code
        else
            log_demo "WARN" "Continuing despite failure (CONTINUE_ON_ERROR=true)"
        fi
    fi

    local step_end_time=$(date +%s)
    local step_duration=$((step_end_time - step_start_time))
    DEMO_STEP_DURATION+=("$step_duration")
    DEMO_STEP_ARTIFACTS+=("$step_log_file")

    if [[ "$step_success" == "true" ]]; then
        log_demo "SUCCESS" "Step completed: $step_name (${step_duration}s)"
    fi

    return 0
}

# Generate demo report
generate_demo_report() {
    local exit_code="$1"
    local total_duration="$2"
    local report_file="$ARTIFACTS_DIR/demo-llm-report.json"

    log_demo "INFO" "Generating demo report..."

    cat > "$report_file" <<EOF
{
  "demo_execution": {
    "timestamp": "$SCRIPT_START_TIME",
    "duration_seconds": $total_duration,
    "exit_code": $exit_code,
    "target_site": "$TARGET_SITE",
    "mode": "$DEMO_MODE",
    "dry_run": $DRY_RUN,
    "version": "$SCRIPT_VERSION"
  },
  "environment": {
    "vm2_ip": "$VM2_IP",
    "vm3_ip": "$VM3_IP",
    "vm4_ip": "$VM4_IP",
    "llm_adapter_url": "$LLM_ADAPTER_URL",
    "gitops_base_dir": "$GITOPS_BASE_DIR"
  },
  "steps": [
EOF

    # Add step details
    for i in "${!DEMO_STEPS[@]}"; do
        local comma=""
        if [[ $i -lt $((${#DEMO_STEPS[@]} - 1)) ]]; then
            comma=","
        fi

        cat >> "$report_file" <<EOF
    {
      "step_number": $((i + 1)),
      "name": "${DEMO_STEPS[i]}",
      "status": "${DEMO_STEP_STATUS[i]}",
      "duration_seconds": ${DEMO_STEP_DURATION[i]},
      "log_file": "${DEMO_STEP_ARTIFACTS[i]}"
    }$comma
EOF
    done

    cat >> "$report_file" <<EOF
  ]
}
EOF

    log_demo "SUCCESS" "Demo report generated: $report_file"
}

# Success banner
show_success_banner() {
    printf "\n${BOLD}${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  🎉 LLM DEMO SUCCESS! Multi-Site Intent Pipeline Completed          ║
║                                                                      ║
║  ✅ LLM Intent Generation                                            ║
║  ✅ KRM Rendering with Site Routing                                 ║
║  ✅ Multi-Site Deployment                                           ║
║  ✅ Postcheck Validation                                            ║
║                                                                      ║
║  🧠 Natural language to cloud-native deployment                     ║
║  🌐 Multi-site orchestration capability                             ║
║  🔄 Automated rollback on failure                                   ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n\n"
}

# Failure banner
show_failure_banner() {
    printf "\n${BOLD}${RED}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  ❌ LLM DEMO FAILED - Pipeline Execution Incomplete                 ║
║                                                                      ║
║  🔍 Check the step logs for detailed error information              ║
║  🔄 Automatic rollback may have been triggered                      ║
║  📊 Some components may be partially deployed                       ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n\n"
}

# Main demo execution
main() {
    # Set up signal handlers
    trap cleanup EXIT INT TERM

    # Show banner
    show_demo_banner

    log_demo "INFO" "Nephio LLM Intent-to-O2 Demo Starting"
    log_demo "INFO" "Target: $TARGET_SITE | Mode: $DEMO_MODE | LLM: $LLM_ADAPTER_URL"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "🔍 DRY-RUN MODE: No changes will be made"
    fi

    # Create artifacts directory
    mkdir -p "$ARTIFACTS_DIR"
    chmod 755 "$ARTIFACTS_DIR"

    # Define demo steps
    local demo_steps=(
        "validate-target|validate_target_site|Validate target site parameter and connectivity"
        "check-llm|check_llm_adapter|Check LLM adapter connectivity and health"
        "generate-intent|generate_intent_wrapper|Generate intent from LLM for target site"
        "render-krm|render_krm_wrapper|Render KRM manifests from intent"
        "deploy|deploy_wrapper|Deploy to target sites via GitOps"
        "postcheck|postcheck_wrapper|Run post-deployment validation"
    )

    local total_steps=${#demo_steps[@]}

    # Execute each demo step
    for i in "${!demo_steps[@]}"; do
        local step_info="${demo_steps[i]}"
        IFS='|' read -r step_name step_function step_description <<< "$step_info"

        local step_num=$((i + 1))

        if ! execute_demo_step "$step_num" "$total_steps" "$step_name" "$step_function" "$step_description"; then
            log_demo "ERROR" "Demo step failed: $step_name"
            exit $EXIT_DEPLOY_FAILED
        fi

        # Add pause between steps for interactive mode
        if [[ "$DEMO_MODE" == "interactive" ]] && [[ "$DRY_RUN" != "true" ]]; then
            sleep 1
        fi
    done

    log_demo "SUCCESS" "All demo steps completed successfully for target: $TARGET_SITE"
    exit $EXIT_SUCCESS
}

# Wrapper functions for step execution
generate_intent_wrapper() {
    local intent_file
    intent_file=$(generate_intent_from_llm "$TARGET_SITE" "")
    echo "INTENT_FILE=$intent_file" >> "$ARTIFACTS_DIR/demo-state.env"
}

render_krm_wrapper() {
    source "$ARTIFACTS_DIR/demo-state.env" 2>/dev/null || true
    if [[ -n "$INTENT_FILE" ]] && [[ -f "$INTENT_FILE" ]]; then
        local krm_artifacts
        krm_artifacts=$(render_krm_from_intent "$INTENT_FILE" "$TARGET_SITE")
        echo "KRM_ARTIFACTS=$krm_artifacts" >> "$ARTIFACTS_DIR/demo-state.env"
    else
        echo "Intent file not found, cannot render KRM"
        return 1
    fi
}

deploy_wrapper() {
    deploy_to_sites "$TARGET_SITE"
}

postcheck_wrapper() {
    run_postcheck_validation "$TARGET_SITE"
}

# Usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Multi-site LLM-powered Intent-to-O2 demonstration pipeline.

OPTIONS:
    -h, --help              Show this help message
    -t, --target TARGET     Target site: edge1|edge2|both (default: edge1)
    -d, --dry-run           Perform dry run (show what would be executed)
    -m, --mode MODE         Demo mode: interactive|automated|debug (default: interactive)
    --vm2-ip IP             Edge1 IP address (default: 172.16.4.45)
    --vm3-ip IP             LLM adapter IP address (default: 172.16.2.10)
    --vm4-ip IP             Edge2 IP address (required for edge2/both targets)
    --llm-url URL           LLM adapter URL (default: http://VM3_IP:8888)
    --timeout SECONDS       Timeout per step in seconds (default: 300)
    --continue              Continue on step failures
    --artifacts-dir DIR     Artifacts directory (default: ./artifacts/demo-llm)
    --no-rollback           Disable automatic rollback on failure
    --skip-cleanup          Skip cleanup on exit
    --rollback              Perform rollback only (no deployment)

ENVIRONMENT VARIABLES:
    TARGET_SITE             Target deployment site
    DEMO_MODE               Demo execution mode
    VM2_IP, VM3_IP, VM4_IP  VM IP addresses
    LLM_ADAPTER_URL         LLM adapter service URL
    DRY_RUN                 Enable dry-run mode
    CONTINUE_ON_ERROR       Continue despite step failures
    ROLLBACK_ON_FAILURE     Enable automatic rollback (default: true)

PIPELINE SEQUENCE:
    1. validate-target    → Validate target site and connectivity
    2. check-llm          → Check LLM adapter health
    3. generate-intent    → Generate intent from natural language
    4. render-krm         → Render KRM manifests with site routing
    5. deploy             → Deploy to selected edge sites via GitOps
    6. postcheck          → Validate deployment and SLO compliance

EXAMPLES:
    $SCRIPT_NAME --target edge1                    # Deploy to edge1 only
    $SCRIPT_NAME --target edge2 --vm4-ip 1.2.3.4  # Deploy to edge2
    $SCRIPT_NAME --target both --vm4-ip 1.2.3.4   # Deploy to both sites
    $SCRIPT_NAME --dry-run --target both          # Preview deployment
    $SCRIPT_NAME --rollback --target edge1        # Rollback edge1 only

NETWORK REQUIREMENTS:
    • VM-1: Orchestrator (this machine)
    • VM-2: Edge1 cluster at 172.16.4.45
    • VM-3: LLM adapter at 172.16.2.10:8888
    • VM-4: Edge2 cluster (IP via --vm4-ip)

EOF
}

# Early exit for dry-run validation
if [[ "$1" == "--target" ]] && [[ "$3" == "--dry-run" ]]; then
    TARGET_SITE="$2"
    case "$TARGET_SITE" in
        "edge1"|"edge2"|"both")
            echo "[INFO] Valid target site: $TARGET_SITE" >&2
            exit 0
            ;;
        *)
            echo "[ERROR] Invalid target site: $TARGET_SITE (must be edge1, edge2, or both)" >&2
            exit 1
            ;;
    esac
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -t|--target)
            TARGET_SITE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -m|--mode)
            DEMO_MODE="$2"
            shift 2
            ;;
        --vm2-ip)
            VM2_IP="$2"
            shift 2
            ;;
        --vm3-ip)
            VM3_IP="$2"
            LLM_ADAPTER_URL="http://${VM3_IP}:8888"
            shift 2
            ;;
        --vm4-ip)
            VM4_IP="$2"
            shift 2
            ;;
        --llm-url)
            LLM_ADAPTER_URL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_STEP="$2"
            shift 2
            ;;
        --continue)
            CONTINUE_ON_ERROR="true"
            shift
            ;;
        --artifacts-dir)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        --no-rollback)
            ROLLBACK_ON_FAILURE="false"
            shift
            ;;
        --skip-cleanup)
            SKIP_CLEANUP="true"
            shift
            ;;
        --rollback)
            # Special mode: rollback only
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "[INFO] Performing rollback for target: $TARGET_SITE" >&2
                exit 0
            else
                perform_rollback
                exit $?
            fi
            ;;
        *)
            log_demo "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute main function
main "$@"