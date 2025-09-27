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
    if [[ "$TARGET_SITE" == "both" ]]; then
        sites=("edge1" "edge2")
    else
        sites=("$TARGET_SITE")
    fi

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
