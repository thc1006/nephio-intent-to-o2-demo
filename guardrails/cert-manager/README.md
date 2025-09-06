# Cert-Manager Configuration

Provides TLS certificate management using cert-manager with self-signed ClusterIssuer.

## Quick Start (TDD Approach)

```bash
# 1. Run tests first (will FAIL - RED phase)
make test

# 2. Install cert-manager in cluster
make install

# 3. Apply ClusterIssuer configuration (GREEN phase)
make apply

# 4. Run tests again (should PASS)
make test

# 5. Validate installation
make validate
```

## Components

- **install.yaml**: References official cert-manager installation
- **cluster-issuer.yaml**: Defines certificate issuers
  - Self-signed ClusterIssuer for testing
  - CA ClusterIssuer with generated root certificate

## Testing

- `test-certificate.yaml`: Test certificate request
- `verify-cert-manager.sh`: Validates cert-manager functionality
  - Checks CRDs installation
  - Verifies pods are running
  - Tests certificate issuance

## Usage Example

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-tls
  namespace: default
spec:
  secretName: app-tls-secret
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  commonName: app.example.com
  dnsNames:
  - app.example.com
```

## Production Considerations

- Replace self-signed issuer with proper CA or ACME issuer
- Configure DNS validation for Let's Encrypt
- Set appropriate certificate rotation policies
- Monitor certificate expiration with Prometheus