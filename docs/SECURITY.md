# Security Implementation Guide

This document provides exact commands for installing and configuring the security guardrails for the Nephio Intent-to-O2 demo pipeline.

## Table of Contents
- [Quick Start](#quick-start)
- [Sigstore Policy Controller](#sigstore-policy-controller)
- [Kyverno Image Verification](#kyverno-image-verification)
- [Cert-Manager](#cert-manager)
- [Demo: Unsigned vs Signed Images](#demo-unsigned-vs-signed-images)
- [Production Checklist](#production-checklist)

## Quick Start

```bash
# Install all security components
cd guardrails

# Method 1: Use Makefile (recommended)
make install-all          # Install all components
make apply-policies       # Apply security policies
make test-all            # Run comprehensive tests
make demo                # Run demonstration

# Method 2: Manual installation
./cert-manager/install.sh   # Install cert-manager (required for TLS)
./sigstore/install.sh       # Install Sigstore policy controller
./kyverno/install.sh        # Install Kyverno (optional alternative)
make apply-policies         # Apply security policies
./demo-signed-unsigned.sh   # Run demonstration

# Method 3: Full integration test
./integration-test.sh     # End-to-end validation
```

## Sigstore Policy Controller

### Installation via Helm

```bash
# Add Helm repository
helm repo add sigstore https://sigstore.github.io/helm-charts
helm repo update

# Install with enforcing mode
helm install policy-controller sigstore/policy-controller \
  --namespace cosign-system \
  --create-namespace \
  --version v0.10.0 \
  --set webhook.configPolicy=enforce \
  --set webhook.failurePolicy=Fail \
  --wait

# Verify installation
kubectl get pods -n cosign-system
kubectl get validatingwebhookconfigurations | grep policy-controller
```

### Installation via kubectl

```bash
# Apply manifest directly
kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/v0.10.0/policy-controller-v0.10.0.yaml

# Wait for readiness
kubectl rollout status deployment/policy-controller-webhook -n cosign-system
kubectl rollout status deployment/policy-controller -n cosign-system
```

### Apply ClusterImagePolicy

```bash
# Apply the policy that rejects unsigned images in non-dev namespaces
kubectl apply -f - <<'EOF'
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: reject-unsigned-production
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
      - issuer: https://accounts.google.com
        subjectRegExp: ".*@chainguard.dev$"
  - key:
      data: |
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE5vTxPbLilbUtbBriPuJQCvmyU3To
        dJGKpQ1/kFwypiUNyfq7lwdLIgLWbXMq5A3H9q3v3zzNPQLvQ8K1YvTUHw==
        -----END PUBLIC KEY-----
EOF
```

### Namespace Exemptions

```bash
# Label namespaces to exempt from policy
kubectl label namespace kube-system policy.sigstore.dev/exclude=true
kubectl label namespace dev environment=dev
kubectl label namespace staging environment=staging
```

## Kyverno Image Verification

### Installation

```bash
# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.12.0/install.yaml

# Wait for readiness
kubectl rollout status deployment/kyverno-admission-controller -n kyverno
kubectl rollout status deployment/kyverno-background-controller -n kyverno
kubectl rollout status deployment/kyverno-cleanup-controller -n kyverno
kubectl rollout status deployment/kyverno-reports-controller -n kyverno
```

### Apply Image Verification Policy

```bash
kubectl apply -f - <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images
spec:
  background: false
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
  - name: verify-signatures
    match:
      any:
      - resources:
          kinds:
          - Pod
          - Deployment
          - DaemonSet
          - StatefulSet
          namespaceSelector:
            matchExpressions:
            - key: environment
              operator: NotIn
              values:
              - dev
    verifyImages:
    - imageReferences:
      - "*"
      attestors:
      - entries:
        - keyless:
            subject: "*@chainguard.dev"
            issuer: https://accounts.google.com
            rekor:
              url: https://rekor.sigstore.dev
      - entries:
        - keyless:
            subject: "*"
            issuer: https://token.actions.githubusercontent.com
            rekor:
              url: https://rekor.sigstore.dev
EOF
```

### Test Kyverno Policies

```bash
# Install kyverno CLI
brew install kyverno  # macOS
# or
curl -L https://github.com/kyverno/kyverno/releases/download/v1.12.0/kyverno-cli_v1.12.0_linux_x86_64.tar.gz | tar -xz

# Run tests
kyverno test \
  --policy guardrails/kyverno/policies/ \
  --resource guardrails/kyverno/tests/resource.yaml \
  --values guardrails/kyverno/tests/test-values.yaml
```

## Cert-Manager

### Installation via kubectl

```bash
# Apply the manifest
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml

# Wait for webhooks to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager

# Verify installation
kubectl get pods -n cert-manager
cmctl check api  # if cmctl is installed
```

### Installation via Helm

```bash
# Add repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.0 \
  --set crds.enabled=true \
  --set prometheus.enabled=false \
  --wait
```

### Create ClusterIssuers

```bash
# Self-signed issuer for testing
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
EOF

# CA issuer with generated root
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-cluster-issuer
spec:
  ca:
    secretName: ca-key-pair
---
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
  namespace: cert-manager
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # base64 encoded cert
  tls.key: LS0tLS1CRUdJTi... # base64 encoded key
EOF
```

### Request a Certificate

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls-secret
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  commonName: example.com
  dnsNames:
  - example.com
  - www.example.com
EOF

# Check certificate status
kubectl describe certificate example-tls
kubectl get secret example-tls-secret -o yaml
```

## Demo: Unsigned vs Signed Images

### Full Interactive Demo

```bash
# Run the complete demo script
./guardrails/demo-signed-unsigned.sh
```

### Manual Demo Steps

#### 1. Setup Test Namespaces

```bash
# Create and label namespaces
kubectl create namespace prod-test
kubectl create namespace dev-test
kubectl label namespace prod-test environment=production
kubectl label namespace dev-test environment=dev
```

#### 2. Test Unsigned Image (REJECTED in production)

```bash
# This should FAIL in production namespace
kubectl run unsigned-nginx --image=nginx:latest -n prod-test

# Expected output:
# Error from server (BadRequest): admission webhook "policy.sigstore.dev" denied the request: 
# validation failed: failed to validate image signature
```

#### 3. Test Signed Image (ACCEPTED in production)

```bash
# This should SUCCEED - using Chainguard signed image
kubectl run signed-nginx --image=cgr.dev/chainguard/nginx:latest -n prod-test

# Verify it's running
kubectl get pod signed-nginx -n prod-test
```

#### 4. Test Unsigned Image in Dev (ACCEPTED)

```bash
# This should SUCCEED in dev namespace (exempted)
kubectl run dev-nginx --image=nginx:latest -n dev-test

# Verify it's running
kubectl get pod dev-nginx -n dev-test
```

### Signed Images for Testing

```bash
# Chainguard images (signed with keyless)
cgr.dev/chainguard/nginx:latest
cgr.dev/chainguard/python:latest
cgr.dev/chainguard/node:latest

# Google Distroless (signed)
gcr.io/distroless/static:nonroot
gcr.io/distroless/base:latest

# GitHub Container Registry (often signed)
ghcr.io/stefanprodan/podinfo:6.5.4
ghcr.io/fluxcd/flux-cli:v2.2.3

# Verify signatures manually
cosign verify \
  --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer-regexp ".*" \
  cgr.dev/chainguard/nginx:latest
```

## Production Checklist

### Pre-Deployment

```bash
# 1. Verify all components are installed
kubectl get ns cert-manager cosign-system kyverno

# 2. Check webhook configurations
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# 3. Test policies in dry-run mode first
kubectl apply -f policies/ --dry-run=server
```

### Monitoring

```bash
# Watch policy controller logs
kubectl logs -f deployment/policy-controller-webhook -n cosign-system

# Watch Kyverno logs
kubectl logs -f deployment/kyverno-admission-controller -n kyverno

# Check cert-manager logs
kubectl logs -f deployment/cert-manager -n cert-manager
```

### Troubleshooting

```bash
# Debug denied admission
kubectl describe replicaset <rs-name> -n <namespace>
kubectl events -n <namespace>

# Check policy status
kubectl get clusterimageepolicy -o yaml
kubectl get clusterpolicy -o yaml

# Verify webhook is receiving requests
kubectl logs -n cosign-system deployment/policy-controller-webhook --tail=100
```

### Emergency Bypass

```bash
# Temporarily disable enforcement (USE WITH CAUTION)
kubectl patch clusterimageepolicy reject-unsigned-production \
  --type='json' -p='[{"op": "replace", "path": "/spec/mode", "value": "warn"}]'

# Re-enable enforcement
kubectl patch clusterimageepolicy reject-unsigned-production \
  --type='json' -p='[{"op": "replace", "path": "/spec/mode", "value": "enforce"}]'
```

## Security Best Practices

1. **Never disable policies in production** - Use namespace exemptions instead
2. **Monitor webhook latency** - Set appropriate timeout values
3. **Use fail-closed configuration** - Deny on webhook failure
4. **Rotate signing keys regularly** - Update ClusterImagePolicy accordingly
5. **Audit policy violations** - Export logs to SIEM
6. **Test in staging first** - Validate policies don't break deployments
7. **Document exemptions** - Maintain list of exempted namespaces/images
8. **Use GitOps for policies** - Version control all security policies

## Integration with Nephio Pipeline

```bash
# Apply policies before deploying Nephio components
kubectl apply -f guardrails/sigstore/policies/
kubectl apply -f guardrails/kyverno/policies/

# Label Nephio namespaces appropriately
kubectl label namespace nephio-system environment=production
kubectl label namespace porch-system environment=production

# Verify Nephio images are signed or add to allowlist
kubectl get deployments -n nephio-system -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | \
  xargs -I {} cosign verify --certificate-identity-regexp ".*" \
    --certificate-oidc-issuer-regexp ".*" {} || echo "Image {} not signed"
```

## Additional Resources

- [Sigstore Policy Controller Documentation](https://docs.sigstore.dev/policy-controller/overview/)
- [Kyverno Policy Library](https://kyverno.io/policies/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [SLSA Framework](https://slsa.dev/)
- [Supply Chain Security Best Practices](https://www.cncf.io/blog/2022/08/08/supply-chain-security-best-practices/)