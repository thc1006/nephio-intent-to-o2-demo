# Edge3 Onboarding Package

**Version**: 1.2.0
**For**: Claude Code on edge3
**From**: VM-1 Orchestrator (172.16.0.78)
**Date**: 2025-09-27
**Status**: Production Ready - Part of 4-Site Deployment

---

## 📦 Configuration Package

### Your Edge Site Information

```yaml
edgeSite:
  name: edge3
  vm1_ip: 172.16.0.78
  vm1_floating_ip: 147.251.115.143
  gitea_url: http://172.16.0.78:8888
  tmf921_adapter: http://172.16.0.78:8889
  metrics_endpoint: http://172.16.0.78:8428
  websocket_services:
    claude_headless: http://172.16.0.78:8002
    realtime_monitor: http://172.16.0.78:8003
    tmux_bridge: http://172.16.0.78:8004
  site_config:
    ip: 172.16.5.81
    o2ims_port: 32080
    prometheus_port: 30090
    user: thc1006
    ssh_key: edge_sites_key
```

### VM-1 SSH Public Key

**Copy this key and add to `~/.ssh/authorized_keys` on edge3:**

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDQU9lTLh32IP7UR3/Ab1BRbFMOO/Mlu0qNuUg07Jai vm1-edge-management
```

---

## 🚀 Quick Setup Commands

### Step 1: Install SSH Key

```bash
# Run on edge3
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Add VM-1 public key
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDQU9lTLh32IP7UR3/Ab1BRbFMOO/Mlu0qNuUg07Jai vm1-edge-management
EOF

chmod 600 ~/.ssh/authorized_keys

# Verify
cat ~/.ssh/authorized_keys
```

### Step 2: Provide Your IP to VM-1

```bash
# Run on edge3 and send output to VM-1 admin
echo "Edge3 IP: $(hostname -I | awk '{print $1}')"
echo "Edge3 Hostname: $(hostname)"
```

**Send this info back so VM-1 can configure SSH connection.**

---

## 🎯 Full Setup (After Providing IP)

### Install Kubernetes

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Setup kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Verify
kubectl get nodes
```

### Setup GitOps Pull

**VM-1 will provide a Gitea token. Replace `YOUR_GITEA_TOKEN` below:**

```bash
# Create Config Sync namespace
kubectl create namespace config-management-system

# Create Gitea token secret
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=token=YOUR_GITEA_TOKEN

# Install Config Sync
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
    dir: clusters/edge3
    auth: token
    secretRef:
      name: gitea-token
    period: 15s
  sourceFormat: unstructured
EOF

# Verify sync
kubectl get rootsync -n config-management-system -w
```

### Setup Prometheus Metrics

```bash
kubectl create namespace monitoring

kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      external_labels:
        cluster: 'edge3'
        region: 'edge'

    remote_write:
      - url: http://172.16.0.78:8428/api/v1/write

    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints

      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node

      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
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
          ports:
            - containerPort: 9090
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

# Verify
kubectl get pods -n monitoring
```

---

## ✅ Verification Commands

Run these and send results to VM-1:

```bash
# System info
echo "=== Edge3 Status Report ==="
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo ""

# Kubernetes
echo "=== Kubernetes ==="
kubectl version --short
kubectl get nodes
echo ""

# GitOps
echo "=== GitOps Status ==="
kubectl get rootsync -n config-management-system
kubectl describe rootsync root-sync -n config-management-system | grep -A5 "Status:"
echo ""

# Prometheus
echo "=== Prometheus ==="
kubectl get pods -n monitoring
echo ""

# Network to VM-1
echo "=== VM-1 Connectivity ==="
nc -zv 172.16.0.78 22 2>&1 | grep succeeded && echo "✅ SSH OK" || echo "❌ SSH Failed"
nc -zv 172.16.0.78 8888 2>&1 | grep succeeded && echo "✅ Gitea OK" || echo "❌ Gitea Failed"
nc -zv 172.16.0.78 8428 2>&1 | grep succeeded && echo "✅ Metrics OK" || echo "❌ Metrics Failed"
```

---

## 📚 Reference Documentation

Saved on VM-1 for your reference:

- **Full Guide**: `docs/operations/EDGE_SITE_ONBOARDING_GUIDE.md`
- **Quick Setup**: `docs/operations/EDGE_QUICK_SETUP.md`
- **VM-1 Control Guide**: `docs/operations/EDGE_SSH_CONTROL_GUIDE.md`
- **Network Config**: `docs/network/AUTHORITATIVE_NETWORK_CONFIG.md`

---

## 🔧 Expected VM-1 Actions After Setup

Once you report your IP, VM-1 will:

1. Update SSH config:
   ```
   Host edge3
     HostName <your-ip>
     User ubuntu
     IdentityFile ~/.ssh/edge_sites_key
   ```

2. Test SSH connection:
   ```bash
   ssh edge3 "hostname; kubectl get nodes"
   ```

3. Register in edge registry:
   ```yaml
   # config/edge-sites-registry.yaml
   - name: edge3
     ip: <your-ip>
     status: active
   ```

4. Create management script:
   ```bash
   scripts/edge-management/edges/edge3.sh
   ```

5. Setup Gitea repository:
   ```
   deployments/clusters/edge3/
   ```

---

## 🚨 Troubleshooting

### SSH Connection Fails

```bash
# Check SSH service
sudo systemctl status sshd

# Check firewall
sudo ufw status
sudo ufw allow from 172.16.0.78 to any port 22

# Check authorized_keys
ls -la ~/.ssh/authorized_keys
cat ~/.ssh/authorized_keys
```

### GitOps Not Syncing

```bash
# Check Config Sync logs
kubectl logs -n config-management-system -l app=reconciler-manager

# Check Gitea connectivity
curl -v http://172.16.0.78:8888/nephio/deployments

# Verify token secret
kubectl get secret gitea-token -n config-management-system
```

### Prometheus Not Running

```bash
# Check logs
kubectl logs -n monitoring -l app=prometheus

# Check config
kubectl get configmap prometheus-config -n monitoring -o yaml

# Restart
kubectl rollout restart deployment prometheus -n monitoring
```

---

## 📞 Contact VM-1

**VM-1 Information (v1.2.0)**:
- Internal IP: `172.16.0.78`
- Floating IP: `147.251.115.143`
- TMF921 Adapter: `http://172.16.0.78:8889` (automated)
- Gitea: `http://172.16.0.78:8888`
- Metrics: `http://172.16.0.78:8428`
- Claude Headless: `http://172.16.0.78:8002`
- Realtime Monitor: `http://172.16.0.78:8003`
- TMux Bridge: `http://172.16.0.78:8004`

**Edge3 Configuration**:
- IP: `172.16.5.81`
- User: `thc1006` (password: 1006)
- O2IMS Port: `32080`
- Prometheus Port: `30090`
- SSH Key: `edge_sites_key`

**What VM-1 Needs from You**:
1. Your IP address (should be 172.16.5.81)
2. Confirmation SSH key is installed for user thc1006
3. Confirmation user thc1006 password works (1006)
4. Status report after setup
5. Verification of O2IMS on port 32080
6. Verification of Prometheus on port 30090

---

**Ready to onboard edge3!** 🚀

Follow steps above and report status to VM-1.