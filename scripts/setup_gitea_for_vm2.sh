#!/bin/bash
# Setup Gitea repository and token for VM-2 GitOps integration

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Gitea Setup for VM-2 Edge GitOps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
GITEA_URL="http://localhost:3000"
GITEA_EXTERNAL="http://172.16.0.78:3000"
GITEA_USER="${GITEA_USER:-admin}"
GITEA_PASS="${GITEA_PASS:-admin123}"  # You'll need to set this
REPO_NAME="edge1-config"
TOKEN_NAME="vm2-gitops-$(date +%s)"

echo -e "${YELLOW}Step 1: Check Gitea Access${NC}"
echo "----------------------------------------"
if curl -s -o /dev/null -w "%{http_code}" "$GITEA_URL" | grep -q "200\|302"; then
    echo -e "${GREEN}✅ Gitea is accessible at $GITEA_URL${NC}"
else
    echo -e "${RED}❌ Cannot access Gitea. Starting port-forward...${NC}"
    kubectl port-forward -n gitea-system svc/gitea-service 3000:3000 &
    PF_PID=$!
    sleep 3
fi

echo ""
echo -e "${YELLOW}Step 2: Create Repository (Manual Steps Required)${NC}"
echo "----------------------------------------"
echo "Please open your browser and go to: $GITEA_URL"
echo ""
echo "1. Login with admin credentials"
echo "2. Create new repository:"
echo "   - Name: ${REPO_NAME}"
echo "   - Description: Edge cluster GitOps configuration"
echo "   - Private: Yes"
echo "   - Initialize with README: Yes"
echo ""
read -p "Press Enter when repository is created..."

echo ""
echo -e "${YELLOW}Step 3: Generate Access Token (Manual)${NC}"
echo "----------------------------------------"
echo "In Gitea web UI:"
echo "1. Go to Settings → Applications"
echo "2. Generate New Token:"
echo "   - Token Name: ${TOKEN_NAME}"
echo "   - Scopes: Select 'repo' (full control)"
echo "3. Copy the generated token"
echo ""
echo -n "Paste the token here (hidden): "
read -s GITEA_TOKEN
echo ""

if [ -z "$GITEA_TOKEN" ]; then
    echo -e "${RED}❌ No token provided${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 4: Create Kubernetes Secret${NC}"
echo "----------------------------------------"
kubectl create namespace config-management-system --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=username=$GITEA_USER \
  --from-literal=token=$GITEA_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Secret created/updated${NC}"

echo ""
echo -e "${YELLOW}Step 5: Initialize Repository with KRM Content${NC}"
echo "----------------------------------------"

# Create temporary directory for git operations
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone the repository
echo "Cloning repository..."
git clone http://${GITEA_USER}:${GITEA_TOKEN}@localhost:3000/${GITEA_USER}/${REPO_NAME}.git
cd "$REPO_NAME"

# Create initial structure
echo "Creating GitOps structure..."
mkdir -p apps/intent
mkdir -p namespaces
mkdir -p system

# Copy KRM artifacts if they exist
if [ -d "/home/ubuntu/nephio-intent-to-o2-demo/packages/intent-to-krm/dist/edge1" ]; then
    echo "Copying KRM artifacts..."
    cp -r /home/ubuntu/nephio-intent-to-o2-demo/packages/intent-to-krm/dist/edge1/* apps/intent/
fi

# Create README
cat > README.md <<EOF
# Edge1 GitOps Configuration

This repository contains the GitOps configuration for the Edge1 cluster.

## Structure

- \`apps/intent/\` - Intent-based KRM configurations
- \`namespaces/\` - Namespace configurations
- \`system/\` - System-level configurations

## Managed by

- Nephio R5 Intent Pipeline
- O-RAN O2 IMS Integration
EOF

# Create a sample namespace
cat > namespaces/edge1-namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: edge1
  labels:
    app.kubernetes.io/managed-by: gitops
    deployment.nephio.org/site: edge1
EOF

# Commit and push
git add .
git commit -m "Initial GitOps configuration for Edge1"
git push origin main

echo -e "${GREEN}✅ Repository initialized and pushed${NC}"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo -e "${YELLOW}Step 6: Generate VM-2 Configuration Command${NC}"
echo "----------------------------------------"
echo -e "${GREEN}Configuration for VM-2:${NC}"
echo ""
echo "Run this command on VM-2:"
echo -e "${BLUE}echo '${GITEA_TOKEN}' | ~/dev/vm2_rootsync.sh${NC}"
echo ""
echo "Or save the token to a file and use:"
echo -e "${BLUE}cat token.txt | ~/dev/vm2_rootsync.sh${NC}"
echo ""

echo -e "${YELLOW}Step 7: Verify Sync Status${NC}"
echo "----------------------------------------"
echo "After running on VM-2, check sync status with:"
echo "kubectl get rootsync -n config-management-system edge1-rootsync"
echo "kubectl get gitrepos -n config-management-system"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Repository URL: ${GITEA_EXTERNAL}/${GITEA_USER}/${REPO_NAME}"
echo "Token: Saved in Kubernetes secret"
echo ""
echo "Next steps:"
echo "1. Run the token command on VM-2"
echo "2. Monitor sync status"
echo "3. Push changes to trigger deployments"