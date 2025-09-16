#!/bin/bash

# Install Config Sync on Edge clusters
set -e

EDGE_IP=$1
EDGE_NAME=$2

if [ -z "$EDGE_IP" ] || [ -z "$EDGE_NAME" ]; then
    echo "Usage: $0 <edge-ip> <edge-name>"
    exit 1
fi

echo "Installing Config Sync on ${EDGE_NAME} (${EDGE_IP})..."

# Download Config Sync manifests
curl -sS https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.15.0/config-sync-manifest.yaml -o /tmp/config-sync.yaml

# Apply to cluster
ssh -o StrictHostKeyChecking=no ubuntu@${EDGE_IP} "kubectl apply -f -" < /tmp/config-sync.yaml

# Wait for deployment
sleep 10

# Create RootSync for the edge
cat > /tmp/rootsync-${EDGE_NAME}.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: config-management-system
---
apiVersion: v1
kind: Secret
metadata:
  name: gitea-token
  namespace: config-management-system
type: Opaque
data:
  token: YWRtaW4xOmFkbWluMTIz  # admin1:admin123
---
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceType: git
  git:
    repo: http://172.16.0.78:8888/admin1/${EDGE_NAME}-config
    branch: main
    auth: token
    secretRef:
      name: gitea-token
EOF

# Apply RootSync
ssh -o StrictHostKeyChecking=no ubuntu@${EDGE_IP} "kubectl apply -f -" < /tmp/rootsync-${EDGE_NAME}.yaml

echo "Config Sync installed on ${EDGE_NAME}"