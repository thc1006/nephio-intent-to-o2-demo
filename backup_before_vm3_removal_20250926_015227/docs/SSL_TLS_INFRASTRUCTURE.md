# SSL/TLS Infrastructure for Nephio Intent-to-O2 Demo

## Overview

This document describes the complete SSL/TLS infrastructure implementation for the Nephio Intent-to-O2 demonstration environment. The infrastructure provides secure communication across all components including Gitea, Kubernetes clusters, and GitOps workflows.

## Architecture

```
                    ┌──────────────────────────────┐
                    │   Nephio Certificate Authority  │
                    │       (Self-Signed Root CA)       │
                    └────────────┬────────────────┘
                                │
                ┌───────────┴───────────┐
                │                           │
        ┌───────├─────────────────────┤───────┐
        │       │                       │       │
    ┌───├───────┐   ┌───────────────┐   ┌───├───────┐
    │   │        │   │   Gitea HTTPS   │   │   │        │
    │   │ Edge1  │   │ 172.16.0.78   │   │   │ Edge2  │
    │   │ K8s TLS│   │ :8443         │   │   │ K8s TLS│
    │   │        │   │ (cert-manager)│   │   │        │
    └───┤        └───┤               └───┤   ┤        └───┘
        │              │                   │            │
    172.16.4.45      GitOps HTTPS        172.16.4.176
    :6443            Repositories        :6443
```

## Components

### 1. Certificate Authority (CA)

- **Type**: Self-signed root CA
- **Purpose**: Issue certificates for all services
- **Validity**: 365 days
- **Location**: `certs/nephio-ca.crt` and `certs/nephio-ca.key`
- **Security**: Private key protected with 600 permissions

### 2. Gitea HTTPS

- **Service**: Git repository server
- **Endpoints**:
  - HTTP: `http://172.16.0.78:8888` (backward compatibility)
  - HTTPS: `https://172.16.0.78:8443` (secure)
- **Certificate**: `certs/gitea/gitea.crt`
- **Private Key**: `certs/gitea/gitea.key`
- **Subject Alternative Names**:
  - DNS: gitea.local, gitea.nephio.local, localhost
  - IP: 127.0.0.1, 172.16.0.78

### 3. Kubernetes TLS

#### Edge1 Cluster (VM-2)
- **API Server**: `https://172.16.4.45:6443`
- **Certificate**: `certs/k8s-edge1/k8s-edge1.crt`
- **cert-manager**: Deployed for automated certificate management
- **ClusterIssuer**: Self-signed and CA-based issuers available

#### Edge2 Cluster (VM-4)
- **API Server**: `https://172.16.4.176:6443`
- **Certificate**: `certs/k8s-edge2/k8s-edge2.crt`
- **cert-manager**: Deployed for automated certificate management
- **ClusterIssuer**: Self-signed and CA-based issuers available

## Deployment

### Quick Start

```bash
# Complete SSL/TLS infrastructure deployment
./scripts/deploy-ssl-infrastructure.sh

# Check deployment status
./scripts/ssl-manager.sh status

# Test connectivity
./scripts/ssl-manager.sh test-gitea
./scripts/ssl-manager.sh test-k8s
```

### Step-by-Step Deployment

1. **Generate Certificates**:
   ```bash
   ./scripts/setup/setup-ssl-certificates.sh install
   ```

2. **Deploy Gitea HTTPS**:
   ```bash
   ./scripts/setup/deploy-gitea-https.sh
   ```

3. **Configure Kubernetes TLS**:
   ```bash
   ./scripts/setup/configure-k8s-tls.sh all install
   ```

### Manual Certificate Generation

If you need to generate certificates manually:

```bash
# Generate CA certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt \
    -subj "/C=TW/ST=Taipei/L=Taipei/O=Nephio Demo/CN=Nephio CA"

# Generate service certificate
openssl genrsa -out service.key 2048
openssl req -new -key service.key -out service.csr \
    -subj "/C=TW/ST=Taipei/L=Taipei/O=Nephio Demo/CN=service.local"
openssl x509 -req -in service.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out service.crt -days 365
```

## Configuration Files

### GitOps HTTPS Configuration

Updated RootSync configurations are created for HTTPS GitOps:

```yaml
# configs/ssl/edge1-rootsync-https.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync-https
  namespace: config-management-system
spec:
  git:
    repo: https://172.16.0.78:8443/admin1/edge1-config
    branch: main
    auth: token
    secretRef:
      name: gitea-token-https
    caCertSecretRef:
      name: gitea-ca-cert
```

### Kubernetes TLS Configuration

Kubeconfig files with TLS settings:

```yaml
# configs/ssl/kubeconfig-edge1-tls.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /path/to/certs/nephio-ca.crt
    server: https://172.16.4.45:6443
  name: edge1-secure
contexts:
- context:
    cluster: edge1-secure
    user: admin
  name: edge1-secure
current-context: edge1-secure
users:
- name: admin
  user:
    client-certificate: /path/to/certs/k8s-edge1/k8s-edge1.crt
    client-key: /path/to/certs/k8s-edge1/k8s-edge1.key
```

## Management

### Certificate Status Check

```bash
# Check all certificate expiration status
./scripts/check-certificate-status.sh

# Or use the unified manager
./scripts/ssl-manager.sh status
```

### Certificate Renewal

```bash
# Renew all certificates
./scripts/renew-certificates.sh

# Or use the unified manager
./scripts/ssl-manager.sh renew
```

### Testing Connectivity

```bash
# Test Gitea HTTPS
./scripts/test-gitea-https.sh

# Test Kubernetes TLS
./scripts/manage-k8s-tls.sh all test

# Use unified manager
./scripts/ssl-manager.sh test-gitea
./scripts/ssl-manager.sh test-k8s
```

### Rollback Procedures

```bash
# Rollback Gitea to HTTP (if needed)
./scripts/rollback-gitea-http.sh

# Or use the unified manager
./scripts/ssl-manager.sh rollback-gitea
```

## Security Considerations

### Certificate Authority Security

1. **Private Key Protection**:
   - CA private key stored with 600 permissions
   - Consider hardware security module (HSM) for production
   - Regular backup of CA key to secure location

2. **Certificate Distribution**:
   - CA certificate can be freely distributed
   - Include CA certificate in container images
   - Configure OS trust stores with CA certificate

### Service Certificate Security

1. **Private Key Management**:
   - All service private keys have 600 permissions
   - Keys stored in secure locations
   - Automatic key rotation planned

2. **Certificate Validation**:
   - Subject Alternative Names (SANs) properly configured
   - Certificate validity periods set appropriately
   - Regular certificate validation checks

### Network Security

1. **Protocol Enforcement**:
   - HTTPS enforced where possible
   - HTTP maintained for backward compatibility only
   - TLS 1.2+ enforced

2. **Firewall Configuration**:
   - Update firewall rules for HTTPS ports (8443)
   - Restrict access to certificate directories
   - Monitor certificate-related network traffic

## Troubleshooting

### Common Issues

1. **Certificate Not Trusted**:
   ```bash
   # Add CA certificate to system trust store
   sudo cp certs/nephio-ca.crt /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   
   # Or use CA certificate with curl
   curl --cacert certs/nephio-ca.crt https://172.16.0.78:8443
   ```

2. **Gitea HTTPS Not Responding**:
   ```bash
   # Check container status
   docker ps | grep gitea
   
   # Check container logs
   docker logs gitea-https
   
   # Restart Gitea container
   ./scripts/setup/deploy-gitea-https.sh
   ```

3. **Kubernetes TLS Issues**:
   ```bash
   # Check cert-manager status
   kubectl --server=https://172.16.4.45:6443 --insecure-skip-tls-verify \
     get pods -n cert-manager
   
   # Check certificate status
   kubectl --server=https://172.16.4.45:6443 --insecure-skip-tls-verify \
     get certificates -A
   ```

4. **GitOps HTTPS Issues**:
   ```bash
   # Check RootSync status
   kubectl get rootsync -n config-management-system
   
   # Check config-sync logs
   kubectl logs -n config-management-system -l app=reconciler-manager
   ```

### Log Locations

- **Deployment Logs**: `reports/ssl-deployment-report-*.md`
- **Container Logs**: `docker logs gitea-https`
- **Kubernetes Logs**: `kubectl logs -n cert-manager`
- **GitOps Logs**: `kubectl logs -n config-management-system`

## Monitoring and Alerting

### Certificate Expiration Monitoring

```bash
# Create a monitoring script
cat > monitor-certificates.sh << 'EOF'
#!/bin/bash
# Check certificate expiration and send alerts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Run certificate status check
"${PROJECT_ROOT}/scripts/check-certificate-status.sh" > /tmp/cert-status.txt

# Check for certificates expiring within 30 days
if grep -q "expires in [0-9]\+ days" /tmp/cert-status.txt; then
    if grep -q "expires in [0-2][0-9] days" /tmp/cert-status.txt; then
        echo "ALERT: Certificates expiring within 30 days detected!"
        grep "expires in [0-2][0-9] days" /tmp/cert-status.txt
        # Send alert to monitoring system
        # curl -X POST "$WEBHOOK_URL" -d @/tmp/cert-status.txt
    fi
fi
EOF

chmod +x monitor-certificates.sh
```

### Automated Renewal

Set up a cron job for automatic certificate renewal:

```bash
# Add to crontab (run monthly)
0 0 1 * * /path/to/nephio-intent-to-o2-demo/scripts/renew-certificates.sh
```

## Production Considerations

### Certificate Authority

1. **Use Proper CA**: Replace self-signed CA with proper certificate authority
2. **Hardware Security**: Use HSM for CA private key storage
3. **Certificate Transparency**: Log certificates to CT logs
4. **OCSP/CRL**: Implement certificate revocation lists

### Certificate Management

1. **Automated Renewal**: Implement full automation with cert-manager
2. **Key Rotation**: Regular private key rotation
3. **Certificate Pinning**: Implement certificate pinning for critical services
4. **Monitoring**: 24/7 certificate expiration monitoring

### Security Hardening

1. **TLS Configuration**: Use modern TLS configurations (TLS 1.3)
2. **Cipher Suites**: Restrict to secure cipher suites only
3. **HSTS**: Implement HTTP Strict Transport Security
4. **Certificate Transparency**: Monitor CT logs for unauthorized certificates

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Gitea HTTPS Configuration](https://docs.gitea.io/en-us/https-setup/)
- [Kubernetes TLS Documentation](https://kubernetes.io/docs/concepts/cluster-administration/certificates/)
- [GitOps Security Best Practices](https://www.weave.works/blog/gitops-security-best-practices)

## Support

For issues or questions regarding the SSL/TLS infrastructure:

1. Check the troubleshooting section above
2. Review deployment logs in `reports/`
3. Run diagnostic scripts: `./scripts/ssl-manager.sh test`
4. Check individual component logs
5. Contact the Nephio Intent-to-O2 Demo team

---

**Last Updated**: 2024-09-16  
**Version**: 1.0.0  
**Maintainer**: Nephio Intent-to-O2 Demo Team
