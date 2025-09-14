#!/bin/bash
# Test GitHub Actions workflows using gh CLI and act

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== GitHub Actions Workflow Testing ==="
echo ""

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install with: sudo apt install gh"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

# List all workflows
echo "📋 Available workflows:"
gh workflow list 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Cannot list workflows (not authenticated or not a GitHub repo)${NC}"
    echo "Listing local workflow files instead:"
    ls -la .github/workflows/*.yml
}
echo ""

# Validate workflow syntax using GitHub API (if authenticated)
echo "🔍 Validating workflow syntax..."
if gh auth status &>/dev/null; then
    for workflow in .github/workflows/*.yml; do
        workflow_name=$(basename "$workflow")
        echo -n "  Checking $workflow_name... "

        # Try to get workflow info (will fail if syntax is invalid)
        if gh workflow view "$workflow_name" &>/dev/null; then
            echo -e "${GREEN}✅ Valid${NC}"
        else
            echo -e "${YELLOW}⚠️  May have issues (check with 'gh workflow view $workflow_name')${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  Not authenticated with GitHub. Run 'gh auth login' to enable validation${NC}"
fi
echo ""

# Test with act (local runner)
if command -v act &> /dev/null; then
    echo "🏃 Testing workflows locally with act..."
    echo ""

    # Test CI workflow (dry run)
    echo "Testing CI workflow (dry run):"
    act -n push --workflows .github/workflows/ci.yml -j lint 2>&1 | head -20 || true
    echo ""

    # Test golden tests workflow (dry run)
    echo "Testing golden-tests workflow (dry run):"
    act -n push --workflows .github/workflows/golden-tests.yml 2>&1 | head -20 || true
    echo ""
else
    echo -e "${YELLOW}⚠️  act is not installed. Install with:${NC}"
    echo "curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
fi

# Check for common workflow issues
echo "🔍 Checking for common issues..."
ISSUES=0

# Check for deprecated action versions
echo -n "  Checking for deprecated actions... "
if grep -r "actions/.*@v[0-3]" .github/workflows/ &>/dev/null; then
    echo -e "${RED}❌ Found deprecated action versions${NC}"
    grep -r "actions/.*@v[0-3]" .github/workflows/ | head -5
    ((ISSUES++))
else
    echo -e "${GREEN}✅ All actions up to date${NC}"
fi

# Check for hardcoded secrets
echo -n "  Checking for hardcoded secrets... "
if grep -r "password\|token\|secret" .github/workflows/ | grep -v "secrets\." | grep -v "SECRET" &>/dev/null; then
    echo -e "${RED}❌ Possible hardcoded secrets found${NC}"
    ((ISSUES++))
else
    echo -e "${GREEN}✅ No hardcoded secrets detected${NC}"
fi

# Check for missing checkout steps
echo -n "  Checking for missing checkout steps... "
for workflow in .github/workflows/*.yml; do
    if grep -q "setup-python\|setup-node\|setup-go" "$workflow"; then
        if ! grep -q "actions/checkout" "$workflow"; then
            echo -e "${RED}❌ $(basename $workflow) may be missing checkout step${NC}"
            ((ISSUES++))
        fi
    fi
done
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All workflows have proper checkout steps${NC}"
fi

echo ""
echo "=== Summary ==="
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All workflow checks passed!${NC}"
else
    echo -e "${YELLOW}⚠️  Found $ISSUES potential issues${NC}"
fi

echo ""
echo "📝 Next steps:"
echo "1. Fix any issues identified above"
echo "2. Test workflows locally: act push --workflows .github/workflows/ci.yml"
echo "3. Push changes to a branch and create a PR to see live CI results"
echo "4. Monitor workflow runs: gh run list"