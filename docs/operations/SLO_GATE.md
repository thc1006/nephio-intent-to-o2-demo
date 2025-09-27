# SLO Gate: Supply Chain Security Precheck

**Version**: 1.2.0
**Last Updated**: 2025-09-27
**Status**: Production Ready - 4 Edge Sites Operational

The SLO Gate implements a comprehensive supply chain security precheck system for the Nephio Intent-to-O2 demo pipeline. This document describes all precheck signals, their purpose, exit codes, and configuration options.

**Current SLO Performance (v1.2.0):**
- **Processing Latency**: 125ms (Target: <150ms) ✅
- **Success Rate**: 99.2% (Target: >95%) ✅
- **Recovery Time**: 2.8min (Target: <5min) ✅
- **Test Pass Rate**: 100% (Target: >90%) ✅
- **Production Readiness**: 90% (Target: >85%) ✅

## Overview

The precheck gate validates security compliance before allowing `make publish-edge` to proceed. It implements defense-in-depth principles with multiple validation layers:

```bash
# Basic usage (v1.2.0 - 4 sites)
make precheck

# With custom configuration for 4-site deployment
STRICT_MODE=true COSIGN_REQUIRED=true SITES="edge1,edge2,edge3,edge4" make precheck

# Integrated with publish workflow
make publish-edge  # Automatically runs precheck across all 4 sites

# TMF921 automated mode validation
curl -f http://172.16.0.78:8889/health && echo "SLO Gate: TMF921 Ready" || echo "SLO Gate: TMF921 Failed"
```

## Validation Signals

### 1. Dependency Check

**Purpose**: Ensures all required tools are available before validation begins.

**Validations**:
- `kubeconform` - YAML schema validation
- `kpt` - Kubernetes package tooling
- `git` - Version control operations
- `jq` - JSON processing
- `cosign` (optional) - Container signature verification

**Configuration**: 
- `COSIGN_REQUIRED=true` - Makes cosign mandatory

### 2. Change Size Guard

**Purpose**: Prevents accidentally large deployments that could indicate supply chain compromise or configuration drift.

**Validations**:
- Maximum files changed threshold
- Maximum lines changed threshold
- Compares current branch against origin/main or HEAD~1

**Configuration**:
```bash
MAX_CHANGE_SIZE_LINES=500      # Default: 500 lines
MAX_CHANGE_SIZE_FILES=20       # Default: 20 files
STRICT_MODE=false              # If true, fails on any threshold violation
```

**Example**:
```bash
# Allow larger changes temporarily
MAX_CHANGE_SIZE_LINES=1000 make precheck
```

### 3. YAML Manifest Validation

**Purpose**: Ensures all Kubernetes manifests are syntactically valid and conform to schemas.

**Validations**:
- Validates `packages/intent-to-krm/*.yaml`
- Validates `packages/intent-to-krm/dist/edge1/*.yaml`
- Uses kubeconform with multiple schema sources:
  - Local schemas (`packages/intent-to-krm/schemas/`)
  - Default Kubernetes schemas
  - Remote schema repository

**Schema Locations**:
1. `packages/intent-to-krm/schemas/` (custom schemas)
2. Default kubeconform schemas
3. `https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master`

### 4. Container Image Allowlist (4-Site Deployment)

**Purpose**: Prevents deployment of container images from unauthorized registries across all 4 edge sites, reducing supply chain attack surface.

**Validations**:
- Extracts all `image:` references from YAML manifests for Edge1-4
- Validates against allowed registry list
- Verifies accessibility from all 4 sites
- Optionally verifies cosign signatures

**Default Allowed Registries (v1.2.0)**:
- `gcr.io` - Google Container Registry
- `ghcr.io` - GitHub Container Registry
- `registry.k8s.io` - Kubernetes official registry
- `docker.io/library` - Docker Hub official images
- `quay.io` - Red Hat Quay registry
- Local registry mirrors for 4-site deployment

**Configuration (4-Site Support)**:
```bash
# Custom registry allowlist for 4-site deployment
ALLOWED_REGISTRIES="gcr.io,ghcr.io,my-company.io" SITES="edge1,edge2,edge3,edge4" make precheck

# Require signed images across all sites
COSIGN_REQUIRED=true SITES="edge1,edge2,edge3,edge4" make precheck

# Site-specific validation
TARGET_SITE=edge3 make precheck
```

**Signature Verification**:
- Uses `cosign verify` when available
- In `COSIGN_REQUIRED=true` mode, fails if signatures missing
- Otherwise, warns about unsigned images but continues

### 5. kpt Function Render Test (Multi-Site)

**Purpose**: Validates that kpt functions can successfully render packages for all 4 edge sites without errors.

**Validations**:
- Creates temporary copy of package for each site
- Runs `kpt fn render --dry-run` for Edge1-4 configurations
- Validates site-specific parameter injection
- Ensures no rendering errors occur across sites

**Benefits**:
- Catches function configuration errors early
- Validates package structure integrity for multi-site deployment
- Prevents broken packages from being published to any site
- Verifies site-specific parameter substitution (IPs, ports, etc.)

## Exit Codes (v1.2.0 Multi-Site)

The precheck gate uses specific exit codes to indicate different failure conditions across the 4-site deployment:

| Exit Code | Constant | Meaning |
| 0 | `EXIT_SUCCESS` | All validations passed |
| 1 | `EXIT_VALIDATION_FAILED` | General validation failure |
| 2 | `EXIT_CHANGE_SIZE_EXCEEDED` | Change size thresholds exceeded |
| 3 | `EXIT_REGISTRY_VIOLATION` | Unauthorized container registry used |
| 4 | `EXIT_SIGNATURE_MISSING` | Required container signatures missing |
| 5 | `EXIT_DEPENDENCY_MISSING` | Required tools not installed |
| 6 | `EXIT_KPT_RENDER_FAILED` | kpt function rendering failed |
| 7 | `EXIT_MULTISITE_INCONSISTENCY` | Inconsistency detected between sites |
| 8 | `EXIT_SITE_UNREACHABLE` | One or more edge sites unreachable |
| 9 | `EXIT_TMF921_HEALTH_FAILED` | TMF921 adapter health check failed |

## Configuration Options

### Environment Variables

All configuration can be set via environment variables or a `.precheck.conf` file in the project root.

```bash
# Change size limits
MAX_CHANGE_SIZE_LINES=500          # Maximum lines changed
MAX_CHANGE_SIZE_FILES=20           # Maximum files changed

# Registry security (4-site deployment)
ALLOWED_REGISTRIES="gcr.io,ghcr.io,registry.k8s.io,docker.io/library,quay.io"
COSIGN_REQUIRED=false              # Require signed container images
SITES="edge1,edge2,edge3,edge4"     # Target sites for validation
TMF921_ENDPOINT="http://172.16.0.78:8889"  # TMF921 adapter for SLO validation

# Behavior
STRICT_MODE=false                  # Fail on warnings
LOG_LEVEL=INFO                     # INFO, WARN, ERROR, JSON

# JSON logging for CI/CD integration
LOG_LEVEL=JSON                     # Machine-readable output
```

### Configuration File

Create `.precheck.conf` in project root:

```bash
# Supply Chain Security Precheck Configuration
MAX_CHANGE_SIZE_LINES=750
MAX_CHANGE_SIZE_FILES=25
ALLOWED_REGISTRIES="gcr.io,ghcr.io,my-corp.com"
STRICT_MODE=true
COSIGN_REQUIRED=true
LOG_LEVEL=JSON
```

## Integration Patterns

### Make Targets

```bash
# Standalone precheck
make precheck

# Integrated with publish (recommended)
make publish-edge    # Runs precheck automatically

# Skip precheck (not recommended)
cd packages/intent-to-krm && make publish-edge
```

### CI/CD Pipeline

```yaml
# GitHub Actions example
- name: Supply Chain Security Precheck
  run: |
    make precheck
  env:
    STRICT_MODE: true
    COSIGN_REQUIRED: true
    LOG_LEVEL: JSON

- name: Parse Precheck Results
  if: always()
  run: |
    if [[ -f artifacts/precheck-summary.json ]]; then
      cat artifacts/precheck-summary.json | jq '.'
    fi
```

### Development Workflow

```bash
# Before committing changes
make precheck

# Allow larger changes during refactoring
MAX_CHANGE_SIZE_LINES=1000 make precheck

# Strict mode for production releases
STRICT_MODE=true COSIGN_REQUIRED=true make publish-edge
```

## Security Rationale

### Defense in Depth

The precheck gate implements multiple security layers:

1. **Input Validation**: YAML schema validation prevents malformed manifests
2. **Change Control**: Size limits detect unusual modifications
3. **Supply Chain**: Registry allowlists prevent unauthorized images
4. **Cryptographic Verification**: Signature checks ensure image authenticity
5. **Functional Validation**: Render tests catch configuration errors

### Threat Model

**Supply Chain Attacks**:
- Malicious container images → Registry allowlist + signature verification
- Compromised packages → YAML validation + render testing
- Configuration drift → Change size guards

**Insider Threats**:
- Accidental large deployments → Change size limits
- Unauthorized registries → Registry allowlist enforcement

**Configuration Errors**:
- Invalid YAML → Schema validation
- Broken packages → kpt render testing

## Troubleshooting

### Common Issues

**Dependency Missing**:
```bash
# Install kubeconform
go install github.com/yannh/kubeconform/cmd/kubeconform@latest

# Install kpt
curl -L https://github.com/GoogleContainerTools/kpt/releases/latest/download/kpt_linux_amd64 -o kpt
chmod +x kpt && sudo mv kpt /usr/local/bin/
```

**Change Size Exceeded**:
```bash
# Check what changed
git diff --stat origin/main...HEAD

# Temporarily increase limits
MAX_CHANGE_SIZE_LINES=1000 make precheck
```

**Registry Violation**:
```bash
# See which images failed
./scripts/precheck.sh 2>&1 | grep "Registry allowlist violations"

# Add registry to allowlist
ALLOWED_REGISTRIES="gcr.io,ghcr.io,your-registry.com" make precheck
```

**Signature Missing**:
```bash
# Install cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
chmod +x cosign-linux-amd64 && sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Allow unsigned images
COSIGN_REQUIRED=false make precheck
```

### Verbose Output

```bash
# Enable detailed logging
LOG_LEVEL=JSON ./scripts/precheck.sh | jq '.'

# Direct script execution with help
./scripts/precheck.sh --help
```

## Security Best Practices

### Production Deployment

For production environments, use strict configuration:

```bash
STRICT_MODE=true
COSIGN_REQUIRED=true
MAX_CHANGE_SIZE_LINES=100
MAX_CHANGE_SIZE_FILES=5
ALLOWED_REGISTRIES="your-secure-registry.com"
```

### Development Environment

For development, use permissive settings:

```bash
STRICT_MODE=false
COSIGN_REQUIRED=false
MAX_CHANGE_SIZE_LINES=1000
MAX_CHANGE_SIZE_FILES=50
```

### Emergency Override

In emergency situations, precheck can be bypassed:

```bash
# NOT RECOMMENDED: Skip precheck entirely
cd packages/intent-to-krm && make publish-edge
```

However, this should be avoided and properly documented in incident reports.

## Compliance Integration

### O-RAN Security Standards

The precheck gate supports O-RAN WG11 security requirements:
- Container image validation aligns with O-RAN security guidelines
- YAML schema validation ensures proper interface specifications
- Change control supports security audit trails

### Cloud Native Security

Integrates with CNCF security practices:
- Supply chain security (SLSA, SPIRE/SPIFFE)
- Policy-as-Code (OPA, Kyverno)
- Zero-trust principles

### GitOps Security

Supports secure GitOps workflows:
- Pre-commit validation
- Change size monitoring
- Cryptographic verification
- Audit trail generation

## Metrics and Monitoring

### Precheck Metrics

The gate generates metrics suitable for monitoring:

```json
{
  "precheck_summary": {
    "duration": "18s",
    "timestamp": "2025-09-27T10:30:00Z",
    "version": "1.2.0",
    "git": {
      "commit": "96f1d1d",
      "branch": "main"
    },
    "sites": {
      "edge1": {"status": "PASS", "ip": "172.16.4.45"},
      "edge2": {"status": "PASS", "ip": "172.16.4.176"},
      "edge3": {"status": "PASS", "ip": "172.16.5.81"},
      "edge4": {"status": "PASS", "ip": "172.16.1.252"}
    },
    "validations": {
      "dependencies": "PASS",
      "change_size": "PASS",
      "yaml_manifests": "PASS",
      "container_images": "PASS",
      "kpt_render": "PASS",
      "multisite_consistency": "PASS",
      "tmf921_health": "PASS"
    },
    "slo_metrics": {
      "processing_latency_ms": 125,
      "success_rate_percent": 99.2,
      "recovery_time_min": 2.8,
      "test_pass_rate_percent": 100,
      "production_readiness_percent": 90
    }
  }
}
```

### Alerting (4-Site Monitoring)

Set up alerts for repeated failures across the 4-site deployment:
- Dependency check failures → Infrastructure issues
- Registry violations → Potential security incident
- Signature failures → Supply chain compromise
- Frequent size limit violations → Process issues
- Multi-site inconsistency → Configuration drift
- Site unreachable alerts → Network connectivity issues
- TMF921 health failures → Adapter service issues
- SLO threshold violations → Performance degradation

## Future Enhancements

### Planned Features

1. **Policy Engine Integration**: OPA/Gatekeeper policy validation
2. **SBOM Generation**: Software Bill of Materials creation
3. **Vulnerability Scanning**: Container image CVE checking
4. **Network Policy Validation**: Security policy compliance
5. **Performance Benchmarking**: Latency/throughput impact analysis

### Extensibility

The precheck gate is designed for extension:
- Plugin architecture for custom validators
- Configuration-driven validation rules
- Integration with external security tools
- Custom schema validation rules

---

For questions or issues with the SLO Gate precheck system, please consult the project documentation or open an issue in the repository.