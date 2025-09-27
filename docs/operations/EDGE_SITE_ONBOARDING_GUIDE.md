# Edge Site Onboarding Guide

**Version**: 1.2.0
**Last Updated**: 2025-09-27
**Status**: Production Ready - 4 Edge Sites Operational
**Purpose**: Configure edge sites to be managed by VM-1 (Orchestrator)
**Audience**: Claude Code running on edge sites (edge1, edge2, edge3, edge4)

---

## 🎯 Overview

You are running on an **edge site** in the 4-site deployment. VM-1 (Orchestrator at `172.16.0.78`) will manage you via:
- **SSH**: For setup and emergency operations
- **TMF921 Adapter**: Intent processing at `http://172.16.0.78:8889`
- **GitOps Pull**: For normal configuration deployment (Config Sync)
- **Prometheus Remote Write**: For metrics aggregation to VM-1
- **WebSocket Services**: Real-time monitoring (ports 8002-8004)

**Current 4-Site Network (v1.2.0)**:
- VM-1 (SMO): 172.16.0.78 - TMF921 (8889), Gitea (8888), WebSockets (8002-8004)
- Edge1: 172.16.4.45 - O2IMS (31280), Prometheus (30090)
- Edge2: 172.16.4.176 - O2IMS (31281), Prometheus (30090)
- Edge3: 172.16.5.81 - O2IMS (32080), Prometheus (30090)
- Edge4: 172.16.1.252 - O2IMS (32080), Prometheus (30090)

---

## 📋 Prerequisites

### Information Needed from VM-1 Admin

VM-1 admin will provide:
1. **Edge site name**: `edge1`, `edge2`, `edge3`, or `edge4`
2. **VM-1 SSH public key**: To add to `~/.ssh/authorized_keys`
3. **User credentials**: `ubuntu` (Edge1/Edge2) or `thc1006` (Edge3/Edge4)
4. **Gitea repository URL**: `http://172.16.0.78:8888/nephio/deployments`
5. **Gitea token**: For repository access
6. **Prometheus remote write endpoint**: `http://172.16.0.78:8428/api/v1/write`
7. **Site-specific ports**: O2IMS port assignment for your site

### What You Need on This Edge Site

- Ubuntu/Debian Linux
- User with sudo access
- SSH server running
- Internet/network connectivity to VM-1
- (Optional) Kubernetes cluster (k3s/k8s)

---

## 🚀 Quick Start

### Step 1: Receive SSH Public Key from VM-1

VM-1 admin will provide different public keys based on your site:

**For Edge1/Edge2 (ubuntu user)**:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDQU9lTLh32IP7UR3/Ab1BRbFMOO/Mlu0qNuUg07Jai ubuntu@vm1
```

**For Edge3/Edge4 (thc1006 user)**:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDQU9lTLh32IP7UR3/Ab1BRbFMOO/Mlu0qNuUg07Jai vm1-edge-management
```

### Step 2: Install SSH Public Key

```bash
# Create .ssh directory if not exists
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add VM-1 public key (use appropriate key for your site)
# For Edge1/Edge2:
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDQU9lTLh32IP7UR3/Ab1BRbFMOO/Mlu0qNuUg07Jai ubuntu@vm1
EOF

# For Edge3/Edge4:
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDQU9lTLh32IP7UR3/Ab1BRbFMOO/Mlu0qNuUg07Jai vm1-edge-management
EOF

# Set correct permissions
chmod 600 ~/.ssh/authorized_keys

# Verify
cat ~/.ssh/authorized_keys
```

### Step 3: Verify SSH Connection

VM-1 admin will test connection. You should see SSH attempts in logs:
```bash
# Monitor SSH connections
sudo journalctl -u sshd -f
```

### Step 4: Install Kubernetes (if not already installed)

```bash
# Install k3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -

# Verify
sudo k3s kubectl get nodes

# Set up kubeconfig for current user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Add to bashrc
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

### Step 5: Configure GitOps Pull (Config Sync)

VM-1 admin will provide Gitea details. Create Config Sync setup:

```bash
# Create config-management-system namespace
kubectl create namespace config-management-system

# Site-specific configuration (replace EDGE_SITE_NAME with your site)
EDGE_SITE_NAME="edge1"  # Change to edge2, edge3, or edge4 as appropriate

# Create Gitea token secret (replace TOKEN with actual token)
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=token=YOUR_GITEA_TOKEN_HERE

# Apply RootSync (replace EDGE_NAME with your edge site name)
kubectl apply -f - << 'EOF'
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/nephio/deployments
    branch: main
    dir: clusters/EDGE_NAME
    auth: token
    secretRef:
      name: gitea-token
    period: 15s
  sourceFormat: unstructured
EOF

# Verify sync status
kubectl get rootsync -n config-management-system -w
```

### Step 6: Configure Prometheus Metrics Export

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus (if not installed)
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'EDGE_NAME'
        region: 'edge'

    remote_write:
      - url: http://172.16.0.78:8428/api/v1/write
        queue_config:
          capacity: 10000
          max_shards: 10
          min_shards: 1
          max_samples_per_send: 5000
          batch_send_deadline: 5s
          min_backoff: 30ms
          max_backoff: 100ms

    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https

      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
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
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus:v2.45.0
          args:
            - '--config.file=/etc/prometheus/prometheus.yml'
            - '--storage.tsdb.path=/prometheus'
            - '--storage.tsdb.retention.time=6h'
            - '--web.enable-lifecycle'
          ports:
            - containerPort: 9090
              name: web
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
            - name: data
              mountPath: /prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-config
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app: prometheus
  ports:
    - port: 9090
      nodePort: 30090
      targetPort: 9090
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - nodes/proxy
      - services
      - endpoints
      - pods
    verbs: ["get", "list", "watch"]
  - apiGroups: ["extensions"]
    resources:
      - ingresses
    verbs: ["get", "list", "watch"]
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
EOF

# Replace EDGE_NAME in the config
EDGE_NAME=$(hostname | cut -d'-' -f1)  # or set manually
kubectl get configmap prometheus-config -n monitoring -o yaml | \
  sed "s/EDGE_NAME/${EDGE_NAME}/g" | \
  kubectl apply -f -

# Verify Prometheus is running
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=prometheus -f
```

---

## 📊 Network Configuration

### Required Network Connectivity

**To VM-1 (172.16.0.78)**:
- SSH (port 22): For management
- Gitea (port 8888): For GitOps pull
- VictoriaMetrics (port 8428): For Prometheus remote_write
- Thanos Receive (port 19291): Alternative metrics endpoint

**Exposed Services on This Edge**:
- Kubernetes API: `6443`
- Prometheus: `30090` (NodePort)
- O2IMS: `31280` (NodePort, if deployed)

### Firewall Configuration

```bash
# Allow SSH from VM-1
sudo ufw allow from 172.16.0.78 to any port 22 comment 'SSH from VM-1'

# Allow NodePort range (if using NodePort services)
sudo ufw allow 30000:32767/tcp comment 'Kubernetes NodePort'

# Enable firewall
sudo ufw --force enable

# Check status
sudo ufw status numbered
```

---

## 🔧 SSH Configuration (Optional Hardening)

Edit `/etc/ssh/sshd_config`:

```bash
# Disable password authentication (key-only)
PasswordAuthentication no
PubkeyAuthentication yes

# Disable root login
PermitRootLogin no

# Limit users (replace with your username)
AllowUsers ubuntu

# Enable key-based auth only
AuthorizedKeysFile .ssh/authorized_keys
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

---

## ✅ Verification Checklist

### 1. SSH Access
```bash
# VM-1 should be able to connect
# You'll see this in your logs:
sudo journalctl -u sshd | grep "Accepted publickey"
```

### 2. Kubernetes Status
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

### 3. GitOps Sync
```bash
# Check Config Sync status
kubectl get rootsync -n config-management-system
kubectl describe rootsync root-sync -n config-management-system

# Check synced resources
kubectl get all -A | grep -v kube-system
```

### 4. Prometheus Metrics
```bash
# Check Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl http://localhost:9090/api/v1/targets

# Check remote_write queue
curl http://localhost:9090/api/v1/query?query=prometheus_remote_storage_samples_pending

# Kill port-forward
pkill -f "port-forward.*prometheus"
```

### 5. Network Connectivity to VM-1
```bash
# Test SSH
nc -zv 172.16.0.78 22

# Test Gitea
nc -zv 172.16.0.78 8888
curl -I http://172.16.0.78:8888

# Test VictoriaMetrics
nc -zv 172.16.0.78 8428
curl -I http://172.16.0.78:8428/health
```

---

## 🚨 Troubleshooting

### Problem: VM-1 Cannot SSH

```bash
# Check SSH service
sudo systemctl status sshd

# Check authorized_keys
ls -la ~/.ssh/authorized_keys
cat ~/.ssh/authorized_keys

# Fix permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Check SSH logs
sudo journalctl -u sshd -f
```

### Problem: GitOps Not Syncing

```bash
# Check Config Sync status
kubectl get rootsync -n config-management-system -o yaml

# Check logs
kubectl logs -n config-management-system -l app=reconciler-manager -f

# Check Gitea connectivity
curl -v http://172.16.0.78:8888/nephio/deployments

# Re-create secret if token is wrong
kubectl delete secret gitea-token -n config-management-system
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=token=NEW_TOKEN
kubectl rollout restart deployment -n config-management-system
```

### Problem: Prometheus Not Sending Metrics

```bash
# Check Prometheus logs
kubectl logs -n monitoring -l app=prometheus -f | grep remote_write

# Check remote_write URL
kubectl get configmap prometheus-config -n monitoring -o yaml | grep remote_write

# Test VictoriaMetrics endpoint
curl -X POST http://172.16.0.78:8428/api/v1/write \
  -H "Content-Type: application/x-protobuf" \
  -d ""

# Check queue status
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl http://localhost:9090/api/v1/query?query=prometheus_remote_storage_queue_length
```

---

## 📚 What VM-1 Will Do

Once you complete setup, VM-1 (Orchestrator) can:

1. **SSH Operations**:
   ```bash
   ssh <your-edge-name> "kubectl get nodes"
   ```

2. **Deploy Configurations**:
   - Push to Gitea → You pull via Config Sync

3. **Monitor Your Status**:
   ```bash
   ssh <your-edge-name> "./check-status.sh"
   ```

4. **Emergency Operations**:
   ```bash
   ssh <your-edge-name> "kubectl rollout restart deployment -n <namespace>"
   ```

---

## 🎯 Expected Files from VM-1

After setup, you may receive these files via GitOps:

```
clusters/<your-edge-name>/
├── namespace.yaml           # Namespaces
├── deployment.yaml          # Workloads
├── service.yaml            # Services
├── configmap.yaml          # Configurations
├── flagger-canary.yaml     # Progressive delivery
└── prometheus-rules.yaml   # Monitoring rules
```

These will auto-apply via Config Sync.

---

## 🔄 Ongoing Operations

### Daily Operations (Automated)

- **GitOps Pull**: Every 15s, Config Sync checks for updates
- **Metrics Push**: Every 15s, Prometheus sends metrics to VM-1
- **Health Checks**: VM-1 may SSH periodically to check status

### Manual Operations (Rare)

- **Troubleshooting**: VM-1 admin SSH for debugging
- **Emergency Rollback**: VM-1 pushes emergency config
- **Upgrades**: VM-1 orchestrates Kubernetes/app upgrades

---

## 📞 Contact

If you encounter issues, provide this info to VM-1 admin:

```bash
# Gather diagnostic info
cat > /tmp/edge-diagnostics.txt << EOF
Hostname: $(hostname)
IP: $(hostname -I)
K8s Version: $(kubectl version --short 2>&1 | head -1)
Nodes: $(kubectl get nodes --no-headers | wc -l)
Pods: $(kubectl get pods -A --no-headers | wc -l)

SSH Config:
$(ls -la ~/.ssh/authorized_keys)

Config Sync:
$(kubectl get rootsync -n config-management-system 2>&1)

Prometheus:
$(kubectl get pods -n monitoring 2>&1)

Network to VM-1:
$(nc -zv 172.16.0.78 22 8888 8428 2>&1)
EOF

cat /tmp/edge-diagnostics.txt
```

---

## 🔒 Security Notes

- SSH key is read-only access to VM-1 (you don't SSH to VM-1)
- GitOps pull is read-only (you pull from Gitea, not push)
- Prometheus metrics are one-way (you send to VM-1, VM-1 doesn't query you directly)
- Zero trust model: You initiate all connections to VM-1

---

## 📋 Quick Reference

| What | Where | Purpose |
|------|-------|---------|
| VM-1 IP | `172.16.0.78` | Orchestrator |
| Gitea | `http://172.16.0.78:8888` | GitOps source |
| VictoriaMetrics | `http://172.16.0.78:8428` | Metrics sink |
| Your K8s API | `:6443` | Kubernetes |
| Your Prometheus | `:30090` | Local metrics |
| Config Sync | `config-management-system` namespace | GitOps agent |

---

**Status**: Production Ready
**Last Updated**: 2025-09-26
**Maintainer**: VM-1 Orchestrator (Claude Code)
**Edge Site**: Apply this guide on edge3, edge4, edge5, ...