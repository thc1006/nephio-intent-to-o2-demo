#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Edge Kind Cluster Deployment on VM-2 ===${NC}"
echo -e "${YELLOW}Binding to: 172.16.4.45:6443${NC}"

# Check if user can access Docker without sudo
if ! docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker requires sudo. Using sudo for Docker commands...${NC}"
    export KIND_EXPERIMENTAL_PROVIDER=podman
    KIND_CMD="sudo kind"
else
    KIND_CMD="kind"
fi

# Step 1: Create Kind cluster
echo -e "\n${GREEN}[1/4] Creating Kind cluster 'edge'...${NC}"
$KIND_CMD create cluster --name edge --config ~/kind-vm2.yaml || true

# Step 2: Export and modify kubeconfig
echo -e "\n${GREEN}[2/4] Exporting kubeconfig...${NC}"
$KIND_CMD get kubeconfig --name edge > /tmp/kubeconfig-edge.yaml

# Rewrite server URL to use VM-2's IP
sed -i 's|server: https://.*|server: https://172.16.4.45:6443|' /tmp/kubeconfig-edge.yaml
echo -e "${YELLOW}Kubeconfig server URL updated to: https://172.16.4.45:6443${NC}"

# Make kubeconfig readable by all (for scp)
chmod 644 /tmp/kubeconfig-edge.yaml

# Step 3: Health checks
echo -e "\n${GREEN}[3/4] Running health checks...${NC}"
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Check nodes
echo -e "${YELLOW}Checking nodes...${NC}"
if kubectl get nodes; then
    echo -e "${GREEN}✓ Nodes are ready${NC}"
else
    echo -e "${RED}✗ Failed to get nodes${NC}"
    exit 1
fi

# Check namespaces
echo -e "${YELLOW}Checking namespaces...${NC}"
if kubectl get ns; then
    echo -e "${GREEN}✓ Namespaces accessible${NC}"
else
    echo -e "${RED}✗ Failed to get namespaces${NC}"
    exit 1
fi

# Step 4: Copy kubeconfig to VM-1
echo -e "\n${GREEN}[4/4] Copying kubeconfig to VM-1...${NC}"
if scp -o StrictHostKeyChecking=no /tmp/kubeconfig-edge.yaml ubuntu@172.16.0.78:/tmp/kubeconfig-edge.yaml; then
    echo -e "${GREEN}✓ Kubeconfig copied to VM-1:/tmp/kubeconfig-edge.yaml${NC}"
else
    echo -e "${RED}✗ Failed to copy kubeconfig to VM-1${NC}"
    echo -e "${YELLOW}Please ensure SSH access to VM-1 (172.16.0.78) is configured${NC}"
fi

# Summary and next steps
echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "${YELLOW}Edge cluster 'edge' is running on VM-2 (172.16.4.45:6443)${NC}"
echo -e "\n${GREEN}Next Steps:${NC}"
echo -e "1. On VM-1, verify access: ${YELLOW}export KUBECONFIG=/tmp/kubeconfig-edge.yaml && kubectl get nodes${NC}"
echo -e "2. Deploy workloads using NodePort services on ports 30080/30443 (mapped to host 31080/31443)"
echo -e "3. Access services via: ${YELLOW}http://172.16.4.45:31080${NC} or ${YELLOW}https://172.16.4.45:31443${NC}"
echo -e "\n${GREEN}Useful Commands:${NC}"
echo -e "- Check cluster: ${YELLOW}${KIND_CMD:-kind} get clusters${NC}"
echo -e "- Delete cluster: ${YELLOW}${KIND_CMD:-kind} delete cluster --name edge${NC}"
echo -e "- View logs: ${YELLOW}sudo docker logs edge-control-plane${NC}"