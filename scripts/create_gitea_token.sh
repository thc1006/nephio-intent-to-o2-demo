#!/bin/bash
set -euo pipefail

# Source environment
source scripts/env.sh 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Gitea Token Creation Helper${NC}"
echo -e "${BLUE}=========================================${NC}"

# Default credentials for fresh Gitea install
DEFAULT_USER="gitea_admin"
DEFAULT_PASS="r8sA8CPHD9!bt6d"
GITEA_URL="${GITEA_URL:-http://172.18.0.2:30924}"

echo -e "\n${YELLOW}Using Gitea URL:${NC} $GITEA_URL"

# Check if user wants to use default credentials
echo -e "\n${BLUE}Enter Gitea credentials:${NC}"
echo "(Press Enter to use defaults for fresh install)"
read -p "Username [$DEFAULT_USER]: " GITEA_USER
GITEA_USER="${GITEA_USER:-$DEFAULT_USER}"

read -s -p "Password [$DEFAULT_PASS]: " GITEA_PASS
GITEA_PASS="${GITEA_PASS:-$DEFAULT_PASS}"
echo ""

echo -e "\n${BLUE}Creating token...${NC}"

# Get CSRF token first (Gitea requires this for web UI operations)
echo "1. Getting session..."
COOKIE_JAR="/tmp/gitea_cookies_$$"
LOGIN_PAGE=$(curl -s -c "$COOKIE_JAR" "${GITEA_URL}/user/login" 2>/dev/null)
CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep 'name="_csrf"' | sed 's/.*value="\([^"]*\)".*/\1/' | head -1)

if [ -z "$CSRF_TOKEN" ]; then
    echo -e "${RED}Failed to get CSRF token. Gitea might not be accessible.${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi

# Login
echo "2. Logging in as $GITEA_USER..."
LOGIN_RESPONSE=$(curl -s -L -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST \
    -d "user_name=${GITEA_USER}" \
    -d "password=${GITEA_PASS}" \
    -d "_csrf=${CSRF_TOKEN}" \
    "${GITEA_URL}/user/login" 2>/dev/null)

# Check if login successful by trying to access settings
SETTINGS_CHECK=$(curl -s -b "$COOKIE_JAR" -o /dev/null -w "%{http_code}" \
    "${GITEA_URL}/user/settings" 2>/dev/null)

if [ "$SETTINGS_CHECK" != "200" ]; then
    echo -e "${RED}Login failed. Please check credentials.${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo -e "${GREEN}✓ Login successful${NC}"

# Try API method first (simpler if it works)
echo "3. Creating API token..."
TOKEN_NAME="edge-gitops-$(date +%s)"

# Try to create token via API with basic auth
API_TOKEN=$(curl -s -X POST \
    -u "${GITEA_USER}:${GITEA_PASS}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${TOKEN_NAME}\",\"scopes\":[\"repo\"]}" \
    "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" 2>/dev/null | jq -r '.sha1 // empty')

if [ -n "$API_TOKEN" ]; then
    echo -e "${GREEN}✓ Token created successfully via API${NC}"
else
    echo -e "${YELLOW}API method failed, trying web UI method...${NC}"
    
    # Get CSRF for settings page
    SETTINGS_PAGE=$(curl -s -b "$COOKIE_JAR" "${GITEA_URL}/user/settings/applications" 2>/dev/null)
    CSRF_TOKEN=$(echo "$SETTINGS_PAGE" | grep 'name="_csrf"' | sed 's/.*value="\([^"]*\)".*/\1/' | head -1)
    
    # Create token via web UI
    TOKEN_RESPONSE=$(curl -s -b "$COOKIE_JAR" \
        -X POST \
        -d "_csrf=${CSRF_TOKEN}" \
        -d "name=${TOKEN_NAME}" \
        -d "scope=repo" \
        "${GITEA_URL}/user/settings/applications" 2>/dev/null)
    
    # Extract token from response
    API_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -oP 'class="ui green.*?text">.*?\K[a-f0-9]{40}' | head -1)
    
    if [ -z "$API_TOKEN" ]; then
        echo -e "${RED}Failed to create token via web UI.${NC}"
        echo "Please create manually at: ${GITEA_URL}/user/settings/applications"
        rm -f "$COOKIE_JAR"
        exit 1
    fi
    echo -e "${GREEN}✓ Token created successfully via web UI${NC}"
fi

# Clean up
rm -f "$COOKIE_JAR"

# Display token and instructions
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✓ Token Created Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Your token:${NC}"
echo "$API_TOKEN"
echo ""
echo -e "${BLUE}To use this token:${NC}"
echo "export GITEA_TOKEN=\"$API_TOKEN\""
echo ""
echo -e "${BLUE}Or add to scripts/env.sh:${NC}"
echo "echo 'export GITEA_TOKEN=\"$API_TOKEN\"' >> scripts/env.sh"
echo ""
echo -e "${BLUE}Then run:${NC}"
echo "source scripts/env.sh"
echo "bash scripts/edge_repo_bootstrap.sh"

# Optionally save to env.sh
echo ""
read -p "Do you want to save this token to scripts/env.sh? (y/N): " SAVE_TOKEN
if [[ "$SAVE_TOKEN" =~ ^[Yy]$ ]]; then
    echo "export GITEA_TOKEN=\"$API_TOKEN\"" >> scripts/env.sh
    echo -e "${GREEN}✓ Token saved to scripts/env.sh${NC}"
    echo "Run: source scripts/env.sh"
fi