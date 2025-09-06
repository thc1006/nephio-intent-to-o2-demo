#!/bin/bash
set -euo pipefail

KYVERNO_VERSION="v1.12.0"

echo "Installing Kyverno ${KYVERNO_VERSION}..."

# Install using kubectl
kubectl create -f https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml

echo "Waiting for Kyverno to be ready..."
kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=300s
kubectl rollout status deployment/kyverno-background-controller -n kyverno --timeout=300s
kubectl rollout status deployment/kyverno-cleanup-controller -n kyverno --timeout=300s
kubectl rollout status deployment/kyverno-reports-controller -n kyverno --timeout=300s

echo ""
echo "Alternative Helm installation method:"
cat << 'EOF'
# Add Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Install Kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --version ${KYVERNO_VERSION} \
  --set admissionController.replicas=3 \
  --set backgroundController.replicas=2 \
  --wait
EOF

echo ""
echo "Verifying installation..."
kubectl get pods -n kyverno
kubectl get crd | grep kyverno

echo ""
echo "Apply image verification policy:"
echo "kubectl apply -f policies/verify-images.yaml"

echo ""
echo "Test policies with kyverno CLI:"
echo "kyverno test --policy policies/ --resource tests/resource.yaml --values tests/test-values.yaml"