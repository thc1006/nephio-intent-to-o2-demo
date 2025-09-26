# 🎯 Summit Demo 完整執行手冊

## 📋 演示前的準備工作

### 必備的連線資訊
```bash
# SSH 登入資訊
主機位址: 147.251.115.143
使用者名稱: ubuntu
工作目錄: /home/ubuntu/nephio-intent-to-o2-demo

# 內部網路 IP 對照表
VM-1 (GitOps 編排器): 172.16.0.78  # 這是你要登入操作的主機
VM-2 (Edge1 站台): 172.16.4.45     # 第一個邊緣站點
VM-1 (LLM 服務): 172.16.0.78        # AI 語言模型服務
VM-4 (Edge2 站台): 172.16.0.89     # 第二個邊緣站點
```

### 要事先開好的網頁
1. **Gitea 版本控制介面**: http://147.251.115.143:8888
   - 帳號: admin
   - 密碼: admin123
   - 用來展示: GitOps 自動化配置更新

2. **LLM 服務 API**: http://172.16.0.78:8888
   - 用來展示: 自然語言轉換成網路意圖

---

## 🆕 Web UI 演示選項（推薦）

### 使用 VM-1 Web UI 的準備
```bash
# 方法一：在你的筆電建立 SSH 隧道（推薦）
ssh -L 8888:172.16.0.78:8888 ubuntu@147.251.115.143

# 然後在瀏覽器開啟
http://localhost:8002/

# 方法二：直接存取（如果在內部網路）
http://172.16.0.78:8888/
```

---

## 🚀 開始演示的執行流程

### 步驟 0: 演示前的準備（提前 10 分鐘）

#### 0.1 登入系統
```bash
# 從你的筆電執行
ssh ubuntu@147.251.115.143

# 切換到專案資料夾
cd /home/ubuntu/nephio-intent-to-o2-demo

# 載入環境設定
source .env.production
```

#### 0.2 準備多個終端機視窗
建議同時開三個 SSH 連線:
- **視窗 1**: 跑主要的演示指令
- **視窗 2**: 即時監看 GitOps 同步狀態
- **視窗 3**: 觀察系統日誌

#### 0.3 確認系統都正常運作
```bash
# 在視窗 1 執行
echo "=== 🔍 檢查系統狀態 ==="

# 確認 Kubernetes 叢集正常
kubectl get nodes

# 確認 LLM 服務有回應
curl -s http://172.16.0.78:8888/health | jq '.status'

# 確認 GitOps 設定正確
kubectl get rootsync -n config-management-system
```

---

### 步驟 1: 展示自然語言轉換成網路意圖（3 分鐘）

#### 🆕 選項 A: 使用 Web UI 演示（推薦，更視覺化）

1. **開啟 Web UI**
   - 瀏覽器訪問 `http://localhost:8002/`（如果已建立 SSH 隧道）
   - 展示專業的介面設計

2. **中文輸入演示**
   - 在輸入框輸入：`部署 5G 高頻寬服務來支援 4K 影片串流`
   - 選擇目標站點：`edge1`
   - 點擊 `Generate TMF921 Intent`
   - 即時顯示生成的 Intent JSON

3. **英文輸入演示**
   - 輸入：`Deploy ultra-reliable service for autonomous vehicles`
   - 選擇目標站點：`edge2`
   - 展示 URLLC 服務識別

#### 選項 B: 使用命令列演示（備用）

##### 1.1 用中文測試 - 高頻寬服務
```bash
# 在視窗 1 執行
echo "=== 🧠 測試中文語言理解能力 ==="

curl -X POST http://172.16.0.78:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "部署 5G 高頻寬服務來支援 4K 影片串流",
    "target_site": "edge1"
  }' | jq '.intent | {intentId, service, targetSite}'
```

**你會看到的結果**:
```json
{
  "intentId": "intent_xxxxx",
  "service": {
    "type": "eMBB"
  },
  "targetSite": "edge1"
}
```

##### 1.2 用英文測試 - 超低延遲服務
```bash
echo "=== 🚗 測試英文的超低延遲服務識別 ==="

curl -X POST http://172.16.0.78:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "Deploy ultra-reliable service for autonomous vehicles",
    "target_site": "edge2"
  }' | jq '.intent | {intentId, service, targetSite}'
```

**跟觀眾說明的重點**:
- AI 會自動判斷你要的是哪種服務（寬頻/低延遲/大連結）
- 中文英文都聽得懂
- 自動知道要部署到哪個站點
- Web UI 讓整個過程更直觀

---

### 步驟 2: 執行單一站點的部署（5 分鐘）

#### 2.1 部署到第一個邊緣站點
```bash
echo "=== 🚀 開始部署到 Edge1 站點 ==="

# 設定各個 VM 的 IP
export VM2_IP=172.16.4.45 VM1_IP=172.16.0.78 VM4_IP=172.16.0.89

# 執行演示腳本（用 dry-run 模式可以更快展示）
./scripts/demo_llm.sh --dry-run --target edge1 --mode automated
```

#### 2.2 在第二個視窗監看 GitOps 同步狀況
```bash
# 在視窗 2 執行這個指令
watch -n 2 'kubectl get rootsync -n config-management-system'
```

#### 2.3 看看系統產生了什麼資源
```bash
# 在視窗 1 執行
echo "=== 📦 檢視系統產生的 KRM 資源 ==="

# 列出剛剛產生的檔案
ls -la artifacts/demo-llm-*/krm-rendered/edge1/

# 展示產生的部署請求
cat artifacts/demo-llm-*/krm-rendered/edge1/*provisioning-request.yaml | head -30
```

#### 2.4 在網頁上看 Git 的變更記錄
1. 打開瀏覽器: http://147.251.115.143:8888
2. 登入帳號: admin/admin123
3. 進入: admin/edge1-config 儲存庫
4. 看最新的 commit 內容

---

### 步驟 3: 同時部署到多個站點（5 分鐘）

#### 3.1 一次部署到兩個站點
```bash
echo "=== 🌐 執行多站點同時部署 (Edge1 + Edge2) ==="

./scripts/demo_llm.sh --dry-run --target both --mode automated
```

#### 3.2 檢查兩個站點的設定內容
```bash
# 看看 Edge1 的設定檔
echo "Edge1 站點的設定:"
ls artifacts/demo-llm-*/krm-rendered/edge1/

# 看看 Edge2 的設定檔
echo "Edge2 站點的設定:"
ls artifacts/demo-llm-*/krm-rendered/edge2/
```

**跟觀眾強調的重點**:
- 一個指令就能同時部署到多個站點
- 每個站點都有自己專屬的網路設定（像是 PLMN ID、TAC 這些）
- GitOps 會同時進行同步，不用一個一個處理

---

### 步驟 4: 服務品質檢查與自動回復（3 分鐘）

#### 4.1 執行服務品質檢查
```bash
echo "=== ✅ 檢查服務品質是否達標 ==="

./scripts/postcheck.sh --target edge1 --json-output | jq '.summary'
```

**會看到的檢查結果**:
```json
{
  "site": "edge1",
  "status": "PASS",
  "metrics": {
    "latency_ms": 45,
    "throughput_mbps": 120,
    "availability": 99.95
  }
}
```

#### 4.2 示範服務品質不達標時的自動回復
```bash
echo "=== 🔄 展示自動回復機制 ==="

# 模擬延遲超標的情況
./scripts/rollback.sh --dry-run --target edge1 --reason "服務品質問題: 延遲超過 100ms"
```

---

### 步驟 5: 產生成果報告（2 分鐘）

#### 5.1 產生 Summit 展示報告
```bash
echo "=== 📊 產生完整的展示報告 ==="

./scripts/package_summit_demo.sh --full-bundle --kpi-charts

# 看看產生了哪些報告檔案
ls -la artifacts/summit-bundle-latest/
```

#### 5.2 展示關鍵績效指標
```bash
# 顯示 KPI 總覽
cat artifacts/summit-bundle-latest/kpi-dashboard/PRODUCTION_KPI_SUMMARY.md | head -20
```

---

## 🎭 跟觀眾互動的橋段

### 選項 A: 讓觀眾輸入他們想要的服務
```bash
# 互動式腳本
read -p "請問您需要什麼樣的 5G 服務？(可以用中文或英文): " USER_INPUT
read -p "要部署到哪個站點？(edge1/edge2/both): " TARGET_SITE

curl -X POST http://172.16.0.78:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d "{
    \"natural_language\": \"$USER_INPUT\",
    \"target_site\": \"$TARGET_SITE\"
  }" | jq '.'
```

### 選項 B: 展示幾個實際應用場景
```bash
# 場景 1: 智慧城市的 IoT 網路
echo "場景一: 智慧城市需要大量 IoT 連線"
curl -X POST http://172.16.0.78:8888/generate_intent \
  -d '{"natural_language": "建立一個可以支援 5 萬個 IoT 裝置的網路", "target_site": "both"}' | jq

# 場景 2: 工廠自動化需要超低延遲
echo "場景二: 工業 4.0 自動化產線"
curl -X POST http://172.16.0.78:8888/generate_intent \
  -d '{"natural_language": "Deploy ultra-low latency network for factory robots", "target_site": "edge1"}' | jq
```

---

## 🆘 萬一出狀況的應對方法

### 狀況 1: LLM 服務沒有回應
```bash
# 改用本機備好的 Intent 檔案
cat tests/intent_edge1.json | jq
./scripts/demo_llm.sh --dry-run --target edge1 --use-local-intent tests/intent_edge1.json
```

### 狀況 2: GitOps 同步卡住了
```bash
# 先檢查 reconciler 的狀態
kubectl get pods -n config-management-system

# 如果需要的話，重新啟動它
kubectl rollout restart deployment reconciler-manager -n config-management-system
```

### 狀況 3: 網路斷線
```bash
# 直接展示之前跑過的結果
cat docs/DEMO_TRANSCRIPT.md
```

---

## 📊 要特別強調的效能數據

演示時記得提到這些亮點：

| 項目 | 數值 | 意義 |
|------|------|------|
| AI 處理速度 | < 20 毫秒 | 幾乎是即時回應 |
| 完成部署 | < 2 分鐘 | 從輸入到部署完成 |
| 服務可靠度 | 99.5% | 超高可靠性 |
| 問題修復 | < 30 秒 | 自動回復速度 |
| 多站點支援 | 2+ | 可以擴充更多 |
| 網路切片種類 | 3 種 | 寬頻/低延遲/大連線 |

---

## ✅ 演示前的最後確認

提前 10 分鐘跑這個檢查：
```bash
#!/bin/bash
echo "=== 🎯 Summit 演示前系統測試 ==="
echo ""
echo "[1/5] 確認 SSH 連線..."
echo "目前使用者: $(whoami)"
echo "工作目錄: $(pwd)"
echo ""
echo "[2/5] 確認 LLM 服務..."
curl -s http://172.16.0.78:8888/health | jq -r '.status' || echo "失敗"
echo ""
echo "[3/5] 確認 Kubernetes 叢集..."
kubectl get nodes --no-headers | wc -l || echo "0"
echo ""
echo "[4/5] 確認 GitOps 設定..."
kubectl get rootsync -A --no-headers 2>/dev/null | wc -l || echo "0"
echo ""
echo "[5/5] 確認演示腳本..."
[ -x "./scripts/demo_llm.sh" ] && echo "✅ 腳本已備妥" || echo "❌ 腳本不存在"
echo ""
echo "=== 檢查完畢 ==="
```

---

## 🎯 演示成功的小撇步

1. **掌握節奏**: 每個步驟都要清楚地開始和結束
2. **讓畫面漂亮**: 用 jq 讓 JSON 輸出更易讀
3. **增加互動**: 適時讓觀眾一起參與
4. **隨時有備案**: 每個指令都可以加 dry-run
5. **講重點**: 強調簡單、快速、智慧

---

**提醒**: 萬一出狀況，馬上加上 `--dry-run` 參數！

加油，一定會成功的！ 🚀