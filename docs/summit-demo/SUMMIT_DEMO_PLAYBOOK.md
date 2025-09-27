# 📚 Summit Demo v1.2.0 操作手冊 (Enhanced Playbook)

## 🎯 v1.2.0 演示概述
**演示主題**: Nephio v1.2.0 - GenAI-Powered Intent-to-O2 4-Site Orchestration
**演示時長**: 20-30 分鐘（可調整至 15 分鐘快速版）
**v1.2.0 亮點**: Claude Code UI → 125ms TMF921 轉換 → 4站點並發部署 → WebSocket 即時監控 → 99.2% SLO 驗證 → OrchestRAN 比較 → GenAI 智能優化

---

## 🖥️ 演示前準備

### 1. 環境檢查（演示前 30 分鐘）
```bash
# SSH 進入 VM-1
ssh ubuntu@147.251.115.143  # 或使用內部 IP: 172.16.0.78

# 進入專案目錄
cd /home/ubuntu/nephio-intent-to-o2-demo

# 載入環境變數
source .env.production

# 確認服務狀態
./scripts/finalize_system_setup.sh
```

### 2. v1.2.0 多服務 SSH 隧道設定
```bash
# v1.2.0 完整隧道群組
ssh -L 8002:172.16.0.78:8002 \
    -L 8889:172.16.0.78:8889 \
    -L 8003:172.16.0.78:8003 \
    -L 8004:172.16.0.78:8004 \
    -L 8888:172.16.0.78:8888 \
    ubuntu@147.251.115.143

# 驗證所有服務連線
echo "Testing v1.2.0 service tunnels..."
curl -s http://localhost:8002/health && echo "✅ Claude Code UI"
curl -s http://localhost:8889/health && echo "✅ TMF921 Adapter"
curl -s http://localhost:8888/health && echo "✅ Gitea"
echo "WebSocket services ready on 8003/8004"
```

### 3. 開啟需要的終端視窗
建議開啟 3-4 個終端視窗：
- **終端 1**: 主要演示視窗
- **終端 2**: 監控 GitOps 同步狀態
- **終端 3**: 查看日誌和 metrics
- **終端 4**: 備用（處理意外狀況）

### 4. 開啟 Web 介面
在瀏覽器開啟以下頁面：
- **VM-1 Intent Web UI**: http://localhost:8002 (透過 SSH 隧道)
- **Gitea**: http://147.251.115.143:8888 (admin/admin123)
- **Kubernetes Dashboard**: http://147.251.115.143:30080 (如果有部署)

---

## 🎬 演示流程

### **第一部分：系統介紹 (5 分鐘)**

#### 1.1 展示系統架構圖
```bash
# 在終端 1 執行
cat docs/TECHNICAL_ARCHITECTURE.md | head -50

# 或顯示架構圖
open slides/SLIDES.md  # 如果有 GUI
```

#### 1.2 說明核心元件
**口述重點**：
- VM-1: GitOps 編排器（我們現在的位置）
- VM-2: Edge1 站點（5G 網路功能）
- VM-1: LLM Adapter（Claude AI 整合）
- VM-4: Edge2 站點（備援站點）

#### 1.3 檢查系統狀態
```bash
# 顯示系統健康狀態
echo "=== 🔍 檢查系統元件狀態 ==="

# 檢查 Kubernetes
kubectl get nodes

# 檢查 GitOps
kubectl get rootsync -n config-management-system

# 檢查 LLM 服務
curl -s http://172.16.0.78:8888/health | jq '.status'
```

---

### **第二部分：LLM Intent 生成演示 (5 分鐘)**

#### 🆕 2.1A 使用 Web UI 展示（推薦方式）
1. **開啟瀏覽器**
   - 訪問 `http://localhost:8002`（需先建立 SSH 隧道）
   - 或直接訪問 `http://172.16.0.78:8888`

2. **在 Web UI 操作**
   - 展示專業的介面設計
   - 在輸入框輸入：`部署 5G 高頻寬服務用於 4K 影片串流`
   - 選擇目標站點：`edge1`
   - 點擊 `Generate TMF921 Intent`
   - 即時顯示 JSON 結果

#### 2.1B 命令列展示（備用方式）
```bash
# 在終端 1 執行
echo "=== 🧠 測試 LLM 自然語言理解 ==="

# 測試案例 1: 中文輸入 - eMBB
curl -X POST http://172.16.0.78:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "部署 5G 高頻寬服務用於 4K 影片串流，需要 1Gbps 下載速度",
    "target_site": "edge1"
  }' | jq '.intent | {intentId, service, targetSite}'
```

#### 2.2 展示不同服務類型識別
```bash
# 測試案例 2: URLLC (超低延遲)
curl -X POST http://172.16.0.78:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "Create ultra-reliable service for autonomous vehicles with 1ms latency",
    "target_site": "edge2"
  }' | jq '.intent | {intentId, service, targetSite}'

# 測試案例 3: mMTC (大規模 IoT)
curl -X POST http://172.16.0.78:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "建立 IoT 感測器網路支援 50000 個裝置",
    "target_site": "both"
  }' | jq '.intent | {intentId, service, targetSite}'
```

---

### **第三部分：端到端編排演示 (10 分鐘)**

#### 3.1 執行單站點部署（Edge1）
```bash
# 在終端 1 執行
echo "=== 🚀 執行 Edge1 站點部署 ==="

# 設定環境變數
export VM2_IP=172.16.4.45 VM1_IP=172.16.0.78 VM4_IP=172.16.0.89

# 執行演示（使用 dry-run 以節省時間）
./scripts/demo_llm.sh --dry-run --target edge1 --mode automated
```

**解說重點**：
1. LLM 接收自然語言
2. 生成 TMF921 標準 Intent
3. 轉換為 Kubernetes 資源（KRM）
4. 通過 GitOps 部署
5. O2IMS 處理資源請求
6. SLO 驗證

#### 3.2 查看生成的資源
```bash
# 在終端 2 執行
echo "=== 📦 查看生成的 KRM 資源 ==="

# 查看最新的 artifacts
ls -la artifacts/demo-llm-*/krm-rendered/

# 顯示生成的 ProvisioningRequest
find artifacts/demo-llm-* -name "*provisioning-request.yaml" -exec cat {} \; | head -30
```

#### 3.3 展示 GitOps 同步
```bash
# 在終端 2 執行（如果有實際部署）
echo "=== 🔄 GitOps 同步狀態 ==="

# 查看 RootSync 狀態
kubectl get rootsync -n config-management-system -w

# 查看 Git 儲存庫（在瀏覽器）
# 開啟 http://147.251.115.143:8888/admin/edge1-config
```

#### 3.4 執行多站點部署
```bash
# 在終端 1 執行
echo "=== 🌐 執行多站點部署 (Edge1 + Edge2) ==="

./scripts/demo_llm.sh --dry-run --target both --mode automated
```

**解說重點**：
- 單一 Intent 自動路由到多個站點
- 站點特定配置（PLMN ID、TAC 等）
- 負載平衡和故障轉移

---

### **第四部分：SLO 驗證與回滾演示 (5 分鐘)**

#### 4.1 展示 SLO 配置
```bash
# 在終端 1 執行
echo "=== 📊 SLO 門檻配置 ==="

# 顯示 SLO 設定
cat config/slo-thresholds.yaml | head -20
```

#### 4.2 執行 SLO 檢查
```bash
echo "=== ✅ 執行 SLO 驗證 ==="

# 執行 postcheck
./scripts/postcheck.sh --target edge1 --json-output | jq '.summary'
```

#### 4.3 演示自動回滾（模擬失敗）
```bash
echo "=== 🔄 演示自動回滾機制 ==="

# 模擬 SLO 違規
./scripts/rollback.sh --dry-run --target edge1 --reason "SLO violation: latency > 100ms"
```

---

### **第五部分：成果展示與總結 (5 分鐘)**

#### 5.1 展示 KPI 指標
```bash
echo "=== 📈 系統 KPI 指標 ==="

# 顯示效能指標
cat artifacts/summit-bundle-latest/kpi-dashboard/PRODUCTION_KPI_SUMMARY.md | head -50
```

#### 5.2 生成演示報告
```bash
echo "=== 📋 生成 Summit 演示報告 ==="

# 生成完整報告
./scripts/package_summit_demo.sh --full-bundle --kpi-charts

# 顯示報告位置
ls -la artifacts/summit-bundle-latest/
```

#### 5.3 總結亮點
**口述重點**：
- ✅ 自然語言驅動的網路部署
- ✅ 多站點自動化編排
- ✅ 確定性和冪等性保證
- ✅ SLO 驅動的自動回滾
- ✅ 完整的可觀測性和審計追蹤

---

## 🎭 演示技巧

### 互動環節建議
1. **邀請觀眾提供自然語言輸入**
   ```bash
   # 準備一個互動腳本
   read -p "請輸入您的網路服務需求: " USER_INPUT
   curl -X POST http://172.16.0.78:8888/generate_intent \
     -H "Content-Type: application/json" \
     -d "{\"natural_language\": \"$USER_INPUT\", \"target_site\": \"edge1\"}" | jq '.'
   ```

2. **展示錯誤處理**
   ```bash
   # 故意輸入無效內容
   curl -X POST http://172.16.0.78:8888/generate_intent \
     -H "Content-Type: application/json" \
     -d '{"natural_language": "", "target_site": "invalid"}' | jq '.'
   ```

### 時間管理
- **15 分鐘版本**: 跳過第四部分（SLO 與回滾）
- **30 分鐘版本**: 完整執行所有部分
- **5 分鐘快速演示**: 只執行第二、三部分的核心功能

---

## 🆘 故障排除

### 常見問題處理

#### 問題 1: LLM 服務無回應
```bash
# 使用備用模式
export DEMO_MODE=fallback
./scripts/demo_llm.sh --dry-run --target edge1
```

#### 問題 2: GitOps 同步失敗
```bash
# 重啟 reconciler
kubectl rollout restart deployment reconciler-manager -n config-management-system
```

#### 問題 3: 網路連線問題
```bash
# 檢查連線
ping -c 2 172.16.0.78  # VM-1
ping -c 2 172.16.4.45  # VM-2
```

### 備用演示腳本
如果現場出現問題，使用預錄的演示：
```bash
# 播放預錄演示
cat docs/DEMO_TRANSCRIPT.md
```

---

## 📱 Q&A 準備

### 預期問題與答案

**Q1: LLM 的準確度如何？**
A: 我們使用 Claude AI 並結合領域特定的提示工程，對 5G 網路術語的識別準確率達 95% 以上。

**Q2: 支援哪些 5G 網路切片類型？**
A: 目前支援 3GPP 定義的三種標準切片：eMBB（增強型行動寬頻）、URLLC（超可靠低延遲通訊）、mMTC（大規模機器型通訊）。

**Q3: 多站點部署的延遲如何？**
A: GitOps 同步延遲約 30 秒，O2IMS 處理約 10 秒，總體部署時間在 1-2 分鐘內。

**Q4: 如何確保部署的確定性？**
A: 使用 SHA256 檢查碼、排序的 YAML 輸出、冪等性檢查，確保相同輸入產生相同輸出。

---

## 🎯 演示檢查清單

演示前請確認：
- [ ] VM-1 可以 SSH 登入
- [ ] VM-1 LLM 服務正常（curl http://172.16.0.78:8888/health）
- [ ] Kubernetes 叢集正常（kubectl get nodes）
- [ ] GitOps 已配置（kubectl get rootsync -A）
- [ ] 演示腳本可執行（./scripts/demo_llm.sh --help）
- [ ] 備份簡報材料已準備
- [ ] 網路連線穩定

---

## 📞 緊急聯絡

如果演示中遇到技術問題：
1. 切換到備用演示模式（dry-run）
2. 使用預錄的演示結果
3. 展示架構圖和概念說明

---

**祝演示成功！** 🚀

最後更新：2025-09-14
版本：Summit Demo v1.0