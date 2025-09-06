# Kyverno Image Verification Policies

Enforces container image signature verification using Kyverno.

## Quick Start (TDD Approach)

```bash
# 1. Run tests first (will FAIL - RED phase)
make test

# 2. Install Kyverno CLI for testing
make install-cli

# 3. Install Kyverno in cluster (if not already installed)
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.11.0/install.yaml

# 4. Apply policies (GREEN phase)
make apply

# 5. Run tests again (should PASS)
make test
```

## Policy Details

- **verify-images.yaml**: Enforces image signature verification
  - Blocks unsigned images in production namespaces
  - Allows unsigned images in dev namespace
  - Exempts system namespaces (kube-system, cert-manager, etc.)

## Testing

Tests use the Kyverno CLI to validate policies against test resources:
- `test-values.yaml`: Defines expected test outcomes
- `resource.yaml`: Test pods with unsigned images
- Tests verify that unsigned images are rejected in production but allowed in dev

## Security Notes

- Replace placeholder public keys with your actual signing keys
- Configure Rekor URL for transparency log verification
- Use admission controller mode for real-time enforcement