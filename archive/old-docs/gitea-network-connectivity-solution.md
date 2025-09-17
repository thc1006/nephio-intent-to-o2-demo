# Gitea Network Connectivity Solution for Edge Clusters

## Problem Statement
Pods in Edge clusters (VM-2 and VM-4) cannot connect to Gitea running in Kind cluster on VM-1 due to network isolation. The Kind cluster uses internal IPs (172.18.0.x) that are not directly accessible from external networks.

## Solution Overview
We've implemented a multi-layer solution to enable Gitea access from Edge clusters:

1. **Port Forwarding**: Set up iptables NAT rules to forward traffic from VM-1's external IP to Kind's internal network
2. **External Service**: Created NodePort and LoadBalancer services for external access
3. **RootSync Configuration**: Updated GitOps configurations to use the accessible Gitea URL
4. **Credentials Management**: Created secure token-based authentication for Git operations

## Network Configuration

### VM Infrastructure
- **VM-1 (SMO/GitOps Orchestrator)**: 172.16.0.78
  - Runs Kind cluster with Gitea
  - Kind internal network: 172.18.0.0/16
  - Gitea internal service: 172.18.0.2:30924

- **VM-2 (Edge-1)**: 172.16.4.45
  - Needs to pull configurations from Gitea

- **VM-4 (Edge-2)**: 172.16.4.176
  - Needs to pull configurations from Gitea

### Access Configuration
- **External Access URL**: `http://172.16.0.78:8888`
- **Port Mapping**: VM-1:8888 → Kind:172.18.0.2:30924 → Gitea:3000
- **Authentication**: Token-based (recommended) or Basic auth

## Implementation Details

### 1. Network Access Setup
The network access is configured using iptables NAT rules:

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Forward external traffic to Kind node
sudo iptables -t nat -A PREROUTING -p tcp -d 172.16.0.78 --dport 8888 \
  -j DNAT --to-destination 172.18.0.2:30924

# Handle return traffic
sudo iptables -t nat -A POSTROUTING -p tcp -d 172.18.0.2 --dport 30924 \
  -j SNAT --to-source 172.16.0.78
```

### 2. Kubernetes Services
Created multiple service configurations for flexibility:

- **gitea-external**: NodePort service on port 30888
- **gitea-loadbalancer**: LoadBalancer with external IP 172.16.0.78
- **gitea-host-service**: ClusterIP service for internal access

### 3. RootSync Configuration
Updated RootSync to use the accessible Gitea URL:

```yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge-root-sync
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://172.16.0.78:8888/admin1/edge-config.git
    branch: main
    dir: /
    period: 30s
    auth: token
    secretRef:
      name: gitea-credentials
```

### 4. Authentication
Gitea credentials are stored as Kubernetes secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: config-management-system
type: Opaque
data:
  username: <base64-encoded-username>
  token: <base64-encoded-token>
```

## Deployment Instructions

### On VM-1 (GitOps Orchestrator)

1. **Setup network access**:
```bash
bash /home/ubuntu/nephio-intent-to-o2-demo/scripts/setup-gitea-network-access.sh
```

2. **Generate credentials**:
```bash
bash /home/ubuntu/nephio-intent-to-o2-demo/scripts/generate-gitea-credentials.sh
```

3. **Test connectivity**:
```bash
bash /home/ubuntu/nephio-intent-to-o2-demo/scripts/test-gitea-connectivity.sh
```

### On Edge VMs (VM-2 and VM-4)

1. **Apply credentials**:
```bash
kubectl apply -f gitops/credentials/gitea-secret-token.yaml
```

2. **Deploy RootSync**:
```bash
# For Edge-1
kubectl apply -f gitops/edge1-config/rootsync-gitea.yaml

# For Edge-2
kubectl apply -f gitops/edge2-config/rootsync-gitea.yaml
```

3. **Verify sync status**:
```bash
kubectl get rootsync -n config-management-system
kubectl describe rootsync -n config-management-system
```

## Testing and Validation

### Test Gitea Access
```bash
# From any VM
curl http://172.16.0.78:8888/api/v1/version

# Test Git operations
git ls-remote http://gitea_admin:r8sA8CPHD9!bt6d@172.16.0.78:8888/admin1/edge1-config.git
```

### Test from Pod
```bash
kubectl run test-pod --image=nicolaka/netshoot --rm -it -- \
  curl http://172.16.0.78:8888
```

### Monitor Sync Status
```bash
# Check RootSync status
kubectl get rootsync -A

# View sync logs
kubectl logs -n config-management-system -l app=reconciler

# Force sync
kubectl annotate rootsync -n config-management-system edge-root-sync \
  sync.gke.io/force-sync=$(date +%s) --overwrite
```

## Troubleshooting

### Common Issues and Solutions

1. **Connection refused from Edge VMs**
   - Check if iptables rules are active: `sudo iptables -t nat -L -n`
   - Verify IP forwarding is enabled: `sysctl net.ipv4.ip_forward`
   - Test from VM-1 first: `curl http://localhost:8888`

2. **Authentication failures**
   - Regenerate token: `bash scripts/generate-gitea-credentials.sh`
   - Check secret exists: `kubectl get secret -n config-management-system`
   - Verify credentials: `echo <base64-string> | base64 -d`

3. **Sync not working**
   - Check reconciler pods: `kubectl get pods -n config-management-system`
   - View detailed errors: `kubectl describe rootsync -n config-management-system`
   - Test Git URL from pod: `kubectl exec -it <pod> -- git ls-remote <repo-url>`

4. **Network policies blocking access**
   - Check network policies: `kubectl get networkpolicies -A`
   - Temporarily allow all traffic for testing
   - Add specific ingress rules for Gitea access

## Alternative Solutions

### SSH Tunnel Method
If direct network access is not possible:

```bash
# From Edge VM, create SSH tunnel to VM-1
ssh -L 8888:172.18.0.2:30924 ubuntu@172.16.0.78

# Update RootSync to use localhost
repo: http://localhost:8888/admin1/edge-config.git
```

### Socat Forwarding
For persistent forwarding without iptables:

```bash
# On VM-1
sudo socat TCP-LISTEN:8888,fork,reuseaddr TCP:172.18.0.2:30924 &
```

### Direct NodePort Access
If firewall allows NodePort range (30000-32767):

```bash
# Use direct NodePort URL
repo: http://172.16.0.78:30924/admin1/edge-config.git
```

## Files Created

1. **Network Configuration**
   - `/gitops/gitea-external-service.yaml` - External service definitions
   - `/scripts/setup-gitea-network-access.sh` - Network setup script

2. **Testing Scripts**
   - `/scripts/test-gitea-connectivity.sh` - Comprehensive connectivity test
   - `/scripts/generate-gitea-credentials.sh` - Credential generation

3. **GitOps Configurations**
   - `/gitops/edge1-config/rootsync-gitea.yaml` - Edge-1 RootSync
   - `/gitops/edge2-config/rootsync-gitea.yaml` - Edge-2 RootSync
   - `/gitops/gitea-credentials-secret.yaml` - Secret template

4. **Deployment Scripts**
   - `/scripts/deploy-gitops-to-edge.sh` - Full deployment automation

## Summary

The solution successfully enables Pod-to-Gitea connectivity by:
1. Creating a network bridge between external IPs and Kind's internal network
2. Providing multiple access methods for reliability
3. Implementing secure token-based authentication
4. Automating deployment and testing processes

The Edge clusters can now pull configurations from Gitea at `http://172.16.0.78:8888`, enabling full GitOps workflow across the infrastructure.