# GitOps Edge Repository Configuration Guide

This guide covers the setup, configuration, and management of private Gitea repositories for edge GitOps in the Nephio intent-to-o2 pipeline.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Authentication Methods](#authentication-methods)
- [Security Considerations](#security-considerations)
- [Configuration Management](#configuration-management)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)

## Overview

Edge GitOps repositories serve as the source of truth for edge cluster configurations in the Nephio ecosystem. These repositories:

- Store Kubernetes manifests for edge deployments
- Follow GitOps principles for declarative configuration
- Integrate with Flux or ArgoCD for continuous delivery
- Support multi-cluster edge deployments
- Enforce security policies through Kyverno and Sigstore

### Key Features

- **Private by Default**: All repositories are created as private for security
- **Structured Layout**: Organized directory structure for apps, infrastructure, and policies
- **Kustomize Integration**: Native support for Kustomize overlays and patches
- **Security-First**: Pod Security Standards and policy enforcement
- **Nephio Compatible**: Designed for Nephio R5 and O-RAN O2 IMS integration

## Quick Start

### Prerequisites

Ensure you have the following tools installed:

```bash
# Check dependencies
command -v curl >/dev/null 2>&1 || echo "curl is required"
command -v git >/dev/null 2>&1 || echo "git is required"  
command -v jq >/dev/null 2>&1 || echo "jq is required"
```

### Basic Usage

1. **Set environment variables**:

```bash
export GITEA_URL="https://your-gitea-instance.com"
export GITEA_TOKEN="your-api-token"  # Recommended
# OR
export GITEA_USER="your-username"
export GITEA_PASS="your-password"
```

2. **Run the bootstrap script**:

```bash
cd /path/to/nephio-intent-to-o2-demo
./scripts/edge_repo_bootstrap.sh
```

3. **Customize for your edge cluster**:

```bash
export EDGE_CLUSTER_NAME="production-edge-01"
export EDGE_REPO_NAME="prod-edge-gitops"
export EDGE_REPO_DIR="./prod-edge-gitops"
./scripts/edge_repo_bootstrap.sh
```

### Dry Run Mode

Test the script without making changes:

```bash
./scripts/edge_repo_bootstrap.sh --dry-run
```

## Repository Structure

The bootstrap script creates a standardized GitOps repository structure:

```
edge-gitops/
├── README.md                 # Repository documentation
├── kustomization.yaml        # Root kustomization
├── clusters/                 # Cluster-specific configurations
│   └── edge-cluster-01/
│       ├── kustomization.yaml
│       └── namespace.yaml
├── apps/                     # Application manifests
│   └── .gitkeep
├── infrastructure/           # Infrastructure components  
│   └── .gitkeep
└── policies/                 # Security policies
    └── .gitkeep
```

### Directory Purposes

#### `clusters/`
Contains cluster-specific configurations and customizations:

```yaml
# clusters/edge-cluster-01/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml

# Cluster-specific labels
commonLabels:
  cluster.nephio.io/name: edge-cluster-01
  cluster.nephio.io/type: edge

# Environment-specific patches
patches:
  - target:
      kind: Deployment
      labelSelector: "app=workload"
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
```

#### `apps/`
Application workloads and their configurations:

```yaml
# apps/sample-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app: sample-app
  version: v1.0.0
```

#### `infrastructure/`
Platform and infrastructure components:

- Operators
- CRDs
- System-level configurations
- Network policies
- Storage classes

#### `policies/`
Security and governance policies:

- Kyverno policies
- OPA Gatekeeper constraints
- Pod Security Policies
- Network security rules

## Authentication Methods

### API Token (Recommended)

API tokens provide secure, scoped access to Gitea:

1. **Generate token in Gitea**:
   - Go to Settings → Applications → Generate Token
   - Select appropriate scopes: `repo`, `write:repo_hook`

2. **Use in script**:
```bash
export GITEA_TOKEN="your-token-here"
./scripts/edge_repo_bootstrap.sh
```

### Username/Password

For environments where API tokens aren't available:

```bash
export GITEA_USER="admin"
export GITEA_PASS="secure-password"
./scripts/edge_repo_bootstrap.sh
```

**Note**: Username/password authentication is less secure and should be avoided in production.

### Git Credential Management

The script automatically configures git credentials for pushing:

```bash
# For token-based auth, credentials are cached temporarily
git config credential.helper cache

# Manual credential configuration
git config credential.helper 'store --file=.git/credentials'
echo "https://token:${GITEA_TOKEN}@git.example.com" > .git/credentials
```

## Security Considerations

### Repository Security

1. **Private Repositories**: All edge GitOps repositories are created as private by default
2. **Access Control**: Limit repository access to necessary personnel only
3. **Branch Protection**: Configure branch protection rules in Gitea:

```bash
# Enable branch protection via API
curl -X POST "${GITEA_URL}/api/v1/repos/${OWNER}/${REPO}/branch_protections" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "branch_name": "main",
    "enable_push": false,
    "enable_push_whitelist": true,
    "push_whitelist_usernames": ["admin"],
    "require_signed_off_by": true
  }'
```

### Pod Security Standards

All created namespaces enforce restricted Pod Security Standards:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Commit Signing

For enhanced security, enable commit signing:

```bash
# Configure GPG signing
git config --global user.signingkey YOUR_GPG_KEY
git config --global commit.gpgsign true

# Or use SSH signing (Git 2.34+)
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/your_signing_key.pub
```

### Secret Management

**Never commit secrets to GitOps repositories**. Use one of these approaches:

1. **External Secrets Operator**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.vault-system:8200"
      path: "secret"
      version: "v2"
```

2. **Sealed Secrets**:
```bash
# Create sealed secret
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal -o yaml > mysealedsecret.yaml
```

3. **SOPS (Secrets OPerationS)**:
```bash
# Encrypt secrets file
sops -e secret.yaml > secret.enc.yaml
```

## Configuration Management

### Environment-Specific Configurations

Use Kustomize overlays for environment differences:

```bash
# Directory structure for multi-environment
apps/my-app/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── development/
    │   ├── kustomization.yaml
    │   └── replica-patch.yaml
    └── production/
        ├── kustomization.yaml
        └── resource-patch.yaml
```

### ConfigMap Management

Store configuration separately from application code:

```yaml
# apps/my-app/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.yaml: |
    server:
      port: 8080
      debug: false
    database:
      host: postgres.database
      port: 5432
```

### Resource Quotas and Limits

Define resource constraints for edge environments:

```yaml
# clusters/edge-cluster-01/resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: edge-cluster-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures

**Symptoms**:
- HTTP 401 responses
- "Authentication failed" errors

**Solutions**:
```bash
# Verify token/credentials
curl -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL}/api/v1/user"

# Check token scopes
curl -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL}/api/v1/user/tokens"

# Test basic auth
curl -u "${GITEA_USER}:${GITEA_PASS}" "${GITEA_URL}/api/v1/user"
```

#### 2. Repository Creation Failures

**Symptoms**:
- HTTP 422 or 409 responses
- "Repository already exists" errors

**Solutions**:
```bash
# List existing repositories
curl -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL}/api/v1/user/repos"

# Delete existing repository (if needed)
curl -X DELETE -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL}/api/v1/repos/${OWNER}/${REPO}"

# Use --force flag
./scripts/edge_repo_bootstrap.sh --force
```

#### 3. Git Push Failures

**Symptoms**:
- "Authentication failed" during push
- "Permission denied" errors

**Solutions**:
```bash
# Clear git credentials cache
git credential reject <<< "protocol=https
host=git.example.com"

# Manually configure remote with token
git remote set-url origin "https://token:${GITEA_TOKEN}@git.example.com/user/repo.git"

# Check git configuration
git config --list | grep -E "(user|credential|remote)"
```

#### 4. Network Connectivity Issues

**Symptoms**:
- Connection timeouts
- DNS resolution failures

**Solutions**:
```bash
# Test basic connectivity
ping git.example.com

# Test HTTP/HTTPS access
curl -I "${GITEA_URL}"

# Check firewall/proxy settings
curl -v "${GITEA_URL}/api/v1/version"
```

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Enable bash debugging
bash -x ./scripts/edge_repo_bootstrap.sh

# Enable curl verbose output
export CURL_OPTS="-v"
./scripts/edge_repo_bootstrap.sh
```

### Logging and Monitoring

Monitor GitOps operations:

```bash
# Check GitOps controller logs (Flux)
kubectl logs -n flux-system deploy/source-controller
kubectl logs -n flux-system deploy/kustomize-controller

# Check ArgoCD logs
kubectl logs -n argocd deploy/argocd-application-controller
```

## Advanced Usage

### Multiple Edge Clusters

Bootstrap repositories for multiple edge locations:

```bash
# Edge cluster in US-West
export EDGE_CLUSTER_NAME="usw-edge-01"
export EDGE_REPO_NAME="usw-edge-gitops"
export EDGE_REPO_DIR="./usw-edge-gitops"
./scripts/edge_repo_bootstrap.sh

# Edge cluster in EU-Central  
export EDGE_CLUSTER_NAME="euc-edge-01"
export EDGE_REPO_NAME="euc-edge-gitops"
export EDGE_REPO_DIR="./euc-edge-gitops"
./scripts/edge_repo_bootstrap.sh
```

### Custom GitOps Structure

Modify the script to create custom directory structures:

```bash
# Create custom function in script
create_custom_structure() {
    local repo_dir="$1"
    
    mkdir -p "${repo_dir}/workloads/critical"
    mkdir -p "${repo_dir}/workloads/best-effort"
    mkdir -p "${repo_dir}/system/monitoring"
    mkdir -p "${repo_dir}/system/logging"
    
    # Custom kustomization files...
}
```

### Integration with CI/CD

Automate repository updates through CI/CD:

```yaml
# .github/workflows/update-edge-config.yml
name: Update Edge Configuration
on:
  push:
    paths:
      - 'config/edge/**'

jobs:
  update-gitops:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Update GitOps Repository
        env:
          GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
          GITEA_URL: ${{ vars.GITEA_URL }}
        run: |
          # Update configurations
          ./scripts/sync-edge-config.sh
```

### Webhook Configuration

Configure Gitea webhooks for GitOps controllers:

```bash
# Create webhook for Flux
curl -X POST "${GITEA_URL}/api/v1/repos/${OWNER}/${REPO}/hooks" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "gitea",
    "config": {
      "url": "http://notification-controller.flux-system/hook/",
      "content_type": "json",
      "secret": "'${WEBHOOK_SECRET}'"
    },
    "events": ["push", "pull_request"],
    "active": true
  }'
```

## Best Practices

### Repository Management

1. **Single Responsibility**: One repository per edge cluster
2. **Consistent Naming**: Use standardized naming conventions
3. **Regular Updates**: Keep base images and dependencies updated
4. **Documentation**: Maintain up-to-date README files

### Security Practices

1. **Least Privilege**: Grant minimal required permissions
2. **Regular Rotation**: Rotate API tokens and SSH keys regularly
3. **Audit Trails**: Enable audit logging in Gitea
4. **Vulnerability Scanning**: Scan container images in manifests

### GitOps Workflow

1. **Feature Branches**: Use branches for changes, not direct commits to main
2. **Pull Requests**: Require code reviews for all changes
3. **Automated Testing**: Validate manifests before merging
4. **Rollback Plans**: Have clear rollback procedures

### Monitoring and Observability

1. **Sync Status Monitoring**: Monitor GitOps controller sync status
2. **Application Health**: Track application health metrics
3. **Resource Usage**: Monitor cluster resource consumption
4. **Alert Configuration**: Set up alerts for sync failures

### Example Monitoring Setup

```yaml
# monitoring/gitops-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitops-dashboard
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "GitOps Edge Monitoring",
        "panels": [
          {
            "title": "Sync Status",
            "targets": [
              {
                "expr": "sum(rate(gotk_reconcile_condition{type=\"Ready\"}[5m])) by (name)"
              }
            ]
          }
        ]
      }
    }
```

### Backup and Disaster Recovery

1. **Repository Backups**: Regular backups of GitOps repositories
2. **Cluster State Backups**: Backup critical cluster state
3. **Recovery Procedures**: Document recovery processes
4. **Multi-Region Setup**: Consider multi-region GitOps for resilience

```bash
# Backup script example
#!/bin/bash
# backup-gitops-repos.sh

BACKUP_DIR="/backup/gitops-$(date +%Y%m%d)"
mkdir -p "${BACKUP_DIR}"

# Backup repositories
for repo in usw-edge-gitops euc-edge-gitops; do
  git clone "https://token:${GITEA_TOKEN}@git.example.com/admin/${repo}.git" "${BACKUP_DIR}/${repo}"
done

# Compress backup
tar -czf "${BACKUP_DIR}.tar.gz" -C "/backup" "gitops-$(date +%Y%m%d)"
```

## Conclusion

This guide provides a comprehensive foundation for managing edge GitOps repositories in the Nephio ecosystem. By following these practices, you can maintain secure, scalable, and reliable edge deployments.

For additional support or questions, refer to:

- [Nephio Documentation](https://nephio.org/docs/)
- [O-RAN O2 IMS Specifications](https://www.o-ran.org/)
- [Kustomize Documentation](https://kustomize.io/)
- [Flux Documentation](https://fluxcd.io/)

---

**Generated by**: Nephio intent-to-o2-demo edge repository bootstrap system  
**Version**: 1.0.0  
**Last Updated**: $(date +%Y-%m-%d)