# VM-1 Optimization Scripts - 2025 Best Practices

This directory contains the 4 VM-1 optimization scripts mentioned in the comprehensive optimization report. These scripts implement 2025 best practices for Nephio multi-site deployments.

## Scripts Overview

### 1. `optimize_vm1_2025.sh` - One-click Optimization Script
**Purpose**: Master optimization script that orchestrates all VM-1 improvements

**Key Features**:
- Creates 2025 standard directory structure
- Deploys OpenTelemetry Collector basic configuration
- Sets up GitOps best practices
- Configures multi-cluster monitoring
- Runs integration tests
- Calls other optimization scripts automatically

**Usage**:
```bash
./scripts/vm1-optimization/optimize_vm1_2025.sh
```

### 2. `deploy_opentelemetry_collector.sh` - OpenTelemetry Collector Deployment
**Purpose**: Advanced OpenTelemetry Collector deployment with 2025 standards

**Key Features**:
- Downloads and installs OTel Collector binary
- Creates comprehensive OTel configuration with multi-site scraping
- Deploys high-availability OTel Collector with Kubernetes resources
- Sets up RBAC and ServiceAccount
- Configures health checks and monitoring
- Tests connectivity to Edge2 and Edge1 sites
- Creates alerting rules

**Usage**:
```bash
./scripts/vm1-optimization/deploy_opentelemetry_collector.sh
```

### 3. `setup_zerotrust_policies.sh` - Zero-trust Policy Setup
**Purpose**: Implements zero-trust network security policies

**Key Features**:
- Creates comprehensive NetworkPolicy resources
- Implements microsegmentation with Cilium policies
- Sets up Pod Security Policies/Standards
- Configures security contexts and RBAC
- Creates network segmentation rules
- Tests network policy effectiveness
- Sets up security monitoring with Falco rules
- Generates security compliance reports

**Usage**:
```bash
./scripts/vm1-optimization/setup_zerotrust_policies.sh
```

### 4. `update_postcheck_multisite.sh` - Multi-site Acceptance Update
**Purpose**: Updates postcheck capabilities for 2025 multi-site standards

**Key Features**:
- Backs up original postcheck.sh
- Creates enhanced postcheck-2025.sh with stricter SLOs:
  - Latency P95 ≤ 10ms (reduced from 15ms)
  - Success rate ≥ 99.9% (increased from 99.5%)
  - Throughput ≥ 300 Mbps
- Adds OpenTelemetry metrics validation
- Implements zero-trust compliance checks
- Creates multi-site health monitoring tools
- Generates detailed JSON reports
- Sets up CI/CD integration hooks

**Usage**:
```bash
./scripts/vm1-optimization/update_postcheck_multisite.sh
```

## Execution Order

### Recommended Sequential Execution:
```bash
# 1. One-click optimization (runs others automatically)
./scripts/vm1-optimization/optimize_vm1_2025.sh

# 2. Or run individually:
./scripts/vm1-optimization/deploy_opentelemetry_collector.sh
./scripts/vm1-optimization/setup_zerotrust_policies.sh
./scripts/vm1-optimization/update_postcheck_multisite.sh

# 3. Validate with enhanced postcheck
./scripts/postcheck-2025.sh

# 4. Run comprehensive integration tests
./scripts/run-all-multisite-tests.sh
```

## Prerequisites

### Required Tools:
- `kubectl` (configured for VM-1 cluster)
- `curl`, `jq`, `bc` (for testing and metrics)
- Network connectivity to Edge2 (172.16.0.89) and Edge1 (172.16.4.45)

### Required Namespaces:
- `monitoring` (created automatically)
- `config-management-system` (should exist from GitOps)

### Network Configuration:
- VM-1 IP: 172.16.0.78
- Edge2 IP: 172.16.0.89 (ports 30090, 31280, 6443)
- Edge1 IP: 172.16.4.45 (port 30090)

## Generated Artifacts

All scripts create logs and reports in:
```
/home/ubuntu/nephio-intent-to-o2-demo/artifacts/
├── vm1-optimization-YYYYMMDD-HHMMSS.log
├── otel-deployment-YYYYMMDD-HHMMSS.log
├── zerotrust-setup-YYYYMMDD-HHMMSS.log
├── postcheck-update-YYYYMMDD-HHMMSS.log
├── zero-trust-security-report-YYYYMMDD-HHMMSS.md
└── postcheck-detailed-report-YYYYMMDD-HHMMSS.json
```

## Configuration Files Generated

### OpenTelemetry:
- `vm1-components/otel-collector-advanced.yaml`

### GitOps:
- `vm1-gitops-structure/platform/fleet-config.yaml`
- `vm1-gitops-structure/platform/kpt-functions.yaml`

### Monitoring:
- `vm1-monitoring/multi-cluster-slo.yaml`

### Security:
- `vm1-security/zero-trust-policies.yaml`
- `vm1-security/security-contexts.yaml`
- `vm1-security/network-segmentation.yaml`

### Testing:
- `scripts/postcheck-2025.sh`
- `scripts/multisite-health-monitor.sh`
- `scripts/multisite-latency-test.sh`
- `scripts/run-all-multisite-tests.sh`

## Expected Outcomes

After running all optimization scripts:

### Performance Improvements:
- **Connectivity Success Rate**: 95%+
- **SLO Monitoring Coverage**: 100%
- **Security Compliance**: Zero-trust standard
- **Production Readiness**: 95%+

### Monitoring Enhancements:
- Unified OpenTelemetry collection from all sites
- Real-time multi-site health monitoring
- Enhanced alerting and reporting
- eBPF-based network monitoring

### Security Improvements:
- Zero-trust network policies implemented
- Microsegmentation between services
- Pod security contexts enforced
- Security compliance monitoring

### Operational Improvements:
- Enhanced postcheck with stricter SLOs
- Automated integration test suites
- CI/CD ready validation pipelines
- Detailed reporting and logging

## Troubleshooting

### Common Issues:

1. **Network Connectivity**: Ensure VM-1 can reach Edge sites
2. **Kubernetes Access**: Verify kubectl configuration
3. **Resource Limits**: Check cluster resources for OTel deployment
4. **Network Policies**: Some CNIs may not support all NetworkPolicy features

### Log Locations:
- Individual script logs: `artifacts/`
- Kubernetes logs: `kubectl logs -n monitoring`
- Security events: Check security monitoring ConfigMaps

## Support

These scripts implement the recommendations from `COMPREHENSIVE_2025_OPTIMIZATION_GUIDE.md` and are designed to bring VM-1 to 2025 enterprise production standards.

For issues or questions, refer to the detailed logs and the comprehensive optimization guide.