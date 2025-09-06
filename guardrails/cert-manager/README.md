# Cert-Manager Certificate Automation

Provides automated TLS certificate lifecycle management for the intent pipeline, following TDD approach with initial test failures that guide proper installation.

## Mission

Automate certificate provisioning, renewal, and management for all components in the intent pipeline including O2 IMS communications, webhook certificates, and internal service mesh TLS.

## Quick Start (TDD Approach)

```bash
# 1. RED PHASE: Run tests first (will FAIL)
make test
# Expected: Tests fail because cert-manager not installed

# 2. Install cert-manager in cluster
make install

# 3. GREEN PHASE: Apply certificate issuers
make apply

# 4. Run tests again (should PASS)
make test

# 5. Validate installation
make validate
```

## Architecture Components

### Installation (manifests/install.yaml):
- **cert-manager namespace**: Dedicated namespace for cert-manager
- **CRDs**: Certificate, Issuer, ClusterIssuer, CertificateRequest
- **Controller**: Watches certificate resources and manages lifecycle
- **Webhook**: Validates and mutates certificate resources
- **CA Injector**: Injects CA certificates into webhooks and admission controllers

### Certificate Issuers (manifests/cluster-issuer.yaml):

1. **selfsigned-cluster-issuer**: 
   - Bootstrap issuer for creating root certificates
   - Used for testing and development environments
   - No external dependencies

2. **ca-cluster-issuer**:
   - Uses self-generated root certificate
   - Provides consistent CA for all certificates  
   - Suitable for internal services and testing

### Test Infrastructure (tests/):
- **test-certificate.yaml**: Sample certificate request
- **verify-cert-manager.sh**: Comprehensive test script with colored output

## Testing Infrastructure

### Test Phases:
1. **CRD Installation**: Verify cert-manager CustomResourceDefinitions exist
2. **Namespace Creation**: Confirm cert-manager namespace is created
3. **Pod Readiness**: Check all cert-manager pods are running
4. **Issuer Functionality**: Verify ClusterIssuer is ready
5. **Certificate Creation**: Test actual certificate issuance

### Current TDD RED State:
Tests intentionally fail when cert-manager is not installed, demonstrating:
- Missing CRDs prevent certificate resources
- Namespace and pod checks fail without installation
- Certificate issuance impossible without functioning controllers

## Certificate Management

### Supported Certificate Types:
- **TLS Server Certificates**: HTTPS endpoints, API servers
- **Client Certificates**: mTLS authentication  
- **CA Certificates**: Root and intermediate authorities
- **Webhook Certificates**: Kubernetes admission controllers

### Automatic Renewal:
- Certificates renewed before expiration (default: 30 days)
- Zero-downtime renewals with rolling updates
- Monitoring and alerting on renewal failures

## Verification Commands

```bash
# Check cert-manager installation
make validate

# Monitor certificate status
kubectl get certificates -A
kubectl get certificaterequests -A

# Check issuer status
kubectl get clusterissuer
kubectl describe clusterissuer selfsigned-cluster-issuer

# View cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
kubectl logs -n cert-manager deployment/cert-manager-webhook
```

## Integration Examples

### Webhook Certificate:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webhook-tls
  namespace: system
spec:
  secretName: webhook-tls-secret
  issuerRef:
    name: ca-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
  - webhook.system.svc.cluster.local
```

### Service Mesh TLS:
```yaml  
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: o2ims-tls
  namespace: o2ims
spec:
  secretName: o2ims-tls-secret
  issuerRef:
    name: ca-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
  - o2ims.o2ims.svc.cluster.local
```

## Troubleshooting

### Common Issues:
- **CRDs not found**: Cert-manager installation incomplete
- **Webhook failures**: Certificate for cert-manager-webhook not ready
- **Certificate stuck Pending**: Check issuer status and logs
- **ACME challenges fail**: DNS/HTTP configuration issues

### Debug Commands:
```bash
# Check certificate events
kubectl describe certificate <cert-name>

# View certificate request details  
kubectl get certificaterequest -o yaml

# Test certificate manually
cmctl check api
cmctl status certificate <cert-name>

# Recreate failed certificate
kubectl delete certificate <cert-name>
kubectl apply -f certificate.yaml
```

## Production Migration

### From Self-Signed to Production CA:
1. **Install proper root CA certificate**
2. **Create CA-based ClusterIssuer**  
3. **Update certificate references**
4. **Rolling update all services**

### ACME/Let's Encrypt Setup:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: security@yourcompany.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

## Production Checklist

- [ ] Replace self-signed issuer with enterprise CA
- [ ] Configure backup and disaster recovery for certificates
- [ ] Set up certificate expiration monitoring
- [ ] Implement certificate rotation testing
- [ ] Configure RBAC for certificate management
- [ ] Document certificate emergency procedures  
- [ ] Set up certificate inventory and audit trails

## Integration with Intent Pipeline

This component enables:
- **Secure O2 IMS Communications**: Automatic TLS for API endpoints
- **Webhook Security**: Certificates for admission controllers
- **Service Mesh**: mTLS between intent pipeline components
- **GitOps Security**: Signed Git commits and webhook authentication
- **Registry Authentication**: Client certificates for image registries

Follows CLAUDE.md principles: secretless configs (automatic certificate management), default-on security (TLS everywhere), and deterministic behavior (predictable certificate lifecycle).