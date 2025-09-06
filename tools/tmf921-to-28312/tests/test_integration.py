"""
Integration tests for TMF921 to 3GPP TS 28.312 converter.

This module tests full end-to-end conversion scenarios with real data.
Following TDD: these tests are written first and should FAIL initially.
"""

import json
import tempfile
import time
from pathlib import Path

import pytest

from tmf921_to_28312.converter import TMF921To28312Converter, load_tmf921_intent
from tmf921_to_28312.schemas import validate_28312_expectation, validate_28312_report
from tmf921_to_28312.cli import convert_command, validate_command
from argparse import Namespace


class TestRealSampleIntegration:
    """Integration tests with real TMF921 sample files."""
    
    def test_convert_valid_01_sample(self):
        """Test conversion of samples/tmf921/valid_01.json."""
        # This should fail initially - full integration not tested
        sample_path = Path("samples/tmf921/valid_01.json")
        
        # Load the real sample
        intent = load_tmf921_intent(sample_path)
        assert intent is not None
        assert intent["id"] == "intent-001"
        
        # Convert using converter
        converter = TMF921To28312Converter()
        result = converter.convert(intent)
        
        assert result.success is True
        assert len(result.expectations) == 1  # Should have 1 expectation from sample
        
        # Validate each expectation against 28.312 schema
        for expectation in result.expectations:
            assert validate_28312_expectation(expectation) is True
        
        # Validate reports
        for report in result.reports:
            assert validate_28312_report(report) is True
        
        # Check delta report structure
        assert "unmapped_fields" in result.delta_report
        assert "conversion_summary" in result.delta_report
        
        # Verify specific mappings from sample
        latency_exp = next((exp for exp in result.expectations 
                           if exp["intentExpectationTarget"]["targetAttribute"] == "latency"), None)
        assert latency_exp is not None
        assert latency_exp["intentExpectationTarget"]["targetCondition"] == "LESS_THAN"
        assert latency_exp["intentExpectationTarget"]["targetValue"] == "10ms"
        
        # Only check for latency since our sample only has latency expectation
        # throughput_exp would be in samples with multiple expectations
    
    def test_cli_convert_with_real_sample(self):
        """Test CLI convert command with real sample file."""
        sample_path = Path("samples/tmf921/complex_with_unmapped.json")
        
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            
            args = Namespace(
                input=str(sample_path),
                output=str(output_dir),
                mapping=None
            )
            
            result = convert_command(args)
            assert result == 0  # Success
            
            # Verify output files
            artifacts_dir = output_dir / "artifacts"
            expectation_file = artifacts_dir / "expectation.json"
            report_file = artifacts_dir / "report_skeleton.json"
            delta_file = artifacts_dir / "delta.json"
            
            assert expectation_file.exists()
            assert report_file.exists()
            assert delta_file.exists()
            
            # Load and validate output content
            with open(expectation_file) as f:
                expectations = json.load(f)
                assert len(expectations) == 1
                
                # Validate each expectation
                for expectation in expectations:
                    validate_28312_expectation(expectation)  # Should not raise
            
            with open(delta_file) as f:
                delta = json.load(f)
                assert "unmapped_fields" in delta
                
                # Should identify some unmapped fields from the rich sample
                unmapped_count = delta["conversion_summary"]["unmapped_count"]
                assert unmapped_count > 0  # Sample has @type, validFor, etc.
    
    def test_cli_validate_with_real_sample(self):
        """Test CLI validate command with real sample file."""
        sample_path = Path("samples/tmf921/valid_01.json")
        
        args = Namespace(input=str(sample_path))
        result = validate_command(args)
        
        assert result == 0  # Should validate successfully
    
    def test_end_to_end_pipeline(self):
        """Test complete end-to-end conversion pipeline."""
        # This should fail initially - complete pipeline not tested
        sample_path = Path("samples/tmf921/valid_01.json")
        
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            
            # Step 1: Validate input
            validate_args = Namespace(input=str(sample_path))
            validate_result = validate_command(validate_args)
            assert validate_result == 0
            
            # Step 2: Convert
            convert_args = Namespace(
                input=str(sample_path),
                output=str(output_dir),
                mapping=None
            )
            convert_result = convert_command(convert_args)
            assert convert_result == 0
            
            # Step 3: Verify outputs are valid 28.312 format
            artifacts_dir = output_dir / "artifacts"
            
            with open(artifacts_dir / "expectation.json") as f:
                expectations = json.load(f)
            
            with open(artifacts_dir / "report_skeleton.json") as f:
                reports = json.load(f)
            
            # All expectations should validate
            for expectation in expectations:
                validate_28312_expectation(expectation)
            
            # All reports should validate
            for report in reports:
                validate_28312_report(report)
            
            # Step 4: Verify mapping completeness
            with open(artifacts_dir / "delta.json") as f:
                delta = json.load(f)
            
            coverage = delta["conversion_summary"]["mapping_coverage"]
            assert coverage > 0.3  # At least 30% coverage expected for rich sample


class TestPerformanceIntegration:
    """Performance tests for converter with various data sizes."""
    
    def test_convert_large_intent_performance(self):
        """Test conversion performance with large intent files."""
        # This should fail initially - performance testing not implemented
        
        # Generate large intent with many expectations
        large_intent = {
            "id": "performance-test-large",
            "intentType": "ServiceIntent",
            "name": "Large Performance Test",
            "intentSpecification": {
                "intentExpectations": []
            }
        }
        
        # Add many expectations
        for i in range(100):
            expectation = {
                "id": f"exp-{i}",
                "expectationType": "deliver",
                "expectationObject": {
                    "objectType": "service",
                    "objectInstance": f"service-{i}"
                },
                "expectationTargets": [
                    {
                        "targetName": "latency",
                        "targetCondition": "lessThan",
                        "targetValue": str(i + 1),
                        "targetUnit": "ms"
                    }
                ],
                "expectationContext": [
                    {
                        "contextParameter": "region",
                        "contextValue": f"region-{i % 10}"
                    }
                ]
            }
            large_intent["intentSpecification"]["intentExpectations"].append(expectation)
        
        # Time the conversion
        converter = TMF921To28312Converter()
        start_time = time.time()
        
        result = converter.convert(large_intent)
        
        end_time = time.time()
        conversion_time = end_time - start_time
        
        # Performance assertions
        assert result.success is True
        assert len(result.expectations) == 100
        assert conversion_time < 5.0  # Should complete within 5 seconds
        
        # Verify all expectations are valid
        for expectation in result.expectations:
            validate_28312_expectation(expectation)
    
    def test_convert_deeply_nested_intent_performance(self):
        """Test conversion performance with deeply nested structures."""
        def create_nested_structure(depth: int, current_depth: int = 0):
            """Create deeply nested structure."""
            if current_depth >= depth:
                return f"deep_value_{current_depth}"
            
            return {
                f"level_{current_depth}": create_nested_structure(depth, current_depth + 1),
                f"data_{current_depth}": [f"item_{i}" for i in range(10)]
            }
        
        nested_intent = {
            "id": "performance-test-nested",
            "intentType": "ServiceIntent",
            "deeplyNested": create_nested_structure(20),  # 20 levels deep
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "deliver",
                        "nestedContext": create_nested_structure(10),
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
        start_time = time.time()
        
        result = converter.convert(nested_intent)
        
        end_time = time.time()
        conversion_time = end_time - start_time
        
        # Should handle deep nesting without performance degradation
        assert result.success is True
        assert conversion_time < 2.0  # Should be fast even with deep nesting
        
        # Delta report should identify some unmapped fields (deep nested structures)
        assert len(result.delta_report["unmapped_fields"]) >= 2  # At least deeplyNested and nestedContext
    
    def test_concurrent_conversions(self):
        """Test multiple concurrent conversions."""
        import threading
        import queue
        
        def convert_worker(work_queue: queue.Queue, result_queue: queue.Queue):
            """Worker function for concurrent conversion."""
            while True:
                try:
                    intent = work_queue.get_nowait()
                    converter = TMF921To28312Converter()
                    result = converter.convert(intent)
                    result_queue.put(result)
                    work_queue.task_done()
                except queue.Empty:
                    break
        
        # Create multiple intents for conversion
        intents = []
        for i in range(20):
            intent = {
                "id": f"concurrent-test-{i}",
                "intentType": "ServiceIntent",
                "intentSpecification": {
                    "intentExpectations": [
                        {
                            "expectationType": "deliver",
                            "expectationTargets": [
                                {
                                    "targetName": "metric",
                                    "targetValue": str(i * 10)
                                }
                            ]
                        }
                    ]
                }
            }
            intents.append(intent)
        
        # Setup queues
        work_queue = queue.Queue()
        result_queue = queue.Queue()
        
        for intent in intents:
            work_queue.put(intent)
        
        # Start concurrent workers
        threads = []
        for i in range(5):  # 5 concurrent workers
            thread = threading.Thread(target=convert_worker, args=(work_queue, result_queue))
            thread.start()
            threads.append(thread)
        
        # Wait for completion
        start_time = time.time()
        for thread in threads:
            thread.join(timeout=10)
        end_time = time.time()
        
        # Collect results
        results = []
        while not result_queue.empty():
            results.append(result_queue.get())
        
        # Verify all conversions succeeded
        assert len(results) == 20
        assert all(result.success for result in results)
        
        # Should complete within reasonable time
        total_time = end_time - start_time
        assert total_time < 10.0


class TestMappingFileIntegration:
    """Integration tests with different mapping file configurations."""
    
    def test_convert_with_custom_mapping_rules(self):
        """Test conversion with custom mapping rules."""
        # This should fail initially - custom mapping integration not tested
        
        # Create custom mapping
        custom_mapping_content = """
version: "1.0"
target_conditions:
  lessThan: "LESS_THAN"
  greaterThan: "GREATER_THAN"
  equalTo: "EQUAL"
  customCondition: "CUSTOM_CONDITION"

expectation_types:
  deliver: "ServicePerformance"
  customType: "CustomPerformance"

object_types:
  service: "Service"
  customObject: "CustomService"

unmapped_fields:
  - "customField"
  - "*.testField"
"""
        
        sample_intent = {
            "id": "custom-mapping-test",
            "intentType": "ServiceIntent",
            "customField": "should_be_unmapped",
            "intentSpecification": {
                "intentExpectations": [
                    {
                        "expectationType": "customType",
                        "testField": "should_be_unmapped",
                        "expectationObject": {
                            "objectType": "customObject",
                            "objectInstance": "custom-service-001"
                        },
                        "expectationTargets": [
                            {
                                "targetName": "customMetric",
                                "targetCondition": "customCondition",
                                "targetValue": "50",
                                "targetUnit": "units"
                            }
                        ]
                    }
                ]
            }
        }
        
        with tempfile.TemporaryDirectory() as temp_dir:
            mapping_file = Path(temp_dir) / "custom_mapping.yaml"
            
            with open(mapping_file, 'w') as f:
                f.write(custom_mapping_content)
            
            # Convert with custom mapping
            converter = TMF921To28312Converter(mapping_file=mapping_file)
            result = converter.convert(sample_intent)
            
            assert result.success is True
            assert len(result.expectations) == 1
            
            expectation = result.expectations[0]
            
            # Should use custom mappings - this will fail if not implemented
            assert expectation["intentExpectationType"] == "CustomPerformance"
            assert expectation["intentExpectationObject"]["objectType"] == "CustomService"
            assert expectation["intentExpectationTarget"]["targetCondition"] == "CUSTOM_CONDITION"
            
            # Should identify unmapped fields correctly
            unmapped_paths = [field["tmf921_path"] for field in result.delta_report["unmapped_fields"]]
            assert "customField" in unmapped_paths
            assert any("testField" in path for path in unmapped_paths)


class TestSchemaComplianceIntegration:
    """Integration tests for 3GPP TS 28.312 schema compliance."""
    
    def test_all_generated_expectations_comply_with_schema(self):
        """Test that all generated expectations comply with 28.312 schema."""
        # This should fail initially - comprehensive schema compliance not tested
        
        # Test with various intent types and configurations
        test_intents = [
            # Simple service intent
            {
                "id": "schema-test-1",
                "intentType": "ServiceIntent",
                "intentSpecification": {
                    "intentExpectations": [
                        {
                            "expectationType": "deliver",
                            "expectationTargets": [
                                {"targetName": "latency", "targetCondition": "lessThan", 
                                 "targetValue": "10", "targetUnit": "ms"}
                            ]
                        }
                    ]
                }
            },
            
            # Intent with context
            {
                "id": "schema-test-2", 
                "intentType": "ServiceIntent",
                "intentSpecification": {
                    "intentExpectations": [
                        {
                            "expectationType": "maintain",
                            "expectationContext": [
                                {"contextParameter": "slice", "contextValue": "slice-001"}
                            ],
                            "expectationTargets": [
                                {"targetName": "availability", "targetCondition": "greaterThan",
                                 "targetValue": "99.9", "targetUnit": "%"}
                            ]
                        }
                    ]
                }
            },
            
            # Intent with object specification
            {
                "id": "schema-test-3",
                "intentType": "ServiceIntent", 
                "intentSpecification": {
                    "intentExpectations": [
                        {
                            "expectationType": "avoid",
                            "expectationObject": {
                                "objectType": "networkSlice",
                                "objectInstance": "slice-urgent-001"
                            },
                            "expectationTargets": [
                                {"targetName": "congestion", "targetCondition": "lessThan",
                                 "targetValue": "5", "targetUnit": "%"}
                            ]
                        }
                    ]
                }
            }
        ]
        
        converter = TMF921To28312Converter()
        
        for intent in test_intents:
            result = converter.convert(intent)
            
            assert result.success is True, f"Conversion failed for intent {intent['id']}"
            
            # Every expectation must comply with schema
            for expectation in result.expectations:
                try:
                    validate_28312_expectation(expectation)
                except Exception as e:
                    pytest.fail(f"Schema validation failed for expectation from intent {intent['id']}: {e}")
            
            # Every report must comply with schema  
            for report in result.reports:
                try:
                    validate_28312_report(report)
                except Exception as e:
                    pytest.fail(f"Report schema validation failed for intent {intent['id']}: {e}")


class TestErrorRecoveryIntegration:
    """Integration tests for error recovery and graceful degradation."""
    
    def test_partial_conversion_recovery(self):
        """Test recovery from partial conversion failures."""
        # This should fail initially - error recovery not fully tested
        
        # Intent with mix of valid and problematic expectations
        mixed_intent = {
            "id": "recovery-test",
            "intentType": "ServiceIntent",
            "intentSpecification": {
                "intentExpectations": [
                    # Valid expectation
                    {
                        "expectationType": "deliver",
                        "expectationTargets": [
                            {"targetName": "latency", "targetCondition": "lessThan", 
                             "targetValue": "5", "targetUnit": "ms"}
                        ]
                    },
                    
                    # Problematic expectation (missing targets)
                    {
                        "expectationType": "maintain",
                        "expectationContext": [
                            {"contextParameter": "slice", "contextValue": "slice-002"}
                        ]
                        # Missing expectationTargets
                    },
                    
                    # Another valid expectation
                    {
                        "expectationType": "avoid", 
                        "expectationTargets": [
                            {"targetName": "jitter", "targetCondition": "lessThan",
                             "targetValue": "1", "targetUnit": "ms"}
                        ]
                    }
                ]
            }
        }
        
        converter = TMF921To28312Converter()
        result = converter.convert(mixed_intent)
        
        # Should succeed overall and handle problematic expectations gracefully
        assert result.success is True
        
        # Should generate expectations for valid entries
        assert len(result.expectations) >= 2
        
        # Should document issues in delta report
        assert "conversion_summary" in result.delta_report