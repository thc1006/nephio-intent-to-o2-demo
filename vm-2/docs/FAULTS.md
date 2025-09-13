# Edge Cluster Fault Injection & Recovery Documentation

## Overview
Fault injection and recovery tools for testing edge cluster resilience, monitoring systems, and rollback mechanisms. These tools simulate controlled failures to verify that VM-1's postcheck/rollback processes work correctly.

## Components

### 1. Fault Injection Script
- **Location**: `/home/ubuntu/dev/fault_inject.sh`
- **Purpose**: Creates controlled failures in the edge cluster
- **Backup**: Automatically backs up state to `/tmp/fault-backup/`

### 2. Fault Recovery Script
- **Location**: `/home/ubuntu/dev/fault_recover.sh`
- **Purpose**: Restores cluster to healthy state after fault injection
- **Methods**: Multiple recovery strategies available

## Available Fault Types

### 1. Replica Fault (`replicas`)
**Description**: Scales deployment to excessive replicas (50)  
**Impact**: Resource exhaustion, pending/failed pods  
**Detection**: High pod count, resource warnings  
**Recovery**: Rollback to previous replica count

```bash
/home/ubuntu/dev/fault_inject.sh edge1 replicas
```

### 2. Readiness Probe Fault (`readiness`)
**Description**: Breaks readiness probe by pointing to non-existent endpoint  
**Impact**: Pods running but not ready, service disruption  
**Detection**: Ready/Total pod mismatch, health score degraded  
**Recovery**: Restore original readiness probe configuration

```bash
/home/ubuntu/dev/fault_inject.sh edge1 readiness
```

### 3. Resource Constraint Fault (`resources`)
**Description**: Sets impossible resource requirements (10Gi memory, 8 CPU)  
**Impact**: Pods stuck in Pending state  
**Detection**: Pending pods, scheduling failures  
**Recovery**: Reset to reasonable resource limits

```bash
/home/ubuntu/dev/fault_inject.sh edge1 resources
```

### 4. Image Fault (`image`)
**Description**: Uses non-existent container image  
**Impact**: ImagePullBackOff errors  
**Detection**: Pod status shows image pull failures  
**Recovery**: Restore to working image

```bash
/home/ubuntu/dev/fault_inject.sh edge1 image
```

### 5. Configuration Fault (`config`)
**Description**: Injects broken configuration file  
**Impact**: Application startup failures  
**Detection**: Container crashes, restart loops  
**Recovery**: Remove broken config, restore defaults

```bash
/home/ubuntu/dev/fault_inject.sh edge1 config
```

## Fault Injection Workflow

### Step 1: Pre-Injection State
```bash
# Check healthy baseline
/home/ubuntu/dev/edge_observe.sh table
```

### Step 2: Inject Fault
```bash
# Inject readiness probe fault (example)
/home/ubuntu/dev/fault_inject.sh edge1 readiness
```

**Expected Output:**
- Health score drops (100% → ~87%)
- Some pods marked as not ready
- Warning status in health report

### Step 3: Observe Impact
```bash
# Monitor cluster state
watch kubectl get pods -n edge1

# Check detailed health
/home/ubuntu/dev/edge_observe.sh json | jq '.health_score'
```

### Step 4: Recovery
```bash
# Automatic recovery
/home/ubuntu/dev/fault_recover.sh edge1 auto
```

**Expected Output:**
- Health score recovers (87% → 93%+)
- All pods return to ready state
- Green "HEALTHY" status

## Recovery Methods

### Auto Recovery (`auto`) - Recommended
- Cleans up artifacts
- Attempts rollback
- Waits for stabilization
- Most comprehensive approach

### Rollback (`rollback`)
- Uses `kubectl rollout undo`
- Returns to previous deployment revision
- Quick but may not clean up all artifacts

### Backup Restore (`backup`)
- Restores from backup file
- Complete state restoration
- Use when rollback isn't available

### Reset (`reset`)
- Resets to known healthy configuration
- Forces specific good state
- Use for complex failure scenarios

### Cleanup Only (`cleanup`)
- Only removes fault artifacts
- Doesn't fix deployment issues
- Use for manual intervention

## Integration with VM-1 Operations

### Precheck Process
VM-1 should verify cluster health before deployments:

```bash
#!/bin/bash
# precheck.sh - Run from VM-1

EDGE_IP="172.16.4.45"

# Check overall health
HEALTH_SCORE=$(ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/edge_observe.sh json" | jq -r '.health_score')

if [ "$HEALTH_SCORE" -lt 90 ]; then
    echo "❌ PRECHECK FAILED: Edge cluster health too low ($HEALTH_SCORE%)"
    exit 1
fi

# Check for failed/pending pods
FAILED_PODS=$(ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/edge_observe.sh json" | jq -r '.pods.failed')
PENDING_PODS=$(ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/edge_observe.sh json" | jq -r '.pods.pending')

if [ "$FAILED_PODS" -gt 0 ] || [ "$PENDING_PODS" -gt 0 ]; then
    echo "❌ PRECHECK FAILED: Unhealthy pods detected (Failed: $FAILED_PODS, Pending: $PENDING_PODS)"
    exit 1
fi

echo "✅ PRECHECK PASSED: Edge cluster is healthy"
```

### Postcheck Process
VM-1 should verify deployment success after changes:

```bash
#!/bin/bash
# postcheck.sh - Run from VM-1

EDGE_IP="172.16.4.45"

# Wait for deployment to settle
sleep 30

# Check post-deployment health
HEALTH_SCORE=$(ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/edge_observe.sh json" | jq -r '.health_score')

if [ "$HEALTH_SCORE" -lt 85 ]; then
    echo "❌ POSTCHECK FAILED: Health degraded to $HEALTH_SCORE%"
    echo "🔄 Initiating rollback..."
    
    # Trigger rollback on edge cluster
    ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/fault_recover.sh edge1 auto"
    
    exit 1
fi

echo "✅ POSTCHECK PASSED: Deployment successful"
```

### Rollback Trigger
VM-1 can trigger emergency rollback:

```bash
#!/bin/bash
# emergency_rollback.sh - Run from VM-1

EDGE_IP="172.16.4.45"

echo "🚨 Emergency rollback initiated..."

# Execute rollback on edge cluster
if ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/fault_recover.sh edge1 auto"; then
    echo "✅ Emergency rollback completed"
else
    echo "❌ Emergency rollback failed - manual intervention required"
    exit 1
fi
```

## Testing Scenarios

### Scenario 1: Full Cycle Test
```bash
# 1. Baseline check
/home/ubuntu/dev/edge_observe.sh table

# 2. Inject fault
/home/ubuntu/dev/fault_inject.sh edge1 readiness

# 3. Verify degradation
/home/ubuntu/dev/edge_observe.sh table

# 4. Recover
/home/ubuntu/dev/fault_recover.sh edge1 auto

# 5. Verify recovery
/home/ubuntu/dev/edge_observe.sh table
```

### Scenario 2: Multiple Fault Types
```bash
# Test different fault types
for fault in readiness resources image; do
    echo "Testing $fault fault..."
    /home/ubuntu/dev/fault_inject.sh edge1 $fault
    sleep 60
    /home/ubuntu/dev/fault_recover.sh edge1 auto
    sleep 30
done
```

### Scenario 3: VM-1 Remote Testing
```bash
# From VM-1 (172.16.0.78)
ssh ubuntu@172.16.4.45 "/home/ubuntu/dev/fault_inject.sh edge1 readiness"
curl -s http://172.16.4.45:31090/ | jq '.slo_gates.pods_ready.passed'
ssh ubuntu@172.16.4.45 "/home/ubuntu/dev/fault_recover.sh edge1 auto"
```

## Expected Results

### Healthy State
- Health Score: 90-100%
- All pods: Ready
- Deployments: Available
- Status: ✅ HEALTHY

### Fault Injected State
- Health Score: 50-89%
- Some pods: Not Ready/Failed/Pending
- Deployments: Partially Available
- Status: ⚠️ WARNING or ❌ CRITICAL

### Recovered State
- Health Score: 90-100%
- All pods: Ready
- Deployments: Available
- Status: ✅ HEALTHY

## Monitoring Integration

### Health Score Thresholds
- **90-100%**: Healthy (Green)
- **70-89%**: Warning (Yellow)
- **0-69%**: Critical (Red)

### SLO Gate Integration
The fault injection affects these SLO gates:
- `pods_ready.passed`: Changes from `true` to `false`
- `deployments_available.passed`: May change based on fault type
- `overall_health`: Reflects composite status

### Automated Alerts
VM-1 can monitor for degradation:
```bash
# Continuous monitoring (add to crontab)
*/5 * * * * curl -s http://172.16.4.45:31090/ | jq -r '.overall_health' | grep -q false && echo "ALERT: Edge cluster unhealthy" | mail -s "Edge Alert" admin@example.com
```

## Troubleshooting

### Common Issues

#### Fault Injection Fails
```bash
# Check namespace exists
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml get ns edge1

# Check permissions
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml auth can-i create deployments -n edge1
```

#### Recovery Fails
```bash
# Check rollout history
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml rollout history deployment/test-app -n edge1

# Manual reset
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml delete deployment test-app -n edge1
/home/ubuntu/dev/fault_inject.sh edge1 readiness  # Recreate clean
```

#### Health Score Doesn't Recover
```bash
# Check all namespaces
/home/ubuntu/dev/edge_observe.sh table

# Look for issues in other namespaces
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml get pods --all-namespaces | grep -v Running
```

### Manual Cleanup
If scripts fail, manual cleanup:
```bash
# Remove test deployment
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml delete deployment test-app -n edge1
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml delete service test-app-service -n edge1
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml delete configmap broken-config -n edge1

# Clean failed pods
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml delete pods --field-selector=status.phase=Failed -n edge1
```

## Best Practices

### 1. Always Backup Before Injection
The scripts automatically backup state, but verify:
```bash
ls -la /tmp/fault-backup/
```

### 2. Test in Isolation
Use dedicated namespaces for fault testing to avoid affecting production workloads.

### 3. Monitor During Testing
Keep health monitoring active during fault injection:
```bash
watch /home/ubuntu/dev/edge_observe.sh table
```

### 4. Document Results
Record fault injection results for trend analysis:
```bash
echo "$(date): Fault injection test - Health degraded to X%" >> /var/log/fault-testing.log
```

### 5. Regular Testing
Schedule regular fault injection tests to ensure recovery mechanisms stay functional.

## Files and Dependencies

### Required Files
- `/home/ubuntu/dev/fault_inject.sh` - Main injection script
- `/home/ubuntu/dev/fault_recover.sh` - Recovery script
- `/home/ubuntu/dev/edge_observe.sh` - Health monitoring
- `/tmp/kubeconfig-edge.yaml` - Kubernetes config

### Generated Files
- `/tmp/fault-backup/state-backup-*.yaml` - State backups
- `/tmp/fault-backup/latest-backup.txt` - Latest backup reference

### External Dependencies
- `kubectl` - Kubernetes CLI
- `jq` - JSON processing
- `curl` - HTTP client for health checks

## Exit Codes

### Fault Injection Script
- `0`: Success
- `1`: General error
- `2`: Prerequisites failed
- `3`: Deployment creation failed

### Recovery Script
- `0`: Recovery successful
- `1`: Recovery failed or verification failed
- `2`: Prerequisites failed
- `3`: Backup not found

---
*Created: 2025-09-07*  
*Version: 1.0.0*  
*Location: VM-2 Edge Cluster (172.16.4.45)*  
*Integration: VM-1 SMO (172.16.0.78)*