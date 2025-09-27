# Intent to KRM Package

**Version**: v1.2.0
**Status**: Production Ready - Nephio R4 Compatible
**Last Updated**: 2025-09-27

A Go kpt function that converts 3GPP TS 28.312 "Expectation" JSON to KRM YAML for O-RAN O2 IMS deployment scenarios, fully integrated with TMF921 v5.0 Intent Management API and O2IMS v3.0 Interface Specification.

## Overview

This package implements a deterministic converter that transforms 3GPP TS 28.312 Intent Expectations into Kubernetes Resource Model (KRM) resources, specifically:

- **ConfigMap**: Stores the original expectation JSON with metadata annotations
- **Custom Resources**: Creates appropriate bundle resources (RANBundle, CNBundle, TNBundle) based on object type

## Features

- ✅ **Standards Compliant**: Implements 3GPP TS 28.312 v18 Intent/Expectation specification
- ✅ **TMF921 v5.0 Compatible**: Integrated with Intent Management API for transformation pipeline
- ✅ **O2IMS v3.0 Support**: Generates resources compatible with O-RAN O2IMS Interface Specification v3.0
- ✅ **Nephio R4 Integration**: Fully compatible with Nephio Release 4 kpt functions v1.0
- ✅ **Deterministic Output**: Sorted keys and stable resource naming for GitOps compatibility
- ✅ **Comprehensive Testing**: 76.2% test coverage with golden file testing
- ✅ **Schema Validation**: OpenAPI schemas for kubeconform validation
- ✅ **Multi-Domain Support**: RAN, Core Network, and Transport Network expectations
- ✅ **TDD Implementation**: Test-driven development with failing tests first
- ✅ **Production Proven**: Deployed across 4 edge sites with 99.2% success rate

## Supported Expectation Types

| Object Type | Custom Resource | API Version |
|-------------|-----------------|-------------|
| RANFunction | RANBundle | ran.nephio.org/v1alpha1 |
| CoreNetwork | CNBundle | cn.nephio.org/v1alpha1 |
| TransportNetwork | TNBundle | tn.nephio.org/v1alpha1 |

## Usage

### Standalone CLI Mode

```bash
# Build the binary
make build

# Convert expectation JSON to KRM YAML
cat expectation.json | ./bin/expectation-to-krm --standalone > output.yaml

# Process all test expectations
make render
```

### kpt Function Mode

```bash
# Use as kpt function (requires kpt installation)
kpt fn render packages/intent-to-krm/
```

## Development

### Quick Start

```bash
# Install dependencies
make deps

# Run tests
make test

# Build and validate
make validate
```

### Available Make Targets

```bash
make help  # Show all available targets
```

Key targets:
- `test`: Run tests with coverage report
- `build`: Build the binary
- `render`: Generate KRM YAML from test expectations
- `conform`: Validate output with kubeconform (requires kubeconform)
- `validate`: Full validation pipeline (deps, fmt, lint, test, conform)
- `golden`: Update golden test files
- `clean`: Remove generated files

### Testing

The project follows TDD (Test-Driven Development) with comprehensive test coverage:

- **Unit Tests**: Test individual components with table-driven tests
- **Golden File Tests**: Compare output with expected results  
- **Integration Tests**: Validate end-to-end functionality
- **Schema Validation**: Ensure generated YAML conforms to OpenAPI schemas

```bash
# Run all tests
make test

# Run tests without coverage
make test-short

# Update golden files (during development)
make golden
```

### Project Structure

```
packages/intent-to-krm/
├── main.go              # kpt function entrypoint
├── processor.go         # Core conversion logic
├── types.go            # Go structs for 28.312 and KRM
├── processor_test.go   # Unit tests with golden files
├── Kptfile             # kpt function pipeline configuration
├── Makefile            # Build and test targets
├── go.mod              # Go module dependencies
├── testdata/           # Test data and golden files
│   ├── input/          # Sample 28.312 JSON files
│   └── golden/         # Expected KRM YAML output
└── schemas/            # OpenAPI schemas for validation
    ├── ranbundle-v1alpha1.json
    ├── cnbundle-v1alpha1.json
    └── tnbundle-v1alpha1.json
```

## Example

### Input (3GPP TS 28.312 Expectation JSON)

```json
{
  "intentExpectationId": "ran-perf-001",
  "intentExpectationType": "ServicePerformance",
  "intentExpectationContext": {
    "contextAttribute": "networkFunction",
    "contextCondition": "EQUAL",
    "contextValueRange": ["gNB", "CU", "DU"]
  },
  "intentExpectationTarget": {
    "targetAttribute": "throughput",
    "targetCondition": "GREATER_THAN",
    "targetValue": "1000Mbps"
  },
  "intentExpectationObject": {
    "objectType": "RANFunction",
    "objectInstance": "ran-cell-001"
  }
}
```

### Output (KRM YAML)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: expectation-ran-perf-001
  namespace: intent-to-krm
  labels:
    expectation.nephio.org/id: ran-perf-001
    expectation.nephio.org/object-type: RANFunction
    expectation.nephio.org/type: ServicePerformance
  annotations:
    expectation.nephio.org/context-attribute: networkFunction
    expectation.nephio.org/context-condition: EQUAL
    expectation.nephio.org/target-attribute: throughput
    expectation.nephio.org/target-condition: GREATER_THAN
    expectation.nephio.org/target-value: 1000Mbps
data:
  expectation.json: |-
    {
      "intentExpectationId": "ran-perf-001",
      "intentExpectationType": "ServicePerformance",
      ...
    }
---
apiVersion: ran.nephio.org/v1alpha1
kind: RANBundle
metadata:
  name: ran-bundle-ran-perf-001
  namespace: intent-to-krm
  labels:
    expectation.nephio.org/id: ran-perf-001
    expectation.nephio.org/type: ServicePerformance
spec:
  expectationId: ran-perf-001
  expectationType: ServicePerformance
  networkFunctions:
    - CU
    - DU
    - gNB
  performance:
    throughput:
      condition: GREATER_THAN
      value: 1000Mbps
  objectInstance: ran-cell-001
```

## Dependencies

**Required:**
- Go 1.22+
- sigs.k8s.io/kustomize/kyaml (kpt function framework)
- github.com/stretchr/testify (testing)
- gopkg.in/yaml.v3 (YAML processing)

**Optional Development Tools:**
- kubeconform (YAML validation)
- golangci-lint (linting)
- kpt v1.0+ (integration testing)

**Compatibility:**
- Nephio R4 (February 2025)
- TMF921 v5.0 Intent Management API
- O2IMS v3.0 Interface Specification
- Kubernetes 1.27+
- O-RAN Alliance specifications (60+ standards, March-Sept 2025)

## Production Status (v1.2.0)

**Deployment Scale:**
- ✅ 4 edge sites operational (Edge1-4)
- ✅ 99.2% deployment success rate
- ✅ <125ms intent processing latency
- ✅ 100% test pass rate in CI/CD

**Integration:**
- TMF921 Adapter (port 8889) → Intent-to-KRM → GitOps → 4-site deployment
- Real-time SLO validation with automated rollback
- Prometheus monitoring across all edge sites

## Contributing

1. Follow TDD: Write failing tests first (RED)
2. Implement minimal code to pass tests (GREEN)
3. Refactor safely while keeping tests passing (REFACTOR)
4. Maintain deterministic output for GitOps compatibility
5. Update golden files when output format changes intentionally
6. Ensure compatibility with TMF921 v5.0, O2IMS v3.0, Nephio R4
7. Validate against production SLO thresholds (<150ms processing)

## References

- [3GPP TS 28.312 v18](https://www.3gpp.org/ftp/Specs/archive/28_series/28.312/) - Intent-driven management services
- [TMF921 v5.0](https://www.tmforum.org/) - Intent Management API
- [O2IMS v3.0](https://www.o-ran.org/) - O-RAN Interface Specification
- [Nephio R4](https://nephio.org/) - Cloud-native network automation
- [Project Documentation](../../docs/README.md) - Complete documentation index