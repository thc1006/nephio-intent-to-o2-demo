# VM-4 網路連接診斷提示詞

**目的**：在 VM-4 上執行，診斷為何無法與 VM-1 (172.16.0.78) 建立連接

---

## 📋 提示詞（複製貼上給 VM-4 上的 Claude Code）

```
你好！我是 edge2 (VM-4)，需要診斷為什麼無法與 VM-1 orchestrator 建立連接。

## 背景資訊

- **本機角色**: Edge site VM-4 (edge2)
- **本機預期 IP**: 172.16.0.89 (內網), 147.251.115.193 (外網)
- **Orchestrator**: VM-1 at 172.16.0.78
- **問題**: VM-1 無法 ping/SSH 到本機

## 請執行以下診斷任務

### 1. 網路配置檢查

請檢查並報告：
- 本機的 IP 地址配置（所有網路介面）
- 預期 IP 172.16.0.89 是否正確配置
- 路由表配置
- 是否能 ping 到 VM-1 (172.16.0.78)
- DNS 配置

命令參考：
```bash
ip addr show
ip route
ping -c 3 172.16.0.78
cat /etc/resolv.conf
```

### 2. 防火牆規則檢查

請檢查：
- iptables 的 INPUT chain 規則
- 是否有規則阻擋來自 172.16.0.78 的連接
- SSH 服務 (port 22) 是否被允許
- ICMP (ping) 是否被允許

命令參考：
```bash
sudo iptables -L INPUT -n -v --line-numbers
sudo iptables -L OUTPUT -n -v --line-numbers
sudo ufw status verbose 2>/dev/null || echo "ufw not active"
```

### 3. SSH 服務檢查

請檢查：
- SSH 服務是否運行
- SSH 監聽的地址和端口
- SSH 配置是否正確
- authorized_keys 是否包含 VM-1 的公鑰

命令參考：
```bash
sudo systemctl status sshd
sudo ss -tlnp | grep :22
cat ~/.ssh/authorized_keys | grep -i "vm1\|edge-management" || echo "No VM-1 key found"
sudo grep -E "^(Port|ListenAddress|PermitRootLogin|PubkeyAuthentication)" /etc/ssh/sshd_config
```

### 4. Kubernetes 服務檢查

請檢查：
- Kubernetes 節點狀態
- Prometheus 服務 (NodePort 30090)
- O2IMS 服務 (NodePort 31280)
- 服務是否正確暴露

命令參考：
```bash
kubectl get nodes -o wide
kubectl get svc -A | grep -E "30090|31280|NodePort"
kubectl get pods -n monitoring
curl -s http://localhost:30090/health || echo "Prometheus health check failed"
```

### 5. 系統資訊

請收集：
- 主機名稱
- 系統版本
- 是否有 SELinux/AppArmor 限制
- 近期系統日誌中與網路相關的錯誤

命令參考：
```bash
hostname
cat /etc/os-release | grep PRETTY_NAME
getenforce 2>/dev/null || echo "SELinux not installed"
sudo journalctl -u sshd -n 50 --no-pager | grep -i "error\|failed\|refused" | tail -10
sudo dmesg | grep -i "firewall\|iptables\|netfilter" | tail -10
```

### 6. 測試反向連接

請測試：
- 能否 ping 到 VM-1 (172.16.0.78)
- 能否連接到 VM-1 的服務（如果知道端口）
- traceroute 到 VM-1 的路徑

命令參考：
```bash
ping -c 5 172.16.0.78
telnet 172.16.0.78 22 2>&1 &
sleep 3
pkill telnet
```

## 輸出格式要求

請以結構化的報告形式輸出，包含：

1. **執行摘要**：3-5 句話說明主要發現
2. **網路配置狀態**：IP、路由、連接性測試結果
3. **防火牆狀態**：是否有阻擋規則
4. **SSH 服務狀態**：服務狀態、配置、密鑰
5. **Kubernetes 服務狀態**：NodePort 服務是否正常
6. **問題分析**：根據診斷結果，列出可能的原因（按可能性排序）
7. **建議修復步驟**：具體的命令或操作步驟

## 重要提醒

- 如果需要 sudo 權限但沒有，請說明哪些檢查無法完成
- 如果某些命令不存在，請使用替代方案
- 請保存完整的診斷報告到 `/tmp/vm4-network-diagnostic-report.md`
```

---

## 🎯 快速版本（精簡提示詞）

如果需要更簡潔的版本：

```
診斷 VM-4 為何無法與 VM-1 (172.16.0.78) 連接。請檢查：

1. 本機 IP 是否為 172.16.0.89
2. 能否 ping 172.16.0.78
3. iptables INPUT 規則是否阻擋 172.16.0.78
4. SSH 服務是否運行且監聽 port 22
5. ~/.ssh/authorized_keys 是否包含 VM-1 公鑰
6. Prometheus (30090) 和 O2IMS (31280) 服務是否運行

生成診斷報告，列出問題原因和修復建議。
```

---

## 📤 使用方式

### 方式 1：直接對話
在 VM-4 上啟動 Claude Code，然後貼上上述提示詞。

### 方式 2：通過檔案
```bash
# 在 VM-4 上
claude -f /path/to/diagnostic-prompt.md
```

### 方式 3：透過 SSH 管道（如果 SSH 有時能通）
```bash
# 在 VM-1 上
cat docs/operations/VM4_DIAGNOSTIC_PROMPT.md | \
  ssh edge2 "claude code -p '\$(cat)'"
```

---

## 🔍 預期診斷結果

Claude Code 應該會發現以下一種或多種問題：

1. **iptables INPUT 規則阻擋**
   - 預期：有 DROP 規則阻擋來自 172.16.0.78 的流量

2. **SSH 服務配置問題**
   - 預期：authorized_keys 缺少 VM-1 公鑰

3. **網路配置錯誤**
   - 預期：IP 地址配置錯誤或路由缺失

4. **防火牆軟體阻擋**
   - 預期：ufw 或其他防火牆軟體啟用

---

## 📞 後續動作

診斷完成後，VM-4 上的 Claude Code 會提供修復建議。請：

1. 審查診斷報告
2. 確認建議的修復步驟
3. 執行修復（可能需要手動確認某些操作）
4. 重新測試連接性

驗證命令（在 VM-4 上執行）：
```bash
# 測試到 VM-1 的連接
ping -c 3 172.16.0.78

# 檢查 VM-1 是否能連入（查看 SSH 日誌）
sudo journalctl -u sshd -f
```