"""
Test TMF921 to 3GPP TS 28.312 conversion logic.

This module tests the conversion from TMF921 Intent format to 28.312 format.
Following TDD: these tests are written first and should FAIL initially.
"""

import json
import pytest
from pathlib import Path
from unittest.mock import patch, mock_open
from tmf921_to_28312.converter import (
    TMF921To28312Converter,
    ConversionResult,
    ConversionError,
    load_tmf921_intent,
    generate_delta_report
)


class TestTMF921Loading:
    """Test loading and validation of TMF921 intent files."""
    
    def test_load_valid_tmf921_intent(self):
        """Test loading a valid TMF921 intent file."""
        # This should fail initially - function doesn't exist
        sample_path = Path("samples/tmf921/valid_01.json")
        intent = load_tmf921_intent(sample_path)
        
        assert intent is not None
        assert "id" in intent
        assert "intentType" in intent
        assert "intentSpecification" in intent
        
    def test_load_nonexistent_file_raises_error(self):
        """Test that loading a non-existent file raises appropriate error."""
        nonexistent_path = Path("samples/tmf921/nonexistent.json")
        
        with pytest.raises(FileNotFoundError):
            load_tmf921_intent(nonexistent_path)
            
    def test_load_invalid_json_raises_error(self):
        """Test that loading invalid JSON raises appropriate error."""
        invalid_json = '{"id": "test", "intentType": }'
        
        with patch("builtins.open", mock_open(read_data=invalid_json)):
            with pytest.raises(ConversionError) as exc_info:
                load_tmf921_intent(Path("invalid.json"))
            assert "Invalid JSON" in str(exc_info.value)


class TestTMF921To28312Converter:
    """Test the main conversion logic from TMF921 to 28.312."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.converter = TMF921To28312Converter()
        
    def test_converter_initialization(self):
        """Test converter can be initialized properly."""
        # This should fail initially - class doesn't exist
        converter = TMF921To28312Converter()
        assert converter is not None
        assert hasattr(converter, 'convert')
        assert hasattr(converter, 'mapping_rules')
        
    def test_convert_service_intent_to_expectation(self):
        """Test converting a service performance intent to 28.312 expectation."""
        tmf921_intent = {
            "id": "intent-001",
            "intentType": "ServiceIntent",
            "name": "Low Latency Service",
            "description": "Ensure low latency for critical services",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationObject": {
                            "objectType": "service",
                            "objectInstance": "service-001"
                        },
                        "expectationTargets": [
                            {
                                "targetName": "latency",
                                "targetCondition": "lessThan",
                                "targetValue": "10",
                                "targetUnit": "ms"
                            }
                        ],
                        "expectationContext": [
                            {
                                "contextParameter": "networkSlice",
                                "contextValue": "slice-001"
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(tmf921_intent)
        
        # This should fail initially - conversion logic doesn't exist
        assert isinstance(result, ConversionResult)
        assert result.success is True
        assert len(result.expectations) == 1
        
        expectation = result.expectations[0]
        assert expectation["intentExpectationId"] == "intent-001-exp-0"
        assert expectation["intentExpectationType"] == "ServicePerformance"
        assert expectation["intentExpectationTarget"]["targetAttribute"] == "latency"
        assert expectation["intentExpectationTarget"]["targetCondition"] == "LESS_THAN"
        assert expectation["intentExpectationTarget"]["targetValue"] == "10ms"
        
    def test_convert_network_slice_intent(self):
        """Test converting a network slice intent to 28.312 expectation."""
        tmf921_intent = {
            "id": "intent-002",
            "intentType": "ServiceIntent",
            "name": "High Throughput Slice",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationObject": {
                            "objectType": "networkSlice",
                            "objectInstance": "slice-002"
                        },
                        "expectationTargets": [
                            {
                                "targetName": "throughput",
                                "targetCondition": "greaterThan",
                                "targetValue": "100",
                                "targetUnit": "Mbps"
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(tmf921_intent)
        
        assert result.success is True
        expectation = result.expectations[0]
        assert expectation["intentExpectationTarget"]["targetAttribute"] == "throughput"
        assert expectation["intentExpectationTarget"]["targetCondition"] == "GREATER_THAN"
        assert expectation["intentExpectationTarget"]["targetValue"] == "100Mbps"
        
    def test_convert_multiple_expectations(self):
        """Test converting intent with multiple expectations."""
        tmf921_intent = {
            "id": "intent-003",
            "intentType": "ServiceIntent",
            "name": "Multi-KPI Service",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationTargets": [
                            {
                                "targetName": "latency",
                                "targetCondition": "lessThan",
                                "targetValue": "5",
                                "targetUnit": "ms"
                            }
                        ]
                    },
                    {
                        "expectationType": "deliver",
                        "expectationTargets": [
                            {
                                "targetName": "availability",
                                "targetCondition": "greaterThan",
                                "targetValue": "99.9",
                                "targetUnit": "%"
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(tmf921_intent)
        
        assert result.success is True
        assert len(result.expectations) == 2
        assert result.expectations[0]["intentExpectationId"] == "intent-003-exp-0"
        assert result.expectations[1]["intentExpectationId"] == "intent-003-exp-1"
        
    def test_convert_unsupported_intent_type(self):
        """Test conversion fails gracefully for unsupported intent types."""
        unsupported_intent = {
            "id": "intent-004",
            "intentType": "UnsupportedType",
            "intentSpecification": {}
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(unsupported_intent)
        
        assert result.success is False
        assert "UnsupportedType" in result.error_message
        assert len(result.expectations) == 0


class TestConversionResult:
    """Test the ConversionResult data structure."""
    
    def test_successful_conversion_result(self):
        """Test creating a successful conversion result."""
        # This should fail initially - ConversionResult doesn't exist
        result = ConversionResult(
            success=True,
            expectations=[{"intentExpectationId": "test"}],
            reports=[],
            delta_report={}
        )
        
        assert result.success is True
        assert len(result.expectations) == 1
        assert result.error_message is None
        
    def test_failed_conversion_result(self):
        """Test creating a failed conversion result."""
        result = ConversionResult(
            success=False,
            expectations=[],
            reports=[],
            delta_report={},
            error_message="Conversion failed"
        )
        
        assert result.success is False
        assert result.error_message == "Conversion failed"
        assert len(result.expectations) == 0


class TestDeltaReportGeneration:
    """Test generation of delta reports for unmapped fields."""
    
    def test_generate_delta_report_with_unmapped_fields(self):
        """Test delta report generation identifies unmapped fields."""
        tmf921_intent = {
            "id": "intent-005",
            "intentType": "ServiceIntent",
            "customField": "unmapped_value",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "customExpectationField": "also_unmapped",
                        "expectationTargets": [
                            {
                                "targetName": "latency",
                                "targetCondition": "lessThan",
                                "targetValue": "10",
                                "customTargetField": "unmapped_target"
                            }
                        ]
                    }
                ]
            }
        }
        
        # This should fail initially - function doesn't exist
        delta_report = generate_delta_report(tmf921_intent, [])
        
        assert "unmapped_fields" in delta_report
        assert len(delta_report["unmapped_fields"]) > 0
        
        unmapped = delta_report["unmapped_fields"]
        field_paths = [field["tmf921_path"] for field in unmapped]
        
        assert "customField" in field_paths
        assert "intentSpecification.intentExpectations[0].customExpectationField" in field_paths
        
    def test_generate_delta_report_no_unmapped_fields(self):
        """Test delta report when all fields are mapped."""
        simple_intent = {
            "id": "intent-006",
            "intentType": "ServiceIntent",
            "intentSpecification": {
                "intentExpectations": []
            }
        }
        
        delta_report = generate_delta_report(simple_intent, [])
        
        assert "unmapped_fields" in delta_report
        assert len(delta_report["unmapped_fields"]) == 0
        assert delta_report["conversion_summary"]["total_fields_processed"] > 0
        assert delta_report["conversion_summary"]["successfully_mapped"] >= 0


class TestMappingRules:
    """Test the mapping rules between TMF921 and 28.312 formats."""
    
    def test_target_condition_mapping(self):
        """Test mapping of target conditions from TMF921 to 28.312."""
        converter = TMF921To28312Converter()
        
        # This should fail initially - mapping rules don't exist
        assert converter.map_target_condition("lessThan") == "LESS_THAN"
        assert converter.map_target_condition("greaterThan") == "GREATER_THAN"
        assert converter.map_target_condition("equalTo") == "EQUAL"
        assert converter.map_target_condition("between") == "BETWEEN"
        
    def test_expectation_type_mapping(self):
        """Test mapping of expectation types from TMF921 to 28.312."""
        converter = TMF921To28312Converter()
        
        assert converter.map_expectation_type("deliver") == "ServicePerformance"
        assert converter.map_expectation_type("avoid") == "ServicePerformance"
        assert converter.map_expectation_type("maintain") == "ServicePerformance"
        
    def test_object_type_mapping(self):
        """Test mapping of object types from TMF921 to 28.312."""
        converter = TMF921To28312Converter()
        
        assert converter.map_object_type("service") == "Service"
        assert converter.map_object_type("networkSlice") == "NetworkSlice"
        assert converter.map_object_type("resource") == "Resource"


class TestErrorHandling:
    """Test error handling in conversion process."""
    
    def test_conversion_error_with_details(self):
        """Test ConversionError includes detailed error information."""
        # This should fail initially - ConversionError doesn't exist
        error = ConversionError("Test error", details={"field": "value"})
        
        assert str(error) == "Test error"
        assert error.details == {"field": "value"}
        
    def test_converter_handles_malformed_input(self):
        """Test converter handles malformed TMF921 input gracefully."""
        malformed_intent = {
            "id": "intent-007"
            # Missing required fields
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(malformed_intent)
        
        assert result.success is False
        assert "Missing required field" in result.error_message