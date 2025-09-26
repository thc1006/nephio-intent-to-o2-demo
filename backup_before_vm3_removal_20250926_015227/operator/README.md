# Nephio Intent Operator

**Version: v0.1.1-alpha**

A Kubernetes operator for managing intent-based deployments in the Nephio ecosystem.

## Description

The Nephio Intent Operator orchestrates the complete lifecycle of intent-based deployments, from natural language or JSON intents to deployed Kubernetes resources with SLO validation and automatic rollback capabilities.

## Features

- **Intent Compilation**: Convert natural language or JSON intents to Kubernetes manifests
- **Multi-Engine Support**: kpt, kustomize, and Helm rendering engines
- **GitOps Integration**: Automatic synchronization with GitOps repositories
- **SLO Validation**: Built-in gates for service level objectives
- **Automatic Rollback**: Smart rollback on validation failures
- **Multi-Site Delivery**: Deploy to edge1, edge2, or both sites

## Getting Started

### Prerequisites

- Go 1.22+ (tests run with 1.24+)
- Docker
- kubectl
- Access to a Kubernetes cluster

### Installation

1. Install the CRDs:
```bash
make install
```

2. Deploy the controller:
```bash
make deploy
```

### Running Tests

Run unit tests with envtest:
```bash
make test
```

Run end-to-end tests:
```bash
make test-e2e
```

### Development

1. Install dependencies:
```bash
make generate
make manifests
```

2. Run locally against your cluster:
```bash
make run
```

3. Build the operator image:
```bash
make docker-build docker-push IMG=<your-registry>/nephio-intent-operator:tag
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GITOPS_REPO_URL` | - | Default GitOps repository URL |
| `RENDER_TIMEOUT` | `5m` | Default timeout for rendering operations |
| `SYNC_WAIT_TIMEOUT` | `10m` | Default timeout for GitOps sync |
| `SLO_CHECK_INTERVAL` | `30s` | Frequency of SLO validation checks |
| `ROLLBACK_ENABLED` | `true` | Global toggle for automatic rollback |

### Example IntentDeployment

```yaml
apiVersion: tna.tna.ai/v1alpha1
kind: IntentDeployment
metadata:
  name: example-deployment
  namespace: default
spec:
  intent: |
    {
      "service": "edge-app",
      "replicas": 3,
      "resources": {
        "cpu": "100m",
        "memory": "128Mi"
      }
    }

  compileConfig:
    engine: kpt
    renderTimeout: 5m

  deliveryConfig:
    targetSite: both
    gitOpsRepo: https://github.com/your-org/gitops
    syncWaitTimeout: 10m

  gatesConfig:
    enabled: true
    sloThresholds:
      error_rate: "0.01"
      latency_p99: "200ms"

  rollbackConfig:
    autoRollback: true
    maxRetries: 3
```

## API Documentation

See [docs/design/crd.md](docs/design/crd.md) for detailed CRD specifications.

## Architecture

See [docs/design/phase-machine.md](docs/design/phase-machine.md) for the phase state machine design.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.