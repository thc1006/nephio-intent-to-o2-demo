# LLM Adapter Demo Guide

## Quick Start

```bash
# Run the interactive demo
cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter
./demo.sh
```

## Demo Script Features

### Interactive Menu
- **Numbered Options (1-8)**: Pre-configured demo scenarios
- **C**: Custom input - enter your own natural language request
- **B**: Batch test - runs multiple scenarios automatically
- **L**: View logs from current session
- **H**: Health check
- **Q**: Quit

### Pre-configured Scenarios

| Option | Service | Language | Description |
|--------|---------|----------|-------------|
| 1 | eMBB | English | Enhanced Mobile Broadband at edge1 |
| 2 | eMBB | 中文 | 增強型移動寬頻在edge1 |
| 3 | URLLC | English | Ultra-Reliable Low Latency at edge2 |
| 4 | URLLC | 中文 | 超可靠低延遲在edge2 |
| 5 | mMTC | English | Massive Machine Type across both edges |
| 6 | mMTC | 中文 | 大規模機器類型跨兩個邊緣 |
| 7 | Complex | English | Advanced AR/VR use case |
| 8 | API v1 | English | Test standard API endpoint |

## Manual Testing (Without Script)

### 1. Check Service Status
```bash
curl http://localhost:8888/health | jq .
```

### 2. Test eMBB Service
```bash
curl -X POST http://localhost:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"text": "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency"}' | jq .
```

### 3. Test URLLC Service
```bash
curl -X POST http://localhost:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"text": "Create URLLC service in edge2 with 10ms latency"}' | jq .
```

### 4. Test mMTC Service
```bash
curl -X POST http://localhost:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"text": "Setup mMTC network for IoT devices"}' | jq .
```

### 5. Test Chinese Input
```bash
curl -X POST http://localhost:8888/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"text": "在edge1部署eMBB切片，下行200Mbps"}' | jq .
```

## Expected Outputs

### Successful TMF921 Intent Response
```json
{
  "intentId": "intent-xxx",
  "intentName": "Deploy eMBB Service",
  "intentType": "NetworkSlice",
  "scope": "5GCore",
  "priority": "medium",
  "requestTime": "2025-09-14T12:00:00Z",
  "intentParameters": {
    "serviceType": "eMBB",
    "qosProfile": {
      "downlinkThroughput": 200,
      "uplinkThroughput": 100,
      "latency": 30
    }
  },
  "targetEntities": ["edge1"]
}
```

## Service Logs

### View Real-time Logs
```bash
# Service logs
tail -f /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter/service.log

# Adapter activity logs
tail -f /home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter/adapter_log_$(date +%Y%m%d).jsonl
```

### Log Files Location
- Service logs: `service.log`
- Activity logs: `/artifacts/adapter/adapter_log_YYYYMMDD.jsonl`
- Demo session logs: `/artifacts/adapter/demo_YYYYMMDD_HHMMSS.log`

## Troubleshooting

### Service Not Running
```bash
# Start service with Claude CLI
export CLAUDE_CLI=1
python3 main.py &
```

### Port Already in Use
```bash
# Kill existing process
pkill -f "python3 main.py"
# Restart
./start_with_claude.sh
```

### Claude CLI Not Working
```bash
# Check Claude CLI status
claude --version

# Fallback to rule-based mode
unset CLAUDE_CLI
python3 main.py
```

## Demo Tips

1. **Start Simple**: Begin with basic scenarios (options 1-3)
2. **Show Language Support**: Demonstrate both English and Chinese inputs
3. **Highlight JSON Output**: The schema-validated TMF921 format
4. **Test Edge Cases**: Use custom input for complex requests
5. **Show Logs**: Demonstrate audit trail capability

## Integration Points

- **VM-1 (Nephio)**: Connects via `http://172.16.2.10:8888`
- **VM-4 (Edge2)**: Connects via `http://172.16.2.10:8888`
- **External Access**: SSH only at `147.251.115.156`

## Architecture Flow
```
User Input (NL) → LLM Adapter (VM-3) → TMF921 Intent JSON
                        ↓
                  Claude CLI Processing
                        ↓
                  Schema Validation
                        ↓
                  JSON Response
```