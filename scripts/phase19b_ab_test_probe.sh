#!/bin/bash
# Phase 19-B A/B Service Testing and Endpoint Probing
# Tests service endpoints and performs A/B validation for edge deployments

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARTIFACTS_DIR="${PROJECT_ROOT}/artifacts/ab-testing"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test configuration
declare -A SERVICE_TESTS=(
    ["edge1"]="embb-service mmtc-service video-streaming"
    ["edge2"]="urllc-service gaming-service iot-gateway"
)

declare -A ENDPOINT_PORTS=(
    ["embb-service"]="8080"
    ["mmtc-service"]="8081"
    ["video-streaming"]="8082"
    ["urllc-service"]="8083"
    ["gaming-service"]="8084"
    ["iot-gateway"]="8085"
)

# Create artifacts directory
mkdir -p "${ARTIFACTS_DIR}"

# Logging functions
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Get service endpoint
get_service_endpoint() {
    local service="$1"
    local namespace="$2"
    local edge="$3"

    # Try LoadBalancer IP first
    local endpoint=$(kubectl get service "$service" -n "$namespace" \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    if [[ -z "$endpoint" ]]; then
        # Try NodePort
        local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
        local node_port=$(kubectl get service "$service" -n "$namespace" \
            -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

        if [[ -n "$node_ip" && -n "$node_port" ]]; then
            endpoint="${node_ip}:${node_port}"
        fi
    fi

    if [[ -z "$endpoint" ]]; then
        # Try ClusterIP
        endpoint=$(kubectl get service "$service" -n "$namespace" \
            -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    fi

    echo "$endpoint"
}

# HTTP health check
http_health_check() {
    local endpoint="$1"
    local port="${2:-80}"
    local path="${3:-/health}"

    local url="http://${endpoint}:${port}${path}"

    # Perform health check with timeout
    local response=$(timeout 5 curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    case "$response" in
        200|201|202|204)
            echo "healthy"
            ;;
        301|302|307|308)
            echo "redirect"
            ;;
        400|401|403|404)
            echo "client_error"
            ;;
        500|502|503|504)
            echo "server_error"
            ;;
        000)
            echo "timeout"
            ;;
        *)
            echo "unknown_${response}"
            ;;
    esac
}

# Latency test
measure_latency() {
    local endpoint="$1"
    local port="${2:-80}"
    local samples="${3:-10}"

    local latencies=()
    local url="http://${endpoint}:${port}/"

    for i in $(seq 1 $samples); do
        local latency=$(curl -o /dev/null -s -w "%{time_total}" "$url" 2>/dev/null || echo "0")
        latencies+=("$latency")
    done

    # Calculate average
    local sum=0
    local count=0
    for lat in "${latencies[@]}"; do
        if [[ "$lat" != "0" ]]; then
            sum=$(echo "$sum + $lat" | bc)
            ((count++))
        fi
    done

    if [[ $count -gt 0 ]]; then
        echo "scale=3; $sum / $count" | bc
    else
        echo "0"
    fi
}

# A/B test comparison
perform_ab_test() {
    local service_a="$1"
    local service_b="$2"
    local namespace="$3"
    local test_duration="${4:-30}"

    log "Starting A/B test between $service_a and $service_b"

    local results='{
        "test": "a_b_comparison",
        "services": {
            "a": "'$service_a'",
            "b": "'$service_b'"
        },
        "metrics": {}
    }'

    # Get endpoints
    local endpoint_a=$(get_service_endpoint "$service_a" "$namespace" "")
    local endpoint_b=$(get_service_endpoint "$service_b" "$namespace" "")

    if [[ -z "$endpoint_a" || -z "$endpoint_b" ]]; then
        warning "Could not get endpoints for A/B testing"
        echo "$results" | jq '.status = "failed" | .error = "endpoints_not_found"'
        return 1
    fi

    # Test health
    local health_a=$(http_health_check "$endpoint_a" "${ENDPOINT_PORTS[$service_a]:-80}")
    local health_b=$(http_health_check "$endpoint_b" "${ENDPOINT_PORTS[$service_b]:-80}")

    # Measure latencies
    local latency_a=$(measure_latency "$endpoint_a" "${ENDPOINT_PORTS[$service_a]:-80}")
    local latency_b=$(measure_latency "$endpoint_b" "${ENDPOINT_PORTS[$service_b]:-80}")

    # Load test (simplified)
    log "Running load test for ${test_duration} seconds..."

    local requests_a=0
    local success_a=0
    local requests_b=0
    local success_b=0

    local end_time=$(($(date +%s) + test_duration))

    while [[ $(date +%s) -lt $end_time ]]; do
        # Test service A
        if timeout 1 curl -s -o /dev/null "http://${endpoint_a}:${ENDPOINT_PORTS[$service_a]:-80}/" 2>/dev/null; then
            ((success_a++))
        fi
        ((requests_a++))

        # Test service B
        if timeout 1 curl -s -o /dev/null "http://${endpoint_b}:${ENDPOINT_PORTS[$service_b]:-80}/" 2>/dev/null; then
            ((success_b++))
        fi
        ((requests_b++))

        sleep 0.5
    done

    # Calculate success rates
    local success_rate_a=$(echo "scale=2; $success_a * 100 / $requests_a" | bc)
    local success_rate_b=$(echo "scale=2; $success_b * 100 / $requests_b" | bc)

    # Compile results
    results=$(echo "$results" | jq \
        --arg health_a "$health_a" \
        --arg health_b "$health_b" \
        --arg latency_a "$latency_a" \
        --arg latency_b "$latency_b" \
        --arg success_rate_a "$success_rate_a" \
        --arg success_rate_b "$success_rate_b" \
        --arg requests_a "$requests_a" \
        --arg requests_b "$requests_b" \
        '.metrics = {
            "service_a": {
                "health": $health_a,
                "avg_latency_ms": ($latency_a | tonumber * 1000),
                "success_rate": ($success_rate_a | tonumber),
                "total_requests": ($requests_a | tonumber)
            },
            "service_b": {
                "health": $health_b,
                "avg_latency_ms": ($latency_b | tonumber * 1000),
                "success_rate": ($success_rate_b | tonumber),
                "total_requests": ($requests_b | tonumber)
            }
        } | .status = "completed"')

    echo "$results"
}

# Canary deployment test
test_canary_deployment() {
    local service="$1"
    local namespace="$2"
    local canary_weight="${3:-10}"

    log "Testing canary deployment for $service (weight: ${canary_weight}%)"

    local endpoint=$(get_service_endpoint "$service" "$namespace" "")

    if [[ -z "$endpoint" ]]; then
        error "Could not find endpoint for $service"
        return 1
    fi

    # Send 100 requests and check version distribution
    local versions=()
    for i in {1..100}; do
        local version=$(curl -s -H "Accept: application/json" \
            "http://${endpoint}:${ENDPOINT_PORTS[$service]:-80}/version" 2>/dev/null | \
            jq -r '.version // "unknown"' || echo "error")
        versions+=("$version")
    done

    # Count versions
    local v1_count=$(printf '%s\n' "${versions[@]}" | grep -c "v1" || echo 0)
    local v2_count=$(printf '%s\n' "${versions[@]}" | grep -c "v2" || echo 0)
    local error_count=$(printf '%s\n' "${versions[@]}" | grep -c "error" || echo 0)

    local canary_actual=$(echo "scale=2; $v2_count * 100 / 100" | bc)

    cat <<EOF
{
    "service": "$service",
    "canary_target": $canary_weight,
    "canary_actual": $canary_actual,
    "distribution": {
        "v1": $v1_count,
        "v2": $v2_count,
        "errors": $error_count
    },
    "status": $(if [[ $(echo "$canary_actual >= $((canary_weight - 5)) && $canary_actual <= $((canary_weight + 5))" | bc) -eq 1 ]]; then echo '"success"'; else echo '"deviation"'; fi)
}
EOF
}

# Blue-Green deployment test
test_blue_green() {
    local service="$1"
    local namespace="$2"
    local expected_version="${3:-blue}"

    log "Testing blue-green deployment for $service (expected: $expected_version)"

    local endpoint=$(get_service_endpoint "$service" "$namespace" "")

    if [[ -z "$endpoint" ]]; then
        error "Could not find endpoint for $service"
        return 1
    fi

    # Check current deployment
    local current_version=$(curl -s -H "Accept: application/json" \
        "http://${endpoint}:${ENDPOINT_PORTS[$service]:-80}/version" 2>/dev/null | \
        jq -r '.deployment // "unknown"' || echo "error")

    # Test consistency (all requests should go to same version)
    local consistent=true
    for i in {1..20}; do
        local version=$(curl -s -H "Accept: application/json" \
            "http://${endpoint}:${ENDPOINT_PORTS[$service]:-80}/version" 2>/dev/null | \
            jq -r '.deployment // "unknown"' || echo "error")

        if [[ "$version" != "$current_version" ]]; then
            consistent=false
            break
        fi
    done

    cat <<EOF
{
    "service": "$service",
    "expected_version": "$expected_version",
    "current_version": "$current_version",
    "consistent": $consistent,
    "status": $(if [[ "$current_version" == "$expected_version" && "$consistent" == "true" ]]; then echo '"success"'; else echo '"failed"'; fi)
}
EOF
}

# Main edge probe function
probe_edge_services() {
    local edge="$1"
    local namespace="${2:-default}"

    log "Probing services for edge: $edge"

    local results='{
        "edge": "'$edge'",
        "timestamp": "'$TIMESTAMP'",
        "services": [],
        "summary": {}
    }'

    local services="${SERVICE_TESTS[$edge]:-}"

    if [[ -z "$services" ]]; then
        warning "No services configured for edge $edge"
        echo "$results" | jq '.status = "no_services"'
        return
    fi

    local total=0
    local healthy=0
    local unhealthy=0

    for service in $services; do
        ((total++))

        info "Testing service: $service"

        # Check if service exists
        if ! kubectl get service "$service" -n "$namespace" &>/dev/null; then
            warning "Service $service not found"
            results=$(echo "$results" | jq --arg svc "$service" \
                '.services += [{"name": $svc, "status": "not_found"}]')
            ((unhealthy++))
            continue
        fi

        # Get endpoint
        local endpoint=$(get_service_endpoint "$service" "$namespace" "$edge")

        if [[ -z "$endpoint" ]]; then
            warning "No endpoint for $service"
            results=$(echo "$results" | jq --arg svc "$service" \
                '.services += [{"name": $svc, "status": "no_endpoint"}]')
            ((unhealthy++))
            continue
        fi

        # Perform health check
        local health=$(http_health_check "$endpoint" "${ENDPOINT_PORTS[$service]:-80}")

        # Measure latency
        local latency=$(measure_latency "$endpoint" "${ENDPOINT_PORTS[$service]:-80}" 5)

        # Add to results
        results=$(echo "$results" | jq \
            --arg svc "$service" \
            --arg endpoint "$endpoint" \
            --arg health "$health" \
            --arg latency "$latency" \
            '.services += [{
                "name": $svc,
                "endpoint": $endpoint,
                "health": $health,
                "latency_ms": ($latency | tonumber * 1000),
                "status": (if $health == "healthy" then "ok" else "degraded" end)
            }]')

        if [[ "$health" == "healthy" ]]; then
            ((healthy++))
            success "✓ $service is healthy (latency: ${latency}s)"
        else
            ((unhealthy++))
            warning "✗ $service is $health"
        fi
    done

    # Update summary
    results=$(echo "$results" | jq \
        --arg total "$total" \
        --arg healthy "$healthy" \
        --arg unhealthy "$unhealthy" \
        '.summary = {
            "total": ($total | tonumber),
            "healthy": ($healthy | tonumber),
            "unhealthy": ($unhealthy | tonumber),
            "health_percentage": (if ($total | tonumber) > 0 then (($healthy | tonumber) * 100 / ($total | tonumber)) else 0 end)
        } | .status = (if ($healthy | tonumber) == ($total | tonumber) then "all_healthy"
                      elif ($healthy | tonumber) > 0 then "partial"
                      else "unhealthy" end)')

    echo "$results"
}

# Main function
main() {
    local mode="${1:-probe}"
    local edge="${2:-edge2}"
    local namespace="${3:-default}"

    log "Phase 19-B A/B Testing and Service Probing"
    log "Mode: $mode | Edge: $edge | Namespace: $namespace"

    case "$mode" in
        probe)
            # Probe all services for an edge
            local results=$(probe_edge_services "$edge" "$namespace")

            # Save results
            local output_file="${ARTIFACTS_DIR}/probe_${edge}_${TIMESTAMP}.json"
            echo "$results" | jq '.' > "$output_file"

            log "Results saved to: $output_file"

            # Display summary
            echo "$results" | jq -r '
                "\n=== Service Probe Results ===",
                "Edge: \(.edge)",
                "Status: \(.status)",
                "Health: \(.summary.healthy)/\(.summary.total) services healthy (\(.summary.health_percentage | round)%)",
                "\nServices:",
                (.services[] | "  - \(.name): \(.status) (\(.health))")
            '
            ;;

        ab)
            # A/B test between two services
            local service_a="${4:-embb-service}"
            local service_b="${5:-urllc-service}"

            local results=$(perform_ab_test "$service_a" "$service_b" "$namespace")

            # Save results
            local output_file="${ARTIFACTS_DIR}/ab_test_${TIMESTAMP}.json"
            echo "$results" | jq '.' > "$output_file"

            log "A/B test results saved to: $output_file"

            # Display comparison
            echo "$results" | jq -r '
                "\n=== A/B Test Results ===",
                "Service A: \(.services.a)",
                "  Health: \(.metrics.service_a.health)",
                "  Latency: \(.metrics.service_a.avg_latency_ms)ms",
                "  Success Rate: \(.metrics.service_a.success_rate)%",
                "",
                "Service B: \(.services.b)",
                "  Health: \(.metrics.service_b.health)",
                "  Latency: \(.metrics.service_b.avg_latency_ms)ms",
                "  Success Rate: \(.metrics.service_b.success_rate)%"
            '
            ;;

        canary)
            # Test canary deployment
            local service="${4:-embb-service}"
            local weight="${5:-10}"

            local results=$(test_canary_deployment "$service" "$namespace" "$weight")

            # Save results
            local output_file="${ARTIFACTS_DIR}/canary_${service}_${TIMESTAMP}.json"
            echo "$results" | jq '.' > "$output_file"

            log "Canary test results saved to: $output_file"
            echo "$results" | jq '.'
            ;;

        blue-green)
            # Test blue-green deployment
            local service="${4:-embb-service}"
            local expected="${5:-blue}"

            local results=$(test_blue_green "$service" "$namespace" "$expected")

            # Save results
            local output_file="${ARTIFACTS_DIR}/blue_green_${service}_${TIMESTAMP}.json"
            echo "$results" | jq '.' > "$output_file"

            log "Blue-green test results saved to: $output_file"
            echo "$results" | jq '.'
            ;;

        all)
            # Run all tests for an edge
            log "Running comprehensive tests for edge: $edge"

            # Probe services
            probe_edge_services "$edge" "$namespace" > "${ARTIFACTS_DIR}/comprehensive_${edge}_${TIMESTAMP}.json"

            # Run A/B tests if services exist
            if [[ -n "${SERVICE_TESTS[$edge]}" ]]; then
                local services=(${SERVICE_TESTS[$edge]})
                if [[ ${#services[@]} -ge 2 ]]; then
                    perform_ab_test "${services[0]}" "${services[1]}" "$namespace" >> \
                        "${ARTIFACTS_DIR}/comprehensive_${edge}_${TIMESTAMP}.json"
                fi
            fi

            success "Comprehensive testing completed for $edge"
            ;;

        *)
            error "Unknown mode: $mode"
            echo "Usage: $0 [probe|ab|canary|blue-green|all] [edge] [namespace] [additional_args]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"