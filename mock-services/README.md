# O2IMS Mock Server

A comprehensive mock implementation of the O-RAN O2IMS Interface Specification 3.0 using FastAPI. This server provides realistic responses for infrastructure inventory and management operations across 4 edge sites (edge1-4).

## Features

- **Complete O2IMS API Implementation**: All required endpoints per specification 3.0
- **Realistic Mock Data**: Comprehensive data models for 4 edge sites with detailed resource information
- **Production-Grade Architecture**: Built with FastAPI, comprehensive logging, error handling
- **Query Parameter Support**: Filtering, pagination, and search capabilities
- **Health Monitoring**: Built-in health check and monitoring endpoints
- **Type Safety**: Full type hints and Pydantic models for data validation
- **Comprehensive Logging**: Request/response logging for debugging and monitoring

## API Endpoints

### Core O2IMS Endpoints

- `GET /o2ims_infrastructureInventory/v1/status` - Service status and capabilities
- `GET /o2ims_infrastructureInventory/v1/deploymentManagers` - List deployment managers
- `GET /o2ims_infrastructureInventory/v1/resourcePools` - List resource pools
- `GET /o2ims_infrastructureInventory/v1/deploymentManagers/{dmId}/o2ims_infrastructureProvisioningRequest` - Provisioning requests

### Additional Utility Endpoints

- `GET /health` - Health check endpoint
- `GET /o2ims_infrastructureInventory/v1/deploymentManagers/{dmId}` - Get specific deployment manager
- `GET /o2ims_infrastructureInventory/v1/resourcePools/{poolId}` - Get specific resource pool
- `GET /docs` - Interactive API documentation (Swagger UI)
- `GET /redoc` - Alternative API documentation (ReDoc)

## Edge Sites Configuration

The mock server simulates 4 edge sites with the following characteristics:

### Edge Site 1 (edge1)
- **Kubernetes Cluster**: v1.28.3 with 4 nodes
- **Compute**: 128 CPU cores, 512GB RAM, 4TB storage
- **Network**: 100Gbps bandwidth, 1.1ms latency
- **Functions**: Full 5G Core (UPF, AMF, SMF, AUSF, UDM)

### Edge Site 2 (edge2)
- **Kubernetes Cluster**: v1.28.3 with 5 nodes
- **Compute**: 160 CPU cores, 640GB RAM, 5TB storage
- **Network**: 200Gbps bandwidth, 1.2ms latency
- **Functions**: Enhanced edge computing with MEC capabilities

### Edge Site 3 (edge3)
- **Kubernetes Cluster**: v1.28.3 with 6 nodes
- **Compute**: 192 CPU cores, 768GB RAM, 6TB storage
- **Network**: 300Gbps bandwidth, 1.3ms latency
- **Functions**: Advanced network slicing support

### Edge Site 4 (edge4)
- **Kubernetes Cluster**: v1.28.3 with 7 nodes
- **Compute**: 224 CPU cores, 896GB RAM, 7TB storage
- **Network**: 400Gbps bandwidth, 1.4ms latency
- **Functions**: Full spectrum of 5G and WiFi-6 support

## Installation

### Prerequisites

- Python 3.8 or higher
- pip package manager

### Quick Start

1. **Install dependencies**:
   ```bash
   cd /home/ubuntu/nephio-intent-to-o2-demo/mock-services
   pip install -r requirements.txt
   ```

2. **Run the server**:
   ```bash
   python o2ims-mock-server.py
   ```

3. **Access the API**:
   - Server: http://localhost:30205
   - Documentation: http://localhost:30205/docs
   - Health Check: http://localhost:30205/health

### Development Mode

For development with auto-reload:

```bash
uvicorn o2ims-mock-server:app --host 0.0.0.0 --port 30205 --reload
```

## Production Deployment

### Using systemd (Recommended)

1. **Install the systemd service**:
   ```bash
   sudo cp o2ims-mock-server.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable o2ims-mock-server
   sudo systemctl start o2ims-mock-server
   ```

2. **Check service status**:
   ```bash
   sudo systemctl status o2ims-mock-server
   sudo journalctl -u o2ims-mock-server -f
   ```

### Using Docker

```bash
# Build image
docker build -t o2ims-mock-server .

# Run container
docker run -d --name o2ims-mock \
  -p 30205:30205 \
  --restart unless-stopped \
  o2ims-mock-server
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  o2ims-mock:
    build: .
    ports:
      - "30205:30205"
    restart: unless-stopped
    environment:
      - LOG_LEVEL=info
    volumes:
      - ./logs:/app/logs
```

## API Usage Examples

### Get Service Status

```bash
curl -X GET "http://localhost:30205/o2ims_infrastructureInventory/v1/status" \
  -H "accept: application/json"
```

### List Deployment Managers

```bash
curl -X GET "http://localhost:30205/o2ims_infrastructureInventory/v1/deploymentManagers" \
  -H "accept: application/json"
```

### List Resource Pools with Filtering

```bash
# Filter by resource pool type
curl -X GET "http://localhost:30205/o2ims_infrastructureInventory/v1/resourcePools?resource_pool_type=COMPUTE&limit=10" \
  -H "accept: application/json"

# Filter by location
curl -X GET "http://localhost:30205/o2ims_infrastructureInventory/v1/resourcePools?location=Edge%20Site%201" \
  -H "accept: application/json"
```

### Get Provisioning Requests

```bash
# Get deployment manager ID first
DM_ID=$(curl -s "http://localhost:30205/o2ims_infrastructureInventory/v1/deploymentManagers" | jq -r '.[0].deployment_manager_id')

# Get provisioning requests for that deployment manager
curl -X GET "http://localhost:30205/o2ims_infrastructureInventory/v1/deploymentManagers/${DM_ID}/o2ims_infrastructureProvisioningRequest" \
  -H "accept: application/json"
```

## Configuration

### Environment Variables

The server supports the following environment variables:

- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR) - default: INFO
- `PORT`: Server port - default: 30205
- `HOST`: Server host - default: 0.0.0.0

### Logging

Logs are written to:
- Console (stdout) for real-time monitoring
- `/tmp/o2ims-mock-server.log` for persistent logging

Log format includes:
- Timestamp
- Log level
- Component name
- Message
- Request/response details for API calls

## Data Models

The server implements comprehensive data models based on O2IMS specification 3.0:

### Core Models
- `O2IMSStatus`: Service status and capabilities
- `DeploymentManagerInfo`: Kubernetes/container orchestrator information
- `ResourcePoolInfo`: Compute, storage, and network resource pools
- `InfrastructureProvisioningRequest`: Resource provisioning requests

### Supporting Models
- `AlarmEventRecord`: Infrastructure alarms and events
- `GlobalCloudId`: Global cloud identification
- Various enums for type safety (AlarmType, ResourceType, etc.)

## Monitoring and Health Checks

### Health Check Endpoint

```bash
curl -X GET "http://localhost:30205/health"
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "service": "O2IMS Mock Server",
  "version": "1.0.0"
}
```

### Logs Monitoring

Monitor server logs in real-time:

```bash
tail -f /tmp/o2ims-mock-server.log
```

### Service Monitoring

For systemd deployment:

```bash
# Service status
sudo systemctl status o2ims-mock-server

# Service logs
sudo journalctl -u o2ims-mock-server -f

# Resource usage
sudo systemctl show o2ims-mock-server --property=MemoryCurrent,CPUUsageNSec
```

## Troubleshooting

### Common Issues

1. **Port already in use**:
   ```bash
   # Check what's using port 30205
   sudo netstat -tlnp | grep 30205

   # Kill the process if needed
   sudo kill -9 <PID>
   ```

2. **Permission denied**:
   ```bash
   # Ensure proper permissions
   chmod +x o2ims-mock-server.py

   # For systemd service
   sudo chown root:root /etc/systemd/system/o2ims-mock-server.service
   sudo chmod 644 /etc/systemd/system/o2ims-mock-server.service
   ```

3. **Python module not found**:
   ```bash
   # Reinstall dependencies
   pip install -r requirements.txt

   # For system-wide installation
   sudo pip3 install -r requirements.txt
   ```

### Debug Mode

Enable debug logging:

```bash
export LOG_LEVEL=DEBUG
python o2ims-mock-server.py
```

### API Testing

Use the interactive documentation for testing:
- Swagger UI: http://localhost:30205/docs
- ReDoc: http://localhost:30205/redoc

## Development

### Code Structure

```
o2ims-mock-server.py
├── Data Models (Pydantic)
│   ├── BaseO2IMSModel
│   ├── O2IMSStatus
│   ├── DeploymentManagerInfo
│   ├── ResourcePoolInfo
│   └── InfrastructureProvisioningRequest
├── Mock Data Generator
│   ├── Edge site configuration
│   ├── Resource pool generation
│   └── Filtering logic
├── FastAPI Application
│   ├── Middleware (CORS, logging)
│   ├── API endpoints
│   └── Error handlers
└── Server Configuration
```

### Adding New Endpoints

1. Define Pydantic models for request/response
2. Add endpoint function with proper decorators
3. Implement business logic in MockDataGenerator
4. Add tests and documentation

### Testing

```bash
# Install test dependencies
pip install pytest pytest-asyncio pytest-cov

# Run tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=o2ims-mock-server --cov-report=html
```

## License

MIT License - see LICENSE file for details.

## Support

For issues and questions:
1. Check the logs: `/tmp/o2ims-mock-server.log`
2. Verify API documentation: http://localhost:30205/docs
3. Test health endpoint: http://localhost:30205/health
4. Review systemd service status: `sudo systemctl status o2ims-mock-server`