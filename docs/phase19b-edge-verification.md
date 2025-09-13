# Phase 19-B (VM-4) Edge Verification Hooks

## Overview

Phase 19-B implements edge site verification hooks that confirm O2IMS Provisioning Requests (PRs) reach READY state and all site resources are properly applied.

## Components

### 1. Multi-Edge Verifier (Python)
**File:** `scripts/phase19b_multi_edge_verifier.py`

A comprehensive Python-based verification system that:
- Checks PR status across multiple edge sites in parallel
- Verifies deployed resources (NetworkSlices, ConfigMaps, Services, Deployments)
- Probes service endpoints for health
- Generates JSON artifacts with verification results
- Supports timeout-based waiting for resources to become ready

**Usage:**
```bash
# Verify multiple edges with wait
python3 scripts/phase19b_multi_edge_verifier.py \
    --edges edge1 edge2 \
    --namespace default \
    --timeout 300 \
    --wait \
    --output summary

# Quick verification without waiting
python3 scripts/phase19b_multi_edge_verifier.py \
    --edges edge2 \
    --output json
```

### 2. Bash Edge Verifier
**File:** `scripts/phase19b_edge_verifier.sh`

A shell script implementation that:
- Works with kubectl or o2imsctl
- Checks PR readiness conditions
- Verifies edge resources
- Outputs results in JSON or text format

**Usage:**
```bash
# Verify edge2 with JSON output
./scripts/phase19b_edge_verifier.sh edge2 default 300 json

# Quick check with text output
./scripts/phase19b_edge_verifier.sh edge1 default 60 text
```

### 3. A/B Service Testing & Probing
**File:** `scripts/phase19b_ab_test_probe.sh`

Advanced service testing capabilities:
- Service endpoint probing with health checks
- A/B comparison testing between services
- Canary deployment verification
- Blue-green deployment validation
- Latency measurements and success rate tracking

**Usage:**
```bash
# Probe all services for an edge
./scripts/phase19b_ab_test_probe.sh probe edge2 default

# A/B test between two services
./scripts/phase19b_ab_test_probe.sh ab edge2 default embb-service urllc-service

# Test canary deployment
./scripts/phase19b_ab_test_probe.sh canary edge2 default embb-service 10

# Validate blue-green deployment
./scripts/phase19b_ab_test_probe.sh blue-green edge2 default embb-service blue
```

## CRD Support

The verifiers support multiple CRD types:
- `provisioningrequests.o2ims.io` (O2IMS standard)
- `provisioningrequests.focom.io` (FOCOM variant)
- `packagerevisions.porch.kpt.dev` (Nephio Package Revisions)

## Output Artifacts

All verification results are saved to `artifacts/` directory:

```
artifacts/
├── edge1/
│   ├── ready_20250113_120000.json
│   └── ready.json -> ready_20250113_120000.json
├── edge2/
│   ├── ready_20250113_120100.json
│   └── ready.json -> ready_20250113_120100.json
├── multi-edge/
│   ├── ready_20250113_120200.json
│   └── ready.json -> ready_20250113_120200.json
└── ab-testing/
    ├── probe_edge2_20250113_120300.json
    ├── ab_test_20250113_120400.json
    └── canary_embb-service_20250113_120500.json
```

## Example Output

### PR Verification Result
```json
{
  "timestamp": "20250113_120000",
  "edge": "edge2",
  "namespace": "default",
  "provisioningRequests": {
    "total": 2,
    "ready": 2,
    "readyCount": 2,
    "provisioningRequests": [
      {
        "name": "edge2-embb-pr",
        "status": "Ready",
        "ready": true
      },
      {
        "name": "edge2-urllc-pr",
        "status": "Ready",
        "ready": true
      }
    ]
  },
  "resources": {
    "networkSlices": 2,
    "configMaps": 3,
    "services": 4,
    "deployments": 2,
    "serviceEndpoints": [
      {
        "name": "embb-service",
        "status": "healthy"
      }
    ],
    "status": "healthy"
  },
  "status": "success"
}
```

### A/B Test Result
```json
{
  "test": "a_b_comparison",
  "services": {
    "a": "embb-service",
    "b": "urllc-service"
  },
  "metrics": {
    "service_a": {
      "health": "healthy",
      "avg_latency_ms": 52.3,
      "success_rate": 99.2,
      "total_requests": 120
    },
    "service_b": {
      "health": "healthy",
      "avg_latency_ms": 18.7,
      "success_rate": 99.8,
      "total_requests": 120
    }
  },
  "status": "completed"
}
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Verify Edge Deployment
  run: |
    python3 scripts/phase19b_multi_edge_verifier.py \
      --edges ${{ matrix.edge }} \
      --namespace production \
      --timeout 600 \
      --wait
```

### Jenkins Pipeline Example
```groovy
stage('Edge Verification') {
    steps {
        sh '''
            ./scripts/phase19b_edge_verifier.sh ${EDGE_SITE} \
                ${NAMESPACE} 300 json > verification.json

            if ! jq -e '.verification.overallStatus == "SUCCESS"' verification.json; then
                echo "Edge verification failed"
                exit 1
            fi
        '''
    }
}
```

## Testing

Run the test suite:
```bash
# Unit tests
python3 tests/test_phase19b_verification.py

# Integration test
./scripts/test_edge_verification.sh
```

## Command Examples

### For Each Edge Site

```bash
# List PRs (with kubectl)
kubectl get pr -A

# List PRs (with o2imsctl)
o2imsctl pr list -n default -o json

# Check specific PR status
kubectl get pr edge2-embb-pr -n default -o jsonpath='{.status.phase}'

# Verify with prompt
claude --dangerously-skip-permissions -p "
You are @edge-verifier.
Goal: Confirm O2IMS PR reaches READY and all site resources applied.
Tasks: list PR, check conditions, probe A/B service endpoints.
Output: artifacts/edge2/ready.json."
```

## Troubleshooting

### Common Issues

1. **CRD Not Found**
   - Ensure O2IMS or Nephio CRDs are installed
   - Check with: `kubectl get crd | grep provision`

2. **Service Endpoints Unreachable**
   - Verify network connectivity
   - Check service type (LoadBalancer/NodePort/ClusterIP)
   - Ensure correct ports in ENDPOINT_PORTS configuration

3. **Timeout Issues**
   - Increase timeout value for slow deployments
   - Check PR controller logs for processing errors

4. **JSON Parse Errors**
   - Ensure kubectl/o2imsctl output valid JSON
   - Check for empty responses or error messages

## Requirements

- Python 3.6+
- kubectl or o2imsctl CLI
- jq for JSON processing
- curl for endpoint testing
- Kubernetes cluster with appropriate CRDs

## Future Enhancements

- [ ] Prometheus metrics integration
- [ ] Slack/webhook notifications
- [ ] Historical trend analysis
- [ ] Performance baseline comparisons
- [ ] Automated rollback triggers