# LLM Intent Adapter Service

A production-ready FastAPI service that converts natural language requests into TMF921-compliant JSON intents using Claude AI.

## Features

- ✅ RESTful API for intent generation
- ✅ TMF921/3GPP standards compliance
- ✅ Health monitoring endpoint
- ✅ Systemd service integration
- ✅ Automatic startup on boot
- ✅ Comprehensive logging
- ✅ Virtual environment isolation
- ✅ Web UI for testing
- ✅ Management scripts and Makefile

## System Requirements

- Ubuntu 22.04 LTS
- Python 3.10+
- Port 8000 (configurable)
- Internet access for Claude API

## Installation

### 1. Initial Setup

```bash
# Navigate to project directory
cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter

# Create virtual environment and install dependencies
make venv
make install
```

### 2. Service Installation

```bash
# Install systemd service
make systemd-install

# Enable auto-start on boot
make systemd-enable
```

## Usage

### Service Management (Recommended)

```bash
# Start service
make run

# Stop service
make stop

# Restart service
make restart

# Check status
make status

# View logs
make logs

# Follow logs in real-time
make logs-follow

# Health check
make health
```

### Direct Script Usage

```bash
# Health check
./scripts/health.sh

# Start service
./scripts/start.sh

# Stop service
./scripts/stop.sh

# View logs
./scripts/logs.sh [-f] [-n LINES]
```

### Systemd Commands

```bash
# Start service
sudo systemctl start llm-adapter

# Stop service
sudo systemctl stop llm-adapter

# Check status
sudo systemctl status llm-adapter

# View logs
sudo journalctl -u llm-adapter -f
```

## API Endpoints

### GET /health
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "service": "LLM Intent Adapter",
  "version": "1.0.0"
}
```

### POST /generate_intent
Generate TMF921-compliant intent from natural language

**Request:**
```json
{
  "text": "Create a network slice for IoT devices with low latency"
}
```

**Response:**
```json
{
  "intentId": "550e8400-e29b-41d4-a716-446655440000",
  "intentName": "Create IoT Network Slice",
  "intentType": "NetworkSliceIntent",
  "scope": "network",
  "priority": "high",
  "requestTime": "2024-01-01T00:00:00Z",
  "intentParameters": {
    "deviceType": "IoT",
    "latencyRequirement": "low",
    "bandwidth": "10Gbps"
  }
}
```

### Web UI
- Access at: `http://localhost:8000/`
- Interactive form for testing intent generation

## Testing

### Run Unit Tests
```bash
make test
```

### Quick API Test
```bash
make api-test
```

### Manual Test
```bash
# Health check
curl http://localhost:8000/health

# Generate intent
curl -X POST http://localhost:8000/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"text": "Deploy 5G network slice for autonomous vehicles"}'
```

## Development

### Run in Development Mode
```bash
make dev
```

### Project Structure
```
llm-adapter/
├── main.py              # Main application entry point
├── app/                 # Application modules
├── tests/               # Test files
├── scripts/             # Management scripts
│   ├── health.sh       # Health check script
│   ├── start.sh        # Start script
│   ├── stop.sh         # Stop script
│   └── logs.sh         # Log viewing script
├── static/              # Static files for web UI
├── .venv/              # Python virtual environment
├── requirements.txt     # Python dependencies
├── Makefile            # Make targets for management
├── llm-adapter.service # Systemd service file
└── service.log         # Service logs
```

## TMF921 Intent Structure

The service generates intents with the following structure:
- `intentId`: Unique identifier
- `intentName`: Descriptive name
- `intentType`: Type of intent (e.g., NetworkSliceDeployment)
- `scope`: Scope of the intent (e.g., 5G-NetworkSlice)
- `priority`: Priority level (high/medium/low)
- `requestTime`: ISO timestamp
- `intentParameters`: Specific parameters for the intent
- `constraints`: Optional constraints
- `targetEntities`: Optional target entities
- `expectedOutcome`: Optional expected outcome

## Example Requests

1. **Network Slice Deployment**:
   "Deploy a 5G eMBB network slice with 1Gbps throughput in zone-1"

2. **Service Provisioning**:
   "Provision VPN service with 500Mbps bandwidth and 99.99% SLA"

3. **Resource Allocation**:
   "Allocate 32 vCPUs and 128GB RAM for edge computing"

4. **Network Function Configuration**:
   "Configure UPF with auto-scaling, min 2 max 10 instances"

## Troubleshooting

### Service Won't Start

1. Check if port 8000 is already in use:
```bash
sudo lsof -i:8000
```

2. Check service logs:
```bash
make logs
# or
sudo journalctl -u llm-adapter -n 50
```

3. Verify Python environment:
```bash
source .venv/bin/activate
python --version  # Should be 3.10+
pip list         # Check installed packages
```

### Port Conflict

If port 8000 is occupied:
```bash
make stop
```

### Claude API Issues

Ensure Claude CLI is properly configured:
```bash
claude --version
```

If not available, the service will return mock responses for testing.

## Maintenance

### Clean Up
```bash
make clean
```

### Update Dependencies
```bash
source .venv/bin/activate
pip install -r requirements.txt --upgrade
```

### View Service Configuration
```bash
cat /etc/systemd/system/llm-adapter.service
```

## Verification Steps

### ✅ Complete Setup Verification

```bash
# 1. Check health endpoint
curl -s http://localhost:8000/health | python3 -m json.tool
# Expected: {"status":"healthy","service":"LLM Intent Adapter","version":"1.0.0"}

# 2. Test API with sample request
curl -s -X POST http://localhost:8000/generate_intent \
  -H "Content-Type: application/json" \
  -d '{"text": "Create network slice for emergency services"}' | python3 -m json.tool
# Expected: Valid JSON intent response

# 3. Check systemd service
sudo systemctl status llm-adapter
# Expected: Active (running)

# 4. Verify auto-start is enabled
sudo systemctl is-enabled llm-adapter
# Expected: enabled
```

## Integration with VM-1

VM-1 can call this service using:
```python
import requests

response = requests.post(
    "http://vm3-ip:8000/generate_intent",
    json={"text": "your natural language request"}
)
intent = response.json()
```