#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Setup Gitea Network Access for Edge Clusters${NC}"
echo -e "${BLUE}=========================================${NC}"

# Configuration
VM1_IP="172.16.0.78"
KIND_NODE_IP="172.18.0.2"
GITEA_NODEPORT="30924"
EXTERNAL_PORT="8888"

echo -e "\n${YELLOW}Current Gitea Service Configuration:${NC}"
kubectl get svc -n gitea-system

echo -e "\n${YELLOW}Option 1: Using socat for port forwarding (Recommended)${NC}"
echo "----------------------------------------"

# Check if socat is installed
if ! command -v socat &> /dev/null; then
    echo "Installing socat..."
    sudo apt-get update && sudo apt-get install -y socat
fi

# Kill any existing socat processes
sudo pkill -f "socat.*TCP-LISTEN:${EXTERNAL_PORT}" 2>/dev/null || true

# Start socat in background
echo "Starting socat forwarder on port ${EXTERNAL_PORT}..."
sudo nohup socat TCP-LISTEN:${EXTERNAL_PORT},fork,reuseaddr TCP:${KIND_NODE_IP}:${GITEA_NODEPORT} > /tmp/socat-gitea.log 2>&1 &
SOCAT_PID=$!

sleep 2

if sudo kill -0 $SOCAT_PID 2>/dev/null; then
    echo -e "${GREEN}✓ Socat forwarder started (PID: $SOCAT_PID)${NC}"
    echo -e "${GREEN}✓ Gitea now accessible at: http://${VM1_IP}:${EXTERNAL_PORT}${NC}"
else
    echo -e "${RED}✗ Failed to start socat forwarder${NC}"
fi

echo -e "\n${YELLOW}Option 2: Using iptables NAT rules${NC}"
echo "----------------------------------------"

# Add iptables NAT rules
echo "Adding iptables NAT rules..."

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Add DNAT rule to forward external traffic to Kind node
sudo iptables -t nat -A PREROUTING -p tcp -d ${VM1_IP} --dport ${EXTERNAL_PORT} -j DNAT --to-destination ${KIND_NODE_IP}:${GITEA_NODEPORT}

# Add SNAT rule for return traffic
sudo iptables -t nat -A POSTROUTING -p tcp -d ${KIND_NODE_IP} --dport ${GITEA_NODEPORT} -j SNAT --to-source ${VM1_IP}

# Allow forwarding
sudo iptables -A FORWARD -p tcp -d ${KIND_NODE_IP} --dport ${GITEA_NODEPORT} -j ACCEPT
sudo iptables -A FORWARD -p tcp -s ${KIND_NODE_IP} --sport ${GITEA_NODEPORT} -j ACCEPT

echo -e "${GREEN}✓ iptables rules added${NC}"

echo -e "\n${YELLOW}Option 3: Using kubectl port-forward with external binding${NC}"
echo "----------------------------------------"

# Kill existing port-forward
pkill -f "kubectl port-forward.*gitea.*${EXTERNAL_PORT}" 2>/dev/null || true

# Start port-forward with external binding
echo "Starting kubectl port-forward..."
nohup kubectl port-forward -n gitea-system svc/gitea-service ${EXTERNAL_PORT}:3000 --address=0.0.0.0 > /tmp/kubectl-pf-gitea.log 2>&1 &
PF_PID=$!

sleep 2

if kill -0 $PF_PID 2>/dev/null; then
    echo -e "${GREEN}✓ kubectl port-forward started (PID: $PF_PID)${NC}"
else
    echo -e "${RED}✗ Failed to start port-forward${NC}"
fi

echo -e "\n${YELLOW}Testing accessibility:${NC}"
echo "----------------------------------------"

# Test local access
echo -n "Testing local access (localhost:${EXTERNAL_PORT})... "
if timeout 5 curl -s -o /dev/null http://localhost:${EXTERNAL_PORT}; then
    echo -e "${GREEN}✓ Success${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Test external access
echo -n "Testing external access (${VM1_IP}:${EXTERNAL_PORT})... "
if timeout 5 curl -s -o /dev/null http://${VM1_IP}:${EXTERNAL_PORT}; then
    echo -e "${GREEN}✓ Success${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE}Configuration for Edge Clusters${NC}"
echo -e "${BLUE}=========================================${NC}"

echo -e "\n${YELLOW}Updated RootSync configuration:${NC}"
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
    repo: http://${VM1_IP}:${EXTERNAL_PORT}/admin1/edge-config.git
    branch: main
    dir: /
    period: 30s
    auth: token
    secretRef:
      name: gitea-credentials
EOF

echo -e "\n${YELLOW}Test from Edge VMs:${NC}"
echo "# From VM-2 (Edge-1):"
echo "curl http://${VM1_IP}:${EXTERNAL_PORT}/api/v1/version"
echo ""
echo "# From VM-4 (Edge-2):"
echo "curl http://${VM1_IP}:${EXTERNAL_PORT}/api/v1/version"

echo -e "\n${YELLOW}To make persistent (survive reboot):${NC}"
echo "# Add to /etc/rc.local or create systemd service:"
echo "sudo socat TCP-LISTEN:${EXTERNAL_PORT},fork,reuseaddr TCP:${KIND_NODE_IP}:${GITEA_NODEPORT} &"

echo -e "\n${YELLOW}To stop the forwarders:${NC}"
echo "# Stop socat:"
echo "sudo pkill -f 'socat.*TCP-LISTEN:${EXTERNAL_PORT}'"
echo ""
echo "# Stop kubectl port-forward:"
echo "pkill -f 'kubectl port-forward.*gitea.*${EXTERNAL_PORT}'"
echo ""
echo "# Remove iptables rules:"
echo "sudo iptables -t nat -D PREROUTING -p tcp -d ${VM1_IP} --dport ${EXTERNAL_PORT} -j DNAT --to-destination ${KIND_NODE_IP}:${GITEA_NODEPORT}"
echo "sudo iptables -t nat -D POSTROUTING -p tcp -d ${KIND_NODE_IP} --dport ${GITEA_NODEPORT} -j SNAT --to-source ${VM1_IP}"

echo -e "\n${GREEN}Setup completed!${NC}"
echo -e "${GREEN}Gitea should now be accessible from Edge VMs at: http://${VM1_IP}:${EXTERNAL_PORT}${NC}"