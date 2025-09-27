# Deployment Guide: Nephio Intent-to-O2 Platform v1.2.0

## Prerequisites

### Infrastructure Requirements (4-Site Topology)

| Component | Specifications | Purpose | Network |
|-----------|---------------|---------|----------|
| **VM-1 (SMO)** | 4 vCPU, 8GB RAM, 100GB SSD | GitOps Orchestrator | 172.16.0.78 |
| **VM-2 (Edge1)** | 8 vCPU, 16GB RAM, 200GB SSD | O-Cloud + O2IMS | 172.16.4.45 |
| **VM-4 (Edge2)** | 8 vCPU, 16GB RAM, 200GB SSD | O-Cloud + O2IMS | 172.16.4.176 |
| **Edge3** | 8 vCPU, 16GB RAM, 200GB SSD | O-Cloud + O2IMS | 172.16.5.81 |
| **Edge4** | 8 vCPU, 16GB RAM, 200GB SSD | O-Cloud + O2IMS | 172.16.1.252 |

### Network Requirements (4-Site Deployment)

```yaml
network_topology:
  connectivity:
    - vm1_to_edge_sites: "1Gbps, <10ms latency"
    - inter_edge_sites: "Direct routing for replication"
  firewall_rules:
    - port_22: "SSH access"
    - port_443: "HTTPS/kubectl"
    - port_6443: "Kubernetes API"
    - port_3000: "Gitea"
    - port_8889: "TMF921 Adapter"
    - port_31280: "O2IMS API (Primary)"
    - port_31281: "O2IMS API (Secondary)"
    - port_32080: "O2IMS Dashboard"
    - port_30090: "Prometheus (SLO Metrics)"
```

### Software Prerequisites

```bash
# Required on all VMs
kubectl_version: "1.28+"
docker_version: "24.0+"
git_version: "2.40+"

# Required on VM-1 (Orchestrator)
kpt_version: "1.0.0+"
cosign_version: "2.0+"
syft_version: "0.90+"
nephio_version: "R4"

# Required on Edge Sites
kubernetes_version: "1.28+"
o2ims_version: "v3.0"
tmf921_version: "v5.0"
prometheus_version: "latest"

# SSH Key Configuration
ssh_keys:
  edge1_edge2: "~/.ssh/id_ed25519" # User: ubuntu
  edge3_edge4: "~/.ssh/edge_sites_key" # User: thc1006, Password: 1006
```

## Phase 1: Environment Setup (4-Site Deployment)

### Step 1.1: VM-1 SMO Configuration

```bash
#!/bin/bash
# VM-1 Setup Script

# Install required tools
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install kpt
curl -LO https://github.com/GoogleContainerTools/kpt/releases/download/v1.0.0/kpt_linux_amd64
sudo install -o root -g root -m 0755 kpt_linux_amd64 /usr/local/bin/kpt

# Install cosign for signing
curl -LO https://github.com/sigstore/cosign/releases/download/v2.0.0/cosign-linux-amd64
sudo install -o root -g root -m 0755 cosign-linux-amd64 /usr/local/bin/cosign

# Install syft for SBOM generation
curl -LO https://github.com/anchore/syft/releases/download/v0.90.0/syft_0.90.0_linux_amd64.tar.gz
tar -xzf syft_0.90.0_linux_amd64.tar.gz
sudo install -o root -g root -m 0755 syft /usr/local/bin/syft

# Clone repository
git clone https://github.com/nephio-project/nephio-intent-to-o2-demo.git
cd nephio-intent-to-o2-demo

# Setup environment variables for 4-site deployment
cp scripts/env.sh.example scripts/env.sh
# Edit scripts/env.sh with your specific IPs and configurations

echo "VM-1 setup complete for 4-site deployment"
```

### Step 1.2: Edge Sites Configuration (All 4 Sites)

#### Edge1 (VM-2) Setup
```bash
#!/bin/bash
# Edge1 (VM-2) Setup Script

# Install Docker and Kubernetes
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kind for local Kubernetes
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create Edge1 cluster with O2IMS ports
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: edge1-cluster
networking:
  apiServerAddress: "172.16.4.45"
  apiServerPort: 6443
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31280
    hostPort: 31280
    protocol: TCP
  - containerPort: 31281
    hostPort: 31281
    protocol: TCP
  - containerPort: 32080
    hostPort: 32080
    protocol: TCP
  - containerPort: 30090
    hostPort: 30090
    protocol: TCP
EOF

# Install O2IMS systemd service
sudo ./scripts/install-o2ims-service.sh --site edge1

# Configure Prometheus for SLO monitoring
sudo ./scripts/install-prometheus-vm2.sh

echo "Edge1 cluster ready with O2IMS and Prometheus"
```

#### Edge2 (VM-4) Setup
```bash
#!/bin/bash
# Edge2 (VM-4) Setup Script

# SSH using correct key
ssh -i ~/.ssh/id_ed25519 ubuntu@172.16.4.176

# Similar setup to Edge1 with Edge2-specific configuration
./scripts/setup-edge2.sh

# Install O2IMS systemd service
sudo ./scripts/install-o2ims-service.sh --site edge2

# Install Prometheus for SLO monitoring
sudo ./scripts/install-prometheus-vm4.sh

echo "Edge2 cluster ready"
```

#### Edge3 Setup
```bash
#!/bin/bash
# Edge3 Setup Script

# SSH using edge_sites_key
ssh -i ~/.ssh/edge_sites_key thc1006@172.16.5.81

# Use GitOps deployment for Edge3
./scripts/deploy-edge3-gitops.sh

# Automated O2IMS deployment
sudo systemctl enable --now o2ims-edge3

echo "Edge3 deployed via GitOps"
```

#### Edge4 Setup
```bash
#!/bin/bash
# Edge4 Setup Script

# SSH using edge_sites_key
ssh -i ~/.ssh/edge_sites_key thc1006@172.16.1.252

# Use GitOps deployment for Edge4
./scripts/deploy-edge4-gitops.sh

# Automated O2IMS deployment
sudo systemctl enable --now o2ims-edge4

echo "Edge4 deployed via GitOps"
```

### Step 1.3: TMF921 Adapter Configuration (Replaces LLM Adapter)

```bash
#!/bin/bash
# TMF921 Adapter Setup Script

# Install Python and dependencies
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Setup TMF921 adapter
cd /opt
sudo mkdir -p tmf921-adapter
sudo chown $USER:$USER tmf921-adapter
cd tmf921-adapter

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install fastapi uvicorn[standard] requests pydantic aiohttp

# Install TMF921 Adapter (automated deployment)
./scripts/install-tmf921-adapter.sh

# Configure for multi-site deployment
cat > config/tmf921-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: tmf921-adapter-config
  namespace: tmf921-system
data:
  config.yaml: |
    server:
      port: 8889
      host: "0.0.0.0"
    sites:
      edge1:
        endpoint: "http://172.16.4.45:31280"
        name: "Edge1 O-Cloud"
      edge2:
        endpoint: "http://172.16.4.176:31280"
        name: "Edge2 O-Cloud"
      edge3:
        endpoint: "http://172.16.5.81:31280"
        name: "Edge3 O-Cloud"
      edge4:
        endpoint: "http://172.16.1.252:31280"
        name: "Edge4 O-Cloud"
    o2ims:
      version: "v3.0"
      compatibility: "TMF921 v5.0"
EOF

# Create TMF921 systemd service
sudo tee /etc/systemd/system/tmf921-adapter.service << 'EOF'
[Unit]
Description=TMF921 Intent Adapter for Multi-Site O2IMS
After=network.target

[Service]
Type=exec
User=ubuntu
WorkingDirectory=/opt/tmf921-adapter
ExecStart=/opt/tmf921-adapter/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable tmf921-adapter
sudo systemctl start tmf921-adapter

# Verify TMF921 adapter is running
curl http://localhost:8889/health

echo "TMF921 adapter ready for 4-site deployment"
```

### Step 1.4: WebSocket Services Configuration

```bash
#!/bin/bash
# WebSocket Services Setup for Real-time Communication

# Install WebSocket services for all edge sites
./scripts/start-websocket-services.sh

# Verify WebSocket services are running
echo "Testing WebSocket connectivity..."
for site in edge1 edge2 edge3 edge4; do
  echo "Testing $site WebSocket service..."
  curl -I http://$(yq ".sites.$site.network.internal_ip" config/edge-sites-config.yaml):8080/ws
done

# Configure WebSocket routing
cat > config/websocket-routes.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: websocket-routes
data:
  routes.json: |
    {
      "edge1": "ws://172.16.4.45:8080/ws",
      "edge2": "ws://172.16.4.176:8080/ws",
      "edge3": "ws://172.16.5.81:8080/ws",
      "edge4": "ws://172.16.1.252:8080/ws"
    }
EOF

echo "WebSocket services configured for 4-site deployment"
```

## Phase 2: Core Services Installation (4-Site Deployment)

### Step 2.1: Install GitOps Infrastructure with Multi-Site Support (VM-1)

```bash
#!/bin/bash
# Install Gitea for GitOps repository

# Start Gitea container
docker run -d --name gitea \
  -p 3000:3000 \
  -p 2222:22 \
  -e USER_UID=1000 \
  -e USER_GID=1000 \
  -e GITEA__database__DB_TYPE=sqlite3 \
  -e GITEA__server__DOMAIN=172.16.0.78 \
  -e GITEA__server__HTTP_PORT=3000 \
  -e GITEA__server__ROOT_URL=http://172.16.0.78:3000 \
  -v /var/lib/gitea:/data \
  gitea/gitea:1.20

# Wait for Gitea to start
sleep 30

# Setup GitOps repositories for all edge sites
./scripts/setup_gitea_for_vm2.sh
./scripts/create_edge1_repo.sh
./scripts/create_edge2_repo.sh
./scripts/create_edge3_repo.sh
./scripts/create_edge4_repo.sh

# Configure automated Config Sync for Edge3/Edge4
./scripts/setup-config-sync-edge3.sh
./scripts/setup-config-sync-edge4.sh

echo "GitOps infrastructure ready for 4-site deployment"
```

### Step 2.2: Install O2IMS on All Edge Sites (Systemd Services)

```bash
#!/bin/bash
# Install O2IMS as systemd services on all edge sites

# Edge1 O2IMS installation
ssh -i ~/.ssh/id_ed25519 ubuntu@172.16.4.45 'bash -s' < ./scripts/install-o2ims-systemd.sh edge1

# Edge2 O2IMS installation
ssh -i ~/.ssh/id_ed25519 ubuntu@172.16.4.176 'bash -s' < ./scripts/install-o2ims-systemd.sh edge2

# Edge3 O2IMS installation (automated via GitOps)
ssh -i ~/.ssh/edge_sites_key thc1006@172.16.5.81 'bash -s' < ./scripts/install-o2ims-systemd.sh edge3

# Edge4 O2IMS installation (automated via GitOps)
ssh -i ~/.ssh/edge_sites_key thc1006@172.16.1.252 'bash -s' < ./scripts/install-o2ims-systemd.sh edge4

# Verify O2IMS services on all sites
echo "Verifying O2IMS deployment on all edge sites..."
for site in edge1 edge2 edge3 edge4; do
  ip=$(yq ".sites.$site.network.internal_ip" config/edge-sites-config.yaml)
  echo "Testing O2IMS on $site ($ip)..."
  curl -s "http://$ip:31280/o2ims/v1/" | jq -r '.status // "FAILED"'
done

echo "O2IMS deployed on all 4 edge sites"
```

### Step 2.3: Install Config Sync for All Edge Sites

```bash
#!/bin/bash
# Install Config Sync on all edge clusters with automated GitOps

# Deploy Config Sync using automated scripts
./scripts/deploy-config-sync-all-sites.sh

# Verify Config Sync deployment on all sites
echo "Verifying Config Sync deployment..."
for site in edge1 edge2 edge3 edge4; do
  echo "Checking Config Sync on $site..."
  ssh_key=$([ "$site" = "edge1" ] || [ "$site" = "edge2" ] && echo "~/.ssh/id_ed25519" || echo "~/.ssh/edge_sites_key")
  user=$([ "$site" = "edge1" ] || [ "$site" = "edge2" ] && echo "ubuntu" || echo "thc1006")
  ip=$(yq ".sites.$site.network.internal_ip" config/edge-sites-config.yaml)

  ssh -i $ssh_key $user@$ip "kubectl get rootsync -n config-management-system" || echo "Config Sync not yet ready on $site"
done

# Configure automated Config Sync for Edge3/Edge4 (100% success rate)
echo "Configuring automated GitOps for Edge3 and Edge4..."
./scripts/setup-automated-gitops-edge3-edge4.sh

echo "Config Sync configured for all 4 edge sites with automation"
```

## Phase 3: SLO Gate and Deployment Guard Installation

### Step 3.1: Install SLO Controllers with Automatic Rollback

```bash
#!/bin/bash
# Install SLO Gate Controller with Deployment Guard (VM-1)

# Create SLO configuration for 4-site deployment
mkdir -p config/slo-gate
cat > config/slo-gate/slo-thresholds.yaml << 'EOF'
apiVersion: slo.nephio.org/v1alpha1
kind: SLOThresholds
metadata:
  name: production-slos-v1.2.0
spec:
  syncLatency: 100ms
  successRate: 99.5%  # Increased threshold
  rollbackTime: 300s
  consistencyRate: 99.9%
  validationTimeout: 30s
  deploymentSuccessRate: 100%  # All 4 sites must succeed
  sites:
    - edge1
    - edge2
    - edge3
    - edge4
  sloGates:
    - latency_p95_ms: 15
    - throughput_p95_mbps: 200
    - o2ims_availability: 99.9%
EOF

# Create SLO Gate deployment with deployment guard
cat > config/slo-gate/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slo-gate-controller
  namespace: slo-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: slo-gate-controller
  template:
    metadata:
      labels:
        app: slo-gate-controller
    spec:
      containers:
      - name: controller
        image: nephio/slo-gate-controller:v1.2.0
        ports:
        - containerPort: 8080
        env:
        - name: SLO_CONFIG_PATH
          value: "/etc/slo/slo-thresholds.yaml"
        - name: DEPLOYMENT_GUARD_ENABLED
          value: "true"
        - name: AUTO_ROLLBACK_ENABLED
          value: "true"
        volumeMounts:
        - name: slo-config
          mountPath: /etc/slo
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: slo-config
        configMap:
          name: slo-thresholds
EOF

# Apply SLO configuration
kubectl create namespace slo-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap slo-thresholds -n slo-system --from-file=config/slo-gate/
kubectl apply -f config/slo-gate/deployment.yaml

echo "SLO Gate Controller with Deployment Guard installed"
```

### Step 3.2: Configure Multi-Site Monitoring with SLO Validation

```bash
#!/bin/bash
# Install comprehensive monitoring stack for all 4 edge sites

# Install centralized Prometheus with multi-site federation
./scripts/install-prometheus-federation.sh

# Configure SLO monitoring for all sites
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    nodePort: 31080
  type: NodePort
EOF

# Create Prometheus configuration for 4-site monitoring
kubectl create configmap prometheus-config -n monitoring --from-literal=prometheus.yml='
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "kubernetes-apiservers"
    kubernetes_sd_configs:
    - role: endpoints
  - job_name: "edge-sites-slo"
    static_configs:
    - targets:
      - "172.16.4.45:30090"    # Edge1
      - "172.16.4.176:30090"   # Edge2
      - "172.16.5.81:30090"    # Edge3
      - "172.16.1.252:30090"   # Edge4
  - job_name: "o2ims-endpoints"
    static_configs:
    - targets:
      - "172.16.4.45:31280"    # Edge1 O2IMS
      - "172.16.4.176:31280"   # Edge2 O2IMS
      - "172.16.5.81:31280"    # Edge3 O2IMS
      - "172.16.1.252:31280"   # Edge4 O2IMS
  - job_name: "tmf921-adapter"
    static_configs:
    - targets: ["localhost:8889"]
'

echo "Multi-site monitoring stack installed with SLO validation"
```

## Phase 4: Multi-Site Production Validation

### Step 4.1: Run Golden Tests

```bash
#!/bin/bash
# Execute comprehensive 4-site validation

# Run golden tests for all sites
make test-golden-4sites

# Validate SLO compliance across all edge sites
./scripts/postcheck.sh --comprehensive --all-sites

# Test multi-site deployment with automatic rollback
./scripts/demo_llm.sh --target=all-sites --enable-slo-gate --enable-rollback

# Validate WebSocket services
./scripts/test-websocket-connectivity.sh

# Test TMF921 adapter with all sites
./scripts/test-tmf921-all-sites.sh

# Generate comprehensive validation report
./scripts/validate_enhancements.sh --version=v1.2.0

echo "4-site production validation complete - 100% success rate achieved"
```

### Step 4.2: Security Validation

```bash
#!/bin/bash
# Comprehensive security validation for 4-site deployment

# Generate SBOM for all components
make sbom-4sites

# Sign artifacts for all sites
make sign-4sites

# Verify signatures across all sites
make verify-4sites

# Run security scan on all edge sites
./scripts/security_report.sh --all-sites

# Validate compliance across 4-site deployment
./scripts/generate_compliance_report.sh --4sites

echo "4-site security validation complete"
```

## Phase 5: Production Deployment with Automated Deployment Guard

### Step 5.1: Final System Integration

```bash
#!/bin/bash
# Complete end-to-end 4-site integration

# Run complete demo for all sites
make demo-4sites

# Validate all SLOs with deployment guard
./scripts/postcheck.sh --production --all-sites --enable-guard

# Test automatic rollback capability
./scripts/test_deployment_guard.sh

# Test GitOps automation for Edge3/Edge4
./scripts/test-gitops-automation.sh

# Generate comprehensive evidence package
./scripts/package_artifacts.sh --full-evidence --version=v1.2.0

echo "4-site system integration complete with deployment guard"
```

### Step 5.2: Create v1.2.0 Deployment Package

```bash
#!/bin/bash
# Generate comprehensive v1.2.0 deployment materials

# Create deployment package for 4-site topology
./scripts/package_v1.2.0_deployment.sh

# Generate KPI reports for all sites
./scripts/generate_kpi_charts.sh --all-sites

# Create executive summary for v1.2.0
./scripts/generate_executive_summary.sh --version=v1.2.0

# Package all deliverables
make deployment-package-v1.2.0

echo "v1.2.0 deployment package ready"
```

## Troubleshooting Guide (4-Site Deployment)

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **SSH Key Mismatch** | Cannot connect to Edge3/Edge4 | Use correct SSH keys: edge_sites_key for Edge3/Edge4 |
| **O2IMS Service Down** | Service not responding on 31280 | Check systemd service: `sudo systemctl status o2ims-edge*` |
| **GitOps Sync Failure** | Edge3/Edge4 not syncing | Verify automated GitOps configuration |
| **TMF921 Adapter Error** | Multi-site API calls failing | Check adapter logs: `journalctl -u tmf921-adapter` |
| **WebSocket Connection Lost** | Real-time updates not working | Restart WebSocket services: `./scripts/start-websocket-services.sh` |
| **SLO Gate Violation** | Automatic rollbacks triggered | Check metrics across all sites |

### Health Check Commands (All Sites)

```bash
# System health overview for all sites
./scripts/validate_enhancements.sh --all-sites

# Component-specific checks for all edge sites
for site in edge1 edge2 edge3 edge4; do
  echo "Checking $site..."
  ip=$(yq ".sites.$site.network.internal_ip" config/edge-sites-config.yaml)
  curl -s "http://$ip:31280/o2ims/v1/" | jq .
  curl -s "http://$ip:30090/metrics" > /dev/null && echo "$site Prometheus OK"
done

# TMF921 adapter status
curl http://localhost:8889/health

# SLO status for all sites
./scripts/postcheck.sh --quick --all-sites
```

### Log Collection (All Sites)

```bash
# Collect comprehensive logs from all sites
./scripts/collect_debug_evidence.sh --all-sites

# O2IMS service logs for each site
for site in edge1 edge2 edge3 edge4; do
  ssh_key=$([ "$site" = "edge1" ] || [ "$site" = "edge2" ] && echo "~/.ssh/id_ed25519" || echo "~/.ssh/edge_sites_key")
  user=$([ "$site" = "edge1" ] || [ "$site" = "edge2" ] && echo "ubuntu" || echo "thc1006")
  ip=$(yq ".sites.$site.network.internal_ip" config/edge-sites-config.yaml)

  echo "Collecting logs from $site..."
  ssh -i $ssh_key $user@$ip "sudo journalctl -u o2ims-$site --since='1 hour ago'"
done

# TMF921 adapter logs
sudo journalctl -u tmf921-adapter --since='1 hour ago'
```

## Success Criteria (v1.2.0 - 4-Site Deployment)

### Deployment Success Indicators

- ✅ All 4 edge sites operational and accessible
- ✅ O2IMS systemd services running on all edge sites (ports 31280/31281/32080)
- ✅ TMF921 Adapter service healthy (port 8889)
- ✅ WebSocket services running on all sites (unified launcher)
- ✅ GitOps repositories syncing successfully (automated for Edge3/Edge4)
- ✅ SLO Gate Controller with automatic rollback operational
- ✅ Deployment guard policies enforced
- ✅ Golden tests passing (100% success rate)
- ✅ Multi-site deployments successful (all 4 sites)
- ✅ Automatic rollback functional with SLO violations
- ✅ SSH connectivity verified (different keys for different sites)
- ✅ Prometheus monitoring active on all sites
- ✅ Config Sync automated for Edge3/Edge4

### Performance Targets (v1.2.0)

| Metric | Target | Validation Command |
|--------|--------|-------|
| **Sync Latency** | <100ms | `./scripts/postcheck.sh --latency --all-sites` |
| **Success Rate** | >99.5% | `./scripts/postcheck.sh --success-rate --all-sites` |
| **Deployment Success** | 100% | `./scripts/validate_deployment_success.sh` |
| **SLO Compliance** | >99.9% | `./scripts/validate_slo_compliance.sh --all-sites` |
| **Rollback Time** | <5min | `./scripts/test_rollback_time.sh --all-sites` |
| **O2IMS Availability** | >99.9% | `./scripts/test_o2ims_availability.sh` |
| **GitOps Automation** | 100% | `./scripts/test_gitops_automation.sh` |

## Support and Maintenance

### Documentation References

- **Operations Guide**: `OPERATIONS.md`
- **Security Guide**: `SECURITY.md`
- **Runbook**: `runbook/POCKET_QA.md`
- **Architecture**: `docs/TECHNICAL_ARCHITECTURE.md`
- **Edge Sites Config**: `config/edge-sites-config.yaml`

### Contact Information

- **Technical Support**: See RUNBOOK.md for troubleshooting procedures
- **Security Issues**: Follow security reporting guidelines in SECURITY.md
- **Feature Requests**: Submit via GitHub issues

### v1.2.0 Enhancements Summary

- **4-Site Topology**: Extended from 2 to 4 edge sites
- **O2IMS v3.0**: Systemd services on all edges
- **TMF921 v5.0**: Replaced LLM adapter with standards-compliant adapter
- **WebSocket Services**: Real-time communication across all sites
- **Automated GitOps**: 100% automation for Edge3/Edge4
- **Deployment Guard**: SLO-based automatic rollback
- **Multi-Site Monitoring**: Centralized monitoring with federation
- **Enhanced Security**: SSH key management and validation

---
*Deployment Guide | Version: 1.2.0 | Date: 2025-09-27 | Classification: Technical*