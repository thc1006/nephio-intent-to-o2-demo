#!/bin/bash
# VM-1 簡化的 Edge2 連通性測試腳本
# 專門針對實際網路行為優化

set -euo pipefail

# 配置
readonly EDGE2_IP="172.16.4.176"      # 使用內網 IP (已驗證可用)
readonly EDGE2_PORT="30090"
readonly TIMEOUT="10"

# 顏色配置
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 日誌函數
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 主要測試函數
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║              VM-1 → VM-4 Edge2 連通性快速驗證                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    log_info "測試目標: VM-4 Edge2 - ${EDGE2_IP}:${EDGE2_PORT}"
    log_info "開始時間: $(date)"
    echo ""

    # 說明網路行為
    log_warn "⚠️  重要說明：ping 會失敗是正常的 (ICMP 被阻擋)，但 HTTP 服務完全正常"
    echo ""

    # 測試 1: HTTP 健康檢查
    log_info "🏥 測試 1: HTTP 健康檢查"
    local health_url="http://${EDGE2_IP}:${EDGE2_PORT}/health"

    if curl -s --max-time ${TIMEOUT} "${health_url}" | grep -q "OK"; then
        log_success "   ✅ 健康檢查通過"
    else
        log_error "   ❌ 健康檢查失敗"
        log_error "   🔧 請檢查："
        log_error "      - VM-4 上的服務是否運行: kubectl get pods -n slo-monitoring"
        log_error "      - 防火牆規則是否正確: sudo ufw status"
        exit 1
    fi

    echo ""

    # 測試 2: SLO 數據獲取
    log_info "📊 測試 2: SLO 數據獲取"
    local slo_url="http://${EDGE2_IP}:${EDGE2_PORT}/metrics/api/v1/slo"

    local slo_response
    if slo_response=$(curl -s --max-time ${TIMEOUT} "${slo_url}"); then
        if echo "$slo_response" | jq . >/dev/null 2>&1; then
            log_success "   ✅ SLO 數據獲取成功"

            # 顯示關鍵指標
            local site=$(echo "$slo_response" | jq -r '.site // "unknown"')
            local latency=$(echo "$slo_response" | jq -r '.slo.latency_p95_ms // "N/A"')
            local success_rate=$(echo "$slo_response" | jq -r '.slo.success_rate // "N/A"')
            local throughput=$(echo "$slo_response" | jq -r '.slo.throughput_p95_mbps // "N/A"')

            log_info "   📈 關鍵指標:"
            log_info "      站點: ${site}"
            log_info "      延遲 P95: ${latency} ms"
            log_info "      成功率: ${success_rate}"
            log_info "      吞吐量: ${throughput} Mbps"
        else
            log_error "   ❌ SLO 數據格式錯誤"
            log_error "   響應: $slo_response"
            exit 1
        fi
    else
        log_error "   ❌ SLO 數據獲取失敗"
        exit 1
    fi

    echo ""

    # 測試 3: postcheck.sh 配置檢查
    log_info "🔧 測試 3: postcheck.sh 配置檢查"

    if [[ -f "./scripts/postcheck.sh" ]]; then
        if grep -q "edge2.*${EDGE2_IP}" "./scripts/postcheck.sh" 2>/dev/null; then
            log_success "   ✅ postcheck.sh 已正確配置 edge2"
        else
            log_warn "   ⚠️  postcheck.sh 需要更新配置"
            echo ""
            log_info "   📝 建議配置 (複製以下內容到 scripts/postcheck.sh):"
            echo "   declare -A SITES=("
            echo "       [edge1]=\"172.16.4.45:30090/metrics/api/v1/slo\""
            echo "       [edge2]=\"${EDGE2_IP}:${EDGE2_PORT}/metrics/api/v1/slo\""
            echo "   )"
        fi
    else
        log_warn "   ⚠️  postcheck.sh 文件不存在"
        log_info "      請確認在正確的專案目錄中執行此腳本"
    fi

    echo ""

    # 結果總結
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                           測試結果總結                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"

    log_success "🎉 VM-4 Edge2 連通性驗證成功！"
    log_success "🔗 HTTP 服務完全正常，可以在 VM-1 上使用多站點功能"
    echo ""

    log_info "📋 後續步驟："
    log_info "1. 更新 scripts/postcheck.sh 配置 (如尚未更新)"
    log_info "2. 執行多站點測試: ./scripts/postcheck.sh"
    log_info "3. 確認兩個站點 (edge1 + edge2) 的 SLO 數據都正常"
    echo ""

    log_info "✅ 驗證完成時間: $(date)"

    # 生成簡單報告
    cat > "./vm1_edge2_test_result.txt" << EOF
VM-1 Edge2 連通性測試結果
========================
測試時間: $(date)
測試目標: ${EDGE2_IP}:${EDGE2_PORT}
測試狀態: 成功

關鍵發現:
- HTTP 連接: 正常
- SLO 數據: 可正常獲取
- 站點標識: ${site}

建議配置:
edge2="${EDGE2_IP}:${EDGE2_PORT}/metrics/api/v1/slo"

注意事項:
- ping 失敗是正常的 (ICMP 被阻擋)
- 使用內網 IP，不使用外網 IP
- HTTP 服務完全可用
EOF

    log_info "📄 測試報告已保存到: ./vm1_edge2_test_result.txt"
}

# 執行主函數
main "$@"