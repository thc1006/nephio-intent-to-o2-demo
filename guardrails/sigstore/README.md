# Sigstore Policy Controller

Enforces container image signatures using Sigstore policy-controller.

## Quick Start (TDD Approach)

```bash
# 1. Run tests first (will FAIL - RED phase)
make test

# 2. Install cosign CLI
make install-cosign

# 3. Install policy-controller in cluster
make install-policy-controller

# 4. Apply policies (GREEN phase)
make apply

# 5. Run tests again (should PASS)
make test
```

## Policy Details

- **cluster-image-policy.yaml**: Defines image verification rules
  - Rejects unsigned images in production namespaces
  - Supports keyless signatures (e.g., distroless images)
  - Supports key-based signatures with custom public keys
  - Excludes dev and system namespaces from enforcement

## Testing

- `test-unsigned-deployment.yaml`: Should be rejected (unsigned nginx)
- `test-signed-deployment.yaml`: Should be accepted (signed distroless)
- `verify-policy.sh`: Automated test script

## Verification Examples

```bash
# Verify a signed image
make verify-signature

# Check specific image
cosign verify gcr.io/distroless/static:nonroot \
  --certificate-identity=keyless@distroless.iam.gserviceaccount.com \
  --certificate-oidc-issuer=https://accounts.google.com
```

## Security Notes

- Replace placeholder public keys with your registry's signing keys
- Configure proper OIDC issuer for keyless signing
- Enable webhook failure policy for strict enforcement
- Monitor policy-controller logs for violations