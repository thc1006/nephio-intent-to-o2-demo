#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Setting up kubectl environment ===${NC}"

# Add KUBECONFIG to bashrc
if ! grep -q "KUBECONFIG=/tmp/kubeconfig-edge.yaml" ~/.bashrc; then
    echo 'export KUBECONFIG=/tmp/kubeconfig-edge.yaml' >> ~/.bashrc
    echo -e "${GREEN}✓ Added KUBECONFIG to ~/.bashrc${NC}"
else
    echo -e "${YELLOW}KUBECONFIG already in ~/.bashrc${NC}"
fi

# Create kubectl alias
if ! grep -q "alias k=" ~/.bashrc; then
    echo "alias k='kubectl'" >> ~/.bashrc
    echo -e "${GREEN}✓ Added kubectl alias 'k'${NC}"
fi

# Set for current session
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Source bashrc
source ~/.bashrc

echo -e "\n${GREEN}=== Testing kubectl connection ===${NC}"
kubectl cluster-info

echo -e "\n${GREEN}=== Checking namespaces ===${NC}"
kubectl get ns | grep -E '(edge|o2ims|config)'

echo -e "\n${GREEN}Setup complete!${NC}"
echo -e "${YELLOW}You can now use:${NC}"
echo -e "  kubectl get nodes"
echo -e "  kubectl get all -n edge1"
echo -e "  k get pods -A  (using alias)"
echo -e "\n${YELLOW}KUBECONFIG is set to: /tmp/kubeconfig-edge.yaml${NC}"