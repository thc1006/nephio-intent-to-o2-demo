# Edge1 Operations Guide - VM-2

## Resource Quotas and Limits

### Current Cluster Resources
- **Node**: edge-control-plane (kind cluster)
- **Kubernetes Version**: v1.27.3
- **Container Runtime**: containerd

### Namespace Quotas

#### slo-monitoring
- **Purpose**: SLO metrics collection and monitoring
- **Key Deployments**:
  - echo-service-v2: 3 replicas (50m-200m CPU, 64Mi-128Mi memory each)
  - slo-collector: 1 replica (50m-200m CPU, 128Mi-256Mi memory)
- **Services**:
  - NodePort 30090: SLO metrics endpoint
  - NodePort 30080: Echo service endpoint

#### o2ims-system
- **Purpose**: O2IMS integration and management
- **Key Components**:
  - MeasurementJob controller (100m-500m CPU, 128Mi-256Mi memory)
  - O2IMS API service (NodePort 31280)
- **CRDs**: measurementjobs.o2ims.oran.org

#### edge1
- **Purpose**: Edge workload namespace
- **Status**: Reserved for application deployments

### Resource Recommendations

```yaml
# Recommended limits per namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "5"
    services.nodeports: "3"
```

## Common Errors and Solutions

### 1. Pod CrashLoopBackOff

**Symptoms**: Pod repeatedly crashes and restarts

**Common Causes**:
- Missing dependencies (e.g., Python modules)
- Port already in use
- Incorrect command/args

**Solutions**:
```bash
# Check pod logs
kubectl logs -n <namespace> <pod-name> --previous

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Check for port conflicts
kubectl get svc -A | grep <port-number>
```

### 2. ImagePullBackOff

**Symptoms**: Pod cannot pull container image

**Common Causes**:
- Network connectivity issues
- Rate limiting from registry
- Image doesn't exist

**Solutions**:
```bash
# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Manually pull image on node (for kind)
docker pull <image-name>
kind load docker-image <image-name> --name edge
```

### 3. Service Not Accessible

**Symptoms**: NodePort/Service not reachable

**Common Causes**:
- Service selector mismatch
- Pod not ready
- Port forwarding needed

**Solutions**:
```bash
# Check endpoints
kubectl get endpoints -n <namespace> <service-name>

# Verify pod labels match service selector
kubectl get pods -n <namespace> --show-labels

# Setup port forward
kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<service-port>
```

### 4. PVC Pending

**Symptoms**: PersistentVolumeClaim stuck in Pending state

**Common Causes**:
- No available PV
- StorageClass not found
- Insufficient storage

**Solutions**:
```bash
# Check PVC events
kubectl describe pvc -n <namespace> <pvc-name>

# Check available storage classes
kubectl get storageclass

# For kind cluster, use local-path-provisioner
kubectl get pv
```

### 5. MeasurementJob Not Updating

**Symptoms**: MeasurementJob stuck or not scraping

**Common Causes**:
- Target endpoint unreachable
- Controller not running
- Network policy blocking

**Solutions**:
```bash
# Check controller logs
kubectl logs -n o2ims-system deployment/measurementjob-controller

# Test endpoint connectivity
kubectl exec -n o2ims-system deployment/measurementjob-controller -- \
  curl -s http://slo-collector.slo-monitoring.svc.cluster.local:8090/metrics/api/v1/slo

# Restart controller
kubectl rollout restart deployment/measurementjob-controller -n o2ims-system
```

## Monitoring Commands

### Quick Health Check
```bash
# Cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running | grep -v Completed

# Service status
kubectl get svc -A | grep NodePort

# Resource usage (if metrics-server installed)
kubectl top nodes
kubectl top pods -A --sort-by=cpu
```

### SLO Monitoring
```bash
# Check SLO metrics
curl -s http://127.0.0.1:30090/metrics/api/v1/slo | jq .

# Run postcheck
python3 /home/ubuntu/scripts/o2ims_postcheck.py

# Update metrics
/home/ubuntu/scripts/run_slo_test.sh
```

### O2IMS Integration
```bash
# Check MeasurementJob status
kubectl get measurementjobs -A

# View MeasurementJob details
kubectl describe measurementjob -n o2ims-system slo-metrics-scraper

# Controller logs
kubectl logs -n o2ims-system deployment/measurementjob-controller --tail=50
```

## Maintenance Tasks

### Daily Checks
1. Verify all pods are running
2. Check NodePort accessibility
3. Review SLO metrics trends
4. Monitor resource usage

### Weekly Tasks
1. Clean up completed jobs
2. Review and rotate logs
3. Update metrics baselines
4. Performance testing

### Cleanup Commands
```bash
# Remove completed pods
kubectl delete pods -A --field-selector=status.phase=Succeeded

# Clean old jobs
kubectl delete jobs -A --field-selector status.successful=1

# Prune unused images (on kind node)
docker exec -it edge-control-plane crictl rmi --prune
```

## Troubleshooting Flowchart

```
Service Not Working?
├── Check Pod Status
│   ├── Running → Check Logs
│   ├── CrashLoopBackOff → Check Previous Logs
│   └── Pending → Check Events/Resources
├── Check Service
│   ├── Endpoints exist? → Check Pod Labels
│   └── NodePort configured? → Check Port Conflicts
└── Check Network
    ├── DNS working? → Test with nslookup
    └── Can reach service internally? → Use port-forward
```

## Emergency Recovery

### Complete Reset
```bash
# Backup current state
kubectl get all -A -o yaml > backup-$(date +%Y%m%d).yaml

# Delete problematic namespace
kubectl delete namespace <namespace> --grace-period=0 --force

# Reapply configurations
kubectl apply -f /home/ubuntu/k8s/
```

### Quick Recovery Script
```bash
#!/bin/bash
# Save as /home/ubuntu/scripts/quick-recovery.sh

echo "Starting quick recovery..."

# Restart critical services
kubectl rollout restart deployment -n slo-monitoring
kubectl rollout restart deployment -n o2ims-system

# Wait for ready
kubectl wait --for=condition=available --timeout=120s \
  deployment/slo-collector -n slo-monitoring

# Test endpoints
curl -s http://127.0.0.1:30090/health || echo "SLO endpoint not ready"

echo "Recovery complete"
```

## Contact and Escalation

### Log Locations
- **Kubernetes logs**: `kubectl logs`
- **System logs**: `/var/log/pods/` (on node)
- **Application logs**: Check ConfigMaps for log paths

### Key Files
- **Configurations**: `/home/ubuntu/k8s/`
- **Scripts**: `/home/ubuntu/scripts/`
- **Documentation**: `/home/ubuntu/docs/`

### Escalation Path
1. Check this operations guide
2. Review pod logs and events
3. Run CI acceptance tests
4. Check cluster resources
5. Restart affected components