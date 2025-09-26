# Deployment Context Documentation

## Environment Overview
- **VM-1 (SMO/Management)**: 172.16.0.78 (Current VM)
- **VM-2 (Edge Cluster)**: 172.16.4.45
- **OS**: Linux 5.15.0-100-generic
- **Date Created**: 2025-09-07
- **Purpose**: Nephio R5 + O-RAN Integration Demo

## Cluster Status Summary

| Cluster | Location | API Endpoint | Kubeconfig | Status |
|---------|----------|--------------|------------|--------|
| nephio-demo | VM-1 | 127.0.0.1:45463 | ~/.kube/config | ✅ Running |
| focom-smo | VM-1 | 127.0.0.1:6443 | /tmp/focom-kubeconfig | ✅ Running |
| edge | VM-2 | 172.16.4.45:6443 | /tmp/kubeconfig-edge.yaml | ✅ Ready (needs kubeconfig) |

## ⚠️ IMMEDIATE ACTION REQUIRED

### Copy Edge Kubeconfig from VM-2 to VM-1

**On VM-2, run:**
```bash
cat /tmp/kubeconfig-edge.yaml
```

**Copy the entire output, then on VM-1 create the file:**
```bash
cat > /tmp/kubeconfig-edge.yaml << 'EOF'
# PASTE THE CONTENT HERE
EOF
```

**Verify connection:**
```bash
export KUBECONFIG=/tmp/kubeconfig-edge.yaml
kubectl get nodes
```

## Kubernetes Clusters Details

### 1. Main Nephio Cluster (nephio-demo) - VM-1

#### Configuration
- **Type**: KinD (Kubernetes in Docker)
- **Version**: v1.29.0
- **API Server**: https://127.0.0.1:45463
- **Nodes**: Control-plane (172.18.0.2), Worker (172.18.0.3)

#### Port Mappings
- **3000**: Gitea Web UI
- **30080**: HTTP Services
- **30443**: HTTPS Services
- **45463**: Kubernetes API

#### Components
- **Gitea**: Git server at 172.18.0.200:3000
- **Porch**: Package orchestration in porch-system namespace
- **Function Runner**: 2 replicas for KRM functions

### 2. FoCoM SMO Cluster (focom-smo) - VM-1

#### Configuration
- **Type**: KinD
- **Version**: v1.34.0
- **API Server**: https://127.0.0.1:6443
- **Purpose**: SMO operations and FoCoM controller

#### Port Mappings
- **31080**: HTTP Services (avoiding conflict with nephio-demo)
- **31443**: HTTPS Services
- **6443**: Kubernetes API

#### Components
- **FoCoM Operator**: Placeholder controller in focom-system
- **CRDs**: OCloud, TemplateInfo, FocomProvisioningRequest
- **O2IMS Resources**: Provisioning requests in o2ims namespace

### 3. Edge Cluster - VM-2

#### Configuration
- **Type**: KinD
- **Name**: edge
- **API Server**: https://172.16.4.45:6443
- **Status**: ✅ READY (awaiting kubeconfig transfer)

#### Port Mappings
- **31080**: NodePort HTTP
- **31443**: NodePort HTTPS
- **6443**: Kubernetes API (external access)

## Gitea Configuration

### Access Methods
1. **Local (VM-1)**: http://localhost:3000
2. **External**: http://172.16.0.78:3000
3. **LoadBalancer**: http://172.18.0.200:3000
4. **SSH**: Port 32040 (NodePort)

### Repository Structure
- `catalog/` - Nephio package catalog
- `management/` - Management cluster configs
- `edge-clusters/` - Edge cluster configurations
- `packages/` - KRM packages

## Network Architecture

```
┌─────────────────────────────────────────┐
│         VM-1 (172.16.0.78)              │
│  ┌───────────────┐  ┌────────────────┐  │
│  │ nephio-demo   │  │ focom-smo      │  │
│  │ • Gitea       │  │ • FoCoM Op     │  │
│  │ • Porch       │  │ • O2IMS CRs    │  │
│  │ Ports: 30080  │  │ Ports: 31080   │  │
│  └───────────────┘  └────────────────┘  │
└─────────────────────────────────────────┘
                    │
                    │ Network: 172.16.0.0/16
                    ▼
┌─────────────────────────────────────────┐
│         VM-2 (172.16.4.45)              │
│  ┌────────────────────────────────┐     │
│  │ edge cluster                   │     │
│  │ • API: 172.16.4.45:6443       │     │
│  │ • O2IMS (to deploy)           │     │
│  │ • RAN workloads (planned)     │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

## Quick Commands Reference

### Cluster Management
```bash
# List all KinD clusters
kind get clusters

# Switch contexts
kubectl config use-context kind-nephio-demo
kubectl config use-context kind-focom-smo
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Check cluster status
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

### Gitea Operations
```bash
# Check Gitea status
kubectl get pods -n gitea-system
kubectl logs -n gitea-system deployment/gitea

# Access Gitea
curl http://localhost:3000
```

### FoCoM Operations
```bash
# Check FoCoM resources
kubectl --kubeconfig /tmp/focom-kubeconfig get oclouds -n o2ims
kubectl --kubeconfig /tmp/focom-kubeconfig get focomprovisioningrequests -n o2ims

# View FoCoM operator logs
kubectl --kubeconfig /tmp/focom-kubeconfig logs -n focom-system deployment/focom-controller
```

### Porch Operations
```bash
# List repositories
kubectl get repositories -n porch-system

# Check package revisions
kubectl get packagerevisions -A

# View Porch server status
kubectl get pods -n porch-system
```

## Important Files

| File | Purpose | Location |
|------|---------|----------|
| Default kubeconfig | nephio-demo cluster | ~/.kube/config |
| FoCoM kubeconfig | focom-smo cluster | /tmp/focom-kubeconfig |
| Edge kubeconfig | edge cluster (VM-2) | /tmp/kubeconfig-edge.yaml |
| O-Cloud provision script | Main automation | scripts/p0.4A_ocloud_provision.sh |
| FoCoM operator manifest | CRDs and controller | manifests/focom-operator.yaml |

## Troubleshooting Guide

### Port Conflicts
```bash
# Check port usage
sudo lsof -i :30080
sudo lsof -i :31080
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### Cluster Connection Issues
```bash
# Test API server
curl -k https://172.16.4.45:6443/healthz

# Check Docker networks
docker network ls
docker network inspect kind

# Verify kubeconfig
kubectl config view --kubeconfig=/tmp/kubeconfig-edge.yaml
```

### Gitea Issues
```bash
# Restart Gitea
kubectl rollout restart deployment/gitea -n gitea-system

# Check service
kubectl get svc -n gitea-system gitea-service
```

## Next Steps After Kubeconfig Transfer

1. **Complete O-Cloud Provisioning**
   ```bash
   ./scripts/p0.4A_ocloud_provision.sh --skip-kind --skip-focom
   ```

2. **Deploy O2IMS on Edge**
   ```bash
   export KUBECONFIG=/tmp/kubeconfig-edge.yaml
   kubectl create namespace o2ims
   # Apply O2IMS manifests
   ```

3. **Verify Integration**
   ```bash
   # Check provisioning status
   kubectl --kubeconfig /tmp/focom-kubeconfig get focomprovisioningrequests -n o2ims -w
   ```

4. **Setup GitOps**
   - Configure repositories in Gitea
   - Setup Flux/ArgoCD
   - Implement SLO gates

## Project Status

### Completed ✅
- Nephio demo cluster with Gitea and Porch
- FoCoM SMO cluster with operator
- Edge cluster created on VM-2
- O-Cloud CRs applied
- Documentation created

### In Progress ⏳
- Edge kubeconfig transfer (awaiting paste from VM-2)
- O2IMS deployment
- FoCoM → O2IMS integration

### Pending ⏸️
- Intent gateway (TMF921 → 28.312)
- KRM package generation
- SLO-gated GitOps
- Sigstore integration

---
*Last Updated: 2025-09-07*
*Status: Awaiting edge kubeconfig from VM-2*