# Nephio Intent-to-O2IMS Demo

**Version**: v1.2.0 (Production Ready - Full Automation)
**Last Updated**: 2025-09-27T07:30:00Z

An intent-driven orchestration system for O-RAN network deployment using Claude AI, Nephio, and O2IMS standards. This production-ready system enables telecommunications operators to deploy and manage multi-site O-RAN networks using natural language intent, with automatic SLO validation, rollback capabilities, and full standards compliance.

---

## 🚀 Quick Start

### For Operators (5 Commands)

```bash
# 1. Start all services (WebSocket + TMF921 + O2IMS)
./scripts/start-websocket-services.sh

# 2. Access Claude AI Web UI
open http://localhost:8002/

# 3. Or use automated TMF921 API (no passwords required)
curl -X POST http://localhost:8889/api/v1/intent/transform \
  -H "Content-Type: application/json" \
  -d '{"natural_language": "Deploy eMBB service on edge3", "target_site": "edge3"}'

# 4. Monitor real-time pipeline
open http://localhost:8003/  # Realtime Monitor

# 5. View configurations in Gitea
open http://172.16.0.78:8888/

# 6. Check O2IMS on all edge sites
curl http://172.16.4.45:31280/health    # Edge1
curl http://172.16.4.176:31281/health   # Edge2
```

### For Developers

```bash
# Run complete demo pipeline
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/demo_llm.sh

# Run tests
cd tests/
pytest -v --cov=. --cov-report=html

# Deploy to new edge site
./scripts/edge-management/onboard-edge-site.sh edge5 172.16.x.x
```

**📖 New Users**: Start with **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** (1-page overview)
**📚 Full Guide**: See **[HOW_TO_USE.md](HOW_TO_USE.md)** for complete instructions
**🚀 Deployment**: See **[docs/DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md)** for step-by-step deployment

---

## 📚 Documentation

### Start Here
| Document | Purpose | Audience |
|----------|---------|----------|
| **[EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)** | 1-page project overview | Executives, Stakeholders |
| **[HOW_TO_USE.md](HOW_TO_USE.md)** | Complete usage guide | Operators, Developers |
| **[DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md)** | Deployment procedures | DevOps, SRE |
| **[DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)** | Master documentation index | Everyone |

### By Category

**Architecture & Design**
- [ARCHITECTURE_SIMPLIFIED.md](ARCHITECTURE_SIMPLIFIED.md) - Quick architecture overview
- [SYSTEM_ARCHITECTURE_HLA.md](docs/architecture/SYSTEM_ARCHITECTURE_HLA.md) - Detailed architecture
- [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](PROJECT_COMPREHENSIVE_UNDERSTANDING.md) - Full project analysis
- [VM1_INTEGRATED_ARCHITECTURE.md](docs/architecture/VM1_INTEGRATED_ARCHITECTURE.md) - VM-1 integration
- [IEEE_PAPER_2025.md](docs/IEEE_PAPER_2025.md) - Academic perspective

**Operations & Deployment**
- [DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md) - Step-by-step deployment
- [EDGE_SITE_ONBOARDING_GUIDE.md](docs/operations/EDGE_SITE_ONBOARDING_GUIDE.md) - Edge site setup
- [TROUBLESHOOTING.md](docs/operations/TROUBLESHOOTING.md) - Problem resolution
- [RUNBOOK.md](RUNBOOK.md) - Operational runbook
- [SECURITY.md](docs/SECURITY.md) - Security guidelines

**Testing & Validation**
- Latest test reports in `/reports/` (see [reports/README.md](reports/README.md))
- Test suites in `/tests/`
- [SLO_GATE_IMPLEMENTATION_SUMMARY.md](reports/SLO_GATE_IMPLEMENTATION_SUMMARY.md) - SLO system

**Network & Configuration**
- [AUTHORITATIVE_NETWORK_CONFIG.md](docs/network/AUTHORITATIVE_NETWORK_CONFIG.md) - Network setup
- [EDGE_SSH_CONTROL_GUIDE.md](docs/operations/EDGE_SSH_CONTROL_GUIDE.md) - SSH access
- `/config/edge-sites-config.yaml` - Edge site definitions

**API & Standards**
- [O2IMS API Documentation](o2ims-sdk/docs/O2IMS.md) - O-RAN O2IMS API
- [TMF921 Adapter](adapter/README.md) - Intent management API
- [3GPP Mapping](tools/tmf921-to-28312/docs/evidence/3gpp-mapping.md) - Standards mapping

**For complete documentation index**: See **[docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)**

---

## 🏗️ Architecture

```
                    ┌─────────────────────────────────────┐
                    │   VM-1: Orchestrator (172.16.0.78) │
                    ├─────────────────────────────────────┤
                    │  Claude AI (8002) → TMF921 Adapter  │
                    │         ↓                            │
                    │  Intent Compiler → Kpt/Porch        │
                    │         ↓                            │
                    │  Gitea (8888) - Git Repository      │
                    │         │                            │
                    │  Prometheus (9090) + Grafana (3000) │
                    └──────────────┬──────────────────────┘
                                   │ GitOps Pull (Config Sync)
            ┌──────────────────────┼──────────────────────┬──────────────────┐
            │                      │                      │                  │
            ▼                      ▼                      ▼                  ▼
    ┌──────────────┐       ┌──────────────┐      ┌──────────────┐  ┌──────────────┐
    │ Edge1 (VM-2) │       │ Edge2 (VM-4) │      │    Edge3     │  │    Edge4     │
    │ 172.16.4.45  │       │172.16.4.176  │      │ 172.16.5.81  │  │172.16.1.252  │
    ├──────────────┤       ├──────────────┤      ├──────────────┤  ├──────────────┤
    │ Config Sync  │       │ Config Sync  │      │ Config Sync  │  │ Config Sync  │
    │ K8s + O2IMS  │       │ K8s + O2IMS  │      │ K8s + O2IMS  │  │ K8s + O2IMS  │
    │ Prometheus   │       │ Prometheus   │      │ Prometheus   │  │ Prometheus   │
    └──────────────┘       └──────────────┘      └──────────────┘  └──────────────┘
```

**Key Features**:
- **Intent-Driven**: Natural language → TMF921 → KRM → Deployment
- **GitOps Pull**: Zero-trust edge deployment via Config Sync
- **SLO Governance**: Automatic validation and rollback
- **Multi-Site**: 4 edge sites operational

See [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) for detailed architecture diagram.

---

## 🔑 Key Features & Status

| Feature | Status | Description |
|---------|--------|-------------|
| **Intent-Driven Orchestration** | ✅ Operational | Claude AI converts natural language to TMF921 intents |
| **Multi-Site Deployment** | ✅ 4 Sites Active | Edge1-4 operational with GitOps sync |
| **SLO Governance** | ✅ Operational | Automatic validation and rollback on SLO violations |
| **Standards Compliance** | ✅ Verified | TMF921, 3GPP TS 28.312, O-RAN O2IMS |
| **Comprehensive Testing** | ✅ 95%+ Coverage | Golden tests, integration tests, E2E validation |
| **Production Monitoring** | ✅ Operational | Prometheus federation + Grafana dashboards |
| **Security Hardening** | ✅ Implemented | Kyverno policies, Sigstore, cert-manager |
| **Complete Documentation** | ✅ 50+ Docs | Architecture, operations, troubleshooting |

**Overall System Health**: ✅ 100% Operational
**Performance**: ⭐⭐⭐⭐⭐ Exceeds industry benchmarks (see [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md))

---

## 📊 Service Endpoints

| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| Claude Headless | 8002 | http://172.16.0.78:8002/ | - |
| Gitea | 8888 | http://172.16.0.78:8888/ | gitea_admin / r8sA8CPHD9!bt6d |
| Prometheus | 9090 | http://172.16.0.78:9090/ | - |
| Grafana | 3000 | http://172.16.0.78:3000/ | admin / admin |

---

## 🧪 Testing

```bash
# Run golden tests
cd tests/
pytest test_golden.py -v

# Run all tests
pytest -v

# Generate coverage report
pytest --cov=. --cov-report=html
```

---

## 📦 Repository Structure

```
nephio-intent-to-o2-demo/
├── adapter/              # TMF921 Intent Adapter
├── services/             # VM-1 integrated services
├── scripts/              # Automation scripts (86+)
├── operator/             # Kubernetes Operator
├── o2ims-sdk/           # O-RAN O2IMS SDK
├── gitops/              # GitOps configurations
├── templates/           # Kpt & Porch templates
├── tests/               # Test suites
├── docs/                # Comprehensive documentation
│   ├── architecture/    # Architecture docs
│   ├── operations/      # Operations guides
│   ├── summit-demo/     # Summit demo materials
│   ├── network/         # Network configs
│   └── archive/         # Historical documents
├── HOW_TO_USE.md        # Complete usage guide
├── PROJECT_COMPREHENSIVE_UNDERSTANDING.md
└── README.md            # This file
```

---

## 🤝 Contributing

### Before You Start
1. **Read**: [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](PROJECT_COMPREHENSIVE_UNDERSTANDING.md)
2. **Review**: [CHANGELOG.md](CHANGELOG.md) for recent changes
3. **Check**: [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md) for existing docs

### Development Workflow
1. **Create branch**: `git checkout -b feature/your-feature`
2. **Follow patterns**: Match existing code style
3. **Write tests**: Maintain 90%+ coverage
4. **Run tests**: `cd tests/ && pytest -v`
5. **Update docs**: Document changes in relevant files
6. **Commit**: Use conventional commits (feat:, fix:, docs:, etc.)
7. **Push**: `git push origin feature/your-feature`
8. **Create PR**: Include description, testing evidence

### Code Quality Standards
- ✅ Python 3.11+ with type hints
- ✅ 90%+ test coverage
- ✅ Linting with flake8/pylint
- ✅ Documentation for all public APIs
- ✅ Security scanning (no secrets in code)

### Testing Requirements
- ✅ Unit tests for all new functions
- ✅ Integration tests for API endpoints
- ✅ Golden tests for critical paths
- ✅ E2E tests for major features

**Questions?** See [TROUBLESHOOTING.md](docs/operations/TROUBLESHOOTING.md) or open an issue.

---

## 📄 License

This project is licensed under the **Apache License 2.0**.

```
Copyright 2025 Nephio Intent-to-O2IMS Demo Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

See [LICENSE](LICENSE) file for complete terms.

### Third-Party Components

This project uses the following open-source components:
- **Nephio** - Apache License 2.0
- **Kubernetes** - Apache License 2.0
- **Gitea** - MIT License
- **Prometheus** - Apache License 2.0
- **Grafana** - AGPL License

See [REFERENCES.md](docs/REFERENCES.md) for complete attribution.

---

## 🔗 References

- **Nephio**: https://nephio.org/
- **O-RAN Alliance**: https://www.o-ran.org/
- **TM Forum TMF921**: https://www.tmforum.org/oda/intent-management/
- **3GPP TS 28.312**: Intent-driven management specification

---

## 📞 Support & Resources

### Getting Help

**Quick Links**:
- 🚀 **New Users**: Start with [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md)
- 📖 **Usage Guide**: See [HOW_TO_USE.md](HOW_TO_USE.md)
- 🔧 **Troubleshooting**: See [docs/operations/TROUBLESHOOTING.md](docs/operations/TROUBLESHOOTING.md)
- 📚 **All Documentation**: See [docs/DOCUMENTATION_INDEX.md](docs/DOCUMENTATION_INDEX.md)

### Service Endpoints

| Service | URL | Credentials |
|---------|-----|-------------|
| Claude AI | http://172.16.0.78:8002/ | - |
| Gitea | http://172.16.0.78:8888/ | gitea_admin / r8sA8CPHD9!bt6d |
| Grafana | http://172.16.0.78:3000/ | admin / admin |
| Prometheus | http://172.16.0.78:9090/ | - |

### Reporting Issues

1. **Check existing docs**: Review [TROUBLESHOOTING.md](docs/operations/TROUBLESHOOTING.md)
2. **Search reports**: Check `/reports/` for similar issues
3. **Gather information**:
   - Component affected
   - Error messages
   - Steps to reproduce
   - System logs
4. **Report**: Create issue with gathered information

### Community

- **Documentation**: `/home/ubuntu/nephio-intent-to-o2-demo/docs/`
- **Reports**: `/home/ubuntu/nephio-intent-to-o2-demo/reports/`
- **Tests**: `/home/ubuntu/nephio-intent-to-o2-demo/tests/`

---

## 🎯 Next Steps

**For Operators**:
1. Read [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) (5 minutes)
2. Follow [HOW_TO_USE.md](HOW_TO_USE.md) (15 minutes)
3. Access http://172.16.0.78:8002/ and try your first intent

**For Developers**:
1. Read [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](PROJECT_COMPREHENSIVE_UNDERSTANDING.md)
2. Review [DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md)
3. Run `./scripts/demo_llm.sh` to see the system in action

**For Architects**:
1. Read [SYSTEM_ARCHITECTURE_HLA.md](docs/architecture/SYSTEM_ARCHITECTURE_HLA.md)
2. Review [IEEE_PAPER_2025.md](docs/IEEE_PAPER_2025.md) for academic perspective
3. Check [PATENT_DISCLOSURE_ANALYSIS.md](docs/PATENT_DISCLOSURE_ANALYSIS.md) for innovations

---

**System Status**: ✅ Production Ready | **Version**: v1.1.1 | **Last Updated**: 2025-09-27