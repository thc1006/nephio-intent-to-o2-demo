# RUNBOOK.md — Operational Runbook for Nephio Intent-to-O2 Demo Platform

## Quick Reference Card

| Component | Location | Primary Port | Health Check |
|-----------|----------|--------------|--------------|
| SMO/GitOps | VM-1 | N/A | `git status` |
| Edge1 API | VM-2 (172.16.4.45) | 6443 | `kubectl --kubeconfig edge1 get nodes` |
| Edge1 HTTP | VM-2 (172.16.4.45) | 31080 | `curl http://172.16.4.45:31080/health` |
| Edge1 HTTPS | VM-2 (172.16.4.45) | 31443 | `curl -k https://172.16.4.45:31443/health` |
| O2IMS | VM-2 (172.16.4.45) | 31280 | `curl http://172.16.4.45:31280/o2ims/api/v1/health` |
| LLM Adapter | VM-1 | 8888 | `curl http://<VM1_IP>:8888/health` |
| Edge2 API | VM-4 | TBD | `kubectl --kubeconfig edge2 get nodes` |

---

## 1. Quick Troubleshooting Guide (5-Minute Fixes)

### 1.1 Common Issues Decision Tree

```
Issue: Demo pipeline fails
├── LLM Adapter unreachable
│   ├── Check VM-1 service: systemctl status llm-adapter
│   ├── Check port 8888: netstat -tlnp | grep 8888
│   └── Restart: systemctl restart llm-adapter
├── Edge cluster unreachable
│   ├── Check kubeconfig: kubectl --kubeconfig edge1 get nodes
│   ├── Check API server: curl -k https://172.16.4.45:6443/healthz
│   └── Restart kubelet: systemctl restart kubelet
├── GitOps sync failed
│   ├── Check RootSync: kubectl get rootsync -A
│   ├── Check Config Sync logs: kubectl logs -n config-management-system -l app=reconciler-manager
│   └── Force sync: kubectl annotate rootsync root-sync configsync.gke.io/sync-token=$(date +%s) -n config-management-system
└── Intent rendering failed
    ├── Check kpt functions: kpt fn render --dry-run
    ├── Check schema validation: jsonschema -i intent.json schema.json
    └── Reset workspace: git clean -fd && git checkout .
```

### 1.2 Service Restart Procedures

#### VM-1 (SMO) Service Restart
```bash
# Gitea service
sudo systemctl restart gitea
sudo systemctl status gitea

# Check repository access
cd /home/ubuntu/nephio-intent-to-o2-demo
git status
git remote -v
```

#### VM-2 (Edge1) Service Restart
```bash
# Kubernetes services
sudo systemctl restart kubelet
sudo systemctl restart containerd

# Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running
```

#### VM-1 Service Restart
```bash
# LLM Adapter service
sudo systemctl restart llm-adapter
sudo systemctl status llm-adapter

# Manual start if needed
cd /opt/llm-adapter
python3 -m uvicorn main:app --host 0.0.0.0 --port 8888 &
```

#### VM-4 (Edge2) Service Restart
```bash
# Similar to Edge1
sudo systemctl restart kubelet
sudo systemctl restart containerd
kubectl get nodes
```

### 1.3 Log Locations and Interpretation

| Service | Log Location | Key Patterns |
|---------|--------------|--------------|
| GitOps Pipeline | `/var/log/demo_llm.log` | `ERROR`, `FAIL`, `rollback` |
| LLM Adapter | `/var/log/llm-adapter.log` | `connection refused`, `timeout` |
| Kubernetes | `journalctl -u kubelet` | `failed to start`, `node not ready` |
| Config Sync | `kubectl logs -n config-management-system` | `sync error`, `apply failed` |
| O2IMS | `/var/log/o2ims.log` | `endpoint unreachable`, `auth failed` |

**Log Analysis Commands:**
```bash
# Last 100 lines with errors
tail -100 /var/log/demo_llm.log | grep -E "(ERROR|FAIL)"

# Real-time monitoring
tail -f /var/log/demo_llm.log

# Kubernetes events
kubectl get events --sort-by='.lastTimestamp' -A
```

---

## 2. Network Configuration

### 2.1 Complete IP/Port Mapping

#### VM-1 (SMO/GitOps Orchestrator)
- **Role**: Central SMO, Workflow Control, KRM Rendering, GitOps Publisher
- **Private IP**: TBD (update after deployment)
- **Services**:
  - Gitea Repository: Port 3000 (internal)
  - SSH: Port 22
  - Demo Pipeline: No exposed ports

#### VM-2 (Edge1 Cluster)
- **Private IP**: 172.16.4.45
- **Services**:
  - Kubernetes API: `https://172.16.4.45:6443`
  - HTTP NodePort: `http://172.16.4.45:31080`
  - HTTPS NodePort: `https://172.16.4.45:31443`
  - O2IMS API: `http://172.16.4.45:31280`
  - SSH: Port 22

#### VM-1
- **Private IP**: TBD (referenced as `<VM1_IP>`)
- **Services**:
  - LLM Adapter API: `http://<VM1_IP>:8888`
  - Health Endpoint: `http://<VM1_IP>:8888/health`
  - SSH: Port 22

#### VM-4 (Edge2 Cluster)
- **Private IP**: TBD (update after deployment)
- **Services**:
  - Kubernetes API: `https://<VM4_IP>:6443`
  - HTTP NodePort: `http://<VM4_IP>:31080`
  - HTTPS NodePort: `https://<VM4_IP>:31443`
  - SSH: Port 22

### 2.2 Network Connectivity Matrix

| From | To | Port | Protocol | Purpose |
|------|----|----- |----------|---------|
| VM-1 | VM-2 | 6443 | HTTPS | Kubernetes API |
| VM-1 | VM-2 | 31280 | HTTP | O2IMS API |
| VM-1 | VM-1 | 8888 | HTTP | LLM Adapter |
| VM-1 | VM-4 | 6443 | HTTPS | Kubernetes API |
| VM-2 | VM-1 | 22 | SSH | Git operations |
| VM-4 | VM-1 | 22 | SSH | Git operations |

### 2.3 Firewall Configuration Check
```bash
# Check open ports
sudo netstat -tlnp | grep -E "(6443|31080|31443|31280|8888)"

# Verify iptables rules
sudo iptables -L -n | grep -E "(6443|31080|31443|31280|8888)"

# Test connectivity
curl -k https://172.16.4.45:6443/healthz
curl http://172.16.4.45:31280/o2ims/api/v1/health
curl http://<VM1_IP>:8888/health
```

---

## 3. Emergency Procedures

### 3.1 Service Failure Recovery

#### Complete Demo Pipeline Failure
```bash
# Step 1: Check all components
./scripts/health_check.sh

# Step 2: Emergency rollback
./scripts/rollback.sh

# Step 3: Reset to known good state
git checkout main
git pull origin main
./scripts/demo_llm.sh --reset

# Step 4: Verify recovery
./scripts/postcheck.sh
```

#### LLM Adapter Service Failure
```bash
# Quick restart
ssh VM-1 "sudo systemctl restart llm-adapter"

# Manual recovery
ssh VM-1 "cd /opt/llm-adapter && python3 -m uvicorn main:app --host 0.0.0.0 --port 8888 --reload"

# Fallback to mock adapter
export LLM_ADAPTER_URL="http://localhost:8889"  # Mock service
./scripts/demo_llm.sh --mock-llm
```

#### Edge Cluster Failure
```bash
# Edge1 recovery
ssh VM-2 "sudo systemctl restart kubelet containerd"
kubectl --kubeconfig configs/edge1-kubeconfig get nodes

# Edge2 recovery
ssh VM-4 "sudo systemctl restart kubelet containerd"
kubectl --kubeconfig configs/edge2-kubeconfig get nodes

# Force pod restart
kubectl --kubeconfig configs/edge1-kubeconfig delete pods -l app=problematic-app
```

### 3.2 Rollback Procedures

#### Automated Rollback
```bash
# Demo pipeline rollback
./scripts/demo_llm.sh --rollback

# GitOps rollback to previous commit
./scripts/rollback.sh --commit-hash <previous_commit>

# Emergency stop all operations
./scripts/emergency_stop.sh
```

#### Manual Rollback Steps
```bash
# 1. Identify last known good commit
git log --oneline -10

# 2. Rollback Git repository
git revert <bad_commit_hash>

# 3. Force GitOps sync
kubectl annotate rootsync root-sync configsync.gke.io/sync-token=$(date +%s) -n config-management-system

# 4. Verify rollback
./scripts/postcheck.sh --verify-rollback
```

### 3.3 Data Backup/Restore

#### Repository Backup
```bash
# Create backup
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz /home/ubuntu/nephio-intent-to-o2-demo

# Restore from backup
tar -xzf backup-YYYYMMDD-HHMMSS.tar.gz -C /
```

#### Configuration Backup
```bash
# Backup cluster configs
cp -r configs/ backups/configs-$(date +%Y%m%d)/

# Backup generated artifacts
cp -r reports/ backups/reports-$(date +%Y%m%d)/

# Restore configurations
cp -r backups/configs-YYYYMMDD/* configs/
```

---

## 4. Health Checks

### 4.1 Component Verification Commands

#### SMO/GitOps Health Check
```bash
#!/bin/bash
# File: scripts/health_check_smo.sh

echo "=== SMO Health Check ==="

# Git repository health
if git status >/dev/null 2>&1; then
    echo "✓ Git repository accessible"
else
    echo "✗ Git repository issues"
    exit 1
fi

# Gitea service health
if systemctl is-active --quiet gitea; then
    echo "✓ Gitea service running"
else
    echo "✗ Gitea service down"
    exit 1
fi

# Demo scripts executable
if [ -x "./scripts/demo_llm.sh" ]; then
    echo "✓ Demo scripts accessible"
else
    echo "✗ Demo scripts missing or not executable"
    exit 1
fi

echo "SMO health check passed"
```

#### Edge Cluster Health Check
```bash
#!/bin/bash
# File: scripts/health_check_edge.sh

EDGE_CONFIG=${1:-"configs/edge1-kubeconfig"}
EDGE_NAME=${2:-"edge1"}

echo "=== $EDGE_NAME Health Check ==="

# API server connectivity
if kubectl --kubeconfig $EDGE_CONFIG get nodes >/dev/null 2>&1; then
    echo "✓ $EDGE_NAME API server accessible"
else
    echo "✗ $EDGE_NAME API server unreachable"
    exit 1
fi

# Node readiness
NOT_READY=$(kubectl --kubeconfig $EDGE_CONFIG get nodes --no-headers | grep -v Ready | wc -l)
if [ $NOT_READY -eq 0 ]; then
    echo "✓ All $EDGE_NAME nodes ready"
else
    echo "✗ $NOT_READY nodes not ready in $EDGE_NAME"
    kubectl --kubeconfig $EDGE_CONFIG get nodes
    exit 1
fi

# Critical pods running
FAILED_PODS=$(kubectl --kubeconfig $EDGE_CONFIG get pods -A --no-headers | grep -v Running | grep -v Completed | wc -l)
if [ $FAILED_PODS -eq 0 ]; then
    echo "✓ All critical pods running in $EDGE_NAME"
else
    echo "✗ $FAILED_PODS pods failing in $EDGE_NAME"
    kubectl --kubeconfig $EDGE_CONFIG get pods -A | grep -v Running | grep -v Completed
fi

echo "$EDGE_NAME health check passed"
```

#### LLM Adapter Health Check
```bash
#!/bin/bash
# File: scripts/health_check_llm.sh

LLM_URL=${LLM_ADAPTER_URL:-"http://<VM1_IP>:8888"}

echo "=== LLM Adapter Health Check ==="

# Service reachability
if curl -s --max-time 5 "$LLM_URL/health" >/dev/null; then
    echo "✓ LLM Adapter reachable at $LLM_URL"
else
    echo "✗ LLM Adapter unreachable at $LLM_URL"
    exit 1
fi

# API functionality
if curl -s --max-time 10 -X POST "$LLM_URL/test" -H "Content-Type: application/json" -d '{"test": true}' | grep -q "ok"; then
    echo "✓ LLM Adapter API functional"
else
    echo "✗ LLM Adapter API not responding correctly"
    exit 1
fi

echo "LLM Adapter health check passed"
```

### 4.2 SLO Monitoring Endpoints

#### SLO Metrics Collection
```bash
#!/bin/bash
# File: scripts/collect_slo_metrics.sh

echo "=== Collecting SLO Metrics ==="

# Edge1 SLO metrics
echo "Edge1 SLO:"
curl -s "http://172.16.4.45:31080/metrics/api/v1/slo" | jq '.'

# Edge2 SLO metrics (when available)
echo "Edge2 SLO:"
curl -s "http://<VM4_IP>:31080/metrics/api/v1/slo" | jq '.'

# O2IMS measurement data
echo "O2IMS Measurements:"
curl -s "http://172.16.4.45:31280/o2ims/api/v1/measurements" | jq '.'

# Generate SLO report
./scripts/postcheck.sh --slo-only > reports/slo-$(date +%Y%m%d-%H%M%S).json
```

### 4.3 O2IMS Probe Procedures

#### Complete O2IMS Health Check
```bash
#!/bin/bash
# File: scripts/o2ims_probe.sh

O2IMS_BASE="http://172.16.4.45:31280/o2ims/api/v1"

echo "=== O2IMS Probe ==="

# Health endpoint
if curl -s --max-time 5 "$O2IMS_BASE/health" | grep -q "healthy"; then
    echo "✓ O2IMS service healthy"
else
    echo "✗ O2IMS service unhealthy"
    exit 1
fi

# Resource types endpoint
if curl -s "$O2IMS_BASE/resourceTypes" | jq -e '.[] | select(.name)' >/dev/null; then
    echo "✓ O2IMS resource types available"
else
    echo "✗ O2IMS resource types unavailable"
fi

# Resource pools endpoint
if curl -s "$O2IMS_BASE/resourcePools" | jq -e '.[] | select(.name)' >/dev/null; then
    echo "✓ O2IMS resource pools available"
else
    echo "✗ O2IMS resource pools unavailable"
fi

# Measurements endpoint
if curl -s "$O2IMS_BASE/measurements" | jq -e '.[] | select(.name)' >/dev/null; then
    echo "✓ O2IMS measurements available"
else
    echo "! O2IMS measurements may be empty (not necessarily error)"
fi

echo "O2IMS probe completed"
```

---

## 5. Incident Response

### 5.1 Escalation Paths

#### Severity Levels

**P0 (Critical) - Demo completely down**
- Contact: Platform team lead immediately
- Action: Execute emergency procedures within 5 minutes
- Communication: Update stakeholders every 15 minutes

**P1 (High) - Single component failure**
- Contact: On-call engineer within 15 minutes
- Action: Implement workarounds, scheduled fix within 1 hour
- Communication: Update stakeholders every 30 minutes

**P2 (Medium) - Performance degradation**
- Contact: Assign to team during business hours
- Action: Root cause analysis, fix within 4 hours
- Communication: Daily updates

**P3 (Low) - Minor issues**
- Contact: Create ticket, no immediate escalation
- Action: Fix in next sprint
- Communication: Weekly summary

### 5.2 Contact Information

```
Platform Team Lead: [TO BE FILLED]
On-Call Engineer: [TO BE FILLED]
Network Operations: [TO BE FILLED]
Security Team: [TO BE FILLED]

Emergency Slack Channel: #nephio-demo-incidents
Email List: nephio-demo-ops@company.com
```

### 5.3 Incident Response Workflow

#### Immediate Response (0-5 minutes)
1. Acknowledge incident
2. Assess severity using matrix above
3. Execute appropriate emergency procedures
4. Notify stakeholders via Slack

#### Investigation Phase (5-30 minutes)
1. Collect logs and metrics
2. Identify root cause
3. Implement temporary fix if possible
4. Document findings

#### Resolution Phase (30 minutes - 4 hours)
1. Implement permanent fix
2. Verify system stability
3. Conduct post-mortem if P0/P1
4. Update runbook with lessons learned

### 5.4 Root Cause Analysis Template

```markdown
## Incident Report: [INCIDENT_ID]

### Summary
- **Date/Time**:
- **Duration**:
- **Severity**:
- **Impact**:

### Timeline
- **[TIME]**: Issue first detected
- **[TIME]**: Emergency procedures initiated
- **[TIME]**: Root cause identified
- **[TIME]**: Fix implemented
- **[TIME]**: System restored

### Root Cause
[Detailed technical explanation]

### Contributing Factors
- Factor 1
- Factor 2

### Resolution
[What was done to fix the issue]

### Prevention
- [ ] Monitoring improvement
- [ ] Documentation update
- [ ] Process change
- [ ] Code/config change

### Action Items
- [ ] [Owner] [Action] [Due Date]
- [ ] [Owner] [Action] [Due Date]
```

---

## 6. Maintenance Procedures

### 6.1 Regular Health Checks

#### Daily Automated Checks
```bash
#!/bin/bash
# File: scripts/daily_health_check.sh
# Add to crontab: 0 9 * * * /path/to/daily_health_check.sh

./scripts/health_check_smo.sh
./scripts/health_check_edge.sh configs/edge1-kubeconfig edge1
./scripts/health_check_edge.sh configs/edge2-kubeconfig edge2
./scripts/health_check_llm.sh
./scripts/o2ims_probe.sh

# Generate daily report
echo "Daily health check completed at $(date)" >> /var/log/daily-health.log
```

#### Weekly Full System Test
```bash
#!/bin/bash
# File: scripts/weekly_system_test.sh

# Run complete demo pipeline
./scripts/demo_llm.sh --target=both --full-test

# Generate comprehensive report
./scripts/postcheck.sh --full-report > reports/weekly-$(date +%Y%m%d).json

# Archive old reports
find reports/ -name "*.json" -mtime +30 -delete
```

### 6.2 Capacity Monitoring

```bash
# Disk usage check
df -h | grep -E "(8[0-9]%|9[0-9]%|100%)"

# Memory usage check
free -h | awk 'NR==2 {print "Memory usage: " $3 "/" $2 " (" $3/$2*100 "%)"}'

# CPU load check
uptime | awk '{print "Load average: " $(NF-2) " " $(NF-1) " " $NF}'
```

---

## 7. Troubleshooting Decision Trees

### 7.1 Demo Pipeline Failures

```
Demo pipeline fails
├── Check LLM Adapter
│   ├── Health endpoint unreachable → Restart service
│   ├── API timeout → Check network, increase timeout
│   └── Invalid response → Check LLM model status
├── Check Intent Processing
│   ├── Schema validation failed → Review intent JSON
│   ├── KRM rendering failed → Check kpt functions
│   └── Target site routing failed → Verify targetSite field
├── Check GitOps Sync
│   ├── RootSync not synced → Force annotation refresh
│   ├── Apply errors → Check RBAC permissions
│   └── Resource conflicts → Manual conflict resolution
└── Check Edge Clusters
    ├── API unreachable → Check kubelet/containerd
    ├── Pods not ready → Check resource limits
    └── Service unavailable → Check NodePort configs
```

### 7.2 Performance Issues

```
Performance degraded
├── High latency
│   ├── Network latency → Check ping times between VMs
│   ├── API latency → Check cluster resource usage
│   └── LLM latency → Check adapter logs, model load
├── Resource exhaustion
│   ├── High CPU → Identify top processes, scale if needed
│   ├── High memory → Check for memory leaks, restart services
│   └── Disk full → Clean old logs, archive reports
└── Concurrent operations
    ├── Lock contention → Check for stuck processes
    ├── Resource conflicts → Review scheduling
    └── Rate limiting → Adjust limits or queue size
```

---

## 8. Quick Commands Reference

### 8.1 Most Common Operations

```bash
# Complete health check
./scripts/health_check.sh

# Run demo with specific target
./scripts/demo_llm.sh --target=edge1

# Emergency rollback
./scripts/rollback.sh

# Check all cluster status
kubectl --kubeconfig configs/edge1-kubeconfig get nodes,pods -A
kubectl --kubeconfig configs/edge2-kubeconfig get nodes,pods -A

# Monitor GitOps sync
watch kubectl get rootsync -A

# Collect all logs
./scripts/collect_logs.sh

# Force config sync refresh
kubectl annotate rootsync root-sync configsync.gke.io/sync-token=$(date +%s) -n config-management-system
```

### 8.2 Log Analysis Commands

```bash
# Search for errors in last hour
journalctl --since "1 hour ago" | grep -i error

# Monitor real-time logs
tail -f /var/log/demo_llm.log | grep -E "(ERROR|WARN|FAIL)"

# Check Kubernetes events
kubectl get events --sort-by='.lastTimestamp' -A | tail -20

# Analyze O2IMS logs
grep -E "(error|fail|timeout)" /var/log/o2ims.log | tail -10
```

---

## Emergency Contact Quick Card

```
CRITICAL (P0): Call +[EMERGENCY_NUMBER]
URGENT (P1): Slack #nephio-demo-incidents
ROUTINE: Email nephio-demo-ops@company.com

Key IPs to remember:
- Edge1: 172.16.4.45 (ports 6443, 31080, 31443, 31280)
- LLM: <VM1_IP>:8888
- Edge2: <VM4_IP> (TBD)

Emergency commands:
- ./scripts/rollback.sh
- ./scripts/emergency_stop.sh
- ./scripts/health_check.sh
```

---

*Last updated: [DATE] | Version: 1.0 | Owner: Platform Engineering Team*