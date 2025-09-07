# Security Policy & Supply Chain Hardening

Complete security policy documentation and supply chain hardening guide for the Nephio Intent-to-O2 demo, following security-by-default principles with comprehensive validation and enforcement.

## Table of Contents
- [Security Policy Overview](#security-policy-overview)
- [Container Registry Policy](#container-registry-policy)  
- [Image Signature Verification](#image-signature-verification)
- [Security Enforcement Levels](#security-enforcement-levels)
- [Incident Response Procedures](#incident-response-procedures)
- [Security Guardrails Implementation](#security-guardrails-implementation)
- [Comprehensive Security Reporting](#comprehensive-security-reporting)
- [Development vs Production Security](#development-vs-production-security)
- [Integration with Intent Pipeline](#integration-with-intent-pipeline)

## Security Policy Overview

The Nephio Intent-to-O2 demo implements a comprehensive security-by-default approach with multiple layers of protection:

### Security Principles
1. **Zero Trust**: No implicit trust for any component or image
2. **Supply Chain Security**: Complete signature verification from intent to deployment  
3. **Defense in Depth**: Multiple overlapping security controls
4. **Fail Secure**: Security failures block deployment by default
5. **Continuous Validation**: Ongoing security assessment and reporting
6. **Least Privilege**: Minimal permissions and access rights

### Security Architecture
```
Intent Creation → TMF921 → 28.312 → KRM Packages → O2 IMS → Deployment
      ↓             ↓        ↓          ↓          ↓         ↓
   Schema       Signed    Policy     Image      TLS      Runtime
   Valid        JSON    Validated   Verified   Secured   Secured
```

## Container Registry Policy

### Allowed Container Registries

**Production Environments:**
- `gcr.io` - Google Container Registry (signed images only)
- `ghcr.io` - GitHub Container Registry (signed images only)  
- `registry.k8s.io` - Kubernetes official registry (signed images only)
- `quay.io` - Red Hat Quay registry (signed images only)

**Development Environments (additional allowlist):**
- `docker.io/library` - Docker Hub official images (signature verification recommended)
- `docker.io/nephio` - Nephio project images (signature verification recommended)
- `docker.io/oransc` - O-RAN Software Community images (signature verification recommended)

### Registry Configuration

Environment variables for registry control:
```bash
# Production configuration
export ALLOWED_REGISTRIES="gcr.io,ghcr.io,registry.k8s.io,quay.io"
export SECURITY_POLICY_LEVEL="strict"
export ALLOW_UNSIGNED="false"

# Development configuration  
export ALLOWED_REGISTRIES="gcr.io,ghcr.io,registry.k8s.io,quay.io,docker.io/library,docker.io/nephio,docker.io/oransc"
export SECURITY_POLICY_LEVEL="permissive"
export ALLOW_UNSIGNED="true"
```

### Registry Validation Process

1. **Image Extraction**: Scan all YAML manifests in packages/, samples/, guardrails/, manifests/
2. **Registry Matching**: Validate each image against allowed registry list
3. **Policy Enforcement**: Block deployment if unauthorized registries detected
4. **Reporting**: Generate detailed violation reports with remediation guidance

## Image Signature Verification

### Cosign Integration

The demo uses [Sigstore cosign](https://docs.sigstore.dev/cosign/system_config/installation/) for image signature verification:

#### Installation
```bash
# Automatic installation in CI environments
export AUTO_INSTALL_COSIGN=true

# Manual installation
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```

#### Signature Verification Process
1. **Image Discovery**: Extract all container images from manifests
2. **Parallel Verification**: Verify signatures using configurable parallelism
3. **Timeout Handling**: Configurable timeout to prevent hanging verifications
4. **Result Aggregation**: Collect signed/unsigned/error status for all images

#### Configuration
```bash
export COSIGN_TIMEOUT=30          # Verification timeout (seconds)
export PARALLEL_SCANS=4           # Parallel verification processes
export COSIGN_REQUIRED=true       # Fail on missing signatures (production)
```

### Signature Verification Examples

**Verify signed distroless image:**
```bash
cosign verify gcr.io/distroless/static:nonroot \
  --certificate-identity=keyless@distroless.iam.gserviceaccount.com \
  --certificate-oidc-issuer=https://accounts.google.com
```

**Expected output for signed image:**
```
Verification for gcr.io/distroless/static:nonroot --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates
```

## Security Enforcement Levels

### Strict Mode (Production)
- **Policy Level**: `SECURITY_POLICY_LEVEL=strict`
- **Unsigned Images**: Blocked (`ALLOW_UNSIGNED=false`)
- **Registry Violations**: Deployment blocked
- **YAML Validation**: Must pass kubeconform
- **Compliance Threshold**: 90+ score required
- **Signature Verification**: Required for all images

### Permissive Mode (Development)  
- **Policy Level**: `SECURITY_POLICY_LEVEL=permissive`
- **Unsigned Images**: Allowed with warnings (`ALLOW_UNSIGNED=true`)
- **Registry Violations**: Warnings only
- **YAML Validation**: Warnings for validation issues
- **Compliance Threshold**: 60+ score required
- **Signature Verification**: Recommended but not required

### Demo Mode (Testing)
- **Policy Level**: `SECURITY_POLICY_LEVEL=demo`
- **Unsigned Images**: Allowed
- **Registry Violations**: Logged only  
- **YAML Validation**: Best effort
- **Compliance Threshold**: No threshold
- **Signature Verification**: Optional

## Incident Response Procedures

### Security Violation Response

**1. Immediate Actions**
- Deployment automatically blocked by security precheck
- Security incident logged with timestamp and details
- Notification sent to security team (if configured)
- Rollback initiated if violation detected post-deployment

**2. Investigation Process**
- Review security report in `reports/security-YYYYMMDD.json`
- Identify specific violation type and affected components
- Assess impact and determine remediation steps
- Document findings and lessons learned

**3. Remediation Steps**
- Replace unsigned images with signed equivalents
- Move images to approved registries
- Fix YAML manifest validation errors
- Update CI/CD pipeline to prevent recurrence

### Security Incident Classification

**Critical (Score < 60)**
- Unsigned images in production
- Images from unapproved registries
- Invalid Kubernetes manifests
- Policy violations in strict mode

**High (Score 60-74)**
- Multiple unsigned images in development
- Registry violations with approved exceptions
- YAML validation warnings

**Medium (Score 75-89)**  
- Few unsigned images with justification
- Minor policy compliance issues
- Missing signature verification in development

**Low (Score 90+)**
- All requirements met
- Best practices followed
- Complete compliance

## Security Guardrails Implementation

### Sigstore Policy Controller Setup

**Installation:**
```bash
cd guardrails/sigstore
make install-cosign
make install-policy-controller
```

**Policy Application:**
```bash
kubectl apply -f policies/cluster-image-policy.yaml
kubectl get clusterimagepolicy
```

**Demo Verification:**
```bash
# Test unsigned image (should be denied)
kubectl apply -f tests/test-unsigned-deployment.yaml -n demo-prod

# Test signed image (should be allowed)
kubectl apply -f tests/test-signed-deployment.yaml -n demo-prod
```

### cert-manager Setup

**Installation:**
```bash
cd guardrails/cert-manager
make install
make apply
make validate
```

**Certificate Verification:**
```bash
kubectl get certificate -A
kubectl describe certificate test-cert -n cert-manager-test
```

### Kyverno Policy Enforcement

**Installation:**
```bash
cd guardrails/kyverno
make install
make apply
make test
```

**Policy Validation:**
```bash
kubectl get clusterpolicy
kubectl describe clusterpolicy verify-images
kyverno test tests/
```

## Comprehensive Security Reporting

### Security Report Generation

The security reporting system provides comprehensive analysis of the entire supply chain:

**Generate Full Report:**
```bash
make security-report
```

**Development Mode:**
```bash
make security-report-dev
```

**Strict Production Mode:**
```bash
make security-report-strict
```

### Report Structure

Security reports are generated in JSON format at `reports/security-YYYYMMDD.json`:

```json
{
  "security_report": {
    "metadata": {
      "timestamp": "2024-01-15T10:30:00Z",
      "version": "1.0.0",
      "git": {
        "commit": "abc123",
        "branch": "main"
      }
    },
    "configuration": {
      "security_policy_level": "strict",
      "allow_unsigned": false,
      "allowed_registries": ["gcr.io", "ghcr.io"]
    },
    "summary": {
      "total_images": 15,
      "registry_violations": 0,
      "signature_issues": 2,
      "kubeconform_files": 25,
      "policy_compliance_score": 85
    },
    "findings": {
      "kubeconform_validation": [...],
      "image_signature_verification": [...],
      "registry_allowlist_violations": [...],
      "policy_compliance": {...}
    },
    "recommendations": [...]
  }
}
```

### Report Integration

Security reports are integrated into the deployment pipeline:

1. **Pre-deployment**: Generated before `publish-edge`
2. **Gate Enforcement**: Deployment blocked if compliance score < threshold
3. **Post-deployment**: Available for audit and review
4. **CI/CD Integration**: JSON format suitable for automated processing

### Viewing Reports

**Command Line Summary:**
```bash
jq -r '.security_report.summary | to_entries[] | "\(.key): \(.value)"' reports/security-latest.json
```

**Detailed Findings:**
```bash
jq '.security_report.findings' reports/security-latest.json
```

**Recommendations:**
```bash
jq -r '.security_report.recommendations[]' reports/security-latest.json
```

## Development vs Production Security

### Development Environment

**Purpose**: Enable rapid development while maintaining basic security
**Configuration**: 
```bash
export SECURITY_POLICY_LEVEL=permissive
export ALLOW_UNSIGNED=true  
export ALLOWED_REGISTRIES="gcr.io,ghcr.io,registry.k8s.io,quay.io,docker.io/library,docker.io/nephio"
```

**Characteristics**:
- Unsigned images allowed with warnings
- Broader registry allowlist
- YAML validation warnings (not failures)
- Compliance threshold: 60+

### Production Environment

**Purpose**: Maximum security for production deployments
**Configuration**:
```bash
export SECURITY_POLICY_LEVEL=strict
export ALLOW_UNSIGNED=false
export ALLOWED_REGISTRIES="gcr.io,ghcr.io,registry.k8s.io,quay.io"
```

**Characteristics**:
- All images must be signed
- Restricted registry allowlist
- YAML validation failures block deployment
- Compliance threshold: 90+

### Environment Detection

The security system can automatically detect environment context:

```bash
# Automatic environment detection
if [[ "${CI}" == "true" ]]; then
    export SECURITY_POLICY_LEVEL=strict
elif [[ "${ENVIRONMENT}" == "production" ]]; then
    export SECURITY_POLICY_LEVEL=strict
else
    export SECURITY_POLICY_LEVEL=permissive
fi
```

## Integration with Intent Pipeline

### Pipeline Security Flow

The security system integrates at multiple pipeline stages:

**1. Intent Validation**
- Schema validation for TMF921 intents
- Input sanitization and validation
- Rate limiting and authentication

**2. Transform Security**
- Signed transformation functions
- Validated conversion logic  
- Audit logging of all transformations

**3. KRM Package Security**
- kubeconform validation of all manifests
- kpt function signature verification
- Policy compliance checking

**4. O2 IMS Integration Security**
- TLS encryption for all API calls
- Authentication token validation
- Request/response integrity checking

**5. Deployment Security**
- Image signature verification
- Registry allowlist enforcement
- Runtime security policies

### Security Gates

Security gates are enforced at key pipeline stages:

**Precheck Gate** (`make precheck`):
- Change size validation
- Basic YAML validation
- Container image allowlist checking
- kpt package structure validation

**Security Report Gate** (`make security-report`):
- Comprehensive kubeconform validation
- Image signature verification
- Policy compliance assessment
- Detailed reporting and recommendations

**Deployment Gate** (`make publish-edge`):
- Security compliance score validation
- Deployment blocking on violations
- Post-deployment SLO validation
- Automatic rollback on failures

### Makefile Integration

Security is integrated throughout the Makefile:

```bash
# Basic security check before deployment
make precheck

# Comprehensive security report
make security-report

# Full deployment with security validation
make publish-edge

# Security-aware demo with validation
make demo-full
```

### Exception Process

For development and demo scenarios, security controls can be overridden:

**Development Override:**
```bash
ALLOW_UNSIGNED=true make security-report-dev
```

**Emergency Override (Production):**
```bash
SECURITY_POLICY_LEVEL=permissive EMERGENCY_OVERRIDE=true make publish-edge
```

**Note**: All overrides are logged and require justification in production environments.

## Monitoring and Alerting

### Security Metrics

Key security metrics tracked:
- Image signature verification success rate
- Registry allowlist violation count
- YAML validation failure rate
- Policy compliance score trends
- Security incident frequency

### Monitoring Setup

**Basic monitoring:**
```bash
# Monitor policy violations
kubectl get events --field-selector reason=PolicyViolation

# Monitor certificate expiration  
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRES:.status.notAfter

# Monitor Kyverno policy reports
kubectl get policyreport -A -o wide
```

**Advanced monitoring with JSON reports:**
```bash
# Track compliance scores over time
jq -r '.security_report.summary.policy_compliance_score' reports/security-*.json

# Identify trending violations
jq -r '.security_report.summary.registry_violations' reports/security-*.json | sort | uniq -c
```

### Security Health Checks

**Component Health:**
```bash
kubectl get pods -n cosign-system -n cert-manager -n kyverno -o wide
```

**Policy Status:**
```bash
kubectl get clusterimagepolicy
kubectl get clusterpolicy  
kubectl get clusterissuer
```

## Production Hardening Checklist

### Pre-Production Requirements
- [ ] Replace self-signed certificates with enterprise CA
- [ ] Configure proper OIDC provider for keyless signing
- [ ] Set up monitoring and alerting for policy violations
- [ ] Implement backup and disaster recovery procedures
- [ ] Configure RBAC for security component access
- [ ] Set up certificate expiration monitoring
- [ ] Document security incident response procedures
- [ ] Regular security policy reviews and updates
- [ ] Implement vulnerability scanning in CI/CD
- [ ] Set up security audit logging
- [ ] Configure automated security report generation
- [ ] Test incident response procedures

### Ongoing Security Operations
- [ ] Weekly security report review
- [ ] Monthly policy compliance assessment  
- [ ] Quarterly security architecture review
- [ ] Regular penetration testing
- [ ] Continuous vulnerability management
- [ ] Security awareness training
- [ ] Incident response drills
- [ ] Threat modeling updates

## Troubleshooting

### Common Issues and Solutions

**1. Cosign Verification Timeouts**
```bash
# Increase timeout
export COSIGN_TIMEOUT=60

# Reduce parallel scans
export PARALLEL_SCANS=2
```

**2. Registry Allowlist Violations**  
```bash
# Check current registry policy
echo $ALLOWED_REGISTRIES

# Add registry for development
export ALLOWED_REGISTRIES="$ALLOWED_REGISTRIES,myregistry.io"
```

**3. YAML Validation Failures**
```bash
# Check specific validation errors
kubeconform -summary -verbose manifests/problem.yaml

# Skip custom resources
kubeconform -skip=CustomResourceDefinition manifests/
```

**4. Policy Controller Issues**
```bash
# Check policy controller status
kubectl get pods -n cosign-system
kubectl logs -n cosign-system deployment/policy-controller-webhook

# Verify webhook configuration
kubectl get validatingadmissionwebhooks
```

### Debug Commands

**Security Component Status:**
```bash
# All security pods
kubectl get pods -n cosign-system -n cert-manager -n kyverno

# Recent security events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -E "(Policy|Violation|Security)"
```

**Manual Testing:**
```bash
# Test policy dry-run
kubectl apply -f tests/test-deployment.yaml --dry-run=server

# Manual image verification
cosign verify gcr.io/distroless/static:nonroot

# Test certificate creation
kubectl apply -f tests/test-certificate.yaml
```

This comprehensive security policy ensures the Nephio Intent-to-O2 demo maintains the highest security standards while providing flexibility for development and demonstration scenarios.