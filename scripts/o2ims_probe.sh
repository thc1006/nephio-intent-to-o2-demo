#!/bin/bash
set -euo pipefail

# o2ims_probe.sh - Multi-site O2IMS Infrastructure Management System Probe
# Supports probing edge1 and edge2 clusters with comprehensive health checks

# Sites configuration (both VM-2 and VM-4 ready)
declare -A SITES=(
    [edge1]="http://172.16.4.45:31280"
    [edge2]="http://172.16.4.176:31280"
)

# Configuration defaults
LOG_JSON="${LOG_JSON:-false}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"
PROBE_INTERVAL="${PROBE_INTERVAL:-60}"

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    if [[ "$LOG_JSON" == "true" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"o2ims-probe\"}"
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

    for dep in curl jq; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Probe a single site's O2IMS endpoint
probe_site() {
    local site="$1"
    local endpoint="${SITES[$site]}"
    local status="UNKNOWN"
    local probe_details=""

    log_info "Probing $site O2IMS endpoint: $endpoint"

    # Probe O2IMS main endpoint
    local response
    local http_code
    response=$(curl -s -w "%{http_code}" -o /dev/null --max-time "$TIMEOUT_SECONDS" "$endpoint" 2>/dev/null)
    http_code=$?

    if [[ "$response" == "200" ]]; then
        status="HEALTHY"
        probe_details="Main endpoint responded successfully"
    elif [[ "$http_code" -ne 0 ]]; then
        status="UNHEALTHY"
        probe_details="Connection error: $(curl -s --max-time "$TIMEOUT_SECONDS" "$endpoint" 2>&1)"
    else
        status="UNHEALTHY"
        probe_details="Unexpected HTTP status code: $response"
    fi

    # Check additional O2IMS API endpoints if main endpoint is healthy
    if [[ "$status" == "HEALTHY" ]]; then
        local endpoints=(
            "/o2ims/v1/resourcePools"
            "/o2ims/v1/resources"
            "/o2ims/measurement/v1/slo"
        )

        for sub_endpoint in "${endpoints[@]}"; do
            local sub_response
            sub_response=$(curl -s --max-time "$TIMEOUT_SECONDS" "${endpoint}${sub_endpoint}" 2>/dev/null)
            if [[ -z "$sub_response" ]] || ! echo "$sub_response" | jq . &> /dev/null; then
                status="DEGRADED"
                probe_details+=" | Sub-endpoint $sub_endpoint failed validation"
            fi
        done
    fi

    # Prepare probe result
    local probe_result=$(jq -n \
        --arg site "$site" \
        --arg status "$status" \
        --arg details "$probe_details" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
        '{
            site: $site,
            status: $status,
            details: $details,
            timestamp: $timestamp
        }')

    echo "$probe_result"
}

# Generate comprehensive probe report
generate_probe_report() {
    local probe_results=("$@")
    local overall_status="HEALTHY"

    # Determine overall status
    for result in "${probe_results[@]}"; do
        local status=$(echo "$result" | jq -r '.status')
        if [[ "$status" == "UNHEALTHY" ]]; then
            overall_status="UNHEALTHY"
            break
        elif [[ "$status" == "DEGRADED" ]]; then
            overall_status="DEGRADED"
        fi
    done

    local final_report=$(jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
        --arg status "$overall_status" \
        --argjson sites "$(printf '%s\n' "${probe_results[@]}" | jq -s '.')" \
        '{
            timestamp: $timestamp,
            status: $status,
            sites: $sites
        }')

    # Output to reports directory
    local report_dir="reports/o2ims/$(date +%Y%m%d)"
    mkdir -p "$report_dir"
    echo "$final_report" | jq . > "$report_dir/probe_report.json"

    echo "$final_report"
}

# Main execution
main() {
    log_info "Starting O2IMS Multi-Site Probe"

    # Check dependencies
    check_dependencies

    # Probe results container
    local probe_results=()

    # Probe each site
    for site in "${!SITES[@]}"; do
        local result
        result=$(probe_site "$site")
        probe_results+=("$result")

        # Log individual site probe result
        echo "$result" | jq -r '"Site " + .site + " status: " + .status + " - " + .details'
    done

    # Generate comprehensive report
    local final_report
    final_report=$(generate_probe_report "${probe_results[@]}")

    # Check final status
    local overall_status
    overall_status=$(echo "$final_report" | jq -r '.status')

    if [[ "$overall_status" == "UNHEALTHY" ]]; then
        log_error "O2IMS probe detected unhealthy sites"
        exit 1
    fi

    log_info "✅ O2IMS Multi-Site Probe Completed Successfully"
    exit 0
}

# Execution control
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Direct script execution
    main "$@"
fi