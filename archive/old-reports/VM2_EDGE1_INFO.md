# VM-2 (Edge-1) Configuration Information

## Network Configuration
- **IP Address**: 172.16.4.45
- **Role**: Edge Site 1
- **Cluster**: edge1
- **SSH Access**: ubuntu@172.16.4.45

## Required Services and Ports

### 1. O2IMS Service (Port 31280)
**Current Status**: ✅ Running (但需要 healthz endpoint)
**Service**: o2ims-api in namespace o2ims-system
**Response**: `{"status":"operational"}`

**To add healthz endpoint**:
```bash
# Create improved O2IMS with healthz
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: o2ims-nginx-config
  namespace: o2ims-system
data:
  default.conf: |
    server {
        listen 8080;

        location / {
            return 200 '{"name":"O2IMS API","status":"operational","timestamp":"'\$(date -Iseconds)'","version":"1.0.0"}';
            add_header Content-Type application/json;
        }

        location /healthz {
            return 200 '{"status":"healthy"}';
            add_header Content-Type application/json;
        }

        location /o2ims/v1 {
            return 200 '{"apiVersion":"1.0","kind":"O2IMS"}';
            add_header Content-Type application/json;
        }
    }
EOF

# Update deployment to use ConfigMap
kubectl patch deployment o2ims-controller -n o2ims-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes",
    "value": [
      {
        "name": "nginx-config",
        "configMap": {
          "name": "o2ims-nginx-config"
        }
      }
    ]
  }
]'
```

### 2. GitOps (Config Sync)
**Current Status**: ✅ SYNCED
**Component**: RootSync in config-management-system
**Repository**: https://github.com/thc1006/nephio-intent-to-o2-demo
**Branch**: main
**Path**: gitops/edge1-config/

### 3. SLO Monitoring Service (Port 31080)
**Current Status**: ✅ Running
**Service**: echo-service-v2 in namespace slo-monitoring
**Purpose**: SLO validation endpoint

### 4. SSL Service (Port 31443)
**Current Status**: ❌ Not configured
**Solution**: SSL termination not required for demo (HTTP sufficient)

## Required Components for VM-2

### 1. Kubernetes Resources
```yaml
# Namespaces needed
- o2ims-system
- config-management-system
- slo-monitoring
- edge1-workloads
```

### 2. Network Policies
```yaml
# Allow ingress to NodePort services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nodeport-ingress
  namespace: o2ims-system
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.16.0.0/16  # Allow from internal network
```

### 3. Resource Quotas
```yaml
# Recommended quotas for edge site
apiVersion: v1
kind: ResourceQuota
metadata:
  name: edge1-quota
  namespace: edge1-workloads
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
```

## Validation Commands for VM-2

### Check all services
```bash
# O2IMS
curl -s http://localhost:31280/ | jq .
curl -s http://localhost:31280/healthz | jq .

# SLO Monitoring
curl -s http://localhost:31080/

# GitOps Status
kubectl get rootsync -n config-management-system -o yaml | yq '.status'

# Workloads
kubectl get deploy,pods -n edge1-workloads
kubectl get deploy,pods -n o2ims-system
```

### Monitor Config Sync
```bash
# Watch sync status
watch 'kubectl get rootsync -n config-management-system'

# Check last synced commit
kubectl get rootsync root-sync -n config-management-system \
  -o jsonpath='{.status.source.commit}'; echo
```

### Performance Metrics
```bash
# CPU and Memory usage
kubectl top nodes
kubectl top pods -A

# Network connectivity to SMO
ping -c 3 172.16.0.78

# Network connectivity to Edge2
ping -c 3 172.16.4.176
```

## Environment Variables for VM-2

```bash
# Add to ~/.bashrc
export EDGE_SITE=edge1
export EDGE_IP=172.16.4.45
export O2IMS_ENDPOINT=http://localhost:31280
export GITOPS_REPO=https://github.com/thc1006/nephio-intent-to-o2-demo
export GITOPS_PATH=gitops/edge1-config
```

## Troubleshooting Guide

### If O2IMS is not responding
```bash
# Check pod status
kubectl get pods -n o2ims-system

# Restart O2IMS
kubectl rollout restart deployment/o2ims-controller -n o2ims-system

# Check logs
kubectl logs -n o2ims-system deployment/o2ims-controller --tail=50
```

### If Config Sync is not syncing
```bash
# Force sync
kubectl annotate rootsync root-sync -n config-management-system \
  sync.gke.io/force=true --overwrite

# Check sync errors
kubectl describe rootsync root-sync -n config-management-system
```

### If SLO monitoring fails
```bash
# Check metrics
curl http://localhost:31080/metrics

# Verify thresholds
kubectl get configmap slo-thresholds -n slo-monitoring -o yaml
```

## Security Considerations

1. **No hardcoded secrets** - Use ConfigMaps and Secrets
2. **Network segmentation** - Use NetworkPolicies
3. **RBAC** - Least privilege for service accounts
4. **Resource limits** - Prevent resource exhaustion
5. **Audit logging** - Enable for compliance

## Contact Information

- **Primary**: VM-1 (SMO/Orchestrator)
- **Backup**: VM-4 (Edge-2)
- **Repository**: https://github.com/thc1006/nephio-intent-to-o2-demo
- **Documentation**: /docs/EDGE1_SETUP.md