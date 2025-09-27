# TMF921 Adapter - Automated Usage Guide

## Overview

The TMF921 Adapter has been configured for fully automated operation without passwords or manual intervention. This guide provides comprehensive documentation on automated usage patterns.

## Quick Start

### 1. Start the Service

```bash
# Option 1: Automated startup script
/home/ubuntu/nephio-intent-to-o2-demo/scripts/edge-management/start_tmf921_automated.sh

# Option 2: Manual start
cd /home/ubuntu/nephio-intent-to-o2-demo/adapter
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8889

# Option 3: Docker (if configured)
docker-compose -f docker-compose.automated.yml up -d
```

### 2. Verify Service Health

```bash
curl -X GET http://localhost:8889/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": 1758956495.17,
  "metrics": {...},
  "retry_config": {...}
}
```

## API Endpoints

### Primary Endpoint: `/api/v1/intent/transform`

**POST** `/api/v1/intent/transform`

Transform natural language into TMF921-compliant JSON intent.

**Request Body:**
```json
{
  "natural_language": "Deploy 5G network slice for gaming at edge1",
  "target_site": "edge1"  // Optional: edge1, edge2, edge3, edge4, both
}
```

**Response:**
```json
{
  "intent": {
    "intentId": "intent_1758956507257",
    "name": "Deploy 5G network slice for gaming at edge1",
    "description": "Deploy 5G network slice for gaming at edge1",
    "service": {
      "name": "eMBB Service",
      "type": "eMBB",
      "characteristics": {
        "reliability": "medium",
        "mobility": "mobile"
      }
    },
    "targetSite": "edge1",
    "qos": {
      "latency_ms": 50
    },
    "slice": {
      "sst": 1,
      "sd": null,
      "plmn": null
    },
    "priority": "medium",
    "lifecycle": "draft",
    "metadata": {
      "createdAt": "2025-09-27T07:01:47Z",
      "version": "1.0.0"
    }
  },
  "execution_time": 0.003,
  "hash": "5212fdb635a859b6e491760a516e26e8a79115774cc929922cdf50781694e004"
}
```

### Legacy Endpoint: `/generate_intent`

Same functionality as `/api/v1/intent/transform` for backward compatibility.

### Health and Monitoring

- **GET** `/health` - Service health check
- **GET** `/metrics` - Performance metrics
- **GET** `/` - Web UI for manual testing

## Service Types and Auto-Detection

The adapter automatically detects service types from natural language:

### eMBB (Enhanced Mobile Broadband) - SST 1
**Keywords:** video, streaming, gaming, broadband, embb, high bandwidth
```bash
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy video streaming service with 100 Mbps"}'
```

### URLLC (Ultra-Reliable Low-Latency Communication) - SST 2
**Keywords:** low latency, ultra-low, urllc, critical, real-time, autonomous, 5ms, 1ms
```bash
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Setup ultra-low latency service for autonomous vehicles"}'
```

### mMTC (Massive Machine Type Communications) - SST 3
**Keywords:** iot, sensor, mmtc, massive, monitoring, machine
```bash
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Configure IoT sensor monitoring network"}'
```

## Target Site Configuration

### Supported Sites
- `edge1` - Edge Site 1 (VM-2)
- `edge2` - Edge Site 2 (VM-4)
- `edge3` - Edge Site 3 (New)
- `edge4` - Edge Site 4 (New)
- `both` - All edge sites

### Auto-Detection
The adapter can auto-detect target sites from text:
```bash
# Auto-detects edge1
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy service at edge site 1"}'

# Auto-detects both
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy across all edge sites"}'
```

### Explicit Override
```bash
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy service", "target_site": "edge3"}'
```

## QoS Parameter Extraction

The adapter automatically extracts QoS parameters from natural language:

### Bandwidth
```bash
# Extracts 100 Mbps downlink
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy service with 100 Mbps bandwidth"}'

# Extracts 1 Gbps downlink
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Setup high-speed connection 1 Gbps"}'
```

### Latency
```bash
# Extracts 10ms latency
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy real-time service with 10ms latency"}'
```

## Automation Examples

### Python Client

```python
import requests
import json

class TMF921Client:
    def __init__(self, base_url="http://localhost:8889"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({'Content-Type': 'application/json'})

    def generate_intent(self, natural_language, target_site=None):
        payload = {"natural_language": natural_language}
        if target_site:
            payload["target_site"] = target_site

        response = self.session.post(f"{self.base_url}/api/v1/intent/transform", json=payload)
        response.raise_for_status()
        return response.json()

# Usage
client = TMF921Client()
result = client.generate_intent("Deploy URLLC service at edge1")
print(json.dumps(result['intent'], indent=2))
```

### Bash Script

```bash
#!/bin/bash
# automated_intent_generation.sh

BASE_URL="http://localhost:8889"

generate_intent() {
    local nl_text="$1"
    local target_site="$2"

    local payload='{"natural_language": "'$nl_text'"'
    if [ ! -z "$target_site" ]; then
        payload+=', "target_site": "'$target_site'"'
    fi
    payload+='}'

    curl -s -X POST "$BASE_URL/api/v1/intent/transform" \
         -H "Content-Type: application/json" \
         -d "$payload" | jq '.'
}

# Examples
generate_intent "Deploy eMBB service for gaming" "edge1"
generate_intent "Setup IoT monitoring network" "edge2"
generate_intent "Configure URLLC for autonomous vehicles" "edge3"
```

### Batch Processing

```bash
#!/bin/bash
# batch_intent_processing.sh

declare -a intents=(
    "Deploy gaming service at edge1"
    "Setup IoT monitoring at edge2"
    "Configure video streaming at edge3"
    "Deploy URLLC for automation at edge4"
    "Setup multi-site CDN deployment"
)

for intent in "${intents[@]}"; do
    echo "Processing: $intent"
    curl -s -X POST http://localhost:8889/api/v1/intent/transform \
         -H "Content-Type: application/json" \
         -d "{\"natural_language\": \"$intent\"}" | \
         jq -r '.intent.intentId + ": " + .intent.service.type + " -> " + .intent.targetSite'
    echo
done
```

## Error Handling

### Common Errors

1. **Empty Input (400)**
```json
{"detail": "String should have at least 1 character"}
```

2. **Invalid Target Site (400)**
```json
{"detail": "Invalid targetSite: invalid_site"}
```

3. **Service Unavailable (503)**
```json
{"detail": "Service unavailable after 3 retries"}
```

### Error Handling in Code

```python
import requests

def safe_generate_intent(natural_language, target_site=None):
    try:
        payload = {"natural_language": natural_language}
        if target_site:
            payload["target_site"] = target_site

        response = requests.post(
            "http://localhost:8889/api/v1/intent/transform",
            json=payload,
            timeout=30
        )

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error {response.status_code}: {response.text}")
            return None

    except requests.exceptions.ConnectionError:
        print("Cannot connect to TMF921 adapter service")
        return None
    except requests.exceptions.Timeout:
        print("Request timeout")
        return None
```

## Testing and Validation

### Automated Test Suite

Run the comprehensive test suite:
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/scripts/edge-management
python3 tmf921_automated_test.py
```

### API Examples

Run all usage examples:
```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/scripts/edge-management
python3 tmf921_api_examples.py
```

### Manual Testing

Access the web UI at: http://localhost:8889

## Performance Monitoring

### Get Metrics
```bash
curl -X GET http://localhost:8889/metrics
```

Response:
```json
{
  "metrics": {
    "total_requests": 25,
    "successful_requests": 25,
    "failed_requests": 0,
    "retry_attempts": 0,
    "total_retries": 0,
    "retry_rate": 0.0,
    "success_rate": 1.0
  },
  "timestamp": 1758956669.87
}
```

## Production Deployment

### Systemd Service

1. Install the service:
```bash
sudo cp /home/ubuntu/nephio-intent-to-o2-demo/scripts/edge-management/tmf921-adapter.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tmf921-adapter
sudo systemctl start tmf921-adapter
```

2. Check status:
```bash
sudo systemctl status tmf921-adapter
```

### Docker Deployment

```bash
cd /home/ubuntu/nephio-intent-to-o2-demo/adapter
docker-compose -f docker-compose.automated.yml up -d
```

## Configuration

### Environment Variables

- `CLAUDE_SKIP_AUTH=true` - Skip Claude CLI authentication
- `TMF921_ADAPTER_MODE=automated` - Enable automated mode
- `TMF921_FALLBACK_ENABLED=true` - Enable fallback intent generation
- `PYTHONPATH=/path/to/adapter/app` - Python module path

### Configuration Files

- `/home/ubuntu/nephio-intent-to-o2-demo/adapter/.env` - Environment configuration
- `/home/ubuntu/.claude/config.json` - Claude CLI configuration

## Troubleshooting

### Service Not Starting

1. Check if port 8889 is available:
```bash
netstat -tlnp | grep 8889
```

2. Check logs:
```bash
journalctl -u tmf921-adapter -f
```

### API Not Responding

1. Check service health:
```bash
curl -f http://localhost:8889/health
```

2. Check process:
```bash
ps aux | grep uvicorn
```

### Invalid JSON Responses

The adapter includes fallback intent generation that ensures valid TMF921 JSON even when Claude CLI is unavailable or fails.

## Security Considerations

- The adapter runs in automated mode without authentication for CI/CD integration
- For production, consider adding API key authentication
- Use HTTPS in production environments
- Implement rate limiting for public deployments

## Support

For issues or questions:
1. Check the automated test results
2. Review service logs
3. Verify API endpoint responses
4. Consult the troubleshooting section

The TMF921 adapter is now fully automated and ready for integration into CI/CD pipelines and automated workflows!