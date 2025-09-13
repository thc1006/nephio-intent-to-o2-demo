#!/bin/bash
# OpenTelemetry Collector 部署腳本 - 2025 年最佳實踐
# /home/ubuntu/nephio-intent-to-o2-demo/scripts/vm1-optimization/deploy_opentelemetry_collector.sh

set -euo pipefail

readonly PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
readonly MONITORING_NAMESPACE="monitoring"
readonly LOG_FILE="$PROJECT_ROOT/artifacts/otel-deployment-$(date +%Y%m%d-%H%M%S).log"

# Edge 站點配置
readonly EDGE2_IP="172.16.0.89"
readonly EDGE1_IP="172.16.4.45"
readonly SLO_PORT="30090"
readonly O2IMS_PORT="31280"

# 日誌函數
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

# 創建日誌目錄
mkdir -p "$(dirname "$LOG_FILE")"

# 檢查 OpenTelemetry Collector 二進制
check_otel_binary() {
    log "檢查 OpenTelemetry Collector 二進制..."

    if ! command -v otelcol-contrib &> /dev/null; then
        log "下載 OpenTelemetry Collector 二進制..."

        local temp_dir=$(mktemp -d)
        cd "$temp_dir"

        curl -LO "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.104.0/otelcol-contrib_0.104.0_linux_amd64.tar.gz"
        tar -xzf otelcol-contrib_*.tar.gz

        sudo mv otelcol-contrib /usr/local/bin/
        sudo chmod +x /usr/local/bin/otelcol-contrib

        cd - && rm -rf "$temp_dir"
        log "✅ OpenTelemetry Collector 二進制安裝完成"
    else
        log "✅ OpenTelemetry Collector 二進制已存在"
    fi
}

# 創建高級 OpenTelemetry 配置
create_advanced_otel_config() {
    log "創建高級 OpenTelemetry Collector 配置..."

    mkdir -p "$PROJECT_ROOT/vm1-components"

    cat > "$PROJECT_ROOT/vm1-components/otel-collector-advanced.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-advanced-config
  namespace: monitoring
data:
  otel-collector.yaml: |
    # 2025 年高級 OpenTelemetry 配置
    receivers:
      # Prometheus 多站點收集
      prometheus/edge2:
        config:
          scrape_configs:
          - job_name: 'edge2-slo-metrics'
            scrape_interval: 15s
            metrics_path: '/metrics/api/v1/slo'
            static_configs:
            - targets: ['172.16.0.89:30090']
              labels:
                site: 'edge2'
                cluster: 'vm-4-edge2'
                environment: 'production'
                region: 'region-1'
          - job_name: 'edge2-o2ims-metrics'
            scrape_interval: 30s
            metrics_path: '/o2ims/measurement/v1/metrics'
            static_configs:
            - targets: ['172.16.0.89:31280']
              labels:
                site: 'edge2'
                service: 'o2ims'
                environment: 'production'

      prometheus/edge1:
        config:
          scrape_configs:
          - job_name: 'edge1-slo-metrics'
            scrape_interval: 15s
            metrics_path: '/metrics/api/v1/slo'
            static_configs:
            - targets: ['172.16.4.45:30090']
              labels:
                site: 'edge1'
                cluster: 'vm-2-edge1'
                environment: 'production'
                region: 'region-1'

      # OTLP 接收器 (traces and metrics)
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      # Jaeger 接收器 (legacy traces)
      jaeger:
        protocols:
          grpc:
            endpoint: 0.0.0.0:14250
          thrift_http:
            endpoint: 0.0.0.0:14268

      # Host metrics 收集
      hostmetrics:
        collection_interval: 30s
        scrapers:
          cpu:
          disk:
          load:
          filesystem:
          memory:
          network:
          process:

    processors:
      # 批處理器
      batch:
        timeout: 10s
        send_batch_size: 1024

      # 內存限制器
      memory_limiter:
        limit_mib: 1024
        spike_limit_mib: 256

      # 資源處理器 - 2025 語義約定
      resource:
        attributes:
        - key: deployment.environment
          value: "production"
          action: upsert
        - key: service.namespace
          value: "nephio-multi-site"
          action: upsert
        - key: service.version
          value: "v2025.09"
          action: upsert
        - key: telemetry.sdk.version
          value: "0.104.0"
          action: upsert

      # 屬性處理器 - 標準化標籤
      attributes:
        actions:
        - key: cluster
          action: update
          from_attribute: cluster
        - key: site
          action: update
          from_attribute: site

      # 指標轉換處理器
      metricstransform:
        transforms:
        - include: slo_.*
          match_type: regexp
          action: update
          new_name: nephio_${1}

      # K8s 屬性處理器
      k8sattributes:
        auth_type: "serviceAccount"
        passthrough: false
        filter:
          node_from_env_var: KUBE_NODE_NAME
        extract:
          metadata:
          - k8s.pod.name
          - k8s.pod.uid
          - k8s.namespace.name
          - k8s.node.name
        pod_association:
        - sources:
          - from: resource_attribute
            name: k8s.pod.ip
        - sources:
          - from: resource_attribute
            name: k8s.pod.uid
        - sources:
          - from: connection

    exporters:
      # Prometheus 導出器 - 2025 最佳實踐
      prometheus:
        endpoint: "0.0.0.0:8889"
        enable_open_metrics: true
        add_metric_suffixes: true
        resource_to_telemetry_conversion:
          enabled: true

      # OTLP 導出器 (for upstream aggregation)
      otlp/jaeger:
        endpoint: jaeger-collector:4317
        tls:
          insecure: true

      # Logging 導出器 (debugging)
      logging:
        loglevel: info

      # File 導出器 (backup)
      file:
        path: /tmp/otel-metrics.json

    extensions:
      # Health check
      health_check:
        endpoint: 0.0.0.0:13133

      # pprof for debugging
      pprof:
        endpoint: 0.0.0.0:1777

      # Memory ballast
      memory_ballast:
        size_mib: 512

    service:
      extensions: [health_check, pprof, memory_ballast]
      pipelines:
        metrics:
          receivers: [prometheus/edge2, prometheus/edge1, otlp, hostmetrics]
          processors: [memory_limiter, resource, attributes, metricstransform, k8sattributes, batch]
          exporters: [prometheus, logging, file]
        traces:
          receivers: [otlp, jaeger]
          processors: [memory_limiter, resource, k8sattributes, batch]
          exporters: [otlp/jaeger, logging]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-advanced
  namespace: monitoring
  labels:
    app: otel-collector
    version: advanced
spec:
  replicas: 2
  selector:
    matchLabels:
      app: otel-collector
      version: advanced
  template:
    metadata:
      labels:
        app: otel-collector
        version: advanced
    spec:
      serviceAccountName: otel-collector
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
        - containerPort: 8889
          name: prometheus
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        - containerPort: 14250
          name: jaeger-grpc
        - containerPort: 14268
          name: jaeger-http
        - containerPort: 13133
          name: health
        env:
        - name: KUBE_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        resources:
          requests:
            memory: 512Mi
            cpu: 200m
          limits:
            memory: 1Gi
            cpu: 1000m
        livenessProbe:
          httpGet:
            path: /
            port: 13133
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 13133
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: otel-collector-config-vol
        configMap:
          name: otel-collector-advanced-config

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: monitoring

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
- apiGroups: [""]
  resources: ["pods", "nodes", "services", "endpoints", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["replicasets", "deployments", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-collector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-collector
subjects:
- kind: ServiceAccount
  name: otel-collector
  namespace: monitoring

---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector-advanced
  namespace: monitoring
  labels:
    app: otel-collector
spec:
  selector:
    app: otel-collector
    version: advanced
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
  - name: jaeger-grpc
    port: 14250
    targetPort: 14250
  - name: jaeger-http
    port: 14268
    targetPort: 14268
  - name: health
    port: 13133
    targetPort: 13133
EOF

    log "✅ 高級 OpenTelemetry Collector 配置創建完成"
}

# 部署 OpenTelemetry Collector
deploy_otel_collector() {
    log "部署 OpenTelemetry Collector..."

    # 創建命名空間
    kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # 部署配置
    if kubectl apply -f "$PROJECT_ROOT/vm1-components/otel-collector-advanced.yaml"; then
        log "✅ OpenTelemetry Collector 配置已應用"
    else
        log_error "OpenTelemetry Collector 配置應用失敗"
        return 1
    fi

    # 等待部署就緒
    log "等待 OpenTelemetry Collector 就緒..."
    if kubectl wait --for=condition=available --timeout=300s deployment/otel-collector-advanced -n "$MONITORING_NAMESPACE"; then
        log "✅ OpenTelemetry Collector 部署成功"
    else
        log_error "OpenTelemetry Collector 部署超時"
        kubectl describe deployment otel-collector-advanced -n "$MONITORING_NAMESPACE" >> "$LOG_FILE"
        return 1
    fi
}

# 驗證 OpenTelemetry Collector
verify_otel_collector() {
    log "驗證 OpenTelemetry Collector..."

    # 檢查 Pod 狀態
    local pod_count=$(kubectl get pods -n "$MONITORING_NAMESPACE" -l app=otel-collector,version=advanced --field-selector=status.phase=Running | grep -c otel-collector || echo "0")
    if [[ "$pod_count" -ge 1 ]]; then
        log "✅ OpenTelemetry Collector Pods 運行正常 ($pod_count 個)"
    else
        log_error "OpenTelemetry Collector Pods 未正常運行"
        kubectl get pods -n "$MONITORING_NAMESPACE" -l app=otel-collector >> "$LOG_FILE"
        return 1
    fi

    # 檢查健康狀態
    local pod_name=$(kubectl get pods -n "$MONITORING_NAMESPACE" -l app=otel-collector,version=advanced -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "$pod_name" ]]; then
        if kubectl exec -n "$MONITORING_NAMESPACE" "$pod_name" -- curl -s http://localhost:13133 | grep -q "Server available"; then
            log "✅ OpenTelemetry Collector 健康檢查通過"
        else
            log "WARNING: OpenTelemetry Collector 健康檢查失敗"
        fi
    fi

    # 測試指標端點
    log "測試 Prometheus 指標端點..."
    kubectl port-forward -n "$MONITORING_NAMESPACE" service/otel-collector-advanced 8889:8889 &
    local pf_pid=$!
    sleep 10

    if curl -s --max-time 10 http://localhost:8889/metrics | grep -q "otelcol_process"; then
        log "✅ Prometheus 指標端點正常"
    else
        log "WARNING: Prometheus 指標端點可能有問題"
    fi

    kill $pf_pid 2>/dev/null || true
    wait $pf_pid 2>/dev/null || true
}

# 測試邊緣站點連通性
test_edge_connectivity() {
    log "測試邊緣站點連通性..."

    # 測試 Edge2 連接
    if curl -s --max-time 10 "http://${EDGE2_IP}:${SLO_PORT}/health" &>/dev/null; then
        log "✅ Edge2 (${EDGE2_IP}:${SLO_PORT}) 連接正常"
    else
        log "WARNING: Edge2 (${EDGE2_IP}:${SLO_PORT}) 連接失敗"
    fi

    # 測試 Edge1 連接 (如果可用)
    if curl -s --max-time 10 "http://${EDGE1_IP}:${SLO_PORT}/health" &>/dev/null; then
        log "✅ Edge1 (${EDGE1_IP}:${SLO_PORT}) 連接正常"
    else
        log "INFO: Edge1 (${EDGE1_IP}:${SLO_PORT}) 不可用或未配置"
    fi

    # 測試 Edge2 O2IMS
    if curl -s --max-time 10 "http://${EDGE2_IP}:${O2IMS_PORT}/o2ims/api/v1/health" &>/dev/null; then
        log "✅ Edge2 O2IMS (${EDGE2_IP}:${O2IMS_PORT}) 連接正常"
    else
        log "INFO: Edge2 O2IMS (${EDGE2_IP}:${O2IMS_PORT}) 不可用或未配置"
    fi
}

# 配置告警規則
setup_alerting() {
    log "配置 OpenTelemetry 告警規則..."

    cat > "$PROJECT_ROOT/vm1-components/otel-alerts.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-alerting-rules
  namespace: monitoring
data:
  otel-alerts.yaml: |
    groups:
    - name: otel-collector
      rules:
      - alert: OtelCollectorDown
        expr: up{job="otel-collector"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "OpenTelemetry Collector is down"
          description: "OpenTelemetry Collector has been down for more than 5 minutes"

      - alert: OtelCollectorHighMemory
        expr: otelcol_process_memory_rss > 1000000000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "OpenTelemetry Collector high memory usage"
          description: "OpenTelemetry Collector memory usage is above 1GB"

      - alert: EdgeSiteDown
        expr: up{site=~"edge.*"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Edge site {{ $labels.site }} is down"
          description: "Edge site {{ $labels.site }} has been unreachable for more than 2 minutes"
EOF

    kubectl apply -f "$PROJECT_ROOT/vm1-components/otel-alerts.yaml"
    log "✅ OpenTelemetry 告警規則配置完成"
}

# 主要執行函數
main() {
    log "🚀 開始部署 OpenTelemetry Collector (2025 最佳實踐)..."

    check_otel_binary
    create_advanced_otel_config
    deploy_otel_collector
    verify_otel_collector
    test_edge_connectivity
    setup_alerting

    log "✅ OpenTelemetry Collector 部署完成！"
    log "📊 指標端點: http://localhost:8889/metrics"
    log "🏥 健康檢查: http://localhost:13133"
    log "📄 詳細日誌: $LOG_FILE"

    # 顯示部署狀態
    kubectl get all -n "$MONITORING_NAMESPACE" -l app=otel-collector
}

# 錯誤處理
trap 'log_error "OpenTelemetry Collector 部署失敗，查看日誌: $LOG_FILE"' ERR

main "$@"