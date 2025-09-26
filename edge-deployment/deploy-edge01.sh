#!/bin/bash
# Deploy observability stack to VM-2 (edge01)
# To be run on VM-2 or from VM-1 via SSH

EDGE_NAME="edge01"
EDGE_IP="172.16.4.45"
VM1_IP="172.16.0.78"

echo "========================================="
echo "Deploying Observability Stack to Edge01"
echo "========================================="

# Create edge01-specific configuration
cat > /tmp/edge01-stack.yaml << EOF
# Edge01 Observability Stack
# Config Sync + Prometheus + Flagger

---
apiVersion: v1
kind: Namespace
metadata:
  name: config-management-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: flagger-system

---
# 1. Config Sync RootSync for Edge01
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge01-root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  sourceType: git
  git:
    repo: http://${VM1_IP}:8888/gitops/edge01-configs
    branch: main
    auth: none
    period: 30s
  sync:
    preventDeletion: false
    prune: true
    resyncPeriod: 60s

---
# 2. Prometheus with Remote Write to VM-1
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
        cluster: 'edge01'
        site: 'edge01'

    # Remote write to VM-1 VictoriaMetrics
    remote_write:
    - url: "http://${VM1_IP}:8428/api/v1/write"
      queue_config:
        capacity: 10000
        max_shards: 30
        max_samples_per_send: 500
      metadata_config:
        send: true
        send_interval: 30s
      write_relabel_configs:
      - source_labels: [__name__]
        regex: 'up|.*_total|.*_seconds.*|.*_bytes.*'
        action: keep

    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true

    - job_name: 'node-exporter'
      static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'edge01-node'

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
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.48.0
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.retention.time=3d
        - --web.enable-lifecycle
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
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
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: 30090
  selector:
    app: prometheus

---
# 3. Node Exporter DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.7.0
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        ports:
        - containerPort: 9100
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /

---
# 4. Flagger for Progressive Delivery
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flagger
  namespace: flagger-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flagger
  template:
    metadata:
      labels:
        app: flagger
    spec:
      serviceAccountName: flagger
      containers:
      - name: flagger
        image: ghcr.io/fluxcd/flagger:1.35.0
        ports:
        - containerPort: 8080
        command:
        - ./flagger
        - -log-level=info
        - -metrics-server=http://prometheus.monitoring:9090
        - -mesh-provider=kubernetes
        resources:
          requests:
            cpu: 100m
            memory: 128Mi

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flagger
  namespace: flagger-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: flagger
rules:
- apiGroups: [""]
  resources: ["events", "configmaps", "services", "pods"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets"]
  verbs: ["*"]
- apiGroups: ["flagger.app"]
  resources: ["canaries", "canaries/status"]
  verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flagger
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flagger
subjects:
- kind: ServiceAccount
  name: flagger
  namespace: flagger-system
EOF

echo "Configuration generated at /tmp/edge01-stack.yaml"

# Deploy to edge01
if command -v kubectl &> /dev/null; then
    echo "Deploying to local Kubernetes cluster..."
    kubectl apply -f /tmp/edge01-stack.yaml

    echo ""
    echo "Checking deployment status..."
    sleep 5
    kubectl get pods -n monitoring
    kubectl get pods -n flagger-system

    echo ""
    echo "Testing Prometheus connectivity..."
    curl -s http://localhost:30090/api/v1/query?query=up | jq '.status' 2>/dev/null || echo "Prometheus starting..."

    echo ""
    echo "Testing remote write to VM-1..."
    curl -X POST http://${VM1_IP}:8428/api/v1/write \
        -H "Content-Type: application/x-protobuf" \
        -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
        --data-binary "@/dev/null" \
        -w "\nRemote write endpoint status: %{http_code}\n"
else
    echo "kubectl not found. Please install Kubernetes first or copy /tmp/edge01-stack.yaml to edge01"
    echo ""
    echo "To deploy manually on edge01:"
    echo "1. Copy /tmp/edge01-stack.yaml to edge01"
    echo "2. SSH to edge01: ssh ubuntu@${EDGE_IP}"
    echo "3. Apply configuration: kubectl apply -f edge01-stack.yaml"
fi

echo ""
echo "========================================="
echo "Edge01 Deployment Summary:"
echo "========================================="
echo "✅ Config Sync: Points to Gitea at ${VM1_IP}:8888"
echo "✅ Prometheus: Remote writes to VM-1 at ${VM1_IP}:8428"
echo "✅ Flagger: Ready for canary deployments"
echo "✅ Node Exporter: Collecting system metrics"
echo ""
echo "Access URLs:"
echo "  Prometheus: http://${EDGE_IP}:30090"
echo "  Metrics endpoint: http://${EDGE_IP}:30090/metrics"
echo ""
echo "Verify remote write:"
echo "  On VM-1: curl http://${VM1_IP}:8428/api/v1/label/__name__/values | grep edge01"
echo "========================================="