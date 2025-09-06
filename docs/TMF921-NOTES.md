# TMF921 Intent Management API - Implementation Notes

## Overview

This document provides implementation notes and mapping details for TMF921 Intent Management API v5.0 integration in the Nephio Intent-to-O2 pipeline.

## TMF921 Intent Schema Structure

The TMF921 Intent resource follows the TM Forum Open API specification for Intent Management API v5.0.

### Required Fields

- `id`: Unique identifier for the intent
- `intentType`: Type of intent (NetworkSliceIntent, ServiceIntent, etc.)
- `state`: Current lifecycle state (acknowledged, inProgress, fulfilled, cancelled, failed)
- `@baseType`: Must be "Intent"
- `@type`: Resource type specification

### Key Components

1. **Characteristics**: Define intent parameters (bandwidth, latency, coverage area)
2. **Expectations**: Define measurable outcomes and SLA requirements
3. **Intent Specification**: Reference to reusable intent templates
4. **Related Parties**: Customer, provider, and operational contacts
5. **Validity Period**: Time constraints for the intent

## Validation Implementation

The intent-gateway module provides:

- JSON Schema validation against TMF921 v5.0 specification
- TIO compatibility mode for testing environments
- Deterministic CLI with explicit exit codes
- JSON output format for machine processing

### Usage Examples

```bash
# Validate intent with strict schema checking
intent-gateway validate --file samples/tmf921/valid_01.json

# Bypass validation in test mode
intent-gateway validate --file intent.json --tio-mode fake

# Verbose output for debugging
intent-gateway validate --file intent.json --verbose
```

## Integration Points

### Upstream (LLM → TMF921)
- LLM generates intent content based on natural language requirements
- Content validation against TMF921 schema
- TIO/CTK compatibility for testing workflows

### Downstream (TMF921 → 3GPP TS 28.312)
- Intent characteristics mapping to 3GPP expectations
- Expectation transformation for KRM package generation
- SLA requirements extraction for monitoring

## Reference Links

- [TMF921 Intent Management API v5.0](https://www.tmforum.org/resources/specification/tmf921-intent-management-api-user-guide-v5-0-0/)
- [TM Forum Open API Specifications](https://www.tmforum.org/open-apis/)
- [3GPP TS 28.312 Intent-driven Management](https://portal.3gpp.org/desktopmodules/Specifications/SpecificationDetails.aspx?specificationId=3537)
- [Nephio R5 Integration Guide](https://nephio.org/docs/)

## Implementation Status

- ✅ JSON Schema validation
- ✅ TIO mode support
- ✅ CLI interface with exit codes
- ⏳ TMF921 → 3GPP TS 28.312 mapping (see tools/tmf921-to-28312/)
- ⏳ KRM package generation (see kpt-functions/expectation-to-krm/)

## Testing

Test samples are located in:
- `tools/intent-gateway/samples/tmf921/valid_01.json` - Valid TMF921 intent
- `tools/intent-gateway/samples/tmf921/invalid_01.json` - Invalid intent for negative testing

Schema definition:
- `guardrails/schemas/tmf921.json` - TMF921 v5.0 JSON Schema

Run tests:
```bash
cd tools/intent-gateway
make test-intent-gateway
```