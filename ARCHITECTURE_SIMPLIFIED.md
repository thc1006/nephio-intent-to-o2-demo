# Simplified Architecture - Nephio Intent-to-O2 Demo

**Status**: Production Ready
**Date**: 2025-09-26

## Current Architecture (Simplified)

### Virtual Machines

| VM | Role | IP Address | Services |
|----|------|------------|----------|
| **VM-1** | Orchestrator + LLM | 172.16.0.78 | • Gitea (8888)<br>• LLM/TMF921 (8002)<br>• Monitoring (3000, 8428, 9090)<br>• K3s (6444)<br>• Web UI (8004, 8005) |
| **VM-2** | Edge Site 1 | 172.16.4.45 | • Kubernetes (6443)<br>• Prometheus (30090)<br>• Workloads |
| **VM-4** | Edge Site 2 | 172.16.4.176 | • Kubernetes (6443)<br>• Prometheus (30090)<br>• Workloads |

### Data Flow

```
User Input (Natural Language)
         ↓
    VM-1 (LLM Processing)
         ↓
    TMF921 Intent JSON
         ↓
    KRM Rendering
         ↓
    GitOps (Gitea)
         ↓
    ┌────┴────┐
    ↓         ↓
  VM-2      VM-4
 Edge01    Edge02
```

## Key Integration Points

### VM-1 Integrated Services
- **Port 8002**: TMF921 Intent Processor (formerly on separate VM)
- **Port 8888**: Gitea Git Server
- **Port 8001**: Real-time Monitor
- **Port 8004**: TMux WebSocket Bridge
- **Port 8005**: Web Frontend
- **Port 6444**: K3s API Server
- **Port 8428**: VictoriaMetrics
- **Port 3000**: Grafana
- **Port 9090**: Prometheus
- **Port 9093**: Alertmanager

### Environment Configuration
```bash
# Current environment variables
export VM1_IP="172.16.0.78"
export VM2_IP="172.16.4.45"
export VM4_IP="172.16.4.176"
export LLM_ADAPTER_URL="http://localhost:8002"
export GITEA_URL="http://localhost:8888"
```

## Benefits of Simplified Architecture

1. **Reduced Complexity**: From 4 VMs to 3 VMs
2. **Lower Latency**: LLM processing local to orchestrator
3. **Simplified Networking**: No inter-VM communication for LLM
4. **Cost Efficient**: One less VM to maintain
5. **Easier Debugging**: All control plane on single VM

## Quick Test Commands

```bash
# Test LLM service
curl http://localhost:8002/health

# Test GitOps
curl http://localhost:8888/api/v1/version

# Test monitoring
curl http://localhost:8428/health

# Test K3s
kubectl --kubeconfig=/home/ubuntu/.kube/config-k3s get nodes

# Test end-to-end
./scripts/verify-e2e-flow.sh
```

## Clean Migration Status

✅ **All legacy references removed**
✅ **Services fully integrated**
✅ **Documentation updated**
✅ **Tests passing (18/18)**
✅ **Production ready**

---

This simplified architecture eliminates unnecessary complexity while maintaining all functionality.