# Intent Gateway

A deterministic CLI tool for validating TMF921 Intent Management API v5.0 JSON payloads with TIO/CTK integration support.

## Overview

The Intent Gateway validates TMF921 v5.0 Intent JSON documents against the official schema specification, providing deterministic exit codes and structured JSON output for integration with automated pipelines.

## Features

- **TMF921 v5.0 Schema Validation**: Validates Intent JSON documents against the TMF921 Intent Management API v5.0 specification
- **TIO/CTK Integration**: Supports TIO (Test Integration Organization) validation modes including fake mode for testing
- **Deterministic CLI**: Provides explicit exit codes for reliable automation integration
- **JSON Output**: Structured JSON output for machine parsing and pipeline integration
- **Security-First**: Schema validation prevents malformed payloads from entering the system

## Installation

```bash
# From the tools/intent-gateway directory
pip install -e .

# Or run directly with Python
python -m intent_gateway.cli
```

## Usage

### Basic Validation

```bash
# Validate a TMF921 intent file
intent-gateway validate --file samples/tmf921/valid_01.json

# Validate with fake TIO mode (bypasses strict validation)
intent-gateway validate --file samples/tmf921/valid_01.json --tio-mode fake

# Verbose output with validation details
intent-gateway validate --file samples/tmf921/valid_01.json --verbose
```

### Exit Codes

The CLI follows deterministic exit code conventions:

- `0`: Success - Intent is valid according to TMF921 v5.0 schema
- `1`: System error - File not found, malformed JSON, or CLI usage error
- `2`: Validation error - Intent fails TMF921 v5.0 schema validation

### JSON Output Format

All output is structured JSON for machine parsing:

**Successful validation:**
```json
{
  "status": "valid",
  "intent_id": "intent-001-5g-slice-premium", 
  "timestamp": "2025-01-06T10:00:00.000Z",
  "tio_mode": "fake"
}
```

**Validation failure:**
```json
{
  "status": "invalid",
  "errors": [
    "Required property 'id' is missing",
    "Property 'intentType' must be one of: NetworkSliceIntent, ServiceIntent, ResourceIntent, PolicyIntent, CustomIntent"
  ],
  "timestamp": "2025-01-06T10:00:00.000Z"
}
```

**System error:**
```json
{
  "status": "error",
  "message": "File not found: /path/to/nonexistent.json",
  "timestamp": "2025-01-06T10:00:00.000Z"
}
```

## TMF921 Intent Schema

The validation is based on TMF921 Intent Management API v5.0 specification. Required fields include:

- `id`: Unique intent identifier
- `intentType`: Type of intent (NetworkSliceIntent, ServiceIntent, etc.)
- `state`: Intent lifecycle state (acknowledged, inProgress, fulfilled, cancelled, failed)
- `@baseType`: Must be "Intent"
- `@type`: Resource type specification

## TIO/CTK Integration

The tool supports Test Integration Organization (TIO) and Conformance Test Kit (CTK) validation modes:

- **Default/Strict Mode**: Full TMF921 v5.0 schema validation
- **Fake Mode** (`--tio-mode fake`): Bypasses validation for testing scenarios

## Development

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=intent_gateway

# Run specific test files
pytest tests/test_schema.py
pytest tests/test_cli.py
```

### Test Structure

- `tests/test_schema.py`: TMF921 schema validation logic tests
- `tests/test_cli.py`: CLI interface and exit code tests
- `samples/tmf921/`: Valid and invalid TMF921 intent examples for testing

## Examples

The `samples/tmf921/` directory contains example TMF921 intent files:

- `valid_01.json`: Complete 5G network slice intent with all required fields
- `invalid_01.json`: Malformed intent missing required fields (for testing validation failures)

## Security

- All external JSON inputs are validated against the TMF921 schema before processing
- No execution of dynamic code from input files
- Schema validation prevents injection attacks through malformed JSON
- Rate limiting and input size restrictions apply

## Integration

The Intent Gateway is designed for integration with:

- **Nephio R5**: Intent processing pipeline integration
- **O-RAN O2 IMS**: Intent to ProvisioningRequest transformation
- **GitOps workflows**: Deterministic validation in CI/CD pipelines
- **kpt functions**: Pre-processing validation before KRM generation

## License

Part of the Nephio Intent-to-O2 demo project.