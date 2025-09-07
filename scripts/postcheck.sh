#!/bin/bash
set -euo pipefail

# postcheck.sh - SLO-gated deployment validation
# Waits for RootSync reconciliation and validates VM-2 observability metrics

# Configuration with defaults
ROOTSYNC_NAME="${ROOTSYNC_NAME:-intent-to-o2-rootsync}"
ROOTSYNC_NAMESPACE="${ROOTSYNC_NAMESPACE:-config-management-system}"
VM2_OBSERVABILITY_HOST="${VM2_OBSERVABILITY_HOST:-172.16.4.45}"
VM2_OBSERVABILITY_PORT="${VM2_OBSERVABILITY_PORT:-30090}"
VM2_METRICS_PATH="${VM2_METRICS_PATH:-/metrics/api/v1/slo}"

# SLO Thresholds (from project requirements)
LATENCY_P95_THRESHOLD_MS="${LATENCY_P95_THRESHOLD_MS:-15}"
SUCCESS_RATE_THRESHOLD="${SUCCESS_RATE_THRESHOLD:-0.995}"
THROUGHPUT_P95_THRESHOLD_MBPS="${THROUGHPUT_P95_THRESHOLD_MBPS:-200}"

# Timeouts
ROOTSYNC_TIMEOUT_SECONDS="${ROOTSYNC_TIMEOUT_SECONDS:-600}"
VM2_METRICS_TIMEOUT_SECONDS="${VM2_METRICS_TIMEOUT_SECONDS:-30}"

# Logging configuration
LOG_JSON="${LOG_JSON:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Load configuration file if exists
if [[ -f ".postcheck.conf" ]]; then
    source ".postcheck.conf"
fi

# Exit codes
EXIT_SUCCESS=0
EXIT_ROOTSYNC_TIMEOUT=1
EXIT_VM2_UNREACHABLE=2
EXIT_SLO_VIOLATION=3
EXIT_DEPENDENCY_MISSING=4
EXIT_CONFIG_ERROR=5

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    if [[ "$LOG_JSON" == "true" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"postcheck\"}"
    else
        echo "[$timestamp] [$level] $message"
    fi
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    for dep in kubectl curl jq; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit $EXIT_DEPENDENCY_MISSING
    fi
}

# Wait for RootSync reconciliation using 2025 best practices
wait_for_rootsync_reconciliation() {
    log_info "Waiting for RootSync '$ROOTSYNC_NAME' reconciliation (timeout: ${ROOTSYNC_TIMEOUT_SECONDS}s)"
    
    local start_time=$(date +%s)
    local timeout_time=$((start_time + ROOTSYNC_TIMEOUT_SECONDS))
    
    while [[ $(date +%s) -lt $timeout_time ]]; do
        # Check if ResourceGroup exists (more reliable than RootSync direct checking)
        if kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" &> /dev/null; then
            # Check ResourceGroup Stalled condition
            local stalled_status=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "")
            
            # Check if observedGeneration matches generation
            local observed_gen=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.observedGeneration}' 2>/dev/null || echo "")
            local current_gen=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.metadata.generation}' 2>/dev/null || echo "")
            
            if [[ "$stalled_status" == "False" ]] && [[ "$observed_gen" == "$current_gen" ]] && [[ -n "$observed_gen" ]]; then
                # Double-check RootSync sync status
                local sync_commit=$(kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                    -o jsonpath='{.status.sync.commit}' 2>/dev/null || echo "")
                local source_commit=$(kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                    -o jsonpath='{.status.source.commit}' 2>/dev/null || echo "")
                
                if [[ "$sync_commit" == "$source_commit" ]] && [[ -n "$sync_commit" ]]; then
                    log_info "RootSync reconciliation completed successfully"
                    log_info "ResourceGroup generation: $current_gen, observed: $observed_gen"
                    log_info "Sync commit: $sync_commit"
                    return 0
                fi
            fi
        else
            # Fall back to direct RootSync checking if ResourceGroup doesn't exist
            log_warn "ResourceGroup not found, checking RootSync directly"
            local reconciling_status=$(kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Reconciling")].status}' 2>/dev/null || echo "")
            local stalled_status=$(kubectl get rootsync "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "")
            
            if [[ "$reconciling_status" == "False" ]] && [[ "$stalled_status" == "False" ]]; then
                log_info "RootSync reconciliation completed (fallback check)"
                return 0
            fi
        fi
        
        log_info "RootSync still reconciling... (stalled: $stalled_status)"
        sleep 10
    done
    
    log_error "RootSync reconciliation timeout after ${ROOTSYNC_TIMEOUT_SECONDS} seconds"
    return $EXIT_ROOTSYNC_TIMEOUT
}

# Fetch and validate VM-2 observability metrics
validate_vm2_observability() {
    local vm2_endpoint="http://${VM2_OBSERVABILITY_HOST}:${VM2_OBSERVABILITY_PORT}${VM2_METRICS_PATH}"
    log_info "Fetching observability metrics from $vm2_endpoint"
    
    # Fetch metrics with timeout
    local metrics_response
    if ! metrics_response=$(curl -s --max-time "$VM2_METRICS_TIMEOUT_SECONDS" "$vm2_endpoint" 2>/dev/null); then
        log_error "Failed to reach VM-2 observability endpoint: $vm2_endpoint"
        return $EXIT_VM2_UNREACHABLE
    fi
    
    # Validate JSON response
    if ! echo "$metrics_response" | jq . &> /dev/null; then
        log_error "Invalid JSON response from VM-2 observability endpoint"
        return $EXIT_VM2_UNREACHABLE
    fi
    
    log_info "Successfully fetched VM-2 metrics"
    
    # Extract SLO metrics
    local latency_p95=$(echo "$metrics_response" | jq -r '.slo.latency_p95_ms // empty')
    local success_rate=$(echo "$metrics_response" | jq -r '.slo.success_rate // empty')
    local throughput_p95=$(echo "$metrics_response" | jq -r '.slo.throughput_p95_mbps // empty')
    
    # Log current metrics
    log_info "Current SLO metrics: latency_p95=${latency_p95}ms, success_rate=${success_rate}, throughput_p95=${throughput_p95}Mbps"
    
    # Validate SLO thresholds
    local violations=()
    
    if [[ -n "$latency_p95" ]] && (( $(echo "$latency_p95 > $LATENCY_P95_THRESHOLD_MS" | bc -l) )); then
        violations+=("latency_p95: ${latency_p95}ms > ${LATENCY_P95_THRESHOLD_MS}ms")
    fi
    
    if [[ -n "$success_rate" ]] && (( $(echo "$success_rate < $SUCCESS_RATE_THRESHOLD" | bc -l) )); then
        violations+=("success_rate: ${success_rate} < ${SUCCESS_RATE_THRESHOLD}")
    fi
    
    if [[ -n "$throughput_p95" ]] && (( $(echo "$throughput_p95 < $THROUGHPUT_P95_THRESHOLD_MBPS" | bc -l) )); then
        violations+=("throughput_p95: ${throughput_p95}Mbps < ${THROUGHPUT_P95_THRESHOLD_MBPS}Mbps")
    fi
    
    # Check for missing metrics
    if [[ -z "$latency_p95" || -z "$success_rate" || -z "$throughput_p95" ]]; then
        log_warn "Some SLO metrics are missing from VM-2 response"
        violations+=("missing_metrics: latency_p95=${latency_p95:-missing}, success_rate=${success_rate:-missing}, throughput_p95=${throughput_p95:-missing}")
    fi
    
    if [[ ${#violations[@]} -gt 0 ]]; then
        log_error "SLO violations detected:"
        for violation in "${violations[@]}"; do
            log_error "  - $violation"
        done
        return $EXIT_SLO_VIOLATION
    fi
    
    log_info "All SLO thresholds met successfully"
    return 0
}

# Main execution
main() {
    log_info "Starting postcheck validation"
    log_info "RootSync: $ROOTSYNC_NAME (namespace: $ROOTSYNC_NAMESPACE)"
    log_info "VM-2 endpoint: ${VM2_OBSERVABILITY_HOST}:${VM2_OBSERVABILITY_PORT}${VM2_METRICS_PATH}"
    log_info "SLO thresholds: latency≤${LATENCY_P95_THRESHOLD_MS}ms, success≥${SUCCESS_RATE_THRESHOLD}, throughput≥${THROUGHPUT_P95_THRESHOLD_MBPS}Mbps"
    
    # Check dependencies
    check_dependencies
    
    # Wait for RootSync reconciliation
    if ! wait_for_rootsync_reconciliation; then
        log_error "RootSync reconciliation failed"
        exit $EXIT_ROOTSYNC_TIMEOUT
    fi
    
    # Validate VM-2 observability metrics
    if ! validate_vm2_observability; then
        log_error "VM-2 observability validation failed"
        exit $?  # Preserve specific exit code from validate_vm2_observability
    fi
    
    log_info "Postcheck validation completed successfully"
    log_info "✅ PASS: RootSync reconciled and all SLO thresholds met"
    exit $EXIT_SUCCESS
}

# Handle script interruption
trap 'log_error "Postcheck interrupted"; exit 130' INT TERM

# Execute main function
main "$@"