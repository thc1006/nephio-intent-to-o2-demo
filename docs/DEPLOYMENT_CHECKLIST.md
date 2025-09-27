# Deployment Checklist

**Nephio Intent-to-O2IMS Demo**
**Version**: v1.1.1
**Last Updated**: 2025-09-27

This comprehensive checklist covers all aspects of deployment, from pre-deployment requirements to post-deployment verification and rollback procedures.

---

## Table of Contents

1. [Pre-Deployment Requirements](#pre-deployment-requirements)
2. [VM-1 Orchestrator Deployment](#vm-1-orchestrator-deployment)
3. [Edge Site Deployment](#edge-site-deployment)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Rollback Procedures](#rollback-procedures)
6. [Troubleshooting](#troubleshooting)
7. [Appendices](#appendices)

---

## Pre-Deployment Requirements

### Hardware Requirements

#### VM-1 (Orchestrator)
- [ ] **CPU**: 8 cores (recommended) or 4 cores (minimum)
- [ ] **RAM**: 16GB (recommended) or 8GB (minimum)
- [ ] **Storage**: 100GB (recommended) or 50GB (minimum)
- [ ] **Network**: 1Gbps NIC
- [ ] **OS**: Ubuntu 22.04 LTS

#### Edge Sites (per site)
- [ ] **CPU**: 4 cores (recommended) or 2 cores (minimum)
- [ ] **RAM**: 8GB (recommended) or 4GB (minimum)
- [ ] **Storage**: 50GB (recommended) or 30GB (minimum)
- [ ] **Network**: 1Gbps NIC
- [ ] **OS**: Ubuntu 22.04 LTS

### Software Prerequisites

#### VM-1 Orchestrator
- [ ] Ubuntu 22.04 LTS installed and updated
- [ ] Python 3.11+ installed
- [ ] Docker 24.0+ installed and running
- [ ] Git 2.40+ installed
- [ ] kubectl 1.28+ installed
- [ ] kpt 1.0+ installed
- [ ] Claude Code CLI installed
- [ ] Network access to all edge sites

#### Edge Sites
- [ ] Ubuntu 22.04 LTS installed and updated
- [ ] Kubernetes 1.28+ installed (K3s recommended)
- [ ] Docker 24.0+ installed and running
- [ ] kubectl 1.28+ installed
- [ ] Network access to VM-1 orchestrator

### Network Requirements

#### VM-1 Orchestrator
- [ ] Static IP address assigned (e.g., 172.16.0.78)
- [ ] Firewall rules configured:
  - Port 8002 (Claude AI) - accessible from operator workstations
  - Port 8888 (Gitea) - accessible from edge sites
  - Port 9090 (Prometheus) - accessible from operator workstations
  - Port 3000 (Grafana) - accessible from operator workstations
  - Port 22 (SSH) - restricted to admin workstations

#### Edge Sites
- [ ] Static IP addresses assigned
- [ ] Firewall rules configured:
  - Port 22 (SSH) - accessible from VM-1
  - Port 6443 (K8s API) - accessible from VM-1
  - Port 31280 (O2IMS API) - accessible from VM-1
  - Port 30090 (Prometheus) - accessible from VM-1

#### Network Connectivity
- [ ] VM-1 can ping all edge sites
- [ ] Edge sites can ping VM-1
- [ ] Edge sites can resolve DNS names
- [ ] Internet connectivity available (for package downloads)

### Security Requirements

#### SSH Access
- [ ] SSH key pairs generated for VM-1 → Edge communication
  - `~/.ssh/id_ed25519` for edge1, edge2 (user: ubuntu)
  - `~/.ssh/edge_sites_key` for edge3, edge4 (user: thc1006)
- [ ] SSH keys deployed to all edge sites
- [ ] SSH configuration file created (`~/.ssh/config`)
- [ ] Password authentication disabled on edge sites

#### Authentication
- [ ] Gitea admin credentials secured
- [ ] Grafana admin password changed from default
- [ ] Kubernetes service account tokens generated
- [ ] Config Sync authentication configured

#### Certificates
- [ ] TLS certificates for Gitea (if using HTTPS)
- [ ] Kubernetes certificates valid
- [ ] O2IMS API certificates (if using HTTPS)

### Backup & Recovery
- [ ] Backup plan documented
- [ ] Backup storage location identified
- [ ] Restore procedures tested
- [ ] Disaster recovery plan in place

---

## VM-1 Orchestrator Deployment

### Step 1: System Preparation

#### 1.1 Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

#### 1.2 Install Dependencies
```bash
# Install Python 3.11
sudo apt install -y python3.11 python3.11-venv python3-pip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kpt
curl -L https://github.com/GoogleContainerTools/kpt/releases/download/v1.0.0-beta.49/kpt_linux_amd64 -o kpt
sudo install -o root -g root -m 0755 kpt /usr/local/bin/kpt

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code
```
- [ ] All dependencies installed successfully
- [ ] Versions verified

#### 1.3 Clone Repository
```bash
cd /home/ubuntu
git clone <repository-url> nephio-intent-to-o2-demo
cd nephio-intent-to-o2-demo
```
- [ ] Repository cloned successfully
- [ ] Correct branch checked out

### Step 2: Configure Network

#### 2.1 Configure Edge Sites
```bash
# Edit config/edge-sites-config.yaml
vi config/edge-sites-config.yaml
```

Example configuration:
```yaml
edge_sites:
  - name: edge1
    ip: 172.16.4.45
    user: ubuntu
    ssh_key: ~/.ssh/id_ed25519
    k8s_api_port: 6443
    o2ims_api_port: 31280
    prometheus_port: 30090

  - name: edge2
    ip: 172.16.4.176
    user: ubuntu
    ssh_key: ~/.ssh/id_ed25519
    k8s_api_port: 6443
    o2ims_api_port: 31280
    prometheus_port: 30090

  - name: edge3
    ip: 172.16.5.81
    user: thc1006
    ssh_key: ~/.ssh/edge_sites_key
    password: "1006"
    k8s_api_port: 6443
    o2ims_api_port: 31280
    prometheus_port: 30090

  - name: edge4
    ip: 172.16.1.252
    user: thc1006
    ssh_key: ~/.ssh/edge_sites_key
    password: "1006"
    k8s_api_port: 6443
    o2ims_api_port: 31280
    prometheus_port: 30090
```
- [ ] Configuration file updated
- [ ] IP addresses verified
- [ ] SSH credentials configured

#### 2.2 Configure SSH
```bash
# Configure SSH for edge sites
vi ~/.ssh/config
```

Example SSH configuration:
```
# Edge1 and Edge2 (user: ubuntu)
Host edge1
    HostName 172.16.4.45
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no

Host edge2
    HostName 172.16.4.176
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no

# Edge3 and Edge4 (user: thc1006)
Host edge3
    HostName 172.16.5.81
    User thc1006
    IdentityFile ~/.ssh/edge_sites_key
    StrictHostKeyChecking no

Host edge4
    HostName 172.16.1.252
    User thc1006
    IdentityFile ~/.ssh/edge_sites_key
    StrictHostKeyChecking no
```
- [ ] SSH config file created
- [ ] SSH connectivity tested to all edge sites

### Step 3: Deploy Core Services

#### 3.1 Deploy Gitea
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/deploy_gitea.sh
```

Verification:
```bash
# Check Gitea is running
curl http://localhost:8888/
```
- [ ] Gitea deployed successfully
- [ ] Gitea web UI accessible
- [ ] Admin account created

#### 3.2 Initialize Git Repositories
```bash
# Create repositories in Gitea
./scripts/init_gitea_repos.sh
```
- [ ] Base repository created
- [ ] Edge site repositories created
- [ ] Initial configurations pushed

#### 3.3 Deploy Prometheus
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/k8s/monitoring
kubectl apply -f prometheus/
```

Verification:
```bash
# Check Prometheus is running
curl http://localhost:9090/-/healthy
```
- [ ] Prometheus deployed successfully
- [ ] Prometheus web UI accessible
- [ ] Scrape targets configured

#### 3.4 Deploy Grafana
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/k8s/monitoring
kubectl apply -f grafana/
```

Verification:
```bash
# Check Grafana is running
curl http://localhost:3000/api/health
```
- [ ] Grafana deployed successfully
- [ ] Grafana web UI accessible
- [ ] Prometheus data source configured
- [ ] Dashboards imported

#### 3.5 Deploy TMF921 Adapter
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/adapter
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
./deploy.sh
```

Verification:
```bash
# Check adapter is running
curl http://localhost:8080/health
```
- [ ] Adapter deployed successfully
- [ ] Health endpoint responding
- [ ] Intent API accessible

#### 3.6 Deploy Claude AI Interface
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/start_claude_headless.sh
```

Verification:
```bash
# Check Claude interface is running
curl http://localhost:8002/
```
- [ ] Claude interface deployed
- [ ] Web UI accessible
- [ ] API key configured

#### 3.7 Deploy Porch
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/deploy_porch.sh
```

Verification:
```bash
# Check Porch is running
kubectl get pods -n porch-system
kubectl get repositories
```
- [ ] Porch deployed successfully
- [ ] CRDs installed
- [ ] Repository registered

### Step 4: Configure Integrations

#### 4.1 Configure Gitea-Porch Integration
```bash
# Register Gitea repository with Porch
./scripts/register_gitea_with_porch.sh
```
- [ ] Gitea repository registered
- [ ] Porch can access Gitea
- [ ] Authentication working

#### 4.2 Configure Prometheus Federation
```bash
# Configure federation for edge site metrics
vi k8s/monitoring/prometheus/prometheus.yaml
# Add federation scrape configs
kubectl apply -f k8s/monitoring/prometheus/
```
- [ ] Federation configured
- [ ] Edge site targets added

#### 4.3 Configure SLO Gates
```bash
# Deploy SLO gate configurations
kubectl apply -f templates/slo-gates/
```
- [ ] SLO gates deployed
- [ ] Thresholds configured
- [ ] Alert rules created

---

## Edge Site Deployment

### Step 1: Edge Site Preparation

For each edge site, perform the following steps:

#### 1.1 Install Kubernetes
```bash
# On edge site
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes
```
- [ ] K3s installed successfully
- [ ] Node in Ready state

#### 1.2 Configure kubectl Access
```bash
# On VM-1, copy kubeconfig from edge site
scp edge1:~/.kube/config ~/.kube/edge1-config
export KUBECONFIG=~/.kube/edge1-config
kubectl get nodes
```
- [ ] Kubeconfig retrieved
- [ ] kubectl can access edge cluster

### Step 2: Deploy Edge Components

#### 2.1 Deploy Config Sync
```bash
# On edge site
kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.17.0/config-sync-manifest.yaml

# Wait for Config Sync to be ready
kubectl wait --for=condition=ready pod -l app=config-sync -n config-management-system --timeout=300s
```
- [ ] Config Sync installed
- [ ] Config Sync pods running

#### 2.2 Configure Config Sync
```bash
# On VM-1, create Config Sync configuration
cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: http://172.16.0.78:8888/gitea_admin/edge1-config.git
    branch: main
    dir: config
    auth: none
    period: 15s
EOF
```
- [ ] RootSync configured
- [ ] Repository URL correct
- [ ] Sync working

#### 2.3 Deploy O2IMS
```bash
# On edge site
kubectl apply -f ~/o2ims-deployment/
```

Verification:
```bash
# Check O2IMS is running
kubectl get pods -n o2ims
curl http://localhost:31280/o2ims-infrastructureInventory/v1/api_versions
```
- [ ] O2IMS deployed
- [ ] API accessible
- [ ] Health check passing

#### 2.4 Deploy Prometheus
```bash
# On edge site
kubectl apply -f ~/prometheus-edge/
```

Verification:
```bash
# Check Prometheus is running
kubectl get pods -n monitoring
curl http://localhost:30090/-/healthy
```
- [ ] Prometheus deployed
- [ ] Metrics scraping
- [ ] Remote write configured (to VM-1)

### Step 3: Repeat for All Edge Sites

- [ ] Edge1 (172.16.4.45) - Deployed and verified
- [ ] Edge2 (172.16.4.176) - Deployed and verified
- [ ] Edge3 (172.16.5.81) - Deployed and verified
- [ ] Edge4 (172.16.1.252) - Deployed and verified

---

## Post-Deployment Verification

### Connectivity Verification

#### VM-1 → Edge Sites
```bash
# From VM-1
for edge in edge1 edge2 edge3 edge4; do
  echo "Testing $edge..."
  ssh $edge "echo 'SSH OK'"
  curl -s http://$edge:31280/o2ims-infrastructureInventory/v1/api_versions && echo "O2IMS OK"
  curl -s http://$edge:30090/-/healthy && echo "Prometheus OK"
done
```
- [ ] SSH connectivity verified for all edge sites
- [ ] O2IMS API accessible from all edge sites
- [ ] Prometheus accessible from all edge sites

#### Edge Sites → VM-1
```bash
# On each edge site
curl http://172.16.0.78:8888/ && echo "Gitea OK"
```
- [ ] Gitea accessible from all edge sites

### Service Verification

#### VM-1 Services
```bash
# Check all VM-1 services
curl http://172.16.0.78:8002/ && echo "Claude OK"
curl http://172.16.0.78:8888/ && echo "Gitea OK"
curl http://172.16.0.78:9090/-/healthy && echo "Prometheus OK"
curl http://172.16.0.78:3000/api/health && echo "Grafana OK"
```
- [ ] Claude AI interface responding
- [ ] Gitea responding
- [ ] Prometheus responding
- [ ] Grafana responding

#### Edge Site Services
```bash
# For each edge site
for edge in edge1 edge2 edge3 edge4; do
  echo "Checking $edge..."
  kubectl --context=$edge get pods --all-namespaces
done
```
- [ ] All pods running on edge1
- [ ] All pods running on edge2
- [ ] All pods running on edge3
- [ ] All pods running on edge4

### Config Sync Verification

```bash
# Check Config Sync status on each edge site
for edge in edge1 edge2 edge3 edge4; do
  echo "Checking Config Sync on $edge..."
  kubectl --context=$edge get rootsync -n config-management-system
  kubectl --context=$edge get configsync -n config-management-system
done
```
- [ ] Config Sync running on all edge sites
- [ ] Sync status is "SYNCED"
- [ ] No sync errors

### Metrics Verification

```bash
# Check Prometheus federation
curl 'http://172.16.0.78:9090/api/v1/query?query=up{job="federate"}'
```
- [ ] Edge site metrics visible in VM-1 Prometheus
- [ ] All edge site Prometheus targets up

### End-to-End Test

```bash
# Run complete E2E test
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/demo_llm.sh
```
- [ ] Intent submitted successfully
- [ ] KRM generated correctly
- [ ] Gitea PR created
- [ ] Config Sync deployed to edge sites
- [ ] SLO gates passed
- [ ] Deployment successful

---

## Rollback Procedures

### General Rollback Principles

1. **Identify the Issue**: Determine what needs to be rolled back
2. **Check Impact**: Assess which components are affected
3. **Execute Rollback**: Follow appropriate procedure below
4. **Verify Rollback**: Confirm system is stable
5. **Document**: Record what happened and why

### Rollback Scenarios

#### Scenario 1: Config Sync Rollback

**When**: Config Sync deployed bad configuration to edge sites

**Procedure**:
```bash
# On VM-1, revert Git commit
cd /path/to/edge-config-repo
git revert HEAD
git push origin main

# Config Sync will automatically sync the revert
# Wait 15 seconds (Config Sync poll interval)

# Verify on edge sites
for edge in edge1 edge2 edge3 edge4; do
  kubectl --context=$edge get rootsync -n config-management-system
done
```
- [ ] Git commit reverted
- [ ] Config Sync re-synced
- [ ] Edge sites back to previous state

#### Scenario 2: SLO Gate Rollback

**When**: SLO gate detects violation and triggers automatic rollback

**Procedure**:
```bash
# Check SLO gate status
kubectl get slogates -n slo-system

# View rollback logs
kubectl logs -n slo-system -l app=slo-gate

# Manual rollback if automatic failed
cd /path/to/edge-config-repo
git reset --hard HEAD~1
git push --force origin main
```
- [ ] SLO violation identified
- [ ] Automatic rollback triggered
- [ ] Previous configuration restored
- [ ] SLO compliance verified

#### Scenario 3: Edge Site Rollback

**When**: Specific edge site has issues, others are fine

**Procedure**:
```bash
# Stop Config Sync on affected edge site
kubectl --context=edge1 delete rootsync root-sync -n config-management-system

# Manually restore previous configuration
kubectl --context=edge1 apply -f backup/edge1-config/

# Re-enable Config Sync
kubectl --context=edge1 apply -f templates/configsync-root.yaml
```
- [ ] Config Sync stopped on affected site
- [ ] Previous configuration restored
- [ ] Edge site stable
- [ ] Config Sync re-enabled

#### Scenario 4: Complete System Rollback

**When**: Major issue requires rolling back all components

**Procedure**:
```bash
# 1. Stop all Config Sync instances
for edge in edge1 edge2 edge3 edge4; do
  kubectl --context=$edge delete rootsync root-sync -n config-management-system
done

# 2. Revert Gitea to previous commit
cd /path/to/all-repos
git revert HEAD
git push origin main

# 3. Restore VM-1 services from backup
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/restore_from_backup.sh <backup-date>

# 4. Re-enable Config Sync
for edge in edge1 edge2 edge3 edge4; do
  kubectl --context=$edge apply -f templates/configsync-root.yaml
done
```
- [ ] All Config Sync stopped
- [ ] Gitea reverted
- [ ] VM-1 services restored
- [ ] Config Sync re-enabled
- [ ] System stable

### Rollback Verification

After any rollback:
```bash
# 1. Verify services
./scripts/health_check.sh

# 2. Check SLO compliance
./scripts/check_slo.sh

# 3. Verify metrics
curl 'http://172.16.0.78:9090/api/v1/query?query=up'

# 4. Run smoke tests
cd tests/
pytest test_smoke.py -v
```
- [ ] All services running
- [ ] SLO compliance achieved
- [ ] Metrics collecting
- [ ] Smoke tests passing

---

## Troubleshooting

### Common Issues

#### Issue 1: Config Sync Not Syncing

**Symptoms**:
- RootSync status shows errors
- Edge sites not receiving configurations

**Diagnosis**:
```bash
kubectl --context=edge1 get rootsync -n config-management-system -o yaml
kubectl --context=edge1 logs -n config-management-system -l app=reconciler
```

**Resolution**:
```bash
# Check Git repository accessibility
ssh edge1 "curl http://172.16.0.78:8888/gitea_admin/edge1-config.git"

# Verify RootSync configuration
kubectl --context=edge1 describe rootsync root-sync -n config-management-system

# Delete and recreate RootSync
kubectl --context=edge1 delete rootsync root-sync -n config-management-system
kubectl --context=edge1 apply -f templates/configsync-root.yaml
```

#### Issue 2: SLO Gate False Positives

**Symptoms**:
- SLO gate triggers rollback unnecessarily
- Metrics show acceptable performance

**Diagnosis**:
```bash
# Check SLO gate thresholds
kubectl get slogate -n slo-system -o yaml

# Check actual metrics
curl 'http://172.16.0.78:9090/api/v1/query?query=<slo_metric>'
```

**Resolution**:
```bash
# Adjust SLO thresholds
kubectl edit slogate <slogate-name> -n slo-system

# Or update threshold in Git and sync
vi templates/slo-gates/<slogate-name>.yaml
git commit -am "Adjust SLO threshold"
git push
```

#### Issue 3: O2IMS API Not Responding

**Symptoms**:
- O2IMS API returns 500 errors or timeouts
- O2IMS pods crashlooping

**Diagnosis**:
```bash
kubectl --context=edge1 get pods -n o2ims
kubectl --context=edge1 logs -n o2ims <o2ims-pod>
```

**Resolution**:
```bash
# Restart O2IMS
kubectl --context=edge1 rollout restart deployment o2ims -n o2ims

# Check O2IMS configuration
kubectl --context=edge1 get configmap o2ims-config -n o2ims -o yaml

# Verify database connectivity (if applicable)
kubectl --context=edge1 exec -it <o2ims-pod> -n o2ims -- curl <database-url>
```

For more troubleshooting guidance, see:
- **[TROUBLESHOOTING.md](operations/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide

---

## Appendices

### Appendix A: Port Reference

| Component | Port | Protocol | Access From |
|-----------|------|----------|-------------|
| **VM-1** |
| Claude AI | 8002 | HTTP | Operator workstations |
| Gitea | 8888 | HTTP | Edge sites, Operators |
| Prometheus | 9090 | HTTP | Operators |
| Grafana | 3000 | HTTP | Operators |
| SSH | 22 | SSH | Admin workstations |
| **Edge Sites** |
| SSH | 22 | SSH | VM-1 |
| K8s API | 6443 | HTTPS | VM-1 |
| O2IMS API | 31280 | HTTP | VM-1 |
| Prometheus | 30090 | HTTP | VM-1 |

### Appendix B: Default Credentials

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| Gitea | gitea_admin | r8sA8CPHD9!bt6d | Change after first login |
| Grafana | admin | admin | Change after first login |
| Edge3/Edge4 SSH | thc1006 | 1006 | Use SSH key authentication |

### Appendix C: Important File Locations

| File/Directory | Location | Purpose |
|----------------|----------|---------|
| Edge Sites Config | `/home/ubuntu/nephio-intent-to-o2-demo/config/edge-sites-config.yaml` | Edge site definitions |
| SSH Config | `~/.ssh/config` | SSH connection details |
| SSH Keys | `~/.ssh/id_ed25519`, `~/.ssh/edge_sites_key` | Authentication keys |
| Gitea Data | `/var/lib/gitea/` | Git repositories |
| Prometheus Data | `/var/lib/prometheus/` | Metrics storage |
| Logs | `/var/log/nephio/` | Application logs |

### Appendix D: Health Check Commands

```bash
# VM-1 Health Check
./scripts/health_check_vm1.sh

# Edge Site Health Check
./scripts/health_check_edge.sh edge1

# Complete System Health Check
./scripts/health_check_all.sh
```

### Appendix E: Backup Commands

```bash
# Backup VM-1
./scripts/backup_vm1.sh

# Backup Edge Site
./scripts/backup_edge.sh edge1

# Backup All
./scripts/backup_all.sh
```

### Appendix F: Useful Links

- **Project Documentation**: `/home/ubuntu/nephio-intent-to-o2-demo/docs/DOCUMENTATION_INDEX.md`
- **Troubleshooting Guide**: `/home/ubuntu/nephio-intent-to-o2-demo/docs/operations/TROUBLESHOOTING.md`
- **Architecture Documentation**: `/home/ubuntu/nephio-intent-to-o2-demo/docs/architecture/`
- **HOW TO USE Guide**: `/home/ubuntu/nephio-intent-to-o2-demo/HOW_TO_USE.md`

---

**Deployment Checklist Version**: 1.0
**Last Updated**: 2025-09-27
**Maintained By**: Deployment Team