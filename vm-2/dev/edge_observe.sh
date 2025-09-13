#!/bin/bash

# Edge Cluster Observability Script
# Provides health metrics and readiness checks for SLO gates
# Author: Edge Platform Team
# Version: 1.0.0

set -e

# Configuration
KUBECONFIG="/tmp/kubeconfig-edge.yaml"
OUTPUT_FORMAT="${1:-table}"  # table or json
NAMESPACE_FILTER="${2:-all}"  # specific namespace or 'all'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_NAMESPACE_FAIL=1
EXIT_POD_FAIL=2
EXIT_DEPLOYMENT_FAIL=3
EXIT_CRITICAL_FAIL=4

# Function to check kubectl availability
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        echo "ERROR: kubectl not found" >&2
        exit $EXIT_CRITICAL_FAIL
    fi
    
    if [ ! -f "$KUBECONFIG" ]; then
        echo "ERROR: Kubeconfig not found at $KUBECONFIG" >&2
        exit $EXIT_CRITICAL_FAIL
    fi
}

# Function to get namespace health
get_namespace_health() {
    local ns_filter="$1"
    local namespaces
    
    if [ "$ns_filter" == "all" ]; then
        namespaces=$(kubectl --kubeconfig="$KUBECONFIG" get ns -o json)
    else
        namespaces=$(kubectl --kubeconfig="$KUBECONFIG" get ns "$ns_filter" -o json 2>/dev/null || echo "{}")
    fi
    
    echo "$namespaces"
}

# Function to get pod readiness
get_pod_readiness() {
    local namespace="$1"
    local selector=""
    
    if [ "$namespace" != "all" ] && [ "$namespace" != "" ]; then
        selector="-n $namespace"
    else
        selector="--all-namespaces"
    fi
    
    kubectl --kubeconfig="$KUBECONFIG" get pods $selector \
        -o json 2>/dev/null || echo '{"items":[]}'
}

# Function to get deployment status
get_deployment_status() {
    local namespace="$1"
    local selector=""
    
    if [ "$namespace" != "all" ] && [ "$namespace" != "" ]; then
        selector="-n $namespace"
    else
        selector="--all-namespaces"
    fi
    
    kubectl --kubeconfig="$KUBECONFIG" get deployments $selector \
        -o json 2>/dev/null || echo '{"items":[]}'
}

# Function to get statefulset status
get_statefulset_status() {
    local namespace="$1"
    local selector=""
    
    if [ "$namespace" != "all" ] && [ "$namespace" != "" ]; then
        selector="-n $namespace"
    else
        selector="--all-namespaces"
    fi
    
    kubectl --kubeconfig="$KUBECONFIG" get statefulsets $selector \
        -o json 2>/dev/null || echo '{"items":[]}'
}

# Function to calculate health metrics
calculate_metrics() {
    local pods_json="$1"
    local deps_json="$2"
    local sts_json="$3"
    
    # Pod metrics
    local total_pods=$(echo "$pods_json" | jq '.items | length')
    local ready_pods=$(echo "$pods_json" | jq '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length')
    local failed_pods=$(echo "$pods_json" | jq '[.items[] | select(.status.phase=="Failed")] | length')
    local pending_pods=$(echo "$pods_json" | jq '[.items[] | select(.status.phase=="Pending")] | length')
    
    # Deployment metrics
    local total_deployments=$(echo "$deps_json" | jq '.items | length')
    local available_deployments=$(echo "$deps_json" | jq '[.items[] | select(.status.replicas == .status.availableReplicas)] | length')
    
    # StatefulSet metrics
    local total_statefulsets=$(echo "$sts_json" | jq '.items | length')
    local ready_statefulsets=$(echo "$sts_json" | jq '[.items[] | select(.status.replicas == .status.readyReplicas)] | length')
    
    # Calculate health score (0-100)
    local health_score=100
    
    if [ "$total_pods" -gt 0 ]; then
        local pod_health=$((ready_pods * 100 / total_pods))
        health_score=$((health_score * pod_health / 100))
    fi
    
    if [ "$failed_pods" -gt 0 ]; then
        health_score=$((health_score - failed_pods * 10))
    fi
    
    if [ "$pending_pods" -gt 0 ]; then
        health_score=$((health_score - pending_pods * 5))
    fi
    
    # Ensure score doesn't go below 0
    if [ "$health_score" -lt 0 ]; then
        health_score=0
    fi
    
    cat <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "cluster": "edge",
    "health_score": $health_score,
    "pods": {
        "total": $total_pods,
        "ready": $ready_pods,
        "failed": $failed_pods,
        "pending": $pending_pods
    },
    "deployments": {
        "total": $total_deployments,
        "available": $available_deployments
    },
    "statefulsets": {
        "total": $total_statefulsets,
        "ready": $ready_statefulsets
    }
}
EOF
}

# Function to output table format
output_table() {
    local metrics="$1"
    
    echo "════════════════════════════════════════════════════════════════"
    echo "                    EDGE CLUSTER HEALTH REPORT                  "
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Timestamp: $(echo "$metrics" | jq -r '.timestamp')"
    echo "Health Score: $(echo "$metrics" | jq -r '.health_score')%"
    echo ""
    echo "┌─────────────────────┬────────┬────────┬─────────┬──────────┐"
    echo "│ Component           │ Total  │ Ready  │ Failed  │ Pending  │"
    echo "├─────────────────────┼────────┼────────┼─────────┼──────────┤"
    printf "│ %-19s │ %6s │ %6s │ %7s │ %8s │\n" \
        "Pods" \
        "$(echo "$metrics" | jq -r '.pods.total')" \
        "$(echo "$metrics" | jq -r '.pods.ready')" \
        "$(echo "$metrics" | jq -r '.pods.failed')" \
        "$(echo "$metrics" | jq -r '.pods.pending')"
    echo "├─────────────────────┼────────┼────────┼─────────┼──────────┤"
    printf "│ %-19s │ %6s │ %6s │ %7s │ %8s │\n" \
        "Deployments" \
        "$(echo "$metrics" | jq -r '.deployments.total')" \
        "$(echo "$metrics" | jq -r '.deployments.available')" \
        "-" \
        "-"
    echo "├─────────────────────┼────────┼────────┼─────────┼──────────┤"
    printf "│ %-19s │ %6s │ %6s │ %7s │ %8s │\n" \
        "StatefulSets" \
        "$(echo "$metrics" | jq -r '.statefulsets.total')" \
        "$(echo "$metrics" | jq -r '.statefulsets.ready')" \
        "-" \
        "-"
    echo "└─────────────────────┴────────┴────────┴─────────┴──────────┘"
    echo ""
    
    # Health status
    local health_score=$(echo "$metrics" | jq -r '.health_score')
    if [ "$health_score" -ge 90 ]; then
        echo -e "${GREEN}✓ HEALTHY${NC}: Cluster is operating normally"
    elif [ "$health_score" -ge 70 ]; then
        echo -e "${YELLOW}⚠ WARNING${NC}: Some components need attention"
    else
        echo -e "${RED}✗ CRITICAL${NC}: Cluster health is degraded"
    fi
}

# Function to check critical namespaces
check_critical_namespaces() {
    local critical_namespaces=("kube-system" "o2ims-system" "config-management-system")
    local failed=0
    
    for ns in "${critical_namespaces[@]}"; do
        if ! kubectl --kubeconfig="$KUBECONFIG" get ns "$ns" &>/dev/null; then
            echo "ERROR: Critical namespace $ns not found" >&2
            failed=1
        fi
    done
    
    return $failed
}

# Function to check API endpoints
check_api_endpoints() {
    local endpoints=()
    endpoints+=("https://172.16.4.45:6443/healthz")  # Kubernetes API
    endpoints+=("http://172.16.4.45:31280/metrics")  # O2IMS metrics
    
    local failed=0
    
    for endpoint in "${endpoints[@]}"; do
        if ! curl -k -s -f --connect-timeout 5 "$endpoint" >/dev/null 2>&1; then
            echo "WARNING: API endpoint $endpoint not reachable" >&2
            # Don't fail on endpoint check, just warn
        fi
    done
    
    return 0
}

# Main execution
main() {
    check_prerequisites
    
    echo "Collecting cluster health metrics..." >&2
    
    # Get current state
    local pods_json=$(get_pod_readiness "$NAMESPACE_FILTER")
    local deps_json=$(get_deployment_status "$NAMESPACE_FILTER")
    local sts_json=$(get_statefulset_status "$NAMESPACE_FILTER")
    
    # Calculate metrics
    local metrics=$(calculate_metrics "$pods_json" "$deps_json" "$sts_json")
    
    # Output based on format
    if [ "$OUTPUT_FORMAT" == "json" ]; then
        echo "$metrics" | jq '.'
    else
        output_table "$metrics"
    fi
    
    # Check critical components
    if ! check_critical_namespaces; then
        exit $EXIT_NAMESPACE_FAIL
    fi
    
    # Check API endpoints
    check_api_endpoints
    
    # Determine exit code based on health
    local health_score=$(echo "$metrics" | jq -r '.health_score')
    local failed_pods=$(echo "$metrics" | jq -r '.pods.failed')
    
    if [ "$health_score" -lt 50 ]; then
        exit $EXIT_CRITICAL_FAIL
    elif [ "$failed_pods" -gt 0 ]; then
        exit $EXIT_POD_FAIL
    fi
    
    exit $EXIT_SUCCESS
}

# Run main function
main "$@"