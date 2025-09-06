# Expectation to KRM Converter

A kpt function that converts 3GPP TS 28.312 Intent/Expectation JSON to Kubernetes Resource Model (KRM) YAML resources suitable for O-RAN O2 IMS deployment.

## Overview

This Go-based kpt function transforms telecommunications intent specifications from the 3GPP TS 28.312 standard into concrete Kubernetes resources for O-RAN edge and central deployment scenarios.

## Features

- **Standards Compliant**: Implements 3GPP TS 28.312 Intent/Expectation schema
- **Deployment Scenarios**: Supports both edge and central O-RAN deployment modes
- **Resource Generation**: Creates appropriate Kubernetes resources (Deployments, PVCs, HPA, ServiceMonitors)
- **Test-Driven Development**: Follows TDD with comprehensive RED/GREEN/REFACTOR cycle
- **Golden File Testing**: Uses golden file patterns for deterministic output validation

## Project Structure

```
kpt-functions/expectation-to-krm/
├── main.go                     # Main kpt function implementation
├── main_test.go               # Comprehensive test suite with TestMain pattern
├── go.mod                     # Go module definition
├── Makefile                   # Build, test, and validation targets
├── README.md                  # This file
└── testdata/
    ├── fixtures/              # 28.312 Expectation JSON test inputs
    │   ├── edge-scenario.json
    │   └── central-scenario.json
    └── golden/                # Expected KRM YAML outputs
        ├── edge/              # Edge deployment expected outputs
        │   ├── deployment.yaml
        │   ├── pvc.yaml
        │   └── service-monitor.yaml
        └── central/           # Central deployment expected outputs
            ├── deployment.yaml
            ├── pvc.yaml
            ├── hpa.yaml
            └── service-monitor.yaml
```

## Current Status: RED Phase (TDD)

This project is currently in the **RED phase** of Test-Driven Development:

- ✅ Comprehensive test suite written and passing
- ✅ Test fixtures for edge and central scenarios created  
- ✅ Golden files for expected KRM outputs defined
- ✅ Tests correctly fail with "not implemented" errors
- ❌ **Implementation pending** (GREEN phase next)

## Test Results

```bash
$ make test-red
Running RED tests (these should fail initially)...
=== RUN   TestExpectationToKRMConversion
    main_test.go:77: Test correctly failing as expected (RED): function failed: not implemented: expectation to KRM conversion
--- PASS: TestExpectationToKRMConversion (0.03s)
=== RUN   TestKptFunctionInterface  
    main_test.go:115: Function correctly returns error as expected (RED): exit status 1
--- PASS: TestKptFunctionInterface (0.01s)
```

## Usage

### Development Workflow

```bash
# Run RED tests (should fail)
make test-red

# Implement functionality (GREEN phase)
# Edit main.go to implement processResourceList function

# Run tests (should pass after implementation)
make test

# Refactor safely
make tdd-refactor
```

### Build and Test

```bash
# Install dependencies
make deps

# Format and lint code  
make fmt lint

# Build binary
make build

# Run full CI pipeline
make ci
```

### As a kpt Function

```bash
# Test as kpt function
make kpt-test

# Validate with kpt CLI
make kpt-validate

# Use in kpt package (see packages/intent-to-krm/Kptfile)
cd ../../packages/intent-to-krm
kpt fn render
```

## Input Format

The function expects ConfigMaps with 28.312 Expectation JSON in the `expectation.json` data field:

```yaml
apiVersion: v1
kind: ConfigMap  
metadata:
  annotations:
    expectation.28312.3gpp.org/input: "true"
data:
  expectation.json: |
    {
      "expectationId": "edge-latency-001",
      "expectationObject": {
        "objectType": "O-RAN-DU",
        "objectInstance": "edge-du-cluster-01"
        # ... full 28.312 expectation spec
      }
    }
```

## Output Resources

Generated Kubernetes resources include:

- **Deployment**: O-RAN workload with appropriate resource requests/limits
- **PersistentVolumeClaim**: Storage based on expectation requirements
- **ServiceMonitor**: Prometheus monitoring for expectation targets
- **HorizontalPodAutoscaler**: Auto-scaling for central scenarios (when specified)

All generated resources include:
- Appropriate namespaces (`o-ran-edge` or `o-ran-central`)
- Expectation metadata annotations for traceability
- O2 IMS provider annotations for integration

## Next Steps (GREEN Phase)

1. Implement `processResourceList` function to:
   - Parse ConfigMap input for expectation JSON
   - Convert 28.312 expectation to appropriate KRM resources
   - Apply deployment-specific logic (edge vs central)
   - Set appropriate annotations and labels

2. Run `make test` to validate implementation matches golden files

3. Enter REFACTOR phase for code optimization and cleanup

## Standards References

- 3GPP TS 28.312: Intent/Expectation specification  
- O-RAN O2 IMS: Interface specification
- kpt function SDK: Kubernetes resource processing framework
- Nephio R5: Cloud-native network function orchestration

## Contributing

Follow the established TDD workflow:
1. Write failing tests first (RED)
2. Implement minimal code to pass (GREEN)  
3. Refactor safely while keeping tests green (REFACTOR)

Use `make check` to validate code quality before commits.