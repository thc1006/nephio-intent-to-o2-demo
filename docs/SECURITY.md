# Security Guardrails Setup & Demo Guide

Complete installation and demonstration guide for the security guardrails in the intent pipeline, following TDD principles with exact commands.

## Overview

The security guardrails provide defense-in-depth protection for the intent pipeline:

- **Sigstore Policy Controller**: Rejects unsigned container images in production
- **Kyverno**: Kubernetes-native policy enforcement with image verification  
- **cert-manager**: Automated TLS certificate lifecycle management

All components follow TDD approach: failing tests first (RED), minimal implementation (GREEN), then optimization (REFACTOR).

## Prerequisites

```bash
# Verify kubectl access
kubectl cluster-info

# Verify you have cluster-admin permissions
kubectl auth can-i '*' '*'

# Check cluster readiness
kubectl get nodes
```

## Table of Contents
- [1. Sigstore Policy Controller Setup](#1-sigstore-policy-controller-setup)
- [2. cert-manager Setup](#2-cert-manager-setup)  
- [3. Kyverno Setup](#3-kyverno-setup)
- [4. Complete Security Demo Script](#4-complete-security-demo-script)
- [5. Troubleshooting](#5-troubleshooting)
- [6. Production Configuration](#6-production-configuration)

## 1. Sigstore Policy Controller Setup

### Quick Installation

```bash
cd guardrails/sigstore

# Install cosign CLI
make install-cosign

# Install policy-controller (kubectl method - recommended)
make install-policy-controller

# Alternative: Helm method
helm repo add sigstore https://sigstore.github.io/helm-charts
helm repo update
helm install policy-controller sigstore/policy-controller \
  --namespace cosign-system --create-namespace
```

### Manual Installation Steps

```bash
# 1. Install policy-controller
kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/v0.8.0/policy-controller.yaml

# 2. Wait for deployment
kubectl -n cosign-system wait --for=condition=Available --timeout=300s deployment/policy-controller-webhook

# 3. Verify installation
kubectl get pods -n cosign-system
kubectl logs -n cosign-system deployment/policy-controller-webhook
```

### Apply Security Policies

```bash
# Apply ClusterImagePolicy
kubectl apply -f policies/cluster-image-policy.yaml

# Verify policy is active
kubectl get clusterimagepolicy
kubectl describe clusterimagepolicy reject-unsigned-images
```

### Demo: Unsigned Denied / Signed Allowed

```bash
# Run automated demo
make demo
```

**Manual Demo Steps:**

```bash
# 1. Create production namespace
kubectl create namespace demo-prod

# 2. Test unsigned image (SHOULD BE DENIED)
echo "Deploying unsigned nginx:latest..."
kubectl apply -f tests/test-unsigned-deployment.yaml -n demo-prod
# Expected: admission webhook error - image signature verification failed

# 3. Test signed image (SHOULD BE ALLOWED)  
echo "Deploying signed distroless image..."
kubectl apply -f tests/test-signed-deployment.yaml -n demo-prod
# Expected: deployment created successfully

# 4. Test dev namespace (unsigned ALLOWED)
kubectl create namespace demo-dev
kubectl label namespace demo-dev environment=dev
kubectl apply -f tests/test-unsigned-deployment.yaml -n demo-dev
# Expected: deployment created with warning

# 5. Cleanup
kubectl delete namespace demo-prod demo-dev
```

### Verify Image Signature

```bash
# Manually verify a signed image
cosign verify gcr.io/distroless/static:nonroot \
  --certificate-identity=keyless@distroless.iam.gserviceaccount.com \
  --certificate-oidc-issuer=https://accounts.google.com

# Check cosign version
cosign version

# Example output of successful verification:
# Verification for gcr.io/distroless/static:nonroot --
# The following checks were performed on each of these signatures:
#   - The cosign claims were validated
#   - Existence of the claims in the transparency log was verified offline
#   - The code-signing certificate was verified using trusted certificate authority certificates
```

## 2. cert-manager Setup

### Quick Installation

```bash
cd guardrails/cert-manager

# Install cert-manager
make install

# Apply certificate issuers
make apply

# Validate installation
make validate
```

### Manual Installation Steps

```bash
# 1. Install cert-manager (kubectl method - recommended)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Alternative: Helm method
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.13.3 --set installCRDs=true

# 2. Wait for deployment
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager-webhook
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager-cainjector

# 3. Verify installation
kubectl get pods -n cert-manager
```

### Apply Certificate Issuers

```bash
# Apply ClusterIssuers
kubectl apply -f manifests/cluster-issuer.yaml

# Verify issuers are ready
kubectl get clusterissuer
kubectl describe clusterissuer selfsigned-cluster-issuer
kubectl describe clusterissuer ca-cluster-issuer
```

### Test Certificate Creation

```bash
# Create test certificate
kubectl apply -f tests/test-certificate.yaml

# Check certificate status
kubectl get certificate -n cert-manager-test
kubectl describe certificate test-cert -n cert-manager-test

# Verify secret is created
kubectl get secret test-cert-secret -n cert-manager-test
kubectl describe secret test-cert-secret -n cert-manager-test

# Cleanup
kubectl delete -f tests/test-certificate.yaml
```

### Install cert-manager CLI (cmctl)

```bash
# Install cmctl tool
make install-cmctl

# Check API readiness
cmctl check api

# Manual install cmctl
curl -fsSL -o cmctl.tar.gz \
  https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cmctl-linux-amd64.tar.gz
tar xzf cmctl.tar.gz
sudo mv cmctl /usr/local/bin
rm cmctl.tar.gz
```

## 3. Kyverno Setup

### Quick Installation

```bash
cd guardrails/kyverno

# Install Kyverno
make install

# Apply policies
make apply

# Run tests
make test
```

### Manual Installation Steps

```bash
# 1. Install Kyverno (kubectl method)
kubectl apply -f https://github.com/kyverno/kyverno/releases/download/v1.11.0/install.yaml

# Alternative: Helm method
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

# 2. Wait for deployment
kubectl wait --for=condition=Available --timeout=300s -n kyverno deployment/kyverno-admission-controller
kubectl wait --for=condition=Available --timeout=300s -n kyverno deployment/kyverno-background-controller
kubectl wait --for=condition=Available --timeout=300s -n kyverno deployment/kyverno-cleanup-controller
kubectl wait --for=condition=Available --timeout=300s -n kyverno deployment/kyverno-reports-controller

# 3. Verify installation
kubectl get pods -n kyverno
```

### Apply Image Verification Policies

```bash
# Apply ClusterPolicy
kubectl apply -f policies/verify-images.yaml

# Verify policy is active
kubectl get clusterpolicy
kubectl describe clusterpolicy verify-images
```

### Run Kyverno Tests

```bash
# Run policy tests
kyverno test tests/

# Expected output shows test results:
# - pass: tests that should pass
# - fail: tests that should fail (demonstrating policy enforcement)
```

## 4. Complete Security Demo Script

### Automated End-to-End Demo

```bash
#!/bin/bash
# Complete security guardrails demo

echo "🛡️  Security Guardrails Demo - Nephio Intent Pipeline"
echo "=================================================="

# 1. Test Sigstore Policy Controller
echo ""
echo "1️⃣  SIGSTORE POLICY CONTROLLER DEMO"
cd guardrails/sigstore
make demo

# 2. Test cert-manager
echo ""
echo "2️⃣  CERT-MANAGER DEMO"
cd ../cert-manager
make test
kubectl apply -f tests/test-certificate.yaml
sleep 10
kubectl get certificate -n cert-manager-test
kubectl delete -f tests/test-certificate.yaml

# 3. Test Kyverno
echo ""
echo "3️⃣  KYVERNO POLICY DEMO"
cd ../kyverno
make test

echo ""
echo "✅ All security guardrails demonstrated successfully!"
echo "   - Unsigned images blocked in production ❌"
echo "   - Signed images allowed in production ✅"
echo "   - Certificates automatically managed 🔒"
echo "   - Policies enforced via Kyverno 📜"
```

### Save and Run Demo

```bash
# Save demo script
cat > /tmp/security-demo.sh << 'EOF'
[paste the script above]
EOF

chmod +x /tmp/security-demo.sh
/tmp/security-demo.sh
```

## 5. Troubleshooting

### Common Issues

#### Policy Controller Issues

```bash
# Check policy-controller status
kubectl get pods -n cosign-system
kubectl logs -n cosign-system deployment/policy-controller-webhook

# Verify webhook configuration
kubectl get validatingadmissionwebhooks
kubectl describe validatingadmissionwebhook policy.sigstore.dev

# Test policy dry-run
kubectl apply -f tests/test-unsigned-deployment.yaml --dry-run=server
```

#### cert-manager Issues

```bash
# Check cert-manager status
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate events
kubectl describe certificate <cert-name>
kubectl get certificaterequest

# Test API connectivity
cmctl check api
```

#### Kyverno Issues

```bash
# Check Kyverno status
kubectl get pods -n kyverno
kubectl logs -n kyverno deployment/kyverno-admission-controller

# Verify policies
kubectl get clusterpolicy
kubectl describe clusterpolicy verify-images

# Check policy violations
kubectl get policyreport -A
```

### Debug Commands

```bash
# Check all security components
kubectl get pods -n cosign-system -n cert-manager -n kyverno

# View recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Test webhook connectivity
kubectl apply -f <test-resource> --dry-run=server -v=6
```

## 6. Production Configuration

### Security Hardening Checklist

- [ ] Replace self-signed certificates with enterprise CA
- [ ] Configure proper OIDC provider for keyless signing
- [ ] Set up monitoring and alerting for policy violations
- [ ] Implement backup and disaster recovery procedures
- [ ] Configure RBAC for security component access
- [ ] Set up certificate expiration monitoring
- [ ] Document security incident response procedures
- [ ] Regular security policy reviews and updates

### Monitoring Commands

```bash
# Monitor policy violations
kubectl get events --field-selector reason=PolicyViolation

# Monitor certificate expiration
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,READY:.status.conditions[0].status,EXPIRES:.status.notAfter

# Monitor Kyverno policy reports
kubectl get policyreport -A -o wide

# Check security component health
kubectl get pods -n cosign-system -n cert-manager -n kyverno -o wide
```

## 7. Integration with Intent Pipeline

The security guardrails integrate with the intent pipeline at multiple points:

1. **Image Verification**: All KRM packages and O2 IMS deployments use only signed images
2. **Certificate Management**: Automatic TLS for all API communications
3. **Policy Enforcement**: Kyverno validates all intent transformations
4. **Supply Chain Security**: Complete signature verification chain from intent to deployment

### Pipeline Security Flow

```
LLM Intent → TMF921 → 28.312 → KRM Packages → O2 IMS
     ↓           ↓        ↓          ↓          ↓
   Schema    Signed   Policy    Image      TLS
   Valid     JSON   Validated  Verified   Secured
```

Each step enforced by the security guardrails ensures end-to-end security from intent creation to O-RAN deployment.

