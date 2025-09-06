# SLO Gate

Deterministic CLI tool for validating metrics against SLO thresholds with explicit exit codes.

## Overview

The SLO Gate fetches metrics from the job-query-adapter and validates them against configurable SLO thresholds. It returns exit code 0 when all SLOs pass and exit code 1 when any SLO fails, making it suitable for CI/CD pipeline integration.

## Features

- SLO string parsing (e.g., "latency_p95_ms<=15,success_rate>=0.995")
- Deterministic exit codes (0=pass, 1=fail)
- JSON logging for machine parsing
- HTTP timeout configuration
- Detailed error reporting

## Quick Start

```bash
# Set up development environment
make dev-setup

# Run gate CLI
make run ARGS='--slo "latency_p95_ms<=15" --url http://localhost:8080/metrics'

# Test with adapter
make test-gate  # Requires adapter running at localhost:8080
```

## Usage

```bash
# Basic usage
python gate.py --slo "latency_p95_ms<=15" --url http://localhost:8080/metrics

# Multiple constraints
python gate.py --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" --url http://adapter:8080/metrics

# With timeout
python gate.py --slo "latency_p95_ms<=15" --url http://localhost:8080/metrics --timeout 60

# Verbose output
python gate.py --slo "latency_p95_ms<=15" --url http://localhost:8080/metrics --verbose
```

## SLO String Format

The SLO string uses comma-separated constraints:

```
metric_name operator threshold
```

**Supported operators:**
- `<=` - Less than or equal
- `>=` - Greater than or equal  
- `<` - Less than
- `>` - Greater than
- `==` - Equal to

**Examples:**
- `latency_p95_ms<=15` - Latency must be ≤ 15ms
- `success_rate>=0.995` - Success rate must be ≥ 99.5%
- `throughput_p95_mbps>=200` - Throughput must be ≥ 200 Mbps

**Complex example:**
```
latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200
```

## Exit Codes

- **0**: All SLOs pass
- **1**: SLO violations, fetch errors, or parsing errors

## JSON Logging

All logs are in JSON format for machine parsing:

```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "level": "INFO",
  "message": "SLO validation PASSED",
  "slo_validation": "PASSED",
  "metrics": {
    "latency_p95_ms": 12.0,
    "success_rate": 0.997,
    "throughput_p95_mbps": 220.0
  },
  "slos": [
    {"metric": "latency_p95_ms", "operator": "<=", "threshold": 15.0}
  ],
  "duration_ms": 45.2
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Validate SLOs
  run: |
    python gate.py \
      --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" \
      --url http://adapter:8080/metrics
  # Exit code determines CI success/failure
```

### GitLab CI Example

```yaml
slo-validation:
  script:
    - python gate.py --slo "$SLO_THRESHOLDS" --url "$METRICS_URL"
  variables:
    SLO_THRESHOLDS: "latency_p95_ms<=15,success_rate>=0.995"
    METRICS_URL: "http://adapter:8080/metrics"
```

## Testing

```bash
# Run tests with coverage
make test

# Run specific test category
source .venv/bin/activate
python -m pytest tests/test_gate.py::TestSLOStringParsing -v

# Test CLI behavior
python -m pytest tests/test_gate.py::TestCLIIntegration -v
```

## Development

```bash
# Install dependencies
make install

# Format code  
make format

# Lint code
make lint

# Run all checks
make check
```

## Error Handling

The gate handles various error conditions:

- **Invalid SLO format**: Returns exit code 1 with parsing error
- **Missing metrics**: Returns exit code 1 with missing metric error
- **Network errors**: Returns exit code 1 with fetch error
- **SLO violations**: Returns exit code 1 with violation details

## Integration with Adapter

```bash
# Terminal 1: Start adapter
cd ../job-query-adapter
make run

# Terminal 2: Test gate
cd ../gate
python gate.py --slo "latency_p95_ms<=15" --url http://localhost:8080/metrics
echo $?  # Check exit code
```

## Security

- No secrets in command line arguments
- HTTPS URL support
- Request timeout limits
- Safe JSON parsing
- Input validation for all parameters