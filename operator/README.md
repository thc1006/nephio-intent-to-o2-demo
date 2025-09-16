# Nephio Intent Operator

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Version](https://img.shields.io/badge/version-v0.1.0--alpha-orange)](https://github.com/thc1006/nephio-intent-operator/releases)

A Kubernetes operator for managing intent-based network configurations in Nephio environments.

## 📍 Repository Structure

This operator can be used in two modes:

### 1. **Standalone Mode** (Independent Repository)
- Repository: https://github.com/thc1006/nephio-intent-operator
- Clone and build independently
- Self-contained with all dependencies

### 2. **Embedded Mode** (Git Subtree)
- Embedded in: https://github.com/thc1006/nephio-intent-to-o2-demo
- Path: `/operator` directory
- Synchronized via git subtree

## 🚀 Quick Start

### Standalone Development
```bash
git clone https://github.com/thc1006/nephio-intent-operator.git
cd nephio-intent-operator
make build
```

### Embedded Development
```bash
cd nephio-intent-to-o2-demo/operator
# Work normally, commits go to main repo
# Sync changes using SYNC.md instructions
```

## 📦 Features

- **Intent Translation**: Converts high-level intents to Kubernetes resources
- **Network Slice Management**: Manages network slices for edge deployments
- **SLA Enforcement**: Monitors and enforces Service Level Agreements
- **GitOps Integration**: Native integration with Config Sync and Flux

## 🏗️ Architecture

The operator follows the standard Kubebuilder layout:

```
operator/
├── api/              # API definitions
│   └── v1alpha1/     # IntentConfig CRD
├── controllers/      # Reconciliation logic
├── config/          # Kustomize manifests
├── docs/            # Documentation
│   └── design/      # Design documents
├── hack/            # Build and deploy scripts
└── test/            # Test suites
```

## 🔧 Development

### Prerequisites
- Go 1.22+
- Kubebuilder v4.8+
- Kubernetes 1.28+
- Kustomize v5.0+

### Building
```bash
make build
```

### Testing
```bash
make test
make test-integration
```

### Deployment
```bash
make deploy IMG=nephio-intent-operator:v0.1.0-alpha
```

## 📋 Versioning

- **Operator Version**: `v0.1.0-alpha` (follows semver)
- **API Version**: `intent.nephio.io/v1alpha1`
- **Shell Pipeline**: Remains at `v1.1.x` (independent versioning)

## 🔄 Synchronization

This repository is maintained as a git subtree in the main demo repository.
For synchronization instructions, see [SYNC.md](./SYNC.md).

## 📝 Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for details on:
- Code of conduct
- Development process
- Submitting pull requests

## 👥 Maintainers

See [CODEOWNERS](./CODEOWNERS) for the list of maintainers.

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

## 🔗 Related Projects

- [Nephio](https://nephio.org/) - Cloud-native automation for telco workloads
- [nephio-intent-to-o2-demo](https://github.com/thc1006/nephio-intent-to-o2-demo) - Main demo repository

## 📊 Status

**Alpha Release** - Not recommended for production use

Current focus:
- [ ] Basic intent reconciliation
- [ ] Network slice lifecycle management
- [ ] SLA monitoring integration
- [ ] Multi-cluster support

---

*This operator is part of the Nephio Intent-to-O2 demonstration project.*