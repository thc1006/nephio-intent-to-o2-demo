# Operations Guide

## Demo Scenarios

### Scenario 1: Basic Intent Pipeline
```bash
# 1. Validate TMF921 intent
./tools/intent-gateway/intent-gateway validate \
  --file samples/tmf921/valid_intent_01.json \
  --tio-mode fake

# 2. Convert to 3GPP TS 28.312
./tools/tmf921-to-28312/tmf921-to-28312 convert \
  --input samples/tmf921/valid_intent_01.json \
  --output artifacts/expectation.json

# 3. Generate KRM packages
kpt fn render packages/intent-to-krm/

# 4. Deploy via O2 IMS
./o2ims-sdk/o2imsctl pr create \
  --from packages/intent-to-krm/pr.yaml \
  --cluster prod-cluster-1
```

### Scenario 2: SLO-Gated GitOps
```bash
# 1. Create provisioning request with SLO
./o2ims-sdk/o2imsctl pr create \
  --from examples/pr-with-slo.yaml \
  --wait

# 2. Query metrics
./slo-gated-gitops/job-query-adapter \
  --pr-id <provisioning-request-id> \
  --output artifacts/metrics.json

# 3. Evaluate gate
./slo-gated-gitops/gate \
  --slo "latency_p95_ms<=15,success_rate>=0.995" \
  --metrics artifacts/metrics.json
```

### Scenario 3: Security Validation
```bash
# 1. Verify image signatures
cosign verify --key cosign.pub <image>

# 2. Apply Kyverno policies
kubectl apply -f guardrails/kyverno/policies/

# 3. Test policy enforcement
kubectl apply -f samples/unsigned-deployment.yaml  # Should fail
```

## Configuration Requirements

### Environment Variables
```bash
# Required
export O2IMS_ENDPOINT="https://o2ims.example.com"
export O2IMS_TOKEN="<bearer-token>"
export KPT_FN_RUNTIME="docker"  # or "podman"

# Optional
export INTENT_GATEWAY_PORT="8080"
export LOG_LEVEL="info"  # debug|info|warn|error
export METRICS_EXPORT_INTERVAL="30s"
```

### Cluster Prerequisites
1. Nephio R5 installed with Porch backend
2. cert-manager for TLS certificates
3. Kyverno or OPA for policy enforcement
4. Prometheus/Grafana for observability (optional)

## Fallback Procedures

### Intent Gateway Unavailable
```bash
# Use direct validation
python -m jsonschema samples/tmf921/valid_intent_01.json \
  --schema guardrails/schemas/tmf921-intent.schema.json
```

### O2 IMS Connection Failed
```bash
# 1. Check connectivity
curl -k ${O2IMS_ENDPOINT}/o2ims/v1/health

# 2. Use mock mode
export O2IMS_MODE="mock"
./o2ims-sdk/o2imsctl pr create --from examples/pr.yaml

# 3. Fall back to kubectl
kubectl apply -f packages/intent-to-krm/
```

### SLO Evaluation Timeout
```bash
# 1. Check measurement job
./o2ims-sdk/o2imsctl mj status --id <job-id>

# 2. Use cached metrics
./slo-gated-gitops/gate \
  --slo "latency_p95_ms<=15" \
  --metrics artifacts/last-known-good-metrics.json \
  --allow-stale
```

## Troubleshooting

### Common Issues

#### 1. Schema Validation Failures
```bash
# Debug mode with detailed errors
./tools/intent-gateway/intent-gateway validate \
  --file input.json \
  --debug \
  --output-errors artifacts/validation-errors.json
```

#### 2. kpt Function Errors
```bash
# Run with verbose logging
kpt fn render packages/intent-to-krm/ --log-level debug

# Test function locally
cd kpt-functions/expectation-to-krm
go test -v ./...
```

#### 3. O2 IMS Authentication
```bash
# Refresh token
./scripts/refresh-o2ims-token.sh

# Test with curl
curl -H "Authorization: Bearer ${O2IMS_TOKEN}" \
  ${O2IMS_ENDPOINT}/o2ims/v1/provisioning-requests
```

### Debug Commands
```bash
# View all artifacts
ls -la artifacts/

# Check container logs
kubectl logs -n nephio-system deployment/intent-gateway

# Trace request flow
./scripts/trace-intent.sh --intent-id <id>

# Export debug bundle
make debug-bundle  # Creates artifacts/debug-bundle.tar.gz
```

## Performance Monitoring

### Key Metrics
- Intent validation latency (target: <100ms)
- TMF921→28.312 conversion time (target: <500ms)
- kpt function execution time (target: <2s)
- O2 IMS provisioning time (target: <30s)
- SLO evaluation frequency (default: 60s)

### Monitoring Commands
```bash
# Real-time metrics
watch -n 5 './scripts/metrics-summary.sh'

# Export Prometheus metrics
curl http://localhost:9090/metrics > artifacts/metrics-snapshot.txt

# Generate performance report
make perf-report
```

## Maintenance Windows

### Planned Maintenance
1. Announce 24h in advance via Slack/email
2. Switch to fallback mode: `make fallback-enable`
3. Perform maintenance
4. Validate: `make test-integration`
5. Resume normal operations: `make fallback-disable`

### Emergency Procedures
```bash
# Quick rollback
kubectl rollout undo deployment/intent-gateway -n nephio-system

# Circuit breaker
export CIRCUIT_BREAKER_ENABLED=true
./scripts/circuit-breaker.sh --action open

# Drain traffic
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets
```

## Contact Information

- **On-call**: Check PagerDuty schedule
- **Slack**: #nephio-intent-ops
- **Documentation**: https://docs.example.com/nephio-intent
- **Issue Tracker**: GitHub Issues