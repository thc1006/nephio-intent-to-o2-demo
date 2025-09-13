# KRM Rendering Pipeline - TDD Implementation

## Overview
Comprehensive Test-Driven Development (TDD) implementation for the KRM rendering pipeline with multi-site GitOps support, idempotency, and deterministic operation.

## Implementation Summary

### 1. Enhanced KRM Rendering Pipeline (`scripts/render_krm.sh`)
- **Idempotent Operation**: Cleans previous renders before creating new ones
- **Deterministic File Ordering**: Resources always created in same order
- **Multi-Site Support**: Routes to edge1-config/, edge2-config/, or both
- **Service Type Support**: eMBB, URLLC, mMTC with appropriate resource profiles
- **Intent Override**: Respects targetSite field in intent JSON
- **Error Handling**: Validates output directories were created successfully
- **Dry-Run Mode**: Preview changes without creating files

### 2. Comprehensive Test Suite (`tests/test_krm_rendering.sh`)
15 test cases covering all aspects of the rendering pipeline:

#### Routing Tests
- **Edge1 routing**: Verifies edge1-only deployment
- **Edge2 routing**: Verifies edge2-only deployment
- **Both sites routing**: Verifies simultaneous deployment to both sites
- **No cross-contamination**: Ensures no edge1 references in edge2 configs and vice versa

#### Quality Tests
- **Idempotency**: Running twice produces identical results
- **Deterministic ordering**: Files always created in same order
- **YAML validation**: All generated files are valid YAML
- **Kustomization validity**: kustomization.yaml references all resources correctly

#### Service Type Tests
- **eMBB rendering**: Enhanced Mobile Broadband service configuration
- **URLLC rendering**: Ultra-Reliable Low-Latency Communication with higher resources
- **mMTC rendering**: Massive Machine-Type Communication with lower resources

#### Feature Tests
- **Intent targetSite override**: Intent file overrides command-line target
- **Resource profiles**: High-performance profile increases replicas
- **Dry-run mode**: No files created in dry-run

#### Error Handling Tests
- **Invalid intent file**: Graceful failure with non-existent files
- **Invalid target site**: Rejects invalid target specifications

### 3. Makefile Integration
New targets for easy testing:
- `make test-golden`: Run full KRM rendering test suite
- `make test-krm`: Alias for test-golden
- `make test-krm-quick`: Quick smoke tests for CI/CD

### 4. Golden Test Files
6 golden test files covering different scenarios:
- `intent_edge1.json`: Edge1-specific deployment
- `intent_edge2.json`: Edge2-specific deployment
- `intent_both.json`: Multi-site deployment
- `intent_edge1_embb.json`: eMBB service type
- `intent_edge2_urllc.json`: URLLC service type
- `intent_both_mmtc.json`: mMTC service type

## Test Results
```
=====================================
Test Summary
=====================================
Tests run:    15
Tests passed: 15
Tests failed: 0
=====================================
✅ All tests passed!
```

## Usage Examples

### Basic Rendering
```bash
# Render to edge1
./scripts/render_krm.sh intent.json --target edge1

# Render to both sites
./scripts/render_krm.sh intent.json --target both

# Dry-run mode
./scripts/render_krm.sh intent.json --target edge2 --dry-run
```

### Running Tests
```bash
# Full test suite
make test-golden

# Quick tests for CI
make test-krm-quick

# Individual test script
./tests/test_krm_rendering.sh
```

### Environment Variables
```bash
# Custom output directory
OUTPUT_BASE=/tmp/custom ./scripts/render_krm.sh intent.json

# Verbose output
VERBOSE=true ./scripts/render_krm.sh intent.json

# Dry-run mode
DRY_RUN=true ./scripts/render_krm.sh intent.json
```

## Key Features

### Idempotency
The pipeline ensures identical results regardless of how many times it's run:
- Previous renders are cleaned before new ones
- Files are created with consistent permissions (644)
- Resource ordering is deterministic

### Determinism
All operations produce predictable, repeatable results:
- Resources listed in sorted order in kustomization.yaml
- Sites always rendered in same order (edge1, then edge2)
- Consistent file permissions and structure

### Multi-Site Routing
Intelligent routing based on intent and command-line options:
- Intent targetSite field takes precedence
- Support for edge1, edge2, or both sites
- Clean separation between site configurations

### Service Type Awareness
Different service types get appropriate resource allocations:
- **eMBB**: 2-3 replicas, 512Mi memory limit
- **URLLC**: 2 replicas, 1Gi memory limit (low latency needs)
- **mMTC**: 1 replica, 256Mi memory limit (IoT efficiency)

## Production Readiness

✅ **Comprehensive Testing**: 15 test cases covering all scenarios
✅ **Idempotent Operations**: Safe to run multiple times
✅ **Deterministic Behavior**: Predictable, repeatable results
✅ **Error Handling**: Graceful failures with clear error messages
✅ **YAML Validation**: All generated files are valid Kubernetes manifests
✅ **Kustomize Compatible**: Works with standard Kubernetes tooling
✅ **CI/CD Ready**: Quick tests for pipeline integration

## Next Steps

1. **Integration with GitOps**: Push rendered configs to Git repositories
2. **Policy Validation**: Add OPA/Kyverno policy checks
3. **Metrics Collection**: Track rendering performance and success rates
4. **Advanced Profiles**: Add more resource profiles (cost-optimized, latency-optimized)
5. **Template Customization**: Allow custom templates per site/service

## Compliance with CLAUDE.md Requirements

This implementation fulfills the Phase 12 requirements from CLAUDE.md:
- ✅ Multi-site GitOps paths (gitops/edge1-config/, gitops/edge2-config/)
- ✅ Target site routing (--target=edge1|edge2|both)
- ✅ Intent targetSite field support
- ✅ Comprehensive TDD with golden tests
- ✅ Idempotent and deterministic operation
- ✅ Production-ready with proper error handling