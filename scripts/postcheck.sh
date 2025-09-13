#!/bin/bash
set -euo pipefail

# postcheck.sh - Multi-site SLO-gated deployment validation
# Supports edge1 and edge2 clusters with O2IMS Measurement preference

# Configuration with defaults
ROOTSYNC_NAME="${ROOTSYNC_NAME:-intent-to-o2-rootsync}"
ROOTSYNC_NAMESPACE="${ROOTSYNC_NAMESPACE:-config-management-system}"

# Multi-site configuration (both VM-2 and VM-4 ready)
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="172.16.0.89:30090/metrics/api/v1/slo"
)

# O2IMS Measurement API endpoints (both VM-2 and VM-4 ready)
declare -A O2IMS_SITES=(
    [edge1]="http://172.16.4.45:31280/o2ims/measurement/v1/slo"
    [edge2]="http://172.16.0.89:31280/o2ims/measurement/v1/slo"
)

# SLO Thresholds (from project requirements)
LATENCY_P95_THRESHOLD_MS="${LATENCY_P95_THRESHOLD_MS:-15}"
SUCCESS_RATE_THRESHOLD="${SUCCESS_RATE_THRESHOLD:-0.995}"
THROUGHPUT_P95_THRESHOLD_MBPS="${THROUGHPUT_P95_THRESHOLD_MBPS:-200}"

# Timeouts
ROOTSYNC_TIMEOUT_SECONDS="${ROOTSYNC_TIMEOUT_SECONDS:-600}"
METRICS_TIMEOUT_SECONDS="${METRICS_TIMEOUT_SECONDS:-30}"

# Logging configuration
LOG_JSON="${LOG_JSON:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Report configuration
REPORT_DIR="${REPORT_DIR:-reports/$(date +%Y%m%d_%H%M%S)}"
REPORT_FILE="${REPORT_DIR}/postcheck_report.json"

# Exit codes
EXIT_SUCCESS=0
EXIT_ROOTSYNC_TIMEOUT=1
EXIT_METRICS_UNREACHABLE=2
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

    for dep in kubectl curl jq mkdir; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit $EXIT_DEPENDENCY_MISSING
    fi
}

# Wait for RootSync reconciliation
wait_for_rootsync_reconciliation() {
    log_info "Waiting for RootSync '$ROOTSYNC_NAME' reconciliation (timeout: ${ROOTSYNC_TIMEOUT_SECONDS}s)"

    local start_time=$(date +%s)
    local timeout_time=$((start_time + ROOTSYNC_TIMEOUT_SECONDS))

    local stalled_status="unknown"

    while [[ $(date +%s) -lt $timeout_time ]]; do
        if kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" &> /dev/null; then
            stalled_status=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "unknown")

            local observed_gen=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.observedGeneration}' 2>/dev/null || echo "")
            local current_gen=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.metadata.generation}' 2>/dev/null || echo "")

            if [[ "$stalled_status" == "False" ]] && [[ "$observed_gen" == "$current_gen" ]] && [[ -n "$observed_gen" ]]; then
                log_info "RootSync reconciliation completed successfully"
                return 0
            fi
        else
            stalled_status="not_found"
        fi

        log_info "RootSync still reconciling... (stalled: $stalled_status)"
        sleep 10
    done

    log_error "RootSync reconciliation timeout after ${ROOTSYNC_TIMEOUT_SECONDS} seconds"
    return $EXIT_ROOTSYNC_TIMEOUT
}

# Fetch O2IMS Measurement metrics
fetch_o2ims_metrics() {
    local site="$1"
    local o2ims_endpoint="${O2IMS_SITES[$site]}"
    log_info "Attempting to fetch O2IMS Measurement metrics for $site"

    local metrics_response
    if metrics_response=$(curl -s --max-time "$METRICS_TIMEOUT_SECONDS" "$o2ims_endpoint" 2>/dev/null); then
        echo "$metrics_response"
        return 0
    fi

    log_warn "O2IMS Measurement metrics unavailable for $site"
    return 1
}

# Fetch SLO metrics from standard endpoint
fetch_slo_metrics() {
    local site="$1"
    local slo_endpoint="http://${SITES[$site]}"
    log_info "Fetching SLO metrics from $slo_endpoint"

    local metrics_response
    if ! metrics_response=$(curl -s --max-time "$METRICS_TIMEOUT_SECONDS" "$slo_endpoint" 2>/dev/null); then
        log_error "Failed to reach SLO endpoint for $site: $slo_endpoint"
        return $EXIT_METRICS_UNREACHABLE
    fi

    if ! echo "$metrics_response" | jq . &> /dev/null; then
        log_error "Invalid JSON response from $site SLO endpoint"
        return $EXIT_METRICS_UNREACHABLE
    fi

    echo "$metrics_response"
    return 0
}

# Validate SLO metrics for a site
validate_site_metrics() {
    local site="$1"
    local metrics_response="$2"
    local violations=()

    # Extract metrics
    local latency_p95=$(echo "$metrics_response" | jq -r '.slo.latency_p95_ms // empty')
    local success_rate=$(echo "$metrics_response" | jq -r '.slo.success_rate // empty')
    local throughput_p95=$(echo "$metrics_response" | jq -r '.slo.throughput_p95_mbps // empty')

    log_info "[$site] Current SLO metrics: latency_p95=${latency_p95}ms, success_rate=${success_rate}, throughput_p95=${throughput_p95}Mbps"

    # Validate thresholds
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
        log_warn "[$site] Some SLO metrics are missing"
        violations+=("missing_metrics: latency_p95=${latency_p95:-missing}, success_rate=${success_rate:-missing}, throughput_p95=${throughput_p95:-missing}")
    fi

    if [[ ${#violations[@]} -gt 0 ]]; then
        log_error "[$site] SLO violations detected:"
        for violation in "${violations[@]}"; do
            log_error "  - $violation"
        done
        return $EXIT_SLO_VIOLATION
    fi

    log_info "[$site] All SLO thresholds met successfully"
    return 0
}

# Generate postcheck report
generate_report() {
    local report_data="$1"

    mkdir -p "$REPORT_DIR"
    echo "$report_data" | jq . > "$REPORT_FILE"
    log_info "Postcheck report generated: $REPORT_FILE"
}

# Main execution
main() {
    log_info "Starting multi-site postcheck validation"

    # Check dependencies
    check_dependencies

    # Wait for RootSync reconciliation
    if ! wait_for_rootsync_reconciliation; then
        log_error "RootSync reconciliation failed"
        exit $EXIT_ROOTSYNC_TIMEOUT
    fi

    # Initialize report data
    local report_sites=()
    local overall_status="PASS"
    local site_status

    # Process each site
    for site in "${!SITES[@]}"; do
        local metrics_response

        # Prefer O2IMS Measurement API if available
        if ! metrics_response=$(fetch_o2ims_metrics "$site"); then
            # Fallback to standard metrics endpoint
            if ! metrics_response=$(fetch_slo_metrics "$site"); then
                log_error "[$site] Unable to fetch metrics"
                site_status="FAIL"
                overall_status="FAIL"
                continue
            fi
        fi

        # Validate site metrics
        if ! validate_site_metrics "$site" "$metrics_response"; then
            log_error "[$site] SLO validation failed"
            site_status="FAIL"
            overall_status="FAIL"
        else
            site_status="PASS"
        fi

        # Build site report
        local site_report=$(echo "$metrics_response" | jq --arg site "$site" --arg status "$site_status" '{
            site: $site,
            status: $status,
            metrics: .slo
        }')

        report_sites+=("$site_report")
    done

    # Prepare final report
    local final_report=$(jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
        --arg status "$overall_status" \
        --argjson sites "$(printf '%s\n' "${report_sites[@]}" | jq -s '.')" \
        '{
            timestamp: $timestamp,
            status: $status,
            sites: $sites
        }')

    # Generate report
    generate_report "$final_report"

    # Final status check
    if [[ "$overall_status" == "FAIL" ]]; then
        log_error "One or more sites failed SLO validation"
        exit $EXIT_SLO_VIOLATION
    fi

    log_info "✅ Postcheck validation completed successfully"
    log_info "✅ PASS: RootSync reconciled and all site SLO thresholds met"
    exit $EXIT_SUCCESS
}

# Handle script interruption
trap 'log_error "Postcheck interrupted"; exit 130' INT TERM

# Execute main function
main "$@"