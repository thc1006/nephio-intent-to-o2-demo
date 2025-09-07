# Nephio Intent-to-O2 Demo Guide

Complete guide for running the one-click Nephio Intent-to-O2 demo showcasing the verifiable intent pipeline for Telco cloud & O-RAN.

## 🎯 Demo Overview

This demo demonstrates a complete **verifiable intent pipeline** that transforms TMF921 intents into O-RAN O2 IMS deployments using cloud-native technologies:

```
📡 TMF921 Intent → 3GPP TS 28.312 → KRM Packages → O2 IMS → GitOps Deployment
     (TIO/CTK)        (Expectation)    (kpt/Porch)   (ProvisioningRequest)   (SLO-gated)
```

### Key Features
- **🔒 Security-First**: Sigstore + Kyverno + cert-manager with default-on security
- **📊 SLO-Gated**: Automated rollback on threshold violations  
- **🏗️ Cloud-Native**: Nephio R5 + O-RAN integration with Kubernetes-native workflows
- **🎬 Presentation-Ready**: Visual progress indicators, timing metrics, comprehensive reporting

---

## 🚀 Quick Start

### One-Click Demo Execution
```bash
# Complete demo pipeline (recommended)
make demo

# Dry-run to preview steps
make demo DRY_RUN=true

# Demo with rollback demonstration
make demo && make demo-rollback
```

### Alternative Execution Methods
```bash
# Direct script execution with options
./scripts/demo_orchestrator.sh --mode presentation

# Development mode with debugging
DEMO_MODE=debug make demo

# Continue on errors for troubleshooting
CONTINUE_ON_ERROR=true make demo
```

---

## 📋 Prerequisites

### System Requirements

#### Required Tools
```bash
# Core tools (must be installed)
- kubectl (v1.28+)
- git (v2.30+)  
- jq (v1.6+)
- curl (v7.68+)
- make (v4.2+)
- python3.11
- go (v1.22+)

# Optional tools (for enhanced experience)
- kpt (v1.0+)
- kubeconform (v0.6+) 
- cosign (v2.0+)
```

#### Prerequisites Check
```bash
# Automated prerequisites validation
make check-prereqs

# Manual verification
kubectl cluster-info
git --version
jq --version
python3.11 --version
go version
```

### Network Configuration

#### Network Assumptions
- **Subnet**: 172.16.0.0/16 (VM-1 and VM-2 must be in this range)
- **VM-1 (Demo Host)**: Current machine running the demo
- **VM-2 (Edge Target)**: 172.16.4.45 (default, configurable)

#### Required Ports
| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| SSH | 22 | TCP | Remote access |
| Kubernetes API | 6443 | TCP | Cluster management |
| Gitea Web | 30080 | TCP | Git repository web UI |
| Observability | 30090 | TCP | Metrics and monitoring |

#### Network Validation
```bash
# Test VM-2 connectivity
ping -c 3 172.16.4.45

# Test port accessibility  
nc -zv 172.16.4.45 6443
nc -zv 172.16.4.45 30080

# Validate subnet configuration
ip route | grep 172.16
```

### Kubernetes Environment

#### Cluster Requirements
- **Kubernetes**: v1.28+ (kind, k3s, or managed clusters supported)
- **Nephio**: R5 release components installed
- **Porch**: Package orchestration system running
- **RBAC**: Cluster-admin permissions for CRD installation

#### Cluster Validation
```bash
# Verify cluster access
kubectl cluster-info

# Check Nephio components
kubectl get pods -n porch-system
kubectl get crd | grep porch

# Validate RBAC permissions
kubectl auth can-i create customresourcedefinitions
```

---

## 🎬 Demo Execution

### Complete Demo Pipeline

The demo executes the following sequence automatically:

#### Phase 1: Infrastructure Validation
```bash
# Step 1: p0-check
make p0-check
```
**Purpose**: Validates Nephio Phase-0 infrastructure readiness
- ✅ kubectl cluster connectivity
- ✅ porch-system pods running  
- ✅ Porch API resources available
- ✅ Configuration management (optional)

#### Phase 2: O2 IMS Installation  
```bash
# Step 2: o2ims-install
make o2ims-install
```
**Purpose**: Installs O-RAN O2 IMS operator components
- ✅ ProvisioningRequest CRD installation
- ✅ O2IMS operator deployment
- ✅ RBAC and service account setup
- ✅ Health check validation

#### Phase 3: O-Cloud Provisioning
```bash
# Step 3: ocloud-provision  
make ocloud-provision
```
**Purpose**: Provisions O-Cloud using FoCoM operator
- ✅ KinD cluster creation for SMO
- ✅ FoCoM operator deployment
- ✅ Edge cluster secret configuration
- ✅ O-Cloud custom resources application

#### Phase 4: Security Precheck
```bash
# Step 4: precheck
make precheck
```
**Purpose**: Supply chain security validation
- ✅ Container image signature verification
- ✅ Vulnerability scanning
- ✅ Policy compliance checking
- ✅ Security gate validation

#### Phase 5: Edge Overlay Publishing  
```bash
# Step 5: publish-edge
make publish-edge
```
**Purpose**: Publishes edge overlay with security validation
- ✅ KRM package validation
- ✅ Security compliance scoring
- ✅ GitOps repository publishing
- ✅ Deployment pipeline trigger

#### Phase 6: SLO Validation
```bash
# Step 6: postcheck
make postcheck
```
**Purpose**: Post-deployment SLO validation
- ✅ RootSync reconciliation monitoring
- ✅ VM-2 observability metrics validation
- ✅ SLO threshold compliance checking
- ✅ Automated rollback on violations

### Demo Timing and Performance

#### Expected Duration
- **Total Demo Time**: 15-25 minutes (depending on network and cluster)
- **Per-Step Timeout**: 5 minutes (configurable)
- **Network Tests**: 30 seconds
- **Security Validation**: 2-3 minutes

#### Performance Monitoring
```bash
# View demo progress in real-time
tail -f artifacts/demo/step-*.log

# Monitor Kubernetes resources
watch kubectl get pods -A

# Check demo artifacts
ls -la artifacts/demo/
```

---

## 📊 Demo Outputs and Artifacts

### Generated Artifacts

#### Execution Reports
```
artifacts/demo/
├── demo-report.json              # Complete execution summary
├── demo-report.html              # Visual presentation report  
├── step-1-p0-check.log          # Phase-0 validation log
├── step-2-o2ims-install.log     # O2IMS installation log
├── step-3-ocloud-provision.log  # O-Cloud provisioning log
├── step-4-precheck.log          # Security precheck log
├── step-5-publish-edge.log      # Edge publishing log
└── step-6-postcheck.log         # SLO validation log
```

#### Security and Compliance Reports
```
reports/
├── security-latest.json         # Comprehensive security report
├── security-YYYYMMDD-HHMMSS.json # Timestamped security snapshots
└── compliance-summary.json     # Policy compliance summary
```

#### Rollback Artifacts (if executed)
```
artifacts/demo-rollback/
├── rollback-audit-report.json   # Rollback execution audit
├── rollback-audit-report.html   # Visual rollback report
├── rollback-diff-report.html    # Before/after comparison
├── state-comparison.json        # System state diff analysis
└── state-snapshots/
    ├── before.json              # Pre-rollback system state
    └── after.json               # Post-rollback system state
```

### Success Indicators

#### Demo Success Criteria
- ✅ All 6 steps complete without errors
- ✅ Security compliance score ≥ 60%
- ✅ SLO thresholds met:
  - Latency P95 ≤ 15ms
  - Success rate ≥ 99.5%  
  - Throughput P95 ≥ 200 Mbps
- ✅ Kubernetes resources deployed successfully
- ✅ GitOps reconciliation completed

#### Visual Success Banner
```
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  🎉 DEMO SUCCESS! Intent-to-O2 Pipeline Completed Successfully      ║
║                                                                      ║
║  ✅ Phase-0 Infrastructure Validated                                ║  
║  ✅ O2 IMS Operator Installed                                       ║
║  ✅ O-Cloud Provisioned                                             ║
║  ✅ Security Precheck Passed                                        ║
║  ✅ Edge Overlay Published                                           ║
║  ✅ SLO Postcheck Validated                                         ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 🔄 Demo Rollback System

### Rollback Demonstration

#### Basic Rollback
```bash
# Execute rollback with state comparison  
make demo-rollback

# Rollback with custom reason
ROLLBACK_REASON="demo-reset" make demo-rollback

# Dry-run rollback preview
make demo-rollback DRY_RUN=true
```

#### Advanced Rollback Options
```bash
# Git revert strategy (preserves history)
ROLLBACK_STRATEGY=revert ./scripts/demo_rollback.sh

# Git reset strategy (clean rollback)
ROLLBACK_STRATEGY=reset ./scripts/demo_rollback.sh  

# Demonstration cleanup strategy
ROLLBACK_STRATEGY=demonstrate ./scripts/demo_rollback.sh
```

### Rollback Features

#### Before/After State Comparison
- **System State Snapshots**: Git, Kubernetes, O2IMS, filesystem
- **Visual Diff Reports**: HTML comparison with change highlighting
- **Impact Analysis**: Quantified changes with severity assessment
- **Audit Trail**: Complete rollback action logging

#### Rollback Strategies
| Strategy | Description | Use Case |
|----------|-------------|----------|
| `revert` | Git revert (preserves history) | Production-safe rollback |
| `reset` | Git reset to main branch | Clean slate rollback |
| `demonstrate` | Demo cleanup (artifacts, namespaces) | Demo reset for re-run |

---

## 🛠️ Configuration Options

### Environment Variables

#### Demo Configuration
```bash
# Demo execution mode
DEMO_MODE=presentation          # presentation|development|debug

# Network configuration
VM2_IP=172.16.4.45             # VM-2 IP address
NETWORK_SUBNET=172.16.0.0/16   # Expected network subnet

# Timeout configuration
TIMEOUT_STEP=300               # Per-step timeout (seconds)
TIMEOUT_TOTAL=1800             # Total demo timeout (seconds)

# Error handling
CONTINUE_ON_ERROR=false        # Continue on step failures
DRY_RUN=false                 # Dry-run mode

# Artifact configuration  
ARTIFACTS_DIR=./artifacts/demo # Artifacts output directory
SKIP_CLEANUP=false            # Skip cleanup on exit
```

#### Security Configuration
```bash
# Security validation levels
SECURITY_POLICY_LEVEL=strict   # strict|permissive
ALLOW_UNSIGNED=false          # Allow unsigned container images

# Compliance thresholds
COMPLIANCE_THRESHOLD=60       # Minimum compliance score (%)

# SLO thresholds
LATENCY_P95_THRESHOLD_MS=15           # Max latency P95 (ms)
SUCCESS_RATE_THRESHOLD=0.995          # Min success rate
THROUGHPUT_P95_THRESHOLD_MBPS=200     # Min throughput P95 (Mbps)
```

#### Rollback Configuration
```bash
# Rollback behavior
ROLLBACK_STRATEGY=revert       # revert|reset|demonstrate
ROLLBACK_REASON=SLO-violation  # Rollback reason
GENERATE_REPORTS=true          # Generate rollback reports
SHOW_VISUAL_DIFF=true         # Display visual differences
```

### Configuration Files

#### Demo Configuration File
Create `.demo.conf` in project root:
```bash
# Demo-specific configuration
DEMO_MODE=presentation
VM2_IP=172.16.4.45
ARTIFACTS_DIR=./artifacts/demo-$(date +%Y%m%d-%H%M%S)
CONTINUE_ON_ERROR=false
```

#### Security Configuration File  
Create `.security.conf` in project root:
```bash  
# Security validation configuration
SECURITY_POLICY_LEVEL=strict
COMPLIANCE_THRESHOLD=75
ALLOW_UNSIGNED=false
```

#### SLO Configuration File
Create `.postcheck.conf` in project root:
```bash
# SLO validation thresholds
LATENCY_P95_THRESHOLD_MS=10
SUCCESS_RATE_THRESHOLD=0.999
THROUGHPUT_P95_THRESHOLD_MBPS=300
```

---

## 🔍 Troubleshooting

### Common Issues and Solutions

#### Prerequisites Failures
**Issue**: Missing required tools
```bash
# Error: "kubectl is required but not installed"
# Solution: Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Issue**: Kubernetes cluster not accessible
```bash  
# Error: "Unable to connect to Kubernetes cluster"
# Solution: Configure kubeconfig
export KUBECONFIG=/path/to/your/kubeconfig
kubectl cluster-info
```

#### Network Connectivity Issues
**Issue**: Cannot reach VM-2
```bash
# Error: "VM-2 not accessible on common ports"
# Diagnosis steps:
ping -c 3 172.16.4.45
nc -zv 172.16.4.45 6443
nc -zv 172.16.4.45 30080

# Solutions:
# 1. Verify VM-2 is running and accessible
# 2. Check firewall rules
# 3. Verify security group configurations
# 4. Update VM2_IP environment variable if different
```

**Issue**: Wrong network subnet
```bash
# Error: "Local IP not in expected subnet"
# Solution: Override network assumptions
export NETWORK_SUBNET=your.actual.subnet/cidr
export VM2_IP=your.vm2.ip.address
```

#### Step-Specific Failures

**Phase-0 Check Failures**
```bash
# Issue: porch-system pods not running
kubectl get pods -n porch-system
kubectl describe pod -n porch-system

# Solution: Install/restart Nephio components
kubectl apply -f https://github.com/nephio-project/nephio/releases/latest/download/install.yaml
```

**O2IMS Installation Failures**
```bash
# Issue: CRD installation failed
# Solution: Check cluster-admin permissions
kubectl auth can-i create customresourcedefinitions

# Issue: Operator pods failing
kubectl logs -n o2ims deployment/o2ims-controller
```

**Security Precheck Failures**
```bash
# Issue: Security compliance score below threshold
# Solution: Review security report
jq '.security_report.summary.policy_compliance_score' reports/security-latest.json

# Solution: Run in development mode
SECURITY_POLICY_LEVEL=permissive make demo
```

**SLO Validation Failures**
```bash
# Issue: SLO thresholds not met
# Solution: Check VM-2 observability endpoint
curl -s http://172.16.4.45:30090/metrics/api/v1/slo | jq .

# Solution: Adjust thresholds for demo environment
export LATENCY_P95_THRESHOLD_MS=50
export SUCCESS_RATE_THRESHOLD=0.95
```

### Debug Mode Execution

#### Enable Debug Mode
```bash
# Full debug mode with verbose logging
DEMO_MODE=debug VERBOSE=true make demo

# Continue on errors for full diagnosis
CONTINUE_ON_ERROR=true DEMO_MODE=debug make demo

# Dry-run with debug information
DRY_RUN=true DEMO_MODE=debug make demo
```

#### Debug Artifacts
```bash
# Review all step logs
ls -la artifacts/demo/step-*.log
tail -f artifacts/demo/step-*.log

# Check demo report for failure details
jq '.steps[] | select(.status == "FAILED")' artifacts/demo/demo-report.json

# Review security report details
jq '.security_report.findings' reports/security-latest.json
```

### Recovery Procedures

#### Clean Recovery
```bash
# Full cleanup and restart
make clean
make demo-rollback ROLLBACK_STRATEGY=demonstrate
make demo
```

#### Partial Recovery  
```bash
# Skip completed phases
make o2ims-install    # If p0-check passed
make ocloud-provision # If o2ims-install passed
# ... continue from where it failed
```

#### Emergency Recovery
```bash
# Nuclear option: reset everything
git checkout main
make clean
./scripts/demo_rollback.sh --strategy reset
make demo
```

---

## 🎯 Demo Presentation Guidelines  

### For Evaluators and Reviewers

#### Presentation Flow
1. **Introduction (2 minutes)**
   - Show demo banner and overview
   - Explain the intent pipeline architecture  
   - Highlight security-first approach

2. **Prerequisites Validation (2 minutes)**
   - Run `make check-prereqs`
   - Show network connectivity to VM-2
   - Demonstrate Kubernetes cluster access

3. **One-Click Demo Execution (15-20 minutes)**
   - Execute `make demo`
   - Highlight progress indicators and timing
   - Show each phase completing successfully
   - Point out security validation gates

4. **Results Review (3 minutes)**
   - Show success banner
   - Navigate through generated artifacts
   - Open HTML reports in browser
   - Highlight key metrics and compliance scores

5. **Rollback Demonstration (5 minutes)**
   - Execute `make demo-rollback`
   - Show before/after state comparison
   - Highlight automated rollback capabilities
   - Show audit trail and impact analysis

#### Key Talking Points
- **Cloud-Native Architecture**: Kubernetes-native with GitOps workflows
- **Security Integration**: Default-on security with comprehensive validation
- **Standards Compliance**: TMF921, 3GPP TS 28.312, O-RAN specifications
- **Production Readiness**: SLO-gated deployments with automated rollback
- **Observability**: Comprehensive monitoring and reporting

### For Technical Audiences

#### Deep Dive Topics
- **Intent Transformation**: TMF921 → 28.312 → KRM mapping details
- **Security Architecture**: Sigstore, Kyverno, cert-manager integration
- **GitOps Implementation**: Flux/ArgoCD with Nephio R5
- **O2 IMS Integration**: ProvisioningRequest lifecycle management
- **SLO Implementation**: Metrics collection and threshold validation

#### Technical Demonstrations
```bash
# Show intent transformation pipeline
cd tools/intent-gateway && ./intent-gateway validate --file ../../samples/tmf921/emergency_slice_intent.json
cd tools/tmf921-to-28312 && ./tmf921-to-28312 convert --input ../../samples/tmf921/emergency_slice_intent.json

# Demonstrate security validation
make security-report-strict
jq '.security_report.summary' reports/security-latest.json

# Show O2 IMS integration
kubectl get provisioningrequests -A
kubectl describe provisioningrequest -n o2ims

# Monitor SLO validation  
curl -s http://172.16.4.45:30090/metrics/api/v1/slo | jq .
```

---

## 📚 Additional Resources

### Documentation References
- **Architecture**: [docs/ARCHITECTURE.md](./ARCHITECTURE.md)
- **Operations**: [docs/OPERATIONS.md](./OPERATIONS.md) 
- **Security**: [docs/SECURITY.md](./SECURITY.md)
- **Pipeline Details**: [docs/PIPELINE.md](./PIPELINE.md)
- **References**: [docs/REFERENCES.md](./REFERENCES.md)

### Component Documentation
- **Intent Gateway**: [tools/intent-gateway/README.md](../tools/intent-gateway/README.md)
- **TMF921-to-28312**: [tools/tmf921-to-28312/README.md](../tools/tmf921-to-28312/README.md)
- **O2IMS SDK**: [o2ims-sdk/README.md](../o2ims-sdk/README.md)
- **Security Guardrails**: [guardrails/README.md](../guardrails/README.md)

### External References
- **Nephio R5**: https://nephio.org/releases/r5
- **O-RAN O2 IMS**: https://docs.o-ran-sc.org/projects/o-ran-sc-smo-o2/en/latest/
- **TMF921**: https://www.tmforum.org/resources/specification/tmf921-intent-management-api/
- **3GPP TS 28.312**: https://www.3gpp.org/ftp/Specs/archive/28_series/28.312/
- **kpt Functions**: https://kpt.dev/book/04-using-functions/

### Support and Community
- **GitHub Issues**: [Project Issues](https://github.com/your-org/nephio-intent-to-o2-demo/issues)
- **Discussion Forum**: [GitHub Discussions](https://github.com/your-org/nephio-intent-to-o2-demo/discussions)  
- **Nephio Community**: [Nephio Slack](https://nephio.slack.com)
- **O-RAN Community**: [O-RAN Software Community](https://wiki.o-ran-sc.org/)

---

## 🏁 Summary

This comprehensive demo system provides:

✅ **One-Click Execution**: Complete pipeline with single `make demo` command  
✅ **Visual Progress**: Real-time progress indicators and timing metrics  
✅ **Comprehensive Reporting**: JSON and HTML reports with detailed analysis  
✅ **Security Integration**: Default-on security with compliance validation  
✅ **Automated Rollback**: SLO-gated deployments with automatic recovery  
✅ **Production-Ready**: Cloud-native architecture with GitOps workflows  
✅ **Presentation-Ready**: Visual banners, success indicators, and artifact generation  

The demo successfully showcases the complete **Nephio Intent-to-O2 pipeline** with verifiable security, automated deployment, and comprehensive observability suitable for evaluation, presentation, and production deployment scenarios.

---

*Generated by Nephio Intent-to-O2 Demo System - Comprehensive cloud-native intent pipeline for Telco & O-RAN*