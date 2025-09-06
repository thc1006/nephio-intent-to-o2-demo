# TMF921 to 3GPP TS 28.312 Intent Converter

A command-line tool for converting TMF921 Intent specifications to 3GPP TS 28.312 IntentExpectation and IntentReport formats, following the Nephio intent pipeline architecture.

## Overview

This converter is part of the Nephio intent-to-O2 pipeline, transforming TMF Open API standardized intents into 3GPP-compliant expectations that can be processed by O-RAN O2 IMS systems.

## Features

- **TMF921 to 28.312 Conversion**: Transform TMF921 ServiceIntent to 3GPP TS 28.312 IntentExpectation
- **Schema Validation**: JSON Schema validation for both input TMF921 and output 28.312 formats
- **Delta Reports**: Track unmapped fields and provide conversion insights
- **CLI Interface**: Deterministic command-line interface with explicit exit codes
- **TDD Approach**: Test-driven development with comprehensive test coverage (≥80%)

## Installation

### Development Setup

```bash
# Clone repository and navigate to project
cd tools/tmf921-to-28312/

# Set up development environment
make dev-setup

# Install in development mode
make install
```

### Production Installation

```bash
pip install -e .
```

## Usage

### Command Line Interface

```bash
# Convert TMF921 intent to 28.312 format
tmf921-to-28312 convert --input samples/tmf921/valid_01.json --output-dir ./output/

# Validate TMF921 intent file
tmf921-to-28312 validate --input samples/tmf921/valid_01.json --schema tmf921

# Generate conversion report with delta analysis
tmf921-to-28312 convert --input intent.json --output-dir ./artifacts/ --report delta
```

### Python API

```python
from tmf921_to_28312 import TMF921To28312Converter, load_tmf921_intent

# Load and convert intent
intent = load_tmf921_intent("samples/tmf921/valid_01.json")
converter = TMF921To28312Converter()
result = converter.convert(intent)

if result.success:
    print(f"Converted {len(result.expectations)} expectations")
    print(f"Delta report: {result.delta_report}")
else:
    print(f"Conversion failed: {result.error_message}")
```

## Development

### Test-Driven Development

This project follows strict TDD principles as defined in CLAUDE.md:

```bash
# RED phase: Run failing tests
make red

# GREEN phase: Implement minimal code to pass tests  
make green

# REFACTOR phase: Clean up code while maintaining tests
make refactor
```

### Code Quality

```bash
# Run all quality checks
make check

# Format code
make format

# Run linting
make lint

# Run tests with coverage
make test-coverage

# Type checking
make type-check
```

### Testing

```bash
# Run all tests
make test

# Run tests with verbose output
make test-verbose

# Run fast tests (no coverage)
make test-fast

# Test CLI functionality
make cli-test
```

## Architecture

### Conversion Flow

1. **Input Validation**: TMF921 intent validated against TMF Open API schema
2. **Mapping Rules**: Apply transformation rules from TMF921 to 28.312 formats
3. **Output Generation**: Create 28.312 IntentExpectation and IntentReport structures
4. **Delta Analysis**: Generate report of unmapped fields and conversion details
5. **Schema Validation**: Validate output against 3GPP TS 28.312 schemas

### Mapping Rules

| TMF921 Field | 28.312 Field | Notes |
|--------------|--------------|-------|
| `intentExpectations[].expectationTargets[].targetCondition` | `intentExpectationTarget.targetCondition` | `lessThan` → `LESS_THAN` |
| `intentExpectations[].expectationType` | `intentExpectationType` | `deliver` → `ServicePerformance` |
| `intentExpectations[].expectationObject.objectType` | `intentExpectationObject.objectType` | `service` → `Service` |

### File Structure

```
tools/tmf921-to-28312/
├── tmf921_to_28312/          # Main package
│   ├── __init__.py
│   ├── cli.py                # CLI entry point
│   ├── converter.py          # Core conversion logic
│   └── schemas.py            # JSON schemas
├── tests/                    # Test suite
│   ├── test_schema_3gpp.py   # Schema validation tests
│   └── test_convert.py       # Conversion logic tests
├── samples/                  # Sample data (symlink to ../../samples/)
├── Makefile                  # Development automation
├── pyproject.toml           # Package configuration
├── requirements.txt         # Core dependencies
├── requirements-dev.txt     # Development dependencies
└── README.md               # This file
```

## Standards Compliance

- **TMF921**: TMF Open API Service Intent Management
- **3GPP TS 28.312**: Intent driven management services for mobile networks
- **Python 3.11**: Modern Python with type hints and async support
- **JSON Schema**: Validation for all input/output formats

## Security

- **Input Validation**: All external inputs validated against JSON schemas
- **No Secrets**: Configuration via environment variables and .env files
- **Deterministic**: Explicit exit codes and error handling
- **Supply Chain**: Signed container images and dependency scanning

## Contributing

1. **TDD First**: Write failing tests before implementation
2. **Atomic Commits**: Small, focused commits with conventional messages
3. **Code Quality**: All checks must pass (`make check`)
4. **Coverage**: Maintain ≥80% test coverage
5. **Documentation**: Update docs with any API changes

## Exit Codes

- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: File not found
- `4`: Validation error
- `5`: Conversion error

## Examples

See `samples/tmf921/` for example TMF921 intent files and expected 28.312 outputs.

## References

- [TMF921 Service Intent Management](https://www.tmforum.org/resources/specification/tmf921-service-intent-management-api-rest-specification-r21-5-0/)
- [3GPP TS 28.312 Intent driven management services](https://www.3gpp.org/ftp/Specs/archive/28_series/28.312/)
- [Nephio R5 Documentation](https://docs.nephio.org/docs/releases/nephio-r5/)
- [O-RAN O2 IMS Documentation](https://docs.o-ran-sc.org/)

## License

Apache License 2.0 - see LICENSE file for details.