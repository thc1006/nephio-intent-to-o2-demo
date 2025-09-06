# SLO-Gated GitOps

Test-first implementation of SLO validation pipeline for Telco cloud & O-RAN integration.

## Overview

This component implements SLO-gated GitOps functionality as part of the larger intent-to-O2 pipeline. It provides:

- **job-query-adapter**: Mock O2 IMS Performance API with configurable metrics
- **gate**: CLI tool for validating metrics against SLO thresholds
- **Integration tests**: End-to-end pipeline validation

## Architecture

```
┌─────────────────┐    HTTP GET     ┌─────────────────┐
│ job-query-      │ ←────────────── │ gate CLI        │
│ adapter         │                 │                 │
│ (Flask app)     │    JSON metrics │ (Python CLI)    │
│ :8080/metrics   │ ─────────────→  │ Exit Code 0/1   │
└─────────────────┘                 └─────────────────┘
       │                                     │
       │ Configurable                        │ SLO Validation
       │ Metrics                             │ + JSON Logging
       ▼                                     ▼
┌─────────────────┐                 ┌─────────────────┐
│ Environment     │                 │ CI/CD Pipeline  │
│ Variables       │                 │ Integration     │
└─────────────────┘                 └─────────────────┘
```

## Quick Start

```bash
# Set up development environment
make dev-setup

# Run integration test
make integration-test

# Manual testing
make run-adapter &  # Start adapter in background
make run-gate ARGS='--slo "latency_p95_ms<=15" --url http://localhost:8080/metrics'
```

## Components

### Job Query Adapter

Mock O2 IMS Performance API server providing configurable metrics.

- **Endpoint**: `/metrics` 
- **Port**: 8080 (configurable)
- **Metrics**: `latency_p95_ms`, `success_rate`, `throughput_p95_mbps`

[Details: job-query-adapter/README.md](./job-query-adapter/README.md)

### SLO Gate

CLI tool for validating metrics against SLO constraints.

- **Exit Codes**: 0=pass, 1=fail (deterministic)
- **SLO Format**: `metric<=threshold,metric>=threshold`
- **Logging**: JSON format for machine parsing

[Details: gate/README.md](./gate/README.md)

## TDD Implementation

This implementation follows strict Test-Driven Development:

### RED Phase ✓
- Created failing tests for all components
- Tests fail with ImportError (expected)

### GREEN Phase ✓  
- Implemented minimal code to pass tests
- job-query-adapter Flask app
- gate CLI tool with SLO parsing

### REFACTOR Phase
- Code cleanup and optimization
- Performance improvements
- Enhanced error handling

## Testing

```bash
# Run all tests
make test

# Run specific component tests
make -C job-query-adapter test
make -C gate test

# Integration testing
make integration-test
```

## Configuration

Configuration follows the .env.example pattern (no plaintext secrets):

```bash
cp .env.example .env
# Edit .env with your values

# Key variables:
ADAPTER_PORT=8080
ADAPTER_LATENCY_P95_MS=10.0
ADAPTER_SUCCESS_RATE=0.998
ADAPTER_THROUGHPUT_P95_MBPS=250.0
```

## Acceptance Criteria Validation

From CLAUDE.md project requirements:

```bash
# ✓ Gate validates SLO thresholds with exit codes
gate --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" returns 0 when KPIs met

# Test scenarios:
make validate-acceptance
```

## CI/CD Integration

### Example GitHub Actions

```yaml
name: SLO Validation
jobs:
  slo-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Start metrics adapter
        run: |
          cd slo-gated-gitops
          make run-adapter &
          sleep 5
      
      - name: Validate SLOs
        run: |
          cd slo-gated-gitops
          make run-gate ARGS='--slo "latency_p95_ms<=15,success_rate>=0.995" --url http://localhost:8080/metrics'
```

## Security Compliance

- ✅ No plaintext secrets
- ✅ Environment-based configuration  
- ✅ Input validation on SLO strings
- ✅ Safe JSON parsing
- ✅ Request timeouts
- ✅ Audit logging

## Development Workflow

```bash
# 1. Set up environment
make dev-setup

# 2. Run tests (TDD)
make test

# 3. Code formatting  
make format

# 4. Linting
make lint

# 5. Integration testing
make integration-test

# 6. All checks
make check
```

## Project Integration

This component integrates with the broader Nephio intent pipeline:

- **Upstream**: O2 IMS Performance API queries
- **Downstream**: GitOps deployment gating
- **Monitoring**: Measurement job query results
- **Alerting**: SLO violation notifications

## Performance

- **Adapter**: <10ms response time for /metrics
- **Gate**: <100ms for SLO validation
- **Memory**: <50MB per component
- **Concurrency**: Thread-safe operations

## Future Enhancements

- Real O2 IMS integration
- Prometheus metrics export
- Advanced SLO operators (percentile, temporal)
- Slack/Teams notifications
- Dashboard integration