# VM-2 Manual Deployment Guide

**Script:** `scripts/p0.4B_vm2_manual.sh`  
**Purpose:** One-command fallback solution for manual multi-VM deployment  
**Target:** VM-2 (Edge/O-Cloud) at IP 172.16.4.45  
**Date:** 2025-01-07

## Quick Start

### Prerequisites
- Ubuntu 22.04 LTS on VM-2
- Network connectivity to VM-1's Gitea (http://147.251.115.143:8888)
- Sudo privileges on VM-2
- At least 4GB RAM and 20GB disk space

### One-Command Deployment

```bash
# SSH to VM-2
ssh ubuntu@172.16.4.45

# Clone the repository (if not already present)
git clone https://github.com/thc1006/nephio-intent-to-o2-demo.git
cd nephio-intent-to-o2-demo

# Run the deployment script
./scripts/p0.4B_vm2_manual.sh
```

### With Gitea Token (Recommended)

```bash
# Set the token before running
export GITEA_TOKEN="your-gitea-token-here"
./scripts/p0.4B_vm2_manual.sh
```

## Verification Checks

### 1. Cluster Health Check

```bash
# Verify cluster is running
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://172.16.4.45:6443
# CoreDNS is running at https://172.16.4.45:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# Check nodes
kubectl get nodes
# Should show: edge1-control-plane Ready
```

### 2. Config Sync Status

```bash
# Check Config Sync operator
kubectl get pods -n config-management-system

# Expected: All pods should be Running
# - config-management-operator-xxx
# - root-reconciler-edge1-rootsync-xxx
# - git-sync-xxx

# Check RootSync status
kubectl get rootsync -n config-management-system edge1-rootsync -o yaml

# Look for:
# status:
#   sync:
#     status: SYNCED
#     lastUpdate: <recent timestamp>
```

### 3. GitOps Sync Verification

```bash
# Check if resources are being synced
kubectl get all --all-namespaces -l app.kubernetes.io/managed-by=configmanagement.gke.io

# Check sync logs
kubectl logs -n config-management-system -l app=git-sync --tail=20

# Verify edge1 namespace (if repository has content)
kubectl get namespace edge1
kubectl get all -n edge1
```

### 4. Network Connectivity Test

```bash
# Test Gitea repository access from VM-2
curl -I http://147.251.115.143:8888/admin1/edge1-config

# Expected: HTTP 200 OK or 301/302 redirect
```

## Rollback Procedures

### Complete Rollback

```bash
# 1. Delete the kind cluster
kind delete cluster --name edge1

# 2. Remove Config Sync CRDs (if needed)
kubectl delete crd --all -l app.kubernetes.io/name=config-management

# 3. Clean up artifacts
rm -rf ./artifacts/p0.4B
rm -f /tmp/p0.4B_vm2_manual_*.log
```

### Partial Rollback (Keep Cluster, Remove GitOps)

```bash
# 1. Delete RootSync
kubectl delete rootsync -n config-management-system edge1-rootsync

# 2. Delete Config Sync namespace
kubectl delete namespace config-management-system

# 3. Remove synced resources
kubectl delete all --all-namespaces -l app.kubernetes.io/managed-by=configmanagement.gke.io
```

## Troubleshooting Guide

### Issue 1: Docker Installation Fails

**Symptoms:**
- Script fails at Docker installation step
- Error: "Package docker.io has no installation candidate"

**Solution:**
```bash
# Update package list
sudo apt-get update

# Install Docker manually
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Re-run the script
./scripts/p0.4B_vm2_manual.sh
```

### Issue 2: Kind Cluster Creation Fails

**Symptoms:**
- Error: "ERROR: failed to create cluster: failed to init node"
- Docker permission errors

**Solution:**
```bash
# Check Docker daemon
sudo systemctl status docker

# If not running
sudo systemctl start docker
sudo systemctl enable docker

# Clean up any existing cluster
kind delete cluster --name edge1

# Check for port conflicts
sudo netstat -tlnp | grep 6443

# Re-run with verbose logging
KIND_EXPERIMENTAL_PROVIDER=docker kind create cluster --name edge1 --config /tmp/kind-config.yaml -v 5
```

### Issue 3: Config Sync Installation Hangs

**Symptoms:**
- Config Sync operator deployment never becomes ready
- Pods stuck in ContainerCreating or CrashLoopBackOff

**Solution:**
```bash
# Check pod events
kubectl describe pods -n config-management-system

# Check for resource constraints
kubectl top nodes
kubectl top pods -n config-management-system

# Delete and reinstall
kubectl delete namespace config-management-system
kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.17.0/config-sync-manifest.yaml

# Wait with increased timeout
kubectl wait --for=condition=Available deployment/config-management-operator \
  -n config-management-system --timeout=600s
```

### Issue 4: RootSync Not Syncing

**Symptoms:**
- RootSync status shows ERROR or STALLED
- No resources being created from Git repository

**Solution:**
```bash
# Check Git credentials
kubectl get secret git-creds -n config-management-system -o yaml

# Update token if needed
kubectl delete secret git-creds -n config-management-system
kubectl create secret generic git-creds \
  --namespace=config-management-system \
  --from-literal=username=admin1 \
  --from-literal=token="YOUR_NEW_TOKEN"

# Check reconciler logs
kubectl logs -n config-management-system -l app=root-reconciler --tail=50

# Force resync
kubectl delete pod -n config-management-system -l app=root-reconciler

# Verify repository structure
curl http://147.251.115.143:8888/admin1/edge1-config
```

### Issue 5: Network Connectivity Issues

**Symptoms:**
- Cannot reach Gitea from VM-2
- Connection timeout errors

**Solution:**
```bash
# Test basic connectivity
ping 147.251.115.143

# Test HTTP connectivity
curl -v http://147.251.115.143:8888

# Check firewall rules
sudo iptables -L -n

# Check routing
ip route get 147.251.115.143

# Alternative: Use SSH tunnel
ssh -L 8888:147.251.115.143:8888 ubuntu@VM1_IP
# Then update RootSync to use http://localhost:8888
```

## Manual Recovery Steps

### Step-by-Step Manual Setup (If Script Fails)

#### 1. Install Prerequisites
```bash
# Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# kubectl
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

#### 2. Create Cluster Manually
```bash
# Create config file
cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: edge1
networking:
  apiServerAddress: "172.16.4.45"
  apiServerPort: 6443
EOF

# Create cluster
kind create cluster --config=/tmp/kind-config.yaml

# Verify
kubectl cluster-info
```

#### 3. Install Config Sync Manually
```bash
# Create namespace
kubectl create namespace config-management-system

# Apply Config Sync manifest
kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.17.0/config-sync-manifest.yaml

# Wait for operator
kubectl wait --for=condition=Available deployment/config-management-operator \
  -n config-management-system --timeout=300s
```

#### 4. Configure RootSync Manually
```bash
# Create secret
kubectl create secret generic git-creds \
  --namespace=config-management-system \
  --from-literal=username=admin1 \
  --from-literal=token="YOUR_GITEA_TOKEN"

# Create RootSync
cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge1-rootsync
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://147.251.115.143:8888/admin1/edge1-config.git
    branch: main
    dir: /
    period: 30s
    auth: token
    secretRef:
      name: git-creds
EOF

# Verify
kubectl get rootsync -n config-management-system
```

## Monitoring and Maintenance

### Continuous Monitoring
```bash
# Watch sync status
watch -n 5 'kubectl get rootsync -n config-management-system'

# Monitor resource creation
kubectl get events --all-namespaces --watch

# Check logs continuously
kubectl logs -f -n config-management-system -l app=root-reconciler
```

### Regular Health Checks
```bash
# Create health check script
cat > /tmp/health-check.sh <<'EOF'
#!/bin/bash
echo "=== Cluster Health ==="
kubectl cluster-info &>/dev/null && echo "✓ Cluster accessible" || echo "✗ Cluster not accessible"

echo "=== Config Sync Health ==="
kubectl get pods -n config-management-system --no-headers | grep Running &>/dev/null && \
  echo "✓ Config Sync running" || echo "✗ Config Sync issues"

echo "=== RootSync Status ==="
status=$(kubectl get rootsync -n config-management-system edge1-rootsync -o jsonpath='{.status.sync.status}' 2>/dev/null)
[[ "$status" == "SYNCED" ]] && echo "✓ RootSync synced" || echo "✗ RootSync status: $status"

echo "=== Git Connectivity ==="
curl -s -o /dev/null -w "%{http_code}" http://147.251.115.143:8888/admin1/edge1-config | \
  grep -q "200\|301\|302" && echo "✓ Git repository accessible" || echo "✗ Git repository not accessible"
EOF

chmod +x /tmp/health-check.sh
/tmp/health-check.sh
```

## Integration Points

### From VM-1 (Management Cluster)
1. Push KRM configurations to Gitea repository
2. Monitor edge cluster deployment status
3. Collect metrics and logs

### To VM-2 (Edge Cluster)
1. Receives configurations via GitOps pull
2. Deploys O-RAN components
3. Reports status back via O2 IMS

## Security Considerations

1. **Token Security**: Never commit Gitea tokens to version control
2. **Network Security**: Ensure firewall rules allow only necessary traffic
3. **RBAC**: Config Sync uses cluster-admin privileges - monitor carefully
4. **Audit Logging**: Enable audit logging on the cluster for compliance

## Support and References

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Config Sync Documentation](https://cloud.google.com/anthos-config-management/docs/config-sync-overview)
- [Gitea API Documentation](https://docs.gitea.io/en-us/api-usage/)
- [Nephio R5 Documentation](https://wiki.nephio.org/)

## Appendix: Environment Variables

The script uses these environment variables (can be overridden):

```bash
export EDGE_CLUSTER_NAME="edge1"
export VM1_GITEA_URL="http://147.251.115.143:8888"
export GITEA_USER="admin1"
export GITEA_REPO="edge1-config"
export VM2_IP="172.16.4.45"
export GITEA_TOKEN="your-token-here"  # Optional
```

## Success Criteria

The deployment is considered successful when:

1. ✅ Kind cluster is running and accessible
2. ✅ Config Sync operator is installed and running
3. ✅ RootSync is configured and shows SYNCED status
4. ✅ Git repository is accessible from VM-2
5. ✅ Resources from Git are being deployed to the cluster
6. ✅ Health checks pass without errors
7. ✅ Artifacts are saved in `./artifacts/p0.4B/`

## Contact and Support

For issues or questions:
1. Check the log file: `/tmp/p0.4B_vm2_manual_*.log`
2. Review artifacts: `./artifacts/p0.4B/`
3. Consult the troubleshooting guide above
4. Reference the main project documentation