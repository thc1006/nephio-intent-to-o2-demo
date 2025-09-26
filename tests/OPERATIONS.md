# Operations Manual - Nephio Intent-to-O2 Demo

**Version:** 1.0.0
**Last Updated:** 2025-09-13

## Edge Switching Operations

### 5-Minute Edge Switch Procedure

**Scenario:** Switch demo from edge1 to edge2 or both

1. **Pre-switch validation** (60 seconds)
   ```bash
   # Check current edge status
   ./scripts/postcheck.sh --sites=edge1
   curl http://172.16.4.45:31280/o2ims/api/v1/health
   ```

2. **Execute switch** (120 seconds)
   ```bash
   # Switch to edge2 (requires VM-4 IP)
   ./scripts/demo_llm.sh --target edge2 --vm4-ip <VM4_IP>
   
   # Or switch to both
   ./scripts/demo_llm.sh --target both --vm4-ip <VM4_IP>
   ```

3. **Post-switch validation** (120 seconds)
   ```bash
   # Verify new target
   ./scripts/postcheck.sh --sites=edge2
   curl http://<VM4_IP>:31280/o2ims/api/v1/health
   ```

## Daily Operations Checklist

### Morning Startup (First demo of day)
- [ ] **VM connectivity check**
  ```bash
  ping 172.16.4.45 && ping 172.16.0.78  
  ```
- [ ] **Service health validation**
  ```bash
  curl http://172.16.4.45:31080/health
  curl http://172.16.0.78:8888/health
  ```
- [ ] **Demo pipeline test**  
  ```bash
  ./scripts/demo_llm.sh --dry-run --target edge1
  ```
- [ ] **Performance baseline**
  ```bash
  ./scripts/postcheck.sh --sites=edge1
  ```

### Between Demos (5-minute reset)
- [ ] **Clean previous state**
  ```bash
  rm -rf artifacts/demo-llm/*
  ```
- [ ] **Reset RootSync if needed**
  ```bash  
  kubectl --context edge1 get rootsync -n config-management-system
  ```
- [ ] **Quick health check**
  ```bash
  curl -s http://172.16.4.45:31080/health | jq .status
  ```

## Common Operational Scenarios

### Demo Preparation
**Time Required:** 10 minutes

1. **Environment validation**
   ```bash
   # Check all required IPs/ports
   nc -zv 172.16.4.45 6443   # K8s API
   nc -zv 172.16.4.45 31080  # HTTP
   nc -zv 172.16.4.45 31280  # O2IMS  
   nc -zv 172.16.0.78 8888   # LLM
   ```

2. **Pre-demo testing**
   ```bash
   # Test intent generation
   curl -X POST http://172.16.0.78:8888/intent \
     -d '{"query": "test demo readiness"}'
   
   # Test KRM rendering
   ./scripts/render_krm.sh tests/golden/intent_edge1.json
   ```

### Multi-Site Demo Setup
**For demonstrations involving both edge1 and edge2**

1. **Verify dual-site connectivity**
   ```bash
   ping 172.16.4.45  # Edge1
   ping <VM4_IP>     # Edge2 (update when VM-4 deployed)
   ```

2. **Configure routing**
   ```bash
   # Test both targets
   ./scripts/demo_llm.sh --dry-run --target both --vm4-ip <VM4_IP>
   ```

3. **Validate dual-site metrics**
   ```bash
   ./scripts/postcheck.sh --sites=edge1,edge2
   ```

## Performance Monitoring

### Key Performance Indicators
| Metric | Threshold | Check Command |
|--------|-----------|---------------|
| Intent Generation Time | < 10s | `time curl http://172.16.0.78:8888/intent` |
| KRM Render Time | < 30s | `time ./scripts/render_krm.sh intent.json` |
| RootSync Reconciliation | < 60s | `kubectl get rootsync -w` |
| SLO Response Time | < 5s | `time curl http://172.16.4.45:30090/metrics/api/v1/slo` |

### Performance Degradation Response
**When response times exceed thresholds:**

1. **Immediate actions**
   ```bash
   # Check resource usage
   ssh vm2 "top -bn1 | head -10"
   ssh vm1_integrated "free -h && df -h"
   ```

2. **Service restart if needed**
   ```bash
   # LLM adapter restart
   ssh vm1_integrated "sudo systemctl restart llm-adapter"
   
   # K8s service restart  
   kubectl --context edge1 rollout restart deployment -n target-namespace
   ```

## Maintenance Procedures

### Weekly Maintenance
**Sunday 02:00-04:00 UTC**

- [ ] **Log rotation and cleanup**
  ```bash
  find ./logs -name "*.log" -mtime +7 -delete
  find ./artifacts -name "*.tar.gz" -mtime +30 -delete
  ```
- [ ] **Configuration backup**
  ```bash
  tar -czf backup/config-$(date +%Y%m%d).tar.gz gitops/ tests/golden/
  ```
- [ ] **Health check all endpoints**
- [ ] **Performance benchmark**
- [ ] **Update monitoring dashboards**

### VM-4 Edge2 Deployment Checklist
**When Edge2 becomes available:**

1. **Update documentation**
   - [ ] Replace `<VM4_IP>` placeholders with actual IP
   - [ ] Update port references (6443, 31080, 31443, 31280)
   - [ ] Test all dual-site procedures

2. **Configuration updates**
   ```bash
   # Update demo scripts with VM-4 IP
   sed -i 's/<VM4_IP>/ACTUAL_IP/g' scripts/*.sh
   
   # Update postcheck configuration
   # Update gitops/edge2-config/ with proper endpoints
   ```

## Common Failures & 5-Min Fixes

### Scenario 1: Complete Demo Failure
**Symptoms:** Everything broken, audience waiting

**5-minute fix:**
```bash
# Step 1: Reset to known state (60s)
git checkout main && git pull

# Step 2: Restart all services (120s)  
ssh vm2 "sudo systemctl restart kubelet"
ssh vm1_integrated "sudo systemctl restart llm-adapter"

# Step 3: Quick validation (120s)
sleep 60 && ./scripts/demo_llm.sh --dry-run --target edge1

# Step 4: Go-live decision (30s)
./scripts/postcheck.sh --sites=edge1
```

### Scenario 2: Partial Edge Failure
**Symptoms:** One edge works, other doesn't

**5-minute fix:**
```bash  
# Identify working edge
curl http://172.16.4.45:31080/health  # edge1
curl http://<VM4_IP>:31080/health     # edge2

# Switch demo to working edge
./scripts/demo_llm.sh --target edge1  # or edge2

# Inform audience of single-site demo
```

### Scenario 3: LLM Adapter Down
**Symptoms:** Intent generation fails at VM-1

**5-minute fix:**
```bash
# Quick restart
ssh vm1_integrated "sudo systemctl restart llm-adapter"

# Wait and test
sleep 30 && curl http://172.16.0.78:8888/health

# If still down, use cached intent
cp tests/golden/intent_edge1.json /tmp/fallback_intent.json
./scripts/render_krm.sh /tmp/fallback_intent.json --target edge1
```

## Escalation Matrix

| Issue Severity | Response Time | Contact |
|---------------|---------------|---------|
| Demo-blocking | Immediate | Team Lead + Platform Engineer |  
| Performance degradation | 15 minutes | Platform Engineer |
| Partial failure | 30 minutes | On-call Engineer |
| Planned maintenance | 24 hours notice | All stakeholders |

---
**Contact Information:**
- **Team Lead:** Immediate escalation required
- **Platform Engineer:** Infrastructure and VM issues  
- **On-call Engineer:** After-hours support (24/7)
