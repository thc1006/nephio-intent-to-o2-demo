#!/usr/bin/env bash
set -euo pipefail
cat > /tmp/kind.yaml <<YAML
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
  - containerPort: 30443
    hostPort: 30443
- role: worker
- role: worker
YAML
kind create cluster --name nephio-mgmt --config /tmp/kind.yaml
kubectl cluster-info
