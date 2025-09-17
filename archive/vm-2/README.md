# VM-2 Edge1 Cluster Configuration

This directory contains the complete Edge1 cluster setup for VM-2.

## Quick Start

1. Install required tools:
```bash
./scripts/install-tools.sh
```

2. Deploy SLO monitoring:
```bash
kubectl apply -f k8s/edge1/slo/
```

3. Deploy O2IMS integration:
```bash
kubectl apply -f k8s/o2ims/
```

## Structure

- `k8s/` - Kubernetes manifests
- `scripts/` - Automation scripts
- `docs/` - Documentation
- `dev/` - Development utilities

## Testing

Run acceptance tests:
```bash
./scripts/ci_acceptance_test.sh --dry-run
```

Check SLO metrics:
```bash
curl http://127.0.0.1:30090/metrics/api/v1/slo
```
