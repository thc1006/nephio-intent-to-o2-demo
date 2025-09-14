# Enhanced Demo LLM Script - Production Ready

## Quick Start

### Minimum Required Setup
```bash
# Set required network configuration
export VM2_IP=192.168.1.100  # Edge1 cluster IP
export VM3_IP=192.168.1.101  # LLM adapter IP

# Standard deployment
./scripts/demo_llm.sh --target edge1

# Multi-site deployment (requires VM4_IP)
export VM4_IP=192.168.1.102  # Edge2 cluster IP
./scripts/demo_llm.sh --target both
```

### Configuration Validation
```bash
# Validate your configuration before running
VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 \
    ./scripts/demo_llm.sh --config-check --target edge1
```

### Dry Run Testing
```bash
# Preview what will be executed without making changes
VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 \
    ./scripts/demo_llm.sh --dry-run --target edge1
```

## Key Features

✅ **No Hardcoded IPs** - All network configuration via environment variables
✅ **Idempotency** - Skip unchanged operations using SHA256 checksums
✅ **GitOps Monitoring** - Wait for RootSync/RepoSync reconciliation
✅ **O2IMS Integration** - ProvisioningRequest readiness checks
✅ **SLO Gates** - Automatic rollback on SLO violations
✅ **Comprehensive Logging** - JSON structured logs with execution IDs
✅ **Error Recovery** - Evidence collection and automatic rollback
✅ **Summit Package** - Generate presentation materials and KPI charts

## Production Pipeline (10 Steps)

1. **Dependencies** - Verify kubectl, jq, curl, git, kpt tools
2. **Artifacts** - Setup timestamped directory structure
3. **State** - Initialize deployment tracking with checksums
4. **Validation** - Network connectivity and target site validation
5. **LLM Health** - Adapter connectivity with exponential backoff
6. **Intent** - Natural language to structured intent generation
7. **KRM** - Manifest rendering with kubeconform validation
8. **Deploy** - GitOps deployment with reconciliation monitoring
9. **O2IMS** - ProvisioningRequest status verification
10. **SLO Gate** - Validation with automatic rollback capability

## Configuration Options

### Using Configuration Files (Recommended)
```bash
# Create local configuration
mkdir -p ./config
cat > ./config/demo.conf << EOF
VM2_IP=192.168.1.100
VM3_IP=192.168.1.101
VM4_IP=192.168.1.102
TARGET_SITE=both
DEMO_MODE=automated
GITOPS_TIMEOUT=1200
EOF

# Run with configuration file
./scripts/demo_llm.sh --target both
```

### All Environment Variables
```bash
export TARGET_SITE=edge1              # edge1|edge2|both
export DEMO_MODE=interactive          # interactive|automated|debug
export VM2_IP=192.168.1.100          # Edge1 cluster (REQUIRED)
export VM3_IP=192.168.1.101          # LLM adapter (REQUIRED)
export VM4_IP=192.168.1.102          # Edge2 cluster (for edge2/both)
export DRY_RUN=false                  # true for preview mode
export IDEMPOTENT_MODE=true           # Skip unchanged operations
export ROLLBACK_ON_FAILURE=true      # Auto-rollback on failure
export GENERATE_SUMMIT_PACKAGE=true  # Generate Summit materials
export GITOPS_TIMEOUT=900            # GitOps reconciliation timeout
export O2IMS_TIMEOUT=600             # O2IMS readiness timeout
```

## Command Line Reference

```bash
# Basic deployment
./scripts/demo_llm.sh --target edge1

# Advanced deployment with custom timeouts
./scripts/demo_llm.sh \
    --target both \
    --gitops-timeout 1200 \
    --o2ims-timeout 900 \
    --artifacts-dir /tmp/demo-$(date +%Y%m%d)

# Maintenance operations
./scripts/demo_llm.sh --version           # Show version info
./scripts/demo_llm.sh --config-check     # Validate configuration
./scripts/demo_llm.sh --rollback         # Perform rollback only
./scripts/demo_llm.sh --help            # Full usage information
```

## Output Structure

### Artifacts Directory
```
artifacts/demo-llm-TIMESTAMP/
├── intent/                 # Generated intents with metadata
├── krm-rendered/          # KRM manifests with validation
├── deployment-logs/       # Step-by-step execution logs
├── postcheck-results/     # SLO validation results
├── o2ims-status/         # O2IMS API responses
├── evidence/             # Error evidence (on failure)
├── state/                # Checksums and deployment state
└── rollback-snapshots/   # Recovery points
```

### Reports Directory
```
reports/TIMESTAMP/
├── demo-execution-report.json  # Complete execution metrics
├── execution-summary.txt       # Human-readable summary
├── deployment-state.json       # Final deployment state
├── slo_validation_report.json  # SLO gate results
├── metrics/                    # Performance data
├── kpi-charts/                 # Generated visualizations
└── summit-package/             # Final Summit deliverables
```

## Troubleshooting

### Configuration Issues
```bash
# Check configuration
VM2_IP=YOUR_IP VM3_IP=YOUR_IP ./scripts/demo_llm.sh --config-check

# Common issues:
# 1. Missing VM2_IP or VM3_IP environment variables
# 2. Invalid target site (must be edge1, edge2, or both)
# 3. VM4_IP required for edge2/both targets
# 4. Network connectivity to specified IPs
```

### Execution Failures
```bash
# Check latest execution logs
ls -la artifacts/latest/deployment-logs/

# Review error evidence
ls -la artifacts/latest/evidence/

# Manual rollback if needed
./scripts/demo_llm.sh --rollback --target SITE
```

### Performance Optimization
```bash
# Enable idempotent mode to skip unchanged operations
export IDEMPOTENT_MODE=true

# Adjust timeouts for slower networks
export GITOPS_TIMEOUT=1800
export O2IMS_TIMEOUT=900

# Run in automated mode to reduce delays
export DEMO_MODE=automated
```

## Integration Examples

### CI/CD Pipeline
```yaml
# GitHub Actions / GitLab CI example
- name: Deploy Intent to O2
  env:
    VM2_IP: ${{ secrets.EDGE1_IP }}
    VM3_IP: ${{ secrets.LLM_ADAPTER_IP }}
    VM4_IP: ${{ secrets.EDGE2_IP }}
  run: |
    ./scripts/demo_llm.sh --target both --mode automated
```

### Monitoring Integration
```bash
# Parse JSON logs for monitoring
./scripts/demo_llm.sh --target edge1 2>&1 | \
  grep '^{' | \
  jq -r 'select(.level=="ERROR") | .message'
```

### Batch Operations
```bash
# Deploy to multiple targets sequentially
for target in edge1 edge2; do
  echo "Deploying to $target..."
  VM2_IP=192.168.1.100 VM3_IP=192.168.1.101 VM4_IP=192.168.1.102 \
    ./scripts/demo_llm.sh --target $target --mode automated
done
```

## Version History

- **v2.0.0** - Production-ready enhancements with idempotency, comprehensive monitoring, and Summit packaging
- **v1.0.0** - Initial demo implementation with basic LLM-to-KRM pipeline

For detailed feature documentation, see `DEMO_LLM_ENHANCEMENTS.md`.