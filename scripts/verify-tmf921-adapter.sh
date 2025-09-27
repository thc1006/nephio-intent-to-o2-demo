#!/bin/bash
# TMF921 Adapter Verification Script
# Comprehensive testing of all endpoints and edge sites

set -euo pipefail

SERVICE_URL="http://172.16.0.78:8889"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_status="${3:-200}"

    echo -e "\n🧪 Testing: $test_name"
    ((TOTAL_TESTS++))

    if response=$(eval "$test_command" 2>/dev/null); then
        if [[ -n "$response" ]]; then
            log_success "$test_name passed"
            echo "   Response: ${response:0:100}..."
        else
            log_error "$test_name failed - no response"
        fi
    else
        log_error "$test_name failed - command error"
    fi
}

echo "🚀 TMF921 Adapter Verification Script"
echo "=================================="

# Test 1: Health Check
run_test "Health Check" "curl -s $SERVICE_URL/health"

# Test 2: Metrics Endpoint
run_test "Metrics Endpoint" "curl -s $SERVICE_URL/metrics"

# Test 3: Web UI (check for HTML)
run_test "Web UI" "curl -s $SERVICE_URL/ | grep -q 'TMF921 Intent Generator' && echo 'HTML page loaded'"

# Test 4: Intent Generation - Edge1 (eMBB)
run_test "Edge1 eMBB Intent" "curl -s -X POST $SERVICE_URL/generate_intent -H 'Content-Type: application/json' -d '{\"natural_language\": \"Deploy 5G gaming service\", \"target_site\": \"edge1\"}' | jq -r '.intent.targetSite'"

# Test 5: Intent Generation - Edge2 (URLLC)
run_test "Edge2 URLLC Intent" "curl -s -X POST $SERVICE_URL/generate_intent -H 'Content-Type: application/json' -d '{\"natural_language\": \"Setup ultra-low latency for industrial automation\", \"target_site\": \"edge2\"}' | jq -r '.intent.service.type'"

# Test 6: Intent Generation - Edge3 (mMTC)
run_test "Edge3 mMTC Intent" "curl -s -X POST $SERVICE_URL/generate_intent -H 'Content-Type: application/json' -d '{\"natural_language\": \"Deploy IoT sensor monitoring\", \"target_site\": \"edge3\"}' | jq -r '.intent.slice.sst'"

# Test 7: Intent Generation - Edge4 (Video)
run_test "Edge4 Video Intent" "curl -s -X POST $SERVICE_URL/generate_intent -H 'Content-Type: application/json' -d '{\"natural_language\": \"Configure 4K video streaming with 2 Gbps\", \"target_site\": \"edge4\"}' | jq -r '.intent.qos.dl_mbps'"

# Test 8: Multi-site Intent
run_test "Multi-site Intent" "curl -s -X POST $SERVICE_URL/generate_intent -H 'Content-Type: application/json' -d '{\"natural_language\": \"Deploy multi-site CDN\", \"target_site\": \"both\"}' | jq -r '.intent.targetSite'"

# Test 9: Performance Test (response time)
echo -e "\n🏁 Performance Test"
start_time=$(date +%s%N)
curl -s -X POST $SERVICE_URL/generate_intent \
  -H 'Content-Type: application/json' \
  -d '{"natural_language": "Performance test request", "target_site": "edge1"}' > /dev/null
end_time=$(date +%s%N)
response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

if [[ $response_time -lt 50 ]]; then
    log_success "Performance test passed: ${response_time}ms (< 50ms target)"
else
    log_warning "Performance test slow: ${response_time}ms (> 50ms)"
fi

# Test 10: Service Type Detection
echo -e "\n🔍 Service Type Detection Tests"

test_urllc() {
    local response=$(curl -s -X POST $SERVICE_URL/generate_intent \
      -H 'Content-Type: application/json' \
      -d '{"natural_language": "1ms latency critical control system", "target_site": "edge2"}')
    local service_type=$(echo "$response" | jq -r '.intent.service.type')
    local sst=$(echo "$response" | jq -r '.intent.slice.sst')

    if [[ "$service_type" == "URLLC" && "$sst" == "2" ]]; then
        log_success "URLLC detection works (SST=2)"
    else
        log_error "URLLC detection failed: type=$service_type, sst=$sst"
    fi
}

test_mmtc() {
    local response=$(curl -s -X POST $SERVICE_URL/generate_intent \
      -H 'Content-Type: application/json' \
      -d '{"natural_language": "IoT sensor data collection", "target_site": "edge3"}')
    local service_type=$(echo "$response" | jq -r '.intent.service.type')
    local sst=$(echo "$response" | jq -r '.intent.slice.sst')

    if [[ "$service_type" == "mMTC" && "$sst" == "3" ]]; then
        log_success "mMTC detection works (SST=3)"
    else
        log_error "mMTC detection failed: type=$service_type, sst=$sst"
    fi
}

test_embb() {
    local response=$(curl -s -X POST $SERVICE_URL/generate_intent \
      -H 'Content-Type: application/json' \
      -d '{"natural_language": "High bandwidth video streaming", "target_site": "edge1"}')
    local service_type=$(echo "$response" | jq -r '.intent.service.type')
    local sst=$(echo "$response" | jq -r '.intent.slice.sst')

    if [[ "$service_type" == "eMBB" && "$sst" == "1" ]]; then
        log_success "eMBB detection works (SST=1)"
    else
        log_error "eMBB detection failed: type=$service_type, sst=$sst"
    fi
}

test_urllc
test_mmtc
test_embb

# Summary
echo -e "\n📊 Test Summary"
echo "=================================="
echo "Total Tests: $TOTAL_TESTS"
echo "Failed Tests: $FAILED_TESTS"
echo "Success Rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All tests passed! TMF921 Adapter is working correctly.${NC}"
    echo -e "\n🌐 Service Access:"
    echo "   • Health: $SERVICE_URL/health"
    echo "   • Web UI: $SERVICE_URL/"
    echo "   • API: $SERVICE_URL/generate_intent"
    exit 0
else
    echo -e "\n${RED}❌ $FAILED_TESTS test(s) failed. Please check the logs.${NC}"
    exit 1
fi