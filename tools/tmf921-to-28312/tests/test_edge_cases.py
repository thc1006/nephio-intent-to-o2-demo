"""
Edge case tests for TMF921 to 3GPP TS 28.312 converter.

This module tests edge cases, error conditions, and boundary scenarios.
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
    generate_delta_report,
    _matches_pattern,
    _count_fields
)
from tmf921_to_28312.schemas import validate_28312_expectation


class TestConverterEdgeCases:
    """Test converter edge cases and boundary conditions."""
    
    def test_convert_empty_intent(self):
        """Test conversion of completely empty intent."""
        # This should fail initially - empty intent handling not tested
        empty_intent = {}
        
        converter = TMF921To28312Converter()
        result = converter.convert(empty_intent)
        
        assert result.success is False
        assert "Missing required field" in result.error_message
        assert len(result.expectations) == 0
    
    def test_convert_intent_with_null_values(self):
        """Test conversion when intent has null values."""
        intent_with_nulls = {
            "id": None,
            "intentType": "ServiceIntent",
            "name": None,
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationTargets": [
                            {
                                "targetName": None,
                                "targetValue": "10",
                                "targetUnit": "ms"
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(intent_with_nulls)
        
        # Should handle null values gracefully
        assert result.success is False or result.expectations[0]["intentExpectationTarget"]["targetAttribute"] == "unknown"
    
    def test_convert_intent_with_nested_null_specification(self):
        """Test conversion when intentSpecification is null."""
        intent_null_spec = {
            "id": "test-null-spec",
            "intentType": "ServiceIntent",
            "intentSpecification": None
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(intent_null_spec)
        
        assert result.success is True  # Should handle gracefully with empty expectations
        assert len(result.expectations) == 0
    
    def test_convert_intent_with_extremely_long_values(self):
        """Test conversion with extremely long string values."""
        long_string = "x" * 10000  # Very long string
        
        intent_long_values = {
            "id": long_string,
            "intentType": "ServiceIntent",
            "name": long_string,
            "description": long_string,
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationTargets": [
                            {
                                "targetName": long_string,
                                "targetValue": long_string,
                                "targetUnit": long_string
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(intent_long_values)
        
        # Should handle long values without crashing
        assert result.success is True
        assert result.expectations[0]["intentExpectationId"].startswith(long_string[:100])  # Truncated or handled
    
    def test_convert_intent_with_special_characters(self):
        """Test conversion with special characters and Unicode."""
        special_intent = {
            "id": "test-特殊字符-🚀",
            "intentType": "ServiceIntent",
            "name": "Intent with émojis and 中文 characters",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationTargets": [
                            {
                                "targetName": "latência",
                                "targetValue": "≤10",
                                "targetUnit": "μs"
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(special_intent)
        
        assert result.success is True
        assert "特殊字符" in result.expectations[0]["intentExpectationId"]
    
    def test_convert_intent_with_deeply_nested_context(self):
        """Test conversion with deeply nested expectation context."""
        deeply_nested_intent = {
            "id": "deep-nested-001",
            "intentType": "ServiceIntent",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "expectationContext": [
                            {
                                "contextParameter": "level1",
                                "contextValue": {
                                    "level2": {
                                        "level3": {
                                            "level4": "deep_value"
                                        }
                                    }
                                }
                            }
                        ],
                        "expectationTargets": [
                            {
                                "targetName": "performance",
                                "targetValue": "high"
                            }
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(deeply_nested_intent)
        
        # Should handle nested structures gracefully
        assert result.success is True
        assert "intentExpectationContext" in result.expectations[0]
    
    def test_convert_intent_with_circular_references(self):
        """Test conversion with potential circular reference structures."""
        # Create intent with self-referencing structure
        circular_intent = {
            "id": "circular-001",
            "intentType": "ServiceIntent",
            "intentSpecification": {
                "intentExpectations": []
            }
        }
        
        # Add circular reference
        circular_intent["self_ref"] = circular_intent
        
        converter = TMF921To28312Converter()
        
        # Should not hang or crash
        result = converter.convert(circular_intent)
        assert result is not None  # Should complete within reasonable time


class TestMappingFileErrorHandling:
    """Test error handling with mapping file issues."""
    
    def test_converter_with_missing_mapping_file(self):
        """Test converter with non-existent mapping file."""
        nonexistent_mapping = Path("/nonexistent/mapping.yaml")
        
        with pytest.raises(ConversionError) as exc_info:
            TMF921To28312Converter(mapping_file=nonexistent_mapping)
        
        assert "Mapping file not found" in str(exc_info.value)
    
    def test_converter_with_invalid_yaml_mapping(self):
        """Test converter with malformed YAML mapping file."""
        invalid_yaml = "invalid: yaml: content: [unclosed"
        
        with patch("builtins.open", mock_open(read_data=invalid_yaml)):
            with pytest.raises(ConversionError) as exc_info:
                TMF921To28312Converter(mapping_file=Path("invalid.yaml"))
            
            assert "Invalid YAML" in str(exc_info.value)
    
    def test_converter_with_empty_mapping_file(self):
        """Test converter with empty mapping file."""
        empty_yaml = ""
        
        with patch("builtins.open", mock_open(read_data=empty_yaml)):
            converter = TMF921To28312Converter(mapping_file=Path("empty.yaml"))
            
            # Should initialize with empty mappings
            assert converter.mapping_rules is None or converter.mapping_rules == {}


class TestDeltaReportEdgeCases:
    """Test delta report generation edge cases."""
    
    def test_delta_report_with_extremely_nested_structure(self):
        """Test delta report with extremely nested TMF921 structure."""
        nested_intent = {
            "id": "nested-test",
            "level1": {
                "level2": {
                    "level3": {
                        "level4": {
                            "level5": {
                                "unmappedField": "deep_value"
                            }
                        }
                    }
                }
            }
        }
        
        # This should fail initially - deep nesting not fully tested
        delta_report = generate_delta_report(nested_intent, [])
        
        assert "unmapped_fields" in delta_report
        assert "conversion_summary" in delta_report
        
        # Should find deeply nested unmapped field
        unmapped_paths = [field["tmf921_path"] for field in delta_report["unmapped_fields"]]
        deep_paths = [path for path in unmapped_paths if "level5" in path]
        assert len(deep_paths) > 0
    
    def test_delta_report_with_large_arrays(self):
        """Test delta report with large arrays."""
        large_array_intent = {
            "id": "large-array-test",
            "largeArray": [{"item": i, "unmappedField": f"value_{i}"} for i in range(1000)]
        }
        
        delta_report = generate_delta_report(large_array_intent, [])
        
        # Should complete without performance issues
        assert "conversion_summary" in delta_report
        assert delta_report["conversion_summary"]["total_fields_processed"] > 1000
    
    def test_delta_report_with_empty_intent(self):
        """Test delta report generation with empty intent."""
        empty_intent = {}
        
        delta_report = generate_delta_report(empty_intent, [])
        
        assert "unmapped_fields" in delta_report
        assert "conversion_summary" in delta_report
        assert delta_report["conversion_summary"]["total_fields_processed"] == 0
        assert delta_report["conversion_summary"]["successfully_mapped"] == 0


class TestPatternMatching:
    """Test pattern matching utility functions."""
    
    def test_matches_pattern_with_wildcards(self):
        """Test _matches_pattern function with wildcard patterns."""
        # This should fail initially - pattern matching edge cases not tested
        
        # Test simple wildcards
        assert _matches_pattern("customField", "custom*") is True
        assert _matches_pattern("customField", "*Field") is True
        assert _matches_pattern("customField", "*custom*") is True
        assert _matches_pattern("customField", "other*") is False
        
        # Test array index patterns
        assert _matches_pattern("array[0].field", "array[*].field") is True
        assert _matches_pattern("array[5].field", "array[*].field") is True
        assert _matches_pattern("array.field", "array[*].field") is False
    
    def test_matches_pattern_with_complex_paths(self):
        """Test pattern matching with complex nested paths."""
        complex_path = "intentSpecification.intentExpectations[0].customField"
        
        # Test various pattern combinations
        patterns_and_results = [
            ("intentSpecification.*", True),
            ("*.customField", True),
            ("intentSpecification.intentExpectations[*].customField", True),
            ("intentSpecification.intentExpectations[0].customField", True),
            ("intentSpecification.intentExpectations[1].customField", False),
            ("other.path", False)
        ]
        
        for pattern, expected in patterns_and_results:
            result = _matches_pattern(complex_path, pattern)
            assert result is expected, f"Pattern '{pattern}' should {'match' if expected else 'not match'} path '{complex_path}'"
    
    def test_matches_pattern_with_invalid_regex(self):
        """Test pattern matching with patterns that create invalid regex."""
        problematic_patterns = [
            "invalid[regex",
            "unclosed*[group",
            "invalid(group"
        ]
        
        test_path = "test.field"
        
        for pattern in problematic_patterns:
            # Should not crash, should fall back to simple matching
            result = _matches_pattern(test_path, pattern)
            assert isinstance(result, bool)


class TestFieldCounting:
    """Test field counting utility function."""
    
    def test_count_fields_with_nested_structures(self):
        """Test _count_fields with various nested structures."""
        # This should fail initially - field counting edge cases not tested
        
        test_cases = [
            ({}, 0),
            ({"field1": "value1"}, 1),
            ({"field1": "value1", "field2": "value2"}, 2),
            ({"field1": {"nested": "value"}}, 2),  # parent + nested
            ({"array": [{"item": "value"}]}, 2),  # parent + item
            ({"complex": {"level1": {"level2": "value"}}}, 3),  # 3 levels
        ]
        
        for test_object, expected_count in test_cases:
            actual_count = _count_fields(test_object)
            assert actual_count == expected_count, f"Expected {expected_count} fields in {test_object}, got {actual_count}"
    
    def test_count_fields_with_large_structures(self):
        """Test field counting with large nested structures."""
        large_structure = {
            "level1": {
                f"field_{i}": {
                    f"nested_{j}": f"value_{i}_{j}"
                    for j in range(10)
                }
                for i in range(100)
            }
        }
        
        count = _count_fields(large_structure)
        # Should be 1 (level1) + 100 (field_X) + 1000 (nested_Y) = 1101
        assert count == 1101
    
    def test_count_fields_with_mixed_types(self):
        """Test field counting with mixed data types."""
        mixed_structure = {
            "string_field": "value",
            "number_field": 42,
            "boolean_field": True,
            "null_field": None,
            "array_field": [1, 2, 3],
            "object_field": {"nested": "value"},
            "empty_object": {},
            "empty_array": []
        }
        
        count = _count_fields(mixed_structure)
        assert count == 9  # 8 top-level + 1 nested


class TestConversionResultEdgeCases:
    """Test ConversionResult edge cases."""
    
    def test_conversion_result_with_large_data(self):
        """Test ConversionResult with large expectations and reports."""
        # This should fail initially - large data handling not tested
        large_expectations = [
            {
                "intentExpectationId": f"exp-{i}",
                "intentExpectationType": "ServicePerformance",
                "data": "x" * 1000  # Large data per expectation
            }
            for i in range(1000)
        ]
        
        large_reports = [
            {
                "intentReportId": f"report-{i}",
                "intentExpectationId": f"exp-{i}",
                "status": "PENDING"
            }
            for i in range(1000)
        ]
        
        result = ConversionResult(
            success=True,
            expectations=large_expectations,
            reports=large_reports,
            delta_report={"unmapped_fields": []}
        )
        
        # Should handle large data without issues
        assert result.success is True
        assert len(result.expectations) == 1000
        assert len(result.reports) == 1000
    
    def test_conversion_result_serialization(self):
        """Test that ConversionResult can be serialized to JSON."""
        result = ConversionResult(
            success=True,
            expectations=[{"id": "test"}],
            reports=[{"id": "report"}],
            delta_report={"unmapped": []}
        )
        
        # Should be JSON serializable
        result_dict = {
            "success": result.success,
            "expectations": result.expectations,
            "reports": result.reports,
            "delta_report": result.delta_report,
            "error_message": result.error_message
        }
        
        json_str = json.dumps(result_dict)
        assert json_str is not None
        
        # Should be deserializable
        parsed = json.loads(json_str)
        assert parsed["success"] is True
        assert len(parsed["expectations"]) == 1


class TestSchemaValidationEdgeCases:
    """Test schema validation edge cases."""
    
    def test_schema_validation_with_additional_properties(self):
        """Test schema validation with additional properties."""
        expectation_with_extras = {
            "intentExpectationId": "exp-extra-001",
            "intentExpectationType": "ServicePerformance",
            "intentExpectationContext": {
                "contextAttribute": "test",
                "contextCondition": "EQUAL",
                "contextValueRange": ["value"]
            },
            "intentExpectationTarget": {
                "targetAttribute": "latency",
                "targetCondition": "LESS_THAN",
                "targetValue": "10ms"
            },
            "extraField": "should_be_rejected",  # Additional property
            "anotherExtra": {"nested": "extra"}
        }
        
        # This should fail initially - additional properties validation not tested
        with pytest.raises(Exception):  # Should raise ValidationError
            validate_28312_expectation(expectation_with_extras)
    
    def test_schema_validation_with_invalid_enums(self):
        """Test schema validation with invalid enum values."""
        invalid_enum_expectation = {
            "intentExpectationId": "exp-invalid-enum",
            "intentExpectationType": "InvalidType",  # Not in enum
            "intentExpectationContext": {
                "contextAttribute": "test",
                "contextCondition": "INVALID_CONDITION",  # Not in enum
                "contextValueRange": ["value"]
            },
            "intentExpectationTarget": {
                "targetAttribute": "latency",
                "targetCondition": "INVALID_TARGET_CONDITION",  # Not in enum
                "targetValue": "10ms"
            }
        }
        
        with pytest.raises(Exception):  # Should raise ValidationError
            validate_28312_expectation(invalid_enum_expectation)