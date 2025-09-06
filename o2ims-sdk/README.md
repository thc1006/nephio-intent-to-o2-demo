# O2 IMS SDK for Kubernetes

A type-safe Go SDK for managing O2 IMS ProvisioningRequest resources in Kubernetes clusters, following O-RAN specifications.

## Project Status: RED Phase (TDD)

⚠️ **This SDK is currently in the RED phase of Test-Driven Development** ⚠️

All tests are designed to **FAIL** at this stage. This is expected and indicates we're following proper TDD methodology:

1. **RED**: Write failing tests (current phase)
2. **GREEN**: Implement minimal code to make tests pass (next phase) 
3. **REFACTOR**: Clean up and optimize code (final phase)

## Quick Start

### Prerequisites

- Go 1.22+
- Kubernetes cluster (for real usage)
- Make

### Build and Test

```bash
# Install dependencies
make deps

# Run tests (will FAIL - this is expected in RED phase)
make test

# Build CLI
make build

# Try the CLI in fake mode (works for demo)
make demo-fake
```

### CLI Usage (Fake Mode)

The CLI works in fake mode for demonstration and testing:

```bash
# Build the CLI
make build

# Create a ProvisioningRequest (fake mode)
./bin/o2imsctl pr create --from examples/pr.yaml --fake

# Wait for it to become Ready (fake mode)
./bin/o2imsctl pr wait example-pr --timeout 10m --fake

# Get the ProvisioningRequest (fake mode)
./bin/o2imsctl pr get example-pr --fake

# List all ProvisioningRequests (fake mode)
./bin/o2imsctl pr list --fake

# Delete the ProvisioningRequest (fake mode)
./bin/o2imsctl pr delete example-pr --fake
```

## Project Structure

```
o2ims-sdk/
├── api/v1alpha1/                   # CRD types and OpenAPI schema
│   ├── doc.go
│   ├── groupversion_info.go
│   └── provisioningrequest_types.go
├── client/                         # Type-safe client interfaces
│   ├── interface.go
│   └── client.go
├── cmd/o2imsctl/                   # CLI implementation
│   ├── main.go
│   └── commands/
│       ├── root.go
│       ├── pr.go
│       └── version.go
├── tests/                          # envtest-based integration tests
│   ├── envtest_suite_test.go
│   ├── provisioningrequest_test.go
│   ├── client_test.go
│   └── cli_test.go
├── examples/                       # Example YAML files
│   ├── pr.yaml
│   ├── pr-minimal.yaml
│   └── pr-high-performance.yaml
├── go.mod
├── Makefile
└── README.md
```

## API Reference

### ProvisioningRequest CRD

The SDK manages `ProvisioningRequest` resources in the `o2ims.provisioning.oran.org/v1alpha1` API group.

#### Spec Fields

- `targetCluster` (required): Target cluster for provisioning
- `resourceRequirements` (required): CPU, memory, and storage requirements
- `networkConfig` (optional): Network configuration including VLAN, subnet, gateway
- `description` (optional): Human-readable description

#### Status Fields

- `phase`: Current phase (Pending, Processing, Ready, Failed)
- `conditions`: Detailed condition information
- `observedGeneration`: Last observed spec generation
- `provisionedResources`: Map of provisioned resource information

#### Example

```yaml
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: example-pr
  namespace: default
spec:
  targetCluster: production-cluster
  description: "5G RAN workload provisioning"
  resourceRequirements:
    cpu: "4000m"
    memory: "8Gi"
    storage: "20Gi"
  networkConfig:
    vlan: 100
    subnet: "192.168.100.0/24"
    gateway: "192.168.100.1"
```

## Client Usage

```go
import (
    "context"
    "github.com/nephio-intent-to-o2-demo/o2ims-sdk/client"
    o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
)

// This will fail in RED phase - not implemented yet
config := client.ClientConfig{
    RestConfig: kubeConfig,
    Namespace:  "default",
}

o2imsClient, err := client.NewO2IMSClient(config)
if err != nil {
    // Will fail with "not implemented" error
    log.Fatal(err)
}

// All operations will fail with "not implemented" in RED phase
prInterface := o2imsClient.ProvisioningRequests("default")
```

## Testing Strategy

### Test Categories

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Use envtest to test against real Kubernetes API
3. **CLI Tests**: Test CLI commands and argument validation
4. **End-to-End Tests**: Full workflow testing (planned for GREEN phase)

### Running Tests

```bash
# Run all tests (will fail in RED phase)
make test

# Run tests with verbose output
make test-verbose

# Run tests with coverage (when implemented)
make test-coverage

# Verify we're in RED phase (tests should fail)
make verify-red-phase
```

## Development Workflow

### TDD Phases

1. **RED Phase** (Current): All tests fail, structure exists
   - ✅ CRD types defined
   - ✅ Client interfaces defined
   - ✅ CLI structure created
   - ✅ Tests written but failing
   - ✅ Example files created

2. **GREEN Phase** (Next): Implement minimal functionality
   - [ ] Implement client methods
   - [ ] Add controller logic
   - [ ] Wire up CLI commands
   - [ ] Make all tests pass

3. **REFACTOR Phase** (Final): Optimize and clean up
   - [ ] Performance improvements  
   - [ ] Code organization
   - [ ] Documentation
   - [ ] Additional features

### Commands

```bash
# Development
make deps           # Install dependencies
make fmt            # Format code
make vet            # Run go vet
make lint           # Run golangci-lint (requires tools)

# Testing
make test           # Run tests with envtest
make demo-fake      # Try CLI in fake mode

# Building
make build          # Build CLI binary
make build-linux    # Build for Linux

# Tools
make install-tools  # Install development tools

# Info
make info           # Show project information
make help           # Show all available commands
```

## Integration with Nephio

This SDK is designed to integrate with:

- **Nephio R5**: For cloud-native network function management
- **O-RAN O2 IMS**: For infrastructure management service
- **kpt Functions**: For GitOps workflow integration
- **Kubernetes Controllers**: For resource lifecycle management

## Contributing

1. Ensure tests fail appropriately in RED phase
2. Follow Go 1.22 best practices
3. Use structured logging (JSON format)
4. Implement proper error handling
5. Add comprehensive tests before implementation

## Security

- All external inputs validated against JSON schemas
- No plaintext secrets in code
- Image signature verification in production
- Rate limiting on API endpoints
- RBAC properly configured

## License

See LICENSE file for details.

---

**Note**: This is a RED phase TDD project. Tests are expected to fail until the GREEN phase implementation is complete.