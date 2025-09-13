# Supply Chain Security Policy

## Overview

This document defines the security policy for container images and Kubernetes manifests in this environment. We implement supply chain security through validation and verification tools to ensure the integrity and compliance of deployed resources.

## Policy Components

### 1. Manifest Validation (Kubeconform)

All Kubernetes YAML manifests MUST pass validation before deployment.

**Requirements:**
- Valid Kubernetes resource definitions
- Compliance with API schema for target Kubernetes version (1.27.0)
- Strict mode enabled by default

**Enforcement:**
```bash
# Validate single file
~/dev/conform.sh manifest.yaml

# Validate directory recursively
~/dev/conform.sh /path/to/manifests/

# Custom Kubernetes version
KUBERNETES_VERSION=1.28.0 ~/dev/conform.sh .
```

### 2. Container Image Verification (Cosign)

Container images SHOULD be cryptographically signed and verified.

**Policy Modes:**

| Mode | Unsigned Images | Verification Failed | Build/Deploy |
|------|----------------|-------------------|--------------|
| `warn` (default) | ⚠️ Warning | ❌ Error | ✅ Continue |
| `block` | ❌ Error | ❌ Error | ❌ Stop |

**Configuration:**
```bash
# Warning mode (default)
POLICY=warn ~/dev/verify-images.sh

# Blocking mode (strict)
POLICY=block ~/dev/verify-images.sh

# Extract and verify from YAML
~/dev/verify-images.sh /path/to/manifests/
```

## Security Requirements

### Minimum Requirements (warn mode)

1. **Manifest Validation**
   - All YAML files must be valid Kubernetes resources
   - Must conform to Kubernetes API schema
   - CRDs must have proper API versions

2. **Image Verification**
   - All images should be scanned for signatures
   - Unsigned images generate warnings
   - Failed verifications are logged

3. **Supply Chain Attestation**
   - Record all images used in deployments
   - Maintain verification audit trail
   - Document exceptions

### Strict Requirements (block mode)

1. **Mandatory Signing**
   - ALL container images MUST be signed
   - Signatures MUST be verifiable via Cosign
   - No unsigned images allowed in production

2. **Verification Gates**
   - Pre-deployment verification required
   - CI/CD pipeline integration mandatory
   - Automated policy enforcement

3. **Compliance Tracking**
   - All verifications logged
   - Failed verifications block deployment
   - Regular audit reports

## Implementation

### Local Development

```bash
# Run both validations
make conform     # Validate manifests
make verify      # Verify images

# Or run individually
~/dev/conform.sh ./manifests/
~/dev/verify-images.sh images.txt
```

### CI/CD Integration

```yaml
# Example GitHub Actions
- name: Validate Manifests
  run: make conform

- name: Verify Images
  env:
    POLICY: block
  run: make verify
```

### GitOps Integration

Before syncing to clusters:
1. Validate all manifests with kubeconform
2. Extract and verify all container images
3. Block sync if policy violations detected

## Image Signing Guide

### Sign Your Images

```bash
# Generate key pair (first time)
cosign generate-key-pair

# Sign an image
cosign sign --key cosign.key image:tag

# Sign with keyless (recommended)
COSIGN_EXPERIMENTAL=1 cosign sign image:tag
```

### Verify Images

```bash
# Verify with public key
cosign verify --key cosign.pub image:tag

# Verify keyless signatures
COSIGN_EXPERIMENTAL=1 cosign verify image:tag
```

## Exceptions

### Approved Unsigned Images

Some system images may not be signed. Document exceptions here:

1. **Local Development Images**
   - busybox:latest (development only)
   - Local test images (non-production)

2. **Legacy System Images**
   - Document with justification
   - Plan for migration

### Override Procedures

```bash
# Temporary override for development
POLICY=warn ~/dev/verify-images.sh

# Skip specific validations
SKIP_VERIFY=true make deploy
```

## Monitoring and Alerts

### Metrics to Track

1. **Validation Metrics**
   - Pass/fail rate for manifests
   - Common validation errors
   - Time to validate

2. **Verification Metrics**
   - Percentage of signed images
   - Verification failures
   - Policy violations

3. **Compliance Score**
   - Overall security posture
   - Trend over time
   - Risk assessment

## Incident Response

### When Verification Fails

1. **Immediate Actions**
   - Block deployment (if policy=block)
   - Alert security team
   - Log incident details

2. **Investigation**
   - Identify image source
   - Check signing authority
   - Verify supply chain

3. **Remediation**
   - Re-sign valid images
   - Update from verified source
   - Document resolution

## Tools and Resources

### Required Tools

| Tool | Purpose | Version | Installation |
|------|---------|---------|--------------|
| kubeconform | Manifest validation | 0.6.3+ | Auto-installed by conform.sh |
| cosign | Image signatures | 2.2.2+ | Auto-installed by verify-images.sh |
| kubectl | Cluster interaction | 1.27+ | Pre-installed |

### References

- [Kubeconform Documentation](https://github.com/yannh/kubeconform)
- [Cosign Documentation](https://docs.sigstore.dev/cosign)
- [SLSA Framework](https://slsa.dev/)
- [Supply Chain Security](https://www.cncf.io/blog/2021/08/11/supply-chain-security/)

## Policy Updates

This policy should be reviewed and updated:
- Quarterly for regular updates
- Immediately after security incidents
- When new tools become available
- Based on compliance requirements

---

**Policy Version:** 1.0.0  
**Effective Date:** 2025-09-07  
**Next Review:** 2025-12-07  
**Owner:** Security Team  
**Classification:** Internal