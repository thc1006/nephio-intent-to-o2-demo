# Kyverno Image Verification Policies

Alternative implementation of container image signature enforcement using Kyverno admission controller, demonstrating TDD approach with initial test failures.

## Mission

Provide a Kubernetes-native alternative to Sigstore policy-controller for image signature verification. Validates signatures using Kyverno's verifyImages feature with support for both keyless and key-based verification.

## Quick Start (TDD Approach)

```bash
# 1. RED PHASE: Run tests first (will FAIL)
make test
# Expected: Tests show wrong results - policies need tuning

# 2. Install Kyverno CLI for testing
make install-cli

# 3. Install Kyverno in cluster (if not already installed)  
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.11.0/install.yaml

# 4. GREEN PHASE: Apply and tune policies
make apply

# 5. REFACTOR: Run tests again and adjust policies
make test
make validate
```

## Policy Architecture

### verify-images.yaml Structure:

1. **ClusterPolicy Configuration:**
   - `validationFailureAction: Enforce` - Blocks violations
   - `background: false` - Real-time admission control only  
   - `failurePolicy: Fail` - Secure by default
   - `webhookTimeoutSeconds: 30` - Reasonable timeout

2. **Rule Matching:**
   - Targets: Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob
   - Namespace exclusion for dev and system namespaces
   - Uses `matchExpressions` for flexible namespace selection

3. **Image Verification:**
   - Supports multiple attestor configurations
   - Key-based verification with public keys  
   - Keyless verification for trusted issuers
   - Rekor transparency log integration
   - Digest mutation and verification

## Testing Infrastructure

### Kyverno CLI Testing:
- `kyverno-test.yaml`: Test definition with expected outcomes
- `resource.yaml`: Pod resources with unsigned images
- Tests validate policy behavior across namespaces

### Test Matrix:
```
Resource              | Namespace  | Expected Result
test-unsigned-pod     | production | FAIL (unsigned)  
test-dev-pod          | dev        | SKIP (exempt)
```

### Current TDD RED State:
The tests intentionally show failures, demonstrating:
- Unsigned images passing when they should fail
- Namespace exemptions not working correctly  
- Policy rules needing refinement

## Verification Examples

```bash
# Test policy locally without cluster
make test

# Validate policy syntax  
make validate

# Check live policy status
kubectl get clusterpolicy verify-images
kubectl describe clusterpolicy verify-images

# Monitor policy violations
kubectl get events --field-selector reason=PolicyViolation
```

## Troubleshooting

### Common Issues:
- **want fail, got pass**: Policy not restrictive enough, check image references
- **want skip, got fail**: Namespace selector not matching dev environment
- **webhook timeout**: Increase timeout or optimize policy complexity

### Debug Commands:
```bash
# Check Kyverno installation
kubectl get pods -n kyverno

# View policy reports  
kubectl get clusterpolicyreport
kubectl get policyreport -A

# Test specific image
kyverno apply policies/verify-images.yaml --resource=test-pod.yaml
```

## Policy Tuning Guide

### Making Policies More Restrictive:
- Change `validationFailureAction` from `Audit` to `Enforce`
- Remove namespace exemptions
- Add additional signature requirements

### Adding New Signature Sources:
```yaml
- count: 1
  entries:
  - keys:
      publicKeys: |
        -----BEGIN PUBLIC KEY-----
        [Your registry's public key]
        -----END PUBLIC KEY-----
      rekor:
        url: https://rekor.sigstore.dev
```

## Production Considerations

- [ ] Replace placeholder public keys with production keys
- [ ] Configure proper keyless OIDC providers
- [ ] Set up policy violation monitoring and alerting  
- [ ] Test impact on deployment pipelines
- [ ] Plan emergency policy bypass procedures
- [ ] Integrate with existing admission controllers

## Comparison with Sigstore Policy-Controller

| Feature | Kyverno | Policy-Controller |
|---------|---------|-------------------|
| K8s Native | ✅ Full CRD support | ✅ Specialized for images |
| Rule Flexibility | ✅ Rich matching | ⚠️ Image-focused |
| Multi-policy | ✅ Combine with other rules | ⚠️ Image verification only |
| Performance | ⚠️ General purpose overhead | ✅ Optimized for images |
| Community | ✅ Large CNCF project | ✅ Sigstore ecosystem |

## Integration with Intent Pipeline

This component provides:
- Kubernetes-native policy enforcement for image signatures
- Alternative verification path for Sigstore policy-controller
- Rich policy reporting and audit capabilities  
- Integration with existing Kyverno policy suites
- GitOps-friendly policy-as-code management

Supports CLAUDE.md requirements: default-on security, explicit validation, and deterministic behavior through clear pass/fail results.