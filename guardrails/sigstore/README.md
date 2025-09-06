# Sigstore Policy Controller

Enforces container image signatures using Sigstore policy-controller, following TDD approach with failing tests first.

## Mission

Reject unsigned container images in production namespaces while allowing signed images and exempting development environments. This ensures only verified, trusted images run in production workloads.

## Quick Start (TDD Approach)

```bash
# 1. RED PHASE: Run tests first (will FAIL)
make test
# Expected: Tests fail showing policies need implementation

# 2. Install required tools
make install-cosign
make install-policy-controller

# 3. GREEN PHASE: Apply policies 
make apply

# 4. Run demo (unsigned denied / signed allowed)
make demo

# 4. Run tests again (should PASS)
make test
```

## Policy Configuration

### cluster-image-policy.yaml Components:

1. **reject-unsigned-images**: Main enforcement policy
   - Matches all images with `glob: "**"`
   - Requires signatures from trusted authorities
   - Uses `enforce` mode to block unsigned images
   - Supports both keyless and key-based verification

2. **allow-unsigned-dev**: Development exemption policy  
   - Targets namespaces labeled `environment: dev`
   - Uses `warn` mode (logs but doesn't block)
   - Empty authorities list allows all images

3. **policy-controller-config**: Webhook configuration
   - Excludes system namespaces from checks
   - Sets default behavior for unmatched policies

### Supported Signature Types:

- **Keyless signatures**: Google distroless images, GitHub Actions
- **Key-based signatures**: Custom public keys for private registries
- **Rekor transparency log**: All signatures verified against public ledger

## Testing Infrastructure

### Test Cases:
- `test-unsigned-deployment.yaml`: nginx:latest (should FAIL in production)
- `test-signed-deployment.yaml`: gcr.io/distroless/static:nonroot (should PASS)
- `verify-policy.sh`: Automated test runner with colored output

### Test Scenarios:
1. **Production namespace**: Unsigned images rejected ❌
2. **Production namespace**: Signed images accepted ✅  
3. **Dev namespace**: Unsigned images allowed ⚠️

## Verification Commands

```bash
# Verify a known signed image
make verify-signature

# Manual verification with cosign
cosign verify gcr.io/distroless/static:nonroot \
  --certificate-identity=keyless@distroless.iam.gserviceaccount.com \
  --certificate-oidc-issuer=https://accounts.google.com

# Check policy-controller status
kubectl get pods -n cosign-system
kubectl logs -n cosign-system deployment/policy-controller-webhook
```

## Troubleshooting

### Common Issues:
- **Tests pass when they should fail**: Policy-controller not installed or policies not applied
- **Signed images rejected**: Check certificate identity and OIDC issuer configuration
- **Webhook timeouts**: Increase webhook timeout in policy configuration

### Debug Commands:
```bash
# Check policy status
kubectl get clusterimagepolicy

# View policy events
kubectl get events --all-namespaces | grep policy-controller

# Test dry-run deployment
kubectl apply -f tests/test-unsigned-deployment.yaml --dry-run=server
```

## Production Checklist

- [ ] Replace placeholder public key with actual signing key
- [ ] Configure proper OIDC provider for keyless signing
- [ ] Set up monitoring and alerting for policy violations
- [ ] Document approved base images and signing process
- [ ] Test emergency override procedures
- [ ] Configure backup webhook admission controllers

## Integration with Intent Pipeline

This component ensures:
- KRM packages use only verified container images
- O2 IMS deployments comply with image security policies  
- GitOps deployments automatically validate image signatures
- Intent transformations cannot introduce unsigned images

Follows CLAUDE.md security principles: default-on security, fail-closed behavior, and transparency through Rekor logs.