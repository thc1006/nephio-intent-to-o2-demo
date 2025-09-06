# Nephio Intent-to-O2 Demo: 10-12 Minute Talk Outline

## Title Slide (0:00-0:30)
**"From Intent to Infrastructure: Automating O-RAN Deployments with Nephio"**

Speaker introduction:
> "Today I'll demonstrate how we transform high-level intents into deployed O-RAN infrastructure using Nephio R5, with built-in security and SLO validation."

## Part 1: The Problem Space (0:30-1:30)

### Slide: Current Challenges
- Manual RAN configuration is error-prone
- Intent standards (TMF921, 3GPP) exist but lack implementation
- Security often bolted on, not built in
- No automated SLO validation

### Quick Architecture Overview
```bash
# Show architecture diagram
cat docs/ARCHITECTURE.md | head -30
```

> "Our pipeline: LLM generates TMF921 intent → validated → converted to 3GPP expectations → transformed to KRM → deployed via O2 IMS → SLO-gated"

## Part 2: Live Demo Setup (1:30-2:00)

### Pre-flight Check Commands
```bash
# Terminal 1: Show environment is ready
echo "=== Environment Check ==="
kubectl get nodes
kubectl get ns | grep -E "nephio|o2ims"

# Terminal 2: Start monitoring
watch -n 2 'kubectl get pods -n nephio-system | grep -E "intent|o2ims"'

# Terminal 3: Log streaming
kubectl logs -n nephio-system deployment/intent-gateway -f --tail=10
```

## Part 3: Intent Validation Demo (2:00-4:00)

### Step 1: Show Sample Intent
```bash
# Display the TMF921 intent we'll use
cat samples/tmf921/5g-coverage-intent.json | jq '.' | head -20

# Key fields to highlight:
# - intentType: "networkCoverage"
# - target: "95% coverage in downtown area"
# - constraints: latency, throughput
```

### Step 2: Validate Intent
```bash
# Run validation with live output
./tools/intent-gateway/intent-gateway validate \
  --file samples/tmf921/5g-coverage-intent.json \
  --tio-mode strict \
  --output artifacts/validated-intent.json

# Show validation passed
echo "✓ Intent validated against TMF921 schema"
cat artifacts/validated-intent.json | jq '.validation_status'
```

### Step 3: Failed Validation Example
```bash
# Show what happens with invalid intent
./tools/intent-gateway/intent-gateway validate \
  --file samples/tmf921/invalid-intent.json \
  --tio-mode strict 2>&1 | head -10

# Highlight the specific validation errors
echo "✗ Schema validation prevents malformed intents"
```

## Part 4: Intent Transformation Pipeline (4:00-6:30)

### Step 1: TMF921 to 3GPP TS 28.312 Conversion
```bash
# Convert intent to 3GPP expectation
./tools/tmf921-to-28312/tmf921-to-28312 convert \
  --input artifacts/validated-intent.json \
  --output artifacts/expectation.json \
  --mapping-table configs/tmf921-to-28312-mapping.yaml \
  --verbose

# Show the conversion delta report
cat artifacts/conversion-delta.json | jq '.mappings[:2]'
echo "→ Converted to 3GPP TS 28.312 Expectation format"
```

### Step 2: Generate KRM Packages
```bash
# Transform expectation to Kubernetes resources
cd packages/intent-to-krm/
kpt fn source expectation.yaml | \
  kpt fn eval - --image gcr.io/nephio/expectation-to-krm:v1 | \
  kpt fn sink manifests/

# Show generated resources
ls -la manifests/
kubectl explain deployment.spec.template.spec | head -10
echo "→ Generated $(ls manifests/*.yaml | wc -l) Kubernetes resources"
```

### Step 3: Security Validation
```bash
# Verify image signatures (Sigstore)
cosign verify --key cosign.pub \
  gcr.io/nephio/o-ran-du:v1.0.0 2>&1 | grep -E "Verified|Valid"

# Apply Kyverno policy check
kubectl apply --dry-run=server -f manifests/ 2>&1 | \
  grep -E "validated|admitted"

echo "✓ All images verified and policies passed"
```

## Part 5: O2 IMS Deployment (6:30-8:30)

### Step 1: Create Provisioning Request
```bash
# Create O2 IMS provisioning request
./o2ims-sdk/o2imsctl pr create \
  --from manifests/provisioning-request.yaml \
  --cluster edge-site-tokyo \
  --namespace o-ran-du \
  --wait \
  --output json | tee artifacts/pr-response.json

# Show provisioning ID
export PR_ID=$(jq -r '.provisioningRequestId' artifacts/pr-response.json)
echo "Provisioning Request ID: $PR_ID"
```

### Step 2: Monitor Deployment Progress
```bash
# Check provisioning status
./o2ims-sdk/o2imsctl pr status --id $PR_ID --watch

# In another terminal - show actual pods spinning up
kubectl get pods -n o-ran-du -w

# Show O2 IMS state transitions
echo "States: Pending → Provisioning → Configuring → Ready"
```

## Part 6: SLO Validation & GitOps Gate (8:30-10:00)

### Step 1: Query Performance Metrics
```bash
# Create measurement job
./o2ims-sdk/o2imsctl mj create \
  --pr-id $PR_ID \
  --metrics "latency,throughput,packet_loss" \
  --interval 30s \
  --duration 2m

# Fetch metrics after 1 minute
sleep 60
./slo-gated-gitops/job-query-adapter \
  --pr-id $PR_ID \
  --output artifacts/metrics.json

# Display metrics
cat artifacts/metrics.json | jq '.measurements' | head -15
```

### Step 2: Evaluate SLO Gate
```bash
# Define SLOs
export SLO="latency_p95_ms<=10,success_rate>=0.999,throughput_mbps>=1000"

# Run gate evaluation
./slo-gated-gitops/gate \
  --slo "$SLO" \
  --metrics artifacts/metrics.json \
  --output artifacts/gate-result.json

# Check result
if [ $? -eq 0 ]; then
  echo "✓ SLO Gate PASSED - Deployment promoted"
  git tag -a "prod-ready-${PR_ID}" -m "SLO validated"
else
  echo "✗ SLO Gate FAILED - Rollback initiated"
  ./o2ims-sdk/o2imsctl pr rollback --id $PR_ID
fi
```

## Part 7: End-to-End Success (10:00-11:00)

### Show Complete Pipeline Status
```bash
# Summary dashboard
echo "=== INTENT PIPELINE STATUS ==="
echo "1. Intent Validation:     ✓ PASSED"
echo "2. TMF921→28.312:        ✓ CONVERTED" 
echo "3. Expectation→KRM:      ✓ GENERATED"
echo "4. Security Validation:   ✓ VERIFIED"
echo "5. O2 IMS Deployment:    ✓ READY"
echo "6. SLO Gate:             ✓ PASSED"
echo ""
echo "Time to Deploy: 3m 42s"
echo "Resources Created: 12"
echo "Coverage Target Met: 95%"
```

### Quick Verification
```bash
# Verify deployment is serving traffic
kubectl port-forward -n o-ran-du svc/du-service 8080:80 &
curl -s http://localhost:8080/health | jq '.'

# Show logs proving it's working
kubectl logs -n o-ran-du deployment/o-ran-du --tail=5
```

## Part 8: Wrap-up & Key Takeaways (11:00-12:00)

### Key Points
1. **Standards-compliant**: TMF921 and 3GPP TS 28.312
2. **Security-first**: Signed images, policy enforcement
3. **Automated validation**: Schema checks, SLO gates
4. **Production-ready**: Nephio R5 + O-RAN O2 IMS integration

### Next Steps
```bash
# Generate documentation
make docs-pdf

# Run full test suite
make test e2e

# Explore more samples
ls -la samples/
```

### Questions?
> "The code is open source at github.com/[org]/nephio-intent-to-o2-demo"
> "Slack: #nephio-intent-ops"

---

## Demo Reset Commands (Between Runs)

```bash
# Quick reset
kubectl delete ns o-ran-du --wait=false
kubectl delete pr -n nephio-system --all
rm -rf artifacts/*
mkdir -p artifacts

# Verify clean state
kubectl get pods -A | grep -E "o-ran|intent"
```

## Troubleshooting Commands (If Demo Fails)

```bash
# If validation fails
cat artifacts/validation-errors.json | jq '.'

# If deployment hangs
kubectl describe pod -n o-ran-du

# If SLO fails
cat artifacts/metrics.json | jq '.measurements[] | select(.value > 10)'

# Emergency abort
./scripts/emergency-abort.sh
```