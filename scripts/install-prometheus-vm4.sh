#!/bin/bash
# Install Prometheus on VM-4 (edge2)
# To be executed on VM-4: ssh edge2 < scripts/install-prometheus-vm4.sh

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Installing Prometheus on VM-4 (edge2)                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "⚠️  Helm not found. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add Prometheus Helm repository
echo "📦 Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create values file for Prometheus
echo "📝 Creating Prometheus configuration..."
cat > /tmp/prometheus-values.yaml <<EOF
server:
  service:
    type: NodePort
    nodePort: 30090

  remoteWrite:
    - url: http://172.16.0.78:8428/api/v1/write
      remoteTimeout: 30s
      queueConfig:
        maxSamplesPerSend: 1000
        maxShards: 200

  persistentVolume:
    enabled: false

  global:
    scrape_interval: 15s
    evaluation_interval: 15s
    external_labels:
      cluster: 'edge2'
      site: 'vm-4'

alertmanager:
  enabled: false

kube-state-metrics:
  enabled: true

prometheus-node-exporter:
  enabled: true

prometheus-pushgateway:
  enabled: false
EOF

# Create monitoring namespace if not exists
echo "📂 Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus
echo "🚀 Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/prometheus \
  -n monitoring \
  -f /tmp/prometheus-values.yaml \
  --wait \
  --timeout 5m

# Wait for Prometheus to be ready
echo "⏳ Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server \
  -n monitoring \
  --timeout=300s

# Verify installation
echo ""
echo "✅ Verifying Prometheus installation..."
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Test Prometheus endpoint
echo ""
echo "🔍 Testing Prometheus endpoint..."
sleep 5
curl -s http://localhost:30090/-/ready && echo "✅ Prometheus is ready!" || echo "❌ Prometheus not responding"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Prometheus Installation Complete!                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Access Prometheus:"
echo "  - From VM-4:  http://localhost:30090"
echo "  - From VM-1:  http://172.16.4.176:30090"
echo ""
echo "Remote Write Target: http://172.16.0.78:8428"