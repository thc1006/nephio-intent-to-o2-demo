# Nephio Intent-to-O2 Demo Talk (10-12 minutes)

## Talk Structure & Timeline

**Total Duration:** 10-12 minutes  
**Audience:** Cloud-native telco engineers, O-RAN developers  
**Goal:** Demonstrate verifiable intent pipeline from LLM to O-RAN O2 IMS

---

### 1. Opening Hook (1 min) - "The Telco Intent Challenge"

**Script:**
> "Imagine telling your cloud: 'Deploy a 5G slice with 99.9% availability for emergency services' and having it automatically generate secure, compliant infrastructure. Today we'll see this working end-to-end with standards-based intent translation."

**Slide:** Pipeline overview diagram
```
LLM → TMF921 Intent → 3GPP TS 28.312 → KRM → O-RAN O2 IMS → GitOps
```

---

### 2. Demo Setup & Prerequisites (1 min) - "Before We Start"

**Live Commands:**
```bash
# Show we're in the right environment
pwd
ls -la | head -10

# Quick health check
make check-prereqs
```

**Expected Output:** All green checkmarks for dependencies

**Backup Plan:** Pre-recorded screenshot of successful health check

---

### 3. Intent Creation & Validation (2 min) - "Speaking Telco Language"

**Demo Flow:**
```bash
# Show sample TMF921 intent
cat samples/tmf921/emergency_slice_intent.json | jq '.'

# Validate against TIO/CTK schema (RED test first)
cd tools/intent-gateway
python -m pytest tests/test_validation.py::test_emergency_slice_invalid -v
# This should FAIL initially

# Now validate the corrected intent (GREEN)
./intent-gateway validate --file ../../samples/tmf921/emergency_slice_intent.json --tio-mode strict
echo "Exit code: $?"
```

**Key Points:**
- TMF921 standard compliance
- TDD approach (RED → GREEN)
- Explicit exit codes for automation

**Backup Script:** Pre-validate all files, show JSON diff of fixes

---

### 4. Intent Translation (2.5 min) - "Standards Bridging"

**Demo Flow:**
```bash
# Convert TMF921 to 3GPP TS 28.312
cd ../tmf921-to-28312
./tmf921-to-28312 convert \
  --input ../../samples/tmf921/emergency_slice_intent.json \
  --output ../../artifacts/28312_expectation.json \
  --report ../../artifacts/conversion_report.json

# Show the transformation
echo "=== Original TMF921 ==="
jq '.intentSpecification.objectives[0]' ../../samples/tmf921/emergency_slice_intent.json

echo "=== Transformed 28.312 ==="
jq '.expectationContext.expectations[0]' ../../artifacts/28312_expectation.json

echo "=== Conversion Delta ==="
jq '.mappings | length' ../../artifacts/conversion_report.json
```

**Key Points:**
- Deterministic mapping tables
- Audit trail with delta reports
- Standards compliance at each step

**Backup Script:** Pre-generated artifacts with clear diff highlighting

---

### 5. KRM Package Generation (2 min) - "Cloud-Native Translation"

**Demo Flow:**
```bash
# Generate KRM packages via kpt function
cd ../../kpt-functions/expectation-to-krm
kpt fn render ../../packages/intent-to-krm/ --image gcr.io/nephio-intent/expectation-to-krm:v0.1.0

# Validate Kubernetes resources
cd ../../packages/intent-to-krm
kubeconform --summary --verbose *.yaml

# Show generated ConfigMap with SLO requirements
kubectl create --dry-run=client -o yaml -f slo-requirements.yaml
```

**Key Points:**
- kpt function SDK usage
- Kubernetes-native resources
- Built-in validation

**Backup Script:** Pre-rendered packages with kubeconform validation output

---

### 6. O2 IMS Integration (2.5 min) - "O-RAN Ready"

**Demo Flow:**
```bash
# Create O2 IMS Provisioning Request
cd ../../o2ims-sdk
./o2imsctl pr create --from ../samples/krm/provisioning_request.yaml --dry-run

# Show the O2 IMS API interaction (mock mode for demo)
export O2IMS_ENDPOINT="mock://demo"
./o2imsctl pr create --from ../samples/krm/provisioning_request.yaml
./o2imsctl pr status --id $(cat ../artifacts/pr_id.txt)

# Query performance metrics (O2 Measurement Job)
./o2imsctl measurement-job query \
  --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" \
  --format json | jq '.kpis'
```

**Key Points:**
- O-RAN O2 IMS standard compliance
- SLO-based validation
- Production-ready API integration

**Backup Script:** Mock O2 IMS responses with realistic data

---

### 7. Security & GitOps Gate (1.5 min) - "Security by Default"

**Demo Flow:**
```bash
# Show Sigstore verification (images must be signed)
cd ../../guardrails/sigstore
kubectl apply --dry-run=client -f policy-controller-config.yaml

# Kyverno policy enforcement
cd ../kyverno
kubectl apply --dry-run=client -f verify-images-policy.yaml

# SLO-gated GitOps check
cd ../../slo-gated-gitops/gate
./gate --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" \
      --kpi-source ../job-query-adapter/mock_metrics.json
echo "GitOps gate result: $?"
```

**Key Points:**
- Supply chain security (signed images only)
- Policy-as-code with Kyverno
- SLO-gated deployments prevent bad rollouts

**Backup Script:** Show policy violations being blocked

---

### 8. End-to-End Workflow (1 min) - "Putting It All Together"

**Demo Flow:**
```bash
# Complete pipeline in one command
make demo-full 2>&1 | tee ../artifacts/full_demo.log

# Show final GitOps-ready artifacts
ls -la artifacts/
git status
```

**Key Points:**
- Fully automated pipeline
- Deterministic artifacts
- Ready for production GitOps

**Backup Script:** Pre-recorded full pipeline run with timing

---

### 9. Closing & Q&A Setup (0.5 min) - "What's Next"

**Key Takeaways:**
- Standards-based intent translation (TMF921 → 28.312 → KRM → O2)
- Security by default (Sigstore + Kyverno)
- SLO-gated GitOps prevents bad deployments
- TDD approach ensures reliability

**Next Steps:**
- Try the demo: `git clone <repo> && make demo-full`
- Contribute: See CONTRIBUTING.md
- Questions?

---

## Backup Video Script

### Pre-recorded Segments (for live demo failures):

1. **"Intent Validation Success"** (30s)
   - Shows clean TMF921 validation with TIO/CTK schema
   - Highlights specific compliance points

2. **"Translation with Delta Report"** (45s)
   - TMF921 → 28.312 transformation
   - Side-by-side JSON diff with mapping explanation

3. **"KRM Generation & Validation"** (40s)
   - kpt function execution
   - kubeconform validation success
   - Generated Kubernetes resources

4. **"O2 IMS Integration"** (60s)
   - Provisioning Request creation
   - Status polling with realistic timing
   - Measurement Job Query results

5. **"Security Policies in Action"** (45s)
   - Policy violations being blocked
   - Successful signed image deployment
   - SLO gate preventing bad rollout

### Fallback Strategy:
- **Network issues:** Switch to pre-recorded O2 IMS interactions
- **Build failures:** Use pre-generated artifacts in `artifacts/demo-backup/`
- **Time overrun:** Skip to end-to-end video (segment 6)
- **Complete failure:** Show architecture slides + final results video

### Technical Contingencies:

```bash
# Quick recovery commands
make clean-demo-state
make demo-restore-checkpoint
make demo-fast-forward  # Skip to specific demo step

# Emergency artifacts
ls artifacts/demo-backup/
# Contains: validated intents, translations, KRM packages, mock responses
```

### Presenter Notes:
- **Keep energy high** - This is cutting-edge telco automation
- **Emphasize standards** - TMF921, 3GPP TS 28.312, O-RAN O2 IMS compliance
- **Show real value** - From intent to production-ready infrastructure
- **Security focus** - Supply chain protection built-in
- **Have backup ready** - Network demos can be unpredictable

### Questions Likely to Come Up:
1. **"How does this compare to Terraform/Ansible?"**
   - Standards-based (TMF921/28.312) vs proprietary
   - Intent-level abstraction vs infrastructure-level
   - Telco-specific SLO validation

2. **"What about production deployment?"**
   - Show Sigstore/Kyverno integration
   - Mention GitOps compatibility
   - Highlight audit trails

3. **"Performance at scale?"**
   - Show O2 Measurement Job Query integration
   - Mention SLO-gated deployment gates
   - Reference load testing in CI

4. **"Vendor lock-in concerns?"**
   - All standards-based (TMF, 3GPP, O-RAN)
   - Open source components only
   - Multi-cloud Kubernetes foundation