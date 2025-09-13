#!/bin/bash

# Pre-Staging Health Check for Edge1 Cluster
# Final validation before staging/production

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}         PRE-STAGING HEALTH CHECK - EDGE1 CLUSTER${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Timestamp: $(date)"
echo "Cluster: edge1"
echo ""

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
}

section() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
    echo "─────────────────────────────────────────"
}

# 1. CLUSTER INFRASTRUCTURE
section "CLUSTER INFRASTRUCTURE"

# Node status
node_ready=$(kubectl get nodes -o json | jq -r '.items[0].status.conditions[] | select(.type=="Ready") | .status')
if [ "$node_ready" = "True" ]; then
    check_pass "Node is Ready"
else
    check_fail "Node is not Ready"
fi

# Kubernetes version
k8s_version=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')
check_pass "Kubernetes version: $k8s_version"

# System namespaces
critical_ns=("kube-system" "kube-public" "kube-node-lease")
for ns in "${critical_ns[@]}"; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        check_pass "System namespace exists: $ns"
    else
        check_fail "System namespace missing: $ns"
    fi
done

# 2. CORE SERVICES
section "CORE SERVICES"

# Check core pods
not_running=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v Running | wc -l)
if [ "$not_running" -eq 0 ]; then
    check_pass "All kube-system pods are Running"
else
    check_fail "$not_running kube-system pods not Running"
fi

# CoreDNS
dns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$dns_pods" -gt 0 ]; then
    check_pass "CoreDNS is running ($dns_pods replicas)"
else
    check_fail "CoreDNS is not running"
fi

# 3. APPLICATION NAMESPACES
section "APPLICATION NAMESPACES"

app_namespaces=("slo-monitoring" "o2ims-system" "edge1")
for ns in "${app_namespaces[@]}"; do
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
        check_pass "Namespace $ns exists ($pod_count pods)"
    else
        check_fail "Namespace $ns missing"
    fi
done

# 4. SLO MONITORING STACK
section "SLO MONITORING STACK"

# Echo service
echo_ready=$(kubectl get deployment -n slo-monitoring echo-service-v2 -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo_desired=$(kubectl get deployment -n slo-monitoring echo-service-v2 -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [ "$echo_ready" = "$echo_desired" ] && [ "$echo_ready" -gt 0 ]; then
    check_pass "Echo service: $echo_ready/$echo_desired replicas ready"
else
    check_fail "Echo service: $echo_ready/$echo_desired replicas ready"
fi

# SLO collector
collector_ready=$(kubectl get deployment -n slo-monitoring slo-collector -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$collector_ready" -gt 0 ]; then
    check_pass "SLO collector is running"
else
    check_fail "SLO collector is not running"
fi

# NodePort services
nodeport_30090=$(kubectl get svc -n slo-monitoring -o json 2>/dev/null | jq -r '.items[] | select(.spec.ports[]?.nodePort==30090) | .metadata.name')
if [ -n "$nodeport_30090" ]; then
    check_pass "NodePort 30090 configured: $nodeport_30090"
else
    check_fail "NodePort 30090 not configured"
fi

nodeport_30080=$(kubectl get svc -n slo-monitoring -o json 2>/dev/null | jq -r '.items[] | select(.spec.ports[]?.nodePort==30080) | .metadata.name')
if [ -n "$nodeport_30080" ]; then
    check_pass "NodePort 30080 configured: $nodeport_30080"
else
    check_warn "NodePort 30080 not configured"
fi

# 5. O2IMS INTEGRATION
section "O2IMS INTEGRATION"

# MeasurementJob CRD
if kubectl get crd measurementjobs.o2ims.oran.org >/dev/null 2>&1; then
    check_pass "MeasurementJob CRD installed"
else
    check_fail "MeasurementJob CRD not found"
fi

# MeasurementJob status
mj_status=$(kubectl get measurementjob -n o2ims-system slo-metrics-scraper -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$mj_status" = "Ready" ]; then
    check_pass "MeasurementJob is Ready"
elif [ "$mj_status" = "NotFound" ]; then
    check_fail "MeasurementJob not found"
else
    check_warn "MeasurementJob status: $mj_status"
fi

# Controller deployment
controller_ready=$(kubectl get deployment -n o2ims-system measurementjob-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$controller_ready" -gt 0 ]; then
    check_pass "MeasurementJob controller is running"
else
    check_fail "MeasurementJob controller not running"
fi

# 6. ENDPOINTS VALIDATION
section "ENDPOINTS VALIDATION"

# SLO endpoint test
if curl -s --max-time 3 http://127.0.0.1:30090/metrics/api/v1/slo 2>/dev/null | jq -e '.metrics' >/dev/null 2>&1; then
    check_pass "SLO endpoint responding with valid JSON"
else
    check_warn "SLO endpoint not accessible (may need port-forward)"
fi

# Echo service test
if curl -s --max-time 3 http://127.0.0.1:30080 2>/dev/null | grep -q "SLO-Echo"; then
    check_pass "Echo service endpoint responding"
else
    check_warn "Echo service endpoint not accessible (may need port-forward)"
fi

# 7. RESOURCE HEALTH
section "RESOURCE HEALTH"

# Check for pod restarts
high_restart_pods=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4>5 {print $1"/"$2" restarts:"$4}')
if [ -z "$high_restart_pods" ]; then
    check_pass "No pods with high restart counts"
else
    echo "$high_restart_pods" | while read pod; do
        check_warn "High restarts: $pod"
    done
fi

# Check for pending pods
pending_pods=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$pending_pods" -eq 0 ]; then
    check_pass "No pending pods"
else
    check_warn "$pending_pods pods in Pending state"
fi

# Check PVCs
unbound_pvcs=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -v Bound | wc -l)
if [ "$unbound_pvcs" -eq 0 ]; then
    check_pass "All PVCs are bound"
else
    check_warn "$unbound_pvcs PVCs not bound"
fi

# 8. RECENT EVENTS
section "RECENT EVENTS"

# Check for warning events in last 5 minutes
warning_events=$(kubectl get events -A --field-selector type=Warning -o json 2>/dev/null | \
    jq -r '.items[] | select(.lastTimestamp > (now - 300 | todate)) | .message' | wc -l)
if [ "$warning_events" -eq 0 ]; then
    check_pass "No warning events in last 5 minutes"
else
    check_warn "$warning_events warning events in last 5 minutes"
fi

# 9. CONFIGURATION FILES
section "CONFIGURATION FILES"

# Check key configuration files
config_files=(
    "/home/ubuntu/k8s/edge1/slo/echo-service-v2.yaml"
    "/home/ubuntu/k8s/edge1/slo/slo-collector-v2.yaml"
    "/home/ubuntu/k8s/o2ims/measurementjob-crd.yaml"
    "/home/ubuntu/k8s/o2ims/slo-measurementjob.yaml"
)

for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Config file exists: $(basename $file)"
    else
        check_warn "Config file missing: $(basename $file)"
    fi
done

# 10. SCRIPTS AND TOOLS
section "SCRIPTS AND TOOLS"

# Check key scripts
scripts=(
    "/home/ubuntu/scripts/edge1_slo_probe.sh"
    "/home/ubuntu/scripts/slo_integration_test.sh"
    "/home/ubuntu/scripts/o2ims_postcheck.py"
    "/home/ubuntu/scripts/ci_acceptance_test.sh"
)

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        check_pass "Script executable: $(basename $script)"
    elif [ -f "$script" ]; then
        check_warn "Script exists but not executable: $(basename $script)"
    else
        check_fail "Script missing: $(basename $script)"
    fi
done

# SUMMARY
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                         HEALTH CHECK SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Total Checks: $TOTAL_CHECKS"
echo -e "  ${GREEN}Passed:${NC}  $PASSED_CHECKS"
echo -e "  ${YELLOW}Warnings:${NC} $WARNING_CHECKS"
echo -e "  ${RED}Failed:${NC}  $FAILED_CHECKS"
echo ""

# Overall status
if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNING_CHECKS -eq 0 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}     ✅ CLUSTER IS READY FOR STAGING${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit_code=0
    else
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}     ⚠️  CLUSTER IS READY WITH WARNINGS${NC}"
        echo -e "${YELLOW}     Review warnings before proceeding to staging${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit_code=0
    fi
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}     ❌ CLUSTER IS NOT READY FOR STAGING${NC}"
    echo -e "${RED}     Fix failed checks before proceeding${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit_code=1
fi

echo ""
echo "Report generated: $(date)"
exit $exit_code