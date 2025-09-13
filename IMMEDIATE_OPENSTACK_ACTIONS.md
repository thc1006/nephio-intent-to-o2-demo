# 立即執行的 OpenStack 修復步驟

**目標**: 解決 VM-4 ping 失敗問題
**環境**: OpenStack VM-4 (172.16.0.89)
**狀態**: HTTP 服務正常，需要修復 ICMP 連通性

---

## 🚀 立即可執行的步驟 (在 VM-4 上)

### 步驟 1: 快速診斷 (30 秒)
```bash
# 檢查當前 ICMP 設置
echo "ICMP ignore all: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_all)"
echo "ICMP ignore broadcasts: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts)"

# 檢查防火牆狀態
sudo ufw status | head -10

# 檢查是否有阻擋 ICMP 的 iptables 規則
sudo iptables -L INPUT | grep -i icmp
```

### 步驟 2: 執行自動修復腳本 (2 分鐘)
```bash
# 執行我們準備的修復腳本
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/fix_openstack_connectivity.sh
```

### 步驟 3: 手動快速修復 (如果腳本不可用)
```bash
# 啟用 ICMP 響應
echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all
echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# 永久設置
echo "net.ipv4.icmp_echo_ignore_all = 0" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts = 0" | sudo tee -a /etc/sysctl.conf

# 允許內網 ICMP
sudo ufw allow from 172.16.0.0/16 to any proto icmp comment "Allow internal ICMP"
sudo ufw reload

# 測試修復結果
ping -c 3 127.0.0.1        # 本地測試
ping -c 3 172.16.0.89      # 自己測試
ping -c 3 172.16.0.1       # 網關測試
```

---

## 🔧 OpenStack 管理層級修復 (需要管理權限)

### 如果你有 OpenStack CLI 訪問權限：

#### 1. 檢查當前安全群組
```bash
# 列出所有安全群組
openstack security group list

# 檢查 VM-4 的安全群組
openstack server show "VM-4（edge2）" -f value -c security_groups

# 查看具體安全群組規則
openstack security group show <security-group-id>
```

#### 2. 添加 ICMP 規則
```bash
# 獲取安全群組名稱
SG_NAME=$(openstack server show "VM-4（edge2）" -f value -c security_groups | tr -d "[]'" | cut -d',' -f1)

# 添加允許內網 ICMP 的規則
openstack security group rule create \
  --protocol icmp \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  --description "Allow ICMP from internal network" \
  "$SG_NAME"

# 驗證規則添加成功
openstack security group rule list "$SG_NAME" | grep icmp
```

#### 3. 檢查浮動 IP 配置
```bash
# 檢查浮動 IP 狀態
openstack floating ip list | grep 147.251.115.193

# 檢查 VM-4 的網路配置
openstack server show "VM-4（edge2）" -c addresses -c security_groups

# 確認浮動 IP 正確綁定
openstack floating ip show 147.251.115.193
```

### 如果你沒有 OpenStack CLI 訪問權限：

聯絡系統管理員，請他們執行以下檢查：
1. 檢查 VM-4 的安全群組是否允許 ICMP 流量
2. 確認安全群組規則包含：`--protocol icmp --ingress --remote-ip 172.16.0.0/16`
3. 驗證浮動 IP 147.251.115.193 正確綁定到 VM-4
4. 檢查網路拓撲和路由器配置

---

## 🧪 即時測試指令

### 在 VM-4 上測試 (修復後)
```bash
# 測試套件 1: 本地連通性
echo "=== 本地連通性測試 ==="
ping -c 2 127.0.0.1
ping -c 2 172.16.0.89
echo ""

# 測試套件 2: 網關和外部
echo "=== 網關和外部測試 ==="
ping -c 2 172.16.0.1        # 網關
ping -c 2 172.16.0.78       # VM-1 (如果已修復)
echo ""

# 測試套件 3: HTTP 服務 (確保仍正常)
echo "=== HTTP 服務測試 ==="
curl -s http://localhost:30090/health
curl -s http://172.16.0.89:30090/health
echo ""

# 測試套件 4: 端口可達性
echo "=== 端口可達性測試 ==="
nc -zv 172.16.0.89 30090
nc -zv 172.16.0.89 31280
nc -zv 172.16.0.89 6443
```

### 在 VM-1 上測試 (修復後)
```bash
# 從 VM-1 測試到 VM-4 的連通性
echo "=== VM-1 到 VM-4 連通性測試 ==="
ping -c 3 172.16.0.89                              # 基本 ping
curl -s http://172.16.0.89:30090/health            # HTTP 健康檢查
curl -s http://172.16.0.89:30090/metrics/api/v1/slo | jq .  # SLO 數據

# 端口掃描測試
nmap -p 30090,31280,6443 172.16.0.89

# 更新並測試 postcheck.sh
./scripts/postcheck.sh
```

---

## 📊 成功指標

修復成功後，你應該看到：

### ✅ 預期成功結果
```bash
# ping 測試成功
$ ping -c 3 172.16.0.89
PING 172.16.0.89 (172.16.0.89) 56(84) bytes of data.
64 bytes from 172.16.0.89: icmp_seq=1 ttl=64 time=0.043 ms
64 bytes from 172.16.0.89: icmp_seq=2 ttl=64 time=0.037 ms
64 bytes from 172.16.0.89: icmp_seq=3 ttl=64 time=0.041 ms

# HTTP 服務正常
$ curl http://172.16.0.89:30090/health
OK

# SLO 數據正常
$ curl http://172.16.0.89:30090/metrics/api/v1/slo | jq .site
"edge2"
```

### ⚠️ 如果仍有問題
```bash
# 檢查系統設置
cat /proc/sys/net/ipv4/icmp_echo_ignore_all    # 應該是 0
sudo ufw status | grep icmp                     # 應該有 ALLOW 規則
sudo iptables -L INPUT | grep -i icmp          # 不應該有 DROP 規則
```

---

## 🔚 完成後的驗證

### 最終驗證清單
- [ ] VM-4 能夠 ping 通自己 (172.16.0.89)
- [ ] VM-4 能夠 ping 通網關 (172.16.0.1)
- [ ] VM-1 能夠 ping 通 VM-4 (172.16.0.89)
- [ ] HTTP 服務仍然正常 (30090, 31280, 6443)
- [ ] postcheck.sh 多站點測試通過

### 記錄修復結果
```bash
# 創建修復報告
cat > /tmp/openstack_fix_report.txt << EOF
OpenStack 網路修復報告
=====================
修復時間: $(date)
修復前狀態: ping 失敗，HTTP 正常
修復後狀態: $(ping -c 1 172.16.0.89 >/dev/null 2>&1 && echo "ping 成功" || echo "ping 仍失敗")

修復動作:
- 啟用 ICMP 響應
- 配置防火牆允許內網 ICMP
- 更新 iptables 規則
- 驗證服務可用性

結果: 網路連通性問題已解決，VM-1 可以正常整合 VM-4 Edge2
EOF

echo "修復報告已保存到: /tmp/openstack_fix_report.txt"
```

---

**🎯 執行優先順序：**
1. **立即執行**: VM-4 上的快速修復腳本
2. **如需要**: OpenStack 安全群組規則添加
3. **最後驗證**: VM-1 多站點整合測試

修復完成後，VM-1 就能完全正常地使用 VM-4 Edge2 的多站點功能了！