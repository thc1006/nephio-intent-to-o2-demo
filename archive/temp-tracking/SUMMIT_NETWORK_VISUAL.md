# 🎯 Summit Network Visual Guide

**Quick Reference for Presenters**
**Summit Date**: 2025-09-16

---

## 🌐 One-Page Network Overview

```
┌─────────────────────────────────────────────────────────┐
│                    PUBLIC ACCESS                         │
│  Gitea: 147.251.115.143:8888   LLM: 147.251.115.156:5000│
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│              INTERNAL NETWORK (172.16.0.0/12)           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  VM-1 (SMO)           VM-3 (LLM)                        │
│  172.16.0.78          172.16.2.10                       │
│  • Gitea:8888         • Web UI:5000                     │
│  • Operator:8080      • Intent API                      │
│  • Prometheus:9090                                      │
│       │                                                  │
│       ├──────────────────────────────┐                  │
│       ↓                              ↓                  │
│  VM-2 (Edge1)                   VM-4 (Edge2)            │
│  172.16.4.45                    172.16.4.176            │
│  • O2IMS:31280 ✅               • O2IMS:31280 ✅        │
│  • SLO:31080 ✅                 • SLO:31080 ✅          │
│  • Metrics:30090 ✅             • Metrics:30090 ✅      │
│  • SSL:31443 ❌                 • SSL:31443 ❌          │
└─────────────────────────────────────────────────────────┘
```

## ⚡ Critical Services Status

| Service | Port | VM-1 | VM-2 | VM-3 | VM-4 |
|---------|------|------|------|------|------|
| **Gitea** | 8888 | ✅ | - | - | - |
| **LLM UI** | 5000 | - | - | ✅ | - |
| **O2IMS** | 31280 | - | ✅ | - | ✅ |
| **SLO Mon** | 31080 | - | ✅ | - | ✅ |
| **Metrics** | 30090 | - | ✅ | - | ✅ |
| **K8s API** | 6443 | ✅ | ✅ | - | ✅ |

## 🔄 Demo Flow (3 Minutes)

### 1️⃣ Intent Submission (30 sec)
```
User → http://172.16.2.10:5000 → "Deploy 5G slice"
```

### 2️⃣ Processing (60 sec)
```
LLM → Operator → Git → Config Sync → Edge Sites
```

### 3️⃣ Validation (60 sec)
```
O2IMS Deploy → SLO Check → Success/Rollback
```

### 4️⃣ Result (30 sec)
```
Dashboard → Show deployment → Metrics OK
```

## 🚨 Quick Fixes

### If O2IMS Down:
```bash
ssh ubuntu@172.16.4.45
kubectl rollout restart deployment -n o2ims-system
```

### If GitOps Not Syncing:
```bash
kubectl --context edge1 annotate rootsync root-sync \
  -n config-management-system sync.gke.io/force=true --overwrite
```

### If Operator Stuck:
```bash
kubectl --context kind-nephio-demo rollout restart \
  deployment -n intent-operator-system
```

## 📋 Pre-Demo Checklist

```bash
# Run this 5 minutes before demo
#!/bin/bash
echo "=== SUMMIT DEMO CHECK ==="

# 1. Check Gitea
curl -s http://172.16.0.78:8888 | grep -q Gitea && \
  echo "✅ Gitea OK" || echo "❌ Gitea FAILED"

# 2. Check LLM UI
curl -s http://172.16.2.10:5000 > /dev/null && \
  echo "✅ LLM UI OK" || echo "❌ LLM UI FAILED"

# 3. Check Edge1 O2IMS
curl -s http://172.16.4.45:31280/healthz | grep -q healthy && \
  echo "✅ Edge1 O2IMS OK" || echo "❌ Edge1 O2IMS FAILED"

# 4. Check Edge2 O2IMS
curl -s http://172.16.4.176:31280/ | grep -q operational && \
  echo "✅ Edge2 O2IMS OK" || echo "❌ Edge2 O2IMS FAILED"
```

## 🎯 Key Talking Points

### Architecture
- **4-VM distributed system**
- **GitOps-driven deployment**
- **Automatic SLO validation**
- **Intent-driven orchestration**

### Innovation
- **Natural language → Network config**
- **TMF921 standard compliance**
- **O-RAN O2 interface**
- **Automatic rollback on SLO breach**

### Performance
- **<100ms API latency (P95)**
- **30-second GitOps sync**
- **5-minute end-to-end deployment**
- **99.9% availability SLO**

## ⚠️ Known Limitations (If Asked)

1. **No SSL/TLS** - Using HTTP for demo simplicity
2. **Edge2 SSH blocked** - Security policy limitation
3. **Mock LLM** - Not using real AI model
4. **Single region** - All VMs in same datacenter

## 🔧 Emergency Contacts

- **VM-1 Console**: If network fails completely
- **GitHub Backup**: https://github.com/thc1006/nephio-intent-to-o2-demo
- **Checkpoint Tag**: v1.1.1 (last known good)

## 📝 Q&A Quick Answers

**Q: Why no SSL on port 31443?**
A: Demo uses HTTP for simplicity, production would have TLS.

**Q: What's the latency?**
A: <100ms P95 for API calls, 30s for GitOps sync.

**Q: How does rollback work?**
A: Automatic on SLO breach, uses git revert.

**Q: What standards are used?**
A: TMF921 for intents, 3GPP TS 28.312, O-RAN O2.

**Q: Can it scale?**
A: Yes, supports multiple edge sites, horizontal scaling.

---

**REMEMBER**:
- Port 31443 (SSL) is intentionally not configured
- O2IMS healthz has been fixed and works
- All services use HTTP (not HTTPS)
- This is the authoritative network reference

---

*Print this page for summit reference*