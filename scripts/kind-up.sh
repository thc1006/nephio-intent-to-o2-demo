#!/bin/bash
# kind cluster setup with NodePorts for O2 IMS access

set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-nephio-demo}"
K8S_VERSION="${K8S_VERSION:-v1.29.0}"

cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --image "kindest/node:$K8S_VERSION" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "nephio.org/role=control"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "nephio.org/role=worker"
EOF

echo "Cluster $CLUSTER_NAME created"
kubectl cluster-info --context "kind-$CLUSTER_NAME"

# Wait for nodes
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "NodePorts 30080/30443 exposed on localhost"
