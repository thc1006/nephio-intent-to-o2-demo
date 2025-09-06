#!/bin/bash
# Test script to verify cert-manager is working
# Initially these tests will FAIL (TDD RED phase)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running cert-manager tests...${NC}"

# Test 1: Check if cert-manager CRDs are installed
echo "Test 1: Checking cert-manager CRDs..."
if kubectl get crd certificates.cert-manager.io 2>/dev/null; then
    echo -e "${GREEN}PASS: cert-manager CRDs found${NC}"
else
    echo -e "${RED}FAIL: cert-manager CRDs not found${NC}"
    exit 1
fi

# Test 2: Check if cert-manager namespace exists
echo "Test 2: Checking cert-manager namespace..."
if kubectl get namespace cert-manager 2>/dev/null; then
    echo -e "${GREEN}PASS: cert-manager namespace exists${NC}"
else
    echo -e "${RED}FAIL: cert-manager namespace not found${NC}"
    exit 1
fi

# Test 3: Check if cert-manager pods are running
echo "Test 3: Checking cert-manager pods..."
READY_PODS=$(kubectl get pods -n cert-manager -o json 2>/dev/null | jq '.items | map(select(.status.phase == "Running")) | length' || echo 0)
if [ "$READY_PODS" -ge 3 ]; then
    echo -e "${GREEN}PASS: cert-manager pods are running${NC}"
else
    echo -e "${RED}FAIL: cert-manager pods not ready (found $READY_PODS)${NC}"
    exit 1
fi

# Test 4: Check if ClusterIssuer exists
echo "Test 4: Checking ClusterIssuer..."
if kubectl get clusterissuer selfsigned-cluster-issuer 2>/dev/null; then
    echo -e "${GREEN}PASS: ClusterIssuer exists${NC}"
else
    echo -e "${RED}FAIL: ClusterIssuer not found${NC}"
    exit 1
fi

# Test 5: Try to create a test certificate
echo "Test 5: Creating test certificate..."
if kubectl apply -f test-certificate.yaml 2>/dev/null; then
    echo -e "${GREEN}PASS: Certificate resource created${NC}"
    
    # Wait for certificate to be ready
    echo "Waiting for certificate to be issued..."
    for i in {1..30}; do
        if kubectl get certificate test-tls-cert -o json | jq -e '.status.conditions[] | select(.type=="Ready" and .status=="True")' 2>/dev/null; then
            echo -e "${GREEN}PASS: Certificate issued successfully${NC}"
            kubectl delete certificate test-tls-cert --ignore-not-found=true
            break
        fi
        sleep 2
    done
else
    echo -e "${RED}FAIL: Could not create certificate${NC}"
    exit 1
fi

echo -e "${GREEN}All cert-manager tests passed!${NC}"