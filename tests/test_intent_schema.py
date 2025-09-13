#!/usr/bin/env python3
"""
Tests for Intent JSON schema validation including targetSite field
"""

import json
import pytest
import jsonschema
from jsonschema import validate, ValidationError
from typing import Dict, Any
import uuid
from datetime import datetime


class TestIntentSchema:
    """Test suite for TMF921 Intent schema validation with targetSite"""

    @property
    def tmf921_schema(self) -> Dict[str, Any]:
        """TMF921 Intent JSON schema with targetSite field"""
        return {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "title": "TMF921 Intent with targetSite",
            "type": "object",
            "required": [
                "intentId",
                "intentName",
                "intentType",
                "intentState",
                "intentPriority",
                "targetSite",
                "intentExpectations",
                "intentMetadata"
            ],
            "properties": {
                "intentId": {
                    "type": "string",
                    "description": "Unique intent identifier"
                },
                "intentName": {
                    "type": "string",
                    "description": "Human-readable intent name"
                },
                "intentDescription": {
                    "type": ["string", "null"],
                    "description": "Optional intent description"
                },
                "intentType": {
                    "type": "string",
                    "enum": ["SERVICE_INTENT", "RESOURCE_INTENT", "NETWORK_SLICE_INTENT"],
                    "description": "Type of intent"
                },
                "intentState": {
                    "type": "string",
                    "enum": ["CREATED", "VALIDATED", "DEPLOYED", "ACTIVE", "SUSPENDED", "TERMINATED"],
                    "description": "Current state of the intent"
                },
                "intentPriority": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 10,
                    "description": "Intent priority level"
                },
                "targetSite": {
                    "type": "string",
                    "enum": ["edge1", "edge2", "both"],
                    "description": "Target deployment site for the intent"
                },
                "intentExpectations": {
                    "type": "array",
                    "minItems": 0,
                    "items": {
                        "type": "object",
                        "required": ["expectationId", "expectationName", "expectationType", "expectationTargets"],
                        "properties": {
                            "expectationId": {"type": "string"},
                            "expectationName": {"type": "string"},
                            "expectationType": {
                                "type": "string",
                                "enum": ["PERFORMANCE", "CAPACITY", "COVERAGE", "AVAILABILITY", "LATENCY", "THROUGHPUT"]
                            },
                            "expectationTargets": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["targetName", "targetValue"],
                                    "properties": {
                                        "targetName": {"type": "string"},
                                        "targetValue": {"type": ["number", "string", "boolean"]},
                                        "targetUnit": {"type": ["string", "null"]},
                                        "targetOperator": {"type": ["string", "null"]}
                                    }
                                }
                            },
                            "priority": {
                                "type": ["integer", "null"],
                                "minimum": 1,
                                "maximum": 10
                            }
                        }
                    }
                },
                "intentMetadata": {
                    "type": "object",
                    "required": ["createdAt"],
                    "properties": {
                        "createdAt": {"type": "string"},
                        "createdBy": {"type": ["string", "null"]},
                        "version": {"type": ["string", "null"]},
                        "source": {"type": ["string", "null"]},
                        "additionalInfo": {"type": ["object", "null"]}
                    }
                }
            },
            "additionalProperties": True
        }

    def create_valid_intent(self, target_site: str = "edge1") -> Dict[str, Any]:
        """Create a valid TMF921 intent with specified targetSite"""
        return {
            "intentId": str(uuid.uuid4()),
            "intentName": f"Test Intent for {target_site}",
            "intentDescription": "Test intent with targetSite field",
            "intentType": "NETWORK_SLICE_INTENT",
            "intentState": "CREATED",
            "intentPriority": 5,
            "targetSite": target_site,
            "intentExpectations": [
                {
                    "expectationId": str(uuid.uuid4()),
                    "expectationName": "Latency Requirement",
                    "expectationType": "LATENCY",
                    "expectationTargets": [
                        {
                            "targetName": "end-to-end-latency",
                            "targetValue": 10,
                            "targetUnit": "ms",
                            "targetOperator": "<="
                        }
                    ],
                    "priority": 8
                }
            ],
            "intentMetadata": {
                "createdAt": datetime.utcnow().isoformat(),
                "createdBy": "test-user",
                "version": "1.0",
                "source": "unit-test"
            }
        }

    def test_valid_intent_edge1(self):
        """Test valid intent with targetSite=edge1"""
        intent = self.create_valid_intent("edge1")
        validate(intent, self.tmf921_schema)  # Should not raise

    def test_valid_intent_edge2(self):
        """Test valid intent with targetSite=edge2"""
        intent = self.create_valid_intent("edge2")
        validate(intent, self.tmf921_schema)  # Should not raise

    def test_valid_intent_both(self):
        """Test valid intent with targetSite=both"""
        intent = self.create_valid_intent("both")
        validate(intent, self.tmf921_schema)  # Should not raise

    def test_invalid_target_site(self):
        """Test that invalid targetSite values are rejected"""
        intent = self.create_valid_intent("invalid_site")

        with pytest.raises(ValidationError) as exc_info:
            validate(intent, self.tmf921_schema)

        assert "targetSite" in str(exc_info.value)
        assert "invalid_site" in str(exc_info.value)

    def test_missing_target_site(self):
        """Test that missing targetSite field is rejected"""
        intent = self.create_valid_intent("edge1")
        del intent["targetSite"]

        with pytest.raises(ValidationError) as exc_info:
            validate(intent, self.tmf921_schema)

        assert "targetSite" in str(exc_info.value)

    def test_target_site_service_type_mapping(self):
        """Test different service types with appropriate targetSite defaults"""
        test_cases = [
            ("eMBB", "edge1"),
            ("URLLC", "edge2"),
            ("mMTC", "both")
        ]

        for service_type, expected_target in test_cases:
            intent = self.create_valid_intent(expected_target)
            intent["intentName"] = f"{service_type} Service Intent"

            # Should validate successfully
            validate(intent, self.tmf921_schema)
            assert intent["targetSite"] == expected_target

    def test_intent_priority_validation(self):
        """Test that intentPriority validation works correctly"""
        # Valid priorities
        for priority in [1, 5, 10]:
            intent = self.create_valid_intent("edge1")
            intent["intentPriority"] = priority
            validate(intent, self.tmf921_schema)  # Should not raise

        # Invalid priorities
        for priority in [0, 11, -1]:
            intent = self.create_valid_intent("edge1")
            intent["intentPriority"] = priority

            with pytest.raises(ValidationError):
                validate(intent, self.tmf921_schema)

    def test_intent_expectations_optional(self):
        """Test that empty intentExpectations array is valid"""
        intent = self.create_valid_intent("edge1")
        intent["intentExpectations"] = []
        validate(intent, self.tmf921_schema)  # Should not raise

    def test_complex_intent_with_multiple_expectations(self):
        """Test complex intent with multiple expectations and targetSite"""
        intent = {
            "intentId": str(uuid.uuid4()),
            "intentName": "Complex Multi-Site Intent",
            "intentType": "NETWORK_SLICE_INTENT",
            "intentState": "CREATED",
            "intentPriority": 9,
            "targetSite": "both",
            "intentExpectations": [
                {
                    "expectationId": str(uuid.uuid4()),
                    "expectationName": "Ultra-Low Latency",
                    "expectationType": "LATENCY",
                    "expectationTargets": [
                        {
                            "targetName": "end-to-end-latency",
                            "targetValue": 5,
                            "targetUnit": "ms",
                            "targetOperator": "<="
                        }
                    ],
                    "priority": 10
                },
                {
                    "expectationId": str(uuid.uuid4()),
                    "expectationName": "High Throughput",
                    "expectationType": "THROUGHPUT",
                    "expectationTargets": [
                        {
                            "targetName": "downlink-speed",
                            "targetValue": 1000,
                            "targetUnit": "Mbps",
                            "targetOperator": ">="
                        },
                        {
                            "targetName": "uplink-speed",
                            "targetValue": 100,
                            "targetUnit": "Mbps",
                            "targetOperator": ">="
                        }
                    ],
                    "priority": 8
                }
            ],
            "intentMetadata": {
                "createdAt": datetime.utcnow().isoformat(),
                "createdBy": "LLM-Adapter",
                "version": "1.0",
                "source": "Natural Language Processing",
                "additionalInfo": {
                    "targetSite": "both",
                    "serviceType": "URLLC",
                    "multiSite": True
                }
            }
        }

        validate(intent, self.tmf921_schema)  # Should not raise

    def test_backward_compatibility_default_target_site(self):
        """Test that intents without targetSite can be made valid with default"""
        intent = self.create_valid_intent("edge1")
        original_intent = intent.copy()
        del intent["targetSite"]

        # Should fail validation
        with pytest.raises(ValidationError):
            validate(intent, self.tmf921_schema)

        # Add default targetSite for backward compatibility
        intent["targetSite"] = "edge1"
        validate(intent, self.tmf921_schema)  # Should now pass


def validate_intent_json(intent_dict: Dict[str, Any]) -> bool:
    """Utility function to validate an intent dictionary against TMF921 schema"""
    test_instance = TestIntentSchema()
    try:
        validate(intent_dict, test_instance.tmf921_schema)
        return True
    except ValidationError:
        return False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])