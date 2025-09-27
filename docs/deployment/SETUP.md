# Setup Guide v1.2.0 - 4-Site Deployment

## Hardware Requirements

### Minimum Requirements (4-Site Topology)
- **Total**: 40 vCPU, 160 GB RAM, 1TB SSD
- **Per Site**: 8 vCPU, 32 GB RAM, 200 GB SSD
- **OS**: Ubuntu 22.04 LTS on all sites

### Site Configuration

| Site | Role | IP Address | SSH Key | User |
|------|------|------------|---------|------|
| **VM-1** | SMO/Orchestrator | 172.16.0.78 | Standard SSH | ubuntu |
| **Edge1** | O-Cloud + O2IMS | 172.16.4.45 | id_ed25519 | ubuntu |
| **Edge2** | O-Cloud + O2IMS | 172.16.4.176 | id_ed25519 | ubuntu |
| **Edge3** | O-Cloud + O2IMS | 172.16.5.81 | edge_sites_key | thc1006 |
| **Edge4** | O-Cloud + O2IMS | 172.16.1.252 | edge_sites_key | thc1006 |

## Software Stack (v1.2.0)

### Core Components
- **Nephio**: R4 (Intent-driven automation)
- **O2IMS**: v3.0 (O-RAN Interface Management)
- **TMF921**: v5.0 (Intent Management)
- **Kubernetes**: 1.28+ (Container orchestration)
- **Prometheus**: Latest (SLO monitoring)

### New in v1.2.0
- **TMF921 Adapter**: Replaces LLM adapter, port 8889
- **WebSocket Services**: Real-time communication
- **Systemd O2IMS**: Service-based deployment
- **Deployment Guard**: Automatic rollback on SLO violations
- **Multi-Site GitOps**: Automated Config Sync for Edge3/Edge4

## Quick Start (4-Site Deployment)

### Step 1: VM-1 (Orchestrator) Setup

```bash
# VM-1: Launch kind cluster and install Nephio R4
./scripts/kind-up.sh

# Install Nephio R4 with 4-site support
kubectl apply -f https://github.com/nephio-project/nephio/releases/download/v4.0.0/nephio-r4-components.yaml

# Install TMF921 Adapter (replaces LLM adapter)
./scripts/install-tmf921-adapter.sh

# Configure 4-site topology
cp config/edge-sites-config.yaml.example config/edge-sites-config.yaml
# Edit with actual site IPs

# Install WebSocket services
./scripts/start-websocket-services.sh
```

### Step 2: Edge Sites Setup

#### Edge1 & Edge2 (Manual Deployment)
```bash
# Edge1 (VM-2) - SSH with id_ed25519
ssh -i ~/.ssh/id_ed25519 ubuntu@172.16.4.45
./scripts/install-edge-site.sh --site edge1 --o2ims-version v3.0

# Edge2 (VM-4) - SSH with id_ed25519
ssh -i ~/.ssh/id_ed25519 ubuntu@172.16.4.176
./scripts/install-edge-site.sh --site edge2 --o2ims-version v3.0
```

#### Edge3 & Edge4 (Automated GitOps)
```bash
# From VM-1: Deploy Edge3 via GitOps
./scripts/deploy-edge3-gitops.sh

# From VM-1: Deploy Edge4 via GitOps
./scripts/deploy-edge4-gitops.sh

# Verify automated deployment (100% success rate)
./scripts/verify-gitops-deployment.sh
```

### Step 3: O2IMS Deployment (Systemd Services)

```bash
# Deploy O2IMS as systemd services on all sites
./scripts/deploy-o2ims-all-sites.sh

# Verify O2IMS services
for site in edge1 edge2 edge3 edge4; do
  ip=$(yq ".sites.$site.network.internal_ip" config/edge-sites-config.yaml)
  curl "http://$ip:31280/o2ims/v1/" | jq .
done
```

### Step 4: SLO Gate & Deployment Guard

```bash
# Install SLO Gate with automatic rollback
./scripts/install-slo-gate.sh --enable-rollback

# Configure deployment guard policies
kubectl apply -f config/deployment-guard/policies.yaml

# Test automatic rollback
./scripts/test-deployment-guard.sh
```

## Port Configuration (4-Site Deployment)

### Standard Ports (All Sites)
- **22**: SSH access
- **6443**: Kubernetes API
- **30090**: Prometheus (SLO metrics)

### O2IMS Ports (All Sites)
- **31280**: O2IMS API (Primary)
- **31281**: O2IMS API (Secondary)
- **32080**: O2IMS Dashboard

### Central Services (VM-1)
- **3000**: Gitea (GitOps repository)
- **8889**: TMF921 Adapter
- **8080**: WebSocket services

## Verification Commands

### Health Check (All Sites)
```bash
# Quick health check for all 4 sites
./scripts/health-check-all-sites.sh

# Expected output:
# ✅ Edge1: O2IMS OK, Prometheus OK, Config Sync OK
# ✅ Edge2: O2IMS OK, Prometheus OK, Config Sync OK
# ✅ Edge3: O2IMS OK, Prometheus OK, GitOps Synced
# ✅ Edge4: O2IMS OK, Prometheus OK, GitOps Synced
```

### SLO Validation
```bash
# Check SLO compliance across all sites
./scripts/postcheck.sh --all-sites

# Expected SLO targets:
# - Sync Latency: <100ms
# - Success Rate: >99.5%
# - O2IMS Availability: >99.9%
# - Deployment Success: 100%
```

### TMF921 Adapter Test
```bash
# Test TMF921 adapter with all sites
curl -X POST http://localhost:8889/api/intent \
  -H "Content-Type: application/json" \
  -d '{
    "intentType": "SliceIntent",
    "targetSites": ["edge1", "edge2", "edge3", "edge4"],
    "sloRequirements": {
      "latency": "10ms",
      "throughput": "1Gbps"
    }
  }'
```

## Automated Features (v1.2.0)

### GitOps Automation
- **Edge3/Edge4**: 100% automated deployment via Config Sync
- **Configuration Management**: Centralized via `config/edge-sites-config.yaml`
- **Rollback**: Automatic on SLO violations

### Monitoring & Alerting
- **Multi-Site Prometheus**: Federation across all sites
- **SLO Gates**: Real-time validation
- **WebSocket**: Real-time status updates

### Security Enhancements
- **SSH Key Management**: Different keys for different site groups
- **Service Authentication**: Automated certificate management
- **Audit Logging**: Comprehensive deployment tracking

## Troubleshooting

### Common Issues
1. **SSH Connection Failed**: Verify correct SSH key for site group
2. **O2IMS Not Responding**: Check systemd service status
3. **GitOps Sync Failed**: Verify Git repository access
4. **SLO Gate Triggered**: Check metrics and adjust thresholds
5. **WebSocket Connection Lost**: Restart WebSocket services

### Log Collection
```bash
# Collect logs from all sites
./scripts/collect-logs-all-sites.sh

# Specific service logs
sudo journalctl -u o2ims-edge1 --since="1 hour ago"
sudo journalctl -u tmf921-adapter --since="1 hour ago"
```

## Migration from v1.1.x

### Breaking Changes
- **LLM Adapter**: Replaced with TMF921 Adapter (port changed 8888→8889)
- **O2IMS Deployment**: Now uses systemd services instead of containers
- **Site Count**: Extended from 2 to 4 sites

### Migration Steps
```bash
# 1. Backup existing configuration
./scripts/backup-v1.1-config.sh

# 2. Update configuration files
cp config/edge-sites-config.yaml.v1.2.0 config/edge-sites-config.yaml

# 3. Deploy new components
./scripts/migrate-to-v1.2.0.sh

# 4. Verify migration
./scripts/verify-v1.2.0-migration.sh
```

## Performance Targets

| Component | Target | Measurement |
|-----------|--------|-------------|
| **Site Deployment** | <30min | Time to full operational |
| **Config Sync** | <2min | GitOps propagation time |
| **O2IMS Response** | <100ms | API response time |
| **SLO Validation** | <30s | End-to-end validation |
| **Rollback Time** | <5min | Full system rollback |

## References

- [Nephio R4 Release](https://github.com/nephio-project/nephio/releases/tag/v4.0.0)
- [O-RAN O2 IMS v3.0 Spec](https://www.o-ran.org/specifications)
- [TMF921 Intent Management v5.0](https://www.tmforum.org/resources/standard/tmf921-intent-management-api-rest-specification-r21-0-0/)
- [kpt Function SDK](https://kpt.dev/book/05-developing-functions/)
- [Config Sync Documentation](https://cloud.google.com/anthos-config-management/docs/config-sync-overview)

## Support

### Documentation
- **Deployment Guide**: `docs/deployment/DEPLOYMENT_GUIDE.md`
- **Operations Guide**: `docs/operations/OPERATIONS.md`
- **Configuration Management**: `docs/deployment/CONFIG_MANAGEMENT.md`
- **Deployment Guard**: `docs/deployment/DEPLOYMENT_GUARD.md`

### Quick Help
```bash
# Show available commands
./scripts/help.sh

# Show site status
./scripts/site-status.sh --all

# Emergency rollback
./scripts/emergency-rollback.sh --reason="Production issue"
```

---
*Setup Guide | Version: 1.2.0 | Date: 2025-09-27 | Classification: Technical*