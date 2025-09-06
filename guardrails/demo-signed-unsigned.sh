#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Sigstore Policy Controller Demo ===${NC}"
echo "Demonstrating unsigned image rejection and signed image acceptance"
echo ""

# Setup test namespaces
echo -e "${YELLOW}Step 1: Creating test namespaces...${NC}"
kubectl create namespace production-test --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev-test --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace production-test environment=production --overwrite
kubectl label namespace dev-test environment=dev --overwrite

echo ""
echo -e "${YELLOW}Step 2: Apply ClusterImagePolicy for Sigstore...${NC}"
cat << 'EOF' | kubectl apply -f -
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: reject-unsigned-images
spec:
  mode: enforce
  images:
  - glob: "**"
  authorities:
  - keyless:
      url: https://fulcio.sigstore.dev
      identities:
      - issuer: https://token.actions.githubusercontent.com
        subjectRegExp: ".*"
  - key:
      data: |
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE5vTxPbLilbUtbBriPuJQCvmyU3To
        dJGKpQ1/kFwypiUNyfq7lwdLIgLWbXMq5A3H9q3v3zzNPQLvQ8K1YvTUHw==
        -----END PUBLIC KEY-----
EOF

sleep 3

echo ""
echo -e "${YELLOW}Step 3: Testing UNSIGNED image in production namespace (should FAIL)...${NC}"
echo "Attempting to deploy nginx:latest (unsigned)..."
kubectl create deployment unsigned-nginx --image=nginx:latest -n production-test --dry-run=client -o yaml | \
  kubectl apply -f - 2>&1 | tee /tmp/unsigned-result.txt || true

if grep -q "admission webhook.*denied\|validation failed\|error validating" /tmp/unsigned-result.txt; then
  echo -e "${GREEN}✓ SUCCESS: Unsigned image was correctly REJECTED in production namespace${NC}"
else
  echo -e "${RED}✗ WARNING: Unsigned image might have been accepted (check if policy is active)${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Testing SIGNED image in production namespace (should SUCCEED)...${NC}"
echo "Attempting to deploy ghcr.io/stefanprodan/podinfo:6.5.4 (signed with keyless)..."
cat << 'EOF' | kubectl apply -f - -n production-test
apiVersion: apps/v1
kind: Deployment
metadata:
  name: signed-podinfo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
      - name: podinfo
        image: ghcr.io/stefanprodan/podinfo:6.5.4
        ports:
        - containerPort: 9898
EOF

sleep 5
if kubectl get deployment signed-podinfo -n production-test &> /dev/null; then
  echo -e "${GREEN}✓ SUCCESS: Signed image was correctly ACCEPTED in production namespace${NC}"
  kubectl get pods -n production-test -l app=podinfo
else
  echo -e "${RED}✗ FAILED: Signed image was not accepted${NC}"
fi

echo ""
echo -e "${YELLOW}Step 5: Testing UNSIGNED image in dev namespace (should SUCCEED)...${NC}"
echo "Attempting to deploy nginx:latest in dev namespace..."
kubectl create deployment dev-nginx --image=nginx:latest -n dev-test

sleep 3
if kubectl get deployment dev-nginx -n dev-test &> /dev/null; then
  echo -e "${GREEN}✓ SUCCESS: Unsigned image was correctly ACCEPTED in dev namespace (exempted)${NC}"
  kubectl get pods -n dev-test
else
  echo -e "${RED}✗ FAILED: Unsigned image was rejected in dev namespace${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Alternative signed images to test...${NC}"
cat << 'EOF'
Other signed images you can test:
- cgr.dev/chainguard/nginx:latest (Chainguard signed)
- gcr.io/distroless/static:nonroot (Google distroless signed)
- quay.io/keycloak/keycloak:24.0 (Red Hat signed)
- registry.k8s.io/pause:3.9 (Kubernetes signed)

Verify signature manually:
cosign verify --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer-regexp ".*" \
  ghcr.io/stefanprodan/podinfo:6.5.4
EOF

echo ""
echo -e "${YELLOW}Step 7: Kyverno alternative (if installed)...${NC}"
cat << 'EOF'
To test with Kyverno instead:
1. Install Kyverno:
   kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

2. Apply Kyverno policy:
   kubectl apply -f guardrails/kyverno/policies/verify-images.yaml

3. Test with kyverno CLI:
   kyverno test --policy guardrails/kyverno/policies/ \
     --resource guardrails/kyverno/tests/resource.yaml \
     --values guardrails/kyverno/tests/test-values.yaml
EOF

echo ""
echo -e "${GREEN}=== Demo Complete ===${NC}"
echo ""
echo "Cleanup commands:"
echo "  kubectl delete namespace production-test dev-test"
echo "  kubectl delete clusterimageepolicy reject-unsigned-images"
echo ""
echo "View logs:"
echo "  kubectl logs -n cosign-system deployment/policy-controller-webhook"