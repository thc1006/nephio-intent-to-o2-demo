#!/bin/bash

# TDD Test Suite for ACC Verification (ACC-12, ACC-13, ACC-19)
# Following Test-Driven Development principles

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ARTIFACTS_DIR="/home/ubuntu/artifacts/edge1"
mkdir -p "$ARTIFACTS_DIR"

echo "🧪 TDD ACC Verification Test Suite"
echo "=================================="

# Test function helper
test_result() {
    local test_name="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        return 1
    fi
}

# ACC-12 Tests: RootSync Health
test_acc12_rootsync() {
    echo -e "${YELLOW}Testing ACC-12: RootSync Health${NC}"

    # Test 1: RootSync CRD exists
    kubectl get crd rootsyncs.configsync.gke.io >/dev/null 2>&1
    test_result "ACC-12.1: RootSync CRD exists" $?

    # Test 2: Config Sync namespace exists
    kubectl get namespace config-management-system >/dev/null 2>&1
    test_result "ACC-12.2: Config Sync namespace exists" $?

    # Test 3: RootSync resource exists
    kubectl get rootsync -n config-management-system >/dev/null 2>&1
    test_result "ACC-12.3: RootSync resource exists" $?

    # Test 4: RootSync is SYNCED
    SYNC_STATUS=$(kubectl get rootsync -n config-management-system -o jsonpath='{.items[0].status.sync.lastUpdate}' 2>/dev/null || echo "")
    [ -n "$SYNC_STATUS" ]
    test_result "ACC-12.4: RootSync has sync status" $?

    # Test 5: Output artifact exists and is valid JSON
    [ -f "$ARTIFACTS_DIR/acc12_rootsync.json" ]
    test_result "ACC-12.5: acc12_rootsync.json exists" $?

    if [ -f "$ARTIFACTS_DIR/acc12_rootsync.json" ]; then
        jq . "$ARTIFACTS_DIR/acc12_rootsync.json" >/dev/null 2>&1
        test_result "ACC-12.6: acc12_rootsync.json is valid JSON" $?
    fi
}

# ACC-13 Tests: SLO Endpoint Observability
test_acc13_slo() {
    echo -e "${YELLOW}Testing ACC-13: SLO Endpoint Observability${NC}"

    # Test 1: SLO endpoint responds
    curl -s -f "http://172.16.4.45:30090/metrics/api/v1/slo" >/dev/null 2>&1
    test_result "ACC-13.1: SLO endpoint responds" $?

    # Test 2: SLO endpoint returns valid JSON
    SLO_RESPONSE=$(curl -s "http://172.16.4.45:30090/metrics/api/v1/slo" 2>/dev/null)
    echo "$SLO_RESPONSE" | jq . >/dev/null 2>&1
    test_result "ACC-13.2: SLO endpoint returns valid JSON" $?

    # Test 3: SLO contains required metrics
    echo "$SLO_RESPONSE" | jq -e '.metrics.success_rate' >/dev/null 2>&1
    test_result "ACC-13.3: SLO contains success_rate" $?

    echo "$SLO_RESPONSE" | jq -e '.metrics.latency_p95_ms' >/dev/null 2>&1
    test_result "ACC-13.4: SLO contains latency_p95_ms" $?

    # Test 5: Load test affects metrics (TDD: metrics should change under load)
    INITIAL_P95=$(echo "$SLO_RESPONSE" | jq -r '.metrics.latency_p95_ms')

    # Simulate load (hey should be available)
    if command -v hey >/dev/null 2>&1; then
        hey -n 100 -c 10 "http://172.16.4.45:31080" >/dev/null 2>&1
        sleep 2
        NEW_SLO_RESPONSE=$(curl -s "http://172.16.4.45:30090/metrics/api/v1/slo" 2>/dev/null)
        NEW_P95=$(echo "$NEW_SLO_RESPONSE" | jq -r '.metrics.latency_p95_ms')

        # Metrics should have updated (timestamp should be different)
        INITIAL_TS=$(echo "$SLO_RESPONSE" | jq -r '.timestamp')
        NEW_TS=$(echo "$NEW_SLO_RESPONSE" | jq -r '.timestamp')
        [ "$INITIAL_TS" != "$NEW_TS" ]
        test_result "ACC-13.5: SLO metrics update under load" $?
    else
        echo -e "${YELLOW}⚠️  SKIP${NC}: ACC-13.5 (hey not available for load testing)"
    fi

    # Test 6: Output artifact exists and is valid
    [ -f "$ARTIFACTS_DIR/acc13_slo.json" ]
    test_result "ACC-13.6: acc13_slo.json exists" $?

    if [ -f "$ARTIFACTS_DIR/acc13_slo.json" ]; then
        jq . "$ARTIFACTS_DIR/acc13_slo.json" >/dev/null 2>&1
        test_result "ACC-13.7: acc13_slo.json is valid JSON" $?
    fi
}

# ACC-19 Tests: Edge PR Verification
test_acc19_pr() {
    echo -e "${YELLOW}Testing ACC-19: Edge PR Verification${NC}"

    # Test 1: O2IMS resources exist (using MeasurementJobs as PR alternative)
    kubectl get measurementjobs -A >/dev/null 2>&1
    test_result "ACC-19.1: O2IMS resources exist" $?

    # Test 2: Service endpoints respond
    curl -s -f "http://172.16.4.45:31080" >/dev/null 2>&1
    test_result "ACC-19.2: NodePort 31080 responds" $?

    curl -s -f "http://172.16.4.45:31443" >/dev/null 2>&1 || curl -s -f "http://172.16.4.45:31280" >/dev/null 2>&1
    test_result "ACC-19.3: NodePort 31443/31280 responds" $?

    # Test 4: O2IMS measurement job is active
    MEASUREMENT_STATUS=$(kubectl get measurementjobs -A -o jsonpath='{.items[0].status}' 2>/dev/null || echo "")
    [ -n "$MEASUREMENT_STATUS" ]
    test_result "ACC-19.4: MeasurementJob has status" $?

    # Test 5: Output artifact exists
    [ -f "$ARTIFACTS_DIR/acc19_ready.json" ]
    test_result "ACC-19.5: acc19_ready.json exists" $?

    if [ -f "$ARTIFACTS_DIR/acc19_ready.json" ]; then
        jq . "$ARTIFACTS_DIR/acc19_ready.json" >/dev/null 2>&1
        test_result "ACC-19.6: acc19_ready.json is valid JSON" $?

        # Test READY status
        OVERALL_STATUS=$(jq -r '.validation_summary.overall_status' "$ARTIFACTS_DIR/acc19_ready.json" 2>/dev/null)
        [[ "$OVERALL_STATUS" =~ READY ]]
        test_result "ACC-19.7: Overall status is READY" $?
    fi
}

# Run all tests
echo -e "\n${YELLOW}🏃 Running TDD Test Suite${NC}"
echo "=========================="

FAILED_TESTS=0

test_acc12_rootsync || ((FAILED_TESTS++))
echo ""
test_acc13_slo || ((FAILED_TESTS++))
echo ""
test_acc19_pr || ((FAILED_TESTS++))

echo -e "\n${YELLOW}📊 Test Results Summary${NC}"
echo "======================="

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! ACC verification complete.${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED_TESTS test group(s) failed. Implementing solutions...${NC}"
    exit 1
fi