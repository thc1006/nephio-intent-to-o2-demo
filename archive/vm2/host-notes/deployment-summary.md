# VM-2 Edge Cluster Deployment Summary

## What Has Been Done

### 1. Kind Cluster Setup ✅
- **Created**: Edge Kind cluster bound to 172.16.4.45:6443
- **Configuration**: ~/kind-vm2.yaml with NodePort mappings (31080, 31443)
- **Script**: ~/dev/net_kind_vm2.sh for automated deployment
- **Kubeconfig**: /tmp/kubeconfig-edge.yaml (accessible from VM-1)
- **Documentation**: ~/edge-cluster-deployment.md

### 2. O2IMS Components Deployment ✅
- **Namespace**: o2ims-system created
- **O2IMS Controller**: Running with busybox placeholder
- **API Service**: NodePort service on 31280 (http://172.16.4.45:31280)
- **CRDs Installed**:
  - ProvisioningRequests (pr)
  - DeploymentManagers (dm)
  - ResourcePools (rp)
- **RBAC**: Full permissions configured
- **Files**:
  - ~/o2ims-operator.yaml
  - ~/o2ims-rbac.yaml
  - ~/o2ims-crds.yaml
  - ~/o2ims-deployment-info.md

### 3. GitOps/ConfigSync Setup ✅
- **Namespace**: config-management-system created
- **RootSync Script**: ~/dev/vm2_rootsync.sh
- **Features**:
  - Automatic namespace creation
  - Gitea token secret management
  - RootSync/git-sync deployment fallback
  - Comprehensive troubleshooting tips
- **Configuration**:
  - Primary URL: http://172.16.0.78:3000/admin/edge1-config
  - Alternative: http://172.18.0.200:3000/admin/edge1-config
  - Branch: main
  - Sync interval: 30s

### 4. Documentation Created ✅
- **Edge Cluster Docs**: ~/edge-cluster-deployment.md
- **O2IMS Info**: ~/o2ims-deployment-info.md
- **Gitea Sync Instructions**: ~/gitea-sync-instructions.md
- **This Summary**: ~/deployment-summary.md

## Current Status

### Running Services
```bash
# Kind Cluster
- API Server: https://172.16.4.45:6443
- NodePorts: 31080 (HTTP), 31443 (HTTPS)

# O2IMS
- Controller: Running in o2ims-system namespace
- API: http://172.16.4.45:31280

# ConfigSync
- Namespace: config-management-system
- Secret: gitea-token (needs real token)
```

### Access Points
- **Kubernetes API**: https://172.16.4.45:6443
- **O2IMS API**: http://172.16.4.45:31280
- **NodePort Services**: 31080, 31443

## Quick Commands

### Check Cluster Status
```bash
export KUBECONFIG=/tmp/kubeconfig-edge.yaml
kubectl get nodes
kubectl get pods -A
```

### Check O2IMS
```bash
kubectl get pods -n o2ims-system
kubectl get svc -n o2ims-system
kubectl get crd | grep o2ims
```

### Setup GitOps with Token
```bash
# Secure token input
read -s GITEA_TOKEN && echo "$GITEA_TOKEN" | ~/dev/vm2_rootsync.sh

# Or with token directly
~/dev/vm2_rootsync.sh YOUR_TOKEN
```

### View Sync Logs
```bash
kubectl logs -n config-management-system deploy/root-reconciler -c git-sync
kubectl logs -n config-management-system deploy/root-reconciler -c reconciler
```

## Network Connectivity

### From VM-2 (This Host)
- Can reach: Local services, Docker network
- API accessible at: 172.16.4.45:6443

### From VM-1 (172.16.0.78)
- Can access: Edge cluster API via kubeconfig
- O2IMS API: http://172.16.4.45:31280
- NodePort services: 31080, 31443

### Gitea Repository
- Primary: http://172.16.0.78:3000 (from edge cluster)
- Alternative: http://172.18.0.200:3000 (Docker network)
- Repository: admin/edge1-config

## Next Steps

1. **Generate Gitea Token**:
   - Login to Gitea at http://172.16.0.78:3000
   - Create token with 'repo' scope
   - Run: `~/dev/vm2_rootsync.sh YOUR_TOKEN`

2. **Create Repository Content**:
   - Push YAML manifests to admin/edge1-config
   - ConfigSync will auto-apply to edge cluster

3. **Test O2IMS Integration**:
   - Send ProvisioningRequests from SMO
   - Monitor at http://172.16.4.45:31280

4. **Monitor Sync**:
   - Watch logs for git-sync activity
   - Verify resources appear in cluster

## Troubleshooting

### Common Issues
1. **Docker permissions**: Add user to docker group or use sudo
2. **Network connectivity**: Check firewall and routing between VMs
3. **Gitea access**: Verify token and repository exists
4. **Sync failures**: Check logs in config-management-system namespace

### Useful Debug Commands
```bash
# Test Gitea connectivity
curl -v http://172.16.0.78:3000

# Check secret
kubectl get secret gitea-token -n config-management-system -o yaml

# Restart sync
kubectl rollout restart deploy/root-reconciler -n config-management-system

# View events
kubectl get events -n config-management-system --sort-by='.lastTimestamp'
```

## Files Overview

| File | Purpose |
|------|---------|
| ~/kind-vm2.yaml | Kind cluster configuration |
| ~/dev/net_kind_vm2.sh | Cluster deployment script |
| ~/dev/vm2_rootsync.sh | RootSync setup script |
| ~/o2ims-*.yaml | O2IMS manifests |
| /tmp/kubeconfig-edge.yaml | Cluster access config |

## Security Notes

- Gitea token stored in Kubernetes secret
- Cluster API bound to specific IP
- RBAC configured for service accounts
- NodePort services exposed on high ports

---
*Generated: 2025-09-07*
*VM-2 Edge Cluster (172.16.4.45)*