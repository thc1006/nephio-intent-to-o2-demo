# Edge Cluster Observability Documentation

## Overview
Minimal observability solution for the edge cluster providing health metrics, SLO gates, and readiness checks that VM-1 can query for precheck/postcheck operations.

## Components

### 1. kube-state-metrics
- **Namespace**: `edge-observability`
- **Port**: 31088 (NodePort)
- **Purpose**: Exports Kubernetes cluster state metrics in Prometheus format
- **Resource Footprint**: ~64Mi memory, 10m CPU

### 2. Health Exporter Service
- **Namespace**: `edge-observability`  
- **Port**: 31090 (NodePort)
- **Purpose**: Provides simplified JSON health endpoints for SLO gates
- **Resource Footprint**: ~32Mi memory, 10m CPU

### 3. Edge Observe Script
- **Location**: `/home/ubuntu/dev/edge_observe.sh`
- **Purpose**: CLI tool for health checks and metrics collection
- **Output Formats**: JSON, Table

## Endpoints

### From VM-1 (172.16.0.78) to VM-2 (172.16.4.45)

#### Kube-State-Metrics
```bash
# Prometheus metrics endpoint
curl http://172.16.4.45:31088/metrics

# Telemetry endpoint
curl http://172.16.4.45:31089/
```

#### Health Exporter
```bash
# SLO Gates JSON endpoint
curl http://172.16.4.45:31090/
```

#### O2IMS Metrics (when available)
```bash
curl http://172.16.4.45:31280/metrics
```

## Usage Examples

### 1. Quick Health Check (Table Format)
```bash
/home/ubuntu/dev/edge_observe.sh table
```

**Example Output:**
```
════════════════════════════════════════════════════════════════
                    EDGE CLUSTER HEALTH REPORT                  
════════════════════════════════════════════════════════════════

Timestamp: 2025-09-07T08:43:10+00:00
Health Score: 100%

┌─────────────────────┬────────┬────────┬─────────┬──────────┐
│ Component           │ Total  │ Ready  │ Failed  │ Pending  │
├─────────────────────┼────────┼────────┼─────────┼──────────┤
│ Pods                │     13 │     13 │       0 │        0 │
├─────────────────────┼────────┼────────┼─────────┼──────────┤
│ Deployments         │      6 │      6 │       - │        - │
├─────────────────────┼────────┼────────┼─────────┼──────────┤
│ StatefulSets        │      0 │      0 │       - │        - │
└─────────────────────┴────────┴────────┴─────────┴──────────┘

✓ HEALTHY: Cluster is operating normally
```

### 2. JSON Output for Automation
```bash
/home/ubuntu/dev/edge_observe.sh json
```

**Example Output:**
```json
{
  "timestamp": "2025-09-07T08:43:16+00:00",
  "cluster": "edge",
  "health_score": 100,
  "pods": {
    "total": 13,
    "ready": 13,
    "failed": 0,
    "pending": 0
  },
  "deployments": {
    "total": 6,
    "available": 6
  },
  "statefulsets": {
    "total": 0,
    "ready": 0
  }
}
```

### 3. VM-1 Remote Query Examples

#### Check Edge Cluster Health from VM-1
```bash
# From VM-1, query edge cluster health
curl -s http://172.16.4.45:31090/ | jq '.'

# Check specific SLO gates
curl -s http://172.16.4.45:31090/ | jq '.slo_gates.pods_ready.passed'

# Get deployment metrics
curl -s http://172.16.4.45:31088/metrics | grep kube_deployment_status_replicas_available
```

#### Precheck/Postcheck Script for VM-1
```bash
#!/bin/bash
# precheck.sh - Run on VM-1 before deployments

EDGE_IP="172.16.4.45"

# Check health score
HEALTH_SCORE=$(ssh ubuntu@$EDGE_IP "/home/ubuntu/dev/edge_observe.sh json" | jq -r '.health_score')

if [ "$HEALTH_SCORE" -lt 90 ]; then
    echo "ERROR: Edge cluster health score too low: $HEALTH_SCORE"
    exit 1
fi

# Check critical namespaces
NAMESPACES_OK=$(curl -s http://$EDGE_IP:31090/ | jq -r '.slo_gates.critical_namespaces | to_entries | all(.value == true)')

if [ "$NAMESPACES_OK" != "true" ]; then
    echo "ERROR: Critical namespaces not ready"
    exit 1
fi

echo "✓ Precheck passed: Edge cluster is healthy"
```

## SLO Gates Definition

### Available SLO Gates

| Gate | Description | Threshold | Query |
|------|-------------|-----------|-------|
| `pods_ready` | Percentage of pods in Ready state | 95% | `.slo_gates.pods_ready.passed` |
| `deployments_available` | All deployments fully available | 100% | `.slo_gates.deployments_available.passed` |
| `critical_namespaces` | Critical namespaces exist | All true | `.slo_gates.critical_namespaces` |
| `api_endpoints` | API endpoints reachable | All true | `.slo_gates.api_endpoints` |
| `overall_health` | Composite health status | - | `.overall_health` |

### Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | SUCCESS | All checks passed |
| 1 | NAMESPACE_FAIL | Critical namespace missing |
| 2 | POD_FAIL | Pod failures detected |
| 3 | DEPLOYMENT_FAIL | Deployment not available |
| 4 | CRITICAL_FAIL | Health score < 50% |

## Integration with CI/CD

### GitLab CI Example
```yaml
edge-health-check:
  stage: pre-deploy
  script:
    - ssh ubuntu@172.16.4.45 "/home/ubuntu/dev/edge_observe.sh json" > health.json
    - jq -e '.health_score >= 90' health.json
    - jq -e '.pods.failed == 0' health.json
  artifacts:
    paths:
      - health.json
```

### Jenkins Pipeline Example
```groovy
stage('Edge Health Check') {
    steps {
        script {
            def health = sh(
                script: "ssh ubuntu@172.16.4.45 '/home/ubuntu/dev/edge_observe.sh json'",
                returnStdout: true
            )
            def healthJson = readJSON text: health
            if (healthJson.health_score < 90) {
                error("Edge cluster unhealthy: ${healthJson.health_score}%")
            }
        }
    }
}
```

## Monitoring Best Practices

### 1. Regular Health Checks
```bash
# Add to crontab for hourly checks
0 * * * * /home/ubuntu/dev/edge_observe.sh json >> /var/log/edge-health.log 2>&1
```

### 2. Alert Thresholds
- **Critical**: Health score < 50%
- **Warning**: Health score < 70%
- **Degraded**: Any failed pods
- **Maintenance**: Pending pods > 0

### 3. Resource Monitoring
```bash
# Check observability components resource usage
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml top pods -n edge-observability
```

## Troubleshooting

### Common Issues

#### Metrics Not Available
```bash
# Check if kube-state-metrics is running
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml get pods -n edge-observability

# Restart if needed
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml rollout restart deployment/kube-state-metrics -n edge-observability
```

#### Port Not Accessible
```bash
# Verify NodePort services
kubectl --kubeconfig /tmp/kubeconfig-edge.yaml get svc -n edge-observability

# Test locally first
curl http://localhost:31088/metrics
```

#### Script Permission Denied
```bash
chmod +x /home/ubuntu/dev/edge_observe.sh
```

## Minimal Footprint

Total resource consumption for observability:
- **Memory**: ~200Mi (all components)
- **CPU**: ~70m (all components)
- **Storage**: Negligible (no persistent storage)

## Files and Locations

- **Script**: `/home/ubuntu/dev/edge_observe.sh`
- **Kube-state-metrics manifest**: `/home/ubuntu/kube-state-metrics-minimal.yaml`
- **Health exporter manifest**: `/home/ubuntu/health-exporter.yaml`
- **This documentation**: `/home/ubuntu/docs/OBS.md`

---
*Created: 2025-09-07*  
*Version: 1.0.0*  
*Location: VM-2 Edge Cluster (172.16.4.45)*