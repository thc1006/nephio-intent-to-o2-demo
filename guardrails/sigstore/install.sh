#!/bin/bash
set -euo pipefail

POLICY_CONTROLLER_VERSION="v0.10.0"
NAMESPACE="cosign-system"

echo "Installing Sigstore Policy Controller ${POLICY_CONTROLLER_VERSION}..."

# Install using Helm
helm repo add sigstore https://sigstore.github.io/helm-charts
helm repo update

helm install policy-controller sigstore/policy-controller \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --version ${POLICY_CONTROLLER_VERSION} \
  --set webhook.configPolicy=enforce \
  --set webhook.failurePolicy=Fail \
  --set webhook.namespaceSelector.matchExpressions[0].key=environment \
  --set webhook.namespaceSelector.matchExpressions[0].operator=NotIn \
  --set webhook.namespaceSelector.matchExpressions[0].values[0]=dev \
  --wait

echo "Policy Controller installed successfully!"

# Alternative: kubectl install method
echo ""
echo "Alternative kubectl install method:"
cat << 'EOF'
kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/${POLICY_CONTROLLER_VERSION}/policy-controller-${POLICY_CONTROLLER_VERSION}.yaml

# Wait for deployment
kubectl rollout status deployment/policy-controller-webhook -n cosign-system
kubectl rollout status deployment/policy-controller -n cosign-system
EOF

echo ""
echo "Verifying installation..."
kubectl get pods -n ${NAMESPACE}
kubectl get validatingwebhookconfigurations | grep policy-controller

echo ""
echo "Apply ClusterImagePolicy:"
echo "kubectl apply -f policies/cluster-image-policy.yaml"