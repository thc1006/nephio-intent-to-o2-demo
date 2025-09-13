#!/bin/bash
# Phase 19-B (VM-4) Edge Verification Hook
# Confirms O2IMS PR reaches READY and all site resources applied

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
EDGE_SITE="${1:-edge2}"
NAMESPACE="${2:-default}"
TIMEOUT="${3:-300}"
OUTPUT_FORMAT="${4:-json}"

# Create artifacts directory
mkdir -p "${ARTIFACTS_DIR}/${EDGE_SITE}"

# Log function
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
}

# Check if o2imsctl is available (fallback to kubectl)
check_o2imsctl() {
    if command -v o2imsctl &> /dev/null; then
        echo "o2imsctl"
    else
        warning "o2imsctl not found, using kubectl as fallback"
        echo "kubectl"
    fi
}

# Get PR list using appropriate tool
get_pr_list() {
    local cmd="$1"
    local ns="$2"

    if [[ "$cmd" == "o2imsctl" ]]; then
        o2imsctl pr list -n "$ns" -o json 2>/dev/null || echo "{}"
    else
        # Try different CRD names
        for crd in "provisioningrequests.o2ims.io" "provisioningrequests.focom.io" "packagerevisions.porch.kpt.dev"; do
            if kubectl get crd "$crd" &>/dev/null; then
                kubectl get "${crd%%.*}" -n "$ns" -o json 2>/dev/null || echo "{}"
                return
            fi
        done
        echo "{}"
    fi
}

# Check PR readiness condition
check_pr_ready() {
    local pr_name="$1"
    local ns="$2"
    local cmd="$3"

    if [[ "$cmd" == "o2imsctl" ]]; then
        local status=$(o2imsctl pr get "$pr_name" -n "$ns" -o json 2>/dev/null | jq -r '.status.phase // "Unknown"')
    else
        # Try to get status from different CRD types
        local status="Unknown"
        for crd in "provisioningrequest" "packagerevision"; do
            if kubectl get "$crd" "$pr_name" -n "$ns" &>/dev/null; then
                status=$(kubectl get "$crd" "$pr_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
                if [[ -z "$status" ]]; then
                    # Try conditions array
                    status=$(kubectl get "$crd" "$pr_name" -n "$ns" -o json | jq -r '.status.conditions[] | select(.type=="Ready") | .status' 2>/dev/null || echo "Unknown")
                fi
                break
            fi
        done
    fi

    [[ "$status" == "Ready" || "$status" == "True" || "$status" == "Published" ]]
}

# Probe service endpoints
probe_service_endpoint() {
    local service="$1"
    local ns="$2"
    local edge="$3"

    local endpoint=$(kubectl get service "$service" -n "$ns" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    if [[ -z "$endpoint" ]]; then
        endpoint=$(kubectl get service "$service" -n "$ns" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    fi

    if [[ -n "$endpoint" ]]; then
        # Check if endpoint is reachable
        if timeout 5 curl -s -o /dev/null -w "%{http_code}" "http://${endpoint}:80" &>/dev/null; then
            echo "reachable"
        else
            echo "unreachable"
        fi
    else
        echo "not_found"
    fi
}

# Verify edge resources
verify_edge_resources() {
    local edge="$1"
    local ns="$2"
    local results=()

    log "Verifying resources for edge: $edge"

    # Check NetworkSlices
    local slices=$(kubectl get networkslices -n "$ns" -o json 2>/dev/null | jq -r '.items[] | .metadata.name' 2>/dev/null || true)
    local slice_count=0
    if [[ -n "$slices" ]]; then
        slice_count=$(echo "$slices" | wc -l)
    fi

    # Check ConfigMaps
    local configs=$(kubectl get configmaps -n "$ns" -l "edge=$edge" -o json 2>/dev/null | jq -r '.items[] | .metadata.name' 2>/dev/null || true)
    local config_count=0
    if [[ -n "$configs" ]]; then
        config_count=$(echo "$configs" | wc -l)
    fi

    # Check Services
    local services=$(kubectl get services -n "$ns" -l "edge=$edge" -o json 2>/dev/null | jq -r '.items[] | .metadata.name' 2>/dev/null || true)
    local service_count=0
    if [[ -n "$services" ]]; then
        service_count=$(echo "$services" | wc -l)
    fi

    # Probe A/B service endpoints
    local service_status="unknown"
    if [[ "$service_count" -gt 0 ]]; then
        for svc in $services; do
            local probe_result=$(probe_service_endpoint "$svc" "$ns" "$edge")
            if [[ "$probe_result" == "reachable" ]]; then
                service_status="healthy"
                break
            elif [[ "$probe_result" == "unreachable" ]]; then
                service_status="unhealthy"
            fi
        done
    fi

    cat <<EOF
{
  "networkSlices": $slice_count,
  "configMaps": $config_count,
  "services": $service_count,
  "serviceStatus": "$service_status"
}
EOF
}

# Main verification flow
main() {
    log "Starting Phase 19-B Edge Verification for site: $EDGE_SITE"

    # Check prerequisites
    check_kubectl
    local CMD=$(check_o2imsctl)

    # Initialize results
    local verification_results='{
        "timestamp": "'$TIMESTAMP'",
        "edge": "'$EDGE_SITE'",
        "namespace": "'$NAMESPACE'",
        "verification": {}
    }'

    # Step 1: List all PRs
    log "Fetching ProvisioningRequests..."
    local pr_list=$(get_pr_list "$CMD" "$NAMESPACE")
    local pr_count=$(echo "$pr_list" | jq '.items | length' 2>/dev/null || echo 0)

    info "Found $pr_count ProvisioningRequest(s)"

    # Step 2: Check PR readiness
    local ready_prs=0
    local pr_statuses='[]'

    if [[ "$pr_count" -gt 0 ]]; then
        while IFS= read -r pr_name; do
            if check_pr_ready "$pr_name" "$NAMESPACE" "$CMD"; then
                ((ready_prs++))
                pr_statuses=$(echo "$pr_statuses" | jq '. + [{"name": "'$pr_name'", "status": "Ready"}]')
                log "PR $pr_name is READY"
            else
                pr_statuses=$(echo "$pr_statuses" | jq '. + [{"name": "'$pr_name'", "status": "NotReady"}]')
                warning "PR $pr_name is not ready"
            fi
        done < <(echo "$pr_list" | jq -r '.items[].metadata.name' 2>/dev/null)
    fi

    # Step 3: Verify edge resources
    local resource_status=$(verify_edge_resources "$EDGE_SITE" "$NAMESPACE")

    # Step 4: Compile results
    verification_results=$(echo "$verification_results" | jq \
        --argjson prs "$pr_statuses" \
        --argjson resources "$resource_status" \
        --arg pr_count "$pr_count" \
        --arg ready_prs "$ready_prs" '
        .verification = {
            "provisioningRequests": {
                "total": ($pr_count | tonumber),
                "ready": ($ready_prs | tonumber),
                "details": $prs
            },
            "resources": $resources,
            "overallStatus": (if (($ready_prs | tonumber) > 0 and $resources.serviceStatus == "healthy") then "SUCCESS" else "PENDING" end)
        }
    ')

    # Step 5: Wait for readiness with timeout
    local start_time=$(date +%s)
    local elapsed=0

    while [[ "$elapsed" -lt "$TIMEOUT" ]]; do
        local overall_status=$(echo "$verification_results" | jq -r '.verification.overallStatus')

        if [[ "$overall_status" == "SUCCESS" ]]; then
            log "Edge $EDGE_SITE verification successful!"
            break
        fi

        warning "Waiting for edge resources to be ready... ($elapsed/$TIMEOUT seconds)"
        sleep 10

        # Re-check resources
        resource_status=$(verify_edge_resources "$EDGE_SITE" "$NAMESPACE")
        ready_prs=0

        # Re-check PRs
        if [[ "$pr_count" -gt 0 ]]; then
            while IFS= read -r pr_name; do
                if check_pr_ready "$pr_name" "$NAMESPACE" "$CMD"; then
                    ((ready_prs++))
                fi
            done < <(echo "$pr_list" | jq -r '.items[].metadata.name' 2>/dev/null)
        fi

        # Update results
        verification_results=$(echo "$verification_results" | jq \
            --argjson resources "$resource_status" \
            --arg ready_prs "$ready_prs" '
            .verification.resources = $resources |
            .verification.provisioningRequests.ready = ($ready_prs | tonumber) |
            .verification.overallStatus = (if (($ready_prs | tonumber) > 0 and $resources.serviceStatus == "healthy") then "SUCCESS" else "PENDING" end)
        ')

        elapsed=$(($(date +%s) - start_time))
    done

    # Step 6: Final status check
    local final_status=$(echo "$verification_results" | jq -r '.verification.overallStatus')

    if [[ "$final_status" != "SUCCESS" ]]; then
        error "Edge verification failed or timed out"
        verification_results=$(echo "$verification_results" | jq '.verification.overallStatus = "FAILED"')
    fi

    # Step 7: Save results
    local output_file="${ARTIFACTS_DIR}/${EDGE_SITE}/ready_${TIMESTAMP}.json"
    echo "$verification_results" | jq '.' > "$output_file"

    log "Verification results saved to: $output_file"

    # Also save a latest symlink
    ln -sf "ready_${TIMESTAMP}.json" "${ARTIFACTS_DIR}/${EDGE_SITE}/ready.json"

    # Output based on format
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$verification_results" | jq '.'
    else
        echo "Edge Verification Report for $EDGE_SITE"
        echo "========================================="
        echo "Timestamp: $TIMESTAMP"
        echo "Namespace: $NAMESPACE"
        echo ""
        echo "ProvisioningRequests:"
        echo "  Total: $pr_count"
        echo "  Ready: $ready_prs"
        echo ""
        echo "Resources:"
        echo "$resource_status" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
        echo ""
        echo "Overall Status: $final_status"
    fi

    # Exit with appropriate code
    [[ "$final_status" == "SUCCESS" ]] && exit 0 || exit 1
}

# Run main function
main "$@"