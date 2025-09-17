# Nephio Intent-to-O2IMS Demo

## Overview
This project demonstrates an end-to-end pipeline from natural language intent to O-RAN O2IMS deployment using Nephio, GitOps, and cloud-native technologies.

## Architecture
- **SMO/GitOps Orchestrator**: VM-1 (Current VM)
- **Edge Site 1**: VM-2 (172.16.4.45)
- **LLM Adapter Service**: VM-3 (Configure via VM3_IP environment variable)
- **Edge Site 2**: VM-4 (172.16.4.176)

## Key Documentation

### Core References
- **[AUTHORITATIVE_NETWORK_CONFIG.md](AUTHORITATIVE_NETWORK_CONFIG.md)** - Network configuration source of truth
- **[SYSTEM_ARCHITECTURE_HLA.md](SYSTEM_ARCHITECTURE_HLA.md)** - System architecture overview
- **[SUMMIT_DEMO_GUIDE.md](SUMMIT_DEMO_GUIDE.md)** - Summit demonstration guide
- **[docs/operations/](docs/operations/)** - Operations documentation

### Setup & Configuration
- **[docs/operations/OPENSTACK_COMPLETE_GUIDE.md](docs/operations/OPENSTACK_COMPLETE_GUIDE.md)** - OpenStack configuration
- **[docs/](docs/)** - Additional documentation

## Quick Start

### Prerequisites
- Access to VMs (VM-1, VM-2, VM-4)
- OpenStack credentials for Security Group configuration
- Git and Docker installed

### Verify Connectivity
```bash
# Test all connections
./scripts/setup/test-connectivity.sh

# Check GitOps service
docker ps | grep gitea
```

### Key Services
| Service | Port | URL |
|---------|------|-----|
| Gitea | 8888 | http://172.16.0.78:8888 |
| K8s API | 6443 | https://<edge-ip>:6443 |
| SLO Service | 30090 | http://<edge-ip>:30090 |
| O2IMS API | 31280 | http://<edge-ip>:31280 |

## Pipeline Flow
```
Natural Language → Intent (JSON) → KRM → GitOps → Edge Deployment → SLO Validation
```

## Multi-Site Support
- **Edge1**: Full functionality (100%)
- **Edge2**: Core services operational (95%)

## Version
- **Current**: v1.1.1 - Production Ready
- **Released**: 2025-09-14
- See [CHANGELOG.md](CHANGELOG.md) for version history

## Contributing
Please refer to contribution guidelines in docs/

## License
[License information]

---
*Last Updated: 2025-09-17*