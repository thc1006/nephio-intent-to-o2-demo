#!/bin/bash
set -euo pipefail

CERT_MANAGER_VERSION="v1.18.2"
NAMESPACE="cert-manager"

echo "Installing cert-manager ${CERT_MANAGER_VERSION}..."

# Install using kubectl
echo "Installing CRDs and cert-manager components..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n ${NAMESPACE}

echo ""
echo "Alternative Helm installation method:"
cat << 'EOF'
# Add Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version ${CERT_MANAGER_VERSION} \
  --set crds.enabled=true \
  --set prometheus.enabled=false \
  --wait
EOF

echo ""
echo "Verifying installation..."
kubectl get pods -n ${NAMESPACE}
kubectl get apiservices | grep cert-manager

echo ""
echo "Creating self-signed ClusterIssuer..."
kubectl apply -f manifests/cluster-issuer.yaml

echo ""
echo "Testing cert-manager with a test certificate..."
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: cert-test
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: cert-test
spec:
  secretName: test-tls
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  commonName: test.example.com
  dnsNames:
  - test.example.com
EOF

sleep 5
echo ""
echo "Checking certificate status..."
kubectl describe certificate test-certificate -n cert-test | grep -A 5 "Status:"

echo ""
echo "Cleanup test resources:"
echo "kubectl delete namespace cert-test"