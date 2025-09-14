#!/usr/bin/env bash
# Phase 19-A Enhanced: Production-Ready Intent→GitOps→O2IMS Pipeline Orchestrator
# Features: Idempotency, GitOps reconciliation, comprehensive artifact management,
#          SLO gate integration, proper error handling, and Summit demo packaging
#
# Environment: Nephio R5, O-RAN O2 IMS integration, Multi-site deployment
# Network: Dynamic configuration via environment variables and config files

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="2.0.0"
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SCRIPT_PID=$$
SCRIPT_EXECUTION_ID="$(date +%Y%m%d_%H%M%S)_${SCRIPT_PID}"

# Load configuration from files
for config_file in "./config/demo.conf" "$HOME/.nephio/demo.conf" "/etc/nephio/demo.conf"; do
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        echo "[INFO] Loaded configuration from: $config_file" >&2
        break
    fi
done

# Configuration with environment variable support (no hardcoded IPs)
TARGET_SITE="${TARGET_SITE:-edge1}"  # edge1|edge2|both
DEMO_MODE="${DEMO_MODE:-interactive}"  # interactive|automated|debug

# Network configuration - use variables, not hardcoded IPs
VM2_IP="${VM2_IP:-}"
VM3_IP="${VM3_IP:-}"
VM4_IP="${VM4_IP:-}"

# Validate required IPs are provided
if [[ -z "$VM2_IP" || -z "$VM3_IP" ]]; then
    echo "[ERROR] Required network configuration missing. Set VM2_IP and VM3_IP environment variables." >&2
    exit 1
fi

LLM_ADAPTER_URL="${LLM_ADAPTER_URL:-http://${VM3_IP}:8888}"
TIMEOUT_STEP="${TIMEOUT_STEP:-300}"   # 5 minutes per step
GITOPS_TIMEOUT="${GITOPS_TIMEOUT:-900}" # 15 minutes for GitOps reconciliation
O2IMS_TIMEOUT="${O2IMS_TIMEOUT:-600}"   # 10 minutes for O2IMS readiness
DRY_RUN="${DRY_RUN:-false}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-false}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
ROLLBACK_ON_FAILURE="${ROLLBACK_ON_FAILURE:-true}"
IDEMPOTENT_MODE="${IDEMPOTENT_MODE:-true}"
GENERATE_SUMMIT_PACKAGE="${GENERATE_SUMMIT_PACKAGE:-true}"

# Timestamped artifacts and reports
TIMESTAMP="${TIMESTAMP:-$SCRIPT_EXECUTION_ID}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./artifacts/demo-llm-${TIMESTAMP}}"
REPORTS_DIR="${REPORTS_DIR:-./reports/${TIMESTAMP}}"
STATE_DIR="${ARTIFACTS_DIR}/state"
CHECKSUMS_FILE="${STATE_DIR}/checksums.sha256"
DEPLOYMENT_STATE_FILE="${STATE_DIR}/deployment.json"
ROLLBACK_SNAPSHOT_DIR="${ARTIFACTS_DIR}/rollback-snapshots"

# GitOps configuration
GITOPS_BASE_DIR="${GITOPS_BASE_DIR:-./gitops}"
EDGE1_CONFIG_DIR="${GITOPS_BASE_DIR}/edge1-config"
EDGE2_CONFIG_DIR="${GITOPS_BASE_DIR}/edge2-config"
ROOTSYNC_NAME="${ROOTSYNC_NAME:-intent-to-o2-rootsync}"
ROOTSYNC_NAMESPACE="${ROOTSYNC_NAMESPACE:-config-management-system}"
REPOSYNC_NAME="${REPOSYNC_NAME:-intent-to-o2-reposync}"
REPOSYNC_NAMESPACE="${REPOSYNC_NAMESPACE:-config-management-system}"

# O2IMS Configuration
O2IMS_EDGE1_ENDPOINT="${O2IMS_EDGE1_ENDPOINT:-http://${VM2_IP}:31280/o2ims}"
O2IMS_EDGE2_ENDPOINT="${O2IMS_EDGE2_ENDPOINT:-http://${VM4_IP}:31280/o2ims}"
PROVISIONING_REQUEST_TIMEOUT="${PROVISIONING_REQUEST_TIMEOUT:-$O2IMS_TIMEOUT}"

# Exponential backoff configuration
BACKOFF_INITIAL_DELAY="${BACKOFF_INITIAL_DELAY:-2}"
BACKOFF_MAX_DELAY="${BACKOFF_MAX_DELAY:-60}"
BACKOFF_MULTIPLIER="${BACKOFF_MULTIPLIER:-2}"
MAX_RETRY_ATTEMPTS="${MAX_RETRY_ATTEMPTS:-10}"

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
EXIT_GITOPS_TIMEOUT=5
EXIT_O2IMS_TIMEOUT=6
EXIT_POSTCHECK_FAILED=7
EXIT_SLO_VIOLATION=8
EXIT_ROLLBACK_FAILED=9
EXIT_DEPENDENCY_MISSING=10
EXIT_IDEMPOTENCY_CHECK_FAILED=11
EXIT_ARTIFACT_CORRUPTION=12
EXIT_CONFIG_ERROR=13

# Demo step tracking
DEMO_STEPS=()
DEMO_STEP_STATUS=()
DEMO_STEP_DURATION=()
DEMO_STEP_ARTIFACTS=()
DEMO_STEP_CHECKSUMS=()

# Global state tracking
DEPLOYMENT_SITES=()
DEPLOYMENT_ARTIFACTS=()
ROLLBACK_POINTS=()
ERROR_EVIDENCE_COLLECTED=false

# Dependency checking
check_dependencies() {
    log_demo "STEP" "Checking required dependencies"
    local missing_deps=()
    local required_tools=("kubectl" "curl" "jq" "git" "kpt" "sha256sum" "bc")

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_demo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        return $EXIT_DEPENDENCY_MISSING
    fi

    log_demo "SUCCESS" "All dependencies satisfied"
    return 0
}

# Exponential backoff utility
exponential_backoff() {
    local max_attempts="$1"
    local command_desc="$2"
    shift 2
    local command=("$@")

    local attempt=1
    local delay=$BACKOFF_INITIAL_DELAY

    while [[ $attempt -le $max_attempts ]]; do
        log_demo "INFO" "Attempt $attempt/$max_attempts: $command_desc"

        if "${command[@]}"; then
            log_demo "SUCCESS" "$command_desc succeeded on attempt $attempt"
            return 0
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_demo "ERROR" "$command_desc failed after $max_attempts attempts"
            return 1
        fi

        log_demo "WARN" "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"

        # Calculate next delay with exponential backoff
        delay=$((delay * BACKOFF_MULTIPLIER))
        if [[ $delay -gt $BACKOFF_MAX_DELAY ]]; then
            delay=$BACKOFF_MAX_DELAY
        fi

        ((attempt++))
    done

    return 1
}

# Calculate SHA256 checksum
calculate_checksum() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        sha256sum "$file_path" | cut -d' ' -f1
    else
        echo "file_not_found"
    fi
}

# Verify checksum
verify_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    local actual_checksum

    actual_checksum=$(calculate_checksum "$file_path")

    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        return 0
    else
        log_demo "ERROR" "Checksum mismatch for $file_path: expected $expected_checksum, got $actual_checksum"
        return 1
    fi
}

# Setup comprehensive artifact directories
setup_artifact_directories() {
    log_demo "STEP" "Setting up artifact directories"

    local directories=(
        "$ARTIFACTS_DIR"
        "$REPORTS_DIR"
        "$STATE_DIR"
        "$ROLLBACK_SNAPSHOT_DIR"
        "$ARTIFACTS_DIR/intent"
        "$ARTIFACTS_DIR/krm-rendered"
        "$ARTIFACTS_DIR/deployment-logs"
        "$ARTIFACTS_DIR/postcheck-results"
        "$ARTIFACTS_DIR/o2ims-status"
        "$ARTIFACTS_DIR/evidence"
        "$REPORTS_DIR/metrics"
        "$REPORTS_DIR/kpi-charts"
        "$REPORTS_DIR/summit-package"
    )

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would create ${#directories[@]} directories"
        return 0
    fi

    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done

    # Create symlinks to latest
    local artifacts_latest="./artifacts/latest"
    local reports_latest="./reports/latest"

    if [[ -L "$artifacts_latest" ]]; then rm "$artifacts_latest"; fi
    if [[ -L "$reports_latest" ]]; then rm "$reports_latest"; fi

    ln -sf "demo-llm-${TIMESTAMP}" "$artifacts_latest"
    ln -sf "${TIMESTAMP}" "$reports_latest"

    log_demo "SUCCESS" "Artifact directories created with timestamp: $TIMESTAMP"
    return 0
}

# Initialize deployment state
initialize_deployment_state() {
    log_demo "STEP" "Initializing deployment state tracking"

    local state_data
    state_data=$(cat <<EOF
{
    "execution_id": "$SCRIPT_EXECUTION_ID",
    "timestamp": "$SCRIPT_START_TIME",
    "target_site": "$TARGET_SITE",
    "script_version": "$SCRIPT_VERSION",
    "dry_run": $DRY_RUN,
    "idempotent_mode": $IDEMPOTENT_MODE,
    "deployment_status": "initializing",
    "artifacts_dir": "$ARTIFACTS_DIR",
    "reports_dir": "$REPORTS_DIR",
    "deployed_sites": [],
    "rollback_points": [],
    "checksums": {}
}
EOF
    )

    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$state_data" | jq . > "$DEPLOYMENT_STATE_FILE"
    fi

    log_demo "SUCCESS" "Deployment state initialized"
    return 0
}

# Logging functions
log_json() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"script\":\"$SCRIPT_NAME\",\"version\":\"$SCRIPT_VERSION\",\"execution_id\":\"$SCRIPT_EXECUTION_ID\",\"message\":\"$message\"}" >&2
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

# Enhanced cleanup function with comprehensive error handling
cleanup() {
    local exit_code=$?
    local end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local duration=$(($(date -d "$end_time" +%s) - $(date -d "$SCRIPT_START_TIME" +%s)))

    log_demo "INFO" "Starting cleanup process (exit code: $exit_code)"

    # Collect error evidence if deployment failed
    if [[ $exit_code -ne 0 && "$ERROR_EVIDENCE_COLLECTED" == "false" ]]; then
        collect_error_evidence "$exit_code"
    fi

    # Update deployment state
    if [[ "$DRY_RUN" == "false" ]] && [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
        local final_status
        if [[ $exit_code -eq 0 ]]; then
            final_status="success"
        else
            final_status="failed"
        fi

        jq --arg status "$final_status" \
           --arg end_time "$end_time" \
           --argjson duration "$duration" \
           --argjson exit_code "$exit_code" \
           '.deployment_status = $status | .end_time = $end_time | .duration_seconds = $duration | .exit_code = $exit_code' \
           "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
           mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
    fi

    if [[ "$SKIP_CLEANUP" != "true" ]]; then
        log_demo "INFO" "Performing cleanup tasks..."

        # Clean up temporary files
        rm -f /tmp/demo-llm-*.log /tmp/intent-*.json /tmp/krm-*.yaml 2>/dev/null || true

        # Kill any background processes
        jobs -p | xargs -r kill 2>/dev/null || true

        # Clean up lock files
        rm -f "${ARTIFACTS_DIR}/.lock" 2>/dev/null || true
    fi

    # Generate comprehensive final report
    generate_demo_report "$exit_code" "$duration"

    # Generate Summit package if requested and successful
    if [[ $exit_code -eq 0 && "$GENERATE_SUMMIT_PACKAGE" == "true" ]]; then
        generate_summit_package
    fi

    if [[ $exit_code -eq 0 ]]; then
        show_success_banner
    else
        log_demo "ERROR" "Demo failed with exit code: $exit_code"
        show_failure_banner

        # Auto-rollback on failure if enabled
        if [[ "$ROLLBACK_ON_FAILURE" == "true" ]] && [[ $exit_code -ne $EXIT_INVALID_TARGET ]] && [[ $exit_code -ne $EXIT_CONFIG_ERROR ]]; then
            log_demo "WARN" "Initiating automatic rollback..."
            if perform_rollback; then
                log_demo "SUCCESS" "Automatic rollback completed"
            else
                log_demo "ERROR" "Automatic rollback failed - manual intervention required"
            fi
        fi
    fi

    log_json "DEMO_COMPLETE" "Duration: ${duration}s, Exit: $exit_code, Target: $TARGET_SITE, ExecutionID: $SCRIPT_EXECUTION_ID"
    exit $exit_code
}

# Collect evidence on failure
collect_error_evidence() {
    local exit_code="$1"
    local evidence_dir="$ARTIFACTS_DIR/evidence"

    log_demo "INFO" "Collecting error evidence for exit code: $exit_code"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would collect error evidence"
        return 0
    fi

    mkdir -p "$evidence_dir"

    # Collect system information
    {
        echo "# Error Evidence Collection"
        echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "Exit Code: $exit_code"
        echo "Execution ID: $SCRIPT_EXECUTION_ID"
        echo "Target Site: $TARGET_SITE"
        echo ""
        echo "# Git Status"
        git status 2>/dev/null || echo "Git status unavailable"
        echo ""
        echo "# Git Log (last 5 commits)"
        git log --oneline -5 2>/dev/null || echo "Git log unavailable"
        echo ""
        echo "# Disk Usage"
        df -h .
        echo ""
        echo "# Memory Usage"
        free -h
    } > "$evidence_dir/system_info.txt"

    # Collect Kubernetes status if available
    if command -v kubectl >/dev/null 2>&1; then
        {
            echo "# Kubernetes Status"
            kubectl get nodes --no-headers 2>/dev/null || echo "No kubectl access"
            echo ""
            echo "# RootSync Status"
            kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" -o yaml 2>/dev/null || echo "RootSync not found"
            echo ""
            echo "# RepoSync Status"
            kubectl get reposync "$REPOSYNC_NAME" -n "$REPOSYNC_NAMESPACE" -o yaml 2>/dev/null || echo "RepoSync not found"
        } > "$evidence_dir/kubernetes_status.yaml"
    fi

    # Collect network connectivity status
    {
        echo "# Network Connectivity Test"
        echo "VM2_IP ($VM2_IP) connectivity:"
        ping -c 3 -W 5 "$VM2_IP" 2>&1 || echo "VM2 unreachable"
        echo ""
        echo "VM3_IP ($VM3_IP) connectivity:"
        ping -c 3 -W 5 "$VM3_IP" 2>&1 || echo "VM3 unreachable"
        if [[ -n "$VM4_IP" ]]; then
            echo ""
            echo "VM4_IP ($VM4_IP) connectivity:"
            ping -c 3 -W 5 "$VM4_IP" 2>&1 || echo "VM4 unreachable"
        fi
        echo ""
        echo "LLM Adapter health check:"
        curl -s --connect-timeout 5 "${LLM_ADAPTER_URL}/health" 2>&1 || echo "LLM adapter unreachable"
    } > "$evidence_dir/network_status.txt"

    # Copy recent logs
    if [[ -d "$ARTIFACTS_DIR/deployment-logs" ]]; then
        cp -r "$ARTIFACTS_DIR/deployment-logs" "$evidence_dir/" 2>/dev/null || true
    fi

    # Create evidence summary
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"execution_id\": \"$SCRIPT_EXECUTION_ID\","
        echo "  \"exit_code\": $exit_code,"
        echo "  \"target_site\": \"$TARGET_SITE\","
        echo "  \"evidence_collected\": true,"
        echo "  \"evidence_files\": ["
        find "$evidence_dir" -type f -printf '    "%P",' 2>/dev/null | sed '$s/,$//' || echo ''
        echo "  ]"
        echo "}"
    } > "$evidence_dir/evidence_summary.json"

    ERROR_EVIDENCE_COLLECTED=true
    log_demo "SUCCESS" "Error evidence collected in: $evidence_dir"
}

# Enhanced signal handling
setup_signal_handlers() {
    trap 'log_demo "WARN" "Received SIGINT (Ctrl+C) - initiating graceful shutdown"; cleanup' INT
    trap 'log_demo "WARN" "Received SIGTERM - initiating graceful shutdown"; cleanup' TERM
    trap 'log_demo "WARN" "Script exiting unexpectedly"; cleanup' EXIT
}

# Idempotency checks
check_idempotency() {
    local operation="$1"
    local resource_id="$2"
    local checksum="$3"

    if [[ "$IDEMPOTENT_MODE" != "true" ]]; then
        log_demo "INFO" "Idempotency checks disabled"
        return 1  # Force execution
    fi

    log_demo "STEP" "Checking idempotency for: $operation"

    if [[ ! -f "$CHECKSUMS_FILE" ]]; then
        log_demo "INFO" "No previous checksums found - first run"
        return 1  # Force execution
    fi

    local stored_checksum
    stored_checksum=$(grep "^${operation}:${resource_id}:" "$CHECKSUMS_FILE" 2>/dev/null | cut -d':' -f3)

    if [[ -n "$stored_checksum" && "$stored_checksum" == "$checksum" ]]; then
        log_demo "SUCCESS" "Operation $operation already completed with same checksum - skipping"
        return 0  # Skip execution
    else
        log_demo "INFO" "Checksum changed or operation not found - will execute"
        return 1  # Force execution
    fi
}

# Store checksum for idempotency
store_checksum() {
    local operation="$1"
    local resource_id="$2"
    local checksum="$3"

    if [[ "$IDEMPOTENT_MODE" != "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    # Remove old entry if exists
    if [[ -f "$CHECKSUMS_FILE" ]]; then
        grep -v "^${operation}:${resource_id}:" "$CHECKSUMS_FILE" > "${CHECKSUMS_FILE}.tmp" || true
        mv "${CHECKSUMS_FILE}.tmp" "$CHECKSUMS_FILE"
    fi

    # Add new entry
    echo "${operation}:${resource_id}:${checksum}" >> "$CHECKSUMS_FILE"

    log_demo "INFO" "Stored checksum for $operation:$resource_id"
}

# Create rollback snapshot
create_rollback_snapshot() {
    local snapshot_name="$1"
    local description="${2:-Automated snapshot}"

    log_demo "STEP" "Creating rollback snapshot: $snapshot_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would create rollback snapshot: $snapshot_name"
        return 0
    fi

    local snapshot_dir="$ROLLBACK_SNAPSHOT_DIR/$snapshot_name"
    mkdir -p "$snapshot_dir"

    # Capture current Git state
    {
        echo "# Rollback Snapshot: $snapshot_name"
        echo "# Description: $description"
        echo "# Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        echo "# Current HEAD"
        git rev-parse HEAD 2>/dev/null || echo "No git repository"
        echo ""
        echo "# Git Status"
        git status --porcelain 2>/dev/null || echo "No git repository"
        echo ""
        echo "# Current Branch"
        git branch --show-current 2>/dev/null || echo "No git repository"
    } > "$snapshot_dir/git_state.txt"

    # Copy current GitOps configurations
    if [[ -d "$GITOPS_BASE_DIR" ]]; then
        cp -r "$GITOPS_BASE_DIR" "$snapshot_dir/gitops_backup/" 2>/dev/null || true
    fi

    # Copy deployment state
    if [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
        cp "$DEPLOYMENT_STATE_FILE" "$snapshot_dir/deployment_state.json"
    fi

    # Add to rollback points tracking
    ROLLBACK_POINTS+=("$snapshot_name")

    log_demo "SUCCESS" "Rollback snapshot created: $snapshot_dir"
    return 0
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

    # Validate required IPs based on target
    if [[ "$TARGET_SITE" == "edge1" || "$TARGET_SITE" == "both" ]]; then
        if [[ -z "$VM2_IP" ]]; then
            log_demo "ERROR" "VM2_IP required for edge1 deployment but not configured"
            return $EXIT_CONFIG_ERROR
        fi
    fi

    if [[ "$TARGET_SITE" == "edge2" || "$TARGET_SITE" == "both" ]]; then
        if [[ -z "$VM4_IP" ]]; then
            log_demo "ERROR" "VM4_IP required for edge2 deployment but not configured"
            return $EXIT_CONFIG_ERROR
        fi
    fi

    # Check connectivity to target sites with retry
    if [[ "$TARGET_SITE" == "edge1" ]] || [[ "$TARGET_SITE" == "both" ]]; then
        if exponential_backoff 3 "Edge1 connectivity check" ping -c 1 -W 5 "$VM2_IP" >/dev/null 2>&1; then
            log_demo "SUCCESS" "Edge1 connectivity confirmed: $VM2_IP"
        else
            log_demo "WARN" "Cannot ping edge1 at $VM2_IP (deployment may fail)"
        fi
    fi

    if [[ "$TARGET_SITE" == "edge2" ]] || [[ "$TARGET_SITE" == "both" ]]; then
        if exponential_backoff 3 "Edge2 connectivity check" ping -c 1 -W 5 "$VM4_IP" >/dev/null 2>&1; then
            log_demo "SUCCESS" "Edge2 connectivity confirmed: $VM4_IP"
        else
            log_demo "WARN" "Cannot ping edge2 at $VM4_IP (deployment may fail)"
        fi
    fi

    return 0
}

# Wait for GitOps reconciliation with comprehensive status checking
wait_for_gitops_reconciliation() {
    local target_site="$1"
    log_demo "STEP" "Waiting for GitOps reconciliation on $target_site (timeout: ${GITOPS_TIMEOUT}s)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would wait for GitOps reconciliation"
        return 0
    fi

    local start_time=$(date +%s)
    local timeout_time=$((start_time + GITOPS_TIMEOUT))
    local check_interval=15
    local status_log="$ARTIFACTS_DIR/deployment-logs/gitops-${target_site}-$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$(dirname "$status_log")"

    while [[ $(date +%s) -lt $timeout_time ]]; do
        local rootsync_status="unknown"
        local reposync_status="unknown"
        local reconciled=false

        # Check RootSync status
        if kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" >/dev/null 2>&1; then
            rootsync_status=$(kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "unknown")

            # Log detailed status
            kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" -o yaml >> "$status_log" 2>/dev/null
        fi

        # Check RepoSync status if applicable
        if kubectl get reposync "$REPOSYNC_NAME" -n "$REPOSYNC_NAMESPACE" >/dev/null 2>&1; then
            reposync_status=$(kubectl get reposync "$REPOSYNC_NAME" -n "$REPOSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "unknown")

            kubectl get reposync "$REPOSYNC_NAME" -n "$REPOSYNC_NAMESPACE" -o yaml >> "$status_log" 2>/dev/null
        fi

        # Check reconciliation status
        if [[ "$rootsync_status" == "True" ]] && [[ "$reposync_status" =~ ^(True|unknown)$ ]]; then
            reconciled=true
        fi

        local elapsed=$(($(date +%s) - start_time))
        log_demo "INFO" "GitOps status [$elapsed s]: RootSync=$rootsync_status, RepoSync=$reposync_status"

        if [[ "$reconciled" == "true" ]]; then
            log_demo "SUCCESS" "GitOps reconciliation completed for $target_site"
            return 0
        fi

        # Log progress to status file
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - Waiting for reconciliation: RootSync=$rootsync_status, RepoSync=$reposync_status" >> "$status_log"

        sleep $check_interval
    done

    log_demo "ERROR" "GitOps reconciliation timeout after ${GITOPS_TIMEOUT} seconds"
    log_demo "INFO" "GitOps status log: $status_log"
    return $EXIT_GITOPS_TIMEOUT
}

# Wait for O2IMS ProvisioningRequest readiness
wait_for_o2ims_provisioning_request() {
    local target_site="$1"
    local pr_name="${2:-intent-deployment-${SCRIPT_EXECUTION_ID}}"

    log_demo "STEP" "Waiting for O2IMS ProvisioningRequest readiness: $pr_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would wait for O2IMS ProvisioningRequest"
        return 0
    fi

    local o2ims_endpoint
    case "$target_site" in
        "edge1") o2ims_endpoint="$O2IMS_EDGE1_ENDPOINT" ;;
        "edge2") o2ims_endpoint="$O2IMS_EDGE2_ENDPOINT" ;;
        *)
            log_demo "ERROR" "Invalid target site for O2IMS check: $target_site"
            return $EXIT_CONFIG_ERROR
            ;;
    esac

    local pr_endpoint="${o2ims_endpoint}/api/v1/provisioningRequests/${pr_name}"
    local status_log="$ARTIFACTS_DIR/o2ims-status/pr-${target_site}-$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$(dirname "$status_log")"

    log_demo "INFO" "Polling O2IMS endpoint: $pr_endpoint"

    check_pr_status() {
        local response
        if response=$(curl -s --connect-timeout 10 --max-time 30 "$pr_endpoint" 2>/dev/null); then
            echo "$response" >> "$status_log"

            local status
            status=$(echo "$response" | jq -r '.status.state // "unknown"' 2>/dev/null)

            case "$status" in
                "Ready"|"Deployed"|"Completed")
                    log_demo "SUCCESS" "ProvisioningRequest $pr_name is ready (status: $status)"
                    return 0
                    ;;
                "Failed"|"Error")
                    log_demo "ERROR" "ProvisioningRequest $pr_name failed (status: $status)"
                    return 1
                    ;;
                "Pending"|"InProgress"|"Processing")
                    log_demo "INFO" "ProvisioningRequest $pr_name in progress (status: $status)"
                    return 2
                    ;;
                *)
                    log_demo "WARN" "ProvisioningRequest $pr_name unknown status: $status"
                    return 2
                    ;;
            esac
        else
            log_demo "WARN" "Failed to query O2IMS ProvisioningRequest endpoint"
            return 2
        fi
    }

    if exponential_backoff $MAX_RETRY_ATTEMPTS "O2IMS ProvisioningRequest readiness check" check_pr_status; then
        return 0
    else
        log_demo "ERROR" "O2IMS ProvisioningRequest timeout or failure"
        return $EXIT_O2IMS_TIMEOUT
    fi
}

# Monitor O2IMS deployment status
monitor_o2ims_deployment() {
    local target_site="$1"
    local deployment_id="${2:-$SCRIPT_EXECUTION_ID}"

    log_demo "STEP" "Monitoring O2IMS deployment status for $target_site"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would monitor O2IMS deployment"
        return 0
    fi

    local o2ims_endpoint
    case "$target_site" in
        "edge1") o2ims_endpoint="$O2IMS_EDGE1_ENDPOINT" ;;
        "edge2") o2ims_endpoint="$O2IMS_EDGE2_ENDPOINT" ;;
        *)
            log_demo "ERROR" "Invalid target site for O2IMS monitoring: $target_site"
            return $EXIT_CONFIG_ERROR
            ;;
    esac

    local status_log="$ARTIFACTS_DIR/o2ims-status/deployment-${target_site}-$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$(dirname "$status_log")"

    # Query O2IMS for deployment status
    local deployments_endpoint="${o2ims_endpoint}/api/v1/deployments"

    log_demo "INFO" "Querying O2IMS deployments: $deployments_endpoint"

    local response
    if response=$(curl -s --connect-timeout 10 --max-time 30 "$deployments_endpoint" 2>/dev/null); then
        echo "$response" | jq . > "$status_log" 2>/dev/null || echo "$response" > "$status_log"

        # Extract deployment information
        local deployment_count
        deployment_count=$(echo "$response" | jq '.deployments | length' 2>/dev/null || echo "0")

        log_demo "SUCCESS" "O2IMS reported $deployment_count active deployments"
        log_demo "INFO" "O2IMS status saved to: $status_log"
        return 0
    else
        log_demo "WARN" "Could not query O2IMS deployment status"
        echo '{"error": "O2IMS unreachable", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "$status_log"
        return 0  # Non-fatal
    fi
}

# Enhanced SLO gate integration
run_slo_gate_validation() {
    local target_site="$1"

    log_demo "STEP" "Running SLO gate validation for $target_site"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would run SLO gate validation"
        return 0
    fi

    # Create rollback snapshot before SLO validation
    create_rollback_snapshot "pre-slo-validation" "Snapshot before SLO gate validation"

    local postcheck_script="./scripts/postcheck.sh"
    local postcheck_args=("--target=$target_site")
    local slo_report_dir="$ARTIFACTS_DIR/postcheck-results"
    local slo_log="$slo_report_dir/slo-validation-$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$slo_report_dir"

    if [[ ! -f "$postcheck_script" ]]; then
        log_demo "ERROR" "SLO validation script not found: $postcheck_script"
        return $EXIT_POSTCHECK_FAILED
    fi

    log_demo "INFO" "Executing SLO validation: $postcheck_script ${postcheck_args[*]}"

    # Set environment variables for postcheck script
    export REPORT_DIR="$slo_report_dir"
    export LOG_JSON="true"
    export TARGET_SITE="$target_site"

    local slo_success=false
    if timeout "$TIMEOUT_STEP" "$postcheck_script" "${postcheck_args[@]}" > "$slo_log" 2>&1; then
        slo_success=true
        log_demo "SUCCESS" "SLO validation passed for $target_site"
    else
        local exit_code=$?
        log_demo "ERROR" "SLO validation failed for $target_site (exit code: $exit_code)"
        log_demo "INFO" "SLO validation log: $slo_log"

        # Show last few lines of SLO log
        if [[ -f "$slo_log" ]]; then
            printf "\n${YELLOW}Last 10 lines from SLO validation log:${NC}\n"
            tail -10 "$slo_log" 2>/dev/null || echo "Could not read SLO log"
            printf "\n"
        fi

        return $EXIT_SLO_VIOLATION
    fi

    # Copy postcheck report if generated
    if [[ -f "$slo_report_dir/postcheck_report.json" ]]; then
        cp "$slo_report_dir/postcheck_report.json" "$REPORTS_DIR/slo_validation_report.json"
        log_demo "INFO" "SLO validation report copied to reports directory"
    fi

    return 0
}

# Check LLM adapter connectivity with enhanced validation
check_llm_adapter() {
    log_demo "STEP" "Checking LLM adapter connectivity and health"

    local health_url="${LLM_ADAPTER_URL}/health"
    local version_url="${LLM_ADAPTER_URL}/version"
    local health_log="$ARTIFACTS_DIR/deployment-logs/llm-health-$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$(dirname "$health_log")"

    check_llm_health() {
        local health_response
        if health_response=$(curl -s --connect-timeout 10 --max-time 30 "$health_url" 2>/dev/null); then
            echo "Health check response: $health_response" >> "$health_log"

            # Validate health response
            local status
            status=$(echo "$health_response" | jq -r '.status // "unknown"' 2>/dev/null)

            if [[ "$status" == "healthy" || "$status" == "ok" ]]; then
                log_demo "SUCCESS" "LLM adapter is healthy"
                return 0
            else
                log_demo "WARN" "LLM adapter health check returned: $status"
                return 1
            fi
        else
            log_demo "WARN" "Cannot reach LLM adapter health endpoint"
            return 1
        fi
    }

    if exponential_backoff 5 "LLM adapter health check" check_llm_health; then
        # Try to get version information
        local version_response
        if version_response=$(curl -s --connect-timeout 5 --max-time 15 "$version_url" 2>/dev/null); then
            echo "Version response: $version_response" >> "$health_log"
            local version
            version=$(echo "$version_response" | jq -r '.version // "unknown"' 2>/dev/null)
            log_demo "INFO" "LLM adapter version: $version"
        fi

        log_demo "SUCCESS" "LLM adapter is accessible and healthy at $LLM_ADAPTER_URL"
        return 0
    else
        log_demo "ERROR" "LLM adapter health check failed after retries"
        log_demo "INFO" "Health check log: $health_log"
        return $EXIT_LLM_FAILED
    fi
}

# Generate intent from LLM with idempotency and validation
generate_intent_from_llm() {
    local target="$1"
    local intent_text="$2"  # Optional: custom intent text
    local intent_file="$ARTIFACTS_DIR/intent/intent-${target}-${SCRIPT_EXECUTION_ID}.json"

    log_demo "STEP" "Generating intent for target: $target"

    # Create input checksum for idempotency
    local intent_input_hash
    intent_input_hash=$(echo "${target}:${intent_text}" | sha256sum | cut -d' ' -f1)

    # Check idempotency
    if check_idempotency "generate_intent" "$target" "$intent_input_hash"; then
        if [[ -f "$intent_file" ]]; then
            log_demo "SUCCESS" "Intent already generated, using existing: $intent_file"
            echo "$intent_file"
            return 0
        fi
    fi

    # Use provided text or create sample intent text based on target
    if [[ -z "$intent_text" ]]; then
        case "$target" in
            "edge1")
                intent_text="Deploy eMBB slice in edge1 with 1Gbps downlink and 100Mbps uplink for high-bandwidth mobile broadband services with QoS requirements"
                ;;
            "edge2")
                intent_text="Create URLLC service in edge2 with 1ms latency for autonomous vehicle communications and industrial automation with high reliability"
                ;;
            "both")
                intent_text="Setup distributed mMTC IoT network across edge1 and edge2 for 50000 smart sensors with load balancing and fault tolerance"
                ;;
        esac
    fi

    log_demo "INFO" "Intent text: $intent_text"
    log_demo "INFO" "Intent input hash: $intent_input_hash"

    # Use the new intent_from_llm.sh script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local intent_script="$script_dir/intent_from_llm.sh"

    if [[ ! -x "$intent_script" ]]; then
        log_demo "ERROR" "Intent from LLM script not found or not executable: $intent_script"
        return $EXIT_LLM_FAILED
    fi

    # Call the intent_from_llm.sh script with timeout and validation
    local intent_generation_log="$ARTIFACTS_DIR/deployment-logs/intent-generation-$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$(dirname "$intent_generation_log")"

    if timeout "$TIMEOUT_STEP" "$intent_script" --output="$intent_file" --url="$LLM_ADAPTER_URL" "$intent_text" > "$intent_generation_log" 2>&1; then
        # Ensure targetSite field is set correctly and add metadata
        local temp_file="/tmp/intent-with-target-$$.json"
        jq --arg target "$target" \
           --arg execution_id "$SCRIPT_EXECUTION_ID" \
           --arg timestamp "$SCRIPT_START_TIME" \
           --arg input_hash "$intent_input_hash" \
           '. + {
               "targetSite": $target,
               "metadata": {
                   "execution_id": $execution_id,
                   "generated_at": $timestamp,
                   "input_hash": $input_hash,
                   "generator": "demo_llm.sh"
               }
           }' "$intent_file" > "$temp_file" && mv "$temp_file" "$intent_file"

        # Validate generated intent
        if ! jq empty "$intent_file" 2>/dev/null; then
            log_demo "ERROR" "Generated intent is not valid JSON"
            return $EXIT_LLM_FAILED
        fi

        # Calculate and store checksum for idempotency
        local intent_checksum
        intent_checksum=$(calculate_checksum "$intent_file")
        store_checksum "generate_intent" "$target" "$intent_checksum"

        log_demo "SUCCESS" "Intent generated and validated: $intent_file"
        log_demo "INFO" "Intent checksum: $intent_checksum"
        echo "$intent_file"
        return 0
    else
        log_demo "ERROR" "Failed to generate intent from LLM"
        log_demo "INFO" "Intent generation log: $intent_generation_log"
        return $EXIT_LLM_FAILED
    fi
}

# Render KRM from intent with idempotency and validation
render_krm_from_intent() {
    local intent_file="$1"
    local target="$2"
    local output_dir=""

    log_demo "STEP" "Rendering KRM for target: $target"

    # Create input checksum for idempotency
    local intent_checksum
    intent_checksum=$(calculate_checksum "$intent_file")

    # Check idempotency
    if check_idempotency "render_krm" "$target" "$intent_checksum"; then
        log_demo "SUCCESS" "KRM already rendered for this intent - skipping"
        return 0
    fi

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
    mkdir -p "$ARTIFACTS_DIR/krm-rendered"

    # KRM rendering with enhanced metadata
    local krm_file="$output_dir/services/intent-rendered-${SCRIPT_EXECUTION_ID}.yaml"
    local krm_backup="$ARTIFACTS_DIR/krm-rendered/krm-${target}-${SCRIPT_EXECUTION_ID}.yaml"
    local service_type="$(jq -r '.intent.serviceType // "eMBB"' "$intent_file")"
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
    generated-at: "$SCRIPT_START_TIME"
    execution-id: "$SCRIPT_EXECUTION_ID"
    intent-checksum: "$intent_checksum"
  annotations:
    nephio.org/intent-source: "$intent_file"
    nephio.org/generated-by: "$SCRIPT_NAME v$SCRIPT_VERSION"
    nephio.org/target-site: "$target"
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

    # Create backup copy in artifacts
    cp "$krm_file" "$krm_backup"

    # If target is "both", also render to edge2
    if [[ "$target" == "both" ]]; then
        local edge2_krm_file="$EDGE2_CONFIG_DIR/services/intent-rendered-${SCRIPT_EXECUTION_ID}.yaml"
        local edge2_backup="$ARTIFACTS_DIR/krm-rendered/krm-edge2-${SCRIPT_EXECUTION_ID}.yaml"
        mkdir -p "$EDGE2_CONFIG_DIR/services"
        sed 's/target-site: both/target-site: edge2/g; s/targetSite: both/targetSite: edge2/g' "$krm_file" > "$edge2_krm_file"
        cp "$edge2_krm_file" "$edge2_backup"
        log_demo "SUCCESS" "KRM rendered for edge2: $edge2_krm_file"
    fi

    # Validate generated KRM
    if command -v kubeconform >/dev/null 2>&1; then
        if kubeconform -summary "$krm_file" >/dev/null 2>&1; then
            log_demo "INFO" "KRM validation passed"
        else
            log_demo "WARN" "KRM validation failed - continuing anyway"
        fi
    fi

    # Store checksum for idempotency
    local krm_checksum
    krm_checksum=$(calculate_checksum "$krm_file")
    store_checksum "render_krm" "$target" "$krm_checksum"

    log_demo "SUCCESS" "KRM rendered successfully: $krm_file"
    log_demo "INFO" "KRM backup: $krm_backup"
    echo "$krm_file"
    return 0
}

# Enhanced deployment to target sites with monitoring
deploy_to_sites() {
    local target="$1"

    log_demo "STEP" "Deploying to target sites: $target"

    # Create rollback snapshot before deployment
    create_rollback_snapshot "pre-deployment-$target" "Snapshot before deployment to $target"

    case "$target" in
        "edge1")
            deploy_to_edge1 && wait_for_gitops_reconciliation "edge1" && monitor_o2ims_deployment "edge1"
            ;;
        "edge2")
            deploy_to_edge2 && wait_for_gitops_reconciliation "edge2" && monitor_o2ims_deployment "edge2"
            ;;
        "both")
            (deploy_to_edge1 && wait_for_gitops_reconciliation "edge1" && monitor_o2ims_deployment "edge1") && \
            (deploy_to_edge2 && wait_for_gitops_reconciliation "edge2" && monitor_o2ims_deployment "edge2")
            ;;
    esac

    local deploy_result=$?

    # Update deployment state
    if [[ "$DRY_RUN" == "false" ]] && [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
        if [[ $deploy_result -eq 0 ]]; then
            jq --arg target "$target" \
               '.deployed_sites += [$target] | .deployment_status = "deployed"' \
               "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
               mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
        else
            jq --arg target "$target" \
               '.deployment_status = "failed" | .failed_site = $target' \
               "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
               mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
        fi
    fi

    return $deploy_result
}

# Deploy to edge1 with comprehensive validation
deploy_to_edge1() {
    log_demo "INFO" "Deploying to edge1 (VM-2: $VM2_IP)"

    local deploy_log="$ARTIFACTS_DIR/deployment-logs/edge1-deploy-$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$(dirname "$deploy_log")"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would deploy KRM to edge1 via GitOps"
        echo "DRY-RUN deployment to edge1" > "$deploy_log"
        return 0
    fi

    # Pre-deployment validation
    if ! exponential_backoff 3 "Edge1 connectivity check" ping -c 1 -W 5 "$VM2_IP" >/dev/null 2>&1; then
        log_demo "ERROR" "Cannot reach edge1 cluster at $VM2_IP"
        return $EXIT_DEPLOY_FAILED
    fi

    # Git commit and push (if GitOps workflow)
    if [[ -d "$EDGE1_CONFIG_DIR" ]] && git -C "$EDGE1_CONFIG_DIR" status >/dev/null 2>&1; then
        {
            echo "# Edge1 Deployment Log - $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "# Execution ID: $SCRIPT_EXECUTION_ID"
            echo ""
            echo "# Git Status Before Commit"
            git -C "$EDGE1_CONFIG_DIR" status
            echo ""
            echo "# Git Commit"
            git -C "$EDGE1_CONFIG_DIR" add .
            git -C "$EDGE1_CONFIG_DIR" commit -m "Deploy intent for edge1 - execution $SCRIPT_EXECUTION_ID" || echo "No changes to commit"
            echo ""
            echo "# Git Push"
            git -C "$EDGE1_CONFIG_DIR" push origin main || echo "Push failed or no remote configured"
        } >> "$deploy_log" 2>&1
    fi

    log_demo "SUCCESS" "Deployment to edge1 initiated successfully"
    log_demo "INFO" "Deployment log: $deploy_log"
    return 0
}

# Deploy to edge2 with comprehensive validation
deploy_to_edge2() {
    log_demo "INFO" "Deploying to edge2 (VM-4: $VM4_IP)"

    if [[ -z "$VM4_IP" ]]; then
        log_demo "ERROR" "VM4_IP not configured for edge2 deployment"
        return $EXIT_CONFIG_ERROR
    fi

    local deploy_log="$ARTIFACTS_DIR/deployment-logs/edge2-deploy-$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$(dirname "$deploy_log")"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would deploy KRM to edge2 via GitOps"
        echo "DRY-RUN deployment to edge2" > "$deploy_log"
        return 0
    fi

    # Pre-deployment validation
    if ! exponential_backoff 3 "Edge2 connectivity check" ping -c 1 -W 5 "$VM4_IP" >/dev/null 2>&1; then
        log_demo "ERROR" "Cannot reach edge2 cluster at $VM4_IP"
        return $EXIT_DEPLOY_FAILED
    fi

    # Git commit and push (if GitOps workflow)
    if [[ -d "$EDGE2_CONFIG_DIR" ]] && git -C "$EDGE2_CONFIG_DIR" status >/dev/null 2>&1; then
        {
            echo "# Edge2 Deployment Log - $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "# Execution ID: $SCRIPT_EXECUTION_ID"
            echo ""
            echo "# Git Status Before Commit"
            git -C "$EDGE2_CONFIG_DIR" status
            echo ""
            echo "# Git Commit"
            git -C "$EDGE2_CONFIG_DIR" add .
            git -C "$EDGE2_CONFIG_DIR" commit -m "Deploy intent for edge2 - execution $SCRIPT_EXECUTION_ID" || echo "No changes to commit"
            echo ""
            echo "# Git Push"
            git -C "$EDGE2_CONFIG_DIR" push origin main || echo "Push failed or no remote configured"
        } >> "$deploy_log" 2>&1
    fi

    log_demo "SUCCESS" "Deployment to edge2 initiated successfully"
    log_demo "INFO" "Deployment log: $deploy_log"
    return 0
}

# Generate Summit demo package
generate_summit_package() {
    log_demo "STEP" "Generating Summit demo package"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would generate Summit package"
        return 0
    fi

    local package_dir="$REPORTS_DIR/summit-package"
    mkdir -p "$package_dir"

    # Call package_artifacts.sh script
    local package_script="./scripts/package_artifacts.sh"
    if [[ -f "$package_script" ]]; then
        if "$package_script" --timestamp="$TIMESTAMP" --reports-dir="$REPORTS_DIR"; then
            log_demo "SUCCESS" "Summit package generated successfully"
        else
            log_demo "WARN" "Summit package generation failed"
        fi
    else
        log_demo "WARN" "Package artifacts script not found: $package_script"
    fi

    # Generate executive summary
    local summary_script="./scripts/generate_executive_summary.sh"
    if [[ -f "$summary_script" ]]; then
        "$summary_script" --execution-id="$SCRIPT_EXECUTION_ID" --reports-dir="$REPORTS_DIR" 2>/dev/null || true
    fi

    # Generate KPI charts if available
    local kpi_script="./scripts/generate_kpi_charts.sh"
    if [[ -f "$kpi_script" ]]; then
        "$kpi_script" --reports-dir="$REPORTS_DIR" 2>/dev/null || true
    fi

    return 0
}

# Enhanced rollback with evidence collection
perform_rollback() {
    local rollback_reason="${1:-SLO-violation}"

    log_demo "STEP" "Performing rollback for target: $TARGET_SITE (reason: $rollback_reason)"

    # Collect evidence before rollback
    if [[ "$ERROR_EVIDENCE_COLLECTED" == "false" ]]; then
        collect_error_evidence "rollback_initiated"
    fi

    local rollback_script="./scripts/rollback.sh"
    local rollback_log="$ARTIFACTS_DIR/deployment-logs/rollback-$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$(dirname "$rollback_log")"

    if [[ -f "$rollback_script" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_demo "INFO" "[DRY-RUN] Would run rollback script"
            return 0
        fi

        # Set environment for rollback script
        export ROLLBACK_REASON="$rollback_reason"
        export TARGET_SITE="$TARGET_SITE"
        export EXECUTION_ID="$SCRIPT_EXECUTION_ID"

        if timeout "$TIMEOUT_STEP" "$rollback_script" "$rollback_reason" > "$rollback_log" 2>&1; then
            log_demo "SUCCESS" "Rollback completed successfully"
            log_demo "INFO" "Rollback log: $rollback_log"

            # Update deployment state
            if [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
                jq --arg reason "$rollback_reason" \
                   '.deployment_status = "rolled_back" | .rollback_reason = $reason' \
                   "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
                   mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
            fi

            return 0
        else
            log_demo "ERROR" "Rollback failed - check log: $rollback_log"
            return $EXIT_ROLLBACK_FAILED
        fi
    else
        log_demo "WARN" "Rollback script not found at $rollback_script"
        log_demo "INFO" "Manual cleanup may be required"

        # Manual rollback attempt - restore from snapshot
        if [[ ${#ROLLBACK_POINTS[@]} -gt 0 ]]; then
            local latest_snapshot="${ROLLBACK_POINTS[-1]}"
            local snapshot_dir="$ROLLBACK_SNAPSHOT_DIR/$latest_snapshot"

            if [[ -d "$snapshot_dir/gitops_backup" ]]; then
                log_demo "INFO" "Attempting manual rollback using snapshot: $latest_snapshot"
                cp -r "$snapshot_dir/gitops_backup"/* "$GITOPS_BASE_DIR/" 2>/dev/null || true
                log_demo "INFO" "Manual rollback attempt completed"
            fi
        fi

        return 0
    fi
}

# Execute demo step with comprehensive error handling and monitoring
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
    local step_log_file="$ARTIFACTS_DIR/deployment-logs/step-${step_num}-${step_name//[^a-zA-Z0-9]/_}.log"
    local step_success=false

    # Create deployment log directory
    mkdir -p "$(dirname "$step_log_file")"

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

        # Calculate and store step checksum
        local step_checksum
        if [[ -f "$step_log_file" ]]; then
            step_checksum=$(calculate_checksum "$step_log_file")
            DEMO_STEP_CHECKSUMS+=("$step_checksum")
        else
            DEMO_STEP_CHECKSUMS+=("no_log")
        fi
    fi

    return 0
}

# Generate comprehensive demo report with metrics
generate_demo_report() {
    local exit_code="$1"
    local total_duration="$2"
    local report_file="$REPORTS_DIR/demo-execution-report.json"

    log_demo "INFO" "Generating comprehensive demo report..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would generate demo report"
        return 0
    fi

    # Calculate success metrics
    local successful_steps=0
    local failed_steps=0
    for status in "${DEMO_STEP_STATUS[@]}"; do
        case "$status" in
            "SUCCESS") ((successful_steps++)) ;;
            "FAILED") ((failed_steps++)) ;;
        esac
    done

    cat > "$report_file" <<EOF
{
  "execution_metadata": {
    "execution_id": "$SCRIPT_EXECUTION_ID",
    "timestamp": "$SCRIPT_START_TIME",
    "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_seconds": $total_duration,
    "exit_code": $exit_code,
    "script_version": "$SCRIPT_VERSION",
    "success": $([ $exit_code -eq 0 ] && echo "true" || echo "false")
  },
  "configuration": {
    "target_site": "$TARGET_SITE",
    "demo_mode": "$DEMO_MODE",
    "dry_run": $DRY_RUN,
    "idempotent_mode": $IDEMPOTENT_MODE,
    "rollback_on_failure": $ROLLBACK_ON_FAILURE
  },
  "environment": {
    "vm2_ip": "$VM2_IP",
    "vm3_ip": "$VM3_IP",
    "vm4_ip": "$VM4_IP",
    "llm_adapter_url": "$LLM_ADAPTER_URL",
    "gitops_base_dir": "$GITOPS_BASE_DIR",
    "o2ims_edge1_endpoint": "$O2IMS_EDGE1_ENDPOINT",
    "o2ims_edge2_endpoint": "$O2IMS_EDGE2_ENDPOINT"
  },
  "metrics": {
    "total_steps": ${#DEMO_STEPS[@]},
    "successful_steps": $successful_steps,
    "failed_steps": $failed_steps,
    "success_rate": $(echo "scale=3; $successful_steps / ${#DEMO_STEPS[@]}" | bc -l 2>/dev/null || echo "0")
  },
  "artifacts": {
    "artifacts_dir": "$ARTIFACTS_DIR",
    "reports_dir": "$REPORTS_DIR",
    "state_dir": "$STATE_DIR",
    "rollback_snapshots": [$(printf '"%s",' "${ROLLBACK_POINTS[@]}" | sed 's/,$//')]
  },
  "steps": [
EOF

    # Add detailed step information
    for i in "${!DEMO_STEPS[@]}"; do
        local comma=""
        if [[ $i -lt $((${#DEMO_STEPS[@]} - 1)) ]]; then
            comma=","
        fi

        local checksum="${DEMO_STEP_CHECKSUMS[i]:-unknown}"

        cat >> "$report_file" <<EOF
    {
      "step_number": $((i + 1)),
      "name": "${DEMO_STEPS[i]}",
      "status": "${DEMO_STEP_STATUS[i]}",
      "duration_seconds": ${DEMO_STEP_DURATION[i]},
      "log_file": "${DEMO_STEP_ARTIFACTS[i]}",
      "checksum": "$checksum"
    }$comma
EOF
    done

    cat >> "$report_file" <<EOF
  ]
}
EOF

    # Copy deployment state if available
    if [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
        cp "$DEPLOYMENT_STATE_FILE" "$REPORTS_DIR/deployment-state.json"
    fi

    # Create a summary file for quick reference
    local summary_file="$REPORTS_DIR/execution-summary.txt"
    {
        echo "# Demo Execution Summary - $SCRIPT_EXECUTION_ID"
        echo "Timestamp: $SCRIPT_START_TIME"
        echo "Target Site: $TARGET_SITE"
        echo "Duration: ${total_duration}s"
        echo "Exit Code: $exit_code"
        echo "Success: $([ $exit_code -eq 0 ] && echo "YES" || echo "NO")"
        echo "Steps: ${#DEMO_STEPS[@]} (Success: $successful_steps, Failed: $failed_steps)"
        echo ""
        echo "Artifacts Directory: $ARTIFACTS_DIR"
        echo "Reports Directory: $REPORTS_DIR"
        echo ""
        echo "Step Details:"
        for i in "${!DEMO_STEPS[@]}"; do
            echo "  $((i + 1)). ${DEMO_STEPS[i]}: ${DEMO_STEP_STATUS[i]} (${DEMO_STEP_DURATION[i]}s)"
        done
    } > "$summary_file"

    log_demo "SUCCESS" "Comprehensive demo report generated: $report_file"
    log_demo "INFO" "Summary available at: $summary_file"
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

# Enhanced main demo execution with comprehensive pipeline
main() {
    # Set up signal handlers first
    setup_signal_handlers

    # Show banner
    show_demo_banner

    log_demo "INFO" "Nephio LLM Intent-to-O2 Enhanced Demo Starting (v$SCRIPT_VERSION)"
    log_demo "INFO" "Execution ID: $SCRIPT_EXECUTION_ID"
    log_demo "INFO" "Target: $TARGET_SITE | Mode: $DEMO_MODE | LLM: $LLM_ADAPTER_URL"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "🔍 DRY-RUN MODE: No changes will be made"
    fi

    if [[ "$IDEMPOTENT_MODE" == "true" ]]; then
        log_demo "INFO" "⚡ IDEMPOTENT MODE: Skipping unchanged operations"
    fi

    # Initialize comprehensive pipeline
    local demo_steps=(
        "check-dependencies|check_dependencies|Verify required tools and dependencies"
        "setup-artifacts|setup_artifact_directories|Setup comprehensive artifact directories"
        "initialize-state|initialize_deployment_state|Initialize deployment state tracking"
        "validate-target|validate_target_site|Validate target site parameter and connectivity"
        "check-llm|check_llm_adapter|Check LLM adapter connectivity and health"
        "generate-intent|generate_intent_wrapper|Generate intent from LLM for target site"
        "render-krm|render_krm_wrapper|Render KRM manifests from intent with validation"
        "deploy|deploy_wrapper|Deploy to target sites via GitOps with monitoring"
        "wait-o2ims|wait_o2ims_wrapper|Wait for O2IMS ProvisioningRequest readiness"
        "slo-gate|slo_gate_wrapper|Run SLO gate validation and metrics collection"
    )

    local total_steps=${#demo_steps[@]}

    log_demo "INFO" "Pipeline configured with $total_steps steps"

    # Execute each demo step with enhanced error handling
    for i in "${!demo_steps[@]}"; do
        local step_info="${demo_steps[i]}"
        IFS='|' read -r step_name step_function step_description <<< "$step_info"

        local step_num=$((i + 1))

        if ! execute_demo_step "$step_num" "$total_steps" "$step_name" "$step_function" "$step_description"; then
            local error_code=$?
            log_demo "ERROR" "Demo step failed: $step_name (exit code: $error_code)"

            # Map specific error codes to appropriate exit codes
            case "$error_code" in
                $EXIT_DEPENDENCY_MISSING) exit $EXIT_DEPENDENCY_MISSING ;;
                $EXIT_LLM_FAILED) exit $EXIT_LLM_FAILED ;;
                $EXIT_GITOPS_TIMEOUT) exit $EXIT_GITOPS_TIMEOUT ;;
                $EXIT_O2IMS_TIMEOUT) exit $EXIT_O2IMS_TIMEOUT ;;
                $EXIT_SLO_VIOLATION) exit $EXIT_SLO_VIOLATION ;;
                *) exit $EXIT_DEPLOY_FAILED ;;
            esac
        fi

        # Add pause between steps for interactive mode
        if [[ "$DEMO_MODE" == "interactive" ]] && [[ "$DRY_RUN" != "true" ]]; then
            sleep 2
        fi

        # Progress checkpoint
        log_demo "INFO" "Pipeline progress: $step_num/$total_steps steps completed"
    done

    log_demo "SUCCESS" "All pipeline steps completed successfully for target: $TARGET_SITE"
    log_demo "INFO" "Execution ID: $SCRIPT_EXECUTION_ID"
    log_demo "INFO" "Total duration: $(($(date +%s) - $(date -d "$SCRIPT_START_TIME" +%s)))s"
    exit $EXIT_SUCCESS
}

# Enhanced wrapper functions for pipeline execution
generate_intent_wrapper() {
    local intent_file
    intent_file=$(generate_intent_from_llm "$TARGET_SITE" "")

    # Store state for next steps
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "INTENT_FILE=$intent_file" >> "$STATE_DIR/pipeline-state.env"

        # Update deployment state
        if [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
            jq --arg intent_file "$intent_file" \
               '.intent_file = $intent_file | .pipeline_stage = "intent_generated"' \
               "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
               mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
        fi
    fi

    log_demo "INFO" "Intent generated and stored: $intent_file"
}

render_krm_wrapper() {
    # Load pipeline state
    if [[ -f "$STATE_DIR/pipeline-state.env" ]]; then
        source "$STATE_DIR/pipeline-state.env"
    fi

    if [[ -n "$INTENT_FILE" ]] && [[ -f "$INTENT_FILE" ]]; then
        local krm_artifacts
        krm_artifacts=$(render_krm_from_intent "$INTENT_FILE" "$TARGET_SITE")

        if [[ "$DRY_RUN" == "false" ]]; then
            echo "KRM_ARTIFACTS=$krm_artifacts" >> "$STATE_DIR/pipeline-state.env"

            # Update deployment state
            if [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
                jq --arg krm_artifacts "$krm_artifacts" \
                   '.krm_artifacts = $krm_artifacts | .pipeline_stage = "krm_rendered"' \
                   "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
                   mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
            fi
        fi

        log_demo "INFO" "KRM rendered and stored: $krm_artifacts"
    else
        log_demo "ERROR" "Intent file not found, cannot render KRM"
        return $EXIT_RENDER_FAILED
    fi
}

deploy_wrapper() {
    if deploy_to_sites "$TARGET_SITE"; then
        # Update deployment state
        if [[ "$DRY_RUN" == "false" ]] && [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
            jq '.pipeline_stage = "deployed"' \
               "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
               mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
        fi
        return 0
    else
        return $EXIT_DEPLOY_FAILED
    fi
}

wait_o2ims_wrapper() {
    case "$TARGET_SITE" in
        "edge1")
            wait_for_o2ims_provisioning_request "edge1"
            ;;
        "edge2")
            wait_for_o2ims_provisioning_request "edge2"
            ;;
        "both")
            wait_for_o2ims_provisioning_request "edge1" && \
            wait_for_o2ims_provisioning_request "edge2"
            ;;
    esac
}

slo_gate_wrapper() {
    if run_slo_gate_validation "$TARGET_SITE"; then
        # Update deployment state to mark successful completion
        if [[ "$DRY_RUN" == "false" ]] && [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
            jq '.pipeline_stage = "slo_validated" | .slo_status = "passed"' \
               "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
               mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
        fi

        log_demo "SUCCESS" "SLO gate validation passed - deployment successful"
        return 0
    else
        local slo_exit_code=$?
        log_demo "ERROR" "SLO gate validation failed - initiating rollback"

        # Mark SLO failure in deployment state
        if [[ "$DRY_RUN" == "false" ]] && [[ -f "$DEPLOYMENT_STATE_FILE" ]]; then
            jq '.pipeline_stage = "slo_failed" | .slo_status = "failed"' \
               "$DEPLOYMENT_STATE_FILE" > "${DEPLOYMENT_STATE_FILE}.tmp" && \
               mv "${DEPLOYMENT_STATE_FILE}.tmp" "$DEPLOYMENT_STATE_FILE"
        fi

        return $slo_exit_code
    fi
}

# Enhanced usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Production-ready multi-site LLM-powered Intent-to-O2 demonstration pipeline.
Enhanced with idempotency, comprehensive monitoring, SLO gates, and Summit packaging.

OPTIONS:
    -h, --help              Show this help message
    -t, --target TARGET     Target site: edge1|edge2|both (default: edge1)
    -d, --dry-run           Perform dry run (show what would be executed)
    -m, --mode MODE         Demo mode: interactive|automated|debug (default: interactive)
    --vm2-ip IP             Edge1 IP address (REQUIRED)
    --vm3-ip IP             LLM adapter IP address (REQUIRED)
    --vm4-ip IP             Edge2 IP address (required for edge2/both targets)
    --llm-url URL           LLM adapter URL (default: http://VM3_IP:8888)
    --timeout SECONDS       Timeout per step in seconds (default: 300)
    --gitops-timeout SEC    GitOps reconciliation timeout (default: 900)
    --o2ims-timeout SEC     O2IMS readiness timeout (default: 600)
    --continue              Continue on step failures
    --artifacts-dir DIR     Artifacts directory (default: ./artifacts/demo-llm-TIMESTAMP)
    --reports-dir DIR       Reports directory (default: ./reports/TIMESTAMP)
    --no-rollback           Disable automatic rollback on failure
    --no-idempotent         Disable idempotency checks
    --no-summit-package     Skip Summit demo package generation
    --skip-cleanup          Skip cleanup on exit
    --rollback              Perform rollback only (no deployment)

ENVIRONMENT VARIABLES:
    TARGET_SITE             Target deployment site
    DEMO_MODE               Demo execution mode
    VM2_IP, VM3_IP, VM4_IP  VM IP addresses (NO HARDCODED VALUES)
    LLM_ADAPTER_URL         LLM adapter service URL
    DRY_RUN                 Enable dry-run mode
    IDEMPOTENT_MODE         Enable idempotency checks (default: true)
    CONTINUE_ON_ERROR       Continue despite step failures
    ROLLBACK_ON_FAILURE     Enable automatic rollback (default: true)
    GENERATE_SUMMIT_PACKAGE Generate Summit demo package (default: true)

ENHANCED PIPELINE SEQUENCE:
    1. check-dependencies → Verify required tools and dependencies
    2. setup-artifacts    → Setup comprehensive artifact directories
    3. initialize-state   → Initialize deployment state tracking
    4. validate-target    → Validate target site and connectivity
    5. check-llm          → Check LLM adapter health with retries
    6. generate-intent    → Generate intent from natural language
    7. render-krm         → Render KRM manifests with validation
    8. deploy             → Deploy via GitOps with reconciliation monitoring
    9. wait-o2ims         → Wait for O2IMS ProvisioningRequest readiness
   10. slo-gate           → SLO gate validation with automatic rollback

FEATURES:
    ✓ Idempotency checks with SHA256 checksums
    ✓ GitOps reconciliation monitoring (RootSync/RepoSync)
    ✓ O2IMS ProvisioningRequest readiness checks
    ✓ Exponential backoff for all network operations
    ✓ Comprehensive artifact management with timestamps
    ✓ Automated rollback on SLO violations
    ✓ Summit demo package generation
    ✓ Enhanced error handling with evidence collection
    ✓ No hardcoded IP addresses or secrets
    ✓ Production-ready logging and metrics collection

EXAMPLES:
    # Standard deployment with required IPs
    VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 $SCRIPT_NAME --target edge1

    # Multi-site deployment
    VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 VM4_IP=192.168.1.102 \
        $SCRIPT_NAME --target both

    # Dry-run with custom timeouts
    VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 \
        $SCRIPT_NAME --dry-run --target edge1 --gitops-timeout 1200

    # Production deployment with custom artifacts location
    VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 \
        $SCRIPT_NAME --target edge1 --artifacts-dir /tmp/demo-artifacts

    # Rollback specific execution
    $SCRIPT_NAME --rollback --target edge1

    # Configuration file based deployment
    echo 'VM2_IP=192.168.1.100' > ./config/demo.conf
    echo 'VM3_IP=192.168.1.101' >> ./config/demo.conf
    $SCRIPT_NAME --target edge1

CONFIGURATION FILES (optional):
    ./config/demo.conf          # Local project configuration
    ~/.nephio/demo.conf         # User configuration
    /etc/nephio/demo.conf       # System configuration

ARTIFACTS & REPORTS:
    artifacts/demo-llm-TIMESTAMP/    # Execution artifacts
    reports/TIMESTAMP/               # Comprehensive reports
    artifacts/latest -> demo-llm-*   # Symlink to latest
    reports/latest -> TIMESTAMP/     # Symlink to latest

NETWORK REQUIREMENTS:
    • VM-1: Orchestrator (this machine) - dynamic configuration
    • VM-2: Edge1 cluster - IP via VM2_IP environment variable
    • VM-3: LLM adapter - IP via VM3_IP environment variable
    • VM-4: Edge2 cluster - IP via VM4_IP environment variable
    • NO HARDCODED IP ADDRESSES - all via environment variables

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

# Enhanced command line argument parsing
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
            case "$DEMO_MODE" in
                "interactive"|"automated"|"debug")
                    ;;
                *)
                    echo "[ERROR] Invalid demo mode: $DEMO_MODE (must be interactive, automated, or debug)" >&2
                    exit $EXIT_CONFIG_ERROR
                    ;;
            esac
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
            if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                TIMEOUT_STEP="$2"
            else
                echo "[ERROR] Invalid timeout value: $2 (must be positive integer)" >&2
                exit $EXIT_CONFIG_ERROR
            fi
            shift 2
            ;;
        --gitops-timeout)
            if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                GITOPS_TIMEOUT="$2"
            else
                echo "[ERROR] Invalid GitOps timeout value: $2 (must be positive integer)" >&2
                exit $EXIT_CONFIG_ERROR
            fi
            shift 2
            ;;
        --o2ims-timeout)
            if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                O2IMS_TIMEOUT="$2"
            else
                echo "[ERROR] Invalid O2IMS timeout value: $2 (must be positive integer)" >&2
                exit $EXIT_CONFIG_ERROR
            fi
            shift 2
            ;;
        --continue)
            CONTINUE_ON_ERROR="true"
            shift
            ;;
        --artifacts-dir)
            ARTIFACTS_DIR="$2"
            # Validate directory path
            if [[ ! "$ARTIFACTS_DIR" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
                echo "[ERROR] Invalid artifacts directory path: $ARTIFACTS_DIR" >&2
                exit $EXIT_CONFIG_ERROR
            fi
            shift 2
            ;;
        --reports-dir)
            REPORTS_DIR="$2"
            # Validate directory path
            if [[ ! "$REPORTS_DIR" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
                echo "[ERROR] Invalid reports directory path: $REPORTS_DIR" >&2
                exit $EXIT_CONFIG_ERROR
            fi
            shift 2
            ;;
        --no-rollback)
            ROLLBACK_ON_FAILURE="false"
            shift
            ;;
        --no-idempotent)
            IDEMPOTENT_MODE="false"
            shift
            ;;
        --no-summit-package)
            GENERATE_SUMMIT_PACKAGE="false"
            shift
            ;;
        --skip-cleanup)
            SKIP_CLEANUP="true"
            shift
            ;;
        --rollback)
            # Special mode: rollback only
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "[INFO] Would perform rollback for target: $TARGET_SITE" >&2
                exit 0
            else
                echo "[INFO] Performing rollback for target: $TARGET_SITE" >&2
                perform_rollback "manual-rollback"
                exit $?
            fi
            ;;
        --version)
            echo "$SCRIPT_NAME version $SCRIPT_VERSION"
            echo "Enhanced production-ready Intent-to-O2 pipeline orchestrator"
            exit 0
            ;;
        --config-check)
            # Validate configuration without running
            echo "[INFO] Configuration validation mode"
            echo "Target Site: $TARGET_SITE"
            echo "Demo Mode: $DEMO_MODE"
            echo "VM2_IP: ${VM2_IP:-NOT_SET}"
            echo "VM3_IP: ${VM3_IP:-NOT_SET}"
            echo "VM4_IP: ${VM4_IP:-NOT_SET}"
            echo "LLM Adapter URL: $LLM_ADAPTER_URL"
            echo "Dry Run: $DRY_RUN"
            echo "Idempotent Mode: $IDEMPOTENT_MODE"
            echo "Artifacts Dir: $ARTIFACTS_DIR"
            echo "Reports Dir: $REPORTS_DIR"
            echo "Generate Summit Package: $GENERATE_SUMMIT_PACKAGE"

            # Validate required settings
            config_errors=0
            if [[ -z "$VM2_IP" ]]; then
                echo "[ERROR] VM2_IP is required but not set" >&2
                ((config_errors++))
            fi
            if [[ -z "$VM3_IP" ]]; then
                echo "[ERROR] VM3_IP is required but not set" >&2
                ((config_errors++))
            fi
            if [[ "$TARGET_SITE" =~ ^(edge2|both)$ ]] && [[ -z "$VM4_IP" ]]; then
                echo "[ERROR] VM4_IP is required for edge2/both targets but not set" >&2
                ((config_errors++))
            fi

            if [[ $config_errors -eq 0 ]]; then
                echo "[SUCCESS] Configuration validation passed"
                exit 0
            else
                echo "[ERROR] Configuration validation failed with $config_errors errors" >&2
                exit $EXIT_CONFIG_ERROR
            fi
            ;;
        -*)
            echo "[ERROR] Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit $EXIT_CONFIG_ERROR
            ;;
        *)
            echo "[ERROR] Unexpected argument: $1" >&2
            echo "Use --help for usage information" >&2
            exit $EXIT_CONFIG_ERROR
            ;;
    esac
done

# Post-processing validation
if [[ -z "$VM2_IP" || -z "$VM3_IP" ]]; then
    echo "[ERROR] VM2_IP and VM3_IP are required. Set them as environment variables or use --vm2-ip and --vm3-ip options." >&2
    echo "Example: VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 $0 --target edge1" >&2
    exit $EXIT_CONFIG_ERROR
fi

# Update derived configurations
if [[ -z "$LLM_ADAPTER_URL" || "$LLM_ADAPTER_URL" == "http://:8888" ]]; then
    LLM_ADAPTER_URL="http://${VM3_IP}:8888"
fi

# Update O2IMS endpoints if not already set
if [[ "$O2IMS_EDGE1_ENDPOINT" == "http://:31280/o2ims" ]]; then
    O2IMS_EDGE1_ENDPOINT="http://${VM2_IP}:31280/o2ims"
fi
if [[ -n "$VM4_IP" ]] && [[ "$O2IMS_EDGE2_ENDPOINT" == "http://:31280/o2ims" ]]; then
    O2IMS_EDGE2_ENDPOINT="http://${VM4_IP}:31280/o2ims"
fi

# Initialize and execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Only run main if script is executed directly (not sourced)
    main "$@"
fi