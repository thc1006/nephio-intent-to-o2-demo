# Documentation Index

**Version**: v1.2.0
**Last Updated**: 2025-09-27T07:30:00Z
**Status**: Production Ready - 100% Complete with Full Automation

## 🚀 Latest Updates (v1.2.0 - 2025-09-27)

- ✅ **Full Automation**: All services operational without passwords
- ✅ **O2IMS Deployment**: 4 edge sites operational (31280/31281/32080)
- ✅ **TMF921 Automation**: API on port 8889, fully automated
- ✅ **WebSocket Services**: Real-time monitoring (8002/8003/8004)
- ✅ **100% Test Pass Rate**: All automated tests passing

Welcome to the Nephio Intent-to-O2IMS Demo documentation. This guide will help you navigate through all available documentation.

---

## 📚 Quick Navigation

### Getting Started
- [Main Project README](../README.md) - Project overview and quick start
- [HOW_TO_USE.md](../HOW_TO_USE.md) - Complete usage guide
- [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](../PROJECT_COMPREHENSIVE_UNDERSTANDING.md) - Full project analysis

### Architecture Documentation
- [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) - System architecture overview
- [architecture/TECHNICAL_ARCHITECTURE.md](architecture/TECHNICAL_ARCHITECTURE.md) - Technical deep dive
- [architecture/SYSTEM_ARCHITECTURE_HLA.md](architecture/SYSTEM_ARCHITECTURE_HLA.md) - High-level architecture
- [architecture/VM1_INTEGRATED_ARCHITECTURE.md](architecture/VM1_INTEGRATED_ARCHITECTURE.md) - VM-1 integration design
- [architecture/THREE_VM_INTEGRATION_PLAN.md](architecture/THREE_VM_INTEGRATION_PLAN.md) - Multi-VM integration
- [architecture/PIPELINE.md](architecture/PIPELINE.md) - Intent processing pipeline
- [architecture/GitOps_Multisite.md](architecture/GitOps_Multisite.md) - Multi-site GitOps
- [architecture/O2IMS.md](architecture/O2IMS.md) - O-RAN O2IMS integration
- [architecture/OCloud.md](architecture/OCloud.md) - O-Cloud infrastructure

### Deployment Guides
- [deployment/DEPLOYMENT_GUIDE.md](deployment/DEPLOYMENT_GUIDE.md) - Complete deployment guide
- [deployment/SETUP.md](deployment/SETUP.md) - Initial setup instructions
- [deployment/CONFIG_MANAGEMENT.md](deployment/CONFIG_MANAGEMENT.md) - Configuration management
- [deployment/DEPLOYMENT_GUARD.md](deployment/DEPLOYMENT_GUARD.md) - Deployment safety mechanisms
- [deployment/VM2_Manual.md](deployment/VM2_Manual.md) - VM-2 (Edge1) manual setup

### Operations Manuals
- [operations/OPERATIONS.md](operations/OPERATIONS.md) - Operations manual
- [operations/RUNBOOK.md](operations/RUNBOOK.md) - Operational runbook
- [operations/TROUBLESHOOTING.md](operations/TROUBLESHOOTING.md) - Troubleshooting guide
- [operations/SECURITY.md](operations/SECURITY.md) - Security guidelines
- [operations/SLO_GATE.md](operations/SLO_GATE.md) - SLO validation gates
- [operations/KPI_DASHBOARD.md](operations/KPI_DASHBOARD.md) - KPI monitoring
- [operations/TMF921_AUTOMATED_USAGE_GUIDE.md](operations/TMF921_AUTOMATED_USAGE_GUIDE.md) - TMF921 automation guide ⭐ NEW
- [operations/TMF921_AUTOMATION_SUMMARY.md](operations/TMF921_AUTOMATION_SUMMARY.md) - TMF921 summary ⭐ NEW
- [operations/OPENSTACK_COMPLETE_GUIDE.md](operations/OPENSTACK_COMPLETE_GUIDE.md) - OpenStack setup

### Development Documentation
- [development/CI_CD_GUIDE.md](development/CI_CD_GUIDE.md) - CI/CD pipeline guide
- [development/KRM_RENDERING_TDD.md](development/KRM_RENDERING_TDD.md) - KRM rendering with TDD
- [development/MODEL_MAP.md](development/MODEL_MAP.md) - Data model mapping

### Summit Demo Materials
- [summit-demo/SUMMIT_DEMO_EXECUTION_GUIDE.md](summit-demo/SUMMIT_DEMO_EXECUTION_GUIDE.md) - Summit execution guide
- [summit-demo/SUMMIT_DEMO_FLOW.md](summit-demo/SUMMIT_DEMO_FLOW.md) - Demo flow visualization
- [summit-demo/DEMO_PREP_CHECKLIST.md](summit-demo/DEMO_PREP_CHECKLIST.md) - Demo preparation
- [summit-demo/DEMO_QUICK_REFERENCE.md](summit-demo/DEMO_QUICK_REFERENCE.md) - Quick reference
- [summit-demo/SUMMIT_DEMO_PLAYBOOK.md](summit-demo/SUMMIT_DEMO_PLAYBOOK.md) - Complete playbook

### Network Configuration
- [network/AUTHORITATIVE_NETWORK_CONFIG.md](network/AUTHORITATIVE_NETWORK_CONFIG.md) - Network configuration source of truth

### Additional Resources
- [DEMO.md](DEMO.md) - Complete demo guide
- [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) - Executive summary
- [WEBSOCKET_SERVICES_GUIDE.md](WEBSOCKET_SERVICES_GUIDE.md) - WebSocket architecture guide ⭐ NEW
- [REFERENCES.md](REFERENCES.md) - External references
- [SECURITY.md](SECURITY.md) - Security documentation

### Academic Publications
- [IEEE_PAPER_2025.md](IEEE_PAPER_2025.md) - IEEE conference paper (publication-ready)
- [IEEE_PAPER_REVIEW.md](IEEE_PAPER_REVIEW.md) - Paper review and submission guide

---

## 📁 Documentation Structure

```
docs/
├── README.md                          # This file
├── DOCS_CLEANUP_ANALYSIS.md          # Cleanup analysis report
│
├── architecture/                      # Architecture documentation
│   ├── ARCHITECTURE.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── SYSTEM_ARCHITECTURE_HLA.md
│   ├── VM1_INTEGRATED_ARCHITECTURE.md
│   ├── THREE_VM_INTEGRATION_PLAN.md
│   ├── PIPELINE.md
│   ├── GitOps_Multisite.md
│   ├── O2IMS.md
│   └── OCloud.md
│
├── deployment/                        # Deployment guides
│   ├── DEPLOYMENT_GUIDE.md
│   ├── SETUP.md
│   ├── CONFIG_MANAGEMENT.md
│   ├── DEPLOYMENT_GUARD.md
│   └── VM2_Manual.md
│
├── operations/                        # Operations manuals
│   ├── OPERATIONS.md
│   ├── RUNBOOK.md
│   ├── TROUBLESHOOTING.md
│   ├── SECURITY.md
│   ├── SLO_GATE.md
│   ├── KPI_DASHBOARD.md
│   └── OPENSTACK_COMPLETE_GUIDE.md
│
├── development/                       # Development documentation
│   ├── CI_CD_GUIDE.md
│   ├── KRM_RENDERING_TDD.md
│   └── MODEL_MAP.md
│
├── summit-demo/                       # Summit demo materials
│   ├── SUMMIT_DEMO_EXECUTION_GUIDE.md
│   ├── SUMMIT_DEMO_FLOW.md
│   ├── DEMO_PREP_CHECKLIST.md
│   ├── DEMO_QUICK_REFERENCE.md
│   └── SUMMIT_DEMO_PLAYBOOK.md
│
├── network/                           # Network configuration
│   └── AUTHORITATIVE_NETWORK_CONFIG.md
│
├── reports/                           # Reports and analysis
│   ├── CLEANUP_REPORT_FINAL.md
│   ├── ENHANCEMENT_COMPLETION_REPORT.md
│   ├── ADAPTER_STATUS.md
│   ├── RELEASE_NOTES_v1.1.0.md
│   └── PROMPT_CONTRACT.md
│
├── vm-configs/                        # VM configuration details
│   └── VM4_ACTUAL_CONFIGURATION.md
│
└── archive/                           # Historical/deprecated documents
    ├── DEPLOYMENT_CONTEXT.md
    ├── GitOps-Edge1.md
    ├── OPERATIONS_ROOT_DEPRECATED.md
    ├── CI_CD_Pipeline_ZH.md
    ├── PACKAGE_ARTIFACTS_USAGE.md
    ├── OPENSTACK_SECURITY_GROUPS.md
    ├── SSL_TLS_INFRASTRUCTURE.md
    ├── FINAL_DEEP_ANALYSIS.md
    ├── GAP_CLOSURE_SUMMARY.md
    ├── SERVICES_DEPLOYMENT_RECORD.md
    ├── TEST_REPORT.md
    └── ULTIMATE_DEVELOPMENT_PLAN.md
```

---

## 🔍 Finding What You Need

### By Role

**New Users / Operators**:
1. Start with [Main README](../README.md)
2. Read [HOW_TO_USE.md](../HOW_TO_USE.md)
3. Follow [deployment/DEPLOYMENT_GUIDE.md](deployment/DEPLOYMENT_GUIDE.md)
4. Reference [operations/OPERATIONS.md](operations/OPERATIONS.md)

**Developers**:
1. Read [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](../PROJECT_COMPREHENSIVE_UNDERSTANDING.md)
2. Study [architecture/TECHNICAL_ARCHITECTURE.md](architecture/TECHNICAL_ARCHITECTURE.md)
3. Follow [development/CI_CD_GUIDE.md](development/CI_CD_GUIDE.md)
4. Reference [development/KRM_RENDERING_TDD.md](development/KRM_RENDERING_TDD.md)

**Architects**:
1. Review [architecture/SYSTEM_ARCHITECTURE_HLA.md](architecture/SYSTEM_ARCHITECTURE_HLA.md)
2. Study [architecture/VM1_INTEGRATED_ARCHITECTURE.md](architecture/VM1_INTEGRATED_ARCHITECTURE.md)
3. Understand [architecture/PIPELINE.md](architecture/PIPELINE.md)
4. Read [IEEE_PAPER_2025.md](IEEE_PAPER_2025.md) for academic perspective

**Demo Presenters**:
1. Study [summit-demo/SUMMIT_DEMO_EXECUTION_GUIDE.md](summit-demo/SUMMIT_DEMO_EXECUTION_GUIDE.md)
2. Use [summit-demo/DEMO_QUICK_REFERENCE.md](summit-demo/DEMO_QUICK_REFERENCE.md)
3. Follow [summit-demo/DEMO_PREP_CHECKLIST.md](summit-demo/DEMO_PREP_CHECKLIST.md)
4. Reference [DEMO.md](DEMO.md) for comprehensive guide

### By Topic

**Intent Processing**:
- [architecture/PIPELINE.md](architecture/PIPELINE.md)
- [HOW_TO_USE.md](../HOW_TO_USE.md) - Natural language examples

**GitOps & Multi-Site**:
- [architecture/GitOps_Multisite.md](architecture/GitOps_Multisite.md)
- [deployment/CONFIG_MANAGEMENT.md](deployment/CONFIG_MANAGEMENT.md)

**O-RAN & O2IMS**:
- [architecture/O2IMS.md](architecture/O2IMS.md)
- [architecture/OCloud.md](architecture/OCloud.md)

**SLO & Quality Gates**:
- [operations/SLO_GATE.md](operations/SLO_GATE.md)
- [operations/KPI_DASHBOARD.md](operations/KPI_DASHBOARD.md)

**Troubleshooting**:
- [operations/TROUBLESHOOTING.md](operations/TROUBLESHOOTING.md)
- [operations/RUNBOOK.md](operations/RUNBOOK.md)

**Security**:
- [operations/SECURITY.md](operations/SECURITY.md)
- [SECURITY.md](SECURITY.md)

---

## 📝 Document Conventions

### File Naming
- Use descriptive names with underscores or dashes
- Capitalize major words (e.g., `DEPLOYMENT_GUIDE.md`)
- Avoid spaces in filenames

### Content Organization
- Start with a clear title and version information
- Include table of contents for longer documents
- Use consistent heading hierarchy (H1 → H2 → H3)
- Include cross-references to related documents

### Maintenance
- Update `Last Updated` date when making changes
- Archive outdated content instead of deleting
- Keep version-specific information in reports/

---

## 🔗 External Resources

- **Project Repository**: https://github.com/thc1006/nephio-intent-to-o2-demo
- **Nephio**: https://nephio.org/
- **O-RAN Alliance**: https://www.o-ran.org/
- **TM Forum (TMF921)**: https://www.tmforum.org/
- **3GPP TS 28.312**: Intent-driven management specification

---

## 📞 Support

For questions or issues:
1. Check [operations/TROUBLESHOOTING.md](operations/TROUBLESHOOTING.md)
2. Review [HOW_TO_USE.md](../HOW_TO_USE.md)
3. Consult [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](../PROJECT_COMPREHENSIVE_UNDERSTANDING.md)
4. Open an issue on GitHub

---

**Documentation maintained by**: Nephio Intent-to-O2IMS Demo Team
**Last major reorganization**: 2025-09-26 (v1.2.0)