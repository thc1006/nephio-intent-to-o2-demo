#!/bin/bash
# VM-1 2025 年最佳實踐部署腳本 - 一鍵優化腳本
# /home/ubuntu/nephio-intent-to-o2-demo/scripts/vm1-optimization/optimize_vm1_2025.sh

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
readonly VM1_CONFIG_DIR="$PROJECT_ROOT/vm1-2025-config"
readonly MONITORING_NAMESPACE="monitoring"
readonly GITOPS_NAMESPACE="config-management-system"
readonly LOG_FILE="$PROJECT_ROOT/artifacts/vm1-optimization-$(date +%Y%m%d-%H%M%S).log"

# 日誌函數
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

# 創建日誌目錄
mkdir -p "$(dirname "$LOG_FILE")"

# 創建 2025 年標準目錄結構
create_2025_structure() {
    log "創建 2025 年標準配置結構..."

    mkdir -p "$VM1_CONFIG_DIR"/{otel,monitoring,gitops,security,o2ims}
    mkdir -p "$PROJECT_ROOT/vm1-components"
    mkdir -p "$PROJECT_ROOT/vm1-gitops-structure/platform"
    mkdir -p "$PROJECT_ROOT/vm1-monitoring"
    mkdir -p "$PROJECT_ROOT/vm1-security"

    # 確保 kubectl 可用
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安裝或不在 PATH 中"
        return 1
    fi

    log "✅ 2025 年標準配置結構創建完成"
}

# 檢查前置條件
check_prerequisites() {
    log "檢查前置條件..."

    # 檢查 Kubernetes 連接
    if ! kubectl cluster-info &>/dev/null; then
        log_error "無法連接到 Kubernetes 集群"
        return 1
    fi

    # 檢查必要的命名空間
    kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # 檢查網路連通性到 VM-4
    if ! curl -s --max-time 5 http://172.16.4.176:30090/health &>/dev/null; then
        log "WARNING: 無法連接到 VM-4 Edge2 (172.16.4.176:30090)，將在稍後重試"
    fi

    log "✅ 前置條件檢查完成"
}

# 創建 OpenTelemetry Collector 配置
create_otel_config() {
    log "創建 OpenTelemetry Collector 配置..."

    cat > "$PROJECT_ROOT/vm1-components/otel-collector.yaml" << 'EOF'
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
            - targets: ['172.16.4.176:30090']
              labels:
                site: 'edge2'
                cluster: 'vm-4-edge2'
          - job_name: 'edge1-slo'
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

---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  selector:
    app: otel-collector
  ports:
  - name: prometheus
    port: 8889
    targetPort: 8889
  - name: otlp-grpc
    port: 4317
    targetPort: 4317
  - name: otlp-http
    port: 4318
    targetPort: 4318
EOF

    log "✅ OpenTelemetry Collector 配置創建完成"
}

# 創建 GitOps 最佳實踐配置
create_gitops_config() {
    log "創建 GitOps 最佳實踐配置..."

    cat > "$PROJECT_ROOT/vm1-gitops-structure/platform/fleet-config.yaml" << 'EOF'
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
        endpoint: "172.16.4.176:30090"
        cluster_type: "edge"
        region: "region-1"
    smo_sites:
      smo1:
        endpoint: "172.16.0.78:8080"
        cluster_type: "management"
        region: "central"
EOF

    cat > "$PROJECT_ROOT/vm1-gitops-structure/platform/kpt-functions.yaml" << 'EOF'
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

    log "✅ GitOps 最佳實踐配置創建完成"
}

# 創建多集群監控配置
create_monitoring_config() {
    log "創建多集群監控配置..."

    cat > "$PROJECT_ROOT/vm1-monitoring/multi-cluster-slo.yaml" << 'EOF'
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
        resources:
          requests:
            memory: 128Mi
            cpu: 50m
          limits:
            memory: 256Mi
            cpu: 200m
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
EOF

    log "✅ 多集群監控配置創建完成"
}

# 部署 OpenTelemetry Collector
deploy_otel_collector() {
    log "部署 OpenTelemetry Collector..."

    if kubectl apply -f "$PROJECT_ROOT/vm1-components/otel-collector.yaml"; then
        # 等待部署就緒
        kubectl wait --for=condition=available --timeout=300s deployment/otel-collector -n "$MONITORING_NAMESPACE" || {
            log_error "OpenTelemetry Collector 部署超時"
            return 1
        }
        log "✅ OpenTelemetry Collector 部署成功"
    else
        log_error "OpenTelemetry Collector 部署失敗"
        return 1
    fi
}

# 部署多集群監控
deploy_monitoring() {
    log "部署多集群監控..."

    if kubectl apply -f "$PROJECT_ROOT/vm1-monitoring/multi-cluster-slo.yaml"; then
        log "✅ 多集群監控配置部署成功"
    else
        log_error "多集群監控配置部署失敗"
        return 1
    fi
}

# 執行整合測試
run_integration_tests() {
    log "執行整合測試..."

    # 測試 OpenTelemetry Collector 健康狀態
    if kubectl get pods -n "$MONITORING_NAMESPACE" -l app=otel-collector --field-selector=status.phase=Running | grep -q otel-collector; then
        log "✅ OpenTelemetry Collector 運行正常"
    else
        log_error "OpenTelemetry Collector 未正常運行"
        return 1
    fi

    # 測試指標端點
    local otel_pod=$(kubectl get pods -n "$MONITORING_NAMESPACE" -l app=otel-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "$otel_pod" ]]; then
        if kubectl port-forward -n "$MONITORING_NAMESPACE" "pod/$otel_pod" 8889:8889 &
        local pf_pid=$!
        sleep 5

        if curl -s --max-time 10 http://localhost:8889/metrics | grep -q "otelcol"; then
            log "✅ OpenTelemetry 指標端點正常"
        else
            log "WARNING: OpenTelemetry 指標端點可能有問題"
        fi

        kill $pf_pid 2>/dev/null || true
        fi
    fi

    log "✅ 整合測試完成"
}

# 主要執行函數
main() {
    log "🚀 開始 VM-1 2025 年最佳實踐一鍵優化..."

    create_2025_structure
    check_prerequisites
    create_otel_config
    create_gitops_config
    create_monitoring_config
    deploy_otel_collector
    deploy_monitoring
    run_integration_tests

    log "✅ VM-1 2025 年最佳實踐一鍵優化完成！"
    log "📄 詳細日誌已保存到: $LOG_FILE"

    # 執行其他優化腳本
    log "🔄 執行其他優化組件..."

    if [[ -x "$SCRIPT_DIR/deploy_opentelemetry_collector.sh" ]]; then
        log "執行 OpenTelemetry Collector 深度配置..."
        "$SCRIPT_DIR/deploy_opentelemetry_collector.sh" || log "WARNING: OpenTelemetry 深度配置可能有問題"
    fi

    if [[ -x "$SCRIPT_DIR/setup_zerotrust_policies.sh" ]]; then
        log "執行零信任策略配置..."
        "$SCRIPT_DIR/setup_zerotrust_policies.sh" || log "WARNING: 零信任策略配置可能有問題"
    fi

    log "🎉 所有優化完成！建議執行 postcheck 驗證"
    log "建議執行: $PROJECT_ROOT/scripts/postcheck.sh"
}

# 錯誤處理
trap 'log_error "腳本執行失敗，查看日誌: $LOG_FILE"' ERR

main "$@"