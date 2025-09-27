# Documentation Index

**Nephio Intent-to-O2IMS Demo**
**Version**: v1.1.1
**Last Updated**: 2025-09-27

This index provides a comprehensive guide to all documentation in this project, organized by category for easy navigation.

---

## 🚀 Quick Start Documents

| Document | Description | Location |
|----------|-------------|----------|
| **HOW_TO_USE.md** | Complete usage guide with examples | `/HOW_TO_USE.md` |
| **README.md** | Project overview and quick start | `/README.md` |
| **EXECUTIVE_SUMMARY.md** | One-page project summary | `/EXECUTIVE_SUMMARY.md` |
| **DEPLOYMENT_CHECKLIST.md** | Pre/post deployment procedures | `/docs/DEPLOYMENT_CHECKLIST.md` |

---

## 🏗️ Architecture & Design

### High-Level Architecture
- **[ARCHITECTURE_SIMPLIFIED.md](../ARCHITECTURE_SIMPLIFIED.md)** - Simplified architecture overview
- **[SYSTEM_ARCHITECTURE_HLA.md](architecture/SYSTEM_ARCHITECTURE_HLA.md)** - Detailed high-level architecture
- **[VM1_INTEGRATED_ARCHITECTURE.md](architecture/VM1_INTEGRATED_ARCHITECTURE.md)** - VM-1 orchestrator design
- **[THREE_VM_INTEGRATION_PLAN.md](architecture/THREE_VM_INTEGRATION_PLAN.md)** - Multi-VM integration architecture

### Component Architecture
- **[PROJECT_COMPREHENSIVE_UNDERSTANDING.md](../PROJECT_COMPREHENSIVE_UNDERSTANDING.md)** - Complete project analysis
- **O2IMS SDK** - `/o2ims-sdk/docs/O2IMS.md`
- **TMF921 Adapter** - `/adapter/README.md`, `/adapter/OPERATIONS.md`
- **Intent Gateway** - `/tools/intent-gateway/README.md`
- **Intent Compiler** - `/tools/intent-compiler/README.md`

### Design Decisions
- **[DEVELOPMENT_ACCELERATION_GUIDE.md](DEVELOPMENT_ACCELERATION_GUIDE.md)** - Development best practices
- **[IEEE_PAPER_2025.md](IEEE_PAPER_2025.md)** - Academic perspective on architecture
- **[PATENT_DISCLOSURE_ANALYSIS.md](PATENT_DISCLOSURE_ANALYSIS.md)** - Novel architecture elements

---

## 📋 Implementation Reports

### Core Implementation
| Report | Date | Description | Path |
|--------|------|-------------|------|
| **SLO Gate Implementation** | 2025-09-27 | SLO validation and rollback system | `/reports/SLO_GATE_IMPLEMENTATION_SUMMARY.md` |
| **Porch Deployment** | 2025-09-27 | Porch v1.5.3 deployment and verification | `/reports/porch-v1.5.3-deployment-20250927.md` |
| **Porch-Gitea Integration** | 2025-09-27 | Integration between Porch and Gitea | `/reports/porch-gitea-integration-20250927.md` |
| **KPT Validation** | 2025-09-27 | KPT function validation implementation | `/reports/kpt-validation-implementation.md` |
| **4-Site Support** | 2025-09-27 | Four edge site deployment support | `/reports/4-site-support-implementation-report.md` |
| **Edge4 Configuration** | 2025-09-27 | Edge4 site configuration and setup | `/reports/edge4-configuration-report-20250927.md` |

### Testing & Validation
| Report | Date | Description | Path |
|--------|------|-------------|------|
| **E2E Test Report** | 2025-09-27 | End-to-end pipeline testing | `/reports/e2e-test-report.md` |
| **E2E Pipeline Analysis** | 2025-09-27 | Pipeline performance analysis | `/reports/e2e-pipeline-analysis.md` |
| **ACC-19 Validation** | 2025-09-26 | Acceptance test validation | `/reports/ACC-19-VALIDATION-SUMMARY.md` |
| **Multi-Site Test** | 2025-09-26 | Multi-site deployment testing | `/reports/multi-site-test-result.md` |
| **SLO Gate Demo** | 2025-09-27 | SLO gate demonstration | `/reports/slo_gate_demo_20250927_045800/` |

### Infrastructure Updates
| Report | Date | Description | Path |
|--------|------|-------------|------|
| **O2IMS Port Update** | 2025-09-27 | O2IMS API port configuration | `/reports/o2ims-port-update.md` |
| **Config Sync Fix** | 2025-09-27 | Config Sync diagnosis and resolution | `/reports/config-sync-diagnosis-fix-20250927.md` |
| **VM4 Resolution** | 2025-09-26 | VM4 connectivity resolution | `/reports/vm4_final_resolution.md` |
| **Network Analysis** | 2025-09-26 | Network connectivity analysis | `/reports/network_connectivity_analysis.md` |

---

## 🧪 Testing & Validation

### Test Documentation
- **Test Execution** - `/tests/README.md` (if exists)
- **Golden Tests** - `/tests/test_golden.py`
- **Integration Tests** - Various test reports in `/reports/`

### Test Reports (Latest)
- **[slo_gate_integration_test_report.md](../reports/slo_gate_test_20250927_045552/slo_gate_integration_test_report.md)** - SLO gate integration testing
- **[slo_gate_integration_validation_report.md](../reports/slo_gate_validation_20250927_045938/slo_gate_integration_validation_report.md)** - SLO gate validation
- **[test-execution-summary.json](../reports/test-execution-summary.json)** - Test execution metrics

### Archived Test Reports
- See `/reports/archive/` for historical test reports

---

## 📖 Deployment Guides

### Deployment Documentation
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Complete deployment checklist
- **[DEMO.md](DEMO.md)** - Demo execution guide
- **[Summit Demo Guide](summit-demo/SUMMIT_DEMO_EXECUTION_GUIDE.md)** - Summit demonstration guide
- **[Summit Demo Flow](summit-demo/SUMMIT_DEMO_FLOW.md)** - Demo flow visualization

### Component Deployment
- **TMF921 Adapter** - `/reports/tmf921-adapter-deployment.md`
- **Porch Deployment** - `/reports/porch-v1.5.3-deployment-20250927.md`
- **Porch Official Compliance** - `/reports/porch-official-compliance-verification-20250927.md`
- **SSL Deployment** - `/reports/ssl-deployment-report-20250916-014317.md`

### Edge Site Onboarding
- **[EDGE_SITE_ONBOARDING_GUIDE.md](operations/EDGE_SITE_ONBOARDING_GUIDE.md)** - Edge site onboarding procedures
- **[EDGE_QUICK_SETUP.md](operations/EDGE_QUICK_SETUP.md)** - Quick setup guide for edge sites
- **[EDGE_SSH_CONTROL_GUIDE.md](operations/EDGE_SSH_CONTROL_GUIDE.md)** - SSH access management
- **[EDGE3_ONBOARDING_PACKAGE.md](operations/EDGE3_ONBOARDING_PACKAGE.md)** - Edge3 specific setup

---

## 🔧 Troubleshooting

### Operational Guides
- **[TROUBLESHOOTING.md](operations/TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
- **[OPERATIONS.md](../adapter/OPERATIONS.md)** - Adapter operations guide
- **[RUNBOOK.md](../RUNBOOK.md)** - Step-by-step operational procedures

### Diagnostic Guides
- **[VM4_DIAGNOSTIC_PROMPT.md](operations/VM4_DIAGNOSTIC_PROMPT.md)** - VM4 diagnostics
- **Network Diagnostics** - `/reports/network_connectivity_analysis.md`
- **Component Updates** - `/reports/component_update_summary.md`

### Known Issues & Resolutions
- **Config Sync Issues** - `/reports/config-sync-diagnosis-fix-20250927.md`
- **O2IMS API Issues** - `/reports/o2ims-api-fix-report.md`
- **VM4 Connectivity** - `/reports/vm4_final_resolution.md`

---

## 📚 API References

### API Documentation
- **O2IMS API** - `/o2ims-sdk/docs/O2IMS.md`
- **TMF921 Intent API** - `/adapter/README.md`
- **Intent Gateway API** - `/tools/intent-gateway/README.md`

### Standards & Specifications
- **TMF921** - TM Forum Intent Management API
- **3GPP TS 28.312** - Intent-driven management specification
- **O-RAN** - O-RAN Alliance specifications
- **Nephio** - Nephio project standards

### API Mappings
- **3GPP Mapping** - `/tools/tmf921-to-28312/docs/evidence/3gpp-mapping.md`

---

## 🔒 Security & Compliance

### Security Documentation
- **[SECURITY.md](SECURITY.md)** - Security guidelines and best practices
- **Security Reports** - `/reports/security-latest.json`
- **Guardrails** - `/guardrails/README.md`

### Compliance & Verification
- **Kyverno Policies** - `/guardrails/kyverno/README.md`
- **Sigstore Integration** - `/guardrails/sigstore/README.md`
- **Cert Manager** - `/guardrails/cert-manager/README.md`

---

## 📊 Monitoring & Observability

### Monitoring Architecture
- **[MONITORING_ARCHITECTURE.md](../k8s/monitoring/MONITORING_ARCHITECTURE.md)** - Monitoring system design
- **Prometheus Configuration** - `/k8s/monitoring/README.md`

### Performance & Metrics
- **SLO Gates** - `/reports/SLO_GATE_IMPLEMENTATION_SUMMARY.md`
- **Performance Analysis** - `/reports/e2e-pipeline-analysis.md`

---

## 📝 Network Configuration

### Network Documentation
- **[AUTHORITATIVE_NETWORK_CONFIG.md](network/AUTHORITATIVE_NETWORK_CONFIG.md)** - Official network configuration
- **Edge Sites Config** - `/config/edge-sites-config.yaml`
- **SSH Configuration** - `/docs/operations/EDGE_SSH_CONTROL_GUIDE.md`

### Network Topology
```
VM-1 (172.16.0.78)    - Orchestrator & Management
VM-2 (172.16.4.45)    - Edge Site 1 (edge1)
VM-4 (172.16.4.176)   - Edge Site 2 (edge2)
Edge3 (172.16.5.81)   - Edge Site 3
Edge4 (172.16.1.252)  - Edge Site 4
```

---

## 📚 Research & Publications

### Academic Papers
- **[IEEE_PAPER_2025.md](IEEE_PAPER_2025.md)** - IEEE ICC 2025 submission
- **[IEEE_PAPER_2025_ANONYMOUS.md](IEEE_PAPER_2025_ANONYMOUS.md)** - Anonymous version for review
- **[IEEE_PAPER_SUPPLEMENTARY.md](IEEE_PAPER_SUPPLEMENTARY.md)** - Supplementary materials
- **[IEEE_PAPER_FIGURES.md](IEEE_PAPER_FIGURES.md)** - Paper figures documentation
- **[IEEE_PAPER_REVIEW.md](IEEE_PAPER_REVIEW.md)** - Review preparation materials

### Research Materials
- **[REBUTTAL_MATERIALS_ICC2026.md](REBUTTAL_MATERIALS_ICC2026.md)** - Conference rebuttal materials
- **[SUPPLEMENTARY_MATERIALS_GUIDE.md](SUPPLEMENTARY_MATERIALS_GUIDE.md)** - Supplementary materials guide
- **[DOUBLE_BLIND_CHECKLIST.md](DOUBLE_BLIND_CHECKLIST.md)** - Double-blind review checklist
- **[ICC2026_SUBMISSION_TIMELINE.md](ICC2026_SUBMISSION_TIMELINE.md)** - Submission timeline and checklist

### Best Practices Research
- **[2025-best-practices-research.md](../reports/2025-best-practices-research.md)** - Research on 2025 best practices

---

## 📦 Historical Documents

### Archived Reports
Location: `/reports/archive/`

Archived reports include:
- Historical test results (timestamped directories)
- Outdated deployment analyses
- Previous implementation reports
- Legacy configuration files

### Changelog & History
- **[CHANGELOG.md](../CHANGELOG.md)** - Version history and changes
- **[COMPLETE_SUMMARY.md](../COMPLETE_SUMMARY.md)** - Complete project summary
- **[COMPLETION_REPORT_2025-09-26.md](COMPLETION_REPORT_2025-09-26.md)** - Project completion report
- **[COMPLETION_SUMMARY.md](COMPLETION_SUMMARY.md)** - Completion summary

---

## 🛠️ Development Resources

### Development Guides
- **[DEVELOPMENT_ACCELERATION_GUIDE.md](DEVELOPMENT_ACCELERATION_GUIDE.md)** - Accelerated development practices
- **[CLAUDE.md](../CLAUDE.md)** - Claude Code configuration and instructions
- **Project Understanding** - `/PROJECT_COMPREHENSIVE_UNDERSTANDING.md`

### Code Organization
- **Adapter** - `/adapter/`
- **Services** - `/services/`
- **Operator** - `/operator/`
- **Scripts** - `/scripts/` (86+ automation scripts)
- **Templates** - `/templates/` (Kpt & Porch templates)

---

## 📍 Service Endpoints Quick Reference

| Service | VM | Port | URL | Purpose |
|---------|----|----|-----|---------|
| Claude Headless | VM-1 | 8002 | http://172.16.0.78:8002/ | AI interface |
| Gitea | VM-1 | 8888 | http://172.16.0.78:8888/ | Git repository |
| Prometheus | VM-1 | 9090 | http://172.16.0.78:9090/ | Metrics |
| Grafana | VM-1 | 3000 | http://172.16.0.78:3000/ | Dashboards |
| O2IMS API (Edge1) | VM-2 | 31280 | http://172.16.4.45:31280/ | O-RAN API |
| O2IMS API (Edge2) | VM-4 | 31280 | http://172.16.4.176:31280/ | O-RAN API |
| Prometheus (Edge1) | VM-2 | 30090 | http://172.16.4.45:30090/ | Edge metrics |
| Prometheus (Edge2) | VM-4 | 30090 | http://172.16.4.176:30090/ | Edge metrics |

---

## 🔍 Document Search Tips

### By Category
- **Architecture**: Look in `/docs/architecture/`
- **Operations**: Look in `/docs/operations/`
- **Reports**: Look in `/reports/` (latest) or `/reports/archive/` (historical)
- **Research**: Look for `IEEE_*` or `PATENT_*` files in `/docs/`

### By Date
- Latest reports: `/reports/*.md` (dated 2025-09-27)
- Archived reports: `/reports/archive/` or timestamped directories

### By Component
- **TMF921**: Search for "tmf921" or "adapter"
- **Porch**: Search for "porch"
- **O2IMS**: Search for "o2ims"
- **Edge Sites**: Search for "edge1", "edge2", "edge3", "edge4"

---

## 📞 Getting Help

1. **Start Here**: [HOW_TO_USE.md](../HOW_TO_USE.md)
2. **Troubleshooting**: [TROUBLESHOOTING.md](operations/TROUBLESHOOTING.md)
3. **Architecture Questions**: [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](../PROJECT_COMPREHENSIVE_UNDERSTANDING.md)
4. **Deployment Issues**: [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
5. **Network Issues**: [AUTHORITATIVE_NETWORK_CONFIG.md](network/AUTHORITATIVE_NETWORK_CONFIG.md)

---

## 📅 Document Maintenance

### Latest Updates (2025-09-27)
- SLO Gate implementation and testing
- Porch v1.5.3 deployment verification
- Edge3/Edge4 site onboarding documentation
- Documentation consolidation and organization

### Next Review Date
**2025-10-27** (Monthly review cycle)

---

## 📝 Document Conventions

### Naming Conventions
- `UPPERCASE.md` - Major documentation files
- `lowercase.md` - Component-specific documentation
- `Component_Name.md` - Mixed case for specific components
- Dates in format: `YYYYMMDD` or `YYYY-MM-DD`

### Status Indicators
- ✅ - Completed, verified, operational
- 🚧 - In progress, under development
- ⚠️ - Warning, requires attention
- ❌ - Not working, requires fix
- 📌 - Important note
- 🔥 - Critical, urgent

---

**Documentation Index Version**: 1.0
**Last Updated**: 2025-09-27
**Maintained By**: Project Documentation Team