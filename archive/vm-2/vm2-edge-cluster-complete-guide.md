# VM-2 Edge Cluster Complete Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Kind Cluster Deployment](#kind-cluster-deployment)
4. [O2IMS Components](#o2ims-components)
5. [GitOps Configuration](#gitops-configuration)
6. [Troubleshooting](#troubleshooting)
7. [Current Status](#current-status)
8. [Quick Reference](#quick-reference)

---

## Overview

This document records the complete deployment process of an edge Kubernetes cluster on VM-2 (172.16.4.45) with GitOps synchronization from a Gitea repository, O2IMS components, and KRM resource management.

### Architecture Summary
```
┌─────────────────────────┐         ┌─────────────────────────┐
│      VM-1 (SMO)         │         │    VM-2 (Edge)          │
│   172.16.0.78           │         │   172.16.4.45           │
│                         │         │                         │
│  ┌─────────────────┐    │         │  ┌─────────────────┐   │
│  │   Gitea Server  │────┼─────────┼──► GitOps Sync     │   │
│  │ :8888 or :3000  │    │         │  │  (RootSync)     │   │
│  └─────────────────┘    │         │  └─────────────────┘   │
│                         │         │           │             │
│  Repository:            │         │           ▼             │
│  admin1/edge1-config    │         │  ┌─────────────────┐   │
│  /apps/intent/          │         │  │  Kind Cluster   │   │
│  /crds/                 │         │  │   API: :6443    │   │
│  /namespaces/           │         │  │  NodePorts:     │   │
│                         │         │  │   31080,31443   │   │
│                         │         │  │   31280 (O2IMS) │   │
│                         │         │  └─────────────────┘   │
└─────────────────────────┘         └─────────────────────────┘
```

---

## Infrastructure Setup

### VM Configuration
- **Hostname**: vm-2ric
- **IP Address**: 172.16.4.45
- **OS**: Ubuntu Linux 5.15.0-100-generic
- **User**: ubuntu
- **Docker**: Required (with sudo or docker group)
- **Network Access**: 
  - To VM-1: 172.16.0.78
  - To Gitea: http://147.251.115.143:8888

### Prerequisites Installation
```bash
# Docker (if not installed)
sudo apt-get update
sudo apt-get install -y docker.io

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker  # Or logout/login

# Kind CLI
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

---

## Kind Cluster Deployment

### Configuration File
**Location**: `~/kind-vm2.yaml`

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "172.16.4.45"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
      - "172.16.4.45"
      - "localhost"
      - "127.0.0.1"
  extraPortMappings:
  - containerPort: 31080
    hostPort: 31080
    protocol: TCP
  - containerPort: 31443
    hostPort: 31443
    protocol: TCP
```

### Deployment Script
**Location**: `~/dev/net_kind_vm2.sh`

**Key Features**:
- Automatic Docker permission detection
- Kubeconfig generation and modification
- Health checks
- Network configuration for external access

### Deployment Process
```bash
# Method 1: Using script
chmod +x ~/dev/net_kind_vm2.sh
~/dev/net_kind_vm2.sh

# Method 2: Manual deployment
sudo kind create cluster --name edge --config ~/kind-vm2.yaml
sudo kind get kubeconfig --name edge > /tmp/kubeconfig-edge.yaml
sed -i 's|server: https://.*|server: https://172.16.4.45:6443|' /tmp/kubeconfig-edge.yaml
chmod 644 /tmp/kubeconfig-edge.yaml
```

### Environment Configuration
```bash
# Set KUBECONFIG permanently
echo 'export KUBECONFIG=/tmp/kubeconfig-edge.yaml' >> ~/.bashrc
source ~/.bashrc

# Or set for current session
export KUBECONFIG=/tmp/kubeconfig-edge.yaml
```

---

## O2IMS Components

### Overview
O2IMS (O-RAN 2 Infrastructure Management Services) operator deployed to handle provisioning requests and resource management.

### Components Deployed

#### 1. Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: o2ims-system
```

#### 2. Custom Resource Definitions
- **ProvisioningRequest** (`provisioningrequests.o2ims.oran.org`)
- **DeploymentManager** (`deploymentmanagers.o2ims.oran.org`)
- **ResourcePool** (`resourcepools.o2ims.oran.org`)

#### 3. O2IMS Controller
- Deployment with busybox placeholder
- Service exposed on NodePort 31280
- Full RBAC permissions configured

### Files Created
- `~/o2ims-operator.yaml` - Main deployment
- `~/o2ims-rbac.yaml` - RBAC configuration
- `~/o2ims-crds.yaml` - Custom Resource Definitions

### Deployment Commands
```bash
kubectl apply -f ~/o2ims-crds.yaml
kubectl apply -f ~/o2ims-operator.yaml
kubectl apply -f ~/o2ims-rbac.yaml
```

### Access Point
- **O2IMS API**: http://172.16.4.45:31280

---

## GitOps Configuration

### Repository Details
- **URL**: http://147.251.115.143:8888/admin1/edge1-config
- **Branch**: main
- **Sync Path**: /apps/intent/
- **Auth**: Token-based (Secret: gitea-token)

### RootSync Configuration

#### Script Location
`~/dev/vm2_rootsync.sh`

#### Features
- Automatic namespace creation
- Token secret management
- Git-sync deployment (RootSync CRD fallback)
- Comprehensive error handling
- Multi-directory synchronization

### Reconciler Deployment

The final reconciler configuration (`~/root-reconciler-complete.yaml`) monitors three directories:

1. **`/crds/`** - Custom Resource Definitions
2. **`/namespaces/`** - Namespace configurations
3. **`/apps/intent/`** - Application resources

#### Sync Process
```bash
# Apply token
echo '9242c0c26d74814eed70a2be48ef9a3cdb3f8d23' | ~/dev/vm2_rootsync.sh

# Or with secure input
read -s GITEA_TOKEN && echo "$GITEA_TOKEN" | ~/dev/vm2_rootsync.sh
```

### Verification Script
**Location**: `~/verify-gitops-sync.sh`

Checks:
- Config Management System status
- RootSync configuration
- Git repository connectivity
- Synced resources
- Recent sync activity

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Docker Permission Denied
```bash
# Solution 1: Add to docker group
sudo usermod -aG docker $USER
newgrp docker

# Solution 2: Use sudo
sudo kind create cluster --name edge --config ~/kind-vm2.yaml
```

#### 2. kubectl Connection Refused
```bash
# Set KUBECONFIG
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Add to bashrc for persistence
echo 'export KUBECONFIG=/tmp/kubeconfig-edge.yaml' >> ~/.bashrc
source ~/.bashrc
```

#### 3. GitOps Sync Not Working
```bash
# Check logs
kubectl logs -n config-management-system deploy/root-reconciler -c git-sync
kubectl logs -n config-management-system deploy/root-reconciler -c reconciler

# Test connectivity
curl -v http://147.251.115.143:8888

# Update token if needed
kubectl edit secret gitea-token -n config-management-system
```

#### 4. CRDs Not Found
```bash
# Check if CRDs are installed
kubectl get crd | grep nephio

# Manually apply CRDs from repository
kubectl exec -n config-management-system deploy/root-reconciler -c git-sync -- \
  cat /repo/current/crds/bundles.yaml | kubectl apply -f -
```

---

## Current Status

### ✅ Successfully Deployed

#### Infrastructure
- [x] Kind cluster running on 172.16.4.45:6443
- [x] NodePort services (31080, 31443)
- [x] Kubeconfig accessible from VM-1

#### O2IMS Components
- [x] Namespace: o2ims-system
- [x] Controller pod running
- [x] API service on port 31280
- [x] Three CRDs installed

#### GitOps Pipeline
- [x] Git-sync pulling from Gitea every 30 seconds
- [x] Token authentication configured
- [x] Multi-directory reconciliation

#### Synced Resources
- [x] CRDs: CNBundle, RANBundle, TNBundle
- [x] Namespaces: edge1, intent-to-krm
- [x] ConfigMaps: expectation-cn-cap-001, expectation-ran-perf-001, expectation-tn-cov-001

### ⚠️ Known Issues
- Bundle custom resources have schema validation errors
- CRD definitions need additional fields to match YAML specifications
- Kustomization CRD not installed

---

## Quick Reference

### Essential Commands

```bash
# Set environment
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Cluster management
kind get clusters
kubectl cluster-info
kubectl get nodes

# Check O2IMS
kubectl get pods -n o2ims-system
kubectl get svc -n o2ims-system
kubectl get crd | grep o2ims

# Check GitOps sync
kubectl logs -n config-management-system deploy/root-reconciler -c reconciler -f
kubectl get configmap -n intent-to-krm

# Verify synced resources
kubectl get crd | grep nephio
kubectl get ns | grep -E 'edge1|intent'

# Restart sync
kubectl rollout restart deploy/root-reconciler -n config-management-system
```

### Important Files

| File | Purpose |
|------|---------|
| `~/kind-vm2.yaml` | Kind cluster configuration |
| `~/dev/net_kind_vm2.sh` | Cluster deployment script |
| `~/dev/vm2_rootsync.sh` | GitOps setup script |
| `~/verify-gitops-sync.sh` | Sync verification script |
| `~/root-reconciler-complete.yaml` | Final reconciler configuration |
| `/tmp/kubeconfig-edge.yaml` | Cluster access credentials |

### Access Points

| Service | URL/Port | Description |
|---------|----------|-------------|
| Kubernetes API | https://172.16.4.45:6443 | Cluster API server |
| O2IMS API | http://172.16.4.45:31280 | O2IMS operator endpoint |
| NodePort HTTP | http://172.16.4.45:31080 | General HTTP services |
| NodePort HTTPS | https://172.16.4.45:31443 | General HTTPS services |

### GitOps Repository Structure

```
admin1/edge1-config/
├── apps/
│   └── intent/
│       ├── cn_capacity.yaml
│       ├── ran_performance.yaml
│       ├── tn_coverage.yaml
│       ├── namespace.yaml
│       └── kustomization.yaml
├── crds/
│   ├── bundles.yaml
│   └── intent-to-krm-namespace.yaml
└── namespaces/
    └── edge1-namespace.yaml
```

---

## Summary

The VM-2 edge cluster deployment is complete and operational with:

1. **Kind Kubernetes cluster** bound to 172.16.4.45:6443
2. **O2IMS operator** for provisioning request handling
3. **GitOps pipeline** syncing from Gitea repository
4. **KRM resources** partially applied (ConfigMaps successful, Bundles need schema fixes)

The system automatically synchronizes configurations from the Gitea repository every 30 seconds, applying CRDs, namespaces, and application resources in the correct order.

---

*Document Generated: 2025-09-07*  
*Location: VM-2 (172.16.4.45)*  
*Cluster: edge*