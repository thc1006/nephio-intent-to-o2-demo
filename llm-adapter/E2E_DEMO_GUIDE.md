# 📚 Nephio Intent-to-O2 端對端演示教學指南

## 目錄
1. [系統架構總覽](#系統架構總覽)
2. [VM-3 Web UI 操作指南](#vm-3-web-ui-操作指南)
3. [VM-1 整合操作流程](#vm-1-整合操作流程)
4. [端對端演示腳本](#端對端演示腳本)
5. [實際案例演練](#實際案例演練)
6. [故障排除](#故障排除)

---

## 🏗️ 系統架構總覽

```
┌─────────────────┐     HTTP/REST      ┌──────────────────┐
│                 │  ────────────────►  │                  │
│     VM-1        │                     │      VM-3        │
│  (Intent CLI)   │  ◄────────────────  │  (LLM Adapter)   │
│                 │     JSON Response   │                  │
└─────────────────┘                     └──────────────────┘
        │                                        │
        │                                        │
        ▼                                        ▼
   GitOps Pipeline                         Claude CLI
   O2IMS Integration                       NLP Processing
```

### 關鍵組件
- **VM-1**: Intent 管理介面，發送自然語言請求
- **VM-3**: LLM Adapter 服務，解析意圖為結構化數據
- **Port**: 8888
- **Protocol**: HTTP REST API

---

## 🖥️ VM-3 Web UI 操作指南

### 1. 訪問 Web UI

在 VM-3 本機或可訪問 VM-3 的瀏覽器中：

```bash
# 本機訪問
http://127.0.0.1:8888/

# 從其他機器訪問
http://172.16.2.10:8888/
```

### 2. Web UI 介面說明

![UI Components]
```
┌────────────────────────────────────────────┐
│  🚀 LLM Intent Adapter Service             │
│                                            │
│  Status: Online | Mode: claude-cli  🟢     │
│                                            │
│  ┌────────────────────────────────────┐   │
│  │ Enter Natural Language Request:     │   │
│  │ [________________________]          │   │
│  └────────────────────────────────────┘   │
│                                            │
│  [Generate Intent] [Parse Intent (v1)]     │
│                                            │
│  Output:                                   │
│  ┌────────────────────────────────────┐   │
│  │ {JSON Response will appear here}    │   │
│  └────────────────────────────────────┘   │
│                                            │
│  📝 Example Requests (Click to use)        │
└────────────────────────────────────────────┘
```

### 3. Web UI 操作步驟

#### Step 1: 檢查服務狀態
- 頁面頂部顯示 `Mode: claude-cli` 表示 Claude 整合啟用
- 若顯示 `Mode: rule-based` 表示使用規則解析

#### Step 2: 輸入自然語言請求
在文字框中輸入網路意圖，例如：
```
Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency
```

#### Step 3: 選擇端點
- **Generate Intent (Legacy)**: 使用 `/generate_intent` 端點
- **Parse Intent (API v1)**: 使用 `/api/v1/intent/parse` 端點（推薦）

#### Step 4: 查看結果
JSON 格式的解析結果會顯示在 Output 區域：
```json
{
  "intent": {
    "service": "eMBB",
    "location": "edge1",
    "qos": {
      "downlink_mbps": 200,
      "uplink_mbps": null,
      "latency_ms": 30
    }
  },
  "raw_text": "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency",
  "model": "claude-cli",
  "version": "1.0.0"
}
```

### 4. 快速測試範例

點擊頁面上的範例請求，自動填入測試文字：

- **eMBB 範例**: Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency
- **URLLC 範例**: Create URLLC service in edge2 with 10ms latency and 100Mbps downlink
- **mMTC 範例**: Setup mMTC network in zone3 for IoT devices with 50Mbps capacity

---

## 🔗 VM-1 整合操作流程

### 1. VM-1 基本設置

在 VM-1 上建立整合腳本：

```bash
# 建立工作目錄
mkdir -p ~/nephio-intent-demo
cd ~/nephio-intent-demo

# 建立 Python 客戶端
cat > llm_client.py << 'EOF'
#!/usr/bin/env python3
import requests
import json
import sys

class IntentClient:
    def __init__(self, base_url="http://172.16.2.10:8888"):
        self.base_url = base_url
        
    def parse_intent(self, text):
        """將自然語言轉換為結構化意圖"""
        try:
            response = requests.post(
                f"{self.base_url}/api/v1/intent/parse",
                json={"text": text},
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error: {e}")
            return None
    
    def health_check(self):
        """檢查服務健康狀態"""
        try:
            response = requests.get(f"{self.base_url}/health")
            return response.json()
        except Exception as e:
            return {"error": str(e)}

# 主程式
if __name__ == "__main__":
    client = IntentClient()
    
    # 檢查服務
    health = client.health_check()
    print(f"Service Status: {health.get('status', 'unknown')}")
    print(f"LLM Mode: {health.get('llm_mode', 'unknown')}")
    
    # 解析意圖
    if len(sys.argv) > 1:
        text = " ".join(sys.argv[1:])
        result = client.parse_intent(text)
        if result:
            print(json.dumps(result, indent=2))
EOF

chmod +x llm_client.py
```

### 2. VM-1 Shell 腳本

建立便利的 Shell 腳本：

```bash
cat > intent_parser.sh << 'EOF'
#!/bin/bash

# 配置
LLM_ADAPTER_URL="http://172.16.2.10:8888"

# 函數：解析意圖
parse_intent() {
    local text="$1"
    curl -s -X POST "${LLM_ADAPTER_URL}/api/v1/intent/parse" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${text}\"}" | jq .
}

# 函數：健康檢查
check_health() {
    curl -s "${LLM_ADAPTER_URL}/health" | jq .
}

# 主程式
case "$1" in
    health)
        check_health
        ;;
    parse)
        shift
        parse_intent "$*"
        ;;
    *)
        echo "Usage: $0 {health|parse <text>}"
        exit 1
        ;;
esac
EOF

chmod +x intent_parser.sh
```

### 3. VM-1 操作命令

```bash
# 健康檢查
./intent_parser.sh health

# 解析意圖
./intent_parser.sh parse "Deploy eMBB slice with 500Mbps in edge1"

# 使用 Python 客戶端
python3 llm_client.py "Create URLLC service with 1ms latency"
```

---

## 🎬 端對端演示腳本

### 演示場景：5G 網路切片部署

#### 場景 1：eMBB 高頻寬服務部署

**步驟 1**: VM-1 發送請求
```bash
# VM-1 執行
./intent_parser.sh parse "Deploy enhanced mobile broadband slice in edge datacenter 1 with 1Gbps downlink and 500Mbps uplink for video streaming services"
```

**步驟 2**: VM-3 處理並回應
```json
{
  "intent": {
    "service": "eMBB",
    "location": "edge1",
    "qos": {
      "downlink_mbps": 1000,
      "uplink_mbps": 500,
      "latency_ms": null
    }
  },
  "raw_text": "Deploy enhanced mobile broadband slice...",
  "model": "claude-cli",
  "version": "1.0.0"
}
```

**步驟 3**: VM-1 處理結構化數據
```bash
# VM-1 提取並使用數據
SERVICE=$(echo $RESPONSE | jq -r '.intent.service')
LOCATION=$(echo $RESPONSE | jq -r '.intent.location')
DL_MBPS=$(echo $RESPONSE | jq -r '.intent.qos.downlink_mbps')

echo "Deploying $SERVICE at $LOCATION with ${DL_MBPS}Mbps downlink"
# 觸發 GitOps pipeline...
```

#### 場景 2：URLLC 低延遲服務部署

**VM-1 請求**:
```bash
./intent_parser.sh parse "Create ultra-reliable low latency service for autonomous vehicle control in zone 2 with maximum 1ms latency"
```

**預期回應**:
```json
{
  "intent": {
    "service": "URLLC",
    "location": "zone2",
    "qos": {
      "downlink_mbps": null,
      "uplink_mbps": null,
      "latency_ms": 1
    }
  }
}
```

#### 場景 3：mMTC IoT 服務部署

**VM-1 請求**:
```bash
./intent_parser.sh parse "Setup massive IoT network for smart city sensors in downtown area supporting 1 million devices"
```

**預期回應**:
```json
{
  "intent": {
    "service": "mMTC",
    "location": "zone1",
    "qos": {
      "downlink_mbps": 1,
      "uplink_mbps": 1,
      "latency_ms": 1000
    }
  }
}
```

---

## 🔬 實際案例演練

### 完整 E2E 流程範例

#### 1. 準備階段（VM-3）

```bash
# 確認服務狀態
sudo systemctl status llm-adapter

# 查看即時日誌
sudo journalctl -u llm-adapter -f
```

#### 2. 測試階段（VM-1）

```bash
# 步驟 1: 健康檢查
curl -s http://172.16.2.10:8888/health | jq .

# 步驟 2: 簡單測試
curl -s -X POST http://172.16.2.10:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Test deployment"}' | jq .

# 步驟 3: 複雜請求
TEXT="Deploy a 5G network slice for emergency services with ultra-low latency under 5ms, high reliability 99.999%, covering the entire metropolitan area including edge1, edge2, and core network with automatic failover capabilities"

curl -s -X POST http://172.16.2.10:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"$TEXT\"}" | jq .
```

#### 3. 批次處理範例（VM-1）

```bash
# 建立批次請求檔案
cat > batch_intents.txt << 'EOF'
Deploy eMBB slice in edge1 with 500Mbps
Create URLLC service in edge2 with 5ms latency
Setup mMTC network in zone3 for 100000 IoT devices
Provision network slice for AR/VR with 1Gbps and 10ms latency
Configure emergency services with 99.999% availability
EOF

# 批次處理腳本
while IFS= read -r line; do
    echo "Processing: $line"
    ./intent_parser.sh parse "$line"
    echo "---"
    sleep 2
done < batch_intents.txt
```

### Web UI 協同演示

#### VM-3 Web UI 監控
1. 開啟瀏覽器訪問 `http://127.0.0.1:8888/`
2. 觀察 Mode 指示器（應顯示 `claude-cli`）

#### VM-1 發送請求
```bash
# 同時在 VM-3 Web UI 觀察
for i in {1..3}; do
    ./intent_parser.sh parse "Test request $i: Deploy service in edge$i"
    sleep 3
done
```

#### 即時監控
VM-3 上開啟監控：
```bash
# Terminal 1: 服務日誌
sudo journalctl -u llm-adapter -f

# Terminal 2: 連接監控
watch -n 1 'ss -tn | grep :8888'
```

---

## 🛠️ 故障排除

### 常見問題與解決方案

#### 問題 1：連接超時
```bash
# VM-1 檢查網路
ping -c 2 172.16.2.10

# VM-3 檢查服務
sudo systemctl status llm-adapter
sudo lsof -i :8888
```

#### 問題 2：JSON 解析錯誤
```bash
# 檢查請求格式
echo '{"text": "test"}' | jq .

# 驗證回應
curl -s http://172.16.2.10:8888/health | jq type
```

#### 問題 3：Claude CLI 失敗
```bash
# VM-3 檢查 Claude 狀態
claude --version

# 查看錯誤日誌
sudo journalctl -u llm-adapter | grep -i error | tail -20

# 切換到 rule-based（臨時）
sudo systemctl stop llm-adapter
unset CLAUDE_CLI
sudo systemctl start llm-adapter
```

### 效能優化建議

#### VM-1 端優化
```python
# 使用連接池
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

session = requests.Session()
retry = Retry(total=3, backoff_factor=0.3)
adapter = HTTPAdapter(max_retries=retry)
session.mount('http://', adapter)
```

#### VM-3 端優化
```bash
# 增加 workers（如需要）
sudo vi /etc/systemd/system/llm-adapter.service
# 修改: --workers 2

sudo systemctl daemon-reload
sudo systemctl restart llm-adapter
```

---

## 📊 監控與維護

### 建立監控 Dashboard

```bash
# VM-3 建立監控腳本
cat > monitor_dashboard.sh << 'EOF'
#!/bin/bash
while true; do
    clear
    echo "=== LLM Adapter Monitor Dashboard ==="
    echo "Time: $(date)"
    echo ""
    echo "Service Status:"
    systemctl is-active llm-adapter
    echo ""
    echo "Recent Requests (last 5):"
    sudo journalctl -u llm-adapter -n 5 --no-pager | grep -E "POST|GET"
    echo ""
    echo "Active Connections:"
    ss -tn | grep :8888
    echo ""
    echo "CPU & Memory:"
    ps aux | grep uvicorn | grep -v grep | awk '{print "CPU: "$3"% MEM: "$4"%"}'
    sleep 5
done
EOF

chmod +x monitor_dashboard.sh
```

### 定期健康檢查

```bash
# Crontab 設置（VM-1）
*/5 * * * * curl -s http://172.16.2.10:8888/health | jq -e '.status == "healthy"' || echo "LLM Adapter unhealthy" | mail -s "Alert" admin@example.com
```

---

## 🎯 最佳實踐

### 1. 請求格式建議
- 使用明確的服務類型關鍵字（eMBB, URLLC, mMTC）
- 包含具體的 QoS 參數（Mbps, ms）
- 指定位置（edge1, zone1, core1）

### 2. 錯誤處理
- 實作重試邏輯
- 設置合理的超時（30秒）
- 記錄所有請求和回應

### 3. 安全考量
- 僅在內部網路使用
- 考慮添加認證機制
- 定期更新依賴套件

---

## 📚 附錄

### A. API 規格摘要

| 端點 | 方法 | 用途 |
|------|------|------|
| `/health` | GET | 健康檢查 |
| `/api/v1/intent/parse` | POST | 解析意圖（推薦） |
| `/generate_intent` | POST | 解析意圖（舊版） |
| `/docs` | GET | API 文檔 |
| `/` | GET | Web UI |

### B. 支援的服務類型

| 服務 | 描述 | 典型 QoS |
|------|------|----------|
| eMBB | 增強移動寬頻 | 高頻寬 (>100Mbps) |
| URLLC | 超可靠低延遲 | 低延遲 (<10ms) |
| mMTC | 大規模機器通信 | 高連接數 |

### C. 快速參考命令

```bash
# VM-3 服務管理
sudo systemctl {start|stop|restart|status} llm-adapter
sudo journalctl -u llm-adapter -f

# VM-1 測試命令
curl -s http://172.16.2.10:8888/health | jq .
curl -X POST http://172.16.2.10:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "YOUR_REQUEST"}' | jq .
```

---

## 🏁 結語

本指南涵蓋了 Nephio Intent-to-O2 系統的完整端對端操作流程。透過 VM-3 的 LLM Adapter 服務，VM-1 可以將自然語言的網路意圖轉換為結構化的 JSON 數據，進而驅動自動化的網路配置流程。

系統的關鍵優勢：
- 🚀 自然語言介面，降低操作門檻
- 🤖 Claude AI 整合，智能意圖解析  
- 📊 統一 API 格式，易於整合
- 🔧 完整運維工具，便於管理

如有問題，請參考故障排除章節或查看服務日誌。

---
*最後更新：2025-09-12*
*版本：1.0.0*