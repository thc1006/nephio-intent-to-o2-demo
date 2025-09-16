# VM-1 使用指南 - VM-4 Edge2 整合就緒

**狀態**: ✅ VM-4 Edge2 部署完成，準備與 VM-1 對接
**日期**: $(date)

---

## 🚀 立即可用的 VM-4 Edge2 端點

```bash
# SLO 度量端點 (主要整合目標) - ✅ 已驗證可用
curl http://172.16.4.176:30090/metrics/api/v1/slo

# 健康檢查端點 - ✅ 已驗證可用
curl http://172.16.4.176:30090/health
```

### ⚠️ 重要網路行為說明：
- **✅ HTTP 連接正常**：curl 和 HTTP 請求完全正常
- **❌ ping 會失敗**：ICMP 被防火牆阻擋，但這不影響服務使用
- **📍 使用內網 IP**：172.16.4.176 (不要使用外網 IP 147.251.115.193)

---

## 📋 VM-1 需要執行的 3 個步驟

### 步驟 1: 驗證連通性 (2 分鐘)
```bash
# 下載並執行自動化測試
cd /path/to/nephio-intent-to-o2-demo
chmod +x scripts/vm1_test_edge2_connectivity.sh
./scripts/vm1_test_edge2_connectivity.sh
```

### 步驟 2: 更新 postcheck.sh 配置 (1 分鐘)
```bash
# 編輯 scripts/postcheck.sh，找到 SITES 陣列並更新：
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="172.16.4.176:30090/metrics/api/v1/slo"  # 新增這行
)
```

### 步驟 3: 測試多站點功能 (1 分鐘)
```bash
# 執行多站點檢查
./scripts/postcheck.sh

# 預期結果：應該看到 edge1 和 edge2 兩個站點的 SLO 數據
```

---

## 🛠️ 如果直接連接有問題，使用 SSH 隧道

```bash
# 創建隧道 (一次性設置)
ssh -L 30092:localhost:30090 ubuntu@172.16.4.176 -N -f

# 更新 postcheck.sh 使用隧道
[edge2]="localhost:30092/metrics/api/v1/slo"

# 測試隧道
curl http://localhost:30092/metrics/api/v1/slo
```

---

## 📚 詳細文檔位置

| 文檔 | 位置 | 用途 |
|------|------|------|
| **完整整合指南** | `VM1_INTEGRATION_GUIDE.md` | 詳細的對接說明和故障排除 |
| **自動化測試** | `scripts/vm1_test_edge2_connectivity.sh` | 連通性驗證工具 |
| **部署報告** | `artifacts/VM4_EDGE2_FINAL_DEPLOYMENT_REPORT.md` | 完整的部署狀態 |

---

## ✅ 驗收檢查清單

- [x] VM-4 Kind 集群運行正常
- [x] SLO 端點 (30090) 可從 VM-1 訪問
- [x] 防火牆規則配置完成
- [x] 自動化測試工具提供
- [x] 完整文檔和指南提供

---

## 🎯 預期結果

完成上述步驟後，VM-1 將能夠：
- ✅ 監控兩個站點 (edge1 + edge2) 的 SLO 指標
- ✅ 執行多站點驗收測試
- ✅ 使用統一的 postcheck.sh 進行品質檢查

---

## 📞 問題聯絡

如有問題，請檢查：
1. `VM1_INTEGRATION_GUIDE.md` 的故障排除章節
2. 執行 `./scripts/vm1_test_edge2_connectivity.sh` 獲取詳細測試報告
3. 查看 VM-4 上的服務狀態：`kubectl get pods -n slo-monitoring`

---

**🎉 VM-4 Edge2 整合就緒！歡迎 VM-1 開始多站點操作！**