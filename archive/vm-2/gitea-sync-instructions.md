# Gitea ConfigSync Setup Instructions

## Overview
ConfigSync components are prepared to synchronize configurations from Gitea repository to the VM-2 edge cluster.

## Gitea Repository Details
- **URL**: http://147.251.115.143:8888
- **Repository**: admin/edge1-config (private)
- **Branch**: main
- **Sync Directory**: / (root)

## Setup Steps

### Step 1: Generate Gitea Access Token
1. Open Gitea: http://147.251.115.143:8888
2. Login as `admin`
3. Navigate to: Settings → Applications
4. Click "Generate New Token"
5. Token Name: `edge-cluster-sync`
6. Select Scopes: `repo` (full repository access)
7. Generate and copy the token

### Step 2: Deploy ConfigSync on Edge Cluster

Run the setup script with your token:
```bash
./setup-gitea-sync.sh YOUR_GENERATED_TOKEN
```

Or manually:
```bash
# Create secret with token
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=username=admin \
  --from-literal=token=YOUR_TOKEN

# Deploy ConfigSync
kubectl apply -f ~/configsync-gitea.yaml
```

### Step 3: Verify Deployment
```bash
# Check pods
kubectl get pods -n config-management-system

# View sync logs
kubectl logs -n config-management-system deploy/config-sync-controller -c git-sync

# View apply logs
kubectl logs -n config-management-system deploy/config-sync-controller -c kubectl-apply
```

## How It Works

1. **Git-Sync Container**: Pulls from Gitea repository every 30 seconds
2. **Kubectl-Apply Container**: Applies all YAML files found in the repository
3. **Authentication**: Uses the gitea-token secret for repository access

## Files Created

1. **~/gitea-secret.yaml** - Secret template (requires token)
2. **~/configsync-gitea.yaml** - ConfigSync deployment manifest
3. **~/setup-gitea-sync.sh** - Automated setup script
4. **~/gitea-sync-instructions.md** - This documentation

## Testing the Sync

1. Create a test file in Gitea repository:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-sync
  namespace: default
data:
  message: "Synced from Gitea!"
```

2. Push to the repository

3. Wait 30 seconds and verify:
```bash
kubectl get configmap test-sync
```

## Monitoring

### Check Sync Status
```bash
# Git sync logs
kubectl logs -n config-management-system -l app=config-sync-controller -c git-sync --tail=20

# Apply logs
kubectl logs -n config-management-system -l app=config-sync-controller -c kubectl-apply --tail=20
```

### Troubleshooting

**Authentication Failed**:
```bash
# Update token
kubectl edit secret gitea-token -n config-management-system
# Restart pods
kubectl rollout restart deploy/config-sync-controller -n config-management-system
```

**Repository Not Found**:
- Ensure repository `admin/edge1-config` exists in Gitea
- Check URL: http://147.251.115.143:8888/admin/edge1-config

**Sync Not Working**:
```bash
# Check pod status
kubectl describe pod -n config-management-system -l app=config-sync-controller

# Check events
kubectl get events -n config-management-system --sort-by='.lastTimestamp'
```

## Security Considerations

1. **Token Security**: Keep the Gitea token secure
2. **RBAC**: ConfigSync has cluster-admin permissions (adjust as needed)
3. **Network**: Ensure edge cluster can reach Gitea at 147.251.115.143:8888

## Next Steps

1. Generate token from Gitea
2. Run: `./setup-gitea-sync.sh YOUR_TOKEN`
3. Push configurations to Gitea repository
4. Monitor automatic sync to edge cluster