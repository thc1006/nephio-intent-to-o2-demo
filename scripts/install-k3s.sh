#!/bin/bash

echo "========================================="
echo "Installing K3s on VM-1 (Port 6444)"
echo "========================================="

# Install K3s with custom API server port (6444) to avoid conflict with Docker
echo "Installing K3s on port 6444..."
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --https-listen-port 6444 \
    --advertise-address 172.16.0.78 \
    --advertise-port 6444

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 10

# Check K3s status
sudo systemctl status k3s --no-pager

# Setup kubeconfig for current user
echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
# Update the server URL in kubeconfig to use port 6444
sed -i 's/:6443/:6444/g' $HOME/.kube/config

# Export KUBECONFIG
export KUBECONFIG=$HOME/.kube/config
echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bashrc

# Verify installation
echo ""
echo "Verifying K3s installation..."
kubectl version --short
kubectl get nodes
kubectl get pods -A

echo ""
echo "========================================="
echo "K3s Installation Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Deploy monitoring components to K3s"
echo "2. Apply Config Sync configurations"
echo "3. Setup ingress for services"
echo ""