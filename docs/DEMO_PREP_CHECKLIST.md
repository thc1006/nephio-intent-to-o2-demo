# Demo Preparation Checklist

## 1 Week Before Demo

### Environment Setup
- [ ] Nephio R5 cluster operational
- [ ] O2 IMS simulator or test instance available  
- [ ] Kubernetes clusters: control plane + 2 edge sites
- [ ] Network connectivity verified between all components
- [ ] Backup cluster ready (separate namespace)

### Code Preparation
- [ ] All components pass `make test`
- [ ] E2E tests run successfully
- [ ] Demo branch created and protected
- [ ] All images pushed to registry
- [ ] Image signatures generated with cosign

### Documentation
- [ ] README.md updated with demo instructions
- [ ] Sample intents validated
- [ ] Backup video recorded
- [ ] Slides finalized

## 1 Day Before Demo

### System Checks
```bash
# Run pre-flight check script
./scripts/demo-preflight.sh

# Verify all namespaces
kubectl get ns | grep -E "nephio|o2ims|kyverno|cert-manager"

# Check all deployments are ready
kubectl get deploy -A | grep -v "1/1"

# Validate certificates
kubectl get cert -A
```

### Data Preparation
```bash
# Generate fresh demo data
./scripts/generate-demo-data.sh

# Pre-pull all images
for img in $(cat manifests/*.yaml | grep image: | cut -d: -f2-); do
  docker pull $img
done

# Stage sample intents
cp samples/tmf921/5g-coverage-intent.json artifacts/demo-intent.json
```

### Performance Optimization
```bash
# Warm up the pipeline
./tools/intent-gateway/intent-gateway validate \
  --file samples/tmf921/valid_intent_01.json \
  --tio-mode fake

# Pre-compile Python
python -m compileall tools/

# Build Go binaries
make build
```

## 1 Hour Before Demo

### Terminal Setup
```bash
# Terminal 1: Main demo
export PS1="\[\033[36m\]demo@nephio>\[\033[0m\] "
cd ~/nephio-intent-to-o2-demo
clear

# Terminal 2: Monitoring
watch -n 2 'kubectl get pods -n nephio-system | grep -v Completed'

# Terminal 3: Logs
kubectl logs -n nephio-system deployment/intent-gateway -f --tail=20

# Terminal 4: Emergency commands (hidden)
cat docs/DEMO_PREP_CHECKLIST.md | grep -A 20 "If Something Goes Wrong"
```

### Final Checks
```bash
# Test critical path
make demo-dry-run

# Verify network
ping -c 3 o2ims.example.com
curl -s ${O2IMS_ENDPOINT}/health | jq '.status'

# Check disk space
df -h | grep -E "/$|/var"

# Clear old artifacts
rm -rf artifacts/*.json artifacts/*.yaml
mkdir -p artifacts
```

### Browser Tabs (if showing dashboard)
1. Kubernetes Dashboard - Overview
2. Grafana - SLO Dashboard  
3. GitHub repo
4. Backup slides
5. Terminal emulator

## During Demo

### Starting Strong
```bash
# Clear and intro
clear
echo "=== Nephio Intent-to-O2 Demo ==="
echo "=== Transforming Intent to Infrastructure ==="
date
```

### Pacing Reminders
- **2 min**: Complete intent validation
- **4 min**: Reach KRM generation
- **6 min**: Start O2 IMS deployment
- **8 min**: Begin SLO validation
- **10 min**: Start wrapping up
- **11 min**: Q&A buffer

### Key Commands to Copy/Paste
```bash
# Intent validation (copy this)
./tools/intent-gateway/intent-gateway validate --file samples/tmf921/5g-coverage-intent.json --tio-mode strict --output artifacts/validated-intent.json

# TMF921 to 28.312 (copy this)
./tools/tmf921-to-28312/tmf921-to-28312 convert --input artifacts/validated-intent.json --output artifacts/expectation.json --verbose

# KRM generation (copy this)  
cd packages/intent-to-krm/ && kpt fn render && cd ../..

# O2 IMS deployment (copy this)
./o2ims-sdk/o2imsctl pr create --from manifests/provisioning-request.yaml --cluster edge-tokyo-1 --wait

# SLO check (copy this)
./slo-gated-gitops/gate --slo "latency_p95_ms<=10,success_rate>=0.999" --metrics artifacts/metrics.json
```

## If Something Goes Wrong

### Fallback Commands

#### Intent Validation Fails
```bash
# Use pre-validated intent
cp artifacts/backup/validated-intent.json artifacts/
echo "✓ Using cached validation result"
```

#### O2 IMS Unreachable
```bash
# Switch to mock mode
export O2IMS_MODE=mock
echo "ℹ Switched to O2 IMS mock mode"
./o2ims-sdk/o2imsctl pr create --from examples/pr.yaml
```

#### Deployment Hangs
```bash
# Show pre-deployed resources
kubectl get pods -n demo-backup
echo "ℹ Showing pre-deployed backup environment"
```

#### SLO Metrics Unavailable
```bash
# Use synthetic metrics
cp artifacts/backup/good-metrics.json artifacts/metrics.json
echo "ℹ Using synthetic metrics for demo"
```

### Recovery Phrases
- "Let me switch to our backup environment to save time"
- "In production, this would retry automatically"
- "I have a cached result from our earlier test run"
- "Let's look at the successful execution we recorded"

### Emergency Abort
```bash
# Kill everything and switch to slides
./scripts/emergency-abort.sh
echo "Switching to architectural discussion"
# Open backup slides
```

## After Demo

### Cleanup
```bash
# Save artifacts for analysis
tar -czf demo-artifacts-$(date +%Y%m%d-%H%M%S).tar.gz artifacts/

# Clean up resources
kubectl delete ns o-ran-du demo-backup
kubectl delete pr -A --all

# Reset to main branch
git checkout main
git pull origin main
```

### Follow-up
- [ ] Send thank you with links to:
  - GitHub repository
  - Recorded demo video
  - Documentation
  - Slack channel
- [ ] Log any issues encountered
- [ ] Update demo based on feedback
- [ ] Schedule retrospective

## Quick Reference Card

### Terminal Colors
```bash
# Success (green)
echo -e "\033[32m✓ Success\033[0m"

# Warning (yellow)  
echo -e "\033[33m⚠ Warning\033[0m"

# Error (red)
echo -e "\033[31m✗ Error\033[0m"

# Info (blue)
echo -e "\033[34mℹ Info\033[0m"
```

### Useful Aliases
```bash
alias k=kubectl
alias kn='kubectl -n nephio-system'
alias ko='kubectl -n o-ran-du'
alias kgp='kubectl get pods'
alias kgl='kubectl logs'
alias demo-reset='./scripts/demo-reset.sh'
```

### Speed Controls
- **Slow down**: Add `sleep 2` between commands
- **Speed up**: Use `&& \` to chain commands
- **Pause**: `read -p "Press enter to continue..."`

## Demo Recording Setup

### OBS Settings
- Canvas: 1920x1080
- FPS: 30
- Audio: -20db to -15db
- Scene 1: Full terminal
- Scene 2: Terminal + Browser split
- Scene 3: Slides

### Recording Checklist
- [ ] Microphone tested
- [ ] Screen recording started
- [ ] Backup recording running
- [ ] Do Not Disturb enabled
- [ ] Notifications disabled
- [ ] Browser in incognito mode