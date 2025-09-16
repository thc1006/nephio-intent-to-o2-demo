#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Generate Gitea Credentials for Config Sync${NC}"
echo -e "${BLUE}=========================================${NC}"

# Configuration
GITEA_URL="${GITEA_URL:-http://172.16.0.78:30924}"
GITEA_USER="${GITEA_USER:-gitea_admin}"
GITEA_PASS="${GITEA_PASS:-r8sA8CPHD9!bt6d}"
OUTPUT_DIR="./gitops/credentials"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "\n${YELLOW}Step 1: Generate Gitea API Token${NC}"
echo "----------------------------------------"

# Check if token already exists in environment
if [ -n "${GITEA_TOKEN:-}" ]; then
    echo -e "${GREEN}Using existing token from environment${NC}"
    TOKEN="$GITEA_TOKEN"
else
    echo "Creating new API token..."

    # Generate token name with timestamp
    TOKEN_NAME="edge-gitops-$(date +%Y%m%d-%H%M%S)"

    # Create token via API
    RESPONSE=$(curl -s -X POST \
        -u "${GITEA_USER}:${GITEA_PASS}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${TOKEN_NAME}\", \"scopes\": [\"repo\", \"admin:org\", \"admin:public_key\", \"admin:repo_hook\"]}" \
        "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" 2>/dev/null)

    TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')

    if [ -z "$TOKEN" ]; then
        echo -e "${RED}Failed to create token${NC}"
        echo "Response: $RESPONSE"
        echo ""
        echo -e "${YELLOW}Trying alternative: Using password-based auth${NC}"
        USE_PASSWORD=true
    else
        echo -e "${GREEN}✓ Token created successfully${NC}"
        echo "Token name: $TOKEN_NAME"

        # Save token to env file
        echo "export GITEA_TOKEN=\"$TOKEN\"" >> scripts/env.sh
        echo -e "${GREEN}Token saved to scripts/env.sh${NC}"
    fi
fi

echo -e "\n${YELLOW}Step 2: Generate Kubernetes Secret YAML${NC}"
echo "----------------------------------------"

if [ "${USE_PASSWORD:-false}" == "true" ]; then
    # Generate password-based secret
    cat > "$OUTPUT_DIR/gitea-secret-password.yaml" <<EOF
# Gitea Credentials Secret (Password-based)
# Generated on $(date)
# Deploy with: kubectl apply -f gitea-secret-password.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: config-management-system
---
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: config-management-system
type: kubernetes.io/basic-auth
stringData:
  username: ${GITEA_USER}
  password: ${GITEA_PASS}
EOF
    echo -e "${GREEN}✓ Created $OUTPUT_DIR/gitea-secret-password.yaml${NC}"
else
    # Generate token-based secret
    TOKEN_B64=$(echo -n "$TOKEN" | base64 -w 0)
    USER_B64=$(echo -n "$GITEA_USER" | base64 -w 0)

    cat > "$OUTPUT_DIR/gitea-secret-token.yaml" <<EOF
# Gitea Credentials Secret (Token-based)
# Generated on $(date)
# Deploy with: kubectl apply -f gitea-secret-token.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: config-management-system
---
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: config-management-system
type: Opaque
data:
  username: ${USER_B64}
  token: ${TOKEN_B64}
EOF
    echo -e "${GREEN}✓ Created $OUTPUT_DIR/gitea-secret-token.yaml${NC}"
fi

echo -e "\n${YELLOW}Step 3: Generate SSH Key (Optional)${NC}"
echo "----------------------------------------"

read -p "Do you want to generate SSH keys for Git access? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SSH_KEY_FILE="$OUTPUT_DIR/gitea-deploy-key"

    # Generate SSH key
    ssh-keygen -t ed25519 -C "gitops@edge-cluster" -f "$SSH_KEY_FILE" -N "" >/dev/null 2>&1

    echo -e "${GREEN}✓ SSH key pair generated${NC}"

    # Get public key
    PUB_KEY=$(cat "${SSH_KEY_FILE}.pub")

    # Add public key to Gitea via API
    echo "Adding public key to Gitea..."

    KEY_TITLE="edge-gitops-$(date +%Y%m%d-%H%M%S)"

    if [ -n "${TOKEN:-}" ]; then
        # Use token auth
        RESPONSE=$(curl -s -X POST \
            -H "Authorization: token ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"${KEY_TITLE}\", \"key\":\"${PUB_KEY}\", \"read_only\": false}" \
            "${GITEA_URL}/api/v1/user/keys")
    else
        # Use basic auth
        RESPONSE=$(curl -s -X POST \
            -u "${GITEA_USER}:${GITEA_PASS}" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"${KEY_TITLE}\", \"key\":\"${PUB_KEY}\", \"read_only\": false}" \
            "${GITEA_URL}/api/v1/user/keys")
    fi

    KEY_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

    if [ -n "$KEY_ID" ]; then
        echo -e "${GREEN}✓ Public key added to Gitea (ID: $KEY_ID)${NC}"
    else
        echo -e "${YELLOW}⚠ Could not add key via API. Add manually:${NC}"
        echo "$PUB_KEY"
    fi

    # Get known_hosts entry
    echo "Getting SSH host key..."
    ssh-keyscan -p 30222 172.16.0.78 2>/dev/null > "$OUTPUT_DIR/known_hosts"

    # Generate SSH secret YAML
    SSH_KEY_B64=$(cat "$SSH_KEY_FILE" | base64 -w 0)
    KNOWN_HOSTS_B64=$(cat "$OUTPUT_DIR/known_hosts" | base64 -w 0)

    cat > "$OUTPUT_DIR/gitea-secret-ssh.yaml" <<EOF
# Gitea SSH Credentials Secret
# Generated on $(date)
# Deploy with: kubectl apply -f gitea-secret-ssh.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: gitea-ssh-key
  namespace: config-management-system
type: kubernetes.io/ssh-auth
data:
  ssh-privatekey: ${SSH_KEY_B64}
  known_hosts: ${KNOWN_HOSTS_B64}
EOF

    echo -e "${GREEN}✓ Created $OUTPUT_DIR/gitea-secret-ssh.yaml${NC}"

    # Update RootSync for SSH
    cat > "$OUTPUT_DIR/rootsync-ssh-example.yaml" <<EOF
# Example RootSync configuration using SSH
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge-root-sync-ssh
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: ssh://git@172.16.0.78:30222/admin1/edge-config.git
    branch: main
    dir: /
    period: 30s
    auth: ssh
    secretRef:
      name: gitea-ssh-key
EOF

    echo -e "${GREEN}✓ Created SSH RootSync example${NC}"
fi

echo -e "\n${YELLOW}Step 4: Test Credentials${NC}"
echo "----------------------------------------"

# Test with token/password
if [ -n "${TOKEN:-}" ]; then
    echo -n "Testing API access with token... "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${TOKEN}" \
        "${GITEA_URL}/api/v1/user" 2>/dev/null)
else
    echo -n "Testing API access with password... "
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "${GITEA_USER}:${GITEA_PASS}" \
        "${GITEA_URL}/api/v1/user" 2>/dev/null)
fi

if [ "$STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Authentication successful${NC}"
else
    echo -e "${RED}✗ Authentication failed (HTTP $STATUS)${NC}"
fi

# Test git clone
echo -n "Testing git repository access... "
if [ -n "${TOKEN:-}" ]; then
    TEST_URL="http://${GITEA_USER}:${TOKEN}@${GITEA_URL#http://}/admin1/edge1-config.git"
else
    TEST_URL="http://${GITEA_USER}:${GITEA_PASS}@${GITEA_URL#http://}/admin1/edge1-config.git"
fi

if timeout 10 git ls-remote "$TEST_URL" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Repository accessible${NC}"
else
    echo -e "${RED}✗ Repository not accessible${NC}"
fi

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}=========================================${NC}"

echo -e "\n${GREEN}Generated files in $OUTPUT_DIR/:${NC}"
ls -la "$OUTPUT_DIR"/*.yaml 2>/dev/null | awk '{print "  - " $NF}'

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Deploy credentials to edge clusters:"
echo "   kubectl apply -f $OUTPUT_DIR/gitea-secret-*.yaml"
echo ""
echo "2. Deploy RootSync configuration:"
echo "   kubectl apply -f gitops/edge1-config/rootsync-gitea.yaml"
echo "   kubectl apply -f gitops/edge2-config/rootsync-gitea.yaml"
echo ""
echo "3. Verify sync status:"
echo "   kubectl get rootsync -n config-management-system"
echo "   kubectl describe rootsync -n config-management-system"
echo ""

if [ -n "${TOKEN:-}" ]; then
    echo -e "${YELLOW}Important: Save this token (it won't be shown again):${NC}"
    echo "$TOKEN"
    echo ""
fi

echo -e "${GREEN}Credentials generation completed!${NC}"