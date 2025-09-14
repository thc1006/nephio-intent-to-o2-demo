# VM-1 與 VM-4 (Edge2) 對接整合指南

**更新日期**: $(date)
**狀態**: VM-4 Edge2 部署完成，準備與 VM-1 整合

---

## 🎯 VM-4 (Edge2) 部署完成狀態

### ✅ 基礎設施就緒
- **Kind 集群**: `edge2-cluster` (2 節點: 1 control-plane + 1 worker)
- **Config Sync**: v1.17.0 已安裝並運行
- **防火牆**: 已開放 30090, 31280, 6443 端口
- **SLO 工作負載**: 已部署並運行正常

### 📍 VM-4 網路資訊
```bash
# VM-4 基本資訊
內部 IP: 172.16.0.89
外部 IP: 147.251.115.193 (如有安全群組限制需開放)
集群名稱: edge2-cluster
```

---

## 🔗 VM-1 可用的 Edge2 端點

### 1. SLO Metrics 端點
```bash
# 直接訪問方式 (如網路允許)
URL: http://172.16.0.89:30090/metrics/api/v1/slo
Method: GET
Response Format: JSON

# 範例響應:
{
  "slo": {
    "latency_p95_ms": 11.8,
    "latency_p99_ms": 11.86,
    "success_rate": 0.98,
    "throughput_p95_mbps": 5.56,
    "total_requests": 100
  },
  "site": "edge2",
  "timestamp": "2025-09-13T12:28:18.161832"
}
```

### 2. 健康檢查端點
```bash
URL: http://172.16.0.89:30090/health
Method: GET
Response: "OK"
```

### 3. O2IMS 端點 (預留)
```bash
URL: http://172.16.0.89:31280/o2ims/measurement/v1/slo
Status: 準備中 (需要部署 O2IMS 服務)
```

---

## 🛠️ VM-1 整合配置更新

### 1. 更新 postcheck.sh 配置

在 VM-1 上更新 `scripts/postcheck.sh` 文件中的站點配置：

```bash
# 原有配置
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="172.16.4.55:30090/metrics/api/v1/slo"  # 舊配置
)

# 更新為新的 VM-4 配置
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="172.16.0.89:30090/metrics/api/v1/slo"  # 新的 VM-4 配置
)

# O2IMS 配置更新
declare -A O2IMS_SITES=(
    [edge1]="http://172.16.4.45:31280/o2ims/measurement/v1/slo"
    [edge2]="http://172.16.0.89:31280/o2ims/measurement/v1/slo"  # 新的 VM-4 配置
)
```

### 2. SSH 隧道方案 (推薦用於生產環境)

如果直接網路存取有限制，在 VM-1 上建立 SSH 隧道：

```bash
# 創建隧道管理腳本
cat > ~/vm4_tunnels.sh << 'EOF'
#!/bin/bash
VM4_IP="172.16.0.89"  # 或使用外部 IP 147.251.115.193

start_tunnels() {
    echo "啟動 VM-4 Edge2 隧道..."
    ssh -L 30092:localhost:30090 ubuntu@${VM4_IP} -N -f
    ssh -L 31282:localhost:31280 ubuntu@${VM4_IP} -N -f
    echo "隧道已啟動 - SLO: localhost:30092, O2IMS: localhost:31282"
}

stop_tunnels() {
    echo "停止 VM-4 隧道..."
    pkill -f "ssh -L 30092"
    pkill -f "ssh -L 31282"
    echo "隧道已停止"
}

status() {
    echo "檢查隧道狀態:"
    ss -tlnp | grep -E "(30092|31282)" || echo "無隧道運行中"
}

case "$1" in
    start) start_tunnels ;;
    stop) stop_tunnels ;;
    status) status ;;
    restart) stop_tunnels; sleep 2; start_tunnels ;;
    *) echo "使用方法: $0 {start|stop|status|restart}" ;;
esac
EOF

chmod +x ~/vm4_tunnels.sh

# 使用隧道時的 postcheck.sh 配置
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="localhost:30092/metrics/api/v1/slo"  # 透過隧道
)
```

---

## 🧪 VM-1 整合測試指令

### 1. 基本連通性測試
```bash
# 測試 VM-4 網路連通性
ping -c 3 172.16.0.89

# 測試 SLO 端點連通性
curl -v http://172.16.0.89:30090/health

# 測試 SLO 數據獲取
curl -s http://172.16.0.89:30090/metrics/api/v1/slo | jq .
```

### 2. 多站點 postcheck 測試
```bash
# 在 VM-1 上執行完整的多站點檢查
cd /path/to/nephio-intent-to-o2-demo
./scripts/postcheck.sh

# 預期輸出應該包含 edge1 和 edge2 兩個站點的 SLO 數據
```

### 3. 自動化檢查腳本
```bash
# 在 VM-1 上創建快速驗證腳本
cat > ~/verify_edge2_connectivity.sh << 'EOF'
#!/bin/bash
EDGE2_IP="172.16.0.89"
EDGE2_SLO_PORT="30090"

echo "=== VM-4 Edge2 連通性驗證 ==="
echo "測試目標: ${EDGE2_IP}:${EDGE2_SLO_PORT}"

# 基本網路測試
echo "1. 網路連通性:"
if ping -c 1 -W 5 ${EDGE2_IP} >/dev/null 2>&1; then
    echo "   ✅ 可以 ping 通 ${EDGE2_IP}"
else
    echo "   ❌ 無法 ping 通 ${EDGE2_IP}"
fi

# 端口測試
echo "2. SLO 端口測試:"
if timeout 5 bash -c "</dev/tcp/${EDGE2_IP}/${EDGE2_SLO_PORT}"; then
    echo "   ✅ 端口 ${EDGE2_SLO_PORT} 可連接"
else
    echo "   ❌ 端口 ${EDGE2_SLO_PORT} 無法連接"
fi

# SLO 數據測試
echo "3. SLO 數據獲取:"
SLO_RESPONSE=$(curl -s --max-time 10 http://${EDGE2_IP}:${EDGE2_SLO_PORT}/metrics/api/v1/slo)
if echo "$SLO_RESPONSE" | jq . >/dev/null 2>&1; then
    echo "   ✅ SLO 數據獲取成功"
    echo "   📊 當前 Edge2 SLO 數據:"
    echo "$SLO_RESPONSE" | jq .
else
    echo "   ❌ SLO 數據獲取失敗"
    echo "   響應: $SLO_RESPONSE"
fi
EOF

chmod +x ~/verify_edge2_connectivity.sh
./verify_edge2_connectivity.sh
```

---

## 📋 VM-1 需要執行的配置步驟

### 第一階段：基礎連通性驗證
```bash
# 1. 執行連通性測試
~/verify_edge2_connectivity.sh

# 2. 如果連通性正常，更新 postcheck.sh 配置
# 編輯 scripts/postcheck.sh，更新 SITES 陣列中的 edge2 配置

# 3. 測試多站點 postcheck
./scripts/postcheck.sh
```

### 第二階段：隧道方案 (如直接連接有問題)
```bash
# 1. 建立隧道
~/vm4_tunnels.sh start

# 2. 使用隧道配置更新 postcheck.sh
# 將 edge2 配置改為 "localhost:30092/metrics/api/v1/slo"

# 3. 測試隧道連接
curl -s http://localhost:30092/metrics/api/v1/slo | jq .
```

---

## 🔧 故障排除指南

### 網路連通性問題
```bash
# 檢查 VM-4 防火牆狀態
sudo ufw status

# 檢查端口是否監聽
ss -tlnp | grep -E "(30090|31280)"

# 檢查 Kind 端口綁定
docker port edge2-cluster-control-plane
```

### SLO 服務問題
```bash
# 檢查 SLO Pod 狀態
kubectl get pods -n slo-monitoring

# 檢查服務狀態
kubectl get svc -n slo-monitoring

# 檢查 Pod 日誌
kubectl logs -n slo-monitoring deployment/slo-exporter-edge2
```

### RootSync 同步問題
```bash
# 檢查 RootSync 狀態
kubectl get rootsync -n config-management-system

# 檢查 Git 認證
kubectl get secret git-creds -n config-management-system -o yaml
```

---

## 📊 當前狀態總結

**✅ 已完成:**
- VM-4 Kind 集群 edge2-cluster 部署完成
- SLO 工作負載部署並運行正常
- 防火牆規則配置完成
- 端口綁定驗證成功 (30090, 31280, 6443)

**🔄 準備中:**
- Git 認證 token 更新 (當前使用 dummy token)
- O2IMS 服務部署 (31280 端口預留)

**🎯 下一步:**
- VM-1 更新 postcheck.sh 配置
- 執行多站點整合測試
- 部署 O2IMS 服務 (如需要)

---

## 📞 支援資訊

**VM-4 Edge2 端點:**
- SLO Metrics: http://172.16.0.89:30090/metrics/api/v1/slo
- 健康檢查: http://172.16.0.89:30090/health
- Kubernetes API: https://172.16.0.89:6443

**故障排除聯絡:**
- 檢查此文檔的故障排除章節
- 查看 VM-4 上的 `/tmp/p0.4C_vm4_edge2_*.log` 日誌文件
- 執行 `kubectl get all -n slo-monitoring` 確認服務狀態

---
*此文檔會隨著整合進度持續更新*