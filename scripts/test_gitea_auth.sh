#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Gitea Authentication Test${NC}"
echo -e "${BLUE}=========================================${NC}"

# Check environment variables
if [ -z "${GITEA_URL:-}" ]; then
    echo -e "${RED}[ERROR]${NC} GITEA_URL is not set"
    echo "Run: export GITEA_URL=\"http://172.18.0.2:30924\""
    exit 1
fi

if [ -z "${GITEA_TOKEN:-}" ] || [ "${GITEA_TOKEN}" == "<PASTE_YOUR_TOKEN>" ]; then
    echo -e "${RED}[ERROR]${NC} GITEA_TOKEN is not set or still has placeholder value"
    echo ""
    echo -e "${YELLOW}To create a token:${NC}"
    echo "1. Open in browser: ${GITEA_URL}/user/settings/applications"
    echo "   Or try: ${GITEA_URL}"
    echo ""
    echo "2. Login with default credentials (if fresh install):"
    echo "   Username: gitea_admin"
    echo "   Password: r8sA8CPHD9!bt6d"
    echo ""
    echo "3. Go to User Settings → Applications"
    echo "4. Generate New Token:"
    echo "   - Token Name: edge-gitops"
    echo "   - Select scopes: ✓ repo (Full control)"
    echo "   - Click 'Generate Token'"
    echo ""
    echo "5. Copy the token and run:"
    echo "   export GITEA_TOKEN=\"<paste-your-actual-token-here>\""
    echo ""
    exit 1
fi

echo -e "${BLUE}Testing connection to:${NC} $GITEA_URL"

# Test basic connectivity
echo -n "1. Basic connectivity: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${GITEA_URL}" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ OK${NC} (HTTP $HTTP_CODE)"
else
    echo -e "${RED}✗ Failed${NC} (HTTP $HTTP_CODE)"
    echo "   Cannot reach Gitea at $GITEA_URL"
    exit 1
fi

# Test API access without auth
echo -n "2. API endpoint: "
API_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${GITEA_URL}/api/v1/version" 2>/dev/null || echo "000")
if [ "$API_CODE" == "200" ]; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ Warning${NC} (HTTP $API_CODE)"
fi

# Test authenticated API access
echo -n "3. Token authentication: "
USER_INFO=$(curl -s -X GET \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_URL}/api/v1/user" 2>/dev/null)

if echo "$USER_INFO" | jq -e '.id' >/dev/null 2>&1; then
    USERNAME=$(echo "$USER_INFO" | jq -r '.login')
    FULL_NAME=$(echo "$USER_INFO" | jq -r '.full_name // .login')
    echo -e "${GREEN}✓ OK${NC}"
    echo "   Authenticated as: $FULL_NAME (@$USERNAME)"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "   Response: $USER_INFO"
    echo ""
    echo -e "${YELLOW}Token might be invalid or expired.${NC}"
    echo "Please create a new token following the steps above."
    exit 1
fi

# Test repository creation permission
echo -n "4. Repository creation permission: "
TEST_REPO="test-repo-$(date +%s)"
CREATE_RESPONSE=$(curl -s -X POST \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${TEST_REPO}\",\"private\":true,\"auto_init\":false}" \
    "${GITEA_URL}/api/v1/user/repos" 2>/dev/null)

if echo "$CREATE_RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
    
    # Clean up test repo
    curl -s -X DELETE \
        -H "Authorization: token ${GITEA_TOKEN}" \
        "${GITEA_URL}/api/v1/repos/${USERNAME}/${TEST_REPO}" >/dev/null 2>&1
    echo "   Test repository created and deleted successfully"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "   Cannot create repositories. Check token permissions."
    echo "   Response: $CREATE_RESPONSE"
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✓ All tests passed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Your Gitea setup is ready. You can now run:"
echo "  bash scripts/edge_repo_bootstrap.sh"
echo ""
echo "Current configuration:"
echo "  GITEA_URL: $GITEA_URL"
echo "  GITEA_TOKEN: ${GITEA_TOKEN:0:10}..."
echo "  Authenticated as: @$USERNAME"