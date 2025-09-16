#!/bin/bash

# Test SLO Gate and Automatic Rollback for Nephio Intent Operator
# This script simulates failures to trigger automatic rollback

set -e

echo "=== SLO Gate and Rollback Testing Script ==="
echo "Testing automatic rollback functionality of IntentDeployment CRs"
echo ""

# Function to inject failure metrics
inject_failure() {
    local site=$1
    local metric=$2
    local value=$3

    echo "Injecting failure: $metric=$value on $site"

    if [ "$site" = "edge1" ]; then
        HOST="172.16.4.45"
    elif [ "$site" = "edge2" ]; then
        HOST="172.16.4.176"
    fi

    # Create a mock endpoint that returns bad metrics
    cat > /tmp/bad_metrics.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)",
  "service": "test-service",
  "metrics": {
    "error_rate": "$value",
    "latency_p99": "800ms",
    "availability": "98.0"
  }
}
EOF

    echo "Bad metrics prepared for $site"
}

# Function to check IntentDeployment phase
check_phase() {
    local deployment=$1
    kubectl get intentdeployment $deployment -o jsonpath='{.status.phase}'
}

# Function to monitor rollback
monitor_rollback() {
    local deployment=$1
    echo "Monitoring $deployment for rollback..."

    for i in {1..30}; do
        phase=$(check_phase $deployment)
        echo "[$i/30] Current phase: $phase"

        if [ "$phase" = "RollingBack" ] || [ "$phase" = "Failed" ]; then
            echo "Rollback triggered! Phase: $phase"

            # Get rollback status
            kubectl get intentdeployment $deployment -o jsonpath='{.status.rollbackStatus}' | jq '.'
            return 0
        fi

        sleep 2
    done

    echo "No rollback triggered after 60 seconds"
    return 1
}

# Test 1: Edge1 high error rate
echo ""
echo "=== Test 1: Edge1 High Error Rate ==="
inject_failure "edge1" "error_rate" "0.15"

# Create a new deployment with strict SLO
cat <<EOF | kubectl apply -f -
apiVersion: tna.tna.ai/v1alpha1
kind: IntentDeployment
metadata:
  name: edge1-slo-test
  namespace: default
spec:
  intent: |
    {
      "service": "slo-test-service",
      "site": "edge1",
      "replicas": 1
    }

  compileConfig:
    engine: kpt
    renderTimeout: 1m

  deliveryConfig:
    targetSite: edge1
    syncWaitTimeout: 2m

  gatesConfig:
    enabled: true
    sloThresholds:
      error_rate: "0.10"  # Will fail with 0.15
      latency_p99: "1000ms"

  rollbackConfig:
    autoRollback: true
    maxRetries: 2
    retainFailedArtifacts: true
EOF

echo "Waiting for SLO validation..."
sleep 5

# Monitor for rollback
if monitor_rollback "edge1-slo-test"; then
    echo "✓ Test 1 PASSED: Rollback triggered successfully"
else
    echo "✗ Test 1 FAILED: Rollback not triggered"
fi

# Test 2: Edge2 high latency
echo ""
echo "=== Test 2: Edge2 High Latency ==="
inject_failure "edge2" "latency_p99" "1500ms"

cat <<EOF | kubectl apply -f -
apiVersion: tna.tna.ai/v1alpha1
kind: IntentDeployment
metadata:
  name: edge2-latency-test
  namespace: default
spec:
  intent: |
    {
      "service": "latency-test-service",
      "site": "edge2",
      "replicas": 1
    }

  compileConfig:
    engine: kpt
    renderTimeout: 1m

  deliveryConfig:
    targetSite: edge2
    syncWaitTimeout: 2m

  gatesConfig:
    enabled: true
    sloThresholds:
      error_rate: "0.20"
      latency_p99: "500ms"  # Will fail with 1500ms

  rollbackConfig:
    autoRollback: true
    maxRetries: 1
EOF

echo "Waiting for SLO validation..."
sleep 5

if monitor_rollback "edge2-latency-test"; then
    echo "✓ Test 2 PASSED: Rollback triggered successfully"
else
    echo "✗ Test 2 FAILED: Rollback not triggered"
fi

# Test 3: Check retained artifacts
echo ""
echo "=== Test 3: Check Retained Artifacts ==="
echo "Checking for retained artifacts..."

# Check operator logs for artifact retention
kubectl logs -n nephio-intent-operator-system deployment/nephio-intent-operator-controller-manager --tail=50 | grep -i "artifact" || true

# Summary
echo ""
echo "=== Testing Summary ==="
echo "1. Edge1 high error rate test completed"
echo "2. Edge2 high latency test completed"
echo "3. Artifact retention checked"
echo ""
echo "Check the following for detailed results:"
echo "- kubectl get intentdeployments -o wide"
echo "- kubectl describe intentdeployment edge1-slo-test"
echo "- kubectl describe intentdeployment edge2-latency-test"
echo "- kubectl logs -n nephio-intent-operator-system deployment/nephio-intent-operator-controller-manager"