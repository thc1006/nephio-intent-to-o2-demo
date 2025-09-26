# Supplementary Materials Guide
# IEEE ICC 2026: Intent-Driven O-RAN Network Orchestration

**Purpose:** Complete guide for preparing reproducible supplementary materials
**Target:** IEEE ICC 2026 submission
**Status:** Template and structure ready for population

---

## Table of Contents

1. [Overview](#1-overview)
2. [Directory Structure](#2-directory-structure)
3. [Source Code Repository](#3-source-code-repository)
4. [Deployment Automation](#4-deployment-automation)
5. [Test Datasets](#5-test-datasets)
6. [Performance Measurement Tools](#6-performance-measurement-tools)
7. [Statistical Analysis](#7-statistical-analysis)
8. [Standards Compliance Tests](#8-standards-compliance-tests)
9. [Demo Video](#9-demo-video)
10. [Documentation](#10-documentation)

---

## 1. Overview

### Purpose of Supplementary Materials

Supplementary materials enable:
- **Reproducibility**: Other researchers can replicate experiments
- **Transparency**: Full disclosure of methodology and data
- **Validation**: Reviewers can verify claims independently
- **Community Impact**: Enable broader adoption and extensions

### What to Include

✅ **MUST Include:**
1. Source code (anonymized for double-blind)
2. Deployment scripts
3. Test datasets
4. Experimental data
5. Analysis scripts
6. README and documentation

✅ **SHOULD Include:**
7. Demo video
8. Performance measurement tools
9. Compliance test results
10. Configuration files

❌ **DO NOT Include:**
- Proprietary code or data
- Sensitive information (IPs, passwords, keys)
- Large binary files (> 100MB) - use external hosting
- Personally identifiable information

---

## 2. Directory Structure

### Recommended Structure

```
supplementary-materials/
├── README.md                          # Main entry point
├── LICENSE                            # Open source license (Apache 2.0 / MIT)
├── INSTALL.md                         # Installation guide
├── QUICKSTART.md                      # Quick start guide
│
├── src/                               # Source code
│   ├── intent-processor/             # LLM intent processing
│   │   ├── claude_service.py
│   │   ├── tmf921_adapter.py
│   │   ├── fallback_engine.py
│   │   └── README.md
│   │
│   ├── orchestrator/                 # Orchestration engine
│   │   ├── krm_compiler.py
│   │   ├── gitops_manager.py
│   │   ├── slo_validator.py
│   │   └── README.md
│   │
│   ├── o2ims/                        # O2IMS integration
│   │   ├── o2ims_client.py
│   │   ├── provisioning_handler.py
│   │   └── README.md
│   │
│   └── common/                       # Common utilities
│       ├── config.py
│       ├── logging.py
│       └── metrics.py
│
├── deployment/                        # Deployment automation
│   ├── kubernetes/                   # K8s manifests
│   │   ├── vm1-orchestrator/
│   │   ├── vm2-edge-site1/
│   │   ├── vm4-edge-site2/
│   │   └── README.md
│   │
│   ├── scripts/                      # Automation scripts
│   │   ├── setup-vm1.sh
│   │   ├── setup-edge-site.sh
│   │   ├── deploy-intent.sh
│   │   └── rollback.sh
│   │
│   ├── kpt/                          # KPT packages
│   │   ├── base-package/
│   │   ├── edge-variants/
│   │   └── README.md
│   │
│   └── docker/                       # Docker configs
│       ├── docker-compose.yml
│       ├── Dockerfile.orchestrator
│       └── Dockerfile.intent-processor
│
├── datasets/                          # Test datasets
│   ├── intents/                      # 1,000 intent samples
│   │   ├── embb/                     # eMBB slice intents
│   │   ├── urllc/                    # URLLC service intents
│   │   ├── mmtc/                     # mMTC deployment intents
│   │   ├── multi-site/               # Multi-site intents
│   │   └── README.md
│   │
│   ├── schemas/                      # JSON schemas
│   │   ├── tmf921-intent.schema.json
│   │   ├── krm-resource.schema.json
│   │   └── o2ims-request.schema.json
│   │
│   └── experimental-data/            # Raw experimental data
│       ├── 30day-deployments.csv
│       ├── intent-latencies.csv
│       ├── slo-violations.csv
│       └── README.md
│
├── tools/                             # Performance and testing tools
│   ├── load-testing/                 # Load test scripts
│   │   ├── locust-intents.py
│   │   ├── k6-gitops.js
│   │   └── README.md
│   │
│   ├── chaos-engineering/            # Chaos tests
│   │   ├── chaos-mesh-scenarios.yaml
│   │   ├── fault-injection-tests.py
│   │   └── README.md
│   │
│   ├── monitoring/                   # Monitoring setup
│   │   ├── prometheus-queries.yaml
│   │   ├── grafana-dashboards.json
│   │   └── README.md
│   │
│   └── compliance/                   # Standards compliance
│       ├── tmf921-validator.py
│       ├── 3gpp-ts28312-checker.py
│       ├── o2ims-conformance-tests.py
│       └── README.md
│
├── analysis/                          # Statistical analysis
│   ├── notebooks/                    # Jupyter notebooks
│   │   ├── 01-intent-latency-analysis.ipynb
│   │   ├── 02-deployment-success-analysis.ipynb
│   │   ├── 03-slo-validation-analysis.ipynb
│   │   ├── 04-comparative-analysis.ipynb
│   │   └── README.md
│   │
│   ├── scripts/                      # Analysis scripts
│   │   ├── generate-figures.py
│   │   ├── statistical-tests.R
│   │   └── README.md
│   │
│   └── results/                      # Analysis outputs
│       ├── figures/                  # Generated figures
│       ├── tables/                   # Generated tables
│       └── reports/                  # Statistical reports
│
├── docs/                              # Documentation
│   ├── architecture/                 # Architecture docs
│   │   ├── system-design.md
│   │   ├── data-flow.md
│   │   ├── deployment-model.md
│   │   └── diagrams/
│   │
│   ├── api/                          # API documentation
│   │   ├── intent-api.md
│   │   ├── tmf921-api.md
│   │   ├── o2ims-api.md
│   │   └── openapi.yaml
│   │
│   ├── deployment/                   # Deployment guides
│   │   ├── prerequisites.md
│   │   ├── vm1-setup.md
│   │   ├── edge-setup.md
│   │   ├── troubleshooting.md
│   │   └── FAQ.md
│   │
│   └── experiments/                  # Experiment methodology
│       ├── test-scenarios.md
│       ├── measurement-methodology.md
│       ├── data-collection.md
│       └── ethics-statement.md
│
├── videos/                            # Demo videos
│   ├── demo-overview.mp4             # 5-10 min overview
│   ├── intent-to-deployment.mp4      # Full pipeline demo
│   ├── slo-rollback.mp4              # Rollback demo
│   └── README.md                     # Video descriptions
│
└── ci/                                # CI/CD configs
    ├── .github/workflows/            # GitHub Actions
    ├── .gitlab-ci.yml                # GitLab CI
    ├── tests/                        # Automated tests
    └── README.md
```

---

## 3. Source Code Repository

### 3.1 Main README.md Template

```markdown
# Intent-Driven O-RAN Network Orchestration System
## Supplementary Materials for IEEE ICC 2026

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![Kubernetes 1.28+](https://img.shields.io/badge/kubernetes-1.28+-blue.svg)](https://kubernetes.io/)

This repository contains the complete implementation and supplementary materials
for our IEEE ICC 2026 paper: "Intent-Driven O-RAN Network Orchestration: A
Production-Ready Multi-Site System Integrating Large Language Models with GitOps
for Autonomous Infrastructure Management."

## 🎯 Quick Start

```bash
# Clone repository
git clone [anonymized-url]
cd supplementary-materials

# Install dependencies
pip install -r requirements.txt

# Run quick demo
./scripts/quickstart.sh
```

## 📊 Paper Claims and Verification

| Claim in Paper | How to Verify | Expected Result |
|----------------|---------------|-----------------|
| Intent latency < 150ms | `python tools/measure-latency.py` | Mean: 150ms ± 13ms |
| Deployment success 98.5% | `python analysis/success-rate.py` | 98.5% ± 0.8% |
| Rollback time 3.2 min | `python tools/test-rollback.py` | 3.2min ± 0.4min |
| Multi-site consistency 99.8% | `python tools/check-consistency.py` | 99.8% |

## 🏗️ System Architecture

[Architecture diagram]

## 📦 Components

- **Intent Processor**: Claude Code CLI integration with TMF921 adapter
- **Orchestration Engine**: KRM compiler + GitOps manager
- **SLO Validator**: Multi-dimensional quality gates
- **O2IMS Client**: O-RAN O2 interface implementation

## 🚀 Deployment

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

### Prerequisites
- 3 VMs (specs in paper Section V.A)
- Ubuntu 22.04 LTS
- Docker 24+, Kubernetes 1.28+
- Claude Code CLI (see setup guide)

### Quick Setup
```bash
# VM-1 (Orchestrator)
./deployment/scripts/setup-vm1.sh

# VM-2/VM-4 (Edge Sites)
./deployment/scripts/setup-edge-site.sh
```

## 📚 Documentation

- [Installation Guide](INSTALL.md)
- [Quick Start Guide](QUICKSTART.md)
- [Architecture Documentation](docs/architecture/)
- [API Reference](docs/api/)
- [Troubleshooting](docs/deployment/troubleshooting.md)

## 🧪 Experiments Reproduction

### Reproduce Paper Results

```bash
# Run all experiments (takes ~30 days for full validation)
python experiments/run-all.py

# Or run individual experiments:
python experiments/intent-latency-test.py      # Table III
python experiments/deployment-success-test.py   # Section V.B
python experiments/chaos-engineering-test.py    # Table V
```

### Generate Figures

```bash
# Generate all paper figures
python analysis/generate-figures.py --all

# Individual figures
python analysis/figure4-performance.py
```

## 📊 Datasets

- **Intent Samples**: 1,033 anonymized intent examples (`datasets/intents/`)
- **Experimental Data**: Raw 30-day deployment data (`datasets/experimental-data/`)
- **Schemas**: TMF921, KRM, O2IMS JSON schemas (`datasets/schemas/`)

## 🔬 Standards Compliance

```bash
# Run compliance tests
python tools/compliance/tmf921-validator.py
python tools/compliance/3gpp-ts28312-checker.py
python tools/compliance/o2ims-conformance-tests.py
```

Expected: 100% pass rate on all tests.

## 🎥 Demo Videos

- [System Overview](videos/demo-overview.mp4) - 5min introduction
- [Intent-to-Deployment](videos/intent-to-deployment.mp4) - Full pipeline
- [SLO Rollback](videos/slo-rollback.mp4) - Automatic recovery demo

## 📄 License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

[Anonymized for double-blind review]

## 📧 Contact

[Anonymized for double-blind review]

For issues, please use the GitHub issue tracker.

## 🌟 Citation

If you use this work, please cite:

```bibtex
[To be added after acceptance]
```

## ⚠️ Disclaimer

This is research software. Use in production environments at your own risk.
We provide no warranties or guarantees.
```

### 3.2 INSTALL.md Template

```markdown
# Installation Guide
## Intent-Driven O-RAN Orchestration System

## Prerequisites

### Hardware Requirements

**VM-1 (Orchestrator):**
- 4 vCPUs
- 8GB RAM
- 100GB SSD
- Ubuntu 22.04 LTS

**VM-2/VM-4 (Edge Sites):**
- 8 vCPUs
- 16GB RAM
- 200GB SSD
- Ubuntu 22.04 LTS

**Network:**
- 1 Gbps interconnects
- Internal network connectivity

### Software Prerequisites

**All VMs:**
```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install basic tools
sudo apt-get install -y \
    git curl wget \
    python3.10 python3-pip \
    docker.io docker-compose \
    kubectl
```

**VM-1 Additional:**
```bash
# Install K3s
curl -sfL https://get.k3s.io | sh -

# Install Claude Code CLI
# See: https://docs.claude.com/claude-code/installation
curl -fsSL https://claude.ai/install.sh | bash
```

**VM-2/VM-4 Additional:**
```bash
# Install Kubernetes (kubeadm)
# See: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
```

## Installation Steps

### Step 1: Clone Repository

```bash
git clone [repository-url]
cd supplementary-materials
```

### Step 2: Install Python Dependencies

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Configure Environment

```bash
# Copy example config
cp config.example.yaml config.yaml

# Edit config with your VM IPs
vim config.yaml

# Set environment variables
export VM1_IP="<vm1-ip>"
export VM2_IP="<vm2-ip>"
export VM4_IP="<vm4-ip>"
```

### Step 4: Setup VM-1 (Orchestrator)

```bash
# Run setup script
./deployment/scripts/setup-vm1.sh

# Verify services
kubectl get pods -n orchestrator
curl http://localhost:8002/health  # Claude service
curl http://localhost:8889/health  # TMF921 adapter
curl http://localhost:8888  # Gitea
```

### Step 5: Setup Edge Sites (VM-2 and VM-4)

```bash
# SSH to VM-2
ssh vm2
./deployment/scripts/setup-edge-site.sh --site edge01

# SSH to VM-4
ssh vm4
./deployment/scripts/setup-edge-site.sh --site edge02
```

### Step 6: Verify Installation

```bash
# Run health checks
python tools/health-check.py

# Expected output:
# ✅ VM-1 Orchestrator: Healthy
# ✅ VM-2 Edge Site 1: Healthy
# ✅ VM-4 Edge Site 2: Healthy
# ✅ GitOps Sync: Active
# ✅ Monitoring: Operational
```

### Step 7: Run Quick Test

```bash
# Deploy test intent
python tools/deploy-test-intent.py

# Monitor deployment
kubectl get deployments -A --watch

# Check SLO validation
python tools/check-slo.py
```

## Troubleshooting

### Common Issues

**1. Claude CLI not found**
```bash
# Solution: Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash
which claude  # Should show path
```

**2. K8s API server unreachable**
```bash
# Solution: Check firewall
sudo ufw allow 6443/tcp
sudo ufw allow 6444/tcp
```

**3. GitOps sync failing**
```bash
# Solution: Check Config Sync logs
kubectl logs -n config-management-system -l app=reconciler-manager
```

See [docs/deployment/troubleshooting.md](docs/deployment/troubleshooting.md)
for more issues.

## Next Steps

- [Quick Start Guide](QUICKSTART.md) - Run your first intent deployment
- [Experiment Reproduction](docs/experiments/reproduction.md) - Replicate paper results
- [API Documentation](docs/api/) - Integrate with your systems

## Support

For issues: [GitHub Issues](repository-url/issues)
```

### 3.3 QUICKSTART.md Template

```markdown
# Quick Start Guide
## Deploy Your First Intent in 5 Minutes

## Prerequisites

- ✅ System installed (see [INSTALL.md](INSTALL.md))
- ✅ All VMs healthy (`python tools/health-check.py`)
- ✅ Claude CLI configured

## Step 1: Write Your Intent (Natural Language)

Create a file `my-intent.txt`:

```
Deploy an eMBB slice to edge site 1 with the following requirements:
- Latency: < 10ms (95th percentile)
- Throughput: > 200 Mbps
- Availability: 99.9%
- Namespace: ran-slice-demo
```

## Step 2: Process Intent with LLM

```bash
python src/intent-processor/claude_service.py \
    --input my-intent.txt \
    --output intent.json

# View generated TMF921 intent
cat intent.json
```

## Step 3: Deploy Intent

```bash
python src/orchestrator/deploy_intent.py \
    --intent intent.json \
    --target edge01

# Monitor deployment
kubectl get deployments -n ran-slice-demo --watch
```

## Step 4: Validate SLO

```bash
# Wait 60 seconds for SLO validation
sleep 60

# Check SLO status
python src/orchestrator/slo_validator.py \
    --namespace ran-slice-demo

# Expected output:
# ✅ Latency P95: 8.3ms (< 10ms) PASS
# ✅ Throughput: 215 Mbps (> 200 Mbps) PASS
# ✅ Availability: 99.95% (> 99.9%) PASS
# ✅ Overall: DEPLOYMENT SUCCESS
```

## Step 5: Test Rollback (Optional)

```bash
# Inject fault to trigger rollback
python tools/chaos-engineering/inject-latency-fault.py \
    --namespace ran-slice-demo \
    --latency 50ms

# Watch automatic rollback (takes ~3.2 minutes)
python tools/monitor-rollback.py

# Expected output:
# ⚠️ SLO VIOLATION DETECTED: Latency 52ms > 10ms
# 🔄 ROLLBACK INITIATED: Reverting to last good commit
# ✅ ROLLBACK COMPLETE: Service restored in 3.1 minutes
```

## What Just Happened?

1. **Natural Language → Intent**: Claude LLM processed your English text
2. **Intent → KRM**: Orchestrator compiled to Kubernetes resources
3. **KRM → Deployment**: GitOps deployed to edge site
4. **SLO Validation**: Automatic quality gates verified deployment
5. **Rollback**: System detected violation and auto-recovered

## Next Steps

- **Explore Datasets**: See `datasets/intents/` for 1,000 more examples
- **Run Experiments**: `python experiments/run-all.py` to reproduce paper
- **Customize**: Modify intents, SLO thresholds, deployment targets
- **Monitor**: Grafana dashboards at `http://vm1-ip:3000`

## Need Help?

- 📖 [Full Documentation](docs/)
- 🐛 [Troubleshooting](docs/deployment/troubleshooting.md)
- 💬 [GitHub Discussions](repository-url/discussions)
```

---

## 4. Deployment Automation Scripts

### 4.1 setup-vm1.sh Template

```bash
#!/bin/bash
# VM-1 Orchestrator Setup Script
# Part of IEEE ICC 2026 Supplementary Materials

set -e  # Exit on error

echo "=== VM-1 Orchestrator Setup ==="
echo "This script will install and configure all orchestrator components."

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Install K3s
echo "📦 Installing K3s..."
curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Claude Code CLI
echo "📦 Installing Claude Code CLI..."
if ! command -v claude &> /dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
fi

# Deploy orchestrator components
echo "🚀 Deploying orchestrator components..."
kubectl apply -f deployment/kubernetes/vm1-orchestrator/

# Install Gitea
echo "📦 Installing Gitea..."
kubectl apply -f deployment/kubernetes/vm1-orchestrator/gitea.yaml

# Install VictoriaMetrics
echo "📊 Installing VictoriaMetrics..."
kubectl apply -f deployment/kubernetes/vm1-orchestrator/victoriametrics.yaml

# Install Grafana
echo "📊 Installing Grafana..."
kubectl apply -f deployment/kubernetes/vm1-orchestrator/grafana.yaml

# Wait for pods
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod \
    --all \
    --namespace=orchestrator \
    --timeout=300s

# Verify installation
echo "✅ Verifying installation..."
python3 tools/health-check.py --vm vm1

echo "🎉 VM-1 Orchestrator setup complete!"
echo ""
echo "Next steps:"
echo "  1. Setup edge sites: ./deployment/scripts/setup-edge-site.sh"
echo "  2. Run quick start: ./scripts/quickstart.sh"
```

---

## 5. Test Datasets

### 5.1 Intent Dataset Structure

```
datasets/intents/
├── README.md
├── embb/                             # eMBB slice intents (400 samples)
│   ├── embb-001.json
│   ├── embb-002.json
│   ...
│   └── embb-400.json
│
├── urllc/                            # URLLC service intents (300 samples)
│   ├── urllc-001.json
│   ...
│   └── urllc-300.json
│
├── mmtc/                             # mMTC deployment intents (233 samples)
│   ├── mmtc-001.json
│   ...
│   └── mmtc-233.json
│
├── multi-site/                       # Multi-site intents (100 samples)
│   ├── multi-001.json
│   ...
│   └── multi-100.json
│
└── schemas/
    ├── intent-schema.json
    └── validation-rules.json
```

### 5.2 Sample Intent JSON

```json
{
  "intentId": "intent-embb-001",
  "name": "eMBB Slice for Video Streaming",
  "naturalLanguageInput": "Deploy an eMBB slice to edge site 1 optimized for 4K video streaming with latency below 20ms",
  "tmf921Intent": {
    "intentId": "intent-embb-001",
    "intentType": "ServiceIntent",
    "service": {
      "name": "video-streaming-slice",
      "type": "eMBB",
      "serviceSpecification": {
        "sliceType": "eMBB",
        "useCaseProfile": "video-streaming"
      }
    },
    "targetSite": "edge01",
    "intentExpectations": [
      {
        "expectationId": "exp-latency",
        "expectationType": "QoSExpectation",
        "expectationTarget": {
          "target": "latency",
          "targetValueRange": {
            "max": 20,
            "unit": "ms"
          }
        }
      },
      {
        "expectationId": "exp-throughput",
        "expectationType": "QoSExpectation",
        "expectationTarget": {
          "target": "throughput",
          "targetValueRange": {
            "min": 180,
            "unit": "Mbps"
          }
        }
      }
    ],
    "lifecycle": "active"
  },
  "deploymentMetrics": {
    "intentProcessingLatency": 142,
    "krmCompilationLatency": 35,
    "deploymentDuration": 47,
    "sloValidationPassed": true
  },
  "anonymizationNote": "Actual site names and IPs anonymized for double-blind review"
}
```

---

## 6. Statistical Analysis Notebooks

### 6.1 Jupyter Notebook Template

```python
# analysis/notebooks/01-intent-latency-analysis.ipynb

"""
Intent Processing Latency Analysis
IEEE ICC 2026 Supplementary Materials

This notebook analyzes intent processing latency data to produce:
- Table III in the paper
- Statistical validation (95% CI, p-values)
- Distribution plots
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats
import seaborn as sns

# Load data
df = pd.read_csv('../../datasets/experimental-data/intent-latencies.csv')

# Basic statistics
print("Intent Processing Latency Statistics")
print("=" * 50)
print(f"Count: {len(df)}")
print(f"Mean: {df['latency_ms'].mean():.2f}ms")
print(f"Std Dev: {df['latency_ms'].std():.2f}ms")
print(f"95% CI: [{df['latency_ms'].quantile(0.025):.2f}, {df['latency_ms'].quantile(0.975):.2f}]ms")

# By intent type
print("\nBy Intent Type:")
print(df.groupby('intent_type')['latency_ms'].describe())

# Statistical tests
# H0: Mean latency = 150ms
t_stat, p_value = stats.ttest_1samp(df['latency_ms'], 150)
print(f"\nOne-sample t-test (H0: μ = 150ms)")
print(f"t-statistic: {t_stat:.4f}")
print(f"p-value: {p_value:.6f}")

# Effect size (Cohen's d)
cohen_d = (df['latency_ms'].mean() - 150) / df['latency_ms'].std()
print(f"Cohen's d: {cohen_d:.4f}")

# Generate figure
plt.figure(figsize=(10, 6))
sns.histplot(data=df, x='latency_ms', kde=True, bins=50)
plt.axvline(150, color='r', linestyle='--', label='Target (150ms)')
plt.xlabel('Latency (ms)')
plt.ylabel('Frequency')
plt.title('Intent Processing Latency Distribution (n=10,000)')
plt.legend()
plt.savefig('../../analysis/results/figures/latency-distribution.pdf', dpi=300)
plt.show()

print("\nFigure saved to: analysis/results/figures/latency-distribution.pdf")
```

---

## 7. Demo Video Script

### 7.1 Demo Video Outline

**Total Duration:** 5-10 minutes

**Segments:**

1. **Introduction** (30s)
   - System overview
   - Architecture diagram
   - Key features

2. **Intent Input** (1min)
   - Natural language input
   - TMF921 generation
   - Claude LLM processing

3. **Orchestration** (2min)
   - KRM compilation
   - GitOps commit and push
   - Edge site synchronization

4. **Deployment** (2min)
   - Kubernetes apply
   - Pod creation
   - Service startup

5. **SLO Validation** (2min)
   - Metrics collection
   - SLO gates checking
   - Success confirmation

6. **Rollback Demo** (2-3min)
   - Fault injection
   - SLO violation detection
   - Automatic rollback
   - Recovery verification

7. **Conclusion** (30s)
   - Results summary
   - Links to code and docs

### 7.2 Recording Checklist

- [ ] Record at 1080p minimum (1920x1080)
- [ ] Use clear narration or subtitles
- [ ] Show terminal commands clearly
- [ ] Highlight key transitions
- [ ] Add annotations for important steps
- [ ] Export as MP4 (H.264 codec)
- [ ] File size < 500MB (upload to YouTube if larger)

---

## 8. Compliance Test Suite

### 8.1 TMF921 Compliance Tests

```python
# tools/compliance/tmf921-validator.py

"""
TMF921 Intent Management API Compliance Validator
Tests all TMF921 requirements as specified in R20.0.1
"""

import json
import jsonschema
from typing import Dict, List

class TMF921Validator:
    def __init__(self, schema_path: str):
        with open(schema_path) as f:
            self.schema = json.load(f)

    def validate_intent_structure(self, intent: Dict) -> bool:
        """Validate intent against TMF921 schema"""
        try:
            jsonschema.validate(intent, self.schema)
            return True
        except jsonschema.ValidationError as e:
            print(f"❌ Schema validation failed: {e.message}")
            return False

    def test_intent_lifecycle(self) -> bool:
        """Test all intent lifecycle states"""
        states = ['draft', 'active', 'suspended', 'terminated']
        print("Testing Intent Lifecycle States...")

        for state in states:
            intent = self.create_test_intent(lifecycle=state)
            if not self.validate_intent_structure(intent):
                print(f"❌ Lifecycle state '{state}' failed validation")
                return False
            print(f"✅ Lifecycle state '{state}' passed")

        return True

    def run_all_tests(self) -> bool:
        """Run complete TMF921 compliance test suite"""
        tests = [
            ('Intent Structure', self.test_intent_structure),
            ('Intent Lifecycle', self.test_intent_lifecycle),
            ('Intent Expectations', self.test_intent_expectations),
            ('REST API', self.test_rest_api),
        ]

        results = []
        for test_name, test_func in tests:
            print(f"\nRunning: {test_name}")
            passed = test_func()
            results.append((test_name, passed))

        # Summary
        print("\n" + "=" * 50)
        print("TMF921 Compliance Test Results")
        print("=" * 50)
        for name, passed in results:
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"{name}: {status}")

        all_passed = all(p for _, p in results)
        print("\n" + ("✅ ALL TESTS PASSED" if all_passed else "❌ SOME TESTS FAILED"))
        return all_passed

if __name__ == "__main__":
    validator = TMF921Validator('datasets/schemas/tmf921-intent.schema.json')
    success = validator.run_all_tests()
    exit(0 if success else 1)
```

---

## 9. Anonymization Guide

### What to Anonymize for Double-Blind Review

✅ **MUST Anonymize:**
1. Author names and affiliations
2. Institution names
3. IP addresses (use XXX.XXX.X.XX)
4. Hostnames
5. Email addresses
6. Organization-specific terminology
7. Acknowledgments (replace with [ANONYMIZED])
8. Self-citations (rephrase or mark as [Author et al.])

✅ **Keep:**
1. System architecture
2. Performance data
3. Code (remove author comments)
4. Experimental methodology
5. Technical specifications

### Anonymization Script

```python
# tools/anonymize.py

import re
from pathlib import Path

def anonymize_file(filepath: Path):
    """Anonymize sensitive information in files"""
    content = filepath.read_text()

    # IP addresses
    content = re.sub(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
                     'XXX.XXX.X.XX', content)

    # Email addresses
    content = re.sub(r'[\w\.-]+@[\w\.-]+\.\w+',
                     '[anonymized-email]', content)

    # Common author markers
    content = content.replace('© 2025 Author', '© 2025 [ANONYMIZED]')
    content = content.replace('Contact:', 'Contact: [ANONYMIZED]')

    filepath.write_text(content)
    print(f"✅ Anonymized: {filepath}")

if __name__ == "__main__":
    # Anonymize all markdown and Python files
    for pattern in ['**/*.md', '**/*.py', '**/*.yaml']:
        for file in Path('.').glob(pattern):
            if 'venv' not in str(file) and '.git' not in str(file):
                anonymize_file(file)
```

---

## 10. Final Checklist

### Before Submission

- [ ] All code anonymized
- [ ] README.md complete and tested
- [ ] INSTALL.md verified on clean VMs
- [ ] QUICKSTART.md tested end-to-end
- [ ] All datasets included (or links provided)
- [ ] Experimental data uploaded
- [ ] Jupyter notebooks run successfully
- [ ] Demo video recorded and uploaded
- [ ] Compliance tests passing (100%)
- [ ] LICENSE file added
- [ ] .gitignore configured (exclude large files)
- [ ] Repository public or anonymous link created
- [ ] All links in paper point to repository
- [ ] Supplementary materials < 100MB or externally hosted

### Hosting Options

1. **GitHub** (Recommended)
   - Public repository
   - Use releases for large files
   - Enable GitHub Pages for docs

2. **Zenodo** (For archival)
   - DOI assigned
   - Permanent hosting
   - Version control

3. **Institutional Repository**
   - University servers
   - Stable URLs

4. **Anonymous GitHub**
   - For double-blind review
   - Use https://anonymous.4open.science/

---

**Document Version:** 1.0
**Last Updated:** September 26, 2025
**Status:** ✅ Ready for implementation

*This guide provides complete structure for creating reproducible supplementary materials for IEEE ICC 2026 submission.*