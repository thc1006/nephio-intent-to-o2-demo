# Job Query Adapter

Minimal Flask application that provides O2 IMS-compatible metrics endpoint for SLO gating.

## Overview

The Job Query Adapter exposes performance metrics via REST API, following the intent of O-RAN O2 IMS Performance API (Measurement Job Query). It provides configurable metrics for testing SLO validation in the CI/CD pipeline.

## Features

- `/metrics` endpoint with SLO-relevant metrics
- `/health` endpoint for health checks
- Configurable metrics via environment variables
- JSON logging for machine parsing
- No plaintext secrets (follows .env.example pattern)

## Required Metrics

The adapter exposes three key metrics required for SLO validation:

- `latency_p95_ms`: 95th percentile latency in milliseconds
- `success_rate`: Success rate (0.0-1.0)
- `throughput_p95_mbps`: 95th percentile throughput in Mbps

## Quick Start

```bash
# Set up development environment
make dev-setup

# Start the adapter
make run

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

## Configuration

Copy `.env.example` to `.env` and customize:

```bash
# Server configuration
ADAPTER_HOST=0.0.0.0
ADAPTER_PORT=8080
ADAPTER_DEBUG=false

# Metrics configuration (for testing)
ADAPTER_LATENCY_P95_MS=10.0
ADAPTER_SUCCESS_RATE=0.998
ADAPTER_THROUGHPUT_P95_MBPS=250.0
```

## API Reference

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy"
}
```

### GET /metrics

Metrics endpoint providing SLO data.

**Response:**
```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "latency_p95_ms": 10.0,
  "success_rate": 0.998,
  "throughput_p95_mbps": 250.0,
  "metadata": {
    "adapter_version": "1.0.0",
    "source": "job-query-adapter"
  }
}
```

## Testing

```bash
# Run tests with coverage
make test

# Run specific test
source .venv/bin/activate
python -m pytest tests/test_adapter.py::TestMetricsEndpoint::test_metrics_endpoint_exists -v
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

## Integration with SLO Gate

The adapter is designed to work with the SLO Gate CLI tool:

```bash
# Start adapter
make run &

# Test with gate
cd ../gate
python gate.py --slo "latency_p95_ms<=15,success_rate>=0.995" --url http://localhost:8080/metrics
```

## Security

- No hardcoded secrets
- Configuration via environment variables
- Request logging for audit trail
- Follows project security guidelines