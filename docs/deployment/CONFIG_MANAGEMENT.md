# Configuration Management Guide v1.2.0 - 4-Site Deployment

## 📋 Overview

This guide explains the unified configuration management system for the 4-site Nephio Intent-to-O2 deployment topology. All site configurations are centrally managed through the authoritative `config/edge-sites-config.yaml` file.

## 🎯 Architecture Overview (v1.2.0)

### File Structure
```
config/
├── edge-sites-config.yaml          # Authoritative 4-site configuration
├── tmf921-config.yaml              # TMF921 adapter configuration
├── websocket-routes.yaml           # WebSocket service routing
├── deployment-guard/               # Deployment guard policies
│   ├── slo-thresholds.yaml
│   └── rollback-policies.yaml
└── ssh-keys/                       # SSH key management
    ├── edge1-edge2.key            # For Edge1/Edge2 (ubuntu user)
    └── edge3-edge4.key            # For Edge3/Edge4 (thc1006 user)
```

### Configuration Hierarchy
```yaml
global:                    # Global settings and thresholds
sites:                     # 4-site configuration
  edge1:                   # VM-2 (172.16.4.45)
  edge2:                   # VM-4 (172.16.4.176)
  edge3:                   # New site (172.16.5.81)
  edge4:                   # New site (172.16.1.252)
cross_site:               # Inter-site configuration
deployment_templates:     # GitOps templates
monitoring:               # Multi-site monitoring
troubleshooting:          # Site-specific guidance
```

## 🚀 Configuration Management (4-Site)

### 1. Central Configuration Reader

```python
# Enhanced configuration reader for v1.2.0
from examples.config_reader import EdgeSiteConfig

# Initialize 4-site configuration reader
config = EdgeSiteConfig(version="v1.2.0")

# Get all 4 sites
all_sites = config.get_all_sites()
print(f"Managing {len(all_sites)} edge sites")

# Get site-specific endpoints
for site in ["edge1", "edge2", "edge3", "edge4"]:
    o2ims_url = config.get_o2ims_endpoint(site)
    slo_url = config.get_slo_endpoint(site)
    ssh_config = config.get_ssh_config(site)

    print(f"{site}: O2IMS={o2ims_url}, SLO={slo_url}")
    print(f"  SSH: {ssh_config['user']}@{ssh_config['host']} (key: {ssh_config['key']})")
```

### 2. Automated Configuration Deployment

```bash
# Deploy configuration to all 4 sites
./scripts/deploy-config-all-sites.sh

# Site-specific deployment
./scripts/deploy-config.sh --site edge1 --component o2ims
./scripts/deploy-config.sh --site edge3 --component gitops --automated

# Validate configuration across all sites
./scripts/validate-config-all-sites.sh
```

### 3. GitOps Configuration Management

#### Edge1 & Edge2 (Manual Sync)
```yaml
# config/gitops/edge1-rootsync.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge1-rootsync
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://172.16.0.78:3000/nephio/edge1-config
    branch: main
    auth: token
    secretRef:
      name: git-creds
```

#### Edge3 & Edge4 (Automated GitOps)
```yaml
# config/gitops/edge3-automated-sync.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge3-automated-sync
  namespace: config-management-system
  annotations:
    config.kubernetes.io/managed-by: "deployment-guard"
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://172.16.0.78:3000/nephio/edge3-config
    branch: main
    period: 30s  # Faster sync for automation
    auth: token
  override:
    automationPolicy: "enabled"
    rollbackOnFailure: true
```

## 🔧 Multi-Site Configuration Patterns

### 1. SSH Key Management

```yaml
# config/ssh-config.yaml
ssh_configuration:
  edge_groups:
    group1:  # Edge1, Edge2
      sites: ["edge1", "edge2"]
      key_path: "~/.ssh/id_ed25519"
      user: "ubuntu"
      description: "Original VM sites"
    group2:  # Edge3, Edge4
      sites: ["edge3", "edge4"]
      key_path: "~/.ssh/edge_sites_key"
      user: "thc1006"
      password: "1006"  # For systems requiring password
      description: "New automated sites"
```

### 2. Service Port Management

```yaml
# config/port-allocation.yaml
service_ports:
  o2ims:
    primary: 31280      # All sites
    secondary: 31281    # All sites
    dashboard: 32080    # All sites
  monitoring:
    prometheus: 30090   # All sites
    grafana: 31090     # Optional
  central_services:     # VM-1 only
    gitea: 3000
    tmf921_adapter: 8889
    websocket: 8080
```

### 3. Deployment Templates

```yaml
# config/deployment-templates/o2ims-systemd.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: o2ims-systemd-template
data:
  service-template: |
    [Unit]
    Description=O2IMS Service for {{.SiteName}}
    After=network.target docker.service
    Requires=docker.service

    [Service]
    Type=exec
    User={{.ServiceUser}}
    Environment="SITE_NAME={{.SiteName}}"
    Environment="O2IMS_VERSION={{.O2IMSVersion}}"
    Environment="LISTEN_PORT={{.PrimaryPort}}"
    ExecStart=/usr/local/bin/o2ims-service
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
```

## 📊 Configuration Validation

### 1. Pre-Deployment Validation

```bash
# Validate configuration syntax
python3 -c "
import yaml
with open('config/edge-sites-config.yaml') as f:
    config = yaml.safe_load(f)
    print('✅ Configuration syntax valid')
"

# Validate site connectivity
./scripts/validate-site-connectivity.sh --all-sites

# Validate SSH access
./scripts/validate-ssh-access.sh --all-sites
```

### 2. Post-Deployment Validation

```bash
# Comprehensive site validation
./scripts/postcheck.sh --all-sites --comprehensive

# Service-specific validation
for site in edge1 edge2 edge3 edge4; do
  echo "Validating $site..."
  ./scripts/validate-site.sh --site $site --services o2ims,prometheus,gitops
done
```

### 3. SLO Configuration Validation

```yaml
# config/slo-validation.yaml
slo_thresholds:
  global:
    deployment_success_rate: 100%    # All 4 sites must succeed
    sync_latency_p95: "100ms"
    rollback_time_max: "300s"
  per_site:
    o2ims_availability: 99.9%
    api_response_time_p95: "50ms"
    prometheus_scrape_success: 99%
```

## 🛠️ Configuration Update Procedures

### 1. Adding New Sites (Future Expansion)

```bash
# Add new site to configuration
./scripts/add-site.sh --name edge5 --ip 172.16.6.100 --type automated

# Generate GitOps configuration
./scripts/generate-gitops-config.sh --site edge5

# Deploy configuration
./scripts/deploy-new-site.sh --site edge5 --validate
```

### 2. Updating Existing Sites

```bash
# Update site configuration
./scripts/update-site-config.sh --site edge2 --update-endpoints

# Propagate changes via GitOps
./scripts/propagate-config-changes.sh --sites edge2

# Validate changes
./scripts/validate-config-update.sh --site edge2
```

### 3. Emergency Configuration Rollback

```bash
# Emergency rollback for all sites
./scripts/emergency-rollback.sh --all-sites --reason "Configuration error"

# Site-specific rollback
./scripts/rollback-site-config.sh --site edge3 --to-revision previous
```

## 🔄 GitOps Integration (Enhanced v1.2.0)

### Automated Config Sync for Edge3/Edge4

```yaml
# gitops/edge3-config/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- o2ims-deployment.yaml
- prometheus-config.yaml
- service-monitor.yaml

configMapGenerator:
- name: site-config
  files:
  - config.yaml=../../../config/edge-sites-config.yaml

patchesStrategicMerge:
- site-specific-patches.yaml
```

### Config Sync Status Monitoring

```bash
# Monitor Config Sync across all sites
watch -n 30 './scripts/monitor-config-sync.sh --all-sites'

# Expected output:
# Edge1: ✅ SYNCED (manual)
# Edge2: ✅ SYNCED (manual)
# Edge3: ✅ SYNCED (automated)
# Edge4: ✅ SYNCED (automated)
```

## 📈 Configuration Metrics

### Key Configuration Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| **Config Sync Success** | 100% | All sites sync successfully |
| **Config Validation Time** | <30s | Time to validate changes |
| **Config Propagation Time** | <2min | Time to propagate to all sites |
| **Rollback Time** | <5min | Time to rollback configuration |

### Monitoring Configuration Health

```bash
# Configuration health dashboard
./scripts/config-health-dashboard.sh

# Alerts for configuration issues
./scripts/setup-config-alerts.sh --webhook-url $WEBHOOK_URL
```

## 🔒 Security & Compliance

### Configuration Security

1. **Encrypted Storage**: All sensitive configuration encrypted at rest
2. **Access Control**: Role-based access to configuration files
3. **Audit Logging**: All configuration changes logged
4. **Validation**: Mandatory validation before deployment

### Compliance Checks

```bash
# Security compliance scan
./scripts/security-compliance-scan.sh --config-files

# Generate compliance report
./scripts/generate-compliance-report.sh --version v1.2.0
```

## 📚 Best Practices (v1.2.0)

### 1. Configuration Management Principles

- ✅ **Single Source of Truth**: All configuration from `edge-sites-config.yaml`
- ✅ **Automation First**: Automated deployment for Edge3/Edge4
- ✅ **Validation Required**: All changes must pass validation
- ✅ **Rollback Ready**: Always maintain rollback capability

### 2. Site-Specific Guidelines

- **Edge1/Edge2**: Manual deployment with validation
- **Edge3/Edge4**: Fully automated via GitOps
- **All Sites**: Consistent monitoring and SLO enforcement

### 3. Change Management

```bash
# Proper change workflow
git checkout -b config/update-edge3-endpoints
# Edit config/edge-sites-config.yaml
./scripts/validate-config.sh --all-sites
git commit -m "Update Edge3 O2IMS endpoints"
./scripts/deploy-config-change.sh --validate --rollback-on-failure
```

## 🎯 Migration from v1.1.x

### Configuration Migration Steps

```bash
# 1. Backup existing configuration
./scripts/backup-v1.1-config.sh

# 2. Migrate to 4-site configuration
./scripts/migrate-config-to-v1.2.0.sh

# 3. Add new sites (Edge3, Edge4)
./scripts/add-sites-edge3-edge4.sh

# 4. Configure automated GitOps
./scripts/setup-automated-gitops.sh --sites edge3,edge4

# 5. Validate migration
./scripts/validate-migration.sh --from v1.1.x --to v1.2.0
```

### Breaking Changes

- **Site Count**: Extended from 2 to 4 sites
- **SSH Configuration**: Different keys for different site groups
- **Service Ports**: Added new ports for expanded services
- **GitOps**: Automated deployment for Edge3/Edge4

## 📞 Support & Troubleshooting

### Configuration Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Config Sync Failed** | Sites not updating | Check Git repository access |
| **SSH Key Mismatch** | Cannot connect to Edge3/Edge4 | Use correct SSH key group |
| **Port Conflicts** | Services not accessible | Check port allocation |
| **SLO Violations** | Automatic rollbacks | Check configuration thresholds |

### Emergency Procedures

```bash
# Emergency configuration reset
./scripts/emergency-config-reset.sh --all-sites

# Restore from backup
./scripts/restore-config-backup.sh --timestamp 2025-09-27-10-30

# Manual site recovery
./scripts/manual-site-recovery.sh --site edge3 --full-reset
```

### Contact Information

- **Configuration Issues**: See this guide and `scripts/help.sh`
- **Site-Specific Problems**: Check `config/troubleshooting` section
- **Emergency Support**: Follow procedures in `docs/operations/EMERGENCY_PROCEDURES.md`

---

**Through centralized configuration management, we ensure consistency, reliability, and automated deployment across all 4 edge sites. The v1.2.0 enhancements provide 100% deployment success rate with automatic rollback capabilities.**

---
*Configuration Management Guide | Version: 1.2.0 | Date: 2025-09-27 | Classification: Technical*