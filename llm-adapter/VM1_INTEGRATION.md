# VM-3 LLM Adapter Service - VM-1 Integration Guide

## 🔌 Service Connection Information

### Network Details
- **VM-3 Hostname**: vm-3llm-adapter
- **Internal IP (Primary)**: 172.16.2.10
- **Secondary IP**: 192.168.0.201
- **Service Port**: 8888
- **Protocol**: HTTP (REST API)

### Service Endpoints
```
Base URL: http://172.16.2.10:8888
```

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check with LLM mode status |
| `/api/v1/intent/parse` | POST | Parse natural language to intent |
| `/generate_intent` | POST | Legacy endpoint (same function) |
| `/docs` | GET | Swagger API documentation |
| `/` | GET | Web UI for testing |

## 🚀 Quick Start for VM-1

### 1. Test Connectivity
```bash
# From VM-1, test if service is reachable
ping -c 2 172.16.2.10

# Check health endpoint
curl -s http://172.16.2.10:8888/health | jq .
```

Expected response:
```json
{
  "status": "healthy",
  "service": "LLM Intent Adapter",
  "version": "1.0.0",
  "llm_mode": "claude-cli"
}
```

### 2. Python Integration Example
```python
import requests
import json

class LLMAdapterClient:
    def __init__(self, base_url="http://172.16.2.10:8888"):
        self.base_url = base_url
        self.timeout = 30  # seconds
    
    def check_health(self):
        """Check service health"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.json()
        except Exception as e:
            return {"error": str(e)}
    
    def parse_intent(self, text):
        """Parse natural language to intent"""
        try:
            response = requests.post(
                f"{self.base_url}/api/v1/intent/parse",
                json={"text": text},
                headers={"Content-Type": "application/json"},
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error: {e}")
            return None

# Usage
client = LLMAdapterClient()

# Check health
health = client.check_health()
print(f"Service status: {health.get('status')}")
print(f"LLM mode: {health.get('llm_mode')}")

# Parse intent
result = client.parse_intent("Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency")
if result:
    intent = result["intent"]
    print(f"Service: {intent['service']}")
    print(f"Location: {intent['location']}")
    print(f"QoS: {intent['qos']}")
```

### 3. Shell Script Integration
```bash
#!/bin/bash

# Configuration
LLM_ADAPTER_URL="http://172.16.2.10:8888"

# Function to parse intent
parse_intent() {
    local text="$1"
    
    response=$(curl -sS -X POST "${LLM_ADAPTER_URL}/api/v1/intent/parse" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${text}\"}" \
        --max-time 30)
    
    if [ $? -eq 0 ]; then
        echo "$response"
    else
        echo '{"error": "Failed to connect to LLM Adapter"}'
    fi
}

# Example usage
intent_json=$(parse_intent "Create URLLC service with 1ms latency")
service=$(echo "$intent_json" | jq -r '.intent.service')
location=$(echo "$intent_json" | jq -r '.intent.location')

echo "Parsed Service: $service"
echo "Parsed Location: $location"
```

## 📋 API Request/Response Format

### Request Format
```json
{
  "text": "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency"
}
```

### Response Format
```json
{
  "intent": {
    "service": "eMBB",     // Values: "eMBB" | "URLLC" | "mMTC"
    "location": "edge1",   // Format: edge[N], zone[N], core[N]
    "qos": {
      "downlink_mbps": 200,    // Can be null
      "uplink_mbps": null,     // Can be null
      "latency_ms": 30         // Can be null
    }
  },
  "raw_text": "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency",
  "model": "claude-cli",        // or "rule-based" if Claude unavailable
  "version": "1.0.0"
}
```

## 🔧 Service Management (from VM-3)

If VM-1 needs to verify service status on VM-3:

```bash
# Check if service is running
ssh ubuntu@172.16.2.10 "sudo systemctl status llm-adapter"

# View recent logs
ssh ubuntu@172.16.2.10 "sudo journalctl -u llm-adapter -n 50"

# Restart service if needed
ssh ubuntu@172.16.2.10 "sudo systemctl restart llm-adapter"
```

## 🐛 Troubleshooting

### Connection Issues
1. **Verify network connectivity**:
   ```bash
   ping -c 2 172.16.2.10
   traceroute 172.16.2.10
   ```

2. **Check firewall on VM-3**:
   ```bash
   ssh ubuntu@172.16.2.10 "sudo ufw status | grep 8888"
   ```

3. **Verify service is listening**:
   ```bash
   ssh ubuntu@172.16.2.10 "sudo lsof -i :8888"
   ```

### Timeout Issues
- Default timeout: 30 seconds (Claude processing can take time)
- Adjust timeout in your client code if needed
- Check `llm_mode` in health response:
  - `"claude-cli"`: May take 5-20 seconds
  - `"rule-based"`: Should respond in <100ms

### Error Responses
- **500 Internal Server Error**: Check VM-3 service logs
- **422 Unprocessable Entity**: Check request format
- **Connection Refused**: Service may be down

## 📊 Performance Expectations

| Mode | Response Time | Accuracy |
|------|--------------|----------|
| claude-cli | 5-20 seconds | High (LLM-based) |
| rule-based | <100ms | Medium (pattern matching) |

## 🔒 Security Notes

- Service runs as user `ubuntu`
- No authentication currently implemented
- Recommended: Keep within internal network
- For production: Add API key authentication

## 📞 Contact & Support

**Service Location**: VM-3 (172.16.2.10:8888)
**Service Name**: llm-adapter
**Logs**: `/home/ubuntu/nephio-intent-to-o2-demo/llm-adapter/service.log`

## Example Test Commands for VM-1

```bash
# 1. Basic health check
curl -s http://172.16.2.10:8888/health | jq .

# 2. Parse eMBB intent
curl -s -X POST http://172.16.2.10:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Deploy eMBB slice in edge1 with 500Mbps downlink"}' | jq .

# 3. Parse URLLC intent
curl -s -X POST http://172.16.2.10:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Create ultra-reliable service with 1ms latency for autonomous vehicles"}' | jq .

# 4. Parse mMTC intent
curl -s -X POST http://172.16.2.10:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Setup IoT network for smart city sensors in zone3"}' | jq .
```

---
Last Updated: 2025-09-12
Service Version: 1.0.0
LLM Mode: claude-cli (with rule-based fallback)