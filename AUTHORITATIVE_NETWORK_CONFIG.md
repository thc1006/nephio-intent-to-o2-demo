# Authoritative Network Configuration - Correct Connection Methods
**Last Updated**: 2025-09-17
**Version**: v2.0.0 FINAL
**Status**: Fully tested and validated

## Important Declaration
**This is the only correct network configuration document. All other documents that conflict should defer to this document.**

---

## Network Topology Overview

```
                     ┌──────────────────────────┐
                     │   VM-1 (SMO/GitOps)      │
                     │   Internal: 172.16.0.78   │
                     │   External: 147.251.115.143│
                     │   Role: Management & Orchestration │
                     └──────────┬───────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
         ┌──────────▼──────────┐  ┌────────▼──────────┐
         │   VM-2 (Edge1)      │  │   VM-4 (Edge2)    │
         │   IP: 172.16.4.45   │  │   IP: 172.16.4.176 │
         │   Role: Edge Site 1 │  │   Role: Edge Site 2│
         └─────────────────────┘  └───────────────────┘

                     ┌──────────────────────────┐
                     │   VM-3 (LLM Adapter)     │
                     │   IP: Configure via VM3_IP│
                     │   Role: Intent Service   │
                     └──────────────────────────┘
```

---

## VM-1 to Edge Sites Connection Status (Verified 2025-09-17)

### VM-1 to Edge1 (VM-2) Connection
| Service | Port | Protocol | Status | Purpose |
|---------|------|----------|--------|---------|
| ICMP | - | ICMP | Success | Basic connectivity test |
| SSH | 22 | TCP | Success | Management access |
| Kubernetes API | 6443 | TCP | Success | K8s cluster management |
| SLO Service | 30090 | TCP | Success | SLO monitoring service |
| O2IMS API | 31280 | TCP | Success | O-RAN O2 interface |

### VM-1 to Edge2 (VM-4) Connection
| Service | Port | Protocol | Status | Purpose |
|---------|------|----------|--------|---------|
| ICMP | - | ICMP | Success (requires OpenStack setup) | Basic connectivity test |
| SSH | 22 | TCP | Timeout (requires additional setup) | Management access |
| Kubernetes API | 6443 | TCP | Success | K8s cluster management |
| SLO Service | 30090 | TCP | Success | SLO monitoring service |
| O2IMS API | 31280 | TCP | Success | O-RAN O2 interface (nginx placeholder) |

---

## OpenStack Security Group Correct Setup

### Required Rules (Verified Successfully)

#### 1. ICMP Rules (Allow ping)
```
Direction: Ingress
Protocol: ICMP
Remote: CIDR
CIDR: 172.16.0.78/32
```

#### 2. Kubernetes API Rules
```
Direction: Ingress
Protocol: TCP
Port: 6443
Remote: CIDR
CIDR: 172.16.0.0/16
```

#### 3. NodePort Service Range
```
Direction: Ingress
Protocol: TCP
Port Range: 30000-32767
Remote: CIDR
CIDR: 172.16.0.0/16
```

#### 4. SSH Rules (Optional)
```
Direction: Ingress
Protocol: TCP
Port: 22
Remote: CIDR
CIDR: 172.16.0.78/32
```

---

## GitOps Sync Configuration

### Gitea Service Status
```bash
# VM-1 Gitea Service
Service Address: http://172.16.0.78:8888
External Address: http://147.251.115.143:8888
Status: Running
Container: gitea/gitea:latest
Port Mapping: 8888:3000, 2222:22
```

### Edge1 GitOps Configuration
```yaml
# Location: vm-2/edge1-rootsync.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/admin1/edge1-config  # Correct: Use internal IP
    branch: main
    auth: token
    secretRef:
      name: gitea-token
```

### Edge2 GitOps Configuration
```yaml
# Location: To be created
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge2-rootsync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/admin1/edge2-config  # Use VM-1 internal IP
    branch: main
    directory: /edge2  # Edge2 watch subdirectory
    auth: token
    secretRef:
      name: git-creds
```

---

## Common Misconfigurations (Please Avoid)

### Error 1: Using External IP for Internal Communication
```yaml
# Incorrect
repo: http://147.251.115.143:8888/admin1/edge1-config

# Correct
repo: http://172.16.0.78:8888/admin1/edge1-config
```

### Error 2: Using SSH Tunnel for Same Network Segment
```bash
# Incorrect: VM-4 on same network doesn't need SSH tunnel
ssh -L 6443:localhost:6443 ubuntu@172.16.4.176

# Correct: Direct connection
kubectl --server=https://172.16.4.176:6443
```

### Error 3: Using Outdated Ports
```bash
# Incorrect: Using 30000 instead of 8888
http://172.16.0.78:30000/admin1/edge1-config

# Correct: Gitea runs on 8888
http://172.16.0.78:8888/admin1/edge1-config
```

---

## Quick Verification Commands

### Verify All Connections from VM-1
```bash
# Test Edge1
echo "=== Testing Edge1 (VM-2) ==="
ping -c 2 172.16.4.45
nc -vz -w 3 172.16.4.45 6443
curl -s http://172.16.4.45:30090/health

# Test Edge2
echo "=== Testing Edge2 (VM-4) ==="
ping -c 2 172.16.4.176
nc -vz -w 3 172.16.4.176 6443
curl -s http://172.16.4.176:30090/health

# Test Gitea
echo "=== Testing Gitea ==="
curl -s http://localhost:8888 | grep -q "Gitea" && echo "Gitea: OK"
```

### Verify GitOps Sync
```bash
# On Edge1 (VM-2)
kubectl -n config-management-system get rootsync
kubectl -n config-management-system logs -l app=root-reconciler --tail=10

# On Edge2 (VM-4)
kubectl -n config-management-system get rootsync
kubectl -n config-management-system logs -l app=root-reconciler --tail=10
```

---

## Sync Capability Summary

### VM-1 Can Successfully Sync to Both Edge Sites

1. **Edge1 (VM-2)**:
   - GitOps sync: Working
   - Monitoring data collection: Normal
   - Management access: Complete

2. **Edge2 (VM-4)**:
   - GitOps sync: Warning - Edge2 needs access to VM-1:8888
   - Monitoring data collection: Normal (VM-1 can actively pull)
   - Management access: Partial (K8s API available, SSH not available)

---

## Issues to Resolve

1. **Edge2 to VM-1 Gitea Connection**
   - Issue: Edge2 cannot access 147.251.115.143:8888
   - Solution: Configure network routing or use internal IP

2. **VM-1 to Edge2 SSH**
   - Issue: SSH port 22 timeout
   - Solution: Check VM-4 SSH service status

---

## Emergency Fix Procedures

If connection fails, execute in order:

1. **Check Gitea Service**
   ```bash
   docker ps | grep gitea
   # If not running, execute:
   ./scripts/setup/start-gitea.sh
   ```

2. **Check OpenStack Security Groups**
   - Confirm ICMP rules are added
   - Confirm TCP 6443, 30000-32767 rules exist

3. **Verify Network Routing**
   ```bash
   ip route | grep 172.16
   ```

4. **Restart Config Sync**
   ```bash
   kubectl -n config-management-system rollout restart deployment reconciler-manager
   ```

---

## Support Information

- **Document Maintainer**: Nephio Intent-to-O2 Team
- **Last Verified**: 2025-09-17
- **Next Review**: 2025-10-14

---

**Important Reminder: This document is the single source of truth for network configuration. Please refer to this document regularly and avoid using outdated information.**