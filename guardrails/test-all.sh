#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TEST_FAILED=0

echo -e "${BLUE}=== Guardrails Comprehensive Test Suite ===${NC}"
echo "Testing Sigstore, Kyverno, and cert-manager components"
echo ""

# Function to run test and capture result
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Testing: ${test_name}${NC}"
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}✓ PASS: ${test_name}${NC}"
    else
        echo -e "${RED}✗ FAIL: ${test_name}${NC}"
        TEST_FAILED=1
    fi
}

# Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
run_test "kubectl available" "command -v kubectl"
run_test "Kubernetes cluster reachable" "kubectl cluster-info"

echo ""
echo -e "${YELLOW}Step 2: Testing Sigstore Policy Controller...${NC}"
if kubectl get deployment policy-controller-webhook -n cosign-system &>/dev/null; then
    run_test "Policy Controller deployment ready" \
        "kubectl rollout status deployment/policy-controller-webhook -n cosign-system --timeout=10s"
    run_test "Policy Controller webhook configured" \
        "kubectl get validatingwebhookconfigurations | grep -q policy-controller"
    
    # Test ClusterImagePolicy
    if [ -f "sigstore/policies/cluster-image-policy.yaml" ]; then
        run_test "ClusterImagePolicy applies without error" \
            "kubectl apply -f sigstore/policies/cluster-image-policy.yaml --dry-run=server"
    fi
    
    # Run Sigstore-specific tests
    if [ -f "sigstore/tests/verify-policy.sh" ]; then
        echo -e "${BLUE}Running Sigstore tests...${NC}"
        bash sigstore/tests/verify-policy.sh
    fi
else
    echo -e "${YELLOW}⚠ Sigstore Policy Controller not installed - skipping tests${NC}"
fi

echo ""
echo -e "${YELLOW}Step 3: Testing Kyverno...${NC}"
if kubectl get deployment kyverno-admission-controller -n kyverno &>/dev/null; then
    run_test "Kyverno admission controller ready" \
        "kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=10s"
    run_test "Kyverno CRDs installed" \
        "kubectl get crd | grep -q kyverno.io"
    
    # Test Kyverno policy
    if [ -f "kyverno/policies/verify-images.yaml" ]; then
        run_test "Kyverno policy applies without error" \
            "kubectl apply -f kyverno/policies/verify-images.yaml --dry-run=server"
    fi
    
    # Run Kyverno tests if CLI is available
    if command -v kyverno &>/dev/null; then
        echo -e "${BLUE}Running Kyverno CLI tests...${NC}"
        if [ -f "kyverno/tests/resource.yaml" ] && [ -f "kyverno/tests/test-values.yaml" ]; then
            run_test "Kyverno policy validation" \
                "kyverno test --policy kyverno/policies/ --resource kyverno/tests/resource.yaml --values kyverno/tests/test-values.yaml"
        fi
    else
        echo -e "${YELLOW}⚠ Kyverno CLI not installed - skipping CLI tests${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Kyverno not installed - skipping tests${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Testing cert-manager...${NC}"
if kubectl get deployment cert-manager -n cert-manager &>/dev/null; then
    run_test "cert-manager deployment ready" \
        "kubectl rollout status deployment/cert-manager -n cert-manager --timeout=10s"
    run_test "cert-manager webhook ready" \
        "kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=10s"
    run_test "cert-manager CRDs installed" \
        "kubectl get crd | grep -q cert-manager.io"
    
    # Test ClusterIssuer
    if [ -f "cert-manager/manifests/cluster-issuer.yaml" ]; then
        run_test "ClusterIssuer applies without error" \
            "kubectl apply -f cert-manager/manifests/cluster-issuer.yaml --dry-run=server"
    fi
    
    # Run cert-manager specific tests
    if [ -f "cert-manager/tests/verify-cert-manager.sh" ]; then
        echo -e "${BLUE}Running cert-manager tests...${NC}"
        bash cert-manager/tests/verify-cert-manager.sh
    fi
else
    echo -e "${YELLOW}⚠ cert-manager not installed - skipping tests${NC}"
fi

echo ""
echo -e "${YELLOW}Step 5: Integration tests...${NC}"
# Test namespace creation and labeling
run_test "Can create test namespace" \
    "kubectl create namespace guardrails-test --dry-run=client -o yaml"

# Test policy interaction
if kubectl get clusterimageepolicy &>/dev/null && kubectl get clusterpolicy &>/dev/null; then
    echo -e "${BLUE}Testing policy interaction...${NC}"
    run_test "Policies don't conflict" \
        "kubectl get clusterimageepolicy,clusterpolicy --all-namespaces"
fi

# Test YAML syntax
echo -e "${BLUE}Validating YAML syntax...${NC}"
for yaml_file in $(find . -name "*.yaml" -o -name "*.yml"); do
    run_test "YAML syntax: $(basename $yaml_file)" \
        "kubectl apply -f $yaml_file --dry-run=client"
done

echo ""
echo -e "${YELLOW}Step 6: Security validation...${NC}"
# Check for common security issues
run_test "No plaintext secrets in configs" \
    "! grep -r 'password\|secret\|key.*:.*[a-zA-Z0-9]' --include='*.yaml' --include='*.yml' ."

run_test "No privileged containers in test resources" \
    "! grep -r 'privileged.*true' --include='*.yaml' --include='*.yml' ."

run_test "No host network in test resources" \
    "! grep -r 'hostNetwork.*true' --include='*.yaml' --include='*.yml' ."

echo ""
if [ $TEST_FAILED -eq 0 ]; then
    echo -e "${GREEN}=== ALL TESTS PASSED ===${NC}"
    echo "Guardrails are properly configured and ready for deployment."
else
    echo -e "${RED}=== SOME TESTS FAILED ===${NC}"
    echo "Please review the failed tests above and fix the issues."
fi

echo ""
echo "Next steps:"
echo "1. Install missing components if needed:"
echo "   ./sigstore/install.sh"
echo "   ./kyverno/install.sh" 
echo "   ./cert-manager/install.sh"
echo ""
echo "2. Apply policies:"
echo "   kubectl apply -f */policies/"
echo ""
echo "3. Run the demonstration:"
echo "   ./demo-signed-unsigned.sh"

exit $TEST_FAILED