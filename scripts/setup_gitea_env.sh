#!/bin/bash
# Gitea environment setup helper script

cat << 'EOF'
================================================================================
Gitea GitOps Setup Helper
================================================================================

This script helps you configure the environment for edge_repo_bootstrap.sh

Follow these steps:

1. First, create a Personal Access Token in Gitea:
   - Login to your Gitea instance
   - Go to Settings → Applications → Generate New Token
   - Give it a name like "edge-gitops-token"
   - Select scopes: repo (full control)
   - Copy the generated token

2. Set your Gitea URL (replace with your actual Gitea URL):
   export GITEA_URL="http://localhost:3000"  # or https://git.example.com

3. Set your Gitea token (paste the token you copied):
   export GITEA_TOKEN="<YOUR_TOKEN_HERE>"

4. Optional: Customize repository settings:
   export EDGE_REPO_NAME="edge1-config"      # default: edge1-config
   export EDGE_REPO_DIR="/tmp/edge-gitops"   # default: /tmp/edge-gitops
   export EDGE_CLUSTER_NAME="edge-cluster-01" # default: edge-cluster-01

5. Run the bootstrap script:
   bash scripts/edge_repo_bootstrap.sh

================================================================================
Example for local Gitea (common setup):
================================================================================
EOF

echo '
# Copy and paste these commands (replace token with your actual token):

export GITEA_URL="http://localhost:3000"
export GITEA_TOKEN="YOUR_ACTUAL_TOKEN_HERE"
export EDGE_REPO_NAME="edge1-config"
export EDGE_REPO_DIR="/tmp/edge-gitops"

# Verify settings:
echo "GITEA_URL: $GITEA_URL"
echo "GITEA_TOKEN: ${GITEA_TOKEN:0:10}..." 
echo "EDGE_REPO_NAME: $EDGE_REPO_NAME"
echo "EDGE_REPO_DIR: $EDGE_REPO_DIR"

# Run bootstrap:
bash scripts/edge_repo_bootstrap.sh
'

echo ""
echo "================================================================================"
echo "Quick test with dry-run (no changes will be made):"
echo "================================================================================"
echo ""
echo "export GITEA_URL=\"http://localhost:3000\""
echo "export GITEA_TOKEN=\"test-token\""
echo "bash scripts/edge_repo_bootstrap.sh --dry-run"