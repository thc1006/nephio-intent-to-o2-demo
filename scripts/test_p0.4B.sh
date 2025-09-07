#!/bin/bash
# Test script for p0.4B_vm2_manual.sh
# This script validates the deployment script without actually running it

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}  Testing P0.4B VM-2 Manual Deployment Script ${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

SCRIPT_PATH="./scripts/p0.4B_vm2_manual.sh"
ERRORS=0

# Test 1: Script exists and is executable
echo -e "${YELLOW}Test 1: Script existence and permissions${NC}"
if [[ -f "$SCRIPT_PATH" ]]; then
    echo -e "${GREEN}✓ Script exists${NC}"
    if [[ -x "$SCRIPT_PATH" ]]; then
        echo -e "${GREEN}✓ Script is executable${NC}"
    else
        echo -e "${RED}✗ Script is not executable${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Script not found at $SCRIPT_PATH${NC}"
    exit 1
fi
echo ""

# Test 2: Syntax validation
echo -e "${YELLOW}Test 2: Shell syntax validation${NC}"
if bash -n "$SCRIPT_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ Script syntax is valid${NC}"
else
    echo -e "${RED}✗ Script has syntax errors${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 3: Check for required commands in script
echo -e "${YELLOW}Test 3: Required commands check${NC}"
REQUIRED_COMMANDS=("docker" "kubectl" "kind" "jq" "yq" "curl" "git")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if grep -q "command_exists $cmd\|command -v $cmd\|which $cmd" "$SCRIPT_PATH"; then
        echo -e "${GREEN}✓ Script checks for: $cmd${NC}"
    else
        echo -e "${YELLOW}⚠ Script may not check for: $cmd${NC}"
    fi
done
echo ""

# Test 4: Configuration validation
echo -e "${YELLOW}Test 4: Configuration validation${NC}"
if grep -q 'VM2_IP="172.16.4.45"' "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Correct VM2 IP configured${NC}"
else
    echo -e "${RED}✗ VM2 IP not correctly configured${NC}"
    ERRORS=$((ERRORS + 1))
fi

if grep -q 'VM1_GITEA_URL="http://147.251.115.143:8888"' "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Correct Gitea URL configured${NC}"
else
    echo -e "${RED}✗ Gitea URL not correctly configured${NC}"
    ERRORS=$((ERRORS + 1))
fi

if grep -q 'GITEA_REPO="edge1-config"' "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Correct repository name configured${NC}"
else
    echo -e "${RED}✗ Repository name not correctly configured${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 5: Error handling
echo -e "${YELLOW}Test 5: Error handling mechanisms${NC}"
if grep -q "set -euo pipefail" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script uses strict error handling${NC}"
else
    echo -e "${RED}✗ Script missing strict error handling${NC}"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "trap.*error_handler" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script has error trap handler${NC}"
else
    echo -e "${RED}✗ Script missing error trap handler${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 6: Idempotency checks
echo -e "${YELLOW}Test 6: Idempotency checks${NC}"
if grep -q "kind get clusters.*grep.*EDGE_CLUSTER_NAME" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script checks for existing cluster${NC}"
else
    echo -e "${YELLOW}⚠ Script may not check for existing cluster${NC}"
fi

if grep -q "kubectl get namespace config-management-system" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script checks for existing Config Sync${NC}"
else
    echo -e "${YELLOW}⚠ Script may not check for existing Config Sync${NC}"
fi
echo ""

# Test 7: Logging and artifacts
echo -e "${YELLOW}Test 7: Logging and artifacts${NC}"
if grep -q "LOG_FILE=" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script creates log file${NC}"
else
    echo -e "${RED}✗ Script doesn't create log file${NC}"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "ARTIFACTS_DIR=" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script creates artifacts directory${NC}"
else
    echo -e "${YELLOW}⚠ Script may not create artifacts directory${NC}"
fi
echo ""

# Test 8: Health checks
echo -e "${YELLOW}Test 8: Health check functions${NC}"
if grep -q "run_health_checks()" "$SCRIPT_PATH"; then
    echo -e "${GREEN}✓ Script includes health checks${NC}"
else
    echo -e "${RED}✗ Script missing health checks${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 9: Documentation references
echo -e "${YELLOW}Test 9: Documentation${NC}"
if [[ -f "docs/VM2-Manual.md" ]]; then
    echo -e "${GREEN}✓ Documentation exists${NC}"
    
    # Check if doc references the script
    if grep -q "p0.4B_vm2_manual.sh" "docs/VM2-Manual.md"; then
        echo -e "${GREEN}✓ Documentation references the script${NC}"
    else
        echo -e "${YELLOW}⚠ Documentation doesn't reference the script${NC}"
    fi
else
    echo -e "${RED}✗ Documentation not found${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 10: Dry run capability
echo -e "${YELLOW}Test 10: Testing key functions (source check)${NC}"
# Source the script with a mock main function to test functions
cat > /tmp/test_functions.sh << 'EOF'
#!/bin/bash
# Override main to prevent execution
main() { 
    echo "Main function overridden for testing"
}

# Source the script
source ./scripts/p0.4B_vm2_manual.sh 2>/dev/null || true

# Test if functions are defined
if type command_exists &>/dev/null; then
    echo "✓ command_exists function is defined"
else
    echo "✗ command_exists function not found"
fi

if type print_banner &>/dev/null; then
    echo "✓ print_banner function is defined"
else
    echo "✗ print_banner function not found"
fi
EOF

if bash /tmp/test_functions.sh 2>/dev/null | grep -q "✓"; then
    echo -e "${GREEN}✓ Core functions are properly defined${NC}"
else
    echo -e "${YELLOW}⚠ Some functions may not be properly defined${NC}"
fi
rm -f /tmp/test_functions.sh
echo ""

# Summary
echo -e "${BLUE}===============================================${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}  All tests passed! Script is ready to use.  ${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    echo -e "${GREEN}To run the deployment on VM-2:${NC}"
    echo "  1. Copy this repository to VM-2"
    echo "  2. Run: ./scripts/p0.4B_vm2_manual.sh"
    echo ""
    echo -e "${GREEN}With Gitea token:${NC}"
    echo "  export GITEA_TOKEN='your-token'"
    echo "  ./scripts/p0.4B_vm2_manual.sh"
else
    echo -e "${RED}  $ERRORS test(s) failed. Please review.     ${NC}"
    echo -e "${BLUE}===============================================${NC}"
    exit 1
fi

# Quick connectivity test
echo -e "${YELLOW}Bonus: Testing Gitea connectivity from VM-1${NC}"
if curl -s -o /dev/null -w "%{http_code}" "http://147.251.115.143:8888" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Gitea is accessible from current host${NC}"
else
    echo -e "${YELLOW}⚠ Cannot reach Gitea (may be normal if testing locally)${NC}"
fi
echo ""