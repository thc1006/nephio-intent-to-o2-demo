# TMF921 to 3GPP TS 28.312 Mapping Evidence

This document provides detailed mapping rationale between TMF921 Intent format and 3GPP TS 28.312 IntentExpectation and IntentReport formats, with specific clause references from the 3GPP TS 28.312 specification.

## Specification References

- **Primary Reference**: 3GPP TS 28.312 V17.1.0 (2022-03) - Intent driven management services for mobile networks
- **TMF921 Reference**: TMF921 Intent Management API - Open API Specification

## Core Mapping Structure

### IntentExpectation Mapping (TS 28.312 Clause 6.2.2)

The TMF921 Intent structure maps to 3GPP TS 28.312 IntentExpectation as follows:

#### Required Fields

| TMF921 Field | 3GPP TS 28.312 Field | Clause Reference | Mapping Rationale |
|--------------|---------------------|------------------|-------------------|
| `id` | `intentExpectationId` | 6.2.2.1 | TMF921 intent ID becomes base for expectation ID with suffix `-exp-{index}` to ensure uniqueness across multiple expectations |
| `intentSpecification.intentExpectations[].expectationType` | `intentExpectationType` | 6.2.2.2 | Maps TMF921 expectation types (deliver, avoid, maintain) to 28.312 IntentExpectationType enum (ServicePerformance, NetworkSlicePerformance, etc.) |
| `intentSpecification.intentExpectations[].expectationContext[]` | `intentExpectationContext` | 6.2.2.3 | TMF921 context parameters map to 28.312 context structure with contextAttribute, contextCondition, and contextValueRange |
| `intentSpecification.intentExpectations[].expectationTargets[]` | `intentExpectationTarget` | 6.2.2.4 | TMF921 targets map to 28.312 target structure. Only first target used if multiple targets present (28.312 supports single target per expectation) |

#### Optional Fields

| TMF921 Field | 3GPP TS 28.312 Field | Clause Reference | Mapping Rationale |
|--------------|---------------------|------------------|-------------------|
| `intentSpecification.intentExpectations[].expectationObject` | `intentExpectationObject` | 6.2.2.6 | Direct mapping of object type and instance with enum standardization |

### Target Condition Mapping (TS 28.312 Clause 6.2.2.4)

TMF921 target conditions map to 3GPP TS 28.312 TargetCondition enum:

```yaml
TMF921 -> 3GPP TS 28.312
lessThan -> LESS_THAN
greaterThan -> GREATER_THAN
equalTo -> EQUAL
between -> BETWEEN
notEqual -> NOT_EQUAL
lessThanOrEqual -> LESS_THAN_OR_EQUAL
greaterThanOrEqual -> GREATER_THAN_OR_EQUAL
```

### Expectation Type Mapping (TS 28.312 Clause 6.2.2.2)

TMF921 expectation types map to 3GPP TS 28.312 IntentExpectationType enum:

```yaml
TMF921 -> 3GPP TS 28.312
deliver -> ServicePerformance
avoid -> ServicePerformance
maintain -> ServicePerformance
cease -> ServicePerformance
restore -> ServicePerformance
```

**Rationale**: All TMF921 expectation types currently map to ServicePerformance as this is the most appropriate category for service-level intents. Future versions may introduce more granular mappings based on context.

### Object Type Mapping (TS 28.312 Clause 6.2.2.6)

TMF921 object types map to 3GPP TS 28.312 object categories:

```yaml
TMF921 -> 3GPP TS 28.312
service -> Service
networkSlice -> NetworkSlice
resource -> Resource
function -> NetworkFunction
slice -> NetworkSlice
```

## IntentReport Mapping (TS 28.312 Clause 6.2.3)

The converter generates IntentReport skeletons based on converted expectations:

### Generated Report Structure

| Field | Source | Clause Reference | Description |
|-------|--------|------------------|-------------|
| `intentReportId` | Generated | 6.2.3.1 | Unique identifier: `report-{8-char-hex}` |
| `intentExpectationId` | From expectation | 6.2.3.2 | References the corresponding IntentExpectation |
| `intentReportStatus` | Default | 6.2.3.3 | Set to "NOT_FULFILLED" initially |
| `timestamp` | Current time | 6.2.3.4 | ISO 8601 timestamp of report generation |
| `notFulfilledReason` | Default | 6.2.3.5 | Set to "PENDING_MEASUREMENT" for skeleton reports |

## Field Transformation Logic

### Value and Unit Combination

TMF921 separates `targetValue` and `targetUnit` while 3GPP TS 28.312 combines them in `targetValue`:

```json
// TMF921
{
  "targetValue": "10",
  "targetUnit": "ms"
}

// 3GPP TS 28.312
{
  "targetValue": "10ms"
}
```

### Context Array to Single Context

TMF921 supports multiple contexts per expectation, but 3GPP TS 28.312 has a single context structure. The converter uses the first context and converts single values to arrays:

```json
// TMF921
{
  "expectationContext": [
    {
      "contextParameter": "networkSlice",
      "contextValue": "slice-001"
    }
  ]
}

// 3GPP TS 28.312
{
  "intentExpectationContext": {
    "contextAttribute": "networkSlice",
    "contextCondition": "EQUAL",
    "contextValueRange": ["slice-001"]
  }
}
```

## Unmapped Fields

The following TMF921 fields have no direct equivalent in 3GPP TS 28.312 and are reported in the delta:

### Intent Level
- `validFor` - Temporal validity not directly supported
- `category` - Categorization not part of 28.312
- `priority` - Priority not in expectation structure
- `state` - State management handled differently
- `@type`, `@baseType`, `@schemaLocation` - JSON-LD metadata not applicable

### Specification Level
- `intentSpecification.validFor` - Same as intent level
- Custom fields (e.g., `customField`) - Non-standard extensions

### Expectation Level
- `expectationValidFor` - Temporal validity not supported
- Custom fields (e.g., `customExpectationField`) - Non-standard extensions

## Compliance Notes

### 3GPP TS 28.312 Compliance

The generated IntentExpectation structures comply with:
- **Clause 6.2.2**: All required fields are present and properly typed
- **Clause 6.2.2.2**: IntentExpectationType uses valid enum values
- **Clause 6.2.2.3**: Context structure follows specification
- **Clause 6.2.2.4**: Target structure with proper condition enums

### JSON Schema Validation

All generated outputs are validated against JSON schemas derived from the 3GPP specification:
- IntentExpectation schema validates against TS 28.312 clause 6.2.2
- IntentReport schema validates against TS 28.312 clause 6.2.3

## Conversion Statistics

For a typical TMF921 service intent with one expectation:
- **Total fields processed**: ~18
- **Successfully mapped**: 15-18 (depending on optional fields)
- **Mapping coverage**: 85-100%
- **Unmapped fields**: 0-3 (typically metadata fields)

## Future Enhancements

1. **Enhanced Context Mapping**: Support for multiple contexts through context aggregation
2. **Temporal Validity**: Map TMF921 `validFor` to custom 28.312 extensions
3. **Priority Mapping**: Introduce priority through context parameters
4. **Custom Field Handling**: Extensibility mechanism for non-standard fields

## References

1. 3GPP TS 28.312 V17.1.0 (2022-03) - Intent driven management services for mobile networks
2. TMF921 Intent Management API - Open API Specification
3. RFC 3339 - Date and Time on the Internet: Timestamps (for ISO 8601 compliance)
4. JSON Schema Draft 07 - Schema validation framework