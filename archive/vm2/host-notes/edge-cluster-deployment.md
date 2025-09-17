# Edge Kind Cluster Deployment Documentation

## Overview
This document describes the deployment of a Kind-based Kubernetes cluster on VM-2 (172.16.4.45) for edge computing scenarios.

## Infrastructure Details

### VM Configuration
- **VM-2 (Edge Node)**
  - IP: 172.16.4.45
  - Role: Kind cluster host
  - OS: Ubuntu Linux 5.15.0-100-generic

- **VM-1 (Management Node)**
  - IP: 172.16.0.78
  - Role: Remote cluster management
  - Access: SSH (requires key setup)

## Kubernetes Cluster Specifications

### Kind Version
- Kind: Latest available
- Kubernetes: v1.27.3 (kindest/node:v1.27.3)
- Container Runtime: Docker

### Cluster Configuration
```yaml
# ~/kind-vm2.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "172.16.4.45"  # Bind API to VM-2's IP
  apiServerPort: 6443               # Standard Kubernetes API port
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:                     # Additional SANs for cert validation
      - "172.16.4.45"
      - "localhost"
      - "127.0.0.1"
  extraPortMappings:                # NodePort service mappings
  - containerPort: 31080            # HTTP traffic
    hostPort: 31080
    protocol: TCP
  - containerPort: 31443            # HTTPS traffic
    hostPort: 31443
    protocol: TCP
```

### Network Architecture
```
┌─────────────────────┐         ┌─────────────────────┐
│      VM-1           │         │       VM-2          │
│   172.16.0.78       │◄────────┤   172.16.4.45       │
│                     │  :6443  │                     │
│  Management Node    │         │   Kind Cluster      │
│  - kubectl client   │         │   - API: :6443      │
│  - Remote access    │         │   - HTTP: :31080    │
└─────────────────────┘         │   - HTTPS: :31443   │
                                └─────────────────────┘
```

## Deployment Process

### Prerequisites
1. Docker installed and running
2. Kind CLI installed
3. kubectl installed
4. User in docker group OR sudo access

### Step 1: Prepare Configuration Files

#### Create Kind cluster config
```bash
cat > ~/kind-vm2.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "172.16.4.45"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
      - "172.16.4.45"
      - "localhost"
      - "127.0.0.1"
  extraPortMappings:
  - containerPort: 31080
    hostPort: 31080
    protocol: TCP
  - containerPort: 31443
    hostPort: 31443
    protocol: TCP
EOF
```

### Step 2: Deploy Cluster

#### Option A: Using deployment script
```bash
# Run the automated deployment script
bash ~/dev/net_kind_vm2.sh
```

#### Option B: Manual deployment
```bash
# 1. Create Kind cluster
kind create cluster --name edge --config ~/kind-vm2.yaml

# If Docker requires sudo:
sudo kind create cluster --name edge --config ~/kind-vm2.yaml

# 2. Export kubeconfig
kind get kubeconfig --name edge > /tmp/kubeconfig-edge.yaml

# 3. Update server URL to VM-2's IP
sed -i 's|server: https://.*|server: https://172.16.4.45:6443|' /tmp/kubeconfig-edge.yaml

# 4. Set permissions
chmod 644 /tmp/kubeconfig-edge.yaml
```

### Step 3: Verify Deployment

```bash
# Set kubeconfig
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Check node status
kubectl get nodes
# Expected output:
# NAME                 STATUS   ROLES           AGE   VERSION
# edge-control-plane   Ready    control-plane   XXs   v1.27.3

# Check system pods
kubectl get pods -n kube-system

# Check all namespaces
kubectl get ns
```

### Step 4: Remote Access Setup

#### From VM-1 (172.16.0.78)
```bash
# Copy kubeconfig from VM-2 (manual method)
scp ubuntu@172.16.4.45:/tmp/kubeconfig-edge.yaml /tmp/kubeconfig-edge.yaml

# Or paste content manually if SSH not configured

# Test remote access
export KUBECONFIG=/tmp/kubeconfig-edge.yaml
kubectl get nodes
```

## Service Exposure

### NodePort Services
Services can be exposed using NodePort on the following ports:
- **31080**: HTTP traffic (maps to container port 31080)
- **31443**: HTTPS traffic (maps to container port 31443)

### Example Service Deployment
```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: 8080
    nodePort: 31080
  - name: https
    port: 443
    targetPort: 8443
    nodePort: 31443
  selector:
    app: example-app
```

Access services at:
- HTTP: `http://172.16.4.45:31080`
- HTTPS: `https://172.16.4.45:31443`

## Troubleshooting

### Common Issues and Solutions

#### 1. Docker Permission Denied
**Error**: `permission denied while trying to connect to the Docker daemon socket`

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes (logout/login or use new group)
newgrp docker

# Or use sudo with kind commands
sudo kind create cluster --name edge --config ~/kind-vm2.yaml
```

#### 2. Node NotReady Status
**Error**: Node shows `NotReady` status

**Possible Causes**:
- CNI plugin still initializing (wait 1-2 minutes)
- Network configuration issues

**Solution**:
```bash
# Check CNI pod status
kubectl get pods -n kube-system | grep kindnet

# Check pod logs
kubectl logs -n kube-system <kindnet-pod-name>

# If persistent, recreate cluster
kind delete cluster --name edge
kind create cluster --name edge --config ~/kind-vm2.yaml
```

#### 3. Cannot Access API from Remote
**Error**: Connection refused when accessing from VM-1

**Checks**:
```bash
# Verify API server binding
docker port edge-control-plane

# Check firewall rules
sudo iptables -L -n | grep 6443

# Verify kubeconfig server URL
grep server /tmp/kubeconfig-edge.yaml
# Should show: server: https://172.16.4.45:6443
```

#### 4. SSH Access Issues
**Error**: Cannot SCP kubeconfig to VM-1

**Solution**:
```bash
# Setup SSH keys on VM-2
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# Copy public key to VM-1
ssh-copy-id ubuntu@172.16.0.78

# Or manually copy kubeconfig content
cat /tmp/kubeconfig-edge.yaml
# Copy and paste to VM-1
```

## Maintenance Operations

### Cluster Management
```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name edge

# Recreate cluster
kind create cluster --name edge --config ~/kind-vm2.yaml

# View cluster logs
docker logs edge-control-plane
```

### Backup and Recovery
```bash
# Backup kubeconfig
cp /tmp/kubeconfig-edge.yaml ~/kubeconfig-edge.backup.yaml

# Backup cluster config
cp ~/kind-vm2.yaml ~/kind-vm2.backup.yaml
```

## Performance Considerations

### Resource Allocation
- Kind cluster runs as Docker container
- Default resource limits apply
- Monitor with: `docker stats edge-control-plane`

### Network Performance
- API server latency depends on network between VMs
- NodePort services add minimal overhead
- Consider using LoadBalancer type for production

## Security Notes

1. **API Server Security**
   - TLS encrypted communication
   - Certificate-based authentication
   - SANs include VM-2 IP for cert validation

2. **Network Security**
   - API bound to specific IP (172.16.4.45)
   - NodePort services exposed on high ports
   - Consider firewall rules for production

3. **Access Control**
   - Kubeconfig contains admin credentials
   - Protect `/tmp/kubeconfig-edge.yaml` file
   - Use RBAC for multi-user scenarios

## Appendix

### Quick Reference Commands
```bash
# Deploy cluster
sudo kind create cluster --name edge --config ~/kind-vm2.yaml

# Get kubeconfig
sudo kind get kubeconfig --name edge > /tmp/kubeconfig-edge.yaml

# Fix kubeconfig server URL
sed -i 's|server: https://.*|server: https://172.16.4.45:6443|' /tmp/kubeconfig-edge.yaml

# Check cluster
export KUBECONFIG=/tmp/kubeconfig-edge.yaml
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Delete cluster
sudo kind delete cluster --name edge
```

### Related Documentation
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

## Version History
- **v1.0** (2025-09-07): Initial deployment with Kind cluster on VM-2
  - Kubernetes v1.27.3
  - API on 172.16.4.45:6443
  - NodePort mappings: 31080, 31443