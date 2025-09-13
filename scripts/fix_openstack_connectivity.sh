#!/bin/bash
# OpenStack 網路連通性快速修復腳本
# 在 VM-4 上執行，解決 ping 失敗問題

set -euo pipefail

# 顏色配置
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 檢查是否為 root 或有 sudo 權限
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_error "此腳本需要 sudo 權限"
        exit 1
    fi
}

# 備份當前配置
backup_configs() {
    log_info "備份當前網路配置..."
    local backup_dir="/tmp/openstack_network_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    # 備份防火牆規則
    sudo ufw status numbered > "$backup_dir/ufw_rules.txt" 2>/dev/null || true
    sudo iptables -L -n > "$backup_dir/iptables_rules.txt" 2>/dev/null || true

    # 備份網路配置
    cp /etc/sysctl.conf "$backup_dir/sysctl.conf.bak" 2>/dev/null || true
    ip route show > "$backup_dir/routes.txt" 2>/dev/null || true

    log_success "配置已備份到: $backup_dir"
    echo "$backup_dir" > /tmp/network_backup_location
}

# 修復 ICMP 響應
fix_icmp_response() {
    log_info "修復 ICMP 響應設置..."

    # 檢查當前 ICMP 設置
    local icmp_ignore_all=$(cat /proc/sys/net/ipv4/icmp_echo_ignore_all 2>/dev/null || echo "1")
    local icmp_ignore_broadcasts=$(cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts 2>/dev/null || echo "1")

    log_info "當前 ICMP 設置: ignore_all=$icmp_ignore_all, ignore_broadcasts=$icmp_ignore_broadcasts"

    if [[ "$icmp_ignore_all" != "0" ]]; then
        log_info "啟用 ICMP echo 響應..."
        echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all >/dev/null

        # 永久設置
        if ! grep -q "net.ipv4.icmp_echo_ignore_all" /etc/sysctl.conf; then
            echo "net.ipv4.icmp_echo_ignore_all = 0" | sudo tee -a /etc/sysctl.conf >/dev/null
        else
            sudo sed -i 's/^net.ipv4.icmp_echo_ignore_all.*/net.ipv4.icmp_echo_ignore_all = 0/' /etc/sysctl.conf
        fi
        log_success "ICMP echo 響應已啟用"
    else
        log_success "ICMP echo 響應已經是啟用狀態"
    fi
}

# 配置防火牆規則
configure_firewall() {
    log_info "配置防火牆以允許內網 ICMP..."

    # 檢查 ufw 狀態
    local ufw_status=$(sudo ufw status | grep -o "Status: \w*" | cut -d' ' -f2)

    if [[ "$ufw_status" == "active" ]]; then
        # 允許來自內網的 ICMP
        sudo ufw allow from 172.16.0.0/16 to any proto icmp comment "Allow ICMP from internal network"

        # 確保現有的端口規則仍然存在
        sudo ufw allow from 172.16.0.0/16 to any port 30090 proto tcp comment "SLO endpoint"
        sudo ufw allow from 172.16.0.0/16 to any port 31280 proto tcp comment "O2IMS endpoint"
        sudo ufw allow from 172.16.0.0/16 to any port 6443 proto tcp comment "Kubernetes API"

        # 重新載入 ufw
        sudo ufw --force reload
        log_success "防火牆規則已更新"
    else
        log_warn "ufw 未啟用，跳過防火牆配置"
    fi
}

# 檢查並修復 iptables 規則
fix_iptables() {
    log_info "檢查 iptables 規則..."

    # 檢查是否有阻擋 ICMP 的規則
    if sudo iptables -C INPUT -p icmp --icmp-type echo-request -j DROP 2>/dev/null; then
        log_warn "發現阻擋 ICMP 的 iptables 規則，正在移除..."
        sudo iptables -D INPUT -p icmp --icmp-type echo-request -j DROP
        log_success "已移除阻擋 ICMP 的規則"
    fi

    # 確保允許內網 ICMP
    if ! sudo iptables -C INPUT -s 172.16.0.0/16 -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null; then
        sudo iptables -I INPUT -s 172.16.0.0/16 -p icmp --icmp-type echo-request -j ACCEPT
        log_success "已添加允許內網 ICMP 的規則"
    else
        log_success "內網 ICMP 規則已存在"
    fi
}

# 測試網路連通性
test_connectivity() {
    log_info "測試網路連通性..."

    # 測試本地回環
    if ping -c 1 -W 2 127.0.0.1 >/dev/null 2>&1; then
        log_success "✅ 本地回環 ping 正常"
    else
        log_error "❌ 本地回環 ping 失敗"
    fi

    # 測試本機 IP
    local local_ip="172.16.0.89"
    if ping -c 1 -W 2 "$local_ip" >/dev/null 2>&1; then
        log_success "✅ 本機 IP ($local_ip) ping 正常"
    else
        log_warn "⚠️  本機 IP ($local_ip) ping 失敗"
    fi

    # 測試網關
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -n "$gateway" ]]; then
        if ping -c 1 -W 2 "$gateway" >/dev/null 2>&1; then
            log_success "✅ 網關 ($gateway) ping 正常"
        else
            log_warn "⚠️  網關 ($gateway) ping 失敗"
        fi
    fi

    # 測試 VM-1 (如果知道 IP)
    local vm1_ip="172.16.0.78"
    log_info "測試到 VM-1 ($vm1_ip) 的連通性..."
    if ping -c 3 -W 2 "$vm1_ip" >/dev/null 2>&1; then
        log_success "✅ VM-1 ($vm1_ip) ping 正常"
    else
        log_warn "⚠️  VM-1 ($vm1_ip) ping 失敗 (這可能需要在 OpenStack 層級解決)"
    fi

    # 測試 HTTP 服務 (應該始終正常)
    if curl -s --max-time 5 http://172.16.0.89:30090/health >/dev/null; then
        log_success "✅ HTTP 服務 (30090) 正常"
    else
        log_error "❌ HTTP 服務 (30090) 異常"
    fi
}

# 顯示診斷資訊
show_diagnostic_info() {
    log_info "顯示診斷資訊..."

    echo ""
    echo "=== 網路介面 ==="
    ip addr show | grep -A2 "ens[0-9]"

    echo ""
    echo "=== 路由表 ==="
    ip route show | head -5

    echo ""
    echo "=== 防火牆狀態 ==="
    sudo ufw status numbered | head -10

    echo ""
    echo "=== ICMP 設置 ==="
    echo "icmp_echo_ignore_all: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_all)"
    echo "icmp_echo_ignore_broadcasts: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts)"

    echo ""
    echo "=== 端口監聽狀態 ==="
    ss -tlnp | grep -E "(30090|31280|6443)" | head -5
}

# 生成後續建議
generate_next_steps() {
    log_info "生成後續建議..."

    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════╗
║                        後續 OpenStack 設置建議                       ║
╚══════════════════════════════════════════════════════════════════════╝

如果本機修復後 VM 間仍無法 ping 通，需要在 OpenStack 管理層級執行：

1. 檢查安全群組規則：
   openstack security group list
   openstack security group rule list <security-group-id>

2. 添加 ICMP 規則到安全群組：
   openstack security group rule create \
     --protocol icmp \
     --ingress \
     --remote-ip 172.16.0.0/16 \
     <security-group-name>

3. 檢查浮動 IP 配置：
   openstack floating ip list
   openstack server show "VM-4（edge2）"

4. 驗證網路拓撲：
   openstack network list
   openstack router list

⚠️ 重要提醒：
- 如果你沒有 OpenStack 管理權限，請聯絡系統管理員
- 在生產環境中進行網路變更前，請先在測試環境驗證

EOF
}

# 主執行函數
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║              OpenStack 網路連通性快速修復工具                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    log_info "開始執行網路連通性修復 - $(date)"
    log_warn "⚠️  此腳本將修改系統網路設置，請確保已了解風險"

    echo -n "是否繼續執行修復? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "修復已取消"
        exit 0
    fi

    # 執行修復步驟
    check_sudo
    backup_configs
    fix_icmp_response
    configure_firewall
    fix_iptables

    echo ""
    log_info "等待 5 秒讓設置生效..."
    sleep 5

    # 測試結果
    test_connectivity

    echo ""
    show_diagnostic_info

    echo ""
    generate_next_steps

    echo ""
    log_success "🎉 VM-4 本機網路修復完成！"
    log_info "如果 VM 間仍無法 ping 通，請參考上述 OpenStack 管理建議"

    local backup_location=$(cat /tmp/network_backup_location 2>/dev/null || echo "未知")
    log_info "配置備份位置: $backup_location"

    log_info "完成時間: $(date)"
}

# 執行主函數
main "$@"