#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

export KUBECONFIG=/tmp/kubeconfig-edge.yaml

echo -e "${GREEN}=== GitOps Sync Verification ===${NC}"
echo -e "${YELLOW}Repository: http://147.251.115.143:8888/admin/edge1-config${NC}"
echo -e "${YELLOW}Sync Path: /apps/intent${NC}\n"

# Check if Config Management System is ready
echo -e "${BLUE}[1/5] Checking Config Management System...${NC}"
if kubectl get ns config-management-system &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Namespace exists"
    
    # Check pods
    echo -e "  Pods in config-management-system:"
    kubectl get pods -n config-management-system --no-headers | while read line; do
        echo "    $line"
    done
else
    echo -e "  ${RED}✗${NC} Namespace not found"
    exit 1
fi

# Check RootSync status (if CRD exists)
echo -e "\n${BLUE}[2/5] Checking RootSync status...${NC}"
if kubectl get crd rootsyncs.configsync.gke.io &>/dev/null; then
    if kubectl get rootsync -n config-management-system root-sync &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} RootSync configured"
        kubectl get rootsync -n config-management-system root-sync -o custom-columns=NAME:.metadata.name,STATUS:.status.sync.status,LAST_SYNC:.status.sync.lastSyncTime --no-headers
    else
        echo -e "  ${YELLOW}⚠${NC} RootSync not found"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} RootSync CRD not installed (using git-sync deployment)"
fi

# Check Git repositories (if CRD exists)
echo -e "\n${BLUE}[3/5] Checking Git repositories...${NC}"
if kubectl get crd gitrepos.configsync.gke.io &>/dev/null; then
    kubectl get gitrepos -n config-management-system --no-headers 2>/dev/null || echo "  No git repositories found"
else
    echo -e "  ${YELLOW}⚠${NC} GitRepo CRD not installed"
fi

# Check reconciler logs
echo -e "\n${BLUE}[4/5] Recent sync activity (last 10 lines)...${NC}"
if kubectl get deploy root-reconciler -n config-management-system &>/dev/null; then
    echo -e "  ${YELLOW}Git-sync logs:${NC}"
    kubectl logs -n config-management-system deploy/root-reconciler -c git-sync --tail=10 2>/dev/null | sed 's/^/    /'
    
    echo -e "\n  ${YELLOW}Reconciler logs:${NC}"
    kubectl logs -n config-management-system deploy/root-reconciler -c reconciler --tail=10 2>/dev/null | sed 's/^/    /'
else
    echo -e "  ${YELLOW}⚠${NC} root-reconciler deployment not found"
fi

# Check for synced resources
echo -e "\n${BLUE}[5/5] Checking for synced resources...${NC}"

# Check for edge namespace (common indicator)
if kubectl get ns edge &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Found 'edge' namespace (sync indicator)"
fi

# Check for ConfigMaps with intent
echo -e "\n  ${YELLOW}ConfigMaps with 'intent' in name:${NC}"
kubectl get configmap --all-namespaces | grep -i intent || echo "    None found yet"

# Check for custom resources
echo -e "\n  ${YELLOW}Custom Resources (Bundle types):${NC}"
for crd in cnbundles ranbundles tnbundles; do
    if kubectl get crd ${crd}.bundle.oran.org &>/dev/null; then
        count=$(kubectl get ${crd} --all-namespaces --no-headers 2>/dev/null | wc -l)
        echo -e "    ${crd}: ${count} found"
    fi
done

# Summary
echo -e "\n${GREEN}=== Troubleshooting Commands ===${NC}"
echo -e "${BLUE}View detailed logs:${NC}"
echo -e "  kubectl logs -n config-management-system deploy/root-reconciler -c git-sync -f"
echo -e "  kubectl logs -n config-management-system deploy/root-reconciler -c reconciler -f"

echo -e "\n${BLUE}Check secret:${NC}"
echo -e "  kubectl get secret gitea-token -n config-management-system -o yaml"

echo -e "\n${BLUE}Test Gitea connectivity:${NC}"
echo -e "  curl -v http://147.251.115.143:8888"
echo -e "  curl -u admin:<token> http://147.251.115.143:8888/api/v1/repos/admin/edge1-config"

echo -e "\n${BLUE}Restart sync:${NC}"
echo -e "  kubectl rollout restart deploy/root-reconciler -n config-management-system"

echo -e "\n${GREEN}=== Status Summary ===${NC}"

# Final status
SYNC_STATUS="UNKNOWN"
if kubectl get deploy root-reconciler -n config-management-system &>/dev/null; then
    READY=$(kubectl get deploy root-reconciler -n config-management-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$READY" -gt 0 ]; then
        SYNC_STATUS="RUNNING"
    else
        SYNC_STATUS="NOT_READY"
    fi
fi

case $SYNC_STATUS in
    RUNNING)
        echo -e "${GREEN}✓ GitOps sync is running${NC}"
        echo -e "  Repository: http://147.251.115.143:8888/admin/edge1-config"
        echo -e "  Sync directory: /apps/intent"
        echo -e "  Next: Push content to Gitea repository"
        ;;
    NOT_READY)
        echo -e "${YELLOW}⚠ GitOps sync is configured but not ready${NC}"
        echo -e "  Check logs for errors"
        echo -e "  Verify Gitea token is correct"
        ;;
    *)
        echo -e "${RED}✗ GitOps sync not configured${NC}"
        echo -e "  Run: ~/dev/vm2_rootsync.sh with your token"
        ;;
esac