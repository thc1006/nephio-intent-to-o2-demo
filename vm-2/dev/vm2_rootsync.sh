#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="config-management-system"
SECRET_NAME="gitea-token"
# External Gitea URL accessible from edge cluster
GITEA_URL="http://147.251.115.143:8888"
GITEA_URL_ALT="http://172.16.0.78:3000"
REPO_PATH="admin1/edge1-config"
BRANCH="main"
SYNC_DIR="/apps/intent"
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

echo -e "${GREEN}=== RootSync Configuration for Gitea Edge Repository ===${NC}"
echo -e "${YELLOW}Primary URL: ${GITEA_URL}/${REPO_PATH}${NC}"
echo -e "${YELLOW}Alternative: ${GITEA_URL_ALT}/${REPO_PATH}${NC}"

# Function to check if namespace exists
check_namespace() {
    kubectl get namespace "$1" &>/dev/null
}

# Function to wait for sync
wait_for_sync() {
    local timeout=120
    local interval=5
    local elapsed=0
    
    echo -e "\n${YELLOW}Waiting for RootSync to synchronize (timeout: ${timeout}s)...${NC}"
    
    while [ $elapsed -lt $timeout ]; do
        # Check if edge namespace exists (example sync indicator)
        if kubectl get namespace edge &>/dev/null; then
            echo -e "${GREEN}✓ Sync successful! Found 'edge' namespace${NC}"
            return 0
        fi
        
        # Check RootSync status
        if kubectl get rootsync -n config-management-system root-sync &>/dev/null; then
            local status=$(kubectl get rootsync -n config-management-system root-sync -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            echo -e "  Sync status: ${BLUE}${status}${NC}"
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo -e "${YELLOW}⚠ Timeout waiting for sync. Check troubleshooting tips below.${NC}"
    return 1
}

# Step 1: Create namespace if missing
echo -e "\n${GREEN}[1/5] Checking namespace '${NAMESPACE}'...${NC}"
if check_namespace "$NAMESPACE"; then
    echo -e "  Namespace exists"
else
    echo -e "  Creating namespace..."
    kubectl create namespace "$NAMESPACE"
fi

# Step 2: Create/update Gitea token secret
echo -e "\n${GREEN}[2/5] Configuring Gitea authentication secret...${NC}"

# Check if token is provided as argument or environment variable
TOKEN="${1:-${GITEA_TOKEN:-PLACEHOLDER_TOKEN}}"

if [ "$TOKEN" = "PLACEHOLDER_TOKEN" ]; then
    echo -e "${YELLOW}⚠ Using placeholder token. Set real token with:${NC}"
    echo -e "${BLUE}  read -s GITEA_TOKEN && echo \$GITEA_TOKEN | $0${NC}"
    echo -e "${BLUE}  Or: $0 <your-token>${NC}"
fi

kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-literal=username=admin \
    --from-literal=token="$TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "  Secret '${SECRET_NAME}' configured"

# Step 3: Create RootSync manifest (if CRD exists)
echo -e "\n${GREEN}[3/5] Configuring RootSync...${NC}"

# Check if RootSync CRD exists
if kubectl get crd rootsyncs.configsync.gke.io &>/dev/null; then
    echo -e "  Creating RootSync resource..."
    cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${GITEA_URL}/${REPO_PATH}.git
    branch: ${BRANCH}
    dir: ${SYNC_DIR}
    auth: token
    secretRef:
      name: ${SECRET_NAME}
    period: 30s
    # noSSLVerify: true  # Uncomment if using self-signed certificates
EOF
    echo -e "  RootSync 'root-sync' applied"
else
    echo -e "  ${YELLOW}⚠ RootSync CRD not found. Using git-sync deployment instead.${NC}"
fi

# Step 4: Check Config Sync components
echo -e "\n${GREEN}[4/5] Verifying Config Sync components...${NC}"

# Check if Config Sync is installed
if kubectl get deployment -n config-management-system root-reconciler &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} root-reconciler deployment found"
else
    echo -e "  ${YELLOW}⚠${NC} root-reconciler not found. Installing Config Sync..."
    
    # Create minimal Config Sync components if not present
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: root-reconciler
  namespace: config-management-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: root-reconciler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: root-reconciler
  namespace: config-management-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: root-reconciler
  namespace: config-management-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: root-reconciler
  template:
    metadata:
      labels:
        app: root-reconciler
    spec:
      serviceAccountName: root-reconciler
      containers:
      - name: git-sync
        image: registry.k8s.io/git-sync/git-sync:v4.0.0
        env:
        - name: GITSYNC_REPO
          value: "${GITEA_URL}/${REPO_PATH}.git"
        - name: GITSYNC_BRANCH
          value: "${BRANCH}"
        - name: GITSYNC_ROOT
          value: "/repo"
        - name: GITSYNC_DEST
          value: "root"
        - name: GITSYNC_SUBDIR
          value: "apps/intent"
        - name: GITSYNC_PERIOD
          value: "30s"
        - name: GITSYNC_USERNAME
          valueFrom:
            secretKeyRef:
              name: ${SECRET_NAME}
              key: username
        - name: GITSYNC_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ${SECRET_NAME}
              key: token
        volumeMounts:
        - name: repo
          mountPath: /repo
      - name: reconciler
        image: bitnami/kubectl:latest
        command:
        - /bin/bash
        - -c
        - |
          while true; do
            if [ -d "/repo/root/apps/intent" ]; then
              echo "Applying configurations from RootSync /apps/intent directory..."
              find /repo/root/apps/intent -name "*.yaml" -o -name "*.yml" | while read file; do
                echo "Applying: \$file"
                kubectl apply -f "\$file" 2>&1 | grep -v "unchanged" || true
              done
            else
              echo "Waiting for /repo/root/apps/intent directory..."
            fi
            sleep 30
          done
        volumeMounts:
        - name: repo
          mountPath: /repo
      volumes:
      - name: repo
        emptyDir: {}
EOF
fi

# Step 5: Wait for sync
echo -e "\n${GREEN}[5/5] Waiting for repository synchronization...${NC}"
wait_for_sync

# Troubleshooting tips
echo -e "\n${GREEN}=== Troubleshooting Tips ===${NC}"
echo -e "${BLUE}1. Network Connectivity:${NC}"
echo -e "   # Test from edge cluster pod:"
echo -e "   kubectl run test-curl --image=curlimages/curl -it --rm -- curl -v ${GITEA_URL}"
echo -e "   # Alternative URL: ${GITEA_URL_ALT}"

echo -e "\n${BLUE}2. Check Credentials:${NC}"
echo -e "   # View secret:"
echo -e "   kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o yaml"
echo -e "   # Update token:"
echo -e "   kubectl edit secret ${SECRET_NAME} -n ${NAMESPACE}"

echo -e "\n${BLUE}3. Check RootSync Status:${NC}"
echo -e "   kubectl describe rootsync -n ${NAMESPACE} root-sync"
echo -e "   kubectl get rootsync -n ${NAMESPACE} root-sync -o yaml"

echo -e "\n${BLUE}4. View Logs:${NC}"
echo -e "   # Git sync logs:"
echo -e "   kubectl logs -n ${NAMESPACE} deploy/root-reconciler -c git-sync"
echo -e "   # Reconciler logs:"
echo -e "   kubectl logs -n ${NAMESPACE} deploy/root-reconciler -c reconciler"

echo -e "\n${BLUE}5. CA Certificate Issues (if HTTPS):${NC}"
echo -e "   # Add noSSLVerify: true to RootSync spec.git section"
echo -e "   kubectl edit rootsync -n ${NAMESPACE} root-sync"

echo -e "\n${BLUE}6. Repository Access:${NC}"
echo -e "   # Ensure repository exists and is accessible:"
echo -e "   curl -u admin:<token> ${GITEA_URL}/api/v1/repos/${REPO_PATH}"

echo -e "\n${GREEN}=== Quick Token Update ===${NC}"
echo -e "${YELLOW}Set token securely with one-liner:${NC}"
echo -e "${BLUE}read -s GITEA_TOKEN && echo \"\$GITEA_TOKEN\" | $0${NC}"

echo -e "\n${GREEN}=== Summary ===${NC}"
if [ "$TOKEN" != "PLACEHOLDER_TOKEN" ]; then
    echo -e "${GREEN}✓${NC} RootSync configured with provided token"
else
    echo -e "${YELLOW}⚠${NC} RootSync configured with placeholder token - update required!"
fi
echo -e "Repository: ${GITEA_URL}/${REPO_PATH}"
echo -e "Branch: ${BRANCH}"
echo -e "Sync Directory: ${SYNC_DIR}"
echo -e "Sync Period: 30s"