#!/bin/bash
set -euo pipefail

# postcheck_v2.sh - Multi-site SLO-gated deployment validation (Configuration-driven)
# 使用權威配置文件系統，避免硬編碼

# 獲取腳本目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 載入配置
echo "📋 載入權威配置文件..."
source "$SCRIPT_DIR/load_config.sh"

# 其他配置 (可從環境變數覆蓋)
ROOTSYNC_NAME="${ROOTSYNC_NAME:-intent-to-o2-rootsync}"
ROOTSYNC_NAMESPACE="${ROOTSYNC_NAMESPACE:-config-management-system}"
ROOTSYNC_TIMEOUT_SECONDS="${ROOTSYNC_TIMEOUT_SECONDS:-600}"

# 日誌配置
LOG_JSON="${LOG_JSON:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# 報告配置
REPORT_DIR="${REPORT_DIR:-reports/$(date +%Y%m%d_%H%M%S)}"
REPORT_FILE="${REPORT_DIR}/postcheck_report.json"

# 退出代碼
EXIT_SUCCESS=0
EXIT_ROOTSYNC_TIMEOUT=1
EXIT_METRICS_UNREACHABLE=2
EXIT_SLO_VIOLATION=3
EXIT_DEPENDENCY_MISSING=4
EXIT_CONFIG_ERROR=5

# 日誌函數
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    if [[ "$LOG_JSON" == "true" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"postcheck-v2\"}"
    else
        echo "[$timestamp] [$level] $message"
    fi
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# 檢查依賴
check_dependencies() {
    local missing_deps=()

    for dep in kubectl curl jq mkdir bc; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必要的依賴工具: ${missing_deps[*]}"
        exit $EXIT_DEPENDENCY_MISSING
    fi
}

# 等待 RootSync 調和
wait_for_rootsync_reconciliation() {
    log_info "等待 RootSync '$ROOTSYNC_NAME' 調和 (超時: ${ROOTSYNC_TIMEOUT_SECONDS}s)"

    local start_time=$(date +%s)
    local timeout_time=$((start_time + ROOTSYNC_TIMEOUT_SECONDS))

    while [[ $(date +%s) -lt $timeout_time ]]; do
        if kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" &> /dev/null; then
            local stalled_status=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "")

            local observed_gen=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.status.observedGeneration}' 2>/dev/null || echo "")
            local current_gen=$(kubectl get resourcegroup.kpt.dev "$ROOTSYNC_NAME" -n "$ROOTSYNC_NAMESPACE" \
                -o jsonpath='{.metadata.generation}' 2>/dev/null || echo "")

            if [[ "$stalled_status" == "False" ]] && [[ "$observed_gen" == "$current_gen" ]] && [[ -n "$observed_gen" ]]; then
                log_info "RootSync 調和成功完成"
                return 0
            fi
        fi

        log_info "RootSync 調和中... (stalled: ${stalled_status:-unknown})"
        sleep 10
    done

    log_error "RootSync 調和超時，經過 ${ROOTSYNC_TIMEOUT_SECONDS} 秒"
    return $EXIT_ROOTSYNC_TIMEOUT
}

# 獲取 O2IMS Measurement 度量
fetch_o2ims_metrics() {
    local site="$1"
    local o2ims_endpoint="${O2IMS_SITES[$site]}"
    log_info "嘗試獲取 $site 的 O2IMS Measurement 度量"

    local metrics_response
    if metrics_response=$(curl -s --max-time "$METRICS_TIMEOUT_SECONDS" "$o2ims_endpoint" 2>/dev/null); then
        echo "$metrics_response"
        return 0
    fi

    log_warn "$site 的 O2IMS Measurement 度量不可用"
    return 1
}

# 從標準端點獲取 SLO 度量
fetch_slo_metrics() {
    local site="$1"
    local slo_endpoint="http://${SITES[$site]}"
    log_info "從 $slo_endpoint 獲取 SLO 度量"

    local metrics_response
    if ! metrics_response=$(curl -s --max-time "$METRICS_TIMEOUT_SECONDS" "$slo_endpoint" 2>/dev/null); then
        log_error "無法連接到 $site 的 SLO 端點: $slo_endpoint"
        return $EXIT_METRICS_UNREACHABLE
    fi

    if ! echo "$metrics_response" | jq . &> /dev/null; then
        log_error "$site SLO 端點返回無效的 JSON"
        return $EXIT_METRICS_UNREACHABLE
    fi

    echo "$metrics_response"
    return 0
}

# 驗證站點的 SLO 度量
validate_site_metrics() {
    local site="$1"
    local metrics_response="$2"
    local violations=()

    # 解析度量 - 支持兩種格式
    local latency_p95
    local success_rate
    local throughput_p95

    # 嘗試解析不同的 JSON 格式
    if echo "$metrics_response" | jq -e '.metrics' > /dev/null; then
        # Edge1 格式 (legacy)
        latency_p95=$(echo "$metrics_response" | jq -r '.metrics.latency_p95_ms // empty')
        success_rate=$(echo "$metrics_response" | jq -r '.metrics.success_rate // empty')
        throughput_p95=$(echo "$metrics_response" | jq -r '.metrics.throughput_p95_mbps // empty')
    elif echo "$metrics_response" | jq -e '.slo' > /dev/null; then
        # Edge2 格式 (standard)
        latency_p95=$(echo "$metrics_response" | jq -r '.slo.latency_p95_ms // empty')
        success_rate=$(echo "$metrics_response" | jq -r '.slo.success_rate // empty')
        throughput_p95=$(echo "$metrics_response" | jq -r '.slo.throughput_p95_mbps // empty')

        # 轉換比例到百分比 (如果需要)
        if [[ -n "$success_rate" ]] && (( $(echo "$success_rate < 1" | bc -l) )); then
            success_rate=$(echo "$success_rate * 100" | bc -l)
        fi
    else
        log_warn "[$site] 無法識別的 SLO 數據格式"
    fi

    log_info "[$site] 當前 SLO 度量: latency_p95=${latency_p95}ms, success_rate=${success_rate}%, throughput_p95=${throughput_p95}Mbps"

    # 驗證閾值
    if [[ -n "$latency_p95" ]] && (( $(echo "$latency_p95 > $LATENCY_P95_THRESHOLD_MS" | bc -l) )); then
        violations+=("latency_p95: ${latency_p95}ms > ${LATENCY_P95_THRESHOLD_MS}ms")
    fi

    if [[ -n "$success_rate" ]] && (( $(echo "$success_rate < $(echo "$SUCCESS_RATE_THRESHOLD * 100" | bc -l)" | bc -l) )); then
        violations+=("success_rate: ${success_rate}% < $(echo "$SUCCESS_RATE_THRESHOLD * 100" | bc -l)%")
    fi

    if [[ -n "$throughput_p95" ]] && (( $(echo "$throughput_p95 < $THROUGHPUT_P95_THRESHOLD_MBPS" | bc -l) )); then
        violations+=("throughput_p95: ${throughput_p95}Mbps < ${THROUGHPUT_P95_THRESHOLD_MBPS}Mbps")
    fi

    # 檢查缺失的度量
    if [[ -z "$latency_p95" || -z "$success_rate" || -z "$throughput_p95" ]]; then
        log_warn "[$site] 某些 SLO 度量缺失"
        violations+=("missing_metrics: latency_p95=${latency_p95:-missing}, success_rate=${success_rate:-missing}, throughput_p95=${throughput_p95:-missing}")
    fi

    if [[ ${#violations[@]} -gt 0 ]]; then
        log_error "[$site] 檢測到 SLO 違規:"
        for violation in "${violations[@]}"; do
            log_error "  - $violation"
        done
        return $EXIT_SLO_VIOLATION
    fi

    log_info "[$site] 所有 SLO 閾值都符合要求"
    return 0
}

# 生成 postcheck 報告
generate_report() {
    local report_data="$1"

    mkdir -p "$REPORT_DIR"
    echo "$report_data" | jq . > "$REPORT_FILE"
    log_info "Postcheck 報告已生成: $REPORT_FILE"
}

# 主執行函數
main() {
    log_info "啟動多站點 postcheck 驗證 (配置驅動版本)"

    # 檢查依賴
    check_dependencies

    # 顯示載入的配置
    log_info "使用配置: ${#SITES[@]} 個站點 (${!SITES[*]})"

    # 等待 RootSync 調和
    if ! wait_for_rootsync_reconciliation; then
        log_error "RootSync 調和失敗"
        exit $EXIT_ROOTSYNC_TIMEOUT
    fi

    # 初始化報告數據
    local report_sites=()
    local overall_status="PASS"
    local site_status

    # 處理每個站點
    for site in "${!SITES[@]}"; do
        local metrics_response

        # 優先使用 O2IMS Measurement API
        if ! metrics_response=$(fetch_o2ims_metrics "$site"); then
            # 回退到標準度量端點
            if ! metrics_response=$(fetch_slo_metrics "$site"); then
                log_error "[$site] 無法獲取度量"
                site_status="FAIL"
                overall_status="FAIL"
                continue
            fi
        fi

        # 驗證站點度量
        if ! validate_site_metrics "$site" "$metrics_response"; then
            log_error "[$site] SLO 驗證失敗"
            site_status="FAIL"
            overall_status="FAIL"
        else
            site_status="PASS"
        fi

        # 建立站點報告
        local site_report=$(echo "$metrics_response" | jq --arg site "$site" --arg status "$site_status" '{
            site: $site,
            status: $status,
            metrics: (if .metrics then .metrics else .slo end)
        }')

        report_sites+=("$site_report")
    done

    # 準備最終報告
    local final_report=$(jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
        --arg status "$overall_status" \
        --arg version "postcheck-v2-config-driven" \
        --argjson sites "$(printf '%s\n' "${report_sites[@]}" | jq -s '.')" \
        '{
            timestamp: $timestamp,
            version: $version,
            status: $status,
            sites: $sites
        }')

    # 生成報告
    generate_report "$final_report"

    # 最終狀態檢查
    if [[ "$overall_status" == "FAIL" ]]; then
        log_error "一個或多個站點 SLO 驗證失敗"
        exit $EXIT_SLO_VIOLATION
    fi

    log_info "✅ Postcheck 驗證成功完成"
    log_info "✅ PASS: RootSync 已調和，所有站點 SLO 閾值都符合要求"
    exit $EXIT_SUCCESS
}

# 處理腳本中斷
trap 'log_error "Postcheck 中斷"; exit 130' INT TERM

# 執行主函數
main "$@"