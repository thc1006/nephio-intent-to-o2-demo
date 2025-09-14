#!/bin/bash
# Push KRM content to external Gitea for VM-2 GitOps sync

set -euo pipefail

# Configuration
GITEA_URL="http://172.16.0.78:8888"
GITEA_USER="${GITEA_USER:-admin1}"
REPO_NAME="edge1-config"

echo "========================================="
echo "  Push KRM to Gitea for VM-2 GitOps"
echo "========================================="
echo ""
echo "Gitea URL: $GITEA_URL"
echo "Repository: $GITEA_USER/$REPO_NAME"
echo ""

# Get token
echo -n "Enter your Gitea access token: "
read -s GITEA_TOKEN
echo ""

if [ -z "$GITEA_TOKEN" ]; then
    echo "Error: No token provided"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

# Clone repository
echo "Cloning repository..."
if ! git clone "${GITEA_URL}/${GITEA_USER}/${REPO_NAME}.git" 2>/dev/null; then
    echo "Trying with authentication..."
    git clone "http://${GITEA_USER}:${GITEA_TOKEN}@${GITEA_URL#http://}/${GITEA_USER}/${REPO_NAME}.git"
fi

cd "$REPO_NAME"

# Create directory structure
echo "Setting up GitOps structure..."
mkdir -p apps/intent
mkdir -p namespaces
mkdir -p system

# Copy KRM artifacts from intent-to-krm
KRM_SOURCE="/home/ubuntu/nephio-intent-to-o2-demo/packages/intent-to-krm/dist/edge1"
if [ -d "$KRM_SOURCE" ]; then
    echo "Copying KRM artifacts..."
    cp -r "$KRM_SOURCE"/* apps/intent/
    echo "Files copied:"
    ls -la apps/intent/
else
    echo "Warning: KRM source directory not found at $KRM_SOURCE"
fi

# Create README if not exists
if [ ! -f README.md ]; then
cat > README.md <<EOF
# Edge1 GitOps Configuration

This repository contains GitOps configurations for Edge1 cluster managed by Nephio Intent Pipeline.

## Structure

- \`apps/intent/\` - Intent-based KRM configurations from 3GPP TS 28.312
- \`namespaces/\` - Namespace configurations
- \`system/\` - System-level configurations

## Synchronization

This repository is synchronized to the edge cluster via Config Sync RootSync.

## Generated Resources

- ConfigMaps containing intent expectations
- RANBundle for RAN domain configurations
- CNBundle for Core Network configurations
- TNBundle for Transport Network configurations

## Managed By

- Nephio R5 Intent Pipeline
- O-RAN O2 IMS Integration
EOF
fi

# Add namespace configuration
cat > namespaces/edge1-namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: edge1
  labels:
    app.kubernetes.io/managed-by: gitops
    deployment.nephio.org/site: edge1
  annotations:
    config.kubernetes.io/source: gitops
EOF

# Configure git
git config user.email "nephio@example.com"
git config user.name "Nephio Intent Pipeline"

# Add, commit and push
echo "Committing changes..."
git add .
git status

COMMIT_MSG="Update KRM artifacts from intent pipeline - $(date +%Y%m%d-%H%M%S)"
git commit -m "$COMMIT_MSG" || echo "No changes to commit"

echo "Pushing to Gitea..."
git push origin main

echo ""
echo "✅ Successfully pushed KRM content to Gitea!"
echo ""
echo "Repository URL: ${GITEA_URL}/${GITEA_USER}/${REPO_NAME}"
echo ""
echo "Next steps for VM-2:"
echo "1. Configure RootSync with the repository URL"
echo "2. Provide the token: echo '$GITEA_TOKEN' | ~/dev/vm2_rootsync.sh"
echo "3. Monitor sync: kubectl get rootsync -n config-management-system"
echo ""
echo "Token command for VM-2:"
echo "echo '$GITEA_TOKEN' | ~/dev/vm2_rootsync.sh"