# Deployment Guide: Nephio Intent-to-O2 Platform

## Prerequisites

### Infrastructure Requirements

| Component | Specifications | Purpose |
|-----------|---------------|---------|
| **VM-1 (SMO)** | 4 vCPU, 8GB RAM, 100GB SSD | GitOps Orchestrator |
| **VM-2 (Edge1)** | 8 vCPU, 16GB RAM, 200GB SSD | O-Cloud + O2IMS |
| **VM-3 (LLM)** | 2 vCPU, 4GB RAM, 50GB SSD | Intent Adapter |
| **VM-4 (Edge2)** | 8 vCPU, 16GB RAM, 200GB SSD | O-Cloud + O2IMS |

### Network Requirements

```yaml
network_topology:
  connectivity:
    - vm1_to_vm2: "1Gbps, <10ms latency"
    - vm1_to_vm3: "1Gbps, <10ms latency"
    - vm1_to_vm4: "1Gbps, <10ms latency"
    - vm2_to_vm4: "1Gbps, <10ms latency"
  firewall_rules:
    - port_22: "SSH access"
    - port_443: "HTTPS/kubectl"
    - port_6443: "Kubernetes API"
    - port_3000: "Gitea"
    - port_8888: "LLM Adapter"
    - port_31280: "O2IMS API"
```

### Software Prerequisites

```bash
# Required on all VMs
kubectl_version: "1.28+"
docker_version: "24.0+"
git_version: "2.40+"

# Required on VM-1
kpt_version: "1.0.0+"
cosign_version: "2.0+"
syft_version: "0.90+"

# Required on VM-2, VM-4
kubernetes_version: "1.28+"
```

## Phase 1: Environment Setup

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

# Setup environment variables
cp scripts/env.sh.example scripts/env.sh
# Edit scripts/env.sh with your specific IPs and configurations

echo "VM-1 setup complete"
```

### Step 1.2: VM-2 Edge1 Configuration

```bash
#!/bin/bash
# VM-2 Edge1 Setup Script

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kind for local Kubernetes
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create Kubernetes cluster
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
  - containerPort: 31080
    hostPort: 31080
    protocol: TCP
EOF

# Verify cluster
kubectl cluster-info

echo "VM-2 Edge1 cluster ready"
```

### Step 1.3: VM-3 LLM Adapter Configuration

```bash
#!/bin/bash
# VM-3 LLM Adapter Setup Script

# Install Python and dependencies
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Setup LLM adapter
cd /opt
sudo mkdir -p llm-adapter
sudo chown $USER:$USER llm-adapter
cd llm-adapter

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install fastapi uvicorn[standard] requests pydantic

# Create LLM adapter service
cat > app.py << 'EOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import json
import logging

app = FastAPI(title="Nephio LLM Intent Adapter")

class TMF921Intent(BaseModel):
    intentExpectationType: str
    targetSite: str
    serviceType: str

class TS28312Expectation(BaseModel):
    expectationType: str
    expectationTargets: list
    expectationContexts: list

@app.post("/api/intent-to-28312", response_model=TS28312Expectation)
async def translate_intent(intent: TMF921Intent):
    """Translate TMF921 intent to 3GPP TS 28.312 expectation"""

    # Context-aware translation logic
    expectation = {
        "expectationType": f"{intent.serviceType}SliceExpectation",
        "expectationTargets": [
            {
                "targetName": f"{intent.targetSite}-slice",
                "targetCondition": "operational"
            }
        ],
        "expectationContexts": [
            {
                "contextAttribute": "site",
                "contextValue": intent.targetSite
            },
            {
                "contextAttribute": "serviceType",
                "contextValue": intent.serviceType
            }
        ]
    }

    return TS28312Expectation(**expectation)

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "llm-adapter"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8888)
EOF

# Create systemd service
sudo tee /etc/systemd/system/llm-adapter.service << 'EOF'
[Unit]
Description=Nephio LLM Intent Adapter
After=network.target

[Service]
Type=exec
User=ubuntu
WorkingDirectory=/opt/llm-adapter
ExecStart=/opt/llm-adapter/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable llm-adapter
sudo systemctl start llm-adapter

echo "VM-3 LLM adapter ready"
```

### Step 1.4: VM-4 Edge2 Configuration

```bash
#!/bin/bash
# VM-4 Edge2 Setup Script (similar to VM-2)

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create Edge2 cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: edge2-cluster
networking:
  apiServerAddress: "172.16.4.46"  # Adjust IP as needed
  apiServerPort: 6443
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31280
    hostPort: 31280
    protocol: TCP
  - containerPort: 31080
    hostPort: 31080
    protocol: TCP
EOF

kubectl cluster-info

echo "VM-4 Edge2 cluster ready"
```

## Phase 2: Core Services Installation

### Step 2.1: Install GitOps Infrastructure (VM-1)

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
  -e GITEA__server__DOMAIN=172.16.4.44 \
  -e GITEA__server__HTTP_PORT=3000 \
  -e GITEA__server__ROOT_URL=http://172.16.4.44:3000 \
  -v /var/lib/gitea:/data \
  gitea/gitea:1.20

# Wait for Gitea to start
sleep 30

# Setup GitOps repositories
./scripts/setup_gitea_for_vm2.sh
./scripts/create_edge1_repo.sh

echo "GitOps infrastructure ready"
```

### Step 2.2: Install O2IMS on Edge Clusters

```bash
#!/bin/bash
# Install O2IMS on VM-2 (run from VM-1)

# Configure kubectl for Edge1
export KUBECONFIG_EDGE1=/tmp/kubeconfig-edge1
ssh ubuntu@172.16.4.45 "kind get kubeconfig --name edge1-cluster" > $KUBECONFIG_EDGE1

# Install O2IMS using provided scripts
KUBECONFIG=$KUBECONFIG_EDGE1 ./scripts/p0.3_o2ims_install.sh

# Provision O-Cloud
KUBECONFIG=$KUBECONFIG_EDGE1 ./scripts/p0.4A_ocloud_provision.sh

echo "O2IMS installed on Edge1"

# Repeat for Edge2
export KUBECONFIG_EDGE2=/tmp/kubeconfig-edge2
ssh ubuntu@172.16.4.46 "kind get kubeconfig --name edge2-cluster" > $KUBECONFIG_EDGE2

KUBECONFIG=$KUBECONFIG_EDGE2 ./scripts/p0.3_o2ims_install.sh
KUBECONFIG=$KUBECONFIG_EDGE2 ./scripts/p0.4C_vm4_edge2.sh

echo "O2IMS installed on Edge2"
```

### Step 2.3: Install Config Sync

```bash
#!/bin/bash
# Install Config Sync on edge clusters

# Edge1 Config Sync
kubectl apply -f - <<EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync-edge1
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: http://172.16.4.44:3000/nephio/edge1-config
    branch: main
    dir: "/"
    auth: none
    noSSLVerify: true
  override:
    statusMode: enabled
    reconcileTimeout: 300s
EOF

# Edge2 Config Sync
kubectl apply -f - <<EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync-edge2
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: http://172.16.4.44:3000/nephio/edge2-config
    branch: main
    dir: "/"
    auth: none
    noSSLVerify: true
  override:
    statusMode: enabled
    reconcileTimeout: 300s
EOF

echo "Config Sync configured"
```

## Phase 3: SLO Gate and Enhancement Installation

### Step 3.1: Install SLO Controllers

```bash
#!/bin/bash
# Install SLO Gate Controller (VM-1)

# Create SLO configuration
mkdir -p config/slo-gate
cat > config/slo-gate/slo-thresholds.yaml << 'EOF'
apiVersion: slo.nephio.org/v1alpha1
kind: SLOThresholds
metadata:
  name: production-slos
spec:
  syncLatency: 100ms
  successRate: 95%
  rollbackTime: 300s
  consistencyRate: 99%
  validationTimeout: 30s
EOF

# Create SLO Gate deployment
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
        image: nephio/slo-gate-controller:v1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: SLO_CONFIG_PATH
          value: "/etc/slo/slo-thresholds.yaml"
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

echo "SLO Gate Controller installed"
```

### Step 3.2: Configure Enhanced Monitoring

```bash
#!/bin/bash
# Install comprehensive monitoring stack

# Install Prometheus
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

# Create Prometheus configuration
kubectl create configmap prometheus-config -n monitoring --from-literal=prometheus.yml='
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "kubernetes-apiservers"
    kubernetes_sd_configs:
    - role: endpoints
  - job_name: "slo-metrics"
    static_configs:
    - targets: ["slo-gate-controller:8080"]
'

echo "Monitoring stack installed"
```

## Phase 4: Production Validation

### Step 4.1: Run Golden Tests

```bash
#!/bin/bash
# Execute comprehensive validation

# Run golden tests
make test-golden

# Validate SLO compliance
./scripts/postcheck.sh --comprehensive

# Test multi-site deployment
./scripts/demo_llm.sh --target=both --enable-slo-gate

# Generate validation report
./scripts/validate_enhancements.sh

echo "Production validation complete"
```

### Step 4.2: Security Validation

```bash
#!/bin/bash
# Comprehensive security validation

# Generate SBOM for all components
make sbom

# Sign artifacts
make sign

# Verify signatures
make verify

# Run security scan
./scripts/security_report.sh

# Validate compliance
./scripts/generate_compliance_report.sh

echo "Security validation complete"
```

## Phase 5: Production Deployment

### Step 5.1: Final System Integration

```bash
#!/bin/bash
# Complete end-to-end integration

# Run complete demo
make demo

# Validate all SLOs
./scripts/postcheck.sh --production

# Test rollback capability
./scripts/test_slo_integration.sh

# Generate evidence package
./scripts/package_artifacts.sh --full-evidence

echo "System integration complete"
```

### Step 5.2: Create Summit Package

```bash
#!/bin/bash
# Generate comprehensive summit materials

# Create summit package
./scripts/package_summit_demo.sh

# Generate KPI reports
./scripts/generate_kpi_charts.sh

# Create executive summary
./scripts/generate_executive_summary.sh

# Package all deliverables
make summit

echo "Summit package ready"
```

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Network Connectivity** | Timeouts, connection refused | Verify firewall rules, test connectivity |
| **GitOps Not Syncing** | RootSync stuck in pending | Check Git repository access, restart Config Sync |
| **SLO Violations** | Automatic rollbacks triggered | Review metrics, adjust thresholds if needed |
| **O2IMS Not Responding** | API calls failing | Check service status, restart O2IMS pods |
| **LLM Adapter Errors** | Translation failures | Verify service health, check logs |

### Health Check Commands

```bash
# System health overview
./scripts/validate_enhancements.sh

# Component-specific checks
kubectl get pods -A | grep -v Running
kubectl get rootsync -A
curl http://172.16.4.45:31280/o2ims/v1/
curl http://172.16.4.46:8888/health

# SLO status
./scripts/postcheck.sh --quick
```

### Log Collection

```bash
# Collect comprehensive logs
./scripts/collect_debug_evidence.sh

# Component logs
kubectl logs -n config-management-system -l app=config-management-operator
kubectl logs -n slo-system -l app=slo-gate-controller
kubectl logs -n oran-system -l app=intent-controller
```

## Post-Deployment Operations

### Daily Operations

```bash
# Daily health check
make validate-production

# Monitor SLO compliance
./scripts/postcheck.sh --daily

# Update KPI dashboards
open http://172.16.4.45:31080/grafana
```

### Maintenance Procedures

```bash
# Update system components
make update-components

# Backup configuration
./scripts/backup_configuration.sh

# Rotate certificates
make rotate-certs
```

## Success Criteria

### Deployment Success Indicators

- ✅ All VMs operational and accessible
- ✅ Kubernetes clusters healthy on VM-2 and VM-4
- ✅ O2IMS API responding on both edge sites
- ✅ LLM Adapter service healthy
- ✅ GitOps repositories syncing successfully
- ✅ SLO Gate Controller operational
- ✅ Golden tests passing
- ✅ Multi-site deployments successful
- ✅ Automatic rollback functional

### Performance Targets

| Metric | Target | Validation Command |
|--------|--------|--------------------|
| **Sync Latency** | <100ms | `./scripts/postcheck.sh --latency` |
| **Success Rate** | >95% | `./scripts/postcheck.sh --success-rate` |
| **SLO Compliance** | >99% | `./scripts/validate_slo_compliance.sh` |
| **Rollback Time** | <5min | `./scripts/test_rollback_time.sh` |

## Support and Maintenance

### Documentation References

- **Operations Guide**: `OPERATIONS.md`
- **Security Guide**: `SECURITY.md`
- **Runbook**: `runbook/POCKET_QA.md`
- **Architecture**: `docs/TECHNICAL_ARCHITECTURE.md`

### Contact Information

- **Technical Support**: See RUNBOOK.md for troubleshooting procedures
- **Security Issues**: Follow security reporting guidelines in SECURITY.md
- **Feature Requests**: Submit via GitHub issues

---
*Deployment Guide | Version: 1.0 | Date: 2025-09-14 | Classification: Technical*