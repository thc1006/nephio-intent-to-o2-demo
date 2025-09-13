# GitOps Multi-Site Configuration

This directory contains GitOps configurations for multi-site deployment across edge1 and edge2 clusters.

## Directory Structure

```
gitops/
├── edge1-config/         # Edge1 cluster (VM-2: 172.16.4.45)
│   ├── baseline/         # Base resources (namespaces, quotas, health checks)
│   ├── services/         # Network services and slices
│   ├── network-functions/# Network function deployments
│   ├── monitoring/       # Monitoring and observability configs
│   └── rootsync.yaml     # Config Sync configuration for edge1
└── edge2-config/         # Edge2 cluster (VM-4: TBD)
    ├── baseline/         # Base resources (namespaces, quotas, health checks)
    ├── services/         # Network services and slices
    ├── network-functions/# Network function deployments
    ├── monitoring/       # Monitoring and observability configs
    └── rootsync.yaml     # Config Sync configuration for edge2
```

## Site Information

### Edge1 (VM-2)
- **IP Address**: 172.16.4.45
- **API Server**: https://172.16.4.45:6443
- **NodePort HTTP**: 31080
- **NodePort HTTPS**: 31443
- **O2IMS**: http://172.16.4.45:31280
- **Status**: Active

### Edge2 (VM-4)
- **IP Address**: TBD (update after VM-4 deployment)
- **API Server**: https://TBD:6443
- **NodePort HTTP**: TBD
- **NodePort HTTPS**: TBD
- **O2IMS**: TBD
- **Status**: Pending deployment

## Deployment Flow

1. **Intent Generation**: LLM generates intent with `targetSite` field
2. **KRM Rendering**: `render_krm.sh` routes manifests to appropriate site directory
3. **GitOps Sync**: Config Sync pulls changes from Git and applies to clusters
4. **Validation**: Post-deployment checks verify successful deployment

## Usage

### Deploy to Edge1 Only
```bash
./scripts/demo_llm.sh --target edge1
```

### Deploy to Edge2 Only
```bash
./scripts/demo_llm.sh --target edge2 --vm4-ip <EDGE2_IP>
```

### Deploy to Both Sites
```bash
./scripts/demo_llm.sh --target both --vm4-ip <EDGE2_IP>
```

## Setting Up Config Sync

### For Edge1
```bash
# On edge1 cluster (VM-2)
kubectl apply -f gitops/edge1-config/rootsync.yaml
```

### For Edge2
```bash
# On edge2 cluster (VM-4) - after updating IP in rootsync.yaml
kubectl apply -f gitops/edge2-config/rootsync.yaml
```

## Monitoring Sync Status

### Check Edge1 Sync
```bash
kubectl get rootsync -n config-management-system
kubectl describe rootsync edge1-root-sync -n config-management-system
```

### Check Edge2 Sync
```bash
kubectl get rootsync -n config-management-system
kubectl describe rootsync edge2-root-sync -n config-management-system
```

## Rollback Procedure

### Automatic Rollback
The demo_llm.sh script includes automatic rollback on failure:
```bash
./scripts/demo_llm.sh --rollback --target edge1
```

### Manual Rollback
```bash
# Revert the last Git commit
git revert HEAD
git push

# Config Sync will automatically apply the rollback
```

## Troubleshooting

### Sync Not Working
1. Check Config Sync operator is installed
2. Verify Git repository access
3. Check RBAC permissions
4. Review sync logs: `kubectl logs -n config-management-system -l app=root-reconciler`

### Deployment Failed
1. Check target site connectivity
2. Verify namespace exists
3. Review resource quotas
4. Check rendered KRM validity

## Security Considerations

- Use Git credentials secret for private repositories
- Apply network policies to restrict traffic
- Enable RBAC for fine-grained access control
- Use sealed secrets for sensitive data
- Enable audit logging on clusters