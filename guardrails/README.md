# Security Guardrails

Minimal but enforceable security policies for the intent pipeline, following TDD approach.

## Components

### 1. Sigstore Policy Controller
- Enforces container image signatures
- Rejects unsigned images in production namespaces
- Supports keyless and key-based verification

### 2. Kyverno Policies
- Image signature verification with Kyverno
- Namespace-based policy enforcement
- Integration with admission controllers

### 3. Cert-Manager
- TLS certificate lifecycle management
- Self-signed ClusterIssuer for testing
- Foundation for mTLS and webhook certificates

## TDD Workflow

Each component follows Test-Driven Development:

1. **RED Phase**: Tests written first, fail due to missing policies
2. **GREEN Phase**: Minimal policies implemented to pass tests
3. **REFACTOR Phase**: Optimize and enhance policies as needed

## Quick Start

```bash
# Run all tests (will fail initially)
for dir in sigstore kyverno cert-manager; do
  echo "Testing $dir..."
  cd $dir && make test && cd ..
done

# Install components
cd cert-manager && make install && make apply && cd ..
cd sigstore && make install-policy-controller && make apply && cd ..
cd kyverno && make apply && cd ..

# Run tests again (should pass)
for dir in sigstore kyverno cert-manager; do
  echo "Testing $dir..."
  cd $dir && make test && cd ..
done
```

## Security Principles

1. **Default Deny**: Unsigned images rejected by default
2. **Namespace Isolation**: Dev environments exempt from strict policies
3. **Fail Closed**: Webhook failures block deployments
4. **Transparency**: All signatures verified against Rekor logs
5. **Certificate Automation**: No manual certificate management

## Integration with Intent Pipeline

These guardrails ensure:
- Only verified KRM packages are deployed
- Intent transformations use signed container images
- O2 IMS communications use proper TLS certificates
- GitOps deployments verify image signatures

## Production Checklist

- [ ] Replace placeholder signing keys with production keys
- [ ] Configure OIDC provider for keyless signing
- [ ] Set up proper CA issuer instead of self-signed
- [ ] Enable policy violation alerts
- [ ] Configure backup and recovery for certificates
- [ ] Implement certificate rotation automation
- [ ] Set up monitoring dashboards for policy violations