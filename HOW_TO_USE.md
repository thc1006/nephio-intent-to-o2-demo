# 🚀 如何使用 Nephio Intent-to-O2 系統

**生成時間**: 2025-09-26
**VM-1 IP**: 172.16.0.78

---

## ✅ 服務狀態確認

### 當前運行的服務

| 服務 | 端口 | 狀態 | 用途 |
|------|------|------|------|
| **Claude Headless** | 8002 | ✅ 運行中 | LLM Intent 處理器 |
| **TMF921 Adapter** | 8889 | ✅ 運行中 | TMF921 標準轉換 |
| **Gitea** | 8888 | ✅ 運行中 | GitOps Repository |
| **Prometheus** | 9090 | ✅ 運行中 | Metrics 監控 |
| **Grafana** | 3000 | ✅ 運行中 | 可視化儀表板 |

### 快速驗證指令

```bash
# 檢查所有服務
curl -s http://localhost:8002/health | jq .
curl -s http://localhost:8889/health | jq .
curl -s http://localhost:8888/api/v1/version | jq .
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:3000/api/health | jq .
```

---

## 📝 方法一：Web UI（最簡單）

### 1. Claude Headless Web UI

**訪問地址**: http://172.16.0.78:8002/

這是最直觀的方式，提供：
- 自然語言輸入框
- 目標站點選擇器（edge1/edge2/both）
- 快速範例按鈕
- 即時 Intent 生成結果

**使用步驟**：

1. 開啟瀏覽器訪問 http://172.16.0.78:8002/
2. 在文字框輸入自然語言，例如：
   ```
   部署 5G 高頻寬服務到 edge1，頻寬 200Mbps
   ```
3. 選擇目標站點：edge1 / edge2 / both
4. 點擊 "Generate TMF921 Intent" 按鈕
5. 查看生成的 JSON Intent

### 2. TMF921 Adapter Web UI

**訪問地址**: http://172.16.0.78:8889/

提供：
- 完整的 TMF921 標準介面
- 重試機制監控
- Metrics 查看
- 更詳細的配置選項

---

## 📝 方法二：REST API（程式化）

### Claude Headless API

```bash
# 基本 Intent 生成
curl -X POST http://172.16.0.78:8002/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{
    "text": "部署 eMBB 服務到 edge1，頻寬 200Mbps",
    "target_sites": ["edge01"]
  }' | jq .

# 批次 Intent 生成
curl -X POST http://172.16.0.78:8002/api/v1/intent/batch \
  -H "Content-Type: application/json" \
  -d '[
    {"text": "部署 eMBB 到 edge1", "target_sites": ["edge01"]},
    {"text": "部署 URLLC 到 edge2", "target_sites": ["edge02"]}
  ]' | jq .

# 健康檢查
curl -s http://172.16.0.78:8002/health | jq .
```

### TMF921 Adapter API

```bash
# 生成 TMF921 Intent
curl -X POST http://172.16.0.78:8889/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "Deploy 5G network slice with low latency",
    "target_site": "edge1"
  }' | jq .

# 查看 Metrics
curl -s http://172.16.0.78:8889/metrics | jq .

# Mock SLO 端點（測試用）
curl -s http://172.16.0.78:8889/mock/slo | jq .
```

---

## 📝 方法三：WebSocket（即時監控）

```javascript
// 連接 WebSocket
const ws = new WebSocket('ws://172.16.0.78:8002/ws');

ws.onopen = function() {
    console.log('WebSocket connected');

    // 發送 Intent 請求
    ws.send(JSON.stringify({
        type: 'intent',
        text: '部署 eMBB 到 edge1',
        context: {}
    }));
};

ws.onmessage = function(event) {
    const data = JSON.parse(event.data);
    console.log('Received:', data);

    // 處理不同階段的更新
    if (data.stage === 'claude_processing') {
        console.log('Claude 正在處理...');
    } else if (data.stage === 'intent_generated') {
        console.log('Intent 已生成:', data.result);
    }
};
```

---

## 📝 方法四：完整 Demo 腳本（端到端）

### 快速 Demo

```bash
# 進入專案目錄
cd /home/ubuntu/nephio-intent-to-o2-demo

# 載入環境變數
source scripts/env.sh

# 執行快速 demo（5分鐘內完成）
./scripts/demo_quick.sh
```

### 完整 LLM Demo

```bash
# 完整的端到端 demo（包含所有步驟）
./scripts/demo_llm.sh

# 步驟包括：
# 1. 環境驗證
# 2. Intent 生成（呼叫 Claude）
# 3. KRM 渲染（kpt functions）
# 4. GitOps 推送
# 5. Edge 部署
# 6. SLO 驗證
# 7. 報告生成
```

### 指定目標站點

```bash
# 只部署到 edge1
./scripts/demo_llm.sh --target edge1

# 只部署到 edge2
./scripts/demo_llm.sh --target edge2

# 部署到所有站點
./scripts/demo_llm.sh --target both
```

### Summit Demo

```bash
# 執行 Summit 示範流程
make -f Makefile.summit summit

# 包括：
# - Edge-1 Analytics 部署
# - Edge-2 ML Inference 部署
# - 聯邦學習部署（兩站點）
# - KPI 測試
# - 報告生成
```

---

## 📊 監控介面

### 1. Prometheus（Metrics）

**訪問地址**: http://172.16.0.78:9090

**常用查詢**：

```promql
# Intent 處理率
rate(intent_total[5m])

# Intent 成功率
rate(intent_total{status="success"}[5m]) / rate(intent_total[5m])

# 部署延遲（P95）
histogram_quantile(0.95, rate(deployment_duration_seconds_bucket[5m]))

# Edge 站點健康狀態
up{job="edge-services"}

# SLO Metrics
latency_p95_ms
success_rate
throughput_rps
```

### 2. Grafana（可視化）

**訪問地址**: http://172.16.0.78:3000

**預設帳號**:
- 用戶名: `admin`
- 密碼: `admin` （首次登入會要求修改）

**主要 Dashboard**:
- Intent-to-O2 Pipeline Overview
- Edge Site Health
- SLO Compliance
- GitOps Sync Status

### 3. 即時監控腳本

```bash
# 視覺化監控
./scripts/visual_monitor.sh

# 互動式監控
./scripts/visual_monitor_interactive.sh

# 狀態條監控
./scripts/status_bar.sh
```

---

## 🗂️ Gitea（GitOps Repository）

### 訪問資訊

**Web UI**: http://172.16.0.78:8888

**登入憑證**:
- 用戶名: `gitea_admin`
- 密碼: `r8sA8CPHD9!bt6d`

### 主要 Repository

1. **nephio/deployments** - 主要部署配置
   - `clusters/edge01/` - Edge1 配置
   - `clusters/edge02/` - Edge2 配置

2. **nephio/o2ims** - O2IMS 相關配置

### 查看部署歷史

```bash
# Clone repository
git clone http://gitea_admin:r8sA8CPHD9!bt6d@172.16.0.78:8888/nephio/deployments.git

cd deployments

# 查看 commit 歷史
git log --oneline --graph --all

# 查看特定 Intent 的變更
git log --grep="intent_" --oneline

# 查看 edge1 的變更
git log --oneline -- clusters/edge01/
```

### API 操作

```bash
# 獲取 Repository 列表
curl -u "gitea_admin:r8sA8CPHD9!bt6d" \
  http://172.16.0.78:8888/api/v1/user/repos | jq .

# 查看最新 commit
curl -u "gitea_admin:r8sA8CPHD9!bt6d" \
  http://172.16.0.78:8888/api/v1/repos/nephio/deployments/commits | jq .
```

---

## 🔍 監控部署狀態

### 查看 GitOps 同步狀態

```bash
# 查看 Config Sync 狀態（需要 kubeconfig）
export KUBECONFIG=~/.kube/edge1.config
kubectl get rootsync -n config-management-system

# 查看同步日誌
kubectl logs -n config-management-system \
  -l app=reconciler --tail=50 -f
```

### 查看部署狀態

```bash
# Edge1 部署
kubectl --context=edge1 get deployments -A

# Edge2 部署
kubectl --context=edge2 get deployments -A

# 查看 O2IMS 狀態
curl -s http://172.16.4.45:31280/o2ims-infrastructureInventory/v1/deploymentManagers | jq .
```

### 查看 SLO Metrics

```bash
# 執行 postcheck
./scripts/postcheck.sh --site edge1

# 查看結果
cat artifacts/postcheck/postcheck.json | jq .

# 查看 SLO verdict
cat artifacts/postcheck/slo_verdict.txt
```

---

## 🎯 自然語言範例

### 中文範例

```
1. 部署 5G 高頻寬服務到 edge1，頻寬 200Mbps，延遲 30ms
2. 在 edge2 上配置超低延遲服務，延遲小於 1ms
3. 部署 IoT 監控服務到所有邊緣站點
4. 建立視頻串流 CDN 跨兩個邊緣站點
5. 部署機器學習推理服務到 edge2
```

### 英文範例

```
1. Deploy eMBB slice on edge1 with 200Mbps bandwidth
2. Configure URLLC service at edge2 with 1ms latency
3. Setup mMTC for IoT monitoring across all edges
4. Deploy video streaming CDN to both sites
5. Create federated learning infrastructure on edge1 and edge2
```

### 技術範例

```
1. Deploy network slice SST=1 SD=000001 on edge01 with 200Mbps DL
2. Configure O-RAN CU/DU on edge2 with F1 interface
3. Setup Prometheus monitoring with remote_write to central VM
4. Deploy Flagger canary with 10% traffic split
5. Configure O2IMS deployment manager on edge1
```

---

## 🔄 常見工作流程

### Workflow 1: 基本 Intent 部署

```bash
# 1. 生成 Intent
curl -X POST http://localhost:8002/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"text": "部署 eMBB 到 edge1", "target_sites": ["edge01"]}' \
  | jq . > intent.json

# 2. 查看生成的 Intent
cat intent.json | jq .

# 3. 執行完整部署
./scripts/demo_llm.sh --intent-file intent.json

# 4. 監控部署
watch -n 5 'kubectl --context=edge1 get pods -A'

# 5. 驗證 SLO
./scripts/postcheck.sh --site edge1
```

### Workflow 2: 多站點部署

```bash
# 1. 生成多站點 Intent
curl -X POST http://localhost:8002/api/v1/intent \
  -H "Content-Type: application/json" \
  -d '{"text": "部署到所有邊緣", "target_sites": ["edge01", "edge02"]}' \
  | jq . > multisite-intent.json

# 2. 執行部署
./scripts/demo_multisite.sh

# 3. 並行監控
tmux new-session -d -s monitor
tmux split-window -h
tmux select-pane -t 0
tmux send-keys "watch kubectl --context=edge1 get pods -A" C-m
tmux select-pane -t 1
tmux send-keys "watch kubectl --context=edge2 get pods -A" C-m
tmux attach -t monitor
```

### Workflow 3: 測試與驗證

```bash
# 1. 運行黃金測試
cd tests/
pytest test_golden.py -v

# 2. 運行合約測試
pytest test_acc18_contract_test.py -v

# 3. 運行 SLO 測試
pytest test_acc13_slo.py -v

# 4. 生成測試報告
pytest --html=report.html --self-contained-html
```

### Workflow 4: 故障注入與恢復

```bash
# 1. 注入高延遲故障
./scripts/inject_fault.sh edge1 high_latency

# 2. 監控 SLO 違規
./scripts/postcheck.sh --site edge1
# 預期：SLO FAILED

# 3. 觸發自動 rollback
./scripts/rollback.sh edge1

# 4. 驗證恢復
./scripts/postcheck.sh --site edge1
# 預期：SLO PASSED

# 5. 查看 rollback 報告
cat artifacts/demo-rollback/rollback-audit-report.json | jq .
```

---

## 📦 產出與報告

### 自動生成的產出

每次執行 demo 後，會在以下目錄生成產出：

```
artifacts/
└── <timestamp>/
    ├── intent.json           # 生成的 Intent
    ├── krm/                  # 渲染的 KRM YAML
    ├── postcheck.json        # SLO 驗證結果
    └── deployment-state.json # 部署狀態快照

reports/
└── <timestamp>/
    ├── index.html            # HTML 報告
    ├── manifest.json         # 元數據清單
    ├── checksums.txt         # SHA256 校驗和
    ├── kpi-results.json      # KPI 結果
    └── executive_summary.md  # 執行摘要
```

### 查看最新報告

```bash
# 列出所有報告
ls -lt reports/

# 查看最新報告
LATEST=$(ls -t reports/ | head -1)
cat reports/$LATEST/executive_summary.md

# 開啟 HTML 報告
open reports/$LATEST/index.html  # macOS
xdg-open reports/$LATEST/index.html  # Linux
```

---

## 🆘 故障排除

### 問題 1: Claude 服務無響應

```bash
# 檢查 Claude 服務
ps aux | grep claude_headless

# 重啟服務
pkill -f claude_headless
cd services/
nohup python3 claude_headless.py > /tmp/claude.log 2>&1 &

# 查看日誌
tail -f /tmp/claude.log
```

### 問題 2: Adapter 端口衝突

```bash
# 找到佔用端口的進程
lsof -i :8889

# 停止舊進程
kill -9 <PID>

# 啟動新進程
cd adapter/
nohup python3 -m app.main > /tmp/adapter.log 2>&1 &
```

### 問題 3: Gitea 無法訪問

```bash
# 檢查 Docker 容器
docker ps | grep gitea

# 重啟 Gitea
docker restart gitea

# 查看日誌
docker logs gitea --tail=50 -f
```

### 問題 4: GitOps 同步失敗

```bash
# 檢查 RootSync 狀態
kubectl get rootsync -n config-management-system -o yaml

# 強制重新同步
kubectl annotate rootsync root-sync \
  -n config-management-system \
  configsync.gke.io/force-sync="$(date +%s)" \
  --overwrite

# 查看 reconciler 日誌
kubectl logs -n config-management-system \
  -l app=reconciler --tail=100 -f
```

---

## 🎓 進階使用

### 自定義 Intent Template

```bash
# 建立自定義 Intent
cat > my-intent.json <<EOF
{
  "intentId": "custom-$(date +%s)",
  "service": {
    "type": "eMBB",
    "name": "My Custom Service"
  },
  "targetSite": "edge1",
  "qos": {
    "dl_mbps": 500,
    "ul_mbps": 250,
    "latency_ms": 20
  },
  "slice": {
    "sst": 1,
    "sd": "000001"
  }
}
EOF

# 直接使用自定義 Intent
./scripts/demo_llm.sh --intent-file my-intent.json
```

### 配置 SLO 閾值

```bash
# 編輯 SLO 配置
vim config/slo-thresholds.yaml

# 範例配置
cat config/slo-thresholds.yaml
# latency_p95_ms: 50
# success_rate: 0.99
# throughput_mbps: 180

# 重新載入配置
source scripts/env.sh
```

### 批次部署

```bash
# 建立批次 Intent
cat > batch-intents.json <<EOF
[
  {"text": "部署 eMBB 到 edge1", "target_sites": ["edge01"]},
  {"text": "部署 URLLC 到 edge2", "target_sites": ["edge02"]},
  {"text": "部署 mMTC 到所有站點", "target_sites": ["edge01", "edge02"]}
]
EOF

# 執行批次部署
curl -X POST http://localhost:8002/api/v1/intent/batch \
  -H "Content-Type: application/json" \
  -d @batch-intents.json | jq .
```

---

## 📚 參考資源

### 文檔

- `PROJECT_COMPREHENSIVE_UNDERSTANDING.md` - 完整專案理解
- `ARCHITECTURE_SIMPLIFIED.md` - 簡化架構
- `SUMMIT_DEMO_GUIDE.md` - Summit 演示指南
- `SUMMIT_DEMO_RUNBOOK.md` - 執行手冊
- [TROUBLESHOOTING.md](docs/operations/TROUBLESHOOTING.md) - 故障排除

### 腳本

- `scripts/demo_llm.sh` - 主 Demo 腳本
- `scripts/demo_quick.sh` - 快速 Demo
- `scripts/postcheck.sh` - SLO 驗證
- `scripts/rollback.sh` - Rollback 執行
- `scripts/visual_monitor.sh` - 視覺化監控

### API 文檔

- Claude Headless: http://172.16.0.78:8002/docs
- TMF921 Adapter: http://172.16.0.78:8889/docs

---

## 🎯 快速開始清單

使用本系統前，請確認：

- [ ] 所有服務運行正常（curl health endpoints）
- [ ] 可以訪問 Gitea（http://172.16.0.78:8888）
- [ ] 可以訪問 Grafana（http://172.16.0.78:3000）
- [ ] kubeconfig 已配置（edge1 和 edge2）
- [ ] 環境變數已載入（source scripts/env.sh）

**您已準備好開始使用！** 🚀

---

**最後更新**: 2025-09-26
**版本**: v1.1.1
**維護者**: @orchestrator