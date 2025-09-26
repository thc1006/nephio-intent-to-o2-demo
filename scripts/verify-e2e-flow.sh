#!/bin/bash

echo "========================================="
echo "End-to-End Flow Verification"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test a service
test_service() {
    local name=$1
    local url=$2
    local expected=$3

    echo -n "Testing $name... "
    response=$(curl -s -o /dev/null -w "%{http_code}" $url 2>/dev/null)

    if [[ "$response" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $response)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $response, expected $expected)"
        ((TESTS_FAILED++))
    fi
}

# Function to test command
test_command() {
    local name=$1
    local cmd=$2

    echo -n "Testing $name... "
    if eval $cmd > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
    fi
}

echo "1. Testing Core Services"
echo "------------------------"
test_service "Real-time Monitor" "http://localhost:8001" "200"
test_service "TMF921 Processor" "http://localhost:8002/health" "200"
test_service "TMux WebSocket Bridge" "http://localhost:8004" "200"
test_service "Web Frontend" "http://localhost:8005" "200"
test_service "Gitea" "http://localhost:8888" "200"
test_service "VictoriaMetrics" "http://localhost:8428/health" "200"
test_service "Grafana" "http://localhost:3000/api/health" "200"
test_service "Alertmanager" "http://localhost:9093/-/healthy" "200"
test_service "Prometheus (Local)" "http://localhost:9090/-/healthy" "200"

echo ""
echo "2. Testing Kubernetes Clusters"
echo "-------------------------------"
test_command "K3s Cluster" "KUBECONFIG=/home/ubuntu/.kube/config-k3s kubectl get nodes | grep -q Ready"
test_command "K3s System Pods" "KUBECONFIG=/home/ubuntu/.kube/config-k3s kubectl get pods -n kube-system | grep -q Running"

echo ""
echo "3. Testing Intent Processing"
echo "-----------------------------"
test_command "Claude CLI" "tmux has-session -t claude-intent 2>/dev/null"
test_command "Intent Processor" "python3 -c 'import sys; sys.path.append(\"/home/ubuntu/nephio-intent-to-o2-demo\"); from services.claude_intent_processor import ClaudeIntentProcessor; print(\"OK\")' | grep -q OK"

echo ""
echo "4. Testing Metrics Flow"
echo "------------------------"
echo -n "Testing VictoriaMetrics metrics ingestion... "
metrics_count=$(curl -s http://localhost:8428/api/v1/label/__name__/values | jq '.data | length' 2>/dev/null)
if [[ "$metrics_count" -gt 100 ]]; then
    echo -e "${GREEN}✓ PASS${NC} ($metrics_count metric types)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (only $metrics_count metric types)"
    ((TESTS_FAILED++))
fi

echo -n "Testing Edge metrics presence... "
edge_metrics=$(curl -s http://localhost:8428/api/v1/label/instance/values | jq -r '.data[]' 2>/dev/null | grep -c edge)
if [[ "$edge_metrics" -gt 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC} ($edge_metrics edge instances)"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ WARN${NC} (no edge metrics found yet)"
fi

echo ""
echo "5. Testing GitOps Components"
echo "-----------------------------"
test_command "Gitea SSH" "nc -zv localhost 2222 2>/dev/null"
test_command "Gitea Actions Enabled" "docker exec gitea grep -q 'ENABLED = true' /data/gitea/conf/app.ini"

echo ""
echo "6. Testing Docker Services"
echo "---------------------------"
echo -n "Testing Docker containers health... "
unhealthy=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v healthy | grep -c -E "(restarting|exited)" || true)
if [[ "$unhealthy" -eq 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC} (all containers healthy)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} ($unhealthy unhealthy containers)"
    ((TESTS_FAILED++))
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [[ "$TESTS_FAILED" -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed! System is fully operational.${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠ Some tests failed. Please review the output above.${NC}"
    exit 1
fi