#!/bin/bash
# Push KRM content to Gitea for VM-2 sync

set -euo pipefail

echo "Setting up Gitea repository for VM-2 GitOps..."

# Get the token
echo -n "Enter Gitea token: "
read -s GITEA_TOKEN
echo ""

# Clone and populate repository
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

git clone http://admin:${GITEA_TOKEN}@localhost:3000/admin/edge1-config.git
cd edge1-config

# Create directory structure
mkdir -p apps/intent

# Copy KRM artifacts
cp -r /home/ubuntu/nephio-intent-to-o2-demo/packages/intent-to-krm/dist/edge1/* apps/intent/

# Add and commit
git add .
git commit -m "Add KRM artifacts for edge deployment"
git push origin main

echo "✅ Content pushed to Gitea"
echo "VM-2 should now sync these resources"

# Cleanup
cd /
rm -rf "$TEMP_DIR"