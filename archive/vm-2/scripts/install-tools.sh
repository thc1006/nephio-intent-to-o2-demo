#!/bin/bash
# Tool installation script for VM-2 environment

set -e

echo "Installing required tools..."

# kubectl
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
fi

# kind
if ! command -v kind &> /dev/null; then
  curl -Lo kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
  chmod +x kind
  sudo mv kind /usr/local/bin/
fi

# kpt
if ! command -v kpt &> /dev/null; then
  curl -LO https://github.com/kptdev/kpt/releases/download/v1.0.0/kpt_linux_amd64
  chmod +x kpt_linux_amd64
  sudo mv kpt_linux_amd64 /usr/local/bin/kpt
fi

echo "Tools installed successfully!"
