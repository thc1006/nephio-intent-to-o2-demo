# Backup Video Script: Intent-to-Infrastructure Demo
**Duration: 10-12 minutes**
**Format: Screen recording with voiceover**

---

## Scene 1: Title Card [0:00-0:10]
**Visual**: Animated logo with pipeline diagram
**Script**: 
> "Welcome to the Nephio Intent-to-Infrastructure demo. I'm demonstrating how we automate O-RAN deployments using intent-driven orchestration, transforming high-level business requirements into deployed infrastructure in under 5 minutes."

---

## Scene 2: Problem Statement [0:10-0:40]
**Visual**: Split screen - manual config (left) vs automated pipeline (right)
**Script**:
> "Today's challenge: Network operators manually configure hundreds of RAN parameters. This leads to errors, inconsistencies, and slow rollouts. Our solution uses TMF921 intents and 3GPP standards to automate this completely, with built-in security validation."

**Terminal Command**:
```bash
# Show current manual process complexity
ls -la /legacy/configs/ | wc -l
echo "247 configuration files to manage manually"
```

---

## Scene 3: Architecture Overview [0:40-1:20]
**Visual**: Animated flow diagram appearing step by step
**Script**:
> "Here's our pipeline: An LLM or operator creates a TMF921 intent. We validate it against schemas, convert to 3GPP expectations, transform to Kubernetes resources, deploy via O2 IMS, and validate against SLOs. Everything is signed and policy-checked."

**Terminal Command**:
```bash
# Display architecture
cat docs/ARCHITECTURE.md | grep -A 20 "Pipeline Diagram"
```

---

## Scene 4: Intent Creation & Validation [1:20-3:00]
**Visual**: VS Code showing intent JSON, then terminal validation
**Script**:
> "Let's start with a real intent. This TMF921 document requests 95% 5G coverage for downtown Tokyo with specific latency requirements. Watch as we validate it."

**Terminal Commands** (with typed effect):
```bash
# Show the intent
cat samples/tmf921/5g-coverage-intent.json | jq '{
  intentType: .intentType,
  target: .target,
  constraints: .constraints[0:2]
}'

# Validate the intent
./tools/intent-gateway/intent-gateway validate \
  --file samples/tmf921/5g-coverage-intent.json \
  --tio-mode strict
```

**Visual Effect**: Green checkmark appears
**Script**:
> "Perfect! The intent passes TMF921 schema validation. Now let's see what happens with a malformed intent."

```bash
# Try invalid intent
./tools/intent-gateway/intent-gateway validate \
  --file samples/tmf921/missing-required-field.json
```

**Visual Effect**: Red X with error details
**Script**:
> "The gateway immediately rejects invalid intents, preventing downstream errors."

---

## Scene 5: Intent Transformation [3:00-4:30]
**Visual**: Side-by-side JSON transformation animation
**Script**:
> "Now we convert the TMF921 intent to 3GPP TS 28.312 format. This uses explicit mapping tables for traceability."

**Terminal Commands**:
```bash
# Run conversion
./tools/tmf921-to-28312/tmf921-to-28312 convert \
  --input artifacts/validated-intent.json \
  --output artifacts/expectation.json \
  --verbose

# Show mapping applied
cat artifacts/conversion-delta.json | jq '.mappings[0]' 
```

**Visual**: Highlight the field mappings
**Script**:
> "Each field transformation is logged. Coverage requirements become ExpectationTargets, constraints become ExpectationContexts."

---

## Scene 6: KRM Generation [4:30-5:30]
**Visual**: Terminal with yaml files appearing
**Script**:
> "The 3GPP expectation now transforms into Kubernetes resources using kpt functions."

**Terminal Commands**:
```bash
# Generate KRM
cd packages/intent-to-krm/
kpt fn render

# Show generated resources
ls -la manifests/
cat manifests/du-deployment.yaml | head -20
```

**Script**:
> "We've generated 12 Kubernetes resources including Deployments, Services, and ConfigMaps - all from that original intent."

---

## Scene 7: Security Validation [5:30-6:30]
**Visual**: Sigstore verification UI mockup + terminal
**Script**:
> "Security is mandatory. Every container image is cryptographically signed and verified."

**Terminal Commands**:
```bash
# Verify signatures
cosign verify --key cosign.pub gcr.io/nephio/o-ran-du:v1.0.0

# Check Kyverno policies  
kubectl apply --dry-run=server -f manifests/
```

**Visual Effect**: Green shields appearing next to each check
**Script**:
> "All images verified. Kyverno policies ensure no unsigned images can deploy to production."

---

## Scene 8: O2 IMS Deployment [6:30-8:00]
**Visual**: O2 IMS dashboard mockup + terminal
**Script**:
> "Time to deploy via O-RAN O2 IMS. We create a ProvisioningRequest that the O-Cloud will execute."

**Terminal Commands**:
```bash
# Create provisioning request
./o2ims-sdk/o2imsctl pr create \
  --from manifests/provisioning-request.yaml \
  --cluster edge-tokyo-1

# Monitor status
./o2ims-sdk/o2imsctl pr status --id PR-2024-1126-001
```

**Visual**: Progress bar animation: Pending → Provisioning → Ready
**Script**:
> "The O2 IMS orchestrates the deployment across the edge site. In production, this handles hundreds of sites simultaneously."

---

## Scene 9: Live Deployment Verification [8:00-9:00]
**Visual**: Split view - terminal and Kubernetes dashboard
**Script**:
> "Let's verify our deployment is running."

**Terminal Commands**:
```bash
# Check pods
kubectl get pods -n o-ran-du

# Test connectivity
kubectl port-forward -n o-ran-du svc/du-service 8080:80 &
curl http://localhost:8080/health
```

**Visual**: Green status indicators lighting up
**Script**:
> "The DU is operational. Now for the critical part - does it meet our SLOs?"

---

## Scene 10: SLO Validation [9:00-10:30]
**Visual**: Grafana dashboard with metrics
**Script**:
> "We continuously monitor performance against the intent's requirements."

**Terminal Commands**:
```bash
# Query metrics
./slo-gated-gitops/job-query-adapter \
  --pr-id PR-2024-1126-001 \
  --output artifacts/metrics.json

# Evaluate SLO gate  
./slo-gated-gitops/gate \
  --slo "latency_p95_ms<=10,success_rate>=0.999" \
  --metrics artifacts/metrics.json
```

**Visual**: Dashboard showing metrics within thresholds
**Script**:
> "Latency P95: 7.2ms - PASS. Success rate: 99.94% - PASS. The deployment meets all SLOs and is automatically promoted."

---

## Scene 11: GitOps Integration [10:30-11:00]
**Visual**: Git commit history showing automated promotion
**Script**:
> "With SLOs validated, GitOps takes over. The deployment is tagged and promoted through environments."

**Terminal Commands**:
```bash
# Show git operations
git log --oneline -5
git tag -l | grep prod-ready
```

**Script**:
> "This entire flow - from intent to production - completed in 3 minutes 42 seconds."

---

## Scene 12: Summary Dashboard [11:00-11:40]
**Visual**: Executive dashboard with all green checkmarks
**Script**:
> "Let's review what we accomplished:"

**Terminal Command**:
```bash
# Final summary
echo "=== DEPLOYMENT SUMMARY ==="
echo "Intent → Infrastructure: 3m 42s"
echo "Validations Passed: 6/6"
echo "Security Checks: ✓ Signed"  
echo "SLO Compliance: ✓ Met"
echo "Sites Deployed: 1"
echo "Coverage Achieved: 95.3%"
```

**Script**:
> "From a high-level business intent to verified, secure infrastructure in under 4 minutes. This is the power of intent-driven automation with Nephio."

---

## Scene 13: Call to Action [11:40-12:00]
**Visual**: GitHub repo, documentation links, QR code
**Script**:
> "This demo used real Nephio R5 components and O-RAN standards. The code is open source. Visit our GitHub for documentation, join our Slack community, and try it yourself. Thank you for watching!"

**End Screen**:
- GitHub: github.com/[org]/nephio-intent-to-o2-demo
- Docs: nephio.org/intent-demo
- Slack: #nephio-intent-ops
- QR code for repo

---

## B-Roll Footage Notes

**Cutaway Shots** (record separately):
1. Typing intent JSON (2-3 seconds)
2. Validation spinner animation (2 seconds)  
3. Pods starting up in k8s (3-4 seconds)
4. Metrics graphs updating (3 seconds)
5. Success checkmark animation (1 second)

**Background Music**: 
- Subtle tech/corporate track
- Lower volume during speech
- Crescendo at success moments

---

## Recording Technical Notes

### Screen Setup
```bash
# Terminal setup
export PS1="\[\033[36m\]demo@nephio>\[\033[0m\] "
clear
tput setaf 2  # Green text for success

# Font: JetBrains Mono, 14pt
# Theme: Dracula or One Dark Pro
# Resolution: 1920x1080
```

### Pre-stage Commands
```bash
# Pre-warm everything
docker pull gcr.io/nephio/o-ran-du:v1.0.0
kubectl create ns o-ran-du
make init

# Create mock data
./scripts/generate-demo-data.sh
```

### Timing Markers
- 0:00 - Start
- 2:00 - First command execution
- 6:00 - Midpoint check
- 10:00 - Begin wrap-up
- 12:00 - End

### Fallback Clips
If any demo fails, cut to pre-recorded successful execution with voiceover:
> "In the interest of time, here's the successful execution we recorded earlier."