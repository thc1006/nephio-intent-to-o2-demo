#!/usr/bin/env bash
# LLM Integration Test Script for VM-3
# Tests the integration between VM-1 and VM-3 LLM Adapter

set -euo pipefail

# Configuration
LLM_ADAPTER_URL="${LLM_ADAPTER_URL:-http://172.16.2.10:8888}"
TEST_TIMEOUT="${TEST_TIMEOUT:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
log_test() { echo -e "\n${YELLOW}[TEST]${NC} $1"; }

# Test 1: Health Check
test_health_check() {
    log_test "Testing health check endpoint"

    local response
    if response=$(curl -s --connect-timeout "$TEST_TIMEOUT" "${LLM_ADAPTER_URL}/health"); then
        if echo "$response" | jq -e '.status == "healthy"' >/dev/null 2>&1; then
            log_success "Health check passed"
            echo "Response: $response"
            return 0
        else
            log_fail "Health check returned non-healthy status"
            echo "Response: $response"
            return 1
        fi
    else
        log_fail "Health check endpoint not reachable"
        return 1
    fi
}

# Test 2: eMBB Intent Generation
test_embb_intent() {
    log_test "Testing eMBB intent generation"

    local request_body='{
        "natural_language": "Deploy eMBB slice at edge1 with 1Gbps downlink for video streaming",
        "target_site": "edge1"
    }'

    local response
    if response=$(curl -s --connect-timeout "$TEST_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "${LLM_ADAPTER_URL}/generate_intent"); then

        # Check required fields
        if echo "$response" | jq -e '.intentId and .serviceType and .targetSite' >/dev/null 2>&1; then
            local service_type=$(echo "$response" | jq -r '.serviceType')
            local target_site=$(echo "$response" | jq -r '.targetSite')

            if [[ "$service_type" == *"mobile-broadband"* ]] && [[ "$target_site" == "edge1" ]]; then
                log_success "eMBB intent generation passed"
                echo "Intent ID: $(echo "$response" | jq -r '.intentId')"
                return 0
            else
                log_fail "Incorrect service type or target site"
                echo "Expected: enhanced-mobile-broadband at edge1"
                echo "Got: $service_type at $target_site"
                return 1
            fi
        else
            log_fail "Response missing required fields"
            echo "Response: $response"
            return 1
        fi
    else
        log_fail "Intent generation endpoint not reachable"
        return 1
    fi
}

# Test 3: URLLC Intent Generation
test_urllc_intent() {
    log_test "Testing URLLC intent generation"

    local request_body='{
        "natural_language": "Create ultra-reliable service for autonomous vehicles at edge2 with 1ms latency",
        "target_site": "edge2"
    }'

    local response
    if response=$(curl -s --connect-timeout "$TEST_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "${LLM_ADAPTER_URL}/generate_intent"); then

        if echo "$response" | jq -e '.intentId' >/dev/null 2>&1; then
            local service_type=$(echo "$response" | jq -r '.serviceType // .intentParameters.serviceType // "unknown"')
            local latency=$(echo "$response" | jq -r '.sla.latency // .intentParameters.qosParameters.latencyMs // 0')

            if [[ "$service_type" == *"ultra-reliable"* ]] || [[ "$latency" -le 5 ]]; then
                log_success "URLLC intent generation passed"
                echo "Latency requirement: ${latency}ms"
                return 0
            else
                log_fail "URLLC requirements not met"
                echo "Service type: $service_type, Latency: $latency"
                return 1
            fi
        else
            log_fail "Response missing intent ID"
            echo "Response: $response"
            return 1
        fi
    else
        log_fail "URLLC intent generation failed"
        return 1
    fi
}

# Test 4: mMTC Multi-site Intent
test_mmtc_multisite() {
    log_test "Testing mMTC multi-site intent generation"

    local request_body='{
        "natural_language": "Setup IoT network for 50000 sensors across both sites",
        "target_site": "both"
    }'

    local response
    if response=$(curl -s --connect-timeout "$TEST_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "${LLM_ADAPTER_URL}/generate_intent"); then

        if echo "$response" | jq -e '.targetSite == "both"' >/dev/null 2>&1; then
            log_success "Multi-site mMTC intent generation passed"
            return 0
        else
            log_fail "Target site not set to 'both'"
            echo "Response: $response"
            return 1
        fi
    else
        log_fail "mMTC intent generation failed"
        return 1
    fi
}

# Test 5: Error Handling
test_error_handling() {
    log_test "Testing error handling"

    local request_body='{
        "natural_language": "",
        "target_site": "invalid"
    }'

    local response
    local http_code
    http_code=$(curl -s -o /tmp/llm_error_response.txt -w "%{http_code}" \
        --connect-timeout "$TEST_TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "${LLM_ADAPTER_URL}/generate_intent")

    response=$(cat /tmp/llm_error_response.txt 2>/dev/null || echo "{}")

    if [[ "$http_code" -ge 400 ]] || echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        log_success "Error handling working correctly"
        return 0
    else
        log_fail "Invalid request should return error"
        echo "HTTP Code: $http_code"
        echo "Response: $response"
        return 1
    fi
}

# Test 6: Response Time
test_response_time() {
    log_test "Testing response time (<5 seconds)"

    local request_body='{
        "natural_language": "Deploy basic network slice at edge1",
        "target_site": "edge1"
    }'

    local start_time=$(date +%s)
    local response

    if response=$(curl -s --connect-timeout 5 --max-time 5 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "${LLM_ADAPTER_URL}/generate_intent" 2>/dev/null); then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        if [[ $duration -le 5 ]]; then
            log_success "Response time acceptable: ${duration}s"
            return 0
        else
            log_fail "Response time too slow: ${duration}s"
            return 1
        fi
    else
        log_fail "Request timed out (>5 seconds)"
        return 1
    fi
}

# Main execution
main() {
    echo "================================================"
    echo "LLM Adapter Integration Test Suite"
    echo "Target: $LLM_ADAPTER_URL"
    echo "================================================"

    # Run tests
    test_health_check || true
    test_embb_intent || true
    test_urllc_intent || true
    test_mmtc_multisite || true
    test_error_handling || true
    test_response_time || true

    # Summary
    echo ""
    echo "================================================"
    echo "Test Summary"
    echo "================================================"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All tests passed! LLM Adapter is ready for integration.${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please check the LLM Adapter implementation.${NC}"
        echo -e "\nRefer to: /home/ubuntu/nephio-intent-to-o2-demo/docs/VM3_INTEGRATION_SPEC.md"
        exit 1
    fi
}

# Run main
main "$@"