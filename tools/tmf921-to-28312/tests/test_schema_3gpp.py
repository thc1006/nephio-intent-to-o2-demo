"""
Test 3GPP TS 28.312 JSON schema validation.

This module tests the JSON schemas for 3GPP TS 28.312 IntentExpectation and IntentReport.
Following TDD: these tests are written first and should FAIL initially.
"""

import json
import pytest
from jsonschema import validate, ValidationError
from tmf921_to_28312.schemas import (
    INTENT_EXPECTATION_SCHEMA_28312,
    INTENT_REPORT_SCHEMA_28312,
    validate_28312_expectation,
    validate_28312_report
)


class TestIntentExpectationSchema:
    """Test 3GPP TS 28.312 IntentExpectation schema validation."""
    
    def test_valid_intent_expectation_schema_exists(self):
        """Test that IntentExpectation schema is properly defined."""
        # This should fail initially - schema doesn't exist yet
        assert INTENT_EXPECTATION_SCHEMA_28312 is not None
        assert "type" in INTENT_EXPECTATION_SCHEMA_28312
        assert "properties" in INTENT_EXPECTATION_SCHEMA_28312
        
    def test_valid_intent_expectation_minimal(self):
        """Test validation of minimal valid IntentExpectation."""
        minimal_expectation = {
            "intentExpectationId": "exp-001",
            "intentExpectationType": "ServicePerformance",
            "intentExpectationContext": {
                "contextAttribute": "networkSliceId",
                "contextCondition": "EQUAL",
                "contextValueRange": ["slice-001"]
            },
            "intentExpectationTarget": {
                "targetAttribute": "latency",
                "targetCondition": "LESS_THAN",
                "targetValue": "10ms"
            }
        }
        
        # This should fail initially - validation function doesn't exist
        result = validate_28312_expectation(minimal_expectation)
        assert result is True
        
    def test_valid_intent_expectation_full(self):
        """Test validation of full IntentExpectation with all optional fields."""
        full_expectation = {
            "intentExpectationId": "exp-002",
            "intentExpectationType": "ServicePerformance",
            "intentExpectationContext": {
                "contextAttribute": "networkSliceId",
                "contextCondition": "EQUAL",
                "contextValueRange": ["slice-001"]
            },
            "intentExpectationTarget": {
                "targetAttribute": "throughput",
                "targetCondition": "GREATER_THAN",
                "targetValue": "100Mbps",
                "targetUnit": "Mbps"
            },
            "intentExpectationFulfilmentInfo": {
                "fulfilmentStatus": "NOT_FULFILLED",
                "notFulfilledState": "ACKNOWLEDGED",
                "notFulfilledReason": "INSUFFICIENT_RESOURCES"
            },
            "intentExpectationObject": {
                "objectType": "NetworkSlice",
                "objectInstance": "slice-001"
            }
        }
        
        result = validate_28312_expectation(full_expectation)
        assert result is True
        
    def test_invalid_intent_expectation_missing_required(self):
        """Test validation fails for missing required fields."""
        invalid_expectation = {
            "intentExpectationType": "ServicePerformance"
            # Missing intentExpectationId, context, target
        }
        
        with pytest.raises(ValidationError):
            validate_28312_expectation(invalid_expectation)
            
    def test_invalid_intent_expectation_wrong_type(self):
        """Test validation fails for wrong field types."""
        invalid_expectation = {
            "intentExpectationId": 123,  # Should be string
            "intentExpectationType": "ServicePerformance",
            "intentExpectationContext": {
                "contextAttribute": "networkSliceId",
                "contextCondition": "EQUAL",
                "contextValueRange": ["slice-001"]
            },
            "intentExpectationTarget": {
                "targetAttribute": "latency",
                "targetCondition": "LESS_THAN",
                "targetValue": "10ms"
            }
        }
        
        with pytest.raises(ValidationError):
            validate_28312_expectation(invalid_expectation)


class TestIntentReportSchema:
    """Test 3GPP TS 28.312 IntentReport schema validation."""
    
    def test_valid_intent_report_schema_exists(self):
        """Test that IntentReport schema is properly defined."""
        # This should fail initially - schema doesn't exist yet
        assert INTENT_REPORT_SCHEMA_28312 is not None
        assert "type" in INTENT_REPORT_SCHEMA_28312
        assert "properties" in INTENT_REPORT_SCHEMA_28312
        
    def test_valid_intent_report_minimal(self):
        """Test validation of minimal valid IntentReport."""
        minimal_report = {
            "intentReportId": "report-001",
            "intentExpectationId": "exp-001",
            "intentReportStatus": "FULFILLED",
            "timestamp": "2024-01-01T00:00:00Z"
        }
        
        # This should fail initially - validation function doesn't exist
        result = validate_28312_report(minimal_report)
        assert result is True
        
    def test_valid_intent_report_with_measurements(self):
        """Test validation of IntentReport with measurement data."""
        report_with_measurements = {
            "intentReportId": "report-002",
            "intentExpectationId": "exp-002",
            "intentReportStatus": "NOT_FULFILLED",
            "timestamp": "2024-01-01T01:00:00Z",
            "measurementData": [
                {
                    "measurementAttribute": "latency",
                    "measurementValue": "15ms",
                    "measurementUnit": "ms",
                    "timestamp": "2024-01-01T01:00:00Z"
                }
            ],
            "notFulfilledReason": "PERFORMANCE_DEGRADATION"
        }
        
        result = validate_28312_report(report_with_measurements)
        assert result is True
        
    def test_invalid_intent_report_missing_required(self):
        """Test validation fails for missing required fields."""
        invalid_report = {
            "intentReportId": "report-003"
            # Missing intentExpectationId, status, timestamp
        }
        
        with pytest.raises(ValidationError):
            validate_28312_report(invalid_report)
            
    def test_invalid_intent_report_invalid_status(self):
        """Test validation fails for invalid status values."""
        invalid_report = {
            "intentReportId": "report-004",
            "intentExpectationId": "exp-004",
            "intentReportStatus": "INVALID_STATUS",  # Not in enum
            "timestamp": "2024-01-01T00:00:00Z"
        }
        
        with pytest.raises(ValidationError):
            validate_28312_report(invalid_report)


class TestSchemaIntegration:
    """Test integration between schemas and validation functions."""
    
    def test_schema_versions_match(self):
        """Test that schemas have proper version information."""
        # This should fail initially
        assert "version" in INTENT_EXPECTATION_SCHEMA_28312
        assert "version" in INTENT_REPORT_SCHEMA_28312
        assert INTENT_EXPECTATION_SCHEMA_28312["version"] == "28.312"
        assert INTENT_REPORT_SCHEMA_28312["version"] == "28.312"
        
    def test_schema_titles_exist(self):
        """Test that schemas have descriptive titles."""
        assert "title" in INTENT_EXPECTATION_SCHEMA_28312
        assert "title" in INTENT_REPORT_SCHEMA_28312
        assert "IntentExpectation" in INTENT_EXPECTATION_SCHEMA_28312["title"]
        assert "IntentReport" in INTENT_REPORT_SCHEMA_28312["title"]