#!/bin/bash

# CI Acceptance Test Script for Edge1 Cluster
# Supports dry-run mode for local testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}
TEST_RESULTS=()
FAILED_TESTS=0
PASSED_TESTS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Run in dry-run mode (no actual changes)"
            echo "  --verbose    Enable verbose output"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TEST_RESULTS+=("PASS: $1")
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    TEST_RESULTS+=("FAIL: $1")
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_command() {
    local cmd=$1
    local description=$2

    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}Running:${NC} $cmd"
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would execute: $cmd"
        return 0
    fi

    if output=$(eval "$cmd" 2>&1); then
        return 0
    else
        if [ "$VERBOSE" = true ]; then
            echo "$output"
        fi
        return 1
    fi
}

# Test Functions
test_cluster_health() {
    log_info "Testing cluster health..."

    if run_command "kubectl get nodes -o json | jq -e '.items[0].status.conditions[] | select(.type==\"Ready\") | .status==\"True\"'" "Check node ready status"; then
        log_success "Cluster node is ready"
    else
        log_error "Cluster node is not ready"
    fi

    # Check system pods
    if run_command "kubectl get pods -n kube-system --no-headers | grep -v Running | wc -l | grep -q '^0$'" "Check system pods"; then
        log_success "All system pods are running"
    else
        log_error "Some system pods are not running"
    fi
}

test_namespaces() {
    log_info "Testing required namespaces..."

    local required_namespaces=("slo-monitoring" "o2ims-system" "edge1")

    for ns in "${required_namespaces[@]}"; do
        if run_command "kubectl get namespace $ns" "Check namespace $ns"; then
            log_success "Namespace $ns exists"
        else
            log_error "Namespace $ns is missing"
        fi
    done
}

test_slo_endpoint() {
    log_info "Testing SLO endpoint..."

    # Check service exists
    if run_command "kubectl get svc -n slo-monitoring slo-collector" "Check SLO collector service"; then
        log_success "SLO collector service exists"
    else
        log_error "SLO collector service not found"
        return
    fi

    # Check NodePort 30090
    if run_command "kubectl get svc -n slo-monitoring -o json | jq -e '.items[] | select(.spec.ports[].nodePort==30090)'" "Check NodePort 30090"; then
        log_success "NodePort 30090 is configured"
    else
        log_error "NodePort 30090 is not configured"
    fi

    # Test endpoint (only if not dry-run)
    if [ "$DRY_RUN" != true ]; then
        if curl -s http://127.0.0.1:30090/metrics/api/v1/slo 2>/dev/null | jq -e '.metrics' >/dev/null 2>&1; then
            log_success "SLO endpoint returns valid JSON"
        else
            log_warning "SLO endpoint not accessible (may need port-forward)"
        fi
    fi
}

test_o2ims_integration() {
    log_info "Testing O2IMS integration..."

    # Check CRD
    if run_command "kubectl get crd measurementjobs.o2ims.oran.org" "Check MeasurementJob CRD"; then
        log_success "MeasurementJob CRD exists"
    else
        log_error "MeasurementJob CRD not found"
    fi

    # Check MeasurementJob
    if run_command "kubectl get measurementjob -n o2ims-system slo-metrics-scraper" "Check MeasurementJob"; then
        # Check status
        status=$(kubectl get measurementjob -n o2ims-system slo-metrics-scraper -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [ "$status" = "Ready" ]; then
            log_success "MeasurementJob is Ready"
        else
            log_warning "MeasurementJob status: $status"
        fi
    else
        log_error "MeasurementJob not found"
    fi

    # Check controller
    if run_command "kubectl get deployment -n o2ims-system measurementjob-controller" "Check controller deployment"; then
        log_success "MeasurementJob controller deployed"
    else
        log_error "MeasurementJob controller not found"
    fi
}

test_workloads() {
    log_info "Testing workloads..."

    # Check echo service
    if run_command "kubectl get deployment -n slo-monitoring echo-service-v2" "Check echo service"; then
        replicas=$(kubectl get deployment -n slo-monitoring echo-service-v2 -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [ "$replicas" -gt 0 ]; then
            log_success "Echo service has $replicas ready replicas"
        else
            log_error "Echo service has no ready replicas"
        fi
    else
        log_error "Echo service deployment not found"
    fi

    # Check SLO collector
    if run_command "kubectl get deployment -n slo-monitoring slo-collector" "Check SLO collector"; then
        log_success "SLO collector deployed"
    else
        log_error "SLO collector not found"
    fi
}

test_resource_quotas() {
    log_info "Testing resource usage..."

    # Check node resources
    if [ "$DRY_RUN" != true ]; then
        cpu_usage=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $3}' | sed 's/%//' || echo "0")
        mem_usage=$(kubectl top nodes --no-headers 2>/dev/null | awk '{print $5}' | sed 's/%//' || echo "0")

        if [ -n "$cpu_usage" ] && [ "$cpu_usage" -lt 80 ]; then
            log_success "CPU usage is healthy: ${cpu_usage}%"
        else
            log_warning "CPU usage: ${cpu_usage}%"
        fi

        if [ -n "$mem_usage" ] && [ "$mem_usage" -lt 80 ]; then
            log_success "Memory usage is healthy: ${mem_usage}%"
        else
            log_warning "Memory usage: ${mem_usage}%"
        fi
    else
        log_info "[DRY-RUN] Would check resource usage"
    fi
}

test_connectivity() {
    log_info "Testing connectivity..."

    # Test DNS
    if run_command "kubectl run test-dns --image=busybox:1.35 --rm -i --restart=Never -- nslookup kubernetes.default 2>/dev/null" "Test cluster DNS"; then
        log_success "Cluster DNS is working"
    else
        log_warning "Cluster DNS test failed (may be transient)"
    fi

    # Test service connectivity
    if [ "$DRY_RUN" != true ]; then
        if kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
            curl -s http://echo-service-v2.slo-monitoring.svc.cluster.local:8080 2>/dev/null | grep -q "SLO-Echo"; then
            log_success "Internal service connectivity working"
        else
            log_warning "Internal service connectivity test failed"
        fi
    else
        log_info "[DRY-RUN] Would test service connectivity"
    fi
}

test_persistent_storage() {
    log_info "Testing persistent storage..."

    # Check PVCs
    pvc_count=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
    if [ "$pvc_count" -gt 0 ]; then
        bound_pvcs=$(kubectl get pvc -A --no-headers 2>/dev/null | grep Bound | wc -l)
        log_success "Found $bound_pvcs bound PVCs out of $pvc_count total"
    else
        log_info "No PVCs found"
    fi
}

# Performance test
test_performance() {
    log_info "Testing performance metrics..."

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would run performance tests"
        return
    fi

    # Quick load test
    log_info "Running quick load test..."

    # Generate some load
    for i in {1..10}; do
        curl -s http://127.0.0.1:30080 >/dev/null 2>&1 &
    done
    wait

    # Check SLO metrics
    if metrics=$(curl -s http://127.0.0.1:30090/metrics/api/v1/slo 2>/dev/null); then
        p95=$(echo "$metrics" | jq -r '.metrics.latency_p95_ms // 0')
        success_rate=$(echo "$metrics" | jq -r '.metrics.success_rate // 0')

        if (( $(echo "$success_rate > 95" | bc -l) )); then
            log_success "Success rate is healthy: ${success_rate}%"
        else
            log_warning "Success rate is low: ${success_rate}%"
        fi

        log_info "P95 latency: ${p95}ms"
    else
        log_warning "Could not fetch SLO metrics"
    fi
}

# Main test execution
main() {
    echo -e "${YELLOW}=== CI Acceptance Test Suite ===${NC}"
    echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY-RUN" || echo "LIVE")"
    echo "Started: $(date)"
    echo ""

    # Run all tests
    test_cluster_health
    echo ""
    test_namespaces
    echo ""
    test_slo_endpoint
    echo ""
    test_o2ims_integration
    echo ""
    test_workloads
    echo ""
    test_resource_quotas
    echo ""
    test_connectivity
    echo ""
    test_persistent_storage
    echo ""
    test_performance

    # Summary
    echo ""
    echo -e "${YELLOW}=== Test Summary ===${NC}"
    echo "Completed: $(date)"
    echo ""
    echo "Results:"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ $result == PASS* ]]; then
            echo -e "  ${GREEN}✓${NC} ${result#PASS: }"
        else
            echo -e "  ${RED}✗${NC} ${result#FAIL: }"
        fi
    done

    echo ""
    echo "Total Tests: $((PASSED_TESTS + FAILED_TESTS))"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

    # Exit code
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

# Run main function
main