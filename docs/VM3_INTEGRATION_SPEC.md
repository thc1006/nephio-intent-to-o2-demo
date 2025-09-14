# VM-3 LLM Adapter 整合規格文件

## 目的
本文件定義 VM-1 (GitOps Orchestrator) 與 VM-3 (LLM Adapter) 的整合介面規格。

## VM-3 需要實現的 API 端點

### 1. 健康檢查端點 ✅ (已實現)
```
GET http://192.168.0.201:8888/health

預期回應:
{
    "status": "healthy",
    "service": "LLM Intent Adapter",
    "version": "1.0.0",
    "llm_mode": "rule-based" | "claude-cli" | "openai"
}
```

### 2. Intent 生成端點（主要）
```
POST http://192.168.0.201:8888/generate_intent
Content-Type: application/json

請求體:
{
    "natural_language": "Deploy eMBB slice in edge1 with 100Mbps throughput",
    "target_site": "edge1" | "edge2" | "both",
    "metadata": {
        "execution_id": "20250914_120515_698845",
        "timestamp": "2025-09-14T12:05:15Z",
        "source": "VM-1-orchestrator"
    }
}

預期回應 (TMF921 格式):
{
    "intentId": "intent-12345-edge1",
    "intentName": "eMBB Service Deployment",
    "intentType": "NETWORK_SLICE_INTENT",
    "intentState": "CREATED",
    "intentPriority": 5,
    "targetSite": "edge1",
    "serviceType": "enhanced-mobile-broadband",
    "intentExpectationId": "exp-001",
    "intentExpectationType": "SERVICE_EXPECTATION",
    "intentParameters": {
        "serviceType": "eMBB",
        "location": "edge1",
        "qosParameters": {
            "downlinkMbps": 100,
            "uplinkMbps": 50,
            "latencyMs": 10,
            "reliability": 99.9
        },
        "resourceProfile": "standard",
        "sliceType": "eMBB"
    },
    "sla": {
        "availability": 99.9,
        "latency": 10,
        "throughput": 100,
        "connections": 1000
    },
    "intentMetadata": {
        "createdAt": "2025-01-14T10:00:00Z",
        "createdBy": "LLM-Adapter",
        "version": "1.0",
        "originalRequest": "Deploy eMBB slice in edge1 with 100Mbps throughput"
    }
}
```

### 3. Intent 解析端點（備用）
```
POST http://192.168.0.201:8888/api/v1/intent/parse
Content-Type: application/json

請求體:
{
    "natural_language": "Create URLLC service for autonomous vehicles with 1ms latency",
    "context": {
        "target": "edge2",
        "priority": "high"
    }
}

預期回應: (同上 TMF921 格式)
```

## 支援的服務類型

VM-3 應該能夠識別並處理以下服務類型的自然語言描述：

### 1. eMBB (Enhanced Mobile Broadband)
**關鍵詞**: "高頻寬", "broadband", "streaming", "video", "高速下載"
```json
{
    "serviceType": "enhanced-mobile-broadband",
    "sliceType": "eMBB",
    "defaultQoS": {
        "downlinkMbps": 1000,
        "uplinkMbps": 100,
        "latencyMs": 50
    }
}
```

### 2. URLLC (Ultra-Reliable Low-Latency)
**關鍵詞**: "低延遲", "ultra-reliable", "autonomous", "industrial", "車聯網"
```json
{
    "serviceType": "ultra-reliable-low-latency",
    "sliceType": "URLLC",
    "defaultQoS": {
        "downlinkMbps": 100,
        "uplinkMbps": 50,
        "latencyMs": 1,
        "reliability": 99.999
    }
}
```

### 3. mMTC (Massive Machine-Type Communications)
**關鍵詞**: "IoT", "感測器", "massive", "smart city", "智慧城市"
```json
{
    "serviceType": "massive-machine-type",
    "sliceType": "mMTC",
    "defaultQoS": {
        "connections": 50000,
        "downlinkMbps": 10,
        "uplinkMbps": 5
    }
}
```

## 站點路由邏輯

VM-3 需要根據自然語言中的位置資訊決定 targetSite：

| 自然語言關鍵詞 | targetSite 值 |
|--------------|-------------|
| "edge1", "第一站點", "主站" | "edge1" |
| "edge2", "第二站點", "備援站" | "edge2" |
| "both", "兩個站點", "多站點", "distributed" | "both" |
| （未指定） | "edge1" (預設) |

## 錯誤處理

當無法處理請求時，VM-3 應返回標準錯誤格式：

```json
{
    "error": {
        "code": "INTENT_PARSE_ERROR",
        "message": "Unable to parse natural language input",
        "details": "Unrecognized service type in input",
        "timestamp": "2025-01-14T10:00:00Z"
    }
}
```

## 測試案例

### 測試案例 1: eMBB 部署
```bash
curl -X POST http://192.168.0.201:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "Deploy eMBB slice at edge1 with 1Gbps downlink for video streaming",
    "target_site": "edge1"
  }'
```

### 測試案例 2: URLLC 部署
```bash
curl -X POST http://192.168.0.201:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "Create ultra-reliable service for autonomous vehicles at edge2 with 1ms latency",
    "target_site": "edge2"
  }'
```

### 測試案例 3: mMTC 多站點部署
```bash
curl -X POST http://192.168.0.201:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language": "Setup IoT network for 50000 sensors across both sites",
    "target_site": "both"
  }'
```

## 驗證檢查清單

VM-3 實現應通過以下檢查：

- [ ] 健康檢查端點返回 200 OK
- [ ] generate_intent 端點接受 POST 請求
- [ ] 回應包含所有必要的 TMF921 欄位
- [ ] intentId 是唯一的
- [ ] targetSite 正確對應到請求
- [ ] serviceType 正確識別（eMBB/URLLC/mMTC）
- [ ] QoS 參數合理設置
- [ ] 錯誤情況返回適當的錯誤碼
- [ ] 回應時間 < 5 秒

## 整合測試腳本

VM-1 提供的測試腳本位置：
```bash
/home/ubuntu/nephio-intent-to-o2-demo/scripts/test_llm_integration.sh
```

執行方式：
```bash
export LLM_ADAPTER_URL=http://192.168.0.201:8888
./scripts/test_llm_integration.sh
```

## 聯絡資訊

- VM-1 團隊：GitOps Orchestrator
- VM-3 團隊：LLM Adapter Service
- 整合文件：本文件
- 測試結果：/reports/llm-integration-test/

---
文件版本：v1.0
最後更新：2025-09-14