#!/bin/bash
#
# Demo Rollback System - Comprehensive rollback with before/after status comparison
# Demonstrates automated rollback capabilities for presentation and evaluation
#
# Features:
# - Before/after system state comparison
# - Visual diff reporting with impact analysis
# - Timing and performance metrics
# - Multiple rollback strategies (revert vs reset)
# - Comprehensive audit trail generation
#

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.1.0" 
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Configuration
ROLLBACK_STRATEGY="${ROLLBACK_STRATEGY:-revert}"    # revert|reset|demonstrate
ROLLBACK_REASON="${ROLLBACK_REASON:-demo-rollback}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-./artifacts/demo-rollback}"
STATE_SNAPSHOT_DIR="$ARTIFACTS_DIR/state-snapshots"
DEMO_MODE="${DEMO_MODE:-presentation}"              # presentation|development|debug
DRY_RUN="${DRY_RUN:-false}"
GENERATE_REPORTS="${GENERATE_REPORTS:-true}"
SHOW_VISUAL_DIFF="${SHOW_VISUAL_DIFF:-true}"

# Colors for presentation
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# State tracking
BEFORE_STATE=""
AFTER_STATE=""
ROLLBACK_ACTIONS=()
ROLLBACK_TIMINGS=()
ROLLBACK_IMPACTS=()

# Exit codes
EXIT_SUCCESS=0
EXIT_NO_ROLLBACK_NEEDED=1
EXIT_STATE_CAPTURE_FAILED=2
EXIT_ROLLBACK_FAILED=3
EXIT_REPORT_GENERATION_FAILED=4

# Logging functions
log_demo() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -u +%H:%M:%S)"
    
    case "$level" in
        "BANNER")
            printf "\n${BOLD}${CYAN}╔══ %s ══╗${NC}\n" "$message" >&2
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
        "STEP")
            printf "\n${BOLD}${MAGENTA}━━━ %s ━━━${NC}\n" "$message" >&2
            ;;
        *)
            printf "[$timestamp] %s\n" "$message" >&2
            ;;
    esac
}

# Demo rollback banner
show_rollback_banner() {
    printf "\n${BOLD}${YELLOW}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           NEPHIO INTENT-TO-O2 DEMO ROLLBACK SYSTEM               ║
║                                                                   ║
║  🔄 Automated rollback with comprehensive state analysis         ║
║  📊 Before/after comparison with visual diff reporting           ║
║  ⚡ Multiple rollback strategies and impact analysis             ║
║  🎯 Designed for presentation and evaluation scenarios           ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n"
}

# Capture system state snapshot
capture_system_state() {
    local snapshot_name="$1"
    local snapshot_file="$STATE_SNAPSHOT_DIR/${snapshot_name}.json"
    
    log_demo "STEP" "Capturing system state snapshot: $snapshot_name"
    
    mkdir -p "$STATE_SNAPSHOT_DIR"
    
    local capture_start=$(date +%s)
    local state_data=""
    
    # Capture comprehensive system state
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"git_state\": {"
        echo "    \"current_branch\": \"$(git branch --show-current 2>/dev/null || echo 'unknown')\","
        echo "    \"head_commit\": \"$(git rev-parse HEAD 2>/dev/null || echo 'unknown')\","
        echo "    \"uncommitted_changes\": $(git status --porcelain | wc -l),"
        echo "    \"last_commit_message\": \"$(git log -1 --pretty=format:'%s' 2>/dev/null || echo 'unknown')\""
        echo "  },"
        
        # Kubernetes state
        echo "  \"kubernetes_state\": {"
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "    \"cluster_accessible\": true,"
            echo "    \"namespaces\": $(kubectl get namespaces -o json 2>/dev/null | jq '[.items[].metadata.name]' || echo '[]'),"
            echo "    \"nodes\": $(kubectl get nodes -o json 2>/dev/null | jq '.items | length' || echo '0'),"
            echo "    \"pods_total\": $(kubectl get pods --all-namespaces 2>/dev/null | wc -l || echo '0'),"
            echo "    \"pods_running\": $(kubectl get pods --all-namespaces --field-selector=status.phase=Running 2>/dev/null | wc -l || echo '0')"
        else
            echo "    \"cluster_accessible\": false"
        fi
        echo "  },"
        
        # O2IMS specific state
        echo "  \"o2ims_state\": {"
        if kubectl get namespace o2ims >/dev/null 2>&1; then
            echo "    \"namespace_exists\": true,"
            echo "    \"pods\": $(kubectl get pods -n o2ims -o json 2>/dev/null | jq '[.items[].metadata.name]' || echo '[]'),"
            echo "    \"provisioningrequests\": $(kubectl get provisioningrequests -A -o json 2>/dev/null | jq '.items | length' || echo '0')"
        else
            echo "    \"namespace_exists\": false"
        fi
        echo "  },"
        
        # Porch state
        echo "  \"porch_state\": {"
        if kubectl get namespace porch-system >/dev/null 2>&1; then
            echo "    \"namespace_exists\": true,"
            echo "    \"pods\": $(kubectl get pods -n porch-system -o json 2>/dev/null | jq '[.items[].metadata.name]' || echo '[]'),"
            echo "    \"packagerevisions\": $(kubectl get packagerevisions -A 2>/dev/null | wc -l || echo '0')"
        else
            echo "    \"namespace_exists\": false"
        fi
        echo "  },"
        
        # Security state
        local sigstore_count=$(kubectl get pods -A 2>/dev/null | grep -c sigstore 2>/dev/null)
        local kyverno_count=$(kubectl get pods -A 2>/dev/null | grep -c kyverno 2>/dev/null)  
        local cert_manager_count=$(kubectl get pods -A 2>/dev/null | grep -c cert-manager 2>/dev/null)
        sigstore_count=${sigstore_count:-0}
        kyverno_count=${kyverno_count:-0}
        cert_manager_count=${cert_manager_count:-0}
        echo "  \"security_state\": {"
        echo "    \"sigstore_installed\": $sigstore_count,"
        echo "    \"kyverno_installed\": $kyverno_count,"
        echo "    \"cert_manager_installed\": $cert_manager_count"
        echo "  },"
        
        # File system state
        echo "  \"filesystem_state\": {"
        echo "    \"artifacts_exist\": $(test -d ./artifacts && echo 'true' || echo 'false'),"
        echo "    \"artifacts_count\": $(find ./artifacts -type f 2>/dev/null | wc -l || echo '0'),"
        echo "    \"reports_exist\": $(test -d ./reports && echo 'true' || echo 'false'),"
        echo "    \"reports_count\": $(find ./reports -type f 2>/dev/null | wc -l || echo '0')"
        echo "  }"
        echo "}"
    } > "$snapshot_file"
    
    local capture_end=$(date +%s)
    local capture_duration=$((capture_end - capture_start))
    
    if [[ -f "$snapshot_file" ]]; then
        log_demo "SUCCESS" "State snapshot captured: $snapshot_file (${capture_duration}s)"
        echo "$snapshot_file"
    else
        log_demo "ERROR" "Failed to capture state snapshot"
        return 1
    fi
}

# Compare two state snapshots and generate visual diff
generate_state_comparison() {
    local before_snapshot="$1"
    local after_snapshot="$2"
    local comparison_file="$ARTIFACTS_DIR/state-comparison.json"
    local diff_report="$ARTIFACTS_DIR/rollback-diff-report.html"
    
    log_demo "STEP" "Generating state comparison and visual diff"
    
    if [[ ! -f "$before_snapshot" ]] || [[ ! -f "$after_snapshot" ]]; then
        log_demo "ERROR" "Missing state snapshots for comparison"
        return 1
    fi
    
    # Generate JSON comparison
    {
        echo "{"
        echo "  \"comparison_metadata\": {"
        echo "    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "    \"before_snapshot\": \"$before_snapshot\","
        echo "    \"after_snapshot\": \"$after_snapshot\","
        echo "    \"rollback_strategy\": \"$ROLLBACK_STRATEGY\","
        echo "    \"rollback_reason\": \"$ROLLBACK_REASON\""
        echo "  },"
        
        # Extract and compare key metrics
        local before_git_commit=$(jq -r '.git_state.head_commit' "$before_snapshot")
        local after_git_commit=$(jq -r '.git_state.head_commit' "$after_snapshot")
        local before_k8s_pods=$(jq -r '.kubernetes_state.pods_running' "$before_snapshot")
        local after_k8s_pods=$(jq -r '.kubernetes_state.pods_running' "$after_snapshot")
        local before_artifacts=$(jq -r '.filesystem_state.artifacts_count' "$before_snapshot")
        local after_artifacts=$(jq -r '.filesystem_state.artifacts_count' "$after_snapshot")
        
        echo "  \"key_changes\": {"
        echo "    \"git_commit_changed\": $(if [[ "$before_git_commit" != "$after_git_commit" ]]; then echo 'true'; else echo 'false'; fi),"
        echo "    \"git_commit_before\": \"$before_git_commit\","
        echo "    \"git_commit_after\": \"$after_git_commit\","
        echo "    \"pods_running_delta\": $((after_k8s_pods - before_k8s_pods)),"
        echo "    \"artifacts_delta\": $((after_artifacts - before_artifacts))"
        echo "  },"
        
        echo "  \"detailed_comparison\": {"
        echo "    \"before_state\": $(cat "$before_snapshot"),"
        echo "    \"after_state\": $(cat "$after_snapshot")"
        echo "  }"
        echo "}"
    } > "$comparison_file"
    
    # Generate HTML visual diff report
    generate_html_diff_report "$diff_report" "$before_snapshot" "$after_snapshot"
    
    log_demo "SUCCESS" "State comparison generated: $comparison_file"
    log_demo "INFO" "Visual diff report: $diff_report"
    
    # Display key changes summary
    if [[ "$SHOW_VISUAL_DIFF" == "true" ]]; then
        display_changes_summary "$comparison_file"
    fi
}

# Generate HTML diff report for visual presentation
generate_html_diff_report() {
    local html_file="$1"
    local before_file="$2"
    local after_file="$3"
    
    cat > "$html_file" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nephio Demo Rollback - System State Comparison</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 3px solid #FF9800; padding-bottom: 20px; margin-bottom: 30px; }
        .comparison-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 30px; margin: 20px 0; }
        .state-panel { background: #f8f9fa; border: 2px solid #ddd; border-radius: 8px; padding: 20px; }
        .state-panel.before { border-color: #2196F3; } .state-panel.after { border-color: #4CAF50; }
        .state-title { font-weight: bold; font-size: 1.2em; margin-bottom: 15px; text-align: center; }
        .state-title.before { color: #2196F3; } .state-title.after { color: #4CAF50; }
        .metric { margin: 10px 0; padding: 10px; background: white; border-radius: 5px; display: flex; justify-content: space-between; }
        .changed { background: #fff3cd; border-left: 4px solid #ffc107; }
        .summary { background: #e1f5fe; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .impact-high { color: #d32f2f; font-weight: bold; }
        .impact-medium { color: #f57c00; font-weight: bold; }  
        .impact-low { color: #388e3c; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Nephio Demo Rollback Analysis</h1>
            <p>System State Comparison: Before vs After Rollback</p>
            <p class="timestamp">Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
        </div>
EOF

    # Extract key metrics for comparison
    local before_commit=$(jq -r '.git_state.head_commit' "$before_file" 2>/dev/null || echo "unknown")
    local after_commit=$(jq -r '.git_state.head_commit' "$after_file" 2>/dev/null || echo "unknown")
    local before_pods=$(jq -r '.kubernetes_state.pods_running' "$before_file" 2>/dev/null || echo "0")
    local after_pods=$(jq -r '.kubernetes_state.pods_running' "$after_file" 2>/dev/null || echo "0")
    local before_namespaces=$(jq -r '.kubernetes_state.namespaces | length' "$before_file" 2>/dev/null || echo "0")
    local after_namespaces=$(jq -r '.kubernetes_state.namespaces | length' "$after_file" 2>/dev/null || echo "0")
    
    # Add summary section
    cat >> "$html_file" <<EOF
        <div class="summary">
            <h2>📊 Rollback Impact Summary</h2>
            <div class="comparison-grid">
                <div>
                    <h3>Git Changes</h3>
                    <div class="metric $(if [[ "$before_commit" != "$after_commit" ]]; then echo 'changed'; fi)">
                        <span>Commit Hash:</span>
                        <span>${before_commit:0:8} → ${after_commit:0:8}</span>
                    </div>
                </div>
                <div>
                    <h3>Kubernetes Impact</h3>
                    <div class="metric $(if [[ "$before_pods" != "$after_pods" ]]; then echo 'changed'; fi)">
                        <span>Running Pods:</span>
                        <span>$before_pods → $after_pods</span>
                    </div>
                    <div class="metric $(if [[ "$before_namespaces" != "$after_namespaces" ]]; then echo 'changed'; fi)">
                        <span>Namespaces:</span>  
                        <span>$before_namespaces → $after_namespaces</span>
                    </div>
                </div>
            </div>
        </div>
        
        <h2>🔍 Detailed State Comparison</h2>
        <div class="comparison-grid">
            <div class="state-panel before">
                <div class="state-title before">📸 Before Rollback</div>
EOF

    # Add before state metrics
    jq -r '
        .git_state as $git |
        .kubernetes_state as $k8s |
        .o2ims_state as $o2ims |
        .filesystem_state as $fs |
        [
            "Git Branch: " + $git.current_branch,
            "Git Commit: " + ($git.head_commit // "unknown")[0:12],
            "Uncommitted Changes: " + ($git.uncommitted_changes | tostring),
            "K8s Cluster: " + (if $k8s.cluster_accessible then "Accessible" else "Not Accessible" end),
            "Total Pods: " + ($k8s.pods_total | tostring),
            "Running Pods: " + ($k8s.pods_running | tostring),
            "O2IMS Namespace: " + (if $o2ims.namespace_exists then "Exists" else "Missing" end),
            "Artifacts Count: " + ($fs.artifacts_count | tostring)
        ][] 
    ' "$before_file" 2>/dev/null | while read -r line; do
        echo "                <div class=\"metric\">$line</div>"
    done >> "$html_file"

    cat >> "$html_file" <<EOF
            </div>
            <div class="state-panel after">
                <div class="state-title after">✅ After Rollback</div>
EOF

    # Add after state metrics
    jq -r '
        .git_state as $git |
        .kubernetes_state as $k8s |
        .o2ims_state as $o2ims |
        .filesystem_state as $fs |
        [
            "Git Branch: " + $git.current_branch,
            "Git Commit: " + ($git.head_commit // "unknown")[0:12],
            "Uncommitted Changes: " + ($git.uncommitted_changes | tostring),
            "K8s Cluster: " + (if $k8s.cluster_accessible then "Accessible" else "Not Accessible" end),
            "Total Pods: " + ($k8s.pods_total | tostring),
            "Running Pods: " + ($k8s.pods_running | tostring),
            "O2IMS Namespace: " + (if $o2ims.namespace_exists then "Exists" else "Missing" end),
            "Artifacts Count: " + ($fs.artifacts_count | tostring)
        ][] 
    ' "$after_file" 2>/dev/null | while read -r line; do
        echo "                <div class=\"metric\">$line</div>"
    done >> "$html_file"

    cat >> "$html_file" <<'EOF'
            </div>
        </div>
        
        <div style="margin-top: 40px; text-align: center; color: #666;">
            <hr>
            <p>🔄 Generated by Nephio Demo Rollback System</p>
            <p><em>Automated rollback with comprehensive state analysis</em></p>
        </div>
    </div>
</body>
</html>
EOF
    
    log_demo "SUCCESS" "HTML diff report generated: $html_file"
}

# Display changes summary in terminal
display_changes_summary() {
    local comparison_file="$1"
    
    printf "\n${BOLD}${CYAN}📊 ROLLBACK IMPACT SUMMARY${NC}\n"
    printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    if [[ -f "$comparison_file" ]]; then
        local git_changed=$(jq -r '.key_changes.git_commit_changed' "$comparison_file" 2>/dev/null || echo 'false')
        local before_commit=$(jq -r '.key_changes.git_commit_before' "$comparison_file" 2>/dev/null || echo 'unknown')
        local after_commit=$(jq -r '.key_changes.git_commit_after' "$comparison_file" 2>/dev/null || echo 'unknown')
        local pods_delta=$(jq -r '.key_changes.pods_running_delta' "$comparison_file" 2>/dev/null || echo '0')
        local artifacts_delta=$(jq -r '.key_changes.artifacts_delta' "$comparison_file" 2>/dev/null || echo '0')
        
        # Git changes
        if [[ "$git_changed" == "true" ]]; then
            printf "${YELLOW}🔄 Git State:${NC}     ${before_commit:0:8} → ${after_commit:0:8} ${GREEN}(CHANGED)${NC}\n"
        else
            printf "${BLUE}🔄 Git State:${NC}     ${before_commit:0:8} ${CYAN}(UNCHANGED)${NC}\n"
        fi
        
        # Kubernetes changes
        if [[ "$pods_delta" -ne 0 ]]; then
            if [[ "$pods_delta" -gt 0 ]]; then
                printf "${YELLOW}☸️  Kubernetes:${NC}    +${pods_delta} pods ${GREEN}(INCREASED)${NC}\n"
            else
                printf "${YELLOW}☸️  Kubernetes:${NC}    ${pods_delta} pods ${RED}(DECREASED)${NC}\n"
            fi
        else
            printf "${BLUE}☸️  Kubernetes:${NC}    No pod changes ${CYAN}(STABLE)${NC}\n"
        fi
        
        # Artifacts changes
        if [[ "$artifacts_delta" -ne 0 ]]; then
            if [[ "$artifacts_delta" -gt 0 ]]; then
                printf "${YELLOW}📁 Artifacts:${NC}     +${artifacts_delta} files ${GREEN}(ADDED)${NC}\n"
            else
                printf "${YELLOW}📁 Artifacts:${NC}     ${artifacts_delta} files ${RED}(REMOVED)${NC}\n"
            fi
        else
            printf "${BLUE}📁 Artifacts:${NC}     No file changes ${CYAN}(STABLE)${NC}\n"
        fi
    else
        printf "${RED}❌ Could not read comparison file${NC}\n"
    fi
    
    printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
}

# Execute rollback with timing and action tracking
execute_rollback() {
    log_demo "STEP" "Executing rollback strategy: $ROLLBACK_STRATEGY"
    
    local rollback_start=$(date +%s)
    local action_count=0
    
    case "$ROLLBACK_STRATEGY" in
        "revert"|"reset")
            # Use the existing rollback script
            log_demo "INFO" "Delegating to rollback.sh with strategy: $ROLLBACK_STRATEGY"
            
            if [[ "$DRY_RUN" == "true" ]]; then
                DRY_RUN=true ROLLBACK_STRATEGY="$ROLLBACK_STRATEGY" ./scripts/rollback.sh "$ROLLBACK_REASON"
            else
                ROLLBACK_STRATEGY="$ROLLBACK_STRATEGY" ./scripts/rollback.sh "$ROLLBACK_REASON"
            fi
            
            ROLLBACK_ACTIONS+=("git-$ROLLBACK_STRATEGY")
            action_count=1
            ;;
            
        "demonstrate")
            # Demo-specific rollback actions
            log_demo "INFO" "Performing demonstration rollback actions"
            
            # Clean artifacts
            if [[ -d "./artifacts" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_demo "INFO" "[DRY-RUN] Would clean artifacts directory"
                else
                    rm -rf ./artifacts/*
                    mkdir -p ./artifacts
                    log_demo "INFO" "Cleaned artifacts directory"
                fi
                ROLLBACK_ACTIONS+=("clean-artifacts")
                action_count=$((action_count + 1))
            fi
            
            # Reset demo state files
            local demo_state_files=(".postcheck.conf" ".rollback.conf" "demo-checkpoint.json")
            for state_file in "${demo_state_files[@]}"; do
                if [[ -f "$state_file" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_demo "INFO" "[DRY-RUN] Would remove state file: $state_file"
                    else
                        rm -f "$state_file"
                        log_demo "INFO" "Removed state file: $state_file"
                    fi
                    ROLLBACK_ACTIONS+=("remove-state-$state_file")
                    action_count=$((action_count + 1))
                fi
            done
            
            # Optional: Clean Kubernetes demo namespaces (be careful in real environments)
            local demo_namespaces=("demo-test" "demo-workloads")
            for ns in "${demo_namespaces[@]}"; do
                if kubectl get namespace "$ns" >/dev/null 2>&1; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_demo "INFO" "[DRY-RUN] Would delete namespace: $ns"
                    else
                        kubectl delete namespace "$ns" --timeout=60s || true
                        log_demo "INFO" "Deleted demo namespace: $ns"
                    fi
                    ROLLBACK_ACTIONS+=("delete-namespace-$ns")
                    action_count=$((action_count + 1))
                fi
            done
            ;;
            
        *)
            log_demo "ERROR" "Unknown rollback strategy: $ROLLBACK_STRATEGY"
            return 1
            ;;
    esac
    
    local rollback_end=$(date +%s)
    local rollback_duration=$((rollback_end - rollback_start))
    ROLLBACK_TIMINGS+=("total:${rollback_duration}s")
    
    log_demo "SUCCESS" "Rollback completed: $action_count actions in ${rollback_duration}s"
    return 0
}

# Generate comprehensive rollback report
generate_rollback_audit_report() {
    local report_file="$ARTIFACTS_DIR/rollback-audit-report.json"
    local html_report="$ARTIFACTS_DIR/rollback-audit-report.html"
    
    log_demo "STEP" "Generating rollback audit report"
    
    # JSON audit report
    cat > "$report_file" <<EOF
{
  "rollback_execution": {
    "timestamp": "$SCRIPT_START_TIME",
    "strategy": "$ROLLBACK_STRATEGY", 
    "reason": "$ROLLBACK_REASON",
    "dry_run": $DRY_RUN,
    "script_version": "$SCRIPT_VERSION",
    "operator": "$(whoami)",
    "hostname": "$(hostname)"
  },
  "actions_performed": [
$(printf '%s\n' "${ROLLBACK_ACTIONS[@]}" | jq -R . | paste -sd, -)
  ],
  "timings": [
$(printf '%s\n' "${ROLLBACK_TIMINGS[@]}" | jq -R . | paste -sd, -)
  ],
  "state_snapshots": {
    "before_snapshot": "$BEFORE_STATE",
    "after_snapshot": "$AFTER_STATE"
  },
  "artifacts_generated": {
    "audit_report": "$report_file",
    "html_report": "$html_report",
    "state_comparison": "$ARTIFACTS_DIR/state-comparison.json",
    "visual_diff": "$ARTIFACTS_DIR/rollback-diff-report.html"
  }
}
EOF
    
    # HTML audit report
    generate_html_audit_report "$html_report"
    
    log_demo "SUCCESS" "Rollback audit report generated: $report_file"
    log_demo "INFO" "HTML audit report: $html_report"
}

# Generate HTML audit report  
generate_html_audit_report() {
    local html_file="$1"
    
    cat > "$html_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Nephio Demo Rollback - Audit Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 3px solid #FF9800; padding-bottom: 20px; margin-bottom: 30px; }
        .section { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .action-list { list-style: none; padding: 0; }
        .action-item { background: white; margin: 5px 0; padding: 10px; border-radius: 5px; border-left: 4px solid #FF9800; }
        .metadata { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .metadata-item { background: white; padding: 15px; border-radius: 8px; text-align: center; }
        .success { color: #4CAF50; } .info { color: #2196F3; } .warning { color: #FF9800; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Nephio Demo Rollback Audit Report</h1>
            <p class="info">Comprehensive rollback execution analysis</p>
            <p>Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
        </div>
        
        <div class="section">
            <h2>📊 Rollback Metadata</h2>
            <div class="metadata">
                <div class="metadata-item">
                    <strong>Strategy</strong><br>
                    <span class="info">$ROLLBACK_STRATEGY</span>
                </div>
                <div class="metadata-item">
                    <strong>Reason</strong><br>
                    <span>$ROLLBACK_REASON</span>
                </div>
                <div class="metadata-item">
                    <strong>Mode</strong><br>
                    <span>$(if [[ "$DRY_RUN" == "true" ]]; then echo "DRY-RUN"; else echo "EXECUTION"; fi)</span>
                </div>
                <div class="metadata-item">
                    <strong>Actions</strong><br>
                    <span class="success">${#ROLLBACK_ACTIONS[@]}</span>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>⚡ Actions Performed</h2>
            <ul class="action-list">
EOF

    # Add rollback actions
    for action in "${ROLLBACK_ACTIONS[@]}"; do
        echo "                <li class=\"action-item\">✓ $action</li>" >> "$html_file"
    done

    cat >> "$html_file" <<'EOF'
            </ul>
        </div>
        
        <div class="section">
            <h2>🔗 Related Artifacts</h2>
            <ul>
                <li><strong>State Comparison:</strong> state-comparison.json</li>
                <li><strong>Visual Diff:</strong> rollback-diff-report.html</li>
                <li><strong>Before Snapshot:</strong> state-snapshots/before.json</li>
                <li><strong>After Snapshot:</strong> state-snapshots/after.json</li>
            </ul>
        </div>
        
        <div style="margin-top: 40px; text-align: center; color: #666;">
            <hr>
            <p>🔄 Generated by Nephio Demo Rollback System</p>
            <p><em>Automated rollback with comprehensive audit trail</em></p>
        </div>
    </div>
</body>
</html>
EOF

    log_demo "SUCCESS" "HTML audit report generated: $html_file"
}

# Show success summary
show_rollback_success() {
    printf "\n${BOLD}${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  ✅ ROLLBACK COMPLETED SUCCESSFULLY                                  ║
║                                                                      ║
║  🔄 System state has been reverted                                  ║
║  📊 Before/after comparison generated                               ║
║  📋 Comprehensive audit trail created                               ║
║  🎯 Ready for next demonstration cycle                              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n\n"
    
    printf "${BOLD}${CYAN}📁 Generated Reports:${NC}\n"
    if [[ -d "$ARTIFACTS_DIR" ]]; then
        find "$ARTIFACTS_DIR" -type f \( -name "*.json" -o -name "*.html" \) | while read -r file; do
            printf "   📄 %s\n" "$file"
        done
    fi
    
    printf "\n${BOLD}${CYAN}🔍 Next Steps:${NC}\n"
    printf "   • View rollback analysis: ${CYAN}open %s/rollback-diff-report.html${NC}\n" "$ARTIFACTS_DIR"
    printf "   • Check audit report: ${CYAN}open %s/rollback-audit-report.html${NC}\n" "$ARTIFACTS_DIR"
    printf "   • Run demo again: ${CYAN}make demo${NC}\n\n"
}

# Main rollback execution
main() {
    local start_time=$(date +%s)
    
    # Setup
    show_rollback_banner
    mkdir -p "$ARTIFACTS_DIR" "$STATE_SNAPSHOT_DIR"
    
    log_demo "INFO" "Demo rollback starting"
    log_demo "INFO" "Strategy: $ROLLBACK_STRATEGY | Reason: $ROLLBACK_REASON"
    log_demo "INFO" "Artifacts: $ARTIFACTS_DIR | DRY_RUN: $DRY_RUN"
    
    # Capture before state
    BEFORE_STATE=$(capture_system_state "before")
    if [[ $? -ne 0 ]]; then
        log_demo "ERROR" "Failed to capture before state"
        exit $EXIT_STATE_CAPTURE_FAILED
    fi
    
    # Execute rollback
    if ! execute_rollback; then
        log_demo "ERROR" "Rollback execution failed"
        exit $EXIT_ROLLBACK_FAILED
    fi
    
    # Capture after state
    AFTER_STATE=$(capture_system_state "after")
    if [[ $? -ne 0 ]]; then
        log_demo "ERROR" "Failed to capture after state"  
        exit $EXIT_STATE_CAPTURE_FAILED
    fi
    
    # Generate reports
    if [[ "$GENERATE_REPORTS" == "true" ]]; then
        generate_state_comparison "$BEFORE_STATE" "$AFTER_STATE"
        generate_rollback_audit_report
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    ROLLBACK_TIMINGS+=("total_execution:${total_duration}s")
    
    show_rollback_success
    log_demo "SUCCESS" "Demo rollback completed in ${total_duration}s"
    exit $EXIT_SUCCESS
}

# Usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Comprehensive rollback system with before/after state comparison for demo purposes.

OPTIONS:
    -h, --help                   Show this help message
    -d, --dry-run               Perform dry run (show what would be executed)
    -s, --strategy STRATEGY     Rollback strategy: revert|reset|demonstrate (default: revert)
    -r, --reason REASON         Rollback reason (default: demo-rollback)
    -m, --mode MODE             Demo mode: presentation|development|debug (default: presentation)
    --no-reports                Skip report generation
    --no-visual-diff            Skip visual diff display
    --artifacts-dir DIR         Artifacts directory (default: ./artifacts/demo-rollback)

ROLLBACK STRATEGIES:
    revert        Git revert (preserves history)
    reset         Git reset to main branch (clean rollback)  
    demonstrate   Demo-specific cleanup (artifacts, namespaces)

ENVIRONMENT VARIABLES:
    ROLLBACK_STRATEGY     Rollback strategy
    ROLLBACK_REASON       Reason for rollback
    DEMO_MODE             Demo execution mode
    DRY_RUN               Enable dry-run mode
    ARTIFACTS_DIR         Artifacts output directory

EXAMPLES:
    $SCRIPT_NAME                                    # Basic revert rollback
    $SCRIPT_NAME --dry-run --strategy reset        # Dry-run reset rollback
    $SCRIPT_NAME --strategy demonstrate            # Demo cleanup rollback
    
    ROLLBACK_STRATEGY=reset $SCRIPT_NAME           # Environment variable override

OUTPUTS:
    • Before/after state snapshots (JSON)
    • Visual diff comparison (HTML)
    • Rollback audit report (JSON + HTML)
    • Action timing and impact analysis
    • Terminal-based summary display

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
        -s|--strategy)
            ROLLBACK_STRATEGY="$2"
            shift 2
            ;;
        -r|--reason)
            ROLLBACK_REASON="$2"
            shift 2
            ;;
        -m|--mode)
            DEMO_MODE="$2"
            shift 2
            ;;
        --no-reports)
            GENERATE_REPORTS="false"
            shift
            ;;
        --no-visual-diff)
            SHOW_VISUAL_DIFF="false"
            shift
            ;;
        --artifacts-dir)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        *)
            log_demo "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate rollback strategy
case "$ROLLBACK_STRATEGY" in
    "revert"|"reset"|"demonstrate")
        # Valid strategies
        ;;
    *)
        log_demo "ERROR" "Invalid rollback strategy: $ROLLBACK_STRATEGY"
        log_demo "INFO" "Valid strategies: revert, reset, demonstrate"
        exit 1
        ;;
esac

# Execute main function
main "$@"