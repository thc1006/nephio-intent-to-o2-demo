# Edge Site Quick Setup - For Claude Code

**You are on**: Edge site (edge3, edge4, ...)
**Managed by**: VM-1 Orchestrator at `172.16.0.78`

---

## 🎯 What You Need to Do

### 1. Install VM-1 SSH Public Key

VM-1 admin will provide a public key. Run:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys << 'EOF'
# VM-1 will provide the key - paste it here between EOF markers
EOF
chmod 600 ~/.ssh/authorized_keys
```

### 2. Tell VM-1 Admin Your IP Address

```bash
echo "My IP: $(hostname -I | awk '{print $1}')"
echo "My hostname: $(hostname)"
```

### 3. Install Kubernetes (if needed)

```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
export KUBECONFIG=~/.kube/config
```

### 4. Setup GitOps Pull

VM-1 admin will provide:
- **Edge name**: `edge3` (example)
- **Gitea token**: `ghp_xxxxx` (example)

```bash
# Create namespace
kubectl create namespace config-management-system

# Create token secret (replace YOUR_TOKEN)
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=token=YOUR_TOKEN

# Install Config Sync (replace EDGE_NAME)
EDGE_NAME="edge3"  # VM-1 admin will tell you
kubectl apply -f - << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/nephio/deployments
    branch: main
    dir: clusters/${EDGE_NAME}
    auth: token
    secretRef:
      name: gitea-token
    period: 15s
  sourceFormat: unstructured
EOF
```

### 5. Setup Prometheus Metrics Export

```bash
# Quick setup (replace EDGE_NAME)
EDGE_NAME="edge3"  # VM-1 admin will tell you

kubectl create namespace monitoring

kubectl apply -f - << EOF
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
        cluster: '${EDGE_NAME}'

    remote_write:
      - url: http://172.16.0.78:8428/api/v1/write

    scrape_configs:
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
      containers:
        - name: prometheus
          image: prom/prometheus:v2.45.0
          args:
            - '--config.file=/etc/prometheus/prometheus.yml'
            - '--storage.tsdb.retention.time=6h'
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-config
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
EOF
```

---

## ✅ Verify Setup

```bash
# 1. Check SSH (VM-1 will test)
sudo journalctl -u sshd | tail -n 20

# 2. Check Kubernetes
kubectl get nodes

# 3. Check GitOps
kubectl get rootsync -n config-management-system

# 4. Check Prometheus
kubectl get pods -n monitoring

# 5. Test connectivity to VM-1
nc -zv 172.16.0.78 22 8888 8428
```

---

## 🚨 If Something Goes Wrong

```bash
# SSH not working?
chmod 600 ~/.ssh/authorized_keys
sudo systemctl restart sshd

# GitOps not syncing?
kubectl describe rootsync root-sync -n config-management-system

# Prometheus not running?
kubectl logs -n monitoring -l app=prometheus

# Can't reach VM-1?
ping 172.16.0.78
```

---

## 📞 Report to VM-1 Admin

```bash
# Copy this output and send to VM-1 admin
echo "=== Edge Site Status ==="
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo "K8s: $(kubectl version --short 2>&1 | grep Server)"
echo "Pods: $(kubectl get pods -A --no-headers | wc -l) pods running"
echo "GitOps: $(kubectl get rootsync -n config-management-system --no-headers 2>&1)"
echo "Prometheus: $(kubectl get pods -n monitoring --no-headers 2>&1)"
```

---

**Done!** VM-1 can now manage this edge site.

Full docs: `docs/operations/EDGE_SITE_ONBOARDING_GUIDE.md`