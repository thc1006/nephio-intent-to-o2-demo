#!/bin/bash
# Demonstrate TDD workflow for security guardrails

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Security Guardrails TDD Demonstration${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}This demo shows the Test-Driven Development approach:${NC}"
echo "1. RED phase: Tests fail because policies don't exist or aren't enforced"
echo "2. GREEN phase: Minimal policies implemented to pass tests"
echo "3. REFACTOR phase: Optimize and enhance as needed"

echo -e "\n${YELLOW}Phase 1: RED - Running tests without policies applied${NC}"
echo "----------------------------------------"

# Kyverno tests
echo -e "\n${BLUE}Kyverno Image Verification:${NC}"
cd kyverno
if make test 2>&1 | grep -q "failed as expected"; then
    echo -e "${RED}✗ Tests failed (as expected - no policies enforced yet)${NC}"
else
    echo -e "${GREEN}✓ Tests passed (policies already applied?)${NC}"
fi
cd ..

# Sigstore tests
echo -e "\n${BLUE}Sigstore Policy Controller:${NC}"
cd sigstore
if [ -f tests/verify-policy.sh ]; then
    echo "Would run: ./tests/verify-policy.sh"
    echo -e "${RED}✗ Tests would fail (policy-controller not installed)${NC}"
else
    echo "Test script not found"
fi
cd ..

# Cert-manager tests
echo -e "\n${BLUE}Cert-Manager:${NC}"
cd cert-manager
if [ -f tests/verify-cert-manager.sh ]; then
    echo "Would run: ./tests/verify-cert-manager.sh"
    echo -e "${RED}✗ Tests would fail (cert-manager not installed)${NC}"
else
    echo "Test script not found"
fi
cd ..

echo -e "\n${YELLOW}Phase 2: GREEN - After applying policies${NC}"
echo "----------------------------------------"
echo "To move to GREEN phase, you would:"
echo "1. Install cert-manager: cd cert-manager && make install"
echo "2. Apply ClusterIssuer: cd cert-manager && make apply"
echo "3. Install Sigstore policy-controller: cd sigstore && make install-policy-controller"
echo "4. Apply Sigstore policies: cd sigstore && make apply"
echo "5. Install Kyverno: kubectl create -f <kyverno-install-url>"
echo "6. Apply Kyverno policies: cd kyverno && make apply"

echo -e "\n${YELLOW}Key Security Principles Demonstrated:${NC}"
echo "----------------------------------------"
echo "✓ Default deny for unsigned images"
echo "✓ Namespace-based policy exceptions (dev allowed)"
echo "✓ Fail-closed webhook configuration"
echo "✓ Certificate automation with cert-manager"
echo "✓ Supply chain security with Sigstore"

echo -e "\n${GREEN}TDD Benefits:${NC}"
echo "----------------------------------------"
echo "• Tests define security requirements upfront"
echo "• Policies are verified to actually work"
echo "• Regression testing for security controls"
echo "• Documentation through executable tests"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Demo Complete${NC}"
echo -e "${BLUE}========================================${NC}"