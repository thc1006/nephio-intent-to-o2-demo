# GitOps Setup Complete - VM-2 Edge Cluster

## ✅ Configuration Updated

### Repository Details
- **URL**: http://147.251.115.143:8888/admin/edge1-config
- **Branch**: main
- **Sync Path**: /apps/intent
- **Auth Method**: Token-based

### Scripts Ready
1. **~/dev/vm2_rootsync.sh** - Main setup script
2. **~/verify-gitops-sync.sh** - Verification script

## 📋 Instructions for VM-1 Side

### Step 1: Create Gitea Repository
1. Access Gitea: http://147.251.115.143:8888
2. Login as admin
3. Create repository: `edge1-config` (private)

### Step 2: Generate Access Token
1. Go to Settings → Applications
2. Click "Generate New Token"
3. Name: `edge-cluster-sync`
4. Scopes: Select `repo`
5. Generate and copy the token

### Step 3: Configure VM-2 RootSync
Once you have the token, run on VM-2:
```bash
echo 'YOUR_ACTUAL_TOKEN' | ~/dev/vm2_rootsync.sh
```

Or for secure input:
```bash
read -s GITEA_TOKEN && echo "$GITEA_TOKEN" | ~/dev/vm2_rootsync.sh
```

## 📦 Expected Resources to Sync

The repository `/apps/intent` directory will contain:

### ConfigMaps
- Intent expectations configurations
- Policy definitions
- Configuration parameters

### Custom Resources
- **CNBundle** - Core Network bundles
- **RANBundle** - Radio Access Network bundles
- **TNBundle** - Transport Network bundles

### Namespace Configurations
- Edge namespace definitions
- RBAC policies
- Service accounts

## ✔️ Verification Commands

### Check Sync Status
```bash
# Run verification script
~/verify-gitops-sync.sh

# Manual checks
kubectl get rootsync -n config-management-system
kubectl get gitrepos -n config-management-system
kubectl get pods -n config-management-system
```

### Monitor Logs
```bash
# Git sync logs
kubectl logs -n config-management-system deploy/root-reconciler -c git-sync -f

# Reconciler logs
kubectl logs -n config-management-system deploy/root-reconciler -c reconciler -f
```

### Check Synced Resources
```bash
# Check for edge namespace
kubectl get ns edge

# Check for ConfigMaps
kubectl get configmap --all-namespaces | grep -i intent

# Check for custom resources (once CRDs are synced)
kubectl get cnbundles --all-namespaces
kubectl get ranbundles --all-namespaces
kubectl get tnbundles --all-namespaces
```

## 🔧 Troubleshooting

### If Token is Invalid
```bash
# Update secret
kubectl edit secret gitea-token -n config-management-system

# Restart reconciler
kubectl rollout restart deploy/root-reconciler -n config-management-system
```

### If Repository Not Accessible
```bash
# Test connectivity
curl -v http://147.251.115.143:8888

# Test with auth
curl -u admin:YOUR_TOKEN http://147.251.115.143:8888/api/v1/repos/admin/edge1-config
```

### If Resources Not Syncing
1. Check logs for errors
2. Verify `/apps/intent` directory exists in repo
3. Ensure YAML files are valid
4. Check RBAC permissions

## 🚀 Next Steps

1. **VM-1**: Create Gitea repository and generate token
2. **VM-2**: Run `echo 'TOKEN' | ~/dev/vm2_rootsync.sh`
3. **VM-1**: Push content to repository `/apps/intent` directory
4. **VM-2**: Verify sync with `~/verify-gitops-sync.sh`

## Summary

The GitOps sync is configured to:
- Pull from: http://147.251.115.143:8888/admin/edge1-config
- Sync directory: /apps/intent
- Apply to: Edge cluster on VM-2
- Update interval: Every 30 seconds

Once the token is provided, the sync will automatically start pulling and applying KRM resources from the Gitea repository.