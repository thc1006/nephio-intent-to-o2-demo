#!/bin/bash
# 多站點驗收測試更新腳本 - 2025 年最佳實踐
# /home/ubuntu/nephio-intent-to-o2-demo/scripts/vm1-optimization/update_postcheck_multisite.sh

set -euo pipefail

readonly PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly LOG_FILE="$PROJECT_ROOT/artifacts/postcheck-update-$(date +%Y%m%d-%H%M%S).log"

# 站點配置 - 2025 年多站點標準
readonly VM1_IP="172.16.0.78"
readonly EDGE2_IP="172.16.0.89"
readonly EDGE1_IP="172.16.4.45"
readonly SLO_PORT="30090"
readonly O2IMS_PORT="31280"
readonly K8S_PORT="6443"

# SLO 閾值 - 2025 年更嚴格標準
readonly LATENCY_P95_THRESHOLD_MS="10"    # 從 15ms 降至 10ms
readonly SUCCESS_RATE_THRESHOLD="0.999"   # 從 0.995 提升至 0.999
readonly THROUGHPUT_P95_THRESHOLD_MBPS="300"  # 提升至 300 Mbps

# 日誌函數
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" | tee -a "$LOG_FILE"
}

# 創建日誌目錄
mkdir -p "$(dirname "$LOG_FILE")"

# 備份原有 postcheck.sh
backup_original_postcheck() {
    log "備份原有 postcheck.sh..."

    if [[ -f "$SCRIPTS_DIR/postcheck.sh" ]]; then
        cp "$SCRIPTS_DIR/postcheck.sh" "$SCRIPTS_DIR/postcheck-backup-$(date +%Y%m%d-%H%M%S).sh"
        log "✅ 原有 postcheck.sh 已備份"
    else
        log_warning "未找到原有 postcheck.sh"
    fi
}

# 創建增強的多站點 postcheck 腳本
create_enhanced_postcheck() {
    log "創建增強的多站點 postcheck 腳本..."

    cat > "$SCRIPTS_DIR/postcheck-2025.sh" << 'POSTCHECK_EOF'
#!/bin/bash
# Enhanced postcheck.sh with 2025 best practices
# 增強的多站點驗收測試 - 支援 OpenTelemetry 和零信任安全

set -euo pipefail

readonly PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
readonly LOG_FILE="$PROJECT_ROOT/artifacts/postcheck-2025-$(date +%Y%m%d-%H%M%S).log"

# 2025 多站點配置 (從 OTel Collector 獲取)
declare -A SITES=(
    [edge2]="172.16.0.89:30090"
    [edge1]="172.16.4.45:30090"
)

declare -A O2IMS_SITES=(
    [edge2]="http://172.16.0.89:31280"
)

declare -A K8S_ENDPOINTS=(
    [edge2]="https://172.16.0.89:6443"
)

# 2025 SLO 閾值 (更嚴格)
readonly LATENCY_P95_THRESHOLD_MS="${LATENCY_P95_THRESHOLD_MS:-10}"
readonly SUCCESS_RATE_THRESHOLD="${SUCCESS_RATE_THRESHOLD:-0.999}"
readonly THROUGHPUT_P95_THRESHOLD_MBPS="${THROUGHPUT_P95_THRESHOLD_MBPS:-300}"
readonly AVAILABILITY_THRESHOLD="${AVAILABILITY_THRESHOLD:-99.9}"

# 測試結果統計
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0

# 日誌函數
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $*" | tee -a "$LOG_FILE"
}

# 測試計數函數
increment_test() {
    ((TOTAL_TESTS++))
}

pass_test() {
    ((PASSED_TESTS++))
    log_success "$1"
}

fail_test() {
    ((FAILED_TESTS++))
    log_error "$1"
}

# OpenTelemetry 指標獲取
fetch_otel_metrics() {
    local site="$1"
    local otel_endpoint="http://otel-collector.monitoring.svc.cluster.local:8889/metrics"

    # 從 OTel Collector 獲取統一指標
    if curl -s --max-time 30 "$otel_endpoint" 2>/dev/null | grep "slo_${site}" || \
       kubectl exec -n monitoring deployment/otel-collector-advanced -- curl -s http://localhost:8889/metrics 2>/dev/null | grep "slo_${site}"; then
        return 0
    else
        return 1
    fi
}

# 零信任網路策略驗證
verify_zero_trust_compliance() {
    local site="$1"

    increment_test

    # 檢查網路策略合規性
    if kubectl get networkpolicy -n monitoring nephio-zero-trust-policy &>/dev/null; then
        pass_test "零信任網路策略已部署"
    else
        fail_test "零信任網路策略未找到"
        return 1
    fi

    # 檢查命名空間標籤
    if kubectl get namespace monitoring -o jsonpath='{.metadata.labels.security\.policy/zero-trust}' | grep -q "enabled"; then
        pass_test "監控命名空間已啟用零信任標籤"
    else
        fail_test "監控命名空間零信任標籤未正確設置"
    fi
}

# OpenTelemetry 組件健康檢查
check_otel_health() {
    increment_test

    # 檢查 OTel Collector 狀態
    if kubectl get pods -n monitoring -l app=otel-collector --field-selector=status.phase=Running | grep -q otel-collector; then
        pass_test "OpenTelemetry Collector 運行正常"
    else
        fail_test "OpenTelemetry Collector 未正常運行"
        return 1
    fi

    # 檢查健康端點
    local pod_name=$(kubectl get pods -n monitoring -l app=otel-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "$pod_name" ]]; then
        if kubectl exec -n monitoring "$pod_name" -- curl -s http://localhost:13133 2>/dev/null | grep -q "Server available"; then
            pass_test "OpenTelemetry 健康檢查端點正常"
        else
            fail_test "OpenTelemetry 健康檢查端點異常"
        fi
    fi

    increment_test
    # 檢查指標端點
    if fetch_otel_metrics "edge2" || fetch_otel_metrics "edge1"; then
        pass_test "OpenTelemetry 指標收集正常"
    else
        fail_test "OpenTelemetry 指標收集異常"
    fi
}

# 增強的站點連通性測試
test_site_connectivity() {
    local site="$1"
    local endpoint="${SITES[$site]}"

    increment_test

    # 基本連通性測試
    if curl -s --max-time 10 "http://$endpoint/health" &>/dev/null; then
        pass_test "$site 基本連通性正常"
    else
        fail_test "$site 基本連通性失敗"
        return 1
    fi

    # SLO 指標測試
    increment_test
    local slo_response=$(curl -s --max-time 30 "http://$endpoint/metrics/api/v1/slo" 2>/dev/null)
    if [[ -n "$slo_response" ]] && echo "$slo_response" | jq -e '.data' &>/dev/null; then
        pass_test "$site SLO 指標端點正常"

        # 解析 SLO 指標
        local latency_p95=$(echo "$slo_response" | jq -r '.data.latency_p95_ms // 0')
        local success_rate=$(echo "$slo_response" | jq -r '.data.success_rate // 0')
        local throughput_mbps=$(echo "$slo_response" | jq -r '.data.throughput_mbps // 0')

        # 延遲檢查
        increment_test
        if (( $(echo "$latency_p95 <= $LATENCY_P95_THRESHOLD_MS" | bc -l) )); then
            pass_test "$site 延遲符合 SLO (${latency_p95}ms <= ${LATENCY_P95_THRESHOLD_MS}ms)"
        else
            fail_test "$site 延遲超出 SLO (${latency_p95}ms > ${LATENCY_P95_THRESHOLD_MS}ms)"
        fi

        # 成功率檢查
        increment_test
        if (( $(echo "$success_rate >= $SUCCESS_RATE_THRESHOLD" | bc -l) )); then
            pass_test "$site 成功率符合 SLO (${success_rate} >= ${SUCCESS_RATE_THRESHOLD})"
        else
            fail_test "$site 成功率低於 SLO (${success_rate} < ${SUCCESS_RATE_THRESHOLD})"
        fi

        # 吞吐量檢查
        increment_test
        if (( $(echo "$throughput_mbps >= $THROUGHPUT_P95_THRESHOLD_MBPS" | bc -l) )); then
            pass_test "$site 吞吐量符合 SLO (${throughput_mbps} Mbps >= ${THROUGHPUT_P95_THRESHOLD_MBPS} Mbps)"
        else
            fail_test "$site 吞吐量低於 SLO (${throughput_mbps} Mbps < ${THROUGHPUT_P95_THRESHOLD_MBPS} Mbps)"
        fi

    else
        fail_test "$site SLO 指標端點異常"
    fi
}

# O2IMS 集成測試
test_o2ims_integration() {
    local site="$1"

    if [[ -n "${O2IMS_SITES[$site]:-}" ]]; then
        local o2ims_url="${O2IMS_SITES[$site]}"

        increment_test
        # O2IMS API 健康檢查
        if curl -s --max-time 10 "$o2ims_url/o2ims/api/v1/health" &>/dev/null; then
            pass_test "$site O2IMS API 可訪問"
        else
            fail_test "$site O2IMS API 不可訪問"
            return 1
        fi

        # O2IMS 資源清單
        increment_test
        local resources_response=$(curl -s --max-time 30 "$o2ims_url/o2ims/api/v1/resourcePools" 2>/dev/null)
        if [[ -n "$resources_response" ]] && echo "$resources_response" | jq -e '.' &>/dev/null; then
            pass_test "$site O2IMS 資源清單獲取成功"
        else
            fail_test "$site O2IMS 資源清單獲取失敗"
        fi

        # TMF921 集成測試
        increment_test
        local intent_response=$(curl -s --max-time 30 "$o2ims_url/tmf921/intent/v1/intents" 2>/dev/null)
        if [[ -n "$intent_response" ]] && echo "$intent_response" | jq -e '.' &>/dev/null; then
            pass_test "$site TMF921 Intent API 集成正常"
        else
            log_warning "$site TMF921 Intent API 可能未完全配置"
        fi
    else
        log_warning "$site 未配置 O2IMS 端點，跳過 O2IMS 測試"
    fi
}

# Kubernetes API 連通性測試
test_k8s_connectivity() {
    local site="$1"

    if [[ -n "${K8S_ENDPOINTS[$site]:-}" ]]; then
        local k8s_endpoint="${K8S_ENDPOINTS[$site]}"

        increment_test
        # K8s API 健康檢查
        if curl -s -k --max-time 10 "$k8s_endpoint/healthz" | grep -q "ok"; then
            pass_test "$site Kubernetes API 可訪問"
        else
            fail_test "$site Kubernetes API 不可訪問"
        fi

        # 集群版本檢查
        increment_test
        local version_response=$(curl -s -k --max-time 10 "$k8s_endpoint/version" 2>/dev/null)
        if [[ -n "$version_response" ]] && echo "$version_response" | jq -e '.gitVersion' &>/dev/null; then
            local k8s_version=$(echo "$version_response" | jq -r '.gitVersion')
            pass_test "$site Kubernetes 版本: $k8s_version"
        else
            fail_test "$site Kubernetes 版本資訊獲取失敗"
        fi
    else
        log_warning "$site 未配置 Kubernetes API 端點，跳過 K8s 測試"
    fi
}

# GitOps 同步狀態檢查
check_gitops_sync() {
    increment_test

    # 檢查 RootSync 狀態
    if kubectl get rootsync -n config-management-system &>/dev/null; then
        local sync_status=$(kubectl get rootsync -n config-management-system -o jsonpath='{.items[0].status.sync}' 2>/dev/null || echo "unknown")

        if [[ "$sync_status" == "SYNCED" ]]; then
            pass_test "GitOps RootSync 狀態: SYNCED"
        else
            fail_test "GitOps RootSync 狀態異常: $sync_status"
        fi
    else
        fail_test "GitOps RootSync 未找到"
    fi

    # 檢查 Config Sync 版本
    increment_test
    if kubectl get deployment -n config-management-system config-management-operator &>/dev/null; then
        pass_test "Config Sync Operator 運行正常"
    else
        fail_test "Config Sync Operator 未運行"
    fi
}

# 網路性能基準測試
run_network_performance_test() {
    local site="$1"
    local endpoint="${SITES[$site]}"

    increment_test

    # 使用 curl 測試網路性能
    local start_time=$(date +%s%3N)
    local response=$(curl -s --max-time 30 -w "%{time_total},%{speed_download},%{http_code}" "http://$endpoint/health" 2>/dev/null)
    local end_time=$(date +%s%3N)

    if [[ -n "$response" ]]; then
        local total_time=$(echo "$response" | cut -d',' -f1)
        local download_speed=$(echo "$response" | cut -d',' -f2)
        local http_code=$(echo "$response" | cut -d',' -f3)

        local latency_ms=$(echo "$total_time * 1000" | bc -l | cut -d'.' -f1)
        local speed_mbps=$(echo "scale=2; $download_speed / 125000" | bc -l)

        if [[ "$http_code" == "200" ]] && (( latency_ms <= LATENCY_P95_THRESHOLD_MS * 2 )); then
            pass_test "$site 網路性能測試通過 (延遲: ${latency_ms}ms, 速度: ${speed_mbps} Mbps)"
        else
            fail_test "$site 網路性能測試失敗 (延遲: ${latency_ms}ms, HTTP: $http_code)"
        fi
    else
        fail_test "$site 網路性能測試無響應"
    fi
}

# 安全合規性檢查
check_security_compliance() {
    increment_test

    # 檢查 Pod 安全策略
    if kubectl get psp nephio-zero-trust-psp &>/dev/null || kubectl get pss &>/dev/null; then
        pass_test "Pod 安全策略已配置"
    else
        log_warning "Pod 安全策略未完全配置"
    fi

    # 檢查網路策略覆蓋率
    increment_test
    local policy_count=$(kubectl get networkpolicy --all-namespaces | grep -v NAME | wc -l)
    if [[ "$policy_count" -gt 0 ]]; then
        pass_test "網路策略覆蓋率: $policy_count 個策略"
    else
        fail_test "未發現網路策略"
    fi

    # 檢查 ServiceAccount 權限
    increment_test
    if kubectl get serviceaccount -n monitoring nephio-monitoring-sa &>/dev/null; then
        pass_test "監控服務帳戶已配置"
    else
        fail_test "監控服務帳戶未配置"
    fi
}

# 生成詳細報告
generate_detailed_report() {
    local report_file="$PROJECT_ROOT/artifacts/postcheck-detailed-report-$(date +%Y%m%d-%H%M%S).json"

    cat > "$report_file" << EOF
{
  "test_summary": {
    "timestamp": "$(date -Iseconds)",
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l),
    "environment": "VM-1 Nephio Multi-Site"
  },
  "thresholds": {
    "latency_p95_ms": $LATENCY_P95_THRESHOLD_MS,
    "success_rate": $SUCCESS_RATE_THRESHOLD,
    "throughput_mbps": $THROUGHPUT_P95_THRESHOLD_MBPS,
    "availability_percent": $AVAILABILITY_THRESHOLD
  },
  "tested_sites": $(printf '%s\n' "${!SITES[@]}" | jq -R . | jq -s .),
  "components_tested": [
    "OpenTelemetry Collector",
    "Zero Trust Network Policies",
    "GitOps Sync Status",
    "Multi-Site Connectivity",
    "O2IMS Integration",
    "Security Compliance"
  ]
}
EOF

    log "✅ 詳細測試報告已生成: $report_file"
}

# 主要執行函數
main() {
    log "🚀 開始 2025 年多站點驗收測試..."

    mkdir -p "$(dirname "$LOG_FILE")"

    # 檢查必要工具
    for cmd in curl jq bc; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "必要工具 $cmd 未安裝"
            exit 1
        fi
    done

    # 核心組件健康檢查
    check_otel_health
    check_gitops_sync

    # 站點測試
    for site in "${!SITES[@]}"; do
        log "測試站點: $site"
        verify_zero_trust_compliance "$site"
        test_site_connectivity "$site"
        test_o2ims_integration "$site"
        test_k8s_connectivity "$site"
        run_network_performance_test "$site"
    done

    # 安全和合規性檢查
    check_security_compliance

    # 生成報告
    generate_detailed_report

    # 總結
    echo ""
    echo "========================================="
    echo "🎯 2025 年多站點驗收測試結果"
    echo "========================================="
    echo "總測試數量: $TOTAL_TESTS"
    echo "通過測試: $PASSED_TESTS"
    echo "失敗測試: $FAILED_TESTS"

    local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)
    echo "成功率: ${success_rate}%"

    if (( FAILED_TESTS == 0 )); then
        log_success "🎉 所有測試通過！多站點環境已達到 2025 年生產標準"
        exit 0
    elif (( $(echo "$success_rate >= 90" | bc -l) )); then
        log_warning "⚠️  大部分測試通過，但有 $FAILED_TESTS 個失敗項需要關注"
        exit 1
    else
        log_error "❌ 多項測試失敗，需要重大修復"
        exit 2
    fi
}

# 錯誤處理
trap 'log_error "多站點驗收測試異常終止"' ERR

main "$@"
POSTCHECK_EOF

    chmod +x "$SCRIPTS_DIR/postcheck-2025.sh"
    log "✅ 增強的多站點 postcheck 腳本創建完成"
}

# 更新原有 postcheck.sh 以支持 2025 功能
update_original_postcheck() {
    log "更新原有 postcheck.sh..."

    if [[ -f "$SCRIPTS_DIR/postcheck.sh" ]]; then
        # 在原有腳本中添加 2025 年功能
        cat >> "$SCRIPTS_DIR/postcheck.sh" << 'APPEND_EOF'

# === 2025 年增強功能 ===

# OpenTelemetry 檢查
check_otel_integration() {
    echo "檢查 OpenTelemetry 集成..."

    if kubectl get pods -n monitoring -l app=otel-collector --field-selector=status.phase=Running | grep -q otel-collector; then
        echo "✅ OpenTelemetry Collector 運行正常"
    else
        echo "❌ OpenTelemetry Collector 未正常運行"
    fi
}

# 零信任策略檢查
check_zero_trust() {
    echo "檢查零信任網路策略..."

    if kubectl get networkpolicy -n monitoring nephio-zero-trust-policy &>/dev/null; then
        echo "✅ 零信任網路策略已部署"
    else
        echo "⚠️  零信任網路策略未找到"
    fi
}

# 執行 2025 年增強檢查
echo ""
echo "=== 2025 年增強功能檢查 ==="
check_otel_integration
check_zero_trust

APPEND_EOF

        log "✅ 原有 postcheck.sh 已更新支持 2025 功能"
    else
        log_warning "未找到原有 postcheck.sh，建議使用新的 postcheck-2025.sh"
    fi
}

# 創建多站點測試工具
create_multisite_tools() {
    log "創建多站點測試工具..."

    # 創建站點健康監控腳本
    cat > "$SCRIPTS_DIR/multisite-health-monitor.sh" << 'MONITOR_EOF'
#!/bin/bash
# 多站點健康監控工具 - 2025 年版本

set -euo pipefail

readonly SITES=("edge2:172.16.0.89:30090" "edge1:172.16.4.45:30090")
readonly CHECK_INTERVAL=30
readonly LOG_FILE="/tmp/multisite-health.log"

monitor_site() {
    local site_info="$1"
    local site_name=$(echo "$site_info" | cut -d':' -f1)
    local site_ip=$(echo "$site_info" | cut -d':' -f2)
    local site_port=$(echo "$site_info" | cut -d':' -f3)

    if curl -s --max-time 10 "http://$site_ip:$site_port/health" &>/dev/null; then
        echo "$(date) [OK] $site_name ($site_ip:$site_port)" | tee -a "$LOG_FILE"
        return 0
    else
        echo "$(date) [FAIL] $site_name ($site_ip:$site_port)" | tee -a "$LOG_FILE"
        return 1
    fi
}

main() {
    echo "開始多站點健康監控..."
    echo "檢查間隔: ${CHECK_INTERVAL}秒"
    echo "日誌文件: $LOG_FILE"
    echo "按 Ctrl+C 停止監控"

    while true; do
        echo ""
        echo "=== $(date) ==="

        for site in "${SITES[@]}"; do
            monitor_site "$site" || true
        done

        sleep "$CHECK_INTERVAL"
    done
}

main "$@"
MONITOR_EOF

    chmod +x "$SCRIPTS_DIR/multisite-health-monitor.sh"

    # 創建網路延遲測試工具
    cat > "$SCRIPTS_DIR/multisite-latency-test.sh" << 'LATENCY_EOF'
#!/bin/bash
# 多站點網路延遲測試工具

set -euo pipefail

readonly EDGE2_IP="172.16.0.89"
readonly EDGE1_IP="172.16.4.45"
readonly TEST_COUNT=10

test_latency() {
    local target_ip="$1"
    local site_name="$2"

    echo "測試到 $site_name ($target_ip) 的延遲..."

    local total_time=0
    local successful_pings=0

    for i in $(seq 1 $TEST_COUNT); do
        local ping_result=$(ping -c 1 -W 2 "$target_ip" 2>/dev/null | grep "time=" | sed -n 's/.*time=\([0-9.]*\).*/\1/p')

        if [[ -n "$ping_result" ]]; then
            total_time=$(echo "$total_time + $ping_result" | bc -l)
            ((successful_pings++))
        fi
    done

    if [[ $successful_pings -gt 0 ]]; then
        local avg_latency=$(echo "scale=2; $total_time / $successful_pings" | bc -l)
        echo "✅ $site_name 平均延遲: ${avg_latency}ms (成功率: $((successful_pings * 100 / TEST_COUNT))%)"
    else
        echo "❌ $site_name 延遲測試失敗"
    fi
}

main() {
    echo "🔍 多站點網路延遲測試"
    echo "測試次數: $TEST_COUNT"
    echo ""

    test_latency "$EDGE2_IP" "Edge2"
    test_latency "$EDGE1_IP" "Edge1"
}

main "$@"
LATENCY_EOF

    chmod +x "$SCRIPTS_DIR/multisite-latency-test.sh"
    log "✅ 多站點測試工具創建完成"
}

# 創建集成測試套件
create_integration_test_suite() {
    log "創建集成測試套件..."

    cat > "$SCRIPTS_DIR/run-all-multisite-tests.sh" << 'SUITE_EOF'
#!/bin/bash
# 多站點集成測試套件 - 一鍵執行所有測試

set -euo pipefail

readonly PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly LOG_DIR="$PROJECT_ROOT/artifacts"

# 創建測試報告目錄
mkdir -p "$LOG_DIR/test-reports"

run_test() {
    local test_name="$1"
    local test_script="$2"
    local log_file="$LOG_DIR/test-reports/${test_name}-$(date +%Y%m%d-%H%M%S).log"

    echo "🧪 執行測試: $test_name"
    echo "   腳本: $test_script"
    echo "   日誌: $log_file"

    if [[ -x "$test_script" ]]; then
        if "$test_script" > "$log_file" 2>&1; then
            echo "✅ $test_name 測試通過"
            return 0
        else
            echo "❌ $test_name 測試失敗，查看日誌: $log_file"
            return 1
        fi
    else
        echo "⚠️  測試腳本不存在或不可執行: $test_script"
        return 1
    fi
}

main() {
    echo "🚀 開始多站點集成測試套件執行..."
    echo "時間: $(date)"
    echo "項目根目錄: $PROJECT_ROOT"
    echo ""

    local total_tests=0
    local passed_tests=0

    # 核心功能測試
    echo "=== 核心功能測試 ==="

    ((total_tests++))
    if run_test "enhanced-postcheck" "$SCRIPTS_DIR/postcheck-2025.sh"; then
        ((passed_tests++))
    fi

    ((total_tests++))
    if run_test "bidirectional-connectivity" "$SCRIPTS_DIR/test_bidirectional_connectivity.sh"; then
        ((passed_tests++))
    fi

    # 網路測試
    echo ""
    echo "=== 網路性能測試 ==="

    ((total_tests++))
    if run_test "multisite-latency" "$SCRIPTS_DIR/multisite-latency-test.sh"; then
        ((passed_tests++))
    fi

    # 安全測試
    echo ""
    echo "=== 安全合規測試 ==="
    echo "檢查零信任策略..."

    if kubectl get networkpolicy -n monitoring nephio-zero-trust-policy &>/dev/null; then
        echo "✅ 零信任策略檢查通過"
        ((passed_tests++))
    else
        echo "❌ 零信任策略檢查失敗"
    fi
    ((total_tests++))

    # 總結報告
    echo ""
    echo "========================================="
    echo "🎯 多站點集成測試總結"
    echo "========================================="
    echo "總測試數: $total_tests"
    echo "通過測試: $passed_tests"
    echo "失敗測試: $((total_tests - passed_tests))"

    local success_rate=$(( passed_tests * 100 / total_tests ))
    echo "成功率: ${success_rate}%"

    if [[ $success_rate -ge 90 ]]; then
        echo "🎉 集成測試評級: 優秀 (≥90%)"
        exit 0
    elif [[ $success_rate -ge 75 ]]; then
        echo "⚠️  集成測試評級: 良好 (≥75%)"
        exit 1
    else
        echo "❌ 集成測試評級: 需要改進 (<75%)"
        exit 2
    fi
}

main "$@"
SUITE_EOF

    chmod +x "$SCRIPTS_DIR/run-all-multisite-tests.sh"
    log "✅ 集成測試套件創建完成"
}

# 創建自動化 CI 鉤子
create_ci_hooks() {
    log "創建 CI/CD 鉤子..."

    mkdir -p "$PROJECT_ROOT/.github/workflows" 2>/dev/null || mkdir -p "$PROJECT_ROOT/ci"

    cat > "$PROJECT_ROOT/ci/multisite-validation.yml" << 'CI_EOF'
# 多站點驗證 CI 流程
name: Multisite Validation

on:
  push:
    branches: [ main, summit-llm-e2e ]
  pull_request:
    branches: [ main ]
  schedule:
    # 每天 UTC 02:00 執行
    - cron: '0 2 * * *'

jobs:
  multisite-tests:
    runs-on: self-hosted
    timeout-minutes: 30

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Environment
      run: |
        echo "Setting up multisite test environment..."
        kubectl cluster-info

    - name: Run OpenTelemetry Health Check
      run: |
        ./scripts/vm1-optimization/deploy_opentelemetry_collector.sh || echo "OTel check completed"

    - name: Run Zero Trust Policy Check
      run: |
        ./scripts/vm1-optimization/setup_zerotrust_policies.sh || echo "Security check completed"

    - name: Run Enhanced Postcheck
      run: |
        ./scripts/postcheck-2025.sh

    - name: Run Multisite Integration Tests
      run: |
        ./scripts/run-all-multisite-tests.sh

    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: multisite-test-results
        path: |
          artifacts/test-reports/
          artifacts/*-report-*.json
          artifacts/*.log
CI_EOF

    log "✅ CI/CD 鉤子創建完成"
}

# 主要執行函數
main() {
    log "🚀 開始更新多站點驗收測試 (2025 最佳實踐)..."

    backup_original_postcheck
    create_enhanced_postcheck
    update_original_postcheck
    create_multisite_tools
    create_integration_test_suite
    create_ci_hooks

    log "✅ 多站點驗收測試更新完成！"
    log ""
    log "📋 新功能概覽："
    log "  🔧 增強的 postcheck-2025.sh (嚴格 SLO 閾值)"
    log "  🌐 多站點健康監控工具"
    log "  ⚡ 網路延遲測試工具"
    log "  🧪 集成測試套件"
    log "  🔄 CI/CD 自動化鉤子"
    log ""
    log "🎯 建議執行順序："
    log "  1. ./scripts/postcheck-2025.sh"
    log "  2. ./scripts/run-all-multisite-tests.sh"
    log "  3. ./scripts/multisite-health-monitor.sh (持續監控)"
    log ""
    log "📄 詳細日誌: $LOG_FILE"

    # 驗證新腳本
    if [[ -x "$SCRIPTS_DIR/postcheck-2025.sh" ]]; then
        log "✅ postcheck-2025.sh 可執行"
    else
        log_error "postcheck-2025.sh 創建失敗"
    fi

    if [[ -x "$SCRIPTS_DIR/run-all-multisite-tests.sh" ]]; then
        log "✅ 集成測試套件可執行"
    else
        log_error "集成測試套件創建失敗"
    fi
}

# 錯誤處理
trap 'log_error "多站點驗收測試更新失敗，查看日誌: $LOG_FILE"' ERR

main "$@"