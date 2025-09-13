#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ConfigSync Setup for Gitea Repository ===${NC}"
echo -e "${YELLOW}Repository: http://147.251.115.143:8888/admin/edge1-config${NC}"

# Check if token is provided as argument
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Gitea token not provided${NC}"
    echo -e "${YELLOW}Usage: $0 <GITEA_TOKEN>${NC}"
    echo -e "\n${BLUE}To generate a token:${NC}"
    echo -e "1. Go to http://147.251.115.143:8888"
    echo -e "2. Login as admin"
    echo -e "3. Go to Settings -> Applications"
    echo -e "4. Generate New Token with 'repo' scope"
    echo -e "5. Run: ${GREEN}$0 YOUR_TOKEN${NC}"
    exit 1
fi

GITEA_TOKEN="$1"
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

echo -e "\n${GREEN}[1/5] Creating Gitea authentication secret...${NC}"
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=username=admin \
  --from-literal=token="${GITEA_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${GREEN}[2/5] Deploying ConfigSync components...${NC}"
kubectl apply -f ~/configsync-gitea.yaml

echo -e "\n${GREEN}[3/5] Waiting for ConfigSync deployment...${NC}"
kubectl rollout status deployment/config-sync-controller -n config-management-system --timeout=60s || true

echo -e "\n${GREEN}[4/5] Checking ConfigSync pod status...${NC}"
kubectl get pods -n config-management-system

echo -e "\n${GREEN}[5/5] Testing Gitea connectivity...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://147.251.115.143:8888 | grep -q "200"; then
    echo -e "${GREEN}✓ Gitea is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Could not reach Gitea at http://147.251.115.143:8888${NC}"
fi

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "${YELLOW}ConfigSync is now monitoring: http://147.251.115.143:8888/admin/edge1-config${NC}"
echo -e "\n${GREEN}Next Steps:${NC}"
echo -e "1. Create/push YAML files to the Gitea repository"
echo -e "2. ConfigSync will automatically apply them to this cluster"
echo -e "3. Check sync status: ${YELLOW}kubectl logs -n config-management-system -l app=config-sync-controller${NC}"
echo -e "\n${GREEN}Useful Commands:${NC}"
echo -e "- View logs: ${YELLOW}kubectl logs -n config-management-system deploy/config-sync-controller -c git-sync${NC}"
echo -e "- Check applied resources: ${YELLOW}kubectl get all --all-namespaces${NC}"
echo -e "- Update token: ${YELLOW}kubectl edit secret gitea-token -n config-management-system${NC}"