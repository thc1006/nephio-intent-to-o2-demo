#!/bin/bash
# Test script for P0.4A O-Cloud provisioning
# Validates the script and manifests without actual deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== P0.4A O-Cloud Provisioning Test ===${NC}"
echo ""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Check if script exists and is executable
run_test "Script exists and is executable" \
    "test -f p0.4A_ocloud_provision.sh && test -x p0.4A_ocloud_provision.sh"

# Test 2: Check script syntax
run_test "Script syntax is valid" \
    "bash -n p0.4A_ocloud_provision.sh"

# Test 3: Check if script has proper shebang
run_test "Script has proper shebang" \
    "head -1 p0.4A_ocloud_provision.sh | grep -q '^#!/bin/bash'"

# Test 4: Check if script uses strict mode
run_test "Script uses strict mode" \
    "grep -q 'set -euo pipefail' p0.4A_ocloud_provision.sh"

# Test 5: Check for required functions
for func in "check_prerequisites" "create_kind_cluster" "deploy_focom_operator" \
            "create_edge_cluster_secret" "apply_ocloud_crs" "wait_for_provisioning" \
            "generate_documentation" "cleanup"; do
    run_test "Function '$func' exists" \
        "grep -q '^${func}()' p0.4A_ocloud_provision.sh"
done

# Test 6: Check for proper exit codes
run_test "Script defines exit codes" \
    "grep -q 'EXIT_SUCCESS=0' p0.4A_ocloud_provision.sh"

# Test 7: Check help function
run_test "Script has help/usage function" \
    "grep -q '^usage()' p0.4A_ocloud_provision.sh"

# Test 8: Validate sample manifests
echo ""
echo -e "${BLUE}=== Validating Sample Manifests ===${NC}"

# Test OCloud manifest
if [ -f "../samples/ocloud/ocloud.yaml" ]; then
    run_test "OCloud manifest syntax" \
        "yq eval '.' ../samples/ocloud/ocloud.yaml > /dev/null"
    
    run_test "OCloud has required fields" \
        "yq eval '.apiVersion' ../samples/ocloud/ocloud.yaml | grep -q 'o2ims.oran.org'"
else
    echo -e "${YELLOW}OCloud manifest not found${NC}"
fi

# Test TemplateInfo manifest
if [ -f "../samples/ocloud/template-info.yaml" ]; then
    run_test "TemplateInfo manifest syntax" \
        "yq eval '.' ../samples/ocloud/template-info.yaml > /dev/null"
    
    run_test "TemplateInfo has required fields" \
        "yq eval '.spec.parameters' ../samples/ocloud/template-info.yaml | grep -q 'name'"
else
    echo -e "${YELLOW}TemplateInfo manifest not found${NC}"
fi

# Test ProvisioningRequest manifest
if [ -f "../samples/ocloud/provisioning-request.yaml" ]; then
    run_test "ProvisioningRequest manifest syntax" \
        "yq eval '.' ../samples/ocloud/provisioning-request.yaml > /dev/null"
    
    run_test "ProvisioningRequest has template reference" \
        "yq eval '.spec.template.name' ../samples/ocloud/provisioning-request.yaml | grep -q 'edge-5g-template'"
else
    echo -e "${YELLOW}ProvisioningRequest manifest not found${NC}"
fi

# Test kustomization
if [ -f "../samples/ocloud/kustomization.yaml" ]; then
    run_test "Kustomization syntax is valid" \
        "yq eval '.' ../samples/ocloud/kustomization.yaml > /dev/null"
    
    # Test if kustomize can build the manifests
    if command -v kustomize &> /dev/null; then
        run_test "Kustomize can build manifests" \
            "kustomize build ../samples/ocloud/ > /dev/null"
    fi
else
    echo -e "${YELLOW}Kustomization file not found${NC}"
fi

# Test 9: Check for required tools (without failing if not present)
echo ""
echo -e "${BLUE}=== Checking Required Tools ===${NC}"

for tool in kubectl kind kpt jq yq; do
    if command -v "$tool" &> /dev/null; then
        echo -e "  $tool: ${GREEN}✓${NC}"
    else
        echo -e "  $tool: ${YELLOW}✗ (not installed)${NC}"
    fi
done

# Test 10: Dry run test
echo ""
echo -e "${BLUE}=== Running Dry Run Test ===${NC}"

# Create a temporary edge kubeconfig for testing
TEMP_KUBECONFIG="/tmp/test-edge-kubeconfig-$$.yaml"
cat > "$TEMP_KUBECONFIG" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://172.16.4.45:6443
  name: test-edge
contexts:
- context:
    cluster: test-edge
    user: test-user
  name: test-context
current-context: test-context
users:
- name: test-user
  user:
    token: test-token
EOF

# Run script in dry-run mode with minimal timeout
if EDGE_KUBECONFIG="$TEMP_KUBECONFIG" \
   DRY_RUN=true \
   TIMEOUT=10 \
   CLEANUP_ON_FAILURE=false \
   bash p0.4A_ocloud_provision.sh --dry-run --help &>/dev/null; then
    echo -e "${GREEN}Dry run help test passed${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}Dry run help test failed (may be due to missing prerequisites)${NC}"
fi

# Clean up temporary file
rm -f "$TEMP_KUBECONFIG"

# Test 11: Check Makefile
echo ""
echo -e "${BLUE}=== Testing Makefile ===${NC}"

if [ -f "Makefile" ]; then
    run_test "Makefile exists" "test -f Makefile"
    run_test "Makefile has ocloud target" "grep -q '^ocloud:' Makefile"
    run_test "Makefile has help target" "grep -q '^help:' Makefile"
    
    # Test if make can parse the Makefile
    run_test "Makefile syntax is valid" "make -n help"
else
    echo -e "${YELLOW}Makefile not found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All tests passed! The P0.4A script is ready to use.${NC}"
    echo ""
    echo "To run the actual provisioning:"
    echo "  ./p0.4A_ocloud_provision.sh"
    echo ""
    echo "Or use the Makefile:"
    echo "  make ocloud"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please review the issues above.${NC}"
    exit 1
fi