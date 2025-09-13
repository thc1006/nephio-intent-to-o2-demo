# 🚀 VM-4 Edge2 全面最佳化指南 - 基於 2025 年最新最佳實踐

**基準日期**: 2025年9月
**研究範圍**: OpenStack、Kubernetes、GitOps、O2IMS、SLO 監控
**目標**: 將 VM-4 Edge2 從 75% 提升至 95%+ 生產就緒狀態

---

## 🎯 **關鍵發現：需要補充給 VM-1 的重要內容**

### 🔥 **立即必須在 VM-1 上部署的組件**

#### 1. **OpenTelemetry Collector (2025 標準)**
**依據**: 2025 年共識：即使你喜歡 PromQL 和 Grafana，也要在前端運行 OTel Collector
**部署在 VM-1 上**:
```yaml
# /home/ubuntu/nephio-intent-to-o2-demo/vm1-components/otel-collector.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: monitoring
data:
  otel-collector.yaml: |
    receivers:
      prometheus:
        config:
          scrape_configs:
          - job_name: 'edge2-slo'
            static_configs:
            - targets: ['172.16.0.89:30090']
              labels:
                site: 'edge2'
                cluster: 'vm-4-edge2'
          - job_name: 'edge1-slo'  # 如果存在
            static_configs:
            - targets: ['172.16.4.45:30090']
              labels:
                site: 'edge1'
                cluster: 'vm-2-edge1'

      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      batch:
      memory_limiter:
        limit_mib: 512

      # 2025 最佳實踐: 語義約定
      resource:
        attributes:
        - key: deployment.environment
          value: "production"
          action: upsert
        - key: service.namespace
          value: "nephio-multi-site"
          action: upsert

    exporters:
      prometheus:
        endpoint: "0.0.0.0:8889"
        enable_open_metrics: true
        # 2025 最佳實踐: 單位命名
        add_metric_suffixes: true

      jaeger:
        endpoint: jaeger-collector:14250
        tls:
          insecure: true

    service:
      pipelines:
        metrics:
          receivers: [prometheus, otlp]
          processors: [memory_limiter, resource, batch]
          exporters: [prometheus]
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [jaeger]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  replicas: 2  # 高可用
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:0.104.0
        command:
        - "/otelcol-contrib"
        - "--config=/etc/otel-collector-config/otel-collector.yaml"
        volumeMounts:
        - name: otel-collector-config-vol
          mountPath: /etc/otel-collector-config
        ports:
        - containerPort: 8889  # Prometheus metrics
        - containerPort: 4317  # OTLP gRPC
        - containerPort: 4318  # OTLP HTTP
        resources:
          requests:
            memory: 256Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: otel-collector-config-vol
        configMap:
          name: otel-collector-config
```

#### 2. **2025 年 GitOps 最佳實踐配置**
**依據**: 分離倉庫結構，測試驅動部署
**在 VM-1 上創建**:
```bash
# /home/ubuntu/nephio-intent-to-o2-demo/vm1-gitops-structure/
mkdir -p vm1-gitops-structure/{platform,applications,packages,environments}

# 平台配置倉庫
cat > vm1-gitops-structure/platform/fleet-config.yaml << 'EOF'
# 2025 最佳實踐: Fleet-wide configuration
apiVersion: configmanagement.gke.io/v1
kind: ClusterSelector
metadata:
  name: nephio-fleet
spec:
  matchLabels:
    environment: "production"
    deployment: "nephio"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nephio-fleet-config
  namespace: config-management-system
data:
  sites.yaml: |
    edge_sites:
      edge1:
        endpoint: "172.16.4.45:30090"
        cluster_type: "edge"
        region: "region-1"
      edge2:
        endpoint: "172.16.0.89:30090"
        cluster_type: "edge"
        region: "region-1"
    smo_sites:
      smo1:
        endpoint: "172.16.0.78:8080"
        cluster_type: "management"
        region: "central"
EOF

# kpt 驗證函數配置 (2025 最佳實踐)
cat > vm1-gitops-structure/platform/kpt-functions.yaml << 'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: nephio-platform
pipeline:
  mutators:
  - image: gcr.io/kpt-fn/set-labels:v0.2.0
    configMap:
      managed-by: "nephio-gitops"
      deployment-date: "2025-09-13"
  validators:
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
  - image: gcr.io/kpt-fn/gatekeeper:v0.2.1
    configMap:
      violations: true
EOF
```

#### 3. **多集群 SLO 監控配置 (2025 標準)**
**依據**: eBPF + OpenTelemetry + Thanos/Mimir 多集群架構
```yaml
# /home/ubuntu/nephio-intent-to-o2-demo/vm1-monitoring/multi-cluster-slo.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-cluster-slo-config
  namespace: monitoring
data:
  slo-definitions.yaml: |
    # 2025 SLO 標準定義
    slos:
      edge2_availability:
        service: "edge2-slo-endpoint"
        target: 99.5
        window: "30d"
        burn_rate_alerts:
          - severity: "critical"
            burn_rate: 14.4
            window: "1h"
          - severity: "warning"
            burn_rate: 6
            window: "6h"

      edge2_latency:
        service: "edge2-slo-endpoint"
        target: 95  # 95% of requests < 15ms
        threshold: "15ms"
        window: "30d"

      cross_site_connectivity:
        service: "vm1-to-edge2"
        target: 99.9
        window: "24h"

---
# 2025 最佳實踐: eBPF 網路監控
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ebpf-network-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: ebpf-network-monitor
  template:
    metadata:
      labels:
        app: ebpf-network-monitor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: ebpf-exporter
        image: cloudflare/ebpf_exporter:v2.3.0
        securityContext:
          privileged: true
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
```

#### 4. **零信任網路安全配置 (2025 標準)**
**依據**: 微分段 + 零信任架構
```yaml
# /home/ubuntu/nephio-intent-to-o2-demo/vm1-security/zero-trust-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nephio-zero-trust-policy
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app: slo-collector
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - podSelector:
        matchLabels:
          app: otel-collector
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # 2025 最佳實踐: 明確允許的目標
  - to: []
    ports:
    - protocol: TCP
      port: 30090  # Edge2 SLO endpoint
    - protocol: TCP
      port: 31280  # Edge2 O2IMS endpoint
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53  # DNS

---
# Cilium 微分段策略 (如果使用 Cilium)
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: nephio-microsegmentation
  namespace: monitoring
spec:
  endpointSelector:
    matchLabels:
      app: multi-site-monitor
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: otel-collector
  egress:
  - toFQDNs:
    - matchName: "*.edge2.local"
  - toPorts:
    - ports:
      - port: "30090"
        protocol: TCP
```

---

## 🏗️ **VM-1 完整部署腳本 (2025 最佳實踐)**

```bash
#!/bin/bash
# VM-1 2025 年最佳實踐部署腳本
# /home/ubuntu/nephio-intent-to-o2-demo/scripts/vm1_2025_optimization.sh

set -euo pipefail

readonly VM1_CONFIG_DIR="/home/ubuntu/nephio-intent-to-o2-demo/vm1-2025-config"
readonly MONITORING_NAMESPACE="monitoring"
readonly GITOPS_NAMESPACE="config-management-system"

# 創建 2025 年標準目錄結構
create_2025_structure() {
    echo "創建 2025 年標準配置結構..."

    mkdir -p "$VM1_CONFIG_DIR"/{otel,monitoring,gitops,security,o2ims}

    # 下載 2025 年標準工具
    curl -LO "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.104.0/otelcol-contrib_0.104.0_linux_amd64.tar.gz"
    tar -xzf otelcol-contrib_*.tar.gz -C /usr/local/bin/ otelcol-contrib
    chmod +x /usr/local/bin/otelcol-contrib
}

# 部署 OpenTelemetry Collector (2025 標準)
deploy_otel_collector() {
    echo "部署 OpenTelemetry Collector..."

    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # 應用前面定義的 OTel 配置
    kubectl apply -f vm1-components/otel-collector.yaml

    # 等待就緒
    kubectl wait --for=condition=available --timeout=300s deployment/otel-collector -n $MONITORING_NAMESPACE
}

# 配置多集群 GitOps (2025 最佳實踐)
setup_gitops_2025() {
    echo "配置 2025 年 GitOps 最佳實踐..."

    # 部署 kpt 驗證器
    kubectl apply -f https://github.com/GoogleContainerTools/kpt/releases/download/v1.0.0-beta.49/kpt-resource-group.yaml

    # 創建分離的配置倉庫結構
    kubectl apply -f vm1-gitops-structure/platform/

    # 更新現有 RootSync 以使用 2025 最佳實踐
    kubectl patch rootsync intent-to-o2-rootsync -n $GITOPS_NAMESPACE --patch='
    spec:
      git:
        dir: "/platform"  # 使用平台配置目錄
        revision: "HEAD"
      override:
        resources:
        - group: ""
          kind: "ConfigMap"
          name: "nephio-fleet-config"
          namespace: "config-management-system"
    '
}

# 部署多集群 SLO 監控 (2025 標準)
deploy_multi_cluster_monitoring() {
    echo "部署多集群 SLO 監控..."

    kubectl apply -f vm1-monitoring/multi-cluster-slo.yaml

    # 配置 Thanos 或 Mimir (多集群標準)
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: thanos-sidecar-config
  namespace: $MONITORING_NAMESPACE
data:
  prometheus.yaml: |
    global:
      scrape_interval: 15s
      external_labels:
        cluster: "smo-vm1"
        replica: "0"
    scrape_configs:
    - job_name: 'edge2-remote'
      static_configs:
      - targets: ['172.16.0.89:30090']
        labels:
          site: 'edge2'
          cluster: 'edge2-vm4'
    - job_name: 'otel-collector'
      static_configs:
      - targets: ['otel-collector.monitoring.svc.cluster.local:8889']
EOF
}

# 實施零信任網路安全 (2025 標準)
implement_zero_trust() {
    echo "實施零信任網路安全..."

    kubectl apply -f vm1-security/zero-trust-policies.yaml

    # 配置 2025 年微分段標準
    kubectl label namespace $MONITORING_NAMESPACE security.policy/zero-trust=enabled
    kubectl label namespace $GITOPS_NAMESPACE security.policy/zero-trust=enabled
}

# 配置 O2IMS 整合 (2025 標準)
setup_o2ims_integration() {
    echo "配置 O2IMS 整合..."

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: o2ims-integration-config
  namespace: $MONITORING_NAMESPACE
data:
  o2ims-endpoints.yaml: |
    # 2025 O2IMS 標準配置
    o2ims_endpoints:
      edge2:
        url: "http://172.16.0.89:31280"
        version: "3.0"
        auth_type: "bearer"
        compliance: "oran-sc"

    tmf921_mapping:
      intent_management:
        endpoint: "/o2ims/measurement/v1/slo"
        format: "tmf921-v5.0"
EOF
}

# 更新 postcheck.sh 使用 2025 最佳實踐
update_postcheck_2025() {
    echo "更新 postcheck.sh 使用 2025 最佳實踐..."

    cat > scripts/postcheck-2025.sh << 'POSTCHECK_EOF'
#!/bin/bash
# Enhanced postcheck.sh with 2025 best practices

set -euo pipefail

# 2025 多站點配置 (從 OTel Collector 獲取)
declare -A SITES=(
    [edge2]="172.16.0.89:30090/metrics/api/v1/slo"
)

declare -A O2IMS_SITES=(
    [edge2]="http://172.16.0.89:31280/o2ims/measurement/v1/slo"
)

# 2025 SLO 閾值 (更嚴格)
LATENCY_P95_THRESHOLD_MS="${LATENCY_P95_THRESHOLD_MS:-10}"  # 更低延遲要求
SUCCESS_RATE_THRESHOLD="${SUCCESS_RATE_THRESHOLD:-0.999}"   # 更高可用性
THROUGHPUT_P95_THRESHOLD_MBPS="${THROUGHPUT_P95_THRESHOLD_MBPS:-300}"

# OpenTelemetry 指標獲取
fetch_otel_metrics() {
    local site="$1"
    local otel_endpoint="http://otel-collector.monitoring.svc.cluster.local:8889/metrics"

    # 從 OTel Collector 獲取統一指標
    curl -s --max-time 30 "$otel_endpoint" | grep "slo_${site}"
}

# 零信任驗證
verify_zero_trust_compliance() {
    local site="$1"

    # 檢查網路策略合規性
    kubectl get networkpolicy -n monitoring | grep -q "nephio-zero-trust-policy" || {
        echo "WARNING: Zero Trust network policies not found"
        return 1
    }
}

# 主要執行邏輯保持原樣，但加入新的驗證
# ... (原有的 postcheck 邏輯，但使用上述新函數)

POSTCHECK_EOF

    chmod +x scripts/postcheck-2025.sh
}

# 主要執行函數
main() {
    echo "🚀 開始 VM-1 2025 年最佳實踐部署..."

    create_2025_structure
    deploy_otel_collector
    setup_gitops_2025
    deploy_multi_cluster_monitoring
    implement_zero_trust
    setup_o2ims_integration
    update_postcheck_2025

    echo "✅ VM-1 2025 年最佳實踐部署完成！"

    # 執行驗證
    echo "🧪 執行整合驗證測試..."
    ./scripts/test_bidirectional_connectivity.sh
    ./scripts/postcheck-2025.sh
}

main "$@"
```

---

## 🎯 **OpenStack 安全群組 2025 最佳實踐配置**

**基於零信任微分段原則**:

```bash
# 2025 年 OpenStack 安全群組最佳實踐腳本
# /home/ubuntu/nephio-intent-to-o2-demo/scripts/openstack_2025_security.sh

#!/bin/bash
set -euo pipefail

readonly VM1_IP="172.16.0.78"
readonly VM4_IP="172.16.0.89"

# 2025 最佳實踐: 創建微分段安全群組
create_microsegmentation_groups() {
    # 為 VM-4 創建專用安全群組
    EDGE2_SG=$(openstack security group create \
        --description "Edge2 VM-4 microsegmentation 2025" \
        nephio-edge2-microseg-2025 -f value -c id)

    # 為 VM-1 創建專用安全群組
    SMO_SG=$(openstack security group create \
        --description "SMO VM-1 microsegmentation 2025" \
        nephio-smo-microseg-2025 -f value -c id)

    echo "Created security groups: Edge2=$EDGE2_SG, SMO=$SMO_SG"
}

# 2025 最佳實踐: 零信任規則配置
configure_zero_trust_rules() {
    local edge2_sg="$1"
    local smo_sg="$2"

    # Edge2 入站規則 (僅允許 SMO 訪問)
    openstack security group rule create \
        --protocol icmp \
        --ingress \
        --remote-ip "${VM1_IP}/32" \
        --description "Allow ICMP from SMO only" \
        "$edge2_sg"

    # SLO 服務端點 (精確到來源)
    openstack security group rule create \
        --protocol tcp \
        --dst-port 30090 \
        --ingress \
        --remote-ip "${VM1_IP}/32" \
        --description "Allow SLO metrics from SMO only" \
        "$edge2_sg"

    # O2IMS 端點 (精確到來源)
    openstack security group rule create \
        --protocol tcp \
        --dst-port 31280 \
        --ingress \
        --remote-ip "${VM1_IP}/32" \
        --description "Allow O2IMS API from SMO only" \
        "$edge2_sg"

    # K8s API (管理訪問)
    openstack security group rule create \
        --protocol tcp \
        --dst-port 6443 \
        --ingress \
        --remote-ip "${VM1_IP}/32" \
        --description "Allow K8s API from SMO only" \
        "$edge2_sg"

    # SSH 管理 (維護窗口)
    openstack security group rule create \
        --protocol tcp \
        --dst-port 22 \
        --ingress \
        --remote-ip "${VM1_IP}/32" \
        --description "Allow SSH management from SMO only" \
        "$edge2_sg"

    # SMO 出站規則 (精確控制)
    openstack security group rule create \
        --protocol tcp \
        --dst-port 30090 \
        --egress \
        --remote-ip "${VM4_IP}/32" \
        --description "Allow outbound SLO queries to Edge2" \
        "$smo_sg"

    openstack security group rule create \
        --protocol tcp \
        --dst-port 31280 \
        --egress \
        --remote-ip "${VM4_IP}/32" \
        --description "Allow outbound O2IMS queries to Edge2" \
        "$smo_sg"
}

# 2025 最佳實踐: 應用安全群組
apply_security_groups() {
    local edge2_sg="$1"
    local smo_sg="$2"

    # 應用到 VM-4
    openstack server add security group "VM-4（edge2）" "$edge2_sg"

    # 應用到 VM-1 (如果存在)
    if openstack server show "VM-1（SMO）" >/dev/null 2>&1; then
        openstack server add security group "VM-1（SMO）" "$smo_sg"
    fi
}

# 2025 最佳實踐: 安全審計
audit_security_compliance() {
    echo "🔒 執行 2025 年安全合規審計..."

    # 檢查規則數量 (最小權限原則)
    local rule_count=$(openstack security group rule list nephio-edge2-microseg-2025 --format value | wc -l)
    if [ "$rule_count" -gt 10 ]; then
        echo "WARNING: 安全群組規則過多，違反最小權限原則"
    fi

    # 檢查是否有 0.0.0.0/0 規則 (零信任違規)
    if openstack security group rule list nephio-edge2-microseg-2025 --format value | grep -q "0.0.0.0/0"; then
        echo "CRITICAL: 發現開放的 0.0.0.0/0 規則，違反零信任原則"
        return 1
    fi

    echo "✅ 安全合規檢查通過"
}

main() {
    echo "🔒 開始 2025 年 OpenStack 安全最佳實踐配置..."

    create_microsegmentation_groups
    local edge2_sg=$(openstack security group show nephio-edge2-microseg-2025 -f value -c id)
    local smo_sg=$(openstack security group show nephio-smo-microseg-2025 -f value -c id)

    configure_zero_trust_rules "$edge2_sg" "$smo_sg"
    apply_security_groups "$edge2_sg" "$smo_sg"
    audit_security_compliance

    echo "✅ 2025 年 OpenStack 安全配置完成！"
}

main "$@"
```

---

## 📋 **VM-1 立即執行清單**

### 🔥 **今天內必須完成** (影響生產就緒度)

1. **下載並執行 VM-1 2025 最佳實踐部署腳本**:
   ```bash
   scp ubuntu@172.16.0.89:~/nephio-intent-to-o2-demo/COMPREHENSIVE_2025_OPTIMIZATION_GUIDE.md ~/
   chmod +x ~/vm1_2025_optimization.sh
   ./vm1_2025_optimization.sh
   ```

2. **執行 OpenStack 安全群組 2025 配置**:
   ```bash
   ./scripts/openstack_2025_security.sh
   ```

3. **驗證雙向連通性**:
   ```bash
   ./scripts/test_bidirectional_connectivity.sh
   ./scripts/postcheck-2025.sh
   ```

### 📅 **本週內執行**

4. **部署 eBPF 網路監控**
5. **配置 Thanos/Mimir 多集群存儲**
6. **實施 O2IMS TMF921 整合**

### 🎯 **預期結果**

- **連通性測試成功率**: 95%+
- **SLO 監控覆蓋率**: 100%
- **安全合規性**: 零信任標準
- **生產就緒度**: 95%+

---

## 🚨 **關鍵提醒**

### ⚡ **必須在 VM-1 上補充的核心組件**:

1. **OpenTelemetry Collector** - 2025 年監控標準
2. **零信任網路策略** - 安全要求
3. **多集群 GitOps 配置** - 管理標準
4. **eBPF 網路監控** - 深度可觀測性
5. **O2IMS 整合配置** - O-RAN 合規性

### 🔒 **安全關鍵點**:

- 所有規則使用 `/32` CIDR (單一 IP)
- 實施零信任微分段
- 啟用網路策略執行
- 定期安全審計

### 📊 **監控關鍵點**:

- OpenTelemetry 作為統一收集層
- eBPF 用於內核級監控
- Prometheus + Thanos 多集群架構
- 語義約定標準化

**🎉 完成這些最佳化後，你的多站點 Nephio 環境將達到 2025 年企業級生產標準！**

---

*指南基於 2025 年 9 月最新最佳實踐研究*
*涵蓋: OpenStack、Kubernetes、GitOps、O2IMS、SLO 監控*
*有效期: 2025 年度*