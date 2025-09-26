# Nephio Intent-to-O2IMS Demo

**Version**: v1.1.1 (Production Ready)
**Last Updated**: 2025-09-26

Intent-driven orchestration system for O-RAN network deployment using Claude AI, Nephio, and O2IMS standards.

---

## 🚀 Quick Start

### Prerequisites
- Claude Code CLI installed
- Kubernetes clusters (VM-1: management, VM-2/VM-4: edge sites)
- Python 3.11+, Docker, kpt, kubectl

### Fastest Way to Use

```bash
# Open Web UI in browser
http://172.16.0.78:8002/

# Or run complete demo
cd /home/ubuntu/nephio-intent-to-o2-demo
./scripts/demo_llm.sh
```

See **[HOW_TO_USE.md](HOW_TO_USE.md)** for complete usage guide.

---

## 📚 Documentation

### Essential Reading
- **[HOW_TO_USE.md](HOW_TO_USE.md)** - Complete usage guide
- **[PROJECT_COMPREHENSIVE_UNDERSTANDING.md](PROJECT_COMPREHENSIVE_UNDERSTANDING.md)** - Full project analysis
- **[ARCHITECTURE_SIMPLIFIED.md](ARCHITECTURE_SIMPLIFIED.md)** - Architecture overview
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

### Detailed Documentation
- **Architecture**: `docs/architecture/`
  - [SYSTEM_ARCHITECTURE_HLA.md](docs/architecture/SYSTEM_ARCHITECTURE_HLA.md) - High-level architecture
  - [VM1_INTEGRATED_ARCHITECTURE.md](docs/architecture/VM1_INTEGRATED_ARCHITECTURE.md) - VM-1 integration design
  - [THREE_VM_INTEGRATION_PLAN.md](docs/architecture/THREE_VM_INTEGRATION_PLAN.md) - Multi-VM integration plan

- **Operations**: `docs/operations/`
  - `OPERATIONS.md` - Operational procedures
  - `RUNBOOK.md` - Step-by-step runbook
  - `SECURITY.md` - Security guidelines
  - [TROUBLESHOOTING.md](docs/operations/TROUBLESHOOTING.md) - Troubleshooting guide

- **Summit Demo**: `docs/summit-demo/`
  - `SUMMIT_DEMO_EXECUTION_GUIDE.md` - Demo execution guide
  - `SUMMIT_DEMO_FLOW.md` - Demo flow visualization

- **Network**: `docs/network/`
  - [AUTHORITATIVE_NETWORK_CONFIG.md](docs/network/AUTHORITATIVE_NETWORK_CONFIG.md) - Network configuration

- **Historical**: `docs/archive/`
  - Past reports and analysis documents

---

## 🏗️ Architecture

```
VM-1 (172.16.0.78)        VM-2 (172.16.4.45)      VM-4 (172.16.4.176)
   Orchestrator               Edge Site 1             Edge Site 2
        │                         │                       │
   Claude CLI ──────────> Config Sync ──────────> Config Sync
   TMF921 Adapter              │                       │
   Gitea (8888)          Kubernetes              Kubernetes
   Monitoring            O2IMS                   O2IMS
```

See [ARCHITECTURE_SIMPLIFIED.md](ARCHITECTURE_SIMPLIFIED.md) for details.

---

## 🔑 Key Features

✅ **Intent-Driven**: Natural language → TMF921 → KRM → Deployment
✅ **Multi-Site**: GitOps pull-based deployment to edge sites
✅ **SLO Governance**: Automatic validation and rollback
✅ **Standards-Compliant**: TMF921, 3GPP TS 28.312, O-RAN
✅ **Production Ready**: Complete testing, monitoring, documentation

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

1. Read [PROJECT_COMPREHENSIVE_UNDERSTANDING.md](PROJECT_COMPREHENSIVE_UNDERSTANDING.md)
2. Check [CHANGELOG.md](CHANGELOG.md) for recent changes
3. Follow existing code patterns
4. Run tests before committing
5. Update documentation

---

## 📄 License

Apache License 2.0 - See [LICENSE](LICENSE) file.

---

## 🔗 References

- **Nephio**: https://nephio.org/
- **O-RAN Alliance**: https://www.o-ran.org/
- **TM Forum TMF921**: https://www.tmforum.org/oda/intent-management/
- **3GPP TS 28.312**: Intent-driven management specification

---

## 📞 Support

- Documentation: See `docs/` directory
- Issues: Check `docs/operations/TROUBLESHOOTING.md`
- Questions: Review [HOW_TO_USE.md](HOW_TO_USE.md)

---

**Ready to use?** → Open [HOW_TO_USE.md](HOW_TO_USE.md) 🚀