#!/bin/bash
# Test script to verify Sigstore policies are working
# Initially these tests will FAIL (TDD RED phase)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running Sigstore policy tests...${NC}"

# Test 1: Unsigned image should be rejected in production namespace
echo "Test 1: Deploying unsigned image to production namespace..."
if kubectl apply -f test-unsigned-deployment.yaml --dry-run=server 2>/dev/null; then
    echo -e "${RED}FAIL: Unsigned image was accepted (policy not enforced)${NC}"
    exit 1
else
    echo -e "${GREEN}PASS: Unsigned image was rejected${NC}"
fi

# Test 2: Signed image should be accepted
echo "Test 2: Deploying signed image to production namespace..."
if kubectl apply -f test-signed-deployment.yaml --dry-run=server 2>/dev/null; then
    echo -e "${GREEN}PASS: Signed image was accepted${NC}"
else
    echo -e "${RED}FAIL: Signed image was rejected${NC}"
    exit 1
fi

# Test 3: Dev namespace should allow unsigned images
echo "Test 3: Deploying unsigned image to dev namespace..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
sed 's/namespace: production/namespace: dev/g' test-unsigned-deployment.yaml | \
    kubectl apply -f - --dry-run=server 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Dev namespace allows unsigned images${NC}"
else
    echo -e "${RED}FAIL: Dev namespace rejected unsigned image${NC}"
    exit 1
fi

echo -e "${GREEN}All Sigstore policy tests passed!${NC}"