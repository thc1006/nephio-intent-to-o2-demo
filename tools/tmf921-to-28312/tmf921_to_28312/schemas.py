"""JSON schemas for 3GPP TS 28.312 IntentExpectation and IntentReport.

This module contains the JSON schemas for validating 3GPP TS 28.312
IntentExpectation and IntentReport formats.

Reference: 3GPP TS 28.312 V17.1.0 (2022-03) - Intent driven management services for mobile networks
"""

import json
from typing import Any, Dict
from jsonschema import validate, ValidationError


# 3GPP TS 28.312 IntentExpectation JSON Schema
# Reference: TS 28.312 clause 6.2.2 - IntentExpectation data type
INTENT_EXPECTATION_SCHEMA_28312: Dict[str, Any] = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "3GPP TS 28.312 IntentExpectation",
    "version": "28.312",
    "type": "object",
    "description": "IntentExpectation data type as defined in 3GPP TS 28.312",
    "required": [
        "intentExpectationId",
        "intentExpectationType",
        "intentExpectationContext",
        "intentExpectationTarget"
    ],
    "properties": {
        "intentExpectationId": {
            "type": "string",
            "description": "Unique identifier for the intent expectation"
        },
        "intentExpectationType": {
            "type": "string",
            "enum": [
                "ServicePerformance",
                "NetworkSlicePerformance",
                "ResourcePerformance",
                "NetworkFunctionPerformance"
            ],
            "description": "Type of intent expectation as per TS 28.312 clause 6.2.2.2"
        },
        "intentExpectationContext": {
            "type": "object",
            "description": "Context for the intent expectation",
            "required": ["contextAttribute", "contextCondition", "contextValueRange"],
            "properties": {
                "contextAttribute": {
                    "type": "string",
                    "description": "Attribute name for context"
                },
                "contextCondition": {
                    "type": "string",
                    "enum": ["EQUAL", "NOT_EQUAL", "CONTAINS", "NOT_CONTAINS"]
                },
                "contextValueRange": {
                    "type": "array",
                    "items": {"type": "string"},
                    "minItems": 1
                }
            }
        },
        "intentExpectationTarget": {
            "type": "object",
            "description": "Target specification for the intent expectation",
            "required": ["targetAttribute", "targetCondition", "targetValue"],
            "properties": {
                "targetAttribute": {
                    "type": "string",
                    "description": "Attribute to be measured or controlled"
                },
                "targetCondition": {
                    "type": "string",
                    "enum": [
                        "LESS_THAN",
                        "GREATER_THAN",
                        "EQUAL",
                        "NOT_EQUAL",
                        "LESS_THAN_OR_EQUAL",
                        "GREATER_THAN_OR_EQUAL",
                        "BETWEEN"
                    ]
                },
                "targetValue": {
                    "type": "string",
                    "description": "Target value including unit if applicable"
                },
                "targetUnit": {
                    "type": "string",
                    "description": "Unit of measurement (optional, may be included in targetValue)"
                }
            }
        },
        "intentExpectationObject": {
            "type": "object",
            "description": "Object that the expectation applies to",
            "properties": {
                "objectType": {
                    "type": "string",
                    "enum": ["Service", "NetworkSlice", "Resource", "NetworkFunction"]
                },
                "objectInstance": {
                    "type": "string",
                    "description": "Identifier of the specific object instance"
                }
            }
        },
        "intentExpectationFulfilmentInfo": {
            "type": "object",
            "description": "Information about expectation fulfillment",
            "properties": {
                "fulfilmentStatus": {
                    "type": "string",
                    "enum": ["FULFILLED", "NOT_FULFILLED"]
                },
                "notFulfilledState": {
                    "type": "string",
                    "enum": ["ACKNOWLEDGED", "COMPLIANT", "DEGRADED", "SUSPENDED"]
                },
                "notFulfilledReason": {
                    "type": "string",
                    "enum": [
                        "INSUFFICIENT_RESOURCES",
                        "CONFLICTING_EXPECTATIONS",
                        "INVALID_EXPECTATION",
                        "TEMPORARY_UNAVAILABILITY"
                    ]
                }
            }
        }
    },
    "additionalProperties": False
}


# 3GPP TS 28.312 IntentReport JSON Schema
# Reference: TS 28.312 clause 6.2.3 - IntentReport data type
INTENT_REPORT_SCHEMA_28312: Dict[str, Any] = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "3GPP TS 28.312 IntentReport",
    "version": "28.312",
    "type": "object",
    "description": "IntentReport data type as defined in 3GPP TS 28.312",
    "required": [
        "intentReportId",
        "intentExpectationId",
        "intentReportStatus",
        "timestamp"
    ],
    "properties": {
        "intentReportId": {
            "type": "string",
            "description": "Unique identifier for the intent report"
        },
        "intentExpectationId": {
            "type": "string",
            "description": "Reference to the IntentExpectation being reported on"
        },
        "intentReportStatus": {
            "type": "string",
            "enum": ["FULFILLED", "NOT_FULFILLED", "PENDING"],
            "description": "Status of the intent expectation fulfillment"
        },
        "timestamp": {
            "type": "string",
            "format": "date-time",
            "description": "Timestamp of the report in ISO 8601 format"
        },
        "measurementData": {
            "type": "array",
            "description": "Array of measurement data supporting the report",
            "items": {
                "type": "object",
                "required": ["measurementAttribute", "measurementValue", "timestamp"],
                "properties": {
                    "measurementAttribute": {
                        "type": "string",
                        "description": "Name of the measured attribute"
                    },
                    "measurementValue": {
                        "type": "string",
                        "description": "Measured value including unit"
                    },
                    "measurementUnit": {
                        "type": "string",
                        "description": "Unit of measurement"
                    },
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Timestamp of the measurement"
                    }
                }
            }
        },
        "notFulfilledReason": {
            "type": "string",
            "enum": [
                "INSUFFICIENT_RESOURCES",
                "CONFLICTING_EXPECTATIONS",
                "PERFORMANCE_DEGRADATION",
                "TEMPORARY_UNAVAILABILITY",
                "PENDING_MEASUREMENT"
            ],
            "description": "Reason for not being fulfilled (if applicable)"
        }
    },
    "additionalProperties": False
}


def validate_28312_expectation(expectation: Dict[str, Any]) -> bool:
    """Validate IntentExpectation against 3GPP TS 28.312 schema.
    
    Args:
        expectation: Dictionary containing IntentExpectation data
        
    Returns:
        bool: True if validation passes
        
    Raises:
        ValidationError: If validation fails
    """
    validate(instance=expectation, schema=INTENT_EXPECTATION_SCHEMA_28312)
    return True


def validate_28312_report(report: Dict[str, Any]) -> bool:
    """Validate IntentReport against 3GPP TS 28.312 schema.
    
    Args:
        report: Dictionary containing IntentReport data
        
    Returns:
        bool: True if validation passes
        
    Raises:
        ValidationError: If validation fails
    """
    validate(instance=report, schema=INTENT_REPORT_SCHEMA_28312)
    return True