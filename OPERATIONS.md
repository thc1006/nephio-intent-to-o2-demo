# Operations Manual - Nephio Intent-to-O2 Multi-Site Platform

## Overview

This operations manual provides comprehensive procedures for managing the Nephio Intent-to-O2 multi-site platform across VM-1 (SMO/GitOps Orchestrator), VM-2 (Edge1), VM-3 (LLM Adapter), and VM-4 (Edge2).

**Network Configuration:**
- VM-1 (SMO): Orchestrator with Gitea at port 8888
- VM-2 (Edge1): API `https://172.16.4.45:6443`, NodePorts `31080/31443`, O2IMS `http://172.16.4.45:31280`
- VM-3 (LLM): Adapter at `http://<VM3_IP>:8888` (default: 172.16.2.10)
- VM-4 (Edge2): API `https://172.16.4.55:6443`, NodePorts `31080/31443`, O2IMS `http://172.16.4.55:31280`

**Critical Ports Reference:**
- **6443**: Kubernetes API Server (HTTPS)
- **31080**: HTTP service endpoint (NodePort)
- **31443**: HTTPS service endpoint (NodePort)
- **31280**: O2IMS API endpoint (NodePort)
- **8888**: LLM Adapter / Gitea services

---

## 1. Multi-Site Operations

### 1.1 Edge Site Management

#### Site Status Check
```bash
# Check all sites health
./scripts/postcheck.sh --target=both

# Individual site check
./scripts/o2ims_probe.sh --site=edge1
./scripts/o2ims_probe.sh --site=edge2
```

#### Site Switching Procedures

**Switch Traffic from Edge1 to Edge2:**
```bash
# 1. Verify Edge2 readiness
kubectl --kubeconfig ~/.kube/edge2-config get nodes
./scripts/o2ims_probe.sh --site=edge2

# 2. Deploy intent to Edge2
./scripts/demo_llm.sh --target=edge2 --intent="migrate_from_edge1"

# 3. Verify deployment success
./scripts/postcheck.sh --target=edge2

# 4. Drain Edge1 (gradual)
./scripts/demo_llm.sh --target=edge1 --intent="scale_down_services"
```

**Switch Traffic from Edge2 to Edge1:**
```bash
# Reverse process
./scripts/demo_llm.sh --target=edge1 --intent="restore_full_capacity"
./scripts/postcheck.sh --target=edge1
./scripts/demo_llm.sh --target=edge2 --intent="maintenance_mode"
```

### 1.2 Traffic Routing Configuration

#### Load Balancing Between Sites
```bash
# Deploy to both sites simultaneously
./scripts/demo_llm.sh --target=both --intent="load_balanced_deployment"

# Configure weighted routing (70% edge1, 30% edge2)
./scripts/render_krm.sh --template=weighted-routing --edge1-weight=70 --edge2-weight=30

# Apply routing configuration
git add gitops/edge1-config/network/ gitops/edge2-config/network/
git commit -m "Configure weighted traffic routing"
git push origin summit-llm-e2e
```

#### Emergency Traffic Redirection
```bash
# Emergency failover to single site
export EMERGENCY_SITE="edge2"
./scripts/demo_llm.sh --target=${EMERGENCY_SITE} --intent="emergency_capacity_scale"

# Monitor failover progress
watch -n 10 './scripts/postcheck.sh --target=${EMERGENCY_SITE}'
```

### 1.3 Failover and Fallback Scenarios

#### Automatic Failover Configuration
```bash
# Enable automatic failover
export ROLLBACK_ON_FAILURE=true
export SLO_THRESHOLD_P95_MS=15
export SUCCESS_RATE_THRESHOLD=0.995

# Configure failover thresholds in postcheck
cat > .postcheck.conf << EOF
LATENCY_P95_THRESHOLD_MS=15
SUCCESS_RATE_THRESHOLD=0.995
THROUGHPUT_P95_THRESHOLD_MBPS=200
FAILOVER_ENABLED=true
FAILOVER_TARGET_SITE=edge2
EOF
```

#### Manual Failover Execution
```bash
# Trigger manual failover
./scripts/demo_rollback.sh --from=edge1 --to=edge2 --reason="planned_maintenance"

# Verify failover success
./scripts/postcheck.sh --target=edge2 --validate-failover

# Fallback when ready
./scripts/demo_llm.sh --target=edge1 --intent="restore_from_maintenance"
./scripts/postcheck.sh --target=both
```

---

## 2. Deployment Operations

### 2.1 Intent-to-O2 Workflow Walkthrough

#### Standard Deployment Flow
```bash
# 1. Generate intent using LLM
./scripts/intent_from_llm.sh \
  --prompt="Deploy 5G network slice with low latency requirements" \
  --target-site="edge1" \
  --output="artifacts/demo-llm/intent.json"

# 2. Validate intent schema
./scripts/validate_intent.sh artifacts/demo-llm/intent.json

# 3. Render KRM from intent
./scripts/render_krm.sh \
  --intent="artifacts/demo-llm/intent.json" \
  --target="edge1" \
  --output-dir="gitops/edge1-config"

# 4. Push to GitOps repository
./scripts/push_krm_to_gitea.sh \
  --source="gitops/edge1-config" \
  --branch="intent-deployment-$(date +%Y%m%d_%H%M%S)"

# 5. Monitor deployment
./scripts/postcheck.sh --target=edge1 --timeout=600

# 6. Generate deployment report
./scripts/package_artifacts.sh --deployment-id="$(date +%Y%m%d_%H%M%S)"
```

#### Multi-Site Deployment
```bash
# Deploy to both sites with site-specific configuration
./scripts/demo_llm.sh \
  --target=both \
  --intent="5G network slice deployment" \
  --edge1-config="low_latency_optimized" \
  --edge2-config="high_throughput_optimized"

# Monitor cross-site deployment
for site in edge1 edge2; do
  ./scripts/postcheck.sh --target=$site &
done
wait
```

### 2.2 KRM Rendering Pipeline Operations

#### Pipeline Configuration
```bash
# Configure KRM rendering pipeline
export KPT_FN_RUNTIME="docker"
export RENDER_TIMEOUT_SECONDS=300

# Render with specific function pipeline
kpt fn render gitops/edge1-config \
  --fn-path=kpt-functions/nephio-functions.yaml \
  --results-dir=artifacts/render-results
```

#### Debug Rendering Issues
```bash
# Debug mode rendering
./scripts/render_krm.sh \
  --debug \
  --intent="artifacts/demo-llm/intent.json" \
  --target="edge1" \
  --dry-run

# Validate rendered manifests
kubeconform -strict -summary \
  -kubernetes-version 1.27.3 \
  gitops/edge1-config/**/*.yaml

# Check for policy violations
opa eval -d guardrails/policies \
  -i gitops/edge1-config \
  "data.violations[_]"
```

### 2.3 GitOps Sync Monitoring

#### RootSync Status Check
```bash
# Check sync status across all sites
kubectl --context=edge1 -n config-management-system get rootsync
kubectl --context=edge2 -n config-management-system get rootsync

# Detailed sync status
kubectl --context=edge1 -n config-management-system describe rootsync intent-to-o2-rootsync

# Monitor sync progress
watch -n 30 'kubectl --context=edge1 -n config-management-system get rootsync -o custom-columns=NAME:.metadata.name,STATUS:.status.sync.lastUpdate,COMMIT:.status.sync.commit[:8]'
```

#### Sync Troubleshooting
```bash
# Check git-sync logs
kubectl --context=edge1 -n config-management-system logs -l app=git-sync --tail=50

# Check reconciler logs
kubectl --context=edge1 -n config-management-system logs deployment/root-reconciler --tail=50

# Force sync retry
kubectl --context=edge1 -n config-management-system annotate rootsync intent-to-o2-rootsync \
  configsync.gke.io/reconcile-timeout="$(date +%s)"
```

---

## 3. Monitoring & Alerting

### 3.1 Prometheus/Grafana Access

#### Service Endpoints
- **Edge1 Prometheus**: `http://172.16.4.45:31090/prometheus`
- **Edge1 Grafana**: `http://172.16.4.45:31091/grafana` (admin/admin)
- **Edge2 Prometheus**: `http://172.16.4.55:31090/prometheus`
- **Edge2 Grafana**: `http://172.16.4.55:31091/grafana`

#### Access Setup
```bash
# Create port forwards for secure access
kubectl --context=edge1 port-forward -n monitoring svc/prometheus-server 9090:80 &
kubectl --context=edge1 port-forward -n monitoring svc/grafana 3000:80 &

# Or use NodePort access
curl -s http://172.16.4.45:31090/prometheus/api/v1/query?query=up | jq '.data.result[]'
```

### 3.2 SLO Dashboard Configuration

#### SLO Metrics Collection
```bash
# Configure SLO collection
cat > monitoring/slo-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: slo-config
  namespace: monitoring
data:
  slo.yaml: |
    slos:
      - name: intent_processing_latency
        threshold: 15ms
        percentile: 95
      - name: deployment_success_rate
        threshold: 0.995
      - name: network_throughput
        threshold: 200mbps
        percentile: 95
EOF

kubectl --context=edge1 apply -f monitoring/slo-config.yaml
kubectl --context=edge2 apply -f monitoring/slo-config.yaml
```

#### SLO Dashboard Import
```bash
# Import predefined dashboards
curl -X POST http://admin:admin@172.16.4.45:31091/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/dashboards/intent-to-o2-slo.json

# Verify dashboard import
curl -s http://admin:admin@172.16.4.45:31091/api/search?query=Intent-to-O2 | jq '.'
```

### 3.3 Alert Routing and Silencing

#### Alert Configuration
```bash
# Configure Alertmanager
cat > monitoring/alertmanager-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 1h
      receiver: 'default'
      routes:
      - match:
          severity: critical
        receiver: 'critical-alerts'
    receivers:
    - name: 'default'
      webhook_configs:
      - url: 'http://slack-webhook-service:8080/hooks/default'
    - name: 'critical-alerts'
      webhook_configs:
      - url: 'http://slack-webhook-service:8080/hooks/critical'
EOF

kubectl --context=edge1 apply -f monitoring/alertmanager-config.yaml
kubectl --context=edge2 apply -f monitoring/alertmanager-config.yaml
```

#### Silence Management
```bash
# Create silence for maintenance window
amtool silence add \
  --alertmanager.url=http://172.16.4.45:31093 \
  --author="operations-team" \
  --comment="Planned maintenance on edge1" \
  --duration=4h \
  alertname="HighLatency" instance="edge1"

# List active silences
amtool silence query --alertmanager.url=http://172.16.4.45:31093

# Expire silence early
amtool silence expire <silence-id> --alertmanager.url=http://172.16.4.45:31093
```

---

## 4. Maintenance Windows

### 4.1 Planned Maintenance Procedures

#### Pre-Maintenance Checklist
```bash
# 1. Verify backup systems
./scripts/backup_cluster_state.sh --target=both

# 2. Scale redundant services
./scripts/demo_llm.sh --target=edge2 --intent="increase_capacity_for_maintenance"

# 3. Create maintenance silence
amtool silence add --duration=6h alertname=".*" instance="edge1"

# 4. Notify stakeholders
echo "Maintenance window starting for edge1 cluster" | \
  curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"'"$(cat)"'"}' \
  $SLACK_WEBHOOK_URL
```

#### Maintenance Execution
```bash
# 1. Drain workloads from maintenance site
kubectl --context=edge1 drain <node> --ignore-daemonsets --delete-emptydir-data

# 2. Perform maintenance (example: cluster upgrade)
./scripts/upgrade_cluster.sh --target=edge1 --version=1.28.0

# 3. Verify cluster health
kubectl --context=edge1 get nodes
kubectl --context=edge1 get pods --all-namespaces

# 4. Run post-maintenance validation
./scripts/postcheck.sh --target=edge1 --comprehensive
```

#### Post-Maintenance Recovery
```bash
# 1. Restore workloads
kubectl --context=edge1 uncordon <node>

# 2. Rebalance traffic
./scripts/demo_llm.sh --target=both --intent="restore_normal_traffic_distribution"

# 3. Remove silences
amtool silence expire --alertmanager.url=http://172.16.4.45:31093

# 4. Generate maintenance report
./scripts/package_artifacts.sh --maintenance-report="edge1-upgrade-$(date +%Y%m%d)"
```

### 4.2 Component Upgrade Paths

#### Kubernetes Cluster Upgrade
```bash
# 1. Upgrade control plane
kubeadm upgrade plan
kubeadm upgrade apply v1.28.0

# 2. Upgrade nodes (rolling)
for node in $(kubectl get nodes -o name); do
  kubectl drain $node --ignore-daemonsets --delete-emptydir-data
  # SSH to node and upgrade
  kubeadm upgrade node
  systemctl restart kubelet
  kubectl uncordon $node
done

# 3. Verify upgrade
kubectl version
kubectl get nodes -o wide
```

#### Config Sync Upgrade
```bash
# 1. Update Config Sync version
export CONFIG_SYNC_VERSION="1.18.0"

# 2. Apply new manifests
kubectl apply -f https://github.com/GoogleCloudPlatform/anthos-config-management/releases/download/v${CONFIG_SYNC_VERSION}/config-sync-operator.yaml

# 3. Monitor rollout
kubectl -n config-management-system rollout status deployment/config-management-operator

# 4. Verify functionality
kubectl -n config-management-system get rootsync
```

### 4.3 Zero-Downtime Deployment Strategies

#### Blue-Green Deployment
```bash
# 1. Deploy to "green" environment (edge2)
./scripts/demo_llm.sh --target=edge2 --intent="blue_green_green_deployment"

# 2. Run comprehensive validation
./scripts/postcheck.sh --target=edge2 --validation=comprehensive

# 3. Switch traffic to green
./scripts/update_ingress_routing.sh --primary=edge2 --weight=100

# 4. Monitor for issues
sleep 300
./scripts/postcheck.sh --target=edge2

# 5. Decommission blue environment
./scripts/demo_llm.sh --target=edge1 --intent="blue_green_cleanup"
```

#### Canary Deployment
```bash
# 1. Deploy canary version to subset of edge1
./scripts/demo_llm.sh --target=edge1 --intent="canary_deployment" --canary-percentage=10

# 2. Monitor canary metrics
./scripts/monitor_canary.sh --duration=600 --threshold-p95=20ms

# 3. Gradually increase canary traffic
for weight in 25 50 75 100; do
  ./scripts/update_canary_weight.sh --weight=$weight
  ./scripts/monitor_canary.sh --duration=300
done

# 4. Complete rollout or rollback
if ./scripts/validate_canary_success.sh; then
  ./scripts/promote_canary.sh
else
  ./scripts/rollback_canary.sh
fi
```

---

## 5. Capacity Management

### 5.1 Resource Utilization Monitoring

#### Cluster Resource Overview
```bash
# Check overall cluster capacity
kubectl --context=edge1 top nodes
kubectl --context=edge2 top nodes

# Pod resource consumption
kubectl --context=edge1 top pods --all-namespaces --sort-by=cpu
kubectl --context=edge1 top pods --all-namespaces --sort-by=memory

# Detailed resource analysis
kubectl --context=edge1 describe nodes | grep -E "Capacity:|Allocatable:|Allocated"
```

#### Resource Utilization Reports
```bash
# Generate utilization report
./scripts/generate_capacity_report.sh --output=reports/capacity-$(date +%Y%m%d).json

# Resource usage trends
curl -s "http://172.16.4.45:31090/prometheus/api/v1/query_range" \
  -G -d 'query=node_cpu_seconds_total{mode="idle"}' \
  -d 'start=1609459200' \
  -d 'end=1609545600' \
  -d 'step=300' | jq '.data.result[]'
```

### 5.2 Scaling Procedures

#### Horizontal Pod Autoscaling
```bash
# Configure HPA for critical services
kubectl --context=edge1 autoscale deployment intent-processor \
  --cpu-percent=70 \
  --min=3 \
  --max=20

# Monitor scaling events
kubectl --context=edge1 get hpa -w
kubectl --context=edge1 describe hpa intent-processor
```

#### Vertical Pod Autoscaling
```bash
# Enable VPA for resource optimization
cat > vpa-config.yaml << EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: intent-processor-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: intent-processor
  updatePolicy:
    updateMode: "Auto"
EOF

kubectl --context=edge1 apply -f vpa-config.yaml
```

#### Cluster Autoscaling
```bash
# Check cluster autoscaler status
kubectl --context=edge1 -n kube-system describe configmap cluster-autoscaler-status

# Scale node pools
# (Implementation depends on cloud provider)
# Example for GKE:
# gcloud container clusters resize edge1-cluster --num-nodes=5 --zone=us-central1-a
```

### 5.3 Performance Tuning Guidelines

#### Network Performance Optimization
```bash
# Optimize network policies
kubectl --context=edge1 apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intent-processing
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: intent-processor
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: o2ims
    ports:
    - protocol: TCP
      port: 8080
EOF
```

#### Storage Performance Tuning
```bash
# Configure high-performance storage class
kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF
```

#### Application-Level Optimization
```bash
# Optimize intent processing pipeline
export INTENT_PROCESSOR_WORKERS=8
export INTENT_PROCESSOR_MEMORY="4Gi"
export INTENT_PROCESSOR_CPU="2000m"

./scripts/update_deployment_resources.sh \
  --deployment=intent-processor \
  --cpu=${INTENT_PROCESSOR_CPU} \
  --memory=${INTENT_PROCESSOR_MEMORY} \
  --workers=${INTENT_PROCESSOR_WORKERS}
```

---

## Operational Checklists

### Daily Health Check
- [ ] Verify all cluster nodes are Ready
- [ ] Check GitOps sync status (both sites)
- [ ] Review SLO dashboard for violations
- [ ] Validate O2IMS endpoints accessibility
- [ ] Check resource utilization trends
- [ ] Review alert status and silences

### Weekly Maintenance
- [ ] Update security patches on all nodes
- [ ] Review and rotate secrets
- [ ] Backup cluster configurations
- [ ] Analyze capacity trends and plan scaling
- [ ] Update operational documentation
- [ ] Test disaster recovery procedures

### Monthly Reviews
- [ ] Comprehensive security audit
- [ ] Performance optimization review
- [ ] Capacity planning assessment
- [ ] Disaster recovery testing
- [ ] Update operational runbooks
- [ ] Review and update SLO thresholds

---

## Emergency Contacts and Escalation

### On-Call Rotation
- **Primary**: Platform Engineering Team
- **Secondary**: Site Reliability Engineering
- **Escalation**: Engineering Management

### Communication Channels
- **Slack**: #nephio-operations
- **Email**: nephio-ops@company.com
- **PagerDuty**: nephio-critical-alerts

### Emergency Procedures
1. **Severity 1 (System Down)**: Page on-call immediately
2. **Severity 2 (Degraded Performance)**: Slack notification + email
3. **Severity 3 (Minor Issues)**: Email notification during business hours

---

## Common Failures and Resolution

### 5-Minute Fix Playbook

#### 1. LLM Adapter Timeout (Port 8888)
**Symptoms**: Intent generation fails with timeout error
```bash
# Quick Fix (< 5 min)
systemctl restart llm-adapter
curl -X GET http://172.16.2.10:8888/health
```

#### 2. O2IMS Connection Failure (Port 31280)
**Symptoms**: ProvisioningRequest not reaching O2IMS
```bash
# Quick Fix (< 5 min)
kubectl rollout restart deployment o2ims-controller -n o2ims-system
kubectl wait --for=condition=ready pod -l app=o2ims -n o2ims-system --timeout=300s
curl http://172.16.4.45:31280/o2ims/v1/health
```

#### 3. API Server Unreachable (Port 6443)
**Symptoms**: kubectl commands fail with connection refused
```bash
# Quick Fix (< 5 min)
systemctl restart kubelet
systemctl restart containerd
kubectl get nodes --request-timeout=10s
```

#### 4. NodePort Services Down (Ports 31080/31443)
**Symptoms**: Services unreachable from external clients
```bash
# Quick Fix (< 5 min)
kubectl get svc -A | grep NodePort
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
curl -k https://172.16.4.45:31443/health
```

#### 5. GitOps Sync Failure
**Symptoms**: RootSync stuck, resources not deploying
```bash
# Quick Fix (< 5 min)
kubectl delete rootsync intent-to-o2-rootsync -n config-management-system
kubectl apply -f gitops/rootsync.yaml
kubectl wait --for=condition=ready rootsync intent-to-o2-rootsync -n config-management-system --timeout=300s
```

### Common Failure Patterns

| Failure Type | Port | Root Cause | Resolution Time | Automation Available |
|--------------|------|------------|-----------------|---------------------|
| LLM Timeout | 8888 | Memory leak | 2-3 min | Yes - restart script |
| O2IMS Down | 31280 | Pod crash | 3-4 min | Yes - health check |
| API Unreachable | 6443 | Certificate expiry | 4-5 min | Yes - cert rotation |
| NodePort Block | 31080/31443 | Firewall rules | 2-3 min | Yes - iptables reset |
| Sync Stuck | N/A | Git conflict | 3-5 min | Yes - force sync |

### Preventive Measures
1. **Automated Health Checks**: Run every 5 minutes on all critical ports
2. **Certificate Monitoring**: Alert 30 days before expiry
3. **Resource Monitoring**: Alert at 80% CPU/Memory usage
4. **Log Aggregation**: Centralized logging for pattern detection
5. **Automated Remediation**: Self-healing scripts for common failures

---

*Document Version: 1.1.0*
*Last Updated: 2025-09-13*
*Next Review: 2025-10-13*