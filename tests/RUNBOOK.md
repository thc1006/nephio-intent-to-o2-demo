# Nephio Intent-to-O2 Demo Runbook

**Version:** 1.0.0
**Last Updated:** 2025-09-13
**Target Recovery Time:** 5 minutes

## Quick Start - Emergency Recovery

### 🚨 5-Minute Emergency Fix Playbook

**When:** System is completely down, demo needs to work in 5 minutes

1. **Check VM connectivity** (30 seconds)
   ```bash
   ping 172.16.4.45  # VM-2 Edge1
   ping 172.16.0.78  # VM-1 LLM Adapter
   ```

2. **Verify core services** (60 seconds)
   ```bash
   curl -s http://172.16.4.45:31080/health
   curl -s http://172.16.0.78:8888/health
   ```

3. **Restart critical components** (90 seconds)
   ```bash
   kubectl --context edge1 rollout restart deployment -n config-management-system
   ./scripts/demo_llm.sh --target edge1 --dry-run
   ```

4. **Validate pipeline** (120 seconds)
   ```bash
   ./scripts/postcheck.sh --sites=edge1
   ```

**If still failing:** Jump to [Common Failures](#common-failures) section below.

## Network Architecture

### VM Infrastructure
| VM | Role | IP Address | Key Ports |
|----|------|------------|-----------|
| VM-1 | SMO/GitOps Orchestrator | localhost | - |
| VM-2 | Edge1 Cluster | 172.16.4.45 | 6443, 31080, 31443, 31280 |
| VM-1 | LLM Adapter | 172.16.0.78 | 8888 |
| VM-4 | Edge2 Cluster | TBD | 6443, 31080, 31443, 31280 |

### Port Reference
| Port | Service | Purpose | VM |
|------|---------|---------|-----|
| 6443 | Kubernetes API | Cluster management | VM-2, VM-4 |
| 31080 | HTTP NodePort | Application access | VM-2, VM-4 |
| 31443 | HTTPS NodePort | Secure application access | VM-2, VM-4 |
| 31280 | O2IMS API | O-RAN O2 Interface | VM-2, VM-4 |
| 8888 | LLM Adapter | Intent processing | VM-1 |

## Common Failures

### 1. LLM Adapter Unreachable (VM-1)
**Symptoms:** demo_llm.sh fails at "check-llm" step
```bash
# Diagnosis
ping 172.16.0.78
curl http://172.16.0.78:8888/health

# 5-min fix
ssh vm1_integrated "sudo systemctl restart llm-adapter"
./scripts/demo_llm.sh --target edge1 --dry-run
```

### 2. Edge1 Kubernetes API Down  
**Symptoms:** kubectl commands timeout, 6443 unreachable
```bash
# 5-min fix
ssh vm2 "sudo systemctl restart kubelet containerd"
sleep 60 && kubectl --context edge1 get nodes
```

### 3. O2IMS API Not Responding
**Symptoms:** 31280 unreachable, postcheck fails
```bash
# 5-min fix  
kubectl --context edge1 -n o2ims rollout restart deployment o2ims-api
```

---
**Emergency Contact:** On-call engineer
