#!/bin/bash
# Helper script to create edge1-config repository in Gitea
# This should be run on VM-1 before VM-2 deployment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
GITEA_URL="${GITEA_URL:-http://localhost:3000}"
GITEA_USER="${GITEA_USER:-admin}"
GITEA_TOKEN="${GITEA_TOKEN:-1b5ea0b27add59e71980ba3f7612a3bfed1487b7}"
REPO_NAME="edge1-config"
REPO_DESC="Edge cluster GitOps configuration for VM-2"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Creating edge1-config Repository     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if repository already exists
echo -e "${YELLOW}Checking if repository exists...${NC}"
if curl -s "$GITEA_URL/api/v1/repos/$GITEA_USER/$REPO_NAME" \
    -H "Authorization: token $GITEA_TOKEN" | jq -e '.id' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Repository '$REPO_NAME' already exists${NC}"
    echo "Repository URL: $GITEA_URL/$GITEA_USER/$REPO_NAME"
    exit 0
fi

# Create repository
echo -e "${YELLOW}Creating repository...${NC}"
RESPONSE=$(curl -s -X POST "$GITEA_URL/api/v1/user/repos" \
    -H "Authorization: token $GITEA_TOKEN" \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
    "name": "$REPO_NAME",
    "description": "$REPO_DESC",
    "private": false,
    "auto_init": true,
    "gitignores": "",
    "license": "",
    "readme": "Default"
}
EOF
)

# Check if creation was successful
if echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Repository created successfully${NC}"
    
    # Initialize with GitOps structure
    echo -e "${YELLOW}Initializing repository structure...${NC}"
    
    # Clone the repository
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone "http://$GITEA_USER:$GITEA_TOKEN@${GITEA_URL#http://}/$GITEA_USER/$REPO_NAME.git"
    cd "$REPO_NAME"
    
    # Create GitOps directory structure
    mkdir -p apps/intent
    mkdir -p namespaces
    mkdir -p system
    mkdir -p clusters/edge1
    
    # Create README
    cat > README.md <<'README'
# Edge1 GitOps Configuration Repository

This repository contains the GitOps configuration for the Edge1 cluster deployed on VM-2.

## Repository Structure

```
.
├── apps/
│   └── intent/        # Intent-based KRM configurations
├── namespaces/        # Namespace configurations
├── system/           # System-level configurations
└── clusters/
    └── edge1/        # Edge1 cluster-specific configs
```

## Deployment Flow

1. VM-1 pushes KRM configurations to this repository
2. Config Sync on VM-2 pulls configurations every 30 seconds
3. Resources are automatically deployed to the edge cluster

## Managed By

- Nephio R5 Intent Pipeline
- O-RAN O2 IMS Integration
- Google Config Sync

## Sync Status

To check sync status on VM-2:
```bash
kubectl get rootsync -n config-management-system edge1-rootsync
```
README
    
    # Create sample namespace configuration
    cat > namespaces/edge1-namespace.yaml <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: edge1
  labels:
    app.kubernetes.io/managed-by: gitops
    deployment.nephio.org/site: edge1
    environment: edge
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: edge1-quota
  namespace: edge1
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
YAML
    
    # Create system configuration
    cat > system/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources: []

commonLabels:
  app.kubernetes.io/managed-by: config-sync
  app.kubernetes.io/part-of: edge1-gitops
YAML
    
    # Create clusters configuration
    cat > clusters/edge1/cluster-info.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-info
  namespace: default
data:
  cluster.name: "edge1"
  cluster.type: "edge"
  cluster.location: "vm2"
  cluster.ip: "172.16.4.45"
  gitops.sync: "enabled"
  gitops.interval: "30s"
YAML
    
    # Commit and push
    git add .
    git config user.email "admin@gitea.local"
    git config user.name "Admin"
    git commit -m "Initial GitOps structure for Edge1 cluster"
    git push origin main
    
    echo -e "${GREEN}✅ Repository initialized with GitOps structure${NC}"
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Repository Ready for GitOps!          ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Repository URL: $GITEA_URL/$GITEA_USER/$REPO_NAME"
    echo "Clone URL: http://$GITEA_USER@${GITEA_URL#http://}/$GITEA_USER/$REPO_NAME.git"
    echo ""
    echo "Next steps:"
    echo "1. Run p0.4B_vm2_manual.sh on VM-2"
    echo "2. Push KRM configurations from VM-1"
    echo "3. Monitor sync status on VM-2"
    
else
    echo -e "${RED}❌ Failed to create repository${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi