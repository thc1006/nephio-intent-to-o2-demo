# Edge2 GitOps Troubleshooting Guide

## SSH Unavailable but GitOps Healthy Operations

This guide focuses on managing the Edge2 cluster when SSH access is unavailable but GitOps remains operational.

### Quick Health Check (No SSH Required)

```bash
# Check cluster via kubectl
kubectl get nodes
kubectl get pods -A | grep -v Running

# Verify GitOps sync status
kubectl -n config-management-system get deployment reconciler-manager
kubectl -n config-management-system logs deployment/reconciler-manager | tail -20

# Check critical services
curl -sS http://127.0.0.1:31280/healthz  # O2IMS health
curl -sS http://127.0.0.1:31080/metrics  # SLO metrics
```

### Common Issues and GitOps-Only Solutions

#### 1. Service Unavailable on NodePort

**Symptom:** `curl: (7) Failed to connect to 127.0.0.1 port 31280`

**GitOps Solution:**
```bash
# Check service definition in git
git show HEAD:sites/edge2/o2ims-service.yaml

# Fix via git commit
git add sites/edge2/o2ims-service.yaml
git commit -m "fix: Update O2IMS NodePort mapping"
git push

# Force sync if needed
kubectl delete pod -n edge2-workloads -l app=o2ims
```

#### 2. Pod CrashLoopBackOff

**Symptom:** Pods repeatedly failing

**GitOps Solution:**
```bash
# Check pod logs without SSH
kubectl logs -n edge2-workloads deployment/o2ims-mock --previous

# Update deployment via git
vi sites/edge2/o2ims-deployment.yaml
git add sites/edge2/
git commit -m "fix: Correct o2ims deployment configuration"
git push
```

#### 3. Config Sync Not Syncing

**Symptom:** Changes in git not reflected in cluster

**GitOps Solution:**
```bash
# Check sync status
kubectl -n config-management-system describe rootsync edge2

# Restart reconciler
kubectl -n config-management-system delete pod -l app=reconciler-manager

# Manual apply as fallback
kubectl apply -f sites/edge2/
```

#### 4. SLO Metrics Missing

**Symptom:** No metrics from port 31080

**GitOps Solution:**
```bash
# Regenerate metrics via make
make edge2-postcheck

# Or trigger load test
kubectl delete job load-generator-slo -n edge2-workloads
kubectl apply -f sites/edge2/load-generator-slo.yaml
```

### GitOps-Only Operations

#### Deploy New Service
```bash
# Create manifest
cat > sites/edge2/new-service.yaml << EOF
apiVersion: v1
kind: Service
...
EOF

# Commit and sync
git add sites/edge2/new-service.yaml
git commit -m "feat: Add new service"
git push
```

#### Update Configuration
```bash
# Edit ConfigMap
vi sites/edge2/config.yaml

# Commit changes
git add -u
git commit -m "config: Update application settings"
git push

# Restart pods to pick up changes
kubectl rollout restart deployment -n edge2-workloads
```

#### Scale Deployment
```bash
# Edit replica count in git
sed -i 's/replicas: 1/replicas: 3/' sites/edge2/o2ims-deployment.yaml

# Commit and push
git add -u
git commit -m "scale: Increase o2ims replicas to 3"
git push
```

### Monitoring Without SSH

#### View Logs
```bash
# Application logs
kubectl logs -n edge2-workloads -l app=o2ims --tail=50

# Config Sync logs
kubectl logs -n config-management-system deployment/reconciler-manager
```

#### Check Resource Usage
```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n edge2-workloads
```

#### Export Diagnostics
```bash
# Generate diagnostic bundle
kubectl cluster-info dump --output-directory=/tmp/edge2-diag
tar -czf edge2-diagnostics.tar.gz /tmp/edge2-diag
```

### Recovery Procedures

#### Full GitOps Reset
```bash
# Delete and recreate RootSync
kubectl delete rootsync edge2 -n config-management-system
kubectl apply -f manifests/configsync/edge2-rootsync.yaml

# Force resync all resources
kubectl delete namespace edge2-workloads
kubectl apply -f sites/edge2/
```

#### Emergency Rollback
```bash
# Revert to previous commit
git revert HEAD
git push

# Or checkout specific commit
git checkout <last-known-good-commit> -- sites/edge2/
git commit -m "rollback: Revert to stable configuration"
git push
```

### Useful Aliases for GitOps Operations

Add to your shell profile:
```bash
alias e2-health='curl -sS http://127.0.0.1:31280/healthz | jq'
alias e2-slo='curl -sS http://127.0.0.1:31080/metrics | jq'
alias e2-sync='kubectl -n config-management-system get rootsync edge2'
alias e2-logs='kubectl logs -n edge2-workloads --tail=50'
alias e2-restart='kubectl rollout restart deployment -n edge2-workloads'
```

### Contact and Escalation

If GitOps operations fail:
1. Check artifacts in `artifacts/edge2/` for last known state
2. Review git history: `git log --oneline sites/edge2/`
3. Validate manifests: `kubectl apply --dry-run=client -f sites/edge2/`
4. Use `make edge2-status` for current state snapshot

Remember: All changes should be made via git commits. Direct `kubectl edit` operations will be overwritten by GitOps.