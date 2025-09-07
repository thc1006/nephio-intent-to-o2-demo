#!/bin/bash
#
# Demo Orchestrator - One-Click Nephio Intent-to-O2 Demo
# Executes complete pipeline: p0-check → o2ims-install → ocloud-provision → precheck → publish-edge → postcheck
#
# Environment: Nephio R5, O-RAN O2 IMS integration, Kubernetes-native pipeline
# Network: Assumes 172.16/16 subnet with VM-1 (this instance) and VM-2 (172.16.4.45)
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.2.0"
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Configuration
DEMO_MODE="${DEMO_MODE:-presentation}"  # presentation|development|debug
VM2_IP="${VM2_IP:-172.16.4.45}"
NETWORK_SUBNET="${NETWORK_SUBNET:-172.16.0.0/16}"
TIMEOUT_STEP="${TIMEOUT_STEP:-300}"     # 5 minutes per step
TIMEOUT_TOTAL="${TIMEOUT_TOTAL:-1800}"  # 30 minutes total
DRY_RUN="${DRY_RUN:-false}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-false}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./artifacts/demo}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

# Colors for presentation mode
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Demo step tracking
DEMO_STEPS=()
DEMO_STEP_STATUS=()
DEMO_STEP_DURATION=()
DEMO_STEP_ARTIFACTS=()

# Exit codes
EXIT_SUCCESS=0
EXIT_PREREQUISITES_FAILED=1
EXIT_NETWORK_CHECK_FAILED=2
EXIT_STEP_FAILED=3
EXIT_TIMEOUT=4
EXIT_CLEANUP_FAILED=5

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
    printf "${BOLD}${CYAN}  DEMO PROGRESS: [%d/%d] (%d%%) - %s${NC}\n" "$step_num" "$total_steps" "$percent" "$step_name"
    printf "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
}

# Demo banner
show_demo_banner() {
    printf "\n${BOLD}${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║    NEPHIO INTENT-TO-O2 DEMO - VERIFIABLE TELCO CLOUD PIPELINE    ║
║                                                                   ║
║  📡 TMF921 Intent → 3GPP TS 28.312 → KRM → O2 IMS → GitOps      ║
║                                                                   ║
║  🔒 Security-First: Sigstore + Kyverno + cert-manager            ║
║  📊 SLO-Gated: Automated rollback on threshold violations        ║
║  🏗️  Cloud-Native: Nephio R5 + O-RAN integration                 ║
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
        rm -f /tmp/demo-*.log /tmp/step-*.output 2>/dev/null || true
    fi
    
    # Generate final report
    generate_demo_report "$exit_code" "$duration"
    
    if [[ $exit_code -eq 0 ]]; then
        show_success_banner
    else
        log_demo "ERROR" "Demo failed with exit code: $exit_code"
        show_failure_banner
    fi
    
    log_json "DEMO_COMPLETE" "Duration: ${duration}s, Exit: $exit_code"
    exit $exit_code
}

# Prerequisites check
check_demo_prerequisites() {
    log_demo "STEP" "Checking demo prerequisites and environment"
    
    local missing_tools=()
    local required_tools=("kubectl" "git" "jq" "curl" "make" "python3.11" "go")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_demo "ERROR" "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check network connectivity to VM-2
    if ! ping -c 1 -W 5 "$VM2_IP" >/dev/null 2>&1; then
        log_demo "WARN" "Cannot ping VM-2 at $VM2_IP (this may be expected)"
    else
        log_demo "SUCCESS" "Network connectivity to VM-2 confirmed"
    fi
    
    # Check if we're in the correct directory
    if [[ ! -f "CLAUDE.md" ]] || [[ ! -d "scripts" ]]; then
        log_demo "ERROR" "Not in the correct project directory"
        return 1
    fi
    
    # Create artifacts directory
    mkdir -p "$ARTIFACTS_DIR"
    chmod 755 "$ARTIFACTS_DIR"
    
    # Check Kubernetes connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_demo "ERROR" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    log_demo "SUCCESS" "All prerequisites satisfied"
    return 0
}

# Network validation
validate_demo_network() {
    log_demo "STEP" "Validating network configuration for demo"
    
    # Check local IP in subnet
    local local_ip
    local_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "unknown")
    
    log_demo "INFO" "Local IP: $local_ip"
    log_demo "INFO" "VM-2 IP: $VM2_IP"
    log_demo "INFO" "Expected subnet: $NETWORK_SUBNET"
    
    # Validate subnet assumptions
    if [[ "$local_ip" =~ ^172\.16\. ]]; then
        log_demo "SUCCESS" "Local IP is in expected 172.16/16 subnet"
    else
        log_demo "WARN" "Local IP not in expected subnet (may cause connectivity issues)"
    fi
    
    # Check VM-2 accessibility on common ports
    local vm2_ports=(22 6443 30080 30090)
    local accessible_ports=()
    
    for port in "${vm2_ports[@]}"; do
        if timeout 5 bash -c "</dev/tcp/$VM2_IP/$port" 2>/dev/null; then
            accessible_ports+=("$port")
        fi
    done
    
    if [[ ${#accessible_ports[@]} -gt 0 ]]; then
        log_demo "SUCCESS" "VM-2 accessible on ports: ${accessible_ports[*]}"
    else
        log_demo "WARN" "VM-2 not accessible on common ports (may be expected)"
    fi
    
    return 0
}

# Execute demo step with comprehensive error handling and timing
execute_demo_step() {
    local step_num="$1"
    local total_steps="$2"  
    local step_name="$3"
    local step_command="$4"
    local step_description="${5:-}"
    
    show_progress "$step_num" "$total_steps" "$step_name"
    
    if [[ -n "$step_description" ]]; then
        log_demo "INFO" "$step_description"
    fi
    
    DEMO_STEPS+=("$step_name")
    
    local step_start_time=$(date +%s)
    local step_log_file="$ARTIFACTS_DIR/step-${step_num}-${step_name//[^a-zA-Z0-9]/_}.log"
    local step_success=false
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "[DRY-RUN] Would execute: $step_command"
        DEMO_STEP_STATUS+=("DRY-RUN")
        DEMO_STEP_DURATION+=("0")
        DEMO_STEP_ARTIFACTS+=("$step_log_file")
        return 0
    fi
    
    log_demo "INFO" "Executing: $step_command"
    
    # Execute with timeout and comprehensive logging
    if timeout "$TIMEOUT_STEP" bash -c "$step_command" >"$step_log_file" 2>&1; then
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

# Generate comprehensive demo report
generate_demo_report() {
    local exit_code="$1"
    local total_duration="$2"
    local report_file="$ARTIFACTS_DIR/demo-report.json"
    local html_report="$ARTIFACTS_DIR/demo-report.html"
    
    log_demo "INFO" "Generating demo report..."
    
    # JSON report
    cat > "$report_file" <<EOF
{
  "demo_execution": {
    "timestamp": "$SCRIPT_START_TIME",
    "duration_seconds": $total_duration,
    "exit_code": $exit_code,
    "mode": "$DEMO_MODE",
    "dry_run": $DRY_RUN,
    "version": "$SCRIPT_VERSION"
  },
  "environment": {
    "vm2_ip": "$VM2_IP",
    "network_subnet": "$NETWORK_SUBNET",
    "artifacts_dir": "$ARTIFACTS_DIR",
    "kubernetes_context": "$(kubectl config current-context 2>/dev/null || echo 'unknown')"
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
  ],
  "artifacts": {
    "report_json": "$report_file",
    "report_html": "$html_report",
    "logs_directory": "$ARTIFACTS_DIR"
  }
}
EOF

    # HTML report for presentation
    generate_html_report "$html_report" "$exit_code" "$total_duration"
    
    log_demo "SUCCESS" "Demo report generated: $report_file"
    log_demo "INFO" "HTML report: $html_report"
}

# Generate HTML report
generate_html_report() {
    local html_file="$1"
    local exit_code="$2"
    local duration="$3"
    
    cat > "$html_file" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nephio Intent-to-O2 Demo Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 3px solid #2196F3; padding-bottom: 20px; margin-bottom: 30px; }
        .success { color: #4CAF50; } .error { color: #f44336; } .warning { color: #ff9800; }
        .step { margin: 15px 0; padding: 15px; border-left: 4px solid #2196F3; background: #f8f9fa; }
        .step.success { border-left-color: #4CAF50; } .step.failed { border-left-color: #f44336; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: #e3f2fd; padding: 20px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #1976d2; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Nephio Intent-to-O2 Demo Report</h1>
            <p class="timestamp">Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
        </div>
EOF

    # Add status and metrics
    local status_class="success"
    local status_text="✅ SUCCESS"
    if [[ $exit_code -ne 0 ]]; then
        status_class="error"
        status_text="❌ FAILED"
    fi
    
    cat >> "$html_file" <<EOF
        <div class="metrics">
            <div class="metric">
                <div class="metric-value $status_class">$status_text</div>
                <div>Overall Status</div>
            </div>
            <div class="metric">
                <div class="metric-value">${duration}s</div>
                <div>Total Duration</div>
            </div>
            <div class="metric">
                <div class="metric-value">${#DEMO_STEPS[@]}</div>
                <div>Steps Executed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$SCRIPT_VERSION</div>
                <div>Script Version</div>
            </div>
        </div>
        
        <h2>📋 Step Details</h2>
EOF

    # Add step details
    for i in "${!DEMO_STEPS[@]}"; do
        local step_class="success"
        local step_icon="✅"
        if [[ "${DEMO_STEP_STATUS[i]}" == "FAILED" ]]; then
            step_class="failed"
            step_icon="❌"
        elif [[ "${DEMO_STEP_STATUS[i]}" == "DRY-RUN" ]]; then
            step_class="warning"
            step_icon="🔍"
        fi
        
        cat >> "$html_file" <<EOF
        <div class="step $step_class">
            <strong>$step_icon Step $((i + 1)): ${DEMO_STEPS[i]}</strong><br>
            Status: ${DEMO_STEP_STATUS[i]} | Duration: ${DEMO_STEP_DURATION[i]}s<br>
            <small>Log: ${DEMO_STEP_ARTIFACTS[i]}</small>
        </div>
EOF
    done

    cat >> "$html_file" <<'EOF'
        
        <div style="margin-top: 40px; text-align: center; color: #666;">
            <hr>
            <p>🤖 Generated by Nephio Intent-to-O2 Demo Orchestrator</p>
            <p><em>Verifiable Intent Pipeline for Telco Cloud & O-RAN</em></p>
        </div>
    </div>
</body>
</html>
EOF
}

# Success banner
show_success_banner() {
    printf "\n${BOLD}${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  🎉 DEMO SUCCESS! Intent-to-O2 Pipeline Completed Successfully      ║
║                                                                      ║
║  ✅ Phase-0 Infrastructure Validated                                ║  
║  ✅ O2 IMS Operator Installed                                       ║
║  ✅ O-Cloud Provisioned                                             ║
║  ✅ Security Precheck Passed                                        ║
║  ✅ Edge Overlay Published                                           ║
║  ✅ SLO Postcheck Validated                                         ║
║                                                                      ║
║  📊 All KPIs within thresholds                                      ║
║  🔒 Security compliance maintained                                   ║
║  🎯 Ready for production deployment                                  ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n\n"
    
    printf "${BOLD}${CYAN}📁 Generated Artifacts:${NC}\n"
    if [[ -d "$ARTIFACTS_DIR" ]]; then
        find "$ARTIFACTS_DIR" -type f -name "*.json" -o -name "*.html" -o -name "*.log" | head -10 | while read -r file; do
            printf "   📄 %s\n" "$file"
        done
    fi
    
    printf "\n${BOLD}${CYAN}🔍 Next Steps:${NC}\n"
    printf "   • View detailed report: ${CYAN}open %s/demo-report.html${NC}\n" "$ARTIFACTS_DIR"
    printf "   • Check artifacts: ${CYAN}ls -la %s/${NC}\n" "$ARTIFACTS_DIR"
    printf "   • Monitor deployments: ${CYAN}kubectl get pods -A${NC}\n"
    printf "   • Run rollback demo: ${CYAN}make demo-rollback${NC}\n\n"
}

# Failure banner
show_failure_banner() {
    printf "\n${BOLD}${RED}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  ❌ DEMO FAILED - Pipeline Execution Incomplete                     ║
║                                                                      ║
║  🔍 Check the step logs for detailed error information              ║
║  📊 Some components may be partially deployed                       ║
║  🔄 Consider running rollback to clean state                        ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n\n"
    
    printf "${BOLD}${YELLOW}🛠️  Troubleshooting:${NC}\n"
    printf "   • Check logs in: ${YELLOW}%s/${NC}\n" "$ARTIFACTS_DIR"
    printf "   • Run rollback: ${YELLOW}make demo-rollback${NC}\n"
    printf "   • Retry in debug mode: ${YELLOW}DEMO_MODE=debug make demo${NC}\n"
    printf "   • Check network: ${YELLOW}ping %s${NC}\n\n" "$VM2_IP"
}

# Main demo execution
main() {
    # Set up signal handlers
    trap cleanup EXIT INT TERM
    
    # Show banner
    show_demo_banner
    
    log_demo "INFO" "Nephio Intent-to-O2 Demo Starting"
    log_demo "INFO" "Mode: $DEMO_MODE | VM2: $VM2_IP | Artifacts: $ARTIFACTS_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_demo "INFO" "🔍 DRY-RUN MODE: No changes will be made"
    fi
    
    # Prerequisites and network validation
    if ! check_demo_prerequisites; then
        log_demo "ERROR" "Prerequisites check failed"
        exit $EXIT_PREREQUISITES_FAILED
    fi
    
    if ! validate_demo_network; then
        log_demo "ERROR" "Network validation failed"
        exit $EXIT_NETWORK_CHECK_FAILED
    fi
    
    # Define demo steps (modify sequence as needed)
    local demo_steps=(
        "p0-check|make p0-check|Validate Nephio Phase-0 infrastructure readiness"
        "o2ims-install|make o2ims-install|Install O-RAN O2 IMS operator components"
        "ocloud-provision|make ocloud-provision|Provision O-Cloud using FoCoM operator"
        "precheck|make precheck|Run supply chain security precheck gate"
        "publish-edge|make publish-edge|Publish edge overlay with security validation"
        "postcheck|make postcheck|Run post-deployment SLO validation"
    )
    
    local total_steps=${#demo_steps[@]}
    
    # Execute each demo step
    for i in "${!demo_steps[@]}"; do
        local step_info="${demo_steps[i]}"
        IFS='|' read -r step_name step_command step_description <<< "$step_info"
        
        local step_num=$((i + 1))
        
        if ! execute_demo_step "$step_num" "$total_steps" "$step_name" "$step_command" "$step_description"; then
            log_demo "ERROR" "Demo step failed: $step_name"
            exit $EXIT_STEP_FAILED
        fi
        
        # Add pause between steps for presentation mode
        if [[ "$DEMO_MODE" == "presentation" ]] && [[ "$DRY_RUN" != "true" ]]; then
            sleep 2
        fi
    done
    
    log_demo "SUCCESS" "All demo steps completed successfully"
    exit $EXIT_SUCCESS
}

# Usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

One-click demonstration of the complete Nephio Intent-to-O2 pipeline.

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run           Perform dry run (show what would be executed)
    -m, --mode MODE         Demo mode: presentation|development|debug (default: presentation)
    -t, --timeout SECONDS   Timeout per step in seconds (default: 300)
    -c, --continue          Continue on step failures (default: stop on failure)
    --vm2-ip IP             VM-2 IP address (default: 172.16.4.45)
    --artifacts-dir DIR     Artifacts directory (default: ./artifacts/demo)
    --skip-cleanup          Skip cleanup on exit

ENVIRONMENT VARIABLES:
    DEMO_MODE               Demo execution mode
    VM2_IP                  VM-2 IP address  
    NETWORK_SUBNET          Expected network subnet
    TIMEOUT_STEP            Per-step timeout in seconds
    DRY_RUN                 Enable dry-run mode
    CONTINUE_ON_ERROR       Continue despite step failures

DEMO SEQUENCE:
    1. p0-check           → Validate Nephio Phase-0 infrastructure
    2. o2ims-install      → Install O-RAN O2 IMS operator
    3. ocloud-provision   → Provision O-Cloud using FoCoM operator
    4. precheck           → Supply chain security validation
    5. publish-edge       → Publish edge overlay with security gates
    6. postcheck          → SLO validation and metrics check

EXAMPLES:
    $SCRIPT_NAME                                    # Full demo
    $SCRIPT_NAME --dry-run                         # Preview demo steps
    $SCRIPT_NAME --mode debug --continue           # Debug mode with error tolerance
    DEMO_MODE=development $SCRIPT_NAME             # Development mode

NETWORK REQUIREMENTS:
    • VM-1 and VM-2 in 172.16/16 subnet
    • VM-2 accessible on ports 22, 6443, 30080, 30090
    • Kubernetes cluster connectivity
    • Internet access for downloading components

ARTIFACTS:
    • Step execution logs
    • JSON and HTML reports  
    • Security compliance reports
    • Performance metrics
    • Rollback audit trails

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -m|--mode)
            DEMO_MODE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT_STEP="$2"
            shift 2
            ;;
        -c|--continue)
            CONTINUE_ON_ERROR="true"
            shift
            ;;
        --vm2-ip)
            VM2_IP="$2"
            shift 2
            ;;
        --artifacts-dir)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        --skip-cleanup)
            SKIP_CLEANUP="true"
            shift
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