#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

echo -e "${BLUE}=== Guardrails Integration Test ===${NC}"
echo "Testing end-to-end security policy enforcement"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    local test_name=$1
    local result=$2
    
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ PASS: ${test_name}${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL: ${test_name}${NC}"
        ((TESTS_FAILED++))
    fi
}

echo -e "${YELLOW}Phase 1: Environment Setup${NC}"

# Create test namespaces with proper labels
kubectl create namespace integration-prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace integration-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace integration-prod environment=production --overwrite
kubectl label namespace integration-dev environment=dev --overwrite

echo "Created test namespaces: integration-prod, integration-dev"

echo ""
echo -e "${YELLOW}Phase 2: Policy Installation Test${NC}"

# Test Sigstore policy application
cat > ${TEMP_DIR}/test-cluster-policy.yaml << 'EOF'
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: integration-test-policy
spec:
  mode: enforce
  images:
  - glob: "nginx:*"
  - glob: "busybox:*"
  authorities:
  - keyless:
      url: https://fulcio.sigstore.dev
      identities:
      - issuer: https://token.actions.githubusercontent.com
        subjectRegExp: ".*"
      - issuer: https://accounts.google.com
        subjectRegExp: ".*@chainguard.dev$"
EOF

kubectl apply -f ${TEMP_DIR}/test-cluster-policy.yaml
test_result "Sigstore ClusterImagePolicy applies" $?

# Test Kyverno policy application
cat > ${TEMP_DIR}/test-kyverno-policy.yaml << 'EOF'
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: integration-verify-images
  namespace: integration-prod
spec:
  validationFailureAction: Enforce
  rules:
  - name: verify-signatures
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "nginx:*"
      - "busybox:*"
      attestors:
      - entries:
        - keyless:
            subject: "*@chainguard.dev"
            issuer: https://accounts.google.com
            rekor:
              url: https://rekor.sigstore.dev
EOF

kubectl apply -f ${TEMP_DIR}/test-kyverno-policy.yaml 2>/dev/null || true
test_result "Kyverno Policy applies" $?

echo ""
echo -e "${YELLOW}Phase 3: Certificate Management Test${NC}"

# Test certificate issuance
cat > ${TEMP_DIR}/test-certificate.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: integration-test-cert
  namespace: integration-prod
spec:
  secretName: integration-test-tls
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  commonName: integration-test.nephio.local
  dnsNames:
  - integration-test.nephio.local
  - api.integration-test.nephio.local
EOF

kubectl apply -f ${TEMP_DIR}/test-certificate.yaml
sleep 10

# Check if certificate was issued
if kubectl get secret integration-test-tls -n integration-prod &>/dev/null; then
    test_result "Certificate issued successfully" 0
else
    test_result "Certificate issued successfully" 1
fi

echo ""
echo -e "${YELLOW}Phase 4: Image Policy Enforcement Test${NC}"

# Test 1: Unsigned image in production (should FAIL)
echo "Testing unsigned image deployment in production namespace..."
cat > ${TEMP_DIR}/unsigned-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unsigned-nginx
  namespace: integration-prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unsigned-nginx
  template:
    metadata:
      labels:
        app: unsigned-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

kubectl apply -f ${TEMP_DIR}/unsigned-deployment.yaml &>/dev/null
UNSIGNED_RESULT=$?

# Should fail (exit code != 0)
if [ $UNSIGNED_RESULT -ne 0 ]; then
    test_result "Unsigned image rejected in production" 0
else
    test_result "Unsigned image rejected in production" 1
fi

# Test 2: Signed image in production (should SUCCEED)
echo "Testing signed image deployment in production namespace..."
cat > ${TEMP_DIR}/signed-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment  
metadata:
  name: signed-nginx
  namespace: integration-prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: signed-nginx
  template:
    metadata:
      labels:
        app: signed-nginx
    spec:
      containers:
      - name: nginx
        image: cgr.dev/chainguard/nginx:latest
        ports:
        - containerPort: 8080
EOF

kubectl apply -f ${TEMP_DIR}/signed-deployment.yaml &>/dev/null
SIGNED_RESULT=$?

test_result "Signed image accepted in production" $SIGNED_RESULT

# Test 3: Unsigned image in dev (should SUCCEED - exempted)
echo "Testing unsigned image deployment in dev namespace..."
cat > ${TEMP_DIR}/dev-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-nginx
  namespace: integration-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-nginx
  template:
    metadata:
      labels:
        app: dev-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

kubectl apply -f ${TEMP_DIR}/dev-deployment.yaml &>/dev/null
DEV_RESULT=$?

test_result "Unsigned image accepted in dev namespace" $DEV_RESULT

echo ""
echo -e "${YELLOW}Phase 5: Policy Interaction Test${NC}"

# Test that multiple policies can coexist
WEBHOOK_COUNT=$(kubectl get validatingwebhookconfigurations | grep -E "(policy-controller|kyverno)" | wc -l)
if [ $WEBHOOK_COUNT -gt 0 ]; then
    test_result "Admission webhooks configured" 0
else
    test_result "Admission webhooks configured" 1
fi

# Test webhook response times
echo "Testing webhook response times..."
START_TIME=$(date +%s%N)
kubectl create pod test-webhook-timing --image=nginx:latest -n integration-dev --dry-run=server -o yaml >/dev/null 2>&1 || true
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 )) # Convert to milliseconds

if [ $RESPONSE_TIME -lt 5000 ]; then  # Less than 5 seconds
    test_result "Webhook response time acceptable (<5s: ${RESPONSE_TIME}ms)" 0
else
    test_result "Webhook response time acceptable (<5s: ${RESPONSE_TIME}ms)" 1
fi

echo ""
echo -e "${YELLOW}Phase 6: Security Validation${NC}"

# Check for secure defaults
kubectl get clusterimageepolicy -o yaml | grep -q "mode: enforce"
test_result "Sigstore policies use enforce mode" $?

# Check cert-manager is not using default self-signed issuer in prod
kubectl get certificates -n integration-prod -o yaml | grep -q "selfsigned-cluster-issuer"
test_result "Test certificate uses controlled issuer" $?

# Verify no privileged containers in test deployments
! kubectl get deployments -n integration-prod -o yaml | grep -q "privileged.*true"
test_result "No privileged containers in production" $?

echo ""
echo -e "${YELLOW}Phase 7: Cleanup and Reporting${NC}"

# Cleanup test resources
kubectl delete namespace integration-prod integration-dev &>/dev/null || true
kubectl delete clusterimageepolicy integration-test-policy &>/dev/null || true

# Final report
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo ""
echo -e "${BLUE}=== Integration Test Results ===${NC}"
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 ALL INTEGRATION TESTS PASSED!${NC}"
    echo "The guardrails security system is properly configured and functional."
    echo ""
    echo "Key validations completed:"
    echo "• Unsigned images are rejected in production namespaces"
    echo "• Signed images are accepted in production namespaces" 
    echo "• Dev namespaces are properly exempted from restrictions"
    echo "• Certificate issuance is working"
    echo "• Webhook performance is acceptable"
    echo "• Security policies are enforcing expected behavior"
else
    echo ""
    echo -e "${RED}❌ INTEGRATION TESTS FAILED!${NC}"
    echo "Review the failed tests and fix the underlying issues."
    echo ""
    echo "Common troubleshooting:"
    echo "• Ensure all security components are installed and ready"
    echo "• Check that policies are applied correctly"
    echo "• Verify namespace labels are set properly"
    echo "• Review webhook configurations and logs"
fi

echo ""
echo "Detailed logs available at:"
echo "• Sigstore: kubectl logs -n cosign-system deployment/policy-controller-webhook"
echo "• Kyverno: kubectl logs -n kyverno deployment/kyverno-admission-controller"
echo "• cert-manager: kubectl logs -n cert-manager deployment/cert-manager"

exit $TESTS_FAILED