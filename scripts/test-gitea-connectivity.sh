#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Gitea Network Connectivity Test${NC}"
echo -e "${BLUE}=========================================${NC}"

# Configuration
VM1_IP="172.16.0.78"
VM2_IP="172.16.4.45"
VM4_IP="172.16.4.176"
GITEA_NODEPORT="30888"
GITEA_SSH_PORT="30222"
GITEA_USER="${GITEA_USER:-gitea_admin}"
GITEA_PASS="${GITEA_PASS:-r8sA8CPHD9!bt6d}"

# Function to test connectivity
test_connection() {
    local host=$1
    local port=$2
    local desc=$3

    echo -n "Testing $desc ($host:$port)... "
    if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}"
        return 1
    fi
}

# Function to test HTTP endpoint
test_http() {
    local url=$1
    local desc=$2

    echo -n "Testing HTTP $desc ($url)... "
    response=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$url" 2>/dev/null || echo "000")
    if [[ "$response" == "200" ]] || [[ "$response" == "302" ]]; then
        echo -e "${GREEN}✓ HTTP $response${NC}"
        return 0
    else
        echo -e "${RED}✗ HTTP $response${NC}"
        return 1
    fi
}

# Function to test from within a pod
test_from_pod() {
    local namespace=$1
    local gitea_url=$2

    echo -e "\n${YELLOW}Testing from pod in namespace: $namespace${NC}"

    # Create a test pod
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: network-test-pod
  namespace: $namespace
spec:
  containers:
  - name: test
    image: nicolaka/netshoot:latest
    command: ["sleep", "300"]
  restartPolicy: Never
EOF

    # Wait for pod to be ready
    echo -n "Waiting for test pod to be ready... "
    kubectl wait --for=condition=Ready pod/network-test-pod -n $namespace --timeout=30s >/dev/null 2>&1
    echo -e "${GREEN}Ready${NC}"

    # Test DNS resolution
    echo -n "  DNS resolution test... "
    if kubectl exec -n $namespace network-test-pod -- nslookup gitea-service.gitea-system.svc.cluster.local >/dev/null 2>&1; then
        echo -e "${GREEN}✓ DNS OK${NC}"
    else
        echo -e "${RED}✗ DNS Failed${NC}"
    fi

    # Test service connectivity
    echo -n "  Service connectivity (ClusterIP)... "
    if kubectl exec -n $namespace network-test-pod -- curl -s -m 5 http://gitea-service.gitea-system.svc.cluster.local:3000 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi

    # Test external connectivity
    echo -n "  External connectivity ($gitea_url)... "
    if kubectl exec -n $namespace network-test-pod -- curl -s -m 5 "$gitea_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi

    # Clean up test pod
    kubectl delete pod network-test-pod -n $namespace --force --grace-period=0 >/dev/null 2>&1
}

# Main tests
echo -e "\n${YELLOW}1. Local Kubernetes Service Tests${NC}"
echo "----------------------------------------"

# Check if Gitea pods are running
echo -n "Gitea pods status... "
pod_status=$(kubectl get pods -n gitea-system -l app=gitea -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$pod_status" == "Running" ]]; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Status: $pod_status${NC}"
fi

# Check services
echo -n "Gitea services... "
svc_count=$(kubectl get svc -n gitea-system -l app=gitea --no-headers 2>/dev/null | wc -l)
echo -e "${GREEN}Found $svc_count service(s)${NC}"

# Get actual NodePort
actual_nodeport=$(kubectl get svc -n gitea-system gitea-service -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}' 2>/dev/null || echo "N/A")
echo "Actual NodePort: $actual_nodeport"

echo -e "\n${YELLOW}2. Network Connectivity Tests${NC}"
echo "----------------------------------------"

# Test from VM-1 (local)
test_connection "localhost" "$actual_nodeport" "localhost NodePort"
test_connection "172.18.0.2" "$actual_nodeport" "Kind node IP"
test_connection "$VM1_IP" "$GITEA_NODEPORT" "VM-1 external NodePort"

# Test HTTP endpoints
echo -e "\n${YELLOW}3. HTTP Endpoint Tests${NC}"
echo "----------------------------------------"
test_http "http://localhost:$actual_nodeport" "localhost"
test_http "http://172.18.0.2:$actual_nodeport" "Kind node"
test_http "http://$VM1_IP:$GITEA_NODEPORT" "VM-1 external"

# Test from pods
echo -e "\n${YELLOW}4. Pod-to-Gitea Connectivity Tests${NC}"
echo "----------------------------------------"

# Test from default namespace
test_from_pod "default" "http://$VM1_IP:$GITEA_NODEPORT"

# Test from config-management-system namespace if it exists
if kubectl get ns config-management-system >/dev/null 2>&1; then
    test_from_pod "config-management-system" "http://$VM1_IP:$GITEA_NODEPORT"
fi

echo -e "\n${YELLOW}5. Git Repository Access Test${NC}"
echo "----------------------------------------"

# Test git clone with credentials
test_repo_url="http://${GITEA_USER}:${GITEA_PASS}@${VM1_IP}:${GITEA_NODEPORT}/admin1/edge1-config.git"
echo -n "Testing git ls-remote... "
if timeout 10 git ls-remote "$test_repo_url" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Repository accessible${NC}"
else
    echo -e "${RED}✗ Repository not accessible${NC}"
    echo "  Trying alternative URLs..."

    # Try alternative URLs
    alt_urls=(
        "http://172.18.0.2:$actual_nodeport/admin1/edge1-config.git"
        "http://gitea-service.gitea-system.svc.cluster.local:3000/admin1/edge1-config.git"
    )

    for url in "${alt_urls[@]}"; do
        full_url="http://${GITEA_USER}:${GITEA_PASS}@${url#http://}"
        echo -n "  Trying $url... "
        if timeout 5 git ls-remote "$full_url" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Works${NC}"
            echo -e "${GREEN}  Working URL: $url${NC}"
            break
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    done
fi

echo -e "\n${YELLOW}6. Network Routes and Firewall${NC}"
echo "----------------------------------------"

# Check routing table
echo "Routing table:"
ip route | grep -E "(172.16|172.18)" | head -5

# Check iptables rules for NodePort
echo -e "\nNodePort iptables rules:"
sudo iptables -t nat -L KUBE-NODEPORTS 2>/dev/null | grep -E "$GITEA_NODEPORT|$actual_nodeport" | head -5 || echo "No specific rules found"

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}=========================================${NC}"

# Provide recommendations
echo -e "\n${YELLOW}Recommended Gitea URLs for Edge Clusters:${NC}"
echo ""
echo "Option 1 - Direct NodePort (if network allows):"
echo "  URL: http://${VM1_IP}:${actual_nodeport}"
echo ""
echo "Option 2 - Via SSH tunnel (most reliable):"
echo "  Setup: ssh -L 8888:172.18.0.2:${actual_nodeport} ubuntu@${VM1_IP}"
echo "  URL: http://localhost:8888"
echo ""
echo "Option 3 - Host network binding (requires setup):"
echo "  URL: http://${VM1_IP}:8888"
echo ""

# Generate recommended RootSync configuration
echo -e "${YELLOW}Recommended RootSync configuration:${NC}"
cat <<EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge-root-sync
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://${VM1_IP}:${actual_nodeport}/admin1/edge-config.git
    branch: main
    dir: /
    period: 30s
    auth: token
    secretRef:
      name: gitea-credentials
EOF

echo -e "\n${GREEN}Test completed!${NC}"