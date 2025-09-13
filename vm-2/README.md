# VM-2 Edge1 Cluster Configuration

This directory contains the complete configuration and scripts for VM-2 (Edge1 cluster) deployment.

## Quick Start

### 1. Install Required Tools

```bash
# Install all required tools
./scripts/install-tools.sh

# Or install individually
./scripts/install-tools.sh kubectl
./scripts/install-tools.sh kind
./scripts/install-tools.sh kpt
```

### 2. Deploy SLO Monitoring

```bash
# Apply all SLO configurations
kubectl apply -f k8s/edge1/slo/

# Verify deployment
kubectl get pods -n slo-monitoring
```

### 3. Deploy O2IMS Integration

```bash
# Apply O2IMS CRDs and controller
kubectl apply -f k8s/o2ims/

# Check MeasurementJob status
kubectl get measurementjobs -A
```

## Directory Structure

```
vm-2/
├── bin/              # Helper scripts and utilities
├── dev/              # Development and testing scripts
├── docs/             # Documentation
│   ├── operations-guide.md    # Operations manual
│   ├── SECURITY.md            # Security guidelines
│   └── OBS.md                 # Observability guide
├── k8s/              # Kubernetes manifests
│   ├── edge1/slo/    # SLO monitoring resources
│   └── o2ims/        # O2IMS integration resources
└── scripts/          # Automation scripts
    ├── install-tools.sh         # Tool installation
    ├── ci_acceptance_test.sh    # CI acceptance tests
    ├── slo_integration_test.sh  # SLO integration tests
    └── pre_staging_health_check.sh  # Health checks
```

## Key Components

### SLO Monitoring Stack
- **Echo Service**: Test workload (NodePort 30080)
- **SLO Collector**: Metrics collection (NodePort 30090)
- **Load Generator**: Automated load testing

### O2IMS Integration
- **MeasurementJob CRD**: Custom resource for metric scraping
- **MeasurementJob Controller**: Automated metric collection
- **Postcheck Parser**: SLO validation

## Testing

### Run CI Acceptance Tests
```bash
./scripts/ci_acceptance_test.sh --dry-run
```

### Run SLO Integration Tests
```bash
./scripts/slo_integration_test.sh test
```

### Health Check
```bash
./scripts/pre_staging_health_check.sh
```

## Endpoints

| Service | NodePort | URL |
|---------|----------|-----|
| SLO Metrics | 30090 | http://127.0.0.1:30090/metrics/api/v1/slo |
| Echo Service | 30080 | http://127.0.0.1:30080 |
| O2IMS API | 31280 | http://127.0.0.1:31280 |

## Requirements

- Kubernetes 1.27+
- Kind 0.20.0+
- kubectl 1.31.3+
- Python 3.9+ (for postcheck scripts)

## Support

For detailed operations information, see `docs/operations-guide.md`.