# GitOps Multi-Site Architecture

## Overview

This document describes the multi-site GitOps architecture for deploying network intents across edge1 and edge2 clusters using Config Sync and KRM rendering.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VM-1 (Orchestrator)                      │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ LLM Adapter │→│ Intent Engine │→│  KRM Renderer        │  │
│  │  (VM-1)     │  │              │  │  (render_krm.sh)     │  │
│  └─────────────┘  └──────────────┘  └──────────────────────┘  │
│                           ↓                     ↓               │
│                    ┌──────────────────────────────┐            │
│                    │   GitOps Repository          │            │
│                    │   ┌──────────┐ ┌──────────┐ │            │
│                    │   │edge1-cfg │ │edge2-cfg │ │            │
│                    │   └──────────┘ └──────────┘ │            │
│                    └──────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                               ↓ Git Pull
    ┌──────────────────────────────────────────────────────────┐
    │                     Config Sync                           │
    └──────────────────────────────────────────────────────────┘
                    ↓                           ↓
    ┌────────────────────────┐   ┌────────────────────────┐
    │   VM-2 (Edge1)         │   │   VM-4 (Edge2)         │
    │   172.16.4.45          │   │   TBD                  │
    │   ┌─────────────────┐  │   │   ┌─────────────────┐  │
    │   │ Kubernetes      │  │   │   │ Kubernetes      │  │
    │   │ Cluster         │  │   │   │ Cluster         │  │
    │   └─────────────────┘  │   │   └─────────────────┘  │
    └────────────────────────┘   └────────────────────────┘
```

## Intent Routing Logic

### 1. Intent Generation
The LLM adapter generates intents with a `targetSite` field:
- `"edge1"` - Deploy only to edge1 cluster
- `"edge2"` - Deploy only to edge2 cluster
- `"both"` - Deploy to both clusters

### 2. KRM Rendering
The `render_krm.sh` script routes manifests based on `targetSite`:

```bash
# Pseudocode logic
if targetSite == "edge1":
    render_to("gitops/edge1-config/")
elif targetSite == "edge2":
    render_to("gitops/edge2-config/")
elif targetSite == "both":
    render_to("gitops/edge1-config/")
    render_to("gitops/edge2-config/")
```

### 3. GitOps Sync
Config Sync on each cluster pulls from its designated directory:
- Edge1: `gitops/edge1-config/`
- Edge2: `gitops/edge2-config/`

## Directory Structure

```
gitops/
├── edge1-config/
│   ├── baseline/           # Core infrastructure
│   │   ├── namespace.yaml
│   │   └── sample-service.yaml
│   ├── services/           # Network services
│   ├── network-functions/  # CNFs/VNFs
│   ├── monitoring/         # Observability
│   └── rootsync.yaml       # Config Sync spec
└── edge2-config/
    ├── baseline/
    ├── services/
    ├── network-functions/
    ├── monitoring/
    └── rootsync.yaml
```

## Deployment Workflow

### Step 1: Generate Intent
```bash
# Generate intent for specific site
./scripts/demo_llm.sh --target edge1
```

### Step 2: Render KRM
```bash
# Render KRM manifests to appropriate directory
./scripts/render_krm.sh --intent intent.json --target edge1
```

### Step 3: Commit and Push
```bash
# Commit rendered manifests
git add gitops/edge1-config/
git commit -m "Deploy network slice to edge1"
git push
```

### Step 4: Automatic Sync
Config Sync automatically:
1. Detects changes in Git repository
2. Pulls updated manifests
3. Applies to target cluster
4. Reports sync status

## Multi-Site Scenarios

### Scenario 1: Single Site Deployment
Deploy a high-bandwidth eMBB slice to edge1 only:
```bash
./scripts/demo_llm.sh --target edge1 \
  --intent "Deploy eMBB slice with 1Gbps downlink for mobile broadband"
```

### Scenario 2: Dual Site Deployment
Deploy IoT services to both sites:
```bash
./scripts/demo_llm.sh --target both --vm4-ip 172.16.5.45 \
  --intent "Deploy mMTC network for 50000 IoT sensors across all sites"
```

### Scenario 3: Site-Specific Services
Deploy URLLC to edge2 for low-latency requirements:
```bash
./scripts/demo_llm.sh --target edge2 --vm4-ip 172.16.5.45 \
  --intent "Create URLLC slice with 1ms latency for autonomous vehicles"
```

## Service Type Mapping

| Service Type | Optimized Sites | AI Characteristics | Enhanced Use Cases |
|-------------|-------------|-----------------|----------|
| eMBB | edge1+edge2 | GenAI bandwidth optimization, ML QoS | 8K streaming, AR/VR, GenAI inference |
| URLLC | edge3+edge4 | <1ms AI-predicted latency, quantum security | Autonomous vehicles, industrial AI, real-time GenAI |
| mMTC | all 4 sites | AI-driven massive scaling, federated learning | Smart cities, AI sensor networks, distributed ML |
| GenAI Services | VM-1 hub | 175B parameter processing, real-time inference | AI orchestration, ML model serving, cognitive automation |

## Rollback Procedures

### Automatic Rollback
On deployment failure, the system automatically:
1. Detects failed post-checks
2. Reverts Git commit
3. Triggers Config Sync re-sync
4. Restores previous state

```bash
# Manual rollback for specific site
./scripts/demo_llm.sh --rollback --target edge1
```

### Manual Rollback
```bash
# Revert last commit
git revert HEAD
git push

# Or reset to specific commit
git reset --hard <commit-hash>
git push --force
```

## Monitoring and Validation

### Check Sync Status
```bash
# Edge1
kubectl get rootsync -n config-management-system
kubectl describe rootsync edge1-root-sync -n config-management-system

# Edge2
kubectl get rootsync -n config-management-system
kubectl describe rootsync edge2-root-sync -n config-management-system
```

### View Sync Logs
```bash
# Edge1 logs
kubectl logs -n config-management-system -l app=root-reconciler --tail=100

# Edge2 logs
kubectl logs -n config-management-system -l app=root-reconciler --tail=100
```

### Validate Deployments
```bash
# Check deployed resources on edge1
kubectl get networkslices -n ran-workloads
kubectl get services -n ran-workloads

# Check deployed resources on edge2
kubectl get networkslices -n ran-workloads
kubectl get services -n ran-workloads
```

## Security Considerations

### RBAC Configuration
Each site has specific RBAC rules:
```yaml
# Edge1 specific permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: edge1-sync-role
rules:
- apiGroups: ["ran.nephio.org"]
  resources: ["networkslices"]
  verbs: ["*"]
```

### Network Policies
Restrict inter-site communication:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: edge-isolation
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Git Authentication
For private repositories:
```bash
# Create secret for Git credentials
kubectl create secret generic git-creds \
  --from-file=ssh-privatekey=/path/to/key \
  -n config-management-system
```

## Troubleshooting

### Issue: Sync Not Working
**Symptoms**: RootSync shows error status
**Resolution**:
1. Check Git connectivity: `git ls-remote <repo-url>`
2. Verify credentials: `kubectl get secret git-creds -n config-management-system`
3. Review sync errors: `kubectl describe rootsync <name> -n config-management-system`

### Issue: Wrong Site Deployment
**Symptoms**: Resources deployed to incorrect cluster
**Resolution**:
1. Check intent `targetSite` field
2. Verify render_krm.sh routing logic
3. Confirm GitOps directory mapping

### Issue: Partial Deployment
**Symptoms**: Some resources missing
**Resolution**:
1. Check resource quotas: `kubectl describe resourcequota -n ran-workloads`
2. Review admission webhooks: `kubectl get validatingwebhookconfigurations`
3. Check RBAC permissions: `kubectl auth can-i create networkslices -n ran-workloads`

## Performance Optimization

### Sync Interval Tuning
Adjust sync frequency based on requirements:
```yaml
spec:
  git:
    period: 30s  # Default
    # period: 10s  # Faster sync for critical deployments
    # period: 60s  # Slower sync for stable environments
```

### Resource Caching
Enable caching for large deployments:
```yaml
spec:
  override:
    enableShellInRendering: false
    resourcesCacheDuration: 5m
```

### Parallel Processing
Enable parallel sync for multiple namespaces:
```yaml
spec:
  override:
    namespaceStrategy:
      parallelize: true
      maxConcurrent: 10
```

## Best Practices

1. **Version Control**: Tag releases for production deployments
2. **Branch Strategy**: Use separate branches for dev/staging/prod
3. **Manifest Validation**: Run pre-commit hooks for YAML validation
4. **Resource Naming**: Use consistent naming conventions
5. **Label Standards**: Apply standard labels for tracking
6. **Monitoring**: Set up alerts for sync failures
7. **Documentation**: Document site-specific configurations
8. **Testing**: Test in staging before production deployment

## Integration Points

### O2IMS Integration
- Edge1 O2IMS: `http://172.16.4.45:31280`
- Edge2 O2IMS: TBD
- Metrics endpoint: `/o2ims/v1/deployments`

### Prometheus Metrics
- Edge1 metrics: `http://172.16.4.45:31090/metrics`
- Edge2 metrics: TBD
- SLO compliance: `/metrics/api/v1/slo`

### LLM Adapter
- Endpoint: `http://172.16.0.78:8888`
- Intent API: `/api/v1/intent/generate`
- Health check: `/health`

## Future Enhancements

1. **Multi-Region Support**: Extend beyond two sites
2. **Dynamic Site Discovery**: Auto-detect available clusters
3. **Intent Federation**: Cross-site intent coordination
4. **Policy Engine**: Site-specific policy enforcement
5. **Cost Optimization**: Route based on resource costs
6. **Disaster Recovery**: Automatic failover between sites
7. **Edge Computing**: Support for far-edge deployments
8. **5G Network Slicing**: Advanced slice orchestration