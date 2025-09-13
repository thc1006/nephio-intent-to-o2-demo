#!/bin/bash
# 雙邊連通性測試腳本
# 測試 VM-1 ↔ VM-4 的完整雙向連通性

set -euo pipefail

# 配置
readonly VM1_IP="172.16.0.78"
readonly VM4_IP="172.16.0.89"
readonly VM1_NAME="VM-1 (SMO)"
readonly VM4_NAME="VM-4 (Edge2)"
readonly TEST_TIMEOUT="10"

# 服務端點配置
readonly VM4_SLO_PORT="30090"
readonly VM4_O2IMS_PORT="31280"
readonly VM4_K8S_PORT="6443"

# 顏色配置
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 測試結果統計
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -a TEST_RESULTS=()

# 日誌函數
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_test() { echo -e "${CYAN}[TEST]${NC} $*"; }

# 測試統計函數
add_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

pass_test() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ $1")
    log_success "$1"
}

fail_test() {
    TEST_RESULTS+=("❌ $1")
    log_error "$1"
}

# 檢測當前執行環境
detect_current_vm() {
    local current_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' || echo "unknown")

    if [[ "$current_ip" == "$VM1_IP" ]]; then
        echo "VM1"
    elif [[ "$current_ip" == "$VM4_IP" ]]; then
        echo "VM4"
    else
        echo "UNKNOWN"
    fi
}

# 基本網路連通性測試
test_basic_connectivity() {
    local source_name="$1"
    local target_ip="$2"
    local target_name="$3"

    log_test "測試基本網路連通性: $source_name → $target_name"

    # Ping 測試
    add_test
    if ping -c 3 -W 5 "$target_ip" >/dev/null 2>&1; then
        pass_test "PING: $source_name → $target_name ($target_ip)"
    else
        fail_test "PING: $source_name → $target_name ($target_ip)"
    fi

    # TCP 端口探測 (使用 nc 如果可用)
    if command -v nc >/dev/null 2>&1; then
        add_test
        if nc -z -w5 "$target_ip" 22 2>/dev/null; then
            pass_test "SSH端口: $source_name → $target_name:22"
        else
            fail_test "SSH端口: $source_name → $target_name:22"
        fi
    fi
}

# HTTP 服務連通性測試
test_http_services() {
    local source_name="$1"
    local target_ip="$2"
    local target_name="$3"

    log_test "測試 HTTP 服務連通性: $source_name → $target_name"

    # SLO 服務測試
    add_test
    local slo_url="http://${target_ip}:${VM4_SLO_PORT}/health"
    if curl -s --max-time "$TEST_TIMEOUT" "$slo_url" | grep -q "OK"; then
        pass_test "SLO健康檢查: $source_name → $target_name:$VM4_SLO_PORT"
    else
        fail_test "SLO健康檢查: $source_name → $target_name:$VM4_SLO_PORT"
    fi

    # SLO 數據獲取測試
    add_test
    local slo_data_url="http://${target_ip}:${VM4_SLO_PORT}/metrics/api/v1/slo"
    local slo_response=$(curl -s --max-time "$TEST_TIMEOUT" "$slo_data_url" 2>/dev/null || echo "")
    if echo "$slo_response" | jq . >/dev/null 2>&1; then
        local site=$(echo "$slo_response" | jq -r '.site // "unknown"')
        pass_test "SLO數據獲取: $source_name → $target_name ($site)"
    else
        fail_test "SLO數據獲取: $source_name → $target_name"
    fi

    # O2IMS 端口測試
    add_test
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w5 "$target_ip" "$VM4_O2IMS_PORT" 2>/dev/null; then
            pass_test "O2IMS端口: $source_name → $target_name:$VM4_O2IMS_PORT"
        else
            fail_test "O2IMS端口: $source_name → $target_name:$VM4_O2IMS_PORT"
        fi
    else
        # 使用 curl 測試端口可達性
        if timeout 5 bash -c "</dev/tcp/$target_ip/$VM4_O2IMS_PORT" 2>/dev/null; then
            pass_test "O2IMS端口: $source_name → $target_name:$VM4_O2IMS_PORT"
        else
            fail_test "O2IMS端口: $source_name → $target_name:$VM4_O2IMS_PORT"
        fi
    fi
}

# Kubernetes API 連通性測試 (針對 VM-4)
test_kubernetes_api() {
    local source_name="$1"
    local target_ip="$2"
    local target_name="$3"

    if [[ "$target_ip" == "$VM4_IP" ]]; then
        log_test "測試 Kubernetes API 連通性: $source_name → $target_name"

        add_test
        if command -v nc >/dev/null 2>&1; then
            if nc -z -w5 "$target_ip" "$VM4_K8S_PORT" 2>/dev/null; then
                pass_test "K8s API端口: $source_name → $target_name:$VM4_K8S_PORT"
            else
                fail_test "K8s API端口: $source_name → $target_name:$VM4_K8S_PORT"
            fi
        else
            if timeout 5 bash -c "</dev/tcp/$target_ip/$VM4_K8S_PORT" 2>/dev/null; then
                pass_test "K8s API端口: $source_name → $target_name:$VM4_K8S_PORT"
            else
                fail_test "K8s API端口: $source_name → $target_name:$VM4_K8S_PORT"
            fi
        fi
    fi
}

# 執行單向連通性測試
run_unidirectional_test() {
    local source_name="$1"
    local target_ip="$2"
    local target_name="$3"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║  測試方向: $source_name → $target_name"
    echo "╚══════════════════════════════════════════════════════════════════════╝"

    test_basic_connectivity "$source_name" "$target_ip" "$target_name"
    test_http_services "$source_name" "$target_ip" "$target_name"
    test_kubernetes_api "$source_name" "$target_ip" "$target_name"
}

# 網路診斷資訊
show_network_info() {
    log_info "收集網路診斷資訊..."

    echo ""
    echo "=== 當前網路配置 ==="
    echo "本機 IP 地址:"
    ip addr show | grep -A1 "inet.*172.16" || echo "未找到 172.16 網段 IP"

    echo ""
    echo "路由表:"
    ip route show | head -5

    echo ""
    echo "監聽端口:"
    ss -tlnp | grep -E "(22|30090|31280|6443)" | head -10 || echo "未找到相關監聽端口"
}

# 遠程測試執行 (使用 SSH)
execute_remote_test() {
    local remote_ip="$1"
    local remote_name="$2"
    local target_ip="$3"
    local target_name="$4"

    log_info "嘗試在 $remote_name 上執行遠程測試..."

    # 檢查是否能 SSH 連接
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "ubuntu@$remote_ip" "echo 'SSH連接成功'" 2>/dev/null; then
        log_warn "無法 SSH 連接到 $remote_name ($remote_ip)，跳過遠程測試"
        return 1
    fi

    # 執行遠程測試
    ssh "ubuntu@$remote_ip" bash << EOF
        echo "在 $remote_name 上測試到 $target_name 的連通性"

        # 基本 ping 測試
        if ping -c 3 -W 5 $target_ip >/dev/null 2>&1; then
            echo "✅ PING: $remote_name → $target_name"
        else
            echo "❌ PING: $remote_name → $target_name"
        fi

        # HTTP 服務測試
        if curl -s --max-time 10 http://$target_ip:$VM4_SLO_PORT/health | grep -q "OK"; then
            echo "✅ SLO服務: $remote_name → $target_name"
        else
            echo "❌ SLO服務: $remote_name → $target_name"
        fi
EOF
}

# 生成測試報告
generate_report() {
    local current_vm="$1"
    local timestamp=$(date -Iseconds)
    local report_file="./bidirectional_connectivity_report_$(date +%Y%m%d_%H%M%S).json"

    local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0.0")

    cat > "$report_file" << EOF
{
  "timestamp": "$timestamp",
  "test_execution_location": "$current_vm",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $((TOTAL_TESTS - PASSED_TESTS)),
    "success_rate": "${success_rate}%"
  },
  "test_results": [
$(printf '%s\n' "${TEST_RESULTS[@]}" | sed 's/.*/"&"/' | paste -sd ',' -)
  ],
  "network_configuration": {
    "vm1_ip": "$VM1_IP",
    "vm4_ip": "$VM4_IP",
    "slo_port": $VM4_SLO_PORT,
    "o2ims_port": $VM4_O2IMS_PORT,
    "kubernetes_api_port": $VM4_K8S_PORT
  }
}
EOF

    log_info "測試報告已生成: $report_file"
}

# 主執行函數
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    雙邊連通性測試工具                                 ║"
    echo "║                   VM-1 ↔ VM-4 完整測試                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # 檢測當前執行環境
    local current_vm=$(detect_current_vm)
    log_info "當前執行環境: $current_vm"
    log_info "測試開始時間: $(date)"

    # 顯示測試配置
    echo ""
    log_info "測試配置:"
    log_info "  $VM1_NAME: $VM1_IP"
    log_info "  $VM4_NAME: $VM4_IP"
    log_info "  服務端口: SLO($VM4_SLO_PORT), O2IMS($VM4_O2IMS_PORT), K8s($VM4_K8S_PORT)"

    # 顯示網路診斷資訊
    show_network_info

    # 根據當前環境執行測試
    case "$current_vm" in
        "VM1")
            log_info "在 VM-1 上執行，測試到 VM-4 的連通性"
            run_unidirectional_test "$VM1_NAME" "$VM4_IP" "$VM4_NAME"

            # 嘗試遠程執行 VM-4 → VM-1 測試
            echo ""
            log_info "嘗試遠程執行 VM-4 → VM-1 測試..."
            if ! execute_remote_test "$VM4_IP" "$VM4_NAME" "$VM1_IP" "$VM1_NAME"; then
                log_warn "建議在 VM-4 上也執行此腳本以完成雙向測試"
            fi
            ;;

        "VM4")
            log_info "在 VM-4 上執行，測試到 VM-1 的連通性"
            run_unidirectional_test "$VM4_NAME" "$VM1_IP" "$VM1_NAME"

            # 嘗試遠程執行 VM-1 → VM-4 測試
            echo ""
            log_info "嘗試遠程執行 VM-1 → VM-4 測試..."
            if ! execute_remote_test "$VM1_IP" "$VM1_NAME" "$VM4_IP" "$VM4_NAME"; then
                log_warn "建議在 VM-1 上也執行此腳本以完成雙向測試"
            fi
            ;;

        "UNKNOWN")
            log_warn "無法識別當前 VM 環境，執行通用測試"
            log_info "測試 VM-1 ↔ VM-4 連通性"

            # 嘗試從當前位置測試兩個方向
            run_unidirectional_test "當前主機" "$VM1_IP" "$VM1_NAME"
            run_unidirectional_test "當前主機" "$VM4_IP" "$VM4_NAME"
            ;;
    esac

    # 顯示測試總結
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                           測試總結                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"

    local success_rate=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0.0")

    echo ""
    log_info "測試統計:"
    log_info "  總測試數: $TOTAL_TESTS"
    log_info "  通過測試: $PASSED_TESTS"
    log_info "  失敗測試: $((TOTAL_TESTS - PASSED_TESTS))"
    log_info "  成功率: ${success_rate}%"

    echo ""
    log_info "詳細結果:"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done

    # 生成報告
    generate_report "$current_vm"

    # 提供後續建議
    echo ""
    if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
        log_success "🎉 所有連通性測試通過！雙站點網路配置正確"
        log_success "📡 多站點 Nephio 環境已就緒"
    elif [[ $PASSED_TESTS -gt $((TOTAL_TESTS / 2)) ]]; then
        log_warn "⚠️  部分測試失敗，建議檢查："
        log_warn "   1. OpenStack 安全群組規則"
        log_warn "   2. 系統防火牆設置"
        log_warn "   3. 服務運行狀態"
    else
        log_error "❌ 多數測試失敗，需要檢查網路配置"
        log_error "   1. 執行 OpenStack 安全群組修復"
        log_error "   2. 運行本地網路修復腳本"
        log_error "   3. 確認服務正常運行"
    fi

    echo ""
    log_info "測試完成時間: $(date)"

    # 返回適當的退出碼
    if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
        exit 0
    else
        exit 1
    fi
}

# 執行主函數
main "$@"