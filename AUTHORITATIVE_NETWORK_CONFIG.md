# Authoritative Network Configuration

## VM Network Topology

### Current Production Configuration
```
VM-1 (Orchestrator + Integrated LLM):
  - Internal IP: 172.16.0.78
  - Floating IP: 147.251.115.143
  - Integrated Services:
    - GitOps (Gitea): Port 8888
    - LLM Adapter: Port 8002
    - TMF921 Processor: Port 8002
    - Real-time Monitor: Port 8001
    - TMux WebSocket: Port 8004
    - Web Frontend: Port 8005
    - K3s API: Port 6444
    - Monitoring Stack: Ports 3000, 8428, 9090, 9093

VM-2 (Edge Site 1):
  - Internal IP: 172.16.4.45
  - K8s API: Port 6443
  - Prometheus: Port 30090

VM-4 (Edge Site 2):
  - Internal IP: 172.16.4.176
  - K8s API: Port 6443
  - Prometheus: Port 30090
```

## Service Architecture
- All LLM and intent processing services are now integrated into VM-1
- Edge sites (VM-2, VM-4) handle workload deployment
- GitOps pull model from VM-1 to edge sites

## Security Groups
Ensure ports are open for inter-VM communication on the internal network.
