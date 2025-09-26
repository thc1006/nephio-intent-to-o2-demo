# Supplementary Materials Structure
# IEEE ICC 2026 Submission

**Document Purpose:** Organization and structure of supplementary materials for paper submission
**Last Updated:** 2025-09-26
**Status:** ⏳ IN PREPARATION

---

## 1. Overview

The supplementary materials package provides complete reproducibility of the research presented in the IEEE ICC 2026 paper. All materials are organized for easy access and use by reviewers and future researchers.

**Total Package Size:** ~500MB (estimated)
**Distribution Method:** Anonymous repository (Zenodo / Anonymous GitHub)
**License:** Apache 2.0 (pending decision)

---

## 2. Directory Structure

```
nephio-intent-to-o2-demo-supplementary/
│
├── README.md                        # Main documentation
├── INSTALL.md                       # Installation guide
├── QUICKSTART.md                    # 15-minute quick start
├── LICENSE                          # Apache 2.0 license
│
├── code/                            # Source code
│   ├── intent-compiler/             # Intent processing engine
│   ├── orchestrator/                # Orchestration layer
│   ├── slo-validator/               # SLO validation framework
│   ├── rollback-controller/         # Automatic rollback logic
│   └── o2ims-adapter/               # O-RAN O2IMS integration
│
├── datasets/                        # Test datasets
│   ├── intents/                     # 1,000 intent samples
│   ├── krm-outputs/                 # Generated KRM resources
│   └── validation-results/          # Experimental results
│
├── scripts/                         # Automation scripts
│   ├── setup/                       # Environment setup
│   ├── deployment/                  # Deployment automation
│   └── testing/                     # Test execution
│
├── configs/                         # Configuration files
│   ├── vm1-orchestrator/            # VM-1 configs
│   ├── vm2-edge1/                   # VM-2 configs
│   └── vm4-edge2/                   # VM-4 configs
│
├── experiments/                     # Experimental data
│   ├── raw-data/                    # 30-day raw measurements
│   ├── analysis/                    # Statistical analysis notebooks
│   └── figures/                     # Generated figures
│
├── tests/                           # Test suites
│   ├── unit/                        # Unit tests
│   ├── integration/                 # Integration tests
│   └── compliance/                  # Standards compliance tests
│
├── docs/                            # Documentation
│   ├── architecture/                # System architecture docs
│   ├── api/                         # API documentation
│   └── tutorials/                   # Step-by-step tutorials
│
└── docker/                          # Containerization
    ├── Dockerfile                   # Main image
    ├── docker-compose.yml           # Multi-container setup
    └── kubernetes/                  # Kubernetes manifests
```

---

## 3. Detailed Component Descriptions

### 3.1. Code Organization

#### `code/intent-compiler/`
**Purpose:** LLM-based intent processing to TMF921 format

**Key Files:**
```
intent-compiler/
├── llm_processor.py          # Claude Code CLI integration
├── tmf921_adapter.py         # TMF921 standard compliance
├── fallback_engine.py        # Rule-based fallback
├── intent_validator.py       # Schema validation
└── requirements.txt          # Python dependencies
```

**Dependencies:**
- Python 3.10+
- Claude Code CLI
- jsonschema
- pydantic

**Size:** ~50KB code, ~500KB dependencies

---

#### `code/orchestrator/`
**Purpose:** KRM compilation and GitOps management

**Key Files:**
```
orchestrator/
├── krm_compiler.py           # Intent to KRM conversion
├── kpt_renderer.py           # kpt functions execution
├── gitops_manager.py         # Git repository management
├── config_sync_mgr.py        # Config Sync integration
└── requirements.txt
```

**Dependencies:**
- Python 3.10+
- kpt CLI
- git
- kubectl

**Size:** ~80KB code

---

#### `code/slo-validator/`
**Purpose:** SLO-gated deployment validation

**Key Files:**
```
slo-validator/
├── slo_gate.py               # Quality gates implementation
├── prometheus_client.py      # Metrics collection
├── deployment_checker.py     # Kubernetes deployment health
├── o2ims_checker.py          # O2IMS status verification
└── requirements.txt
```

**Key Features:**
- Multi-dimensional SLO validation
- Latency P95 < 50ms
- Throughput > 180 Mbps
- Success rate > 99%

**Size:** ~60KB code

---

#### `code/rollback-controller/`
**Purpose:** Automatic rollback on SLO failure

**Key Files:**
```
rollback-controller/
├── rollback_engine.py        # Main rollback logic
├── git_state_manager.py      # Git commit management
├── config_sync_forcer.py     # Force sync execution
└── recovery_validator.py     # Post-rollback validation
```

**Key Features:**
- 3.2 minute average MTTR
- 100% rollback success rate
- Automatic last-good-commit identification

**Size:** ~45KB code

---

#### `code/o2ims-adapter/`
**Purpose:** O-RAN O2IMS standard integration

**Key Files:**
```
o2ims-adapter/
├── o2ims_client.py           # O2IMS API client
├── provisioning_request.py   # Infrastructure provisioning
├── inventory_manager.py      # Resource inventory
└── deployment_manager.py     # Deployment management
```

**Standards Compliance:**
- O-RAN O2 Interface Specification v5.0
- Infrastructure Management Services (IMS)
- Deployment Management Services (DMS)

**Size:** ~70KB code

---

### 3.2. Datasets

#### `datasets/intents/`
**Contents:** 1,000 anonymized intent samples

**Format:**
```json
{
  "intentId": "intent_001",
  "name": "eMBB Slice for Edge Site 1",
  "service": {
    "type": "eMBB",
    "name": "high-bandwidth-video"
  },
  "targetSite": "edge1",
  "qos": {
    "latency_p95": "10ms",
    "throughput_min": "200Mbps"
  },
  "slice": {
    "isolation": "strict",
    "priority": "high"
  }
}
```

**Categories:**
- eMBB intents: 400 samples
- URLLC intents: 300 samples
- mMTC intents: 200 samples
- Complex multi-site: 100 samples

**Size:** ~5MB total

**Anonymization:** All IP addresses, hostnames, and identifying info removed

---

#### `datasets/krm-outputs/`
**Contents:** Generated Kubernetes Resource Model (KRM) outputs

**Format:** YAML files with Deployments, ConfigMaps, Services, etc.

**Size:** ~15MB total

---

#### `datasets/validation-results/`
**Contents:** Raw experimental results from 30-day validation

**Files:**
```
validation-results/
├── intent_processing_latency.csv     # 10,000 measurements
├── deployment_success_log.csv        # 1,050 deployment attempts
├── gitops_sync_metrics.csv           # Continuous sync measurements
├── slo_validation_results.csv        # Quality gate outcomes
└── rollback_performance.csv          # Rollback timing data
```

**Size:** ~50MB CSV data

---

### 3.3. Scripts

#### `scripts/setup/`
**Purpose:** Automated environment setup

**Key Scripts:**
```bash
setup/
├── 01_install_dependencies.sh        # Install kpt, kubectl, etc.
├── 02_setup_k3s.sh                    # Setup K3s cluster (VM-1)
├── 03_setup_k8s_edge.sh               # Setup K8s clusters (VM-2, VM-4)
├── 04_install_claude_cli.sh           # Install Claude Code CLI
└── 05_configure_gitops.sh             # Setup Gitea and Config Sync
```

**Execution Time:** ~30 minutes for full setup

---

#### `scripts/deployment/`
**Purpose:** Deployment automation

**Key Scripts:**
```bash
deployment/
├── deploy_orchestrator.sh             # Deploy orchestrator services
├── deploy_edge_sync.sh                # Deploy Config Sync to edges
├── deploy_slo_validator.sh            # Deploy SLO validation
└── deploy_monitoring.sh               # Deploy Prometheus stack
```

---

#### `scripts/testing/`
**Purpose:** Test execution automation

**Key Scripts:**
```bash
testing/
├── run_intent_tests.sh                # Test intent processing
├── run_deployment_tests.sh            # Test full deployment pipeline
├── run_chaos_tests.sh                 # Chaos engineering tests
└── run_compliance_tests.sh            # Standards compliance validation
```

---

### 3.4. Configuration Files

#### VM-Specific Configurations
Each VM has dedicated configuration directory with:
- Kubernetes manifests
- GitOps repository structure
- Monitoring configurations
- Network policies

**Size:** ~10MB total

---

### 3.5. Experimental Data

#### `experiments/raw-data/`
**Contents:** Complete 30-day production measurements

**Data Files:**
```
raw-data/
├── intent_processing/          # LLM processing metrics
├── deployment_cycles/          # Deployment success/failure logs
├── gitops_sync/                # Config Sync performance
├── slo_metrics/                # Prometheus time-series data
└── system_resources/           # CPU/Memory/Network utilization
```

**Format:** CSV, JSON, Prometheus TSDB snapshots

**Size:** ~200MB

---

#### `experiments/analysis/`
**Contents:** Jupyter notebooks for statistical analysis

**Notebooks:**
```
analysis/
├── 01_intent_latency_analysis.ipynb       # Latency distribution
├── 02_deployment_success_analysis.ipynb   # Success rate calculation
├── 03_gitops_performance.ipynb            # Sync performance analysis
├── 04_slo_validation_effectiveness.ipynb  # Quality gate analysis
└── 05_statistical_tests.ipynb             # t-tests, ANOVA, effect sizes
```

**Requirements:** Python 3.10+, Jupyter, matplotlib, pandas, scipy

**Size:** ~5MB

---

#### `experiments/figures/`
**Contents:** High-resolution figures for paper

**Files:**
```
figures/
├── figure1_architecture.pdf       # System architecture
├── figure2_topology.pdf           # Network topology
├── figure3_dataflow.pdf           # Data flow diagram
├── figure4_performance.pdf        # Performance over time
└── supplementary/                 # Additional figures
```

**Format:** PDF (300 DPI) + source files (TikZ, Python)

**Size:** ~20MB

---

### 3.6. Test Suites

#### `tests/unit/`
**Contents:** Unit tests for all components

**Coverage:** >80% code coverage

**Framework:** pytest

**Execution Time:** ~5 minutes

---

#### `tests/integration/`
**Contents:** Integration tests for end-to-end pipeline

**Scenarios:**
- Intent → KRM compilation
- GitOps deployment cycle
- SLO validation
- Automatic rollback

**Execution Time:** ~15 minutes

---

#### `tests/compliance/`
**Contents:** Standards compliance validation

**Tests:**
- TMF921 schema validation
- 3GPP TS 28.312 compliance
- O-RAN O2IMS API compliance

**Execution Time:** ~10 minutes

---

### 3.7. Documentation

#### `docs/architecture/`
**Contents:** System architecture documentation

**Files:**
```
architecture/
├── overview.md                 # High-level overview
├── intent-layer.md             # Intent processing details
├── orchestration-layer.md      # Orchestration engine
├── infrastructure-layer.md     # Multi-VM topology
└── design-decisions.md         # Design rationale
```

---

#### `docs/api/`
**Contents:** API documentation

**Files:**
```
api/
├── intent-api.md               # Intent submission API
├── tmf921-endpoints.md         # TMF921 REST API
├── o2ims-endpoints.md          # O2IMS API
└── prometheus-metrics.md       # Monitoring metrics
```

**Format:** OpenAPI 3.0 specifications + Markdown

---

#### `docs/tutorials/`
**Contents:** Step-by-step tutorials

**Tutorials:**
1. **Quick Start (15 minutes)**
   - Deploy minimal system
   - Submit first intent
   - Observe GitOps deployment

2. **Production Deployment (2 hours)**
   - Full multi-VM setup
   - Configure monitoring
   - Run validation tests

3. **Standards Compliance (1 hour)**
   - Validate TMF921 compliance
   - Test 3GPP TS 28.312 integration
   - Verify O2IMS functionality

4. **Extending the System (3 hours)**
   - Add new intent types
   - Implement custom SLO gates
   - Integrate additional LLM backends

---

### 3.8. Docker Containerization

#### `docker/Dockerfile`
**Purpose:** Containerized deployment for easy reproduction

**Base Image:** ubuntu:22.04

**Includes:**
- Python 3.10
- Claude Code CLI
- kpt
- kubectl
- Prometheus client

**Size:** ~800MB image

---

#### `docker/docker-compose.yml`
**Purpose:** Multi-container orchestration

**Services:**
- intent-compiler
- orchestrator
- slo-validator
- rollback-controller
- prometheus
- grafana

---

#### `docker/kubernetes/`
**Purpose:** Production-grade Kubernetes deployment

**Manifests:**
```
kubernetes/
├── namespaces/
├── deployments/
├── services/
├── configmaps/
├── secrets/                    # Templates only, no real secrets
└── monitoring/
```

---

## 4. README.md Structure

```markdown
# Intent-Driven O-RAN Network Orchestration - Supplementary Materials

Companion materials for IEEE ICC 2026 paper:
"Intent-Driven O-RAN Network Orchestration: A Production-Ready Multi-Site
System Integrating Large Language Models with GitOps"

## Quick Start (15 minutes)

```bash
# 1. Clone repository
git clone <anonymous-url>
cd nephio-intent-to-o2-demo-supplementary

# 2. Run setup script
./scripts/setup/quickstart.sh

# 3. Submit test intent
./scripts/testing/submit_test_intent.sh

# 4. Observe deployment
./scripts/monitoring/watch_deployment.sh
```

## Full Installation (see INSTALL.md)

## Reproducing Paper Results

See `experiments/README.md` for instructions on reproducing all experimental results from the paper.

## Citation

```bibtex
@inproceedings{anonymous2026intent,
  title={Intent-Driven O-RAN Network Orchestration: A Production-Ready Multi-Site System Integrating Large Language Models with GitOps},
  author={[ANONYMIZED FOR REVIEW]},
  booktitle={IEEE International Conference on Communications (ICC)},
  year={2026}
}
```

## License

Apache 2.0 (see LICENSE file)

## Contact

For questions, please contact via the conference submission system.
```

---

## 5. INSTALL.md Structure

**Sections:**
1. Prerequisites
2. Hardware Requirements
3. Software Dependencies
4. Step-by-Step Installation
5. Verification
6. Troubleshooting
7. FAQ

**Length:** ~500 lines, comprehensive guide

---

## 6. QUICKSTART.md Structure

**Goal:** Get system running in 15 minutes

**Steps:**
1. Prerequisites check (2 min)
2. Automated setup script (5 min)
3. Submit test intent (1 min)
4. Observe deployment (5 min)
5. Verify results (2 min)

---

## 7. Anonymization Checklist

Before publishing supplementary materials:

- [ ] Remove all author names from code
- [ ] Remove all institutional affiliations
- [ ] Anonymize IP addresses in configs
- [ ] Remove email addresses
- [ ] Remove proprietary information
- [ ] Remove .git history (use `git archive`)
- [ ] Use anonymous repository (Zenodo / Anonymous GitHub)
- [ ] Remove personal identifiers from datasets
- [ ] Generic contact info only

---

## 8. Distribution Method

### Option 1: Zenodo (Recommended)
**Pros:**
- Permanent DOI
- Versioned releases
- Academic-friendly
- Large file support (50GB limit)

**Cons:**
- Public after publication
- Cannot be updated after final publish

**URL Format:** `https://zenodo.org/record/XXXXXX`

---

### Option 2: Anonymous GitHub
**Pros:**
- Familiar to developers
- Version control
- Can be updated during review
- Good for code review

**Cons:**
- May reveal identity through commit patterns
- Not permanent

**URL Format:** `https://anonymous.4open.science/r/XXXX`

---

### Option 3: Conference Submission System
**Pros:**
- Integrated with submission
- Guaranteed anonymous
- Secure

**Cons:**
- File size limits
- Limited accessibility

---

## 9. Packaging Instructions

```bash
# 1. Clone repository
git clone https://github.com/your-org/nephio-intent-to-o2-demo.git
cd nephio-intent-to-o2-demo

# 2. Remove .git history
git archive --format=tar.gz --output=supplementary.tar.gz HEAD

# 3. Extract and anonymize
tar -xzf supplementary.tar.gz -C supplementary/
cd supplementary/

# 4. Run anonymization script
./scripts/anonymize/remove_identifiers.sh

# 5. Create final package
cd ..
tar -czf nephio-intent-to-o2-demo-supplementary-anonymous.tar.gz supplementary/

# 6. Upload to Zenodo or Anonymous GitHub
```

---

## 10. Verification Checklist

Before distribution:

- [ ] All scripts execute without errors
- [ ] Tests pass (unit, integration, compliance)
- [ ] Documentation is complete and accurate
- [ ] README provides clear instructions
- [ ] INSTALL guide is tested on fresh VM
- [ ] QUICKSTART completes in <20 minutes
- [ ] All datasets are anonymized
- [ ] No identifying information present
- [ ] License file included
- [ ] Citation information provided
- [ ] File sizes reasonable (<1GB total)

---

## 11. Post-Acceptance Updates

After paper acceptance, update supplementary materials to include:

1. **De-anonymize:**
   - Add author names
   - Add institutional affiliations
   - Add contact emails
   - Link to published paper

2. **Enhance:**
   - Add video tutorials
   - Add community forum/Discord link
   - Add contribution guidelines
   - Add roadmap for future development

3. **Promote:**
   - Blog post
   - Social media announcement
   - Mailing list notification
   - Conference presentation materials

---

## 12. Maintenance Plan

**During Review Period:**
- Monitor for issues
- Respond to reviewer requests
- Fix reported bugs
- Update documentation as needed

**Post-Publication:**
- Migrate from anonymous to public repository
- Set up CI/CD
- Establish issue tracking
- Create community guidelines
- Plan regular updates

---

## 13. Size Budget

| Component | Target Size | Actual Size (Est.) |
|-----------|-------------|-------------------|
| Code | 50MB | ~500KB |
| Datasets | 100MB | ~70MB |
| Experimental Data | 200MB | ~200MB |
| Documentation | 10MB | ~5MB |
| Docker Images | N/A | ~800MB (separate) |
| **Total** | **360MB** | **~275MB** |

**Distribution:** Within IEEE size limits ✅

---

## 14. Timeline

| Task | Duration | Deadline |
|------|----------|----------|
| Prepare code | 2 days | Week 3 (Oct) |
| Prepare datasets | 1 day | Week 3 (Oct) |
| Write documentation | 2 days | Week 4 (Oct) |
| Test installation | 1 day | Week 4 (Oct) |
| Anonymize | 0.5 days | Week 4 (Oct) |
| Package | 0.5 days | Week 4 (Oct) |
| Upload | 0.5 days | Week 4 (Oct) |
| **Total** | **7.5 days** | **End of Week 4** |

**Aligns with submission timeline** ✅

---

**Document Version:** 1.0
**Last Updated:** 2025-09-26
**Status:** Structure defined, implementation pending
**Next Step:** Begin code preparation (Week 3)

---

*This structure document serves as the blueprint for creating comprehensive, reproducible supplementary materials for the IEEE ICC 2026 submission.*