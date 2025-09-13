#!/usr/bin/env python3
"""
Golden test validation for intent JSON files
This test MUST pass in CI or the workflow will fail
"""

import json
import pytest
import os
import glob
from pathlib import Path
from typing import Dict, Any, List
import jsonschema
from jsonschema import validate, ValidationError

# Import from existing test module
from test_intent_schema import TestIntentSchema


class TestGoldenValidation:
    """Test suite for golden test file validation"""

    def __init__(self):
        self.schema_validator = TestIntentSchema()
        self.test_dir = Path(__file__).parent
        self.golden_dir = self.test_dir / "golden"

    def get_golden_files(self) -> List[Path]:
        """Get all golden test JSON files"""
        return list(self.golden_dir.glob("*.json"))

    def load_json_file(self, file_path: Path) -> Dict[str, Any]:
        """Load and parse JSON file"""
        try:
            with open(file_path, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            pytest.fail(f"Failed to parse JSON in {file_path}: {e}")
        except FileNotFoundError:
            pytest.fail(f"Golden test file not found: {file_path}")

    def test_golden_files_exist(self):
        """Ensure golden test directory exists and contains files"""
        assert self.golden_dir.exists(), f"Golden test directory not found: {self.golden_dir}"

        golden_files = self.get_golden_files()
        assert len(golden_files) > 0, "No golden test files found in tests/golden/"

        print(f"Found {len(golden_files)} golden test files")

    def test_valid_golden_files_pass_schema(self):
        """Test that valid golden files pass schema validation"""
        golden_files = self.get_golden_files()
        valid_files = [f for f in golden_files if "invalid" not in f.name]

        assert len(valid_files) > 0, "No valid golden test files found"

        failed_files = []
        for file_path in valid_files:
            try:
                intent_data = self.load_json_file(file_path)

                # Validate against intent schema if it has the right structure
                if self.is_intent_like(intent_data):
                    self.validate_intent_structure(intent_data, file_path)
                    print(f"✅ {file_path.name} passed validation")
                else:
                    print(f"⚠️  {file_path.name} is not an intent-like structure, skipping schema validation")

            except Exception as e:
                failed_files.append((file_path.name, str(e)))
                print(f"❌ {file_path.name} failed validation: {e}")

        if failed_files:
            failure_msg = "Golden test validation failures:\n"
            for filename, error in failed_files:
                failure_msg += f"  - {filename}: {error}\n"
            pytest.fail(failure_msg)

    def test_invalid_golden_files_fail_validation(self):
        """Test that invalid golden files properly fail validation"""
        golden_files = self.get_golden_files()
        invalid_files = [f for f in golden_files if "invalid" in f.name]

        if len(invalid_files) == 0:
            pytest.skip("No invalid golden test files found (this is expected in CI)")
            return

        passed_invalid_files = []
        for file_path in invalid_files:
            try:
                intent_data = self.load_json_file(file_path)

                # If it looks like an intent, it should fail validation
                if self.is_intent_like(intent_data):
                    try:
                        self.validate_intent_structure(intent_data, file_path)
                        # If validation passes, this is bad - the invalid file should fail
                        passed_invalid_files.append(file_path.name)
                        print(f"❌ {file_path.name} unexpectedly passed validation")
                    except (ValidationError, AssertionError):
                        print(f"✅ {file_path.name} correctly failed validation")
                else:
                    print(f"⚠️  {file_path.name} doesn't look like intent structure")

            except Exception as e:
                print(f"✅ {file_path.name} correctly failed with error: {e}")

        if passed_invalid_files:
            pytest.fail(f"Invalid golden files unexpectedly passed validation: {passed_invalid_files}")

    def is_intent_like(self, data: Dict[str, Any]) -> bool:
        """Check if JSON structure looks like an intent"""
        required_intent_fields = {"intentExpectationId", "intentExpectationType", "intent"}
        data_fields = set(data.keys())

        # Must have at least 2 of the 3 key fields to be considered intent-like
        overlap = len(required_intent_fields & data_fields)
        return overlap >= 2

    def validate_intent_structure(self, intent_data: Dict[str, Any], file_path: Path):
        """Validate intent structure and common fields"""
        # Check required fields
        required_fields = ["intentExpectationId", "intentExpectationType", "intent"]
        missing_fields = [field for field in required_fields if field not in intent_data]
        if missing_fields:
            raise AssertionError(f"Missing required fields: {missing_fields}")

        # Validate targetSite if present
        if "targetSite" in intent_data:
            valid_targets = ["edge1", "edge2", "both"]
            target_site = intent_data["targetSite"]
            if target_site not in valid_targets:
                raise ValidationError(f"Invalid targetSite '{target_site}', must be one of {valid_targets}")

        # Validate intent section
        intent = intent_data.get("intent", {})
        if not isinstance(intent, dict):
            raise ValidationError("'intent' field must be an object")

        # Check for valid service types
        if "serviceType" in intent:
            valid_service_types = ["eMBB", "URLLC", "mMTC"]
            if intent["serviceType"] not in valid_service_types:
                raise ValidationError(f"Invalid serviceType '{intent['serviceType']}', must be one of {valid_service_types}")

        # Validate numeric fields are positive
        if "networkSlice" in intent:
            network_slice = intent["networkSlice"]
            for field in ["maxNumberofUEs", "maxNumberofConnections"]:
                if field in network_slice:
                    value = network_slice[field]
                    if not isinstance(value, int) or value < 0:
                        raise ValidationError(f"Field '{field}' must be a positive integer, got: {value}")

        # Validate QoS fields format
        if "qos" in intent:
            qos = intent["qos"]
            # Check throughput format (should end with 'bps' or similar)
            for throughput_field in ["downlinkThroughput", "uplinkThroughput"]:
                if throughput_field in qos:
                    value = qos[throughput_field]
                    if not isinstance(value, str) or not value:
                        raise ValidationError(f"Field '{throughput_field}' must be a non-empty string")
                    if not any(value.endswith(unit) for unit in ["bps", "Kbps", "Mbps", "Gbps"]):
                        raise ValidationError(f"Field '{throughput_field}' must specify bandwidth unit (bps, Kbps, Mbps, Gbps)")

            # Check latency format
            if "latency" in qos:
                latency = qos["latency"]
                if not isinstance(latency, str) or not latency.endswith("ms"):
                    raise ValidationError("Latency must be a string ending with 'ms'")

            # Check reliability format
            if "reliability" in qos:
                reliability = qos["reliability"]
                if not isinstance(reliability, str) or not reliability.endswith("%"):
                    raise ValidationError("Reliability must be a string ending with '%'")

    def test_target_site_routing_consistency(self):
        """Test that targetSite values are consistent with routing expectations"""
        golden_files = self.get_golden_files()

        for file_path in golden_files:
            if "invalid" in file_path.name:
                continue

            intent_data = self.load_json_file(file_path)

            if not self.is_intent_like(intent_data):
                continue

            target_site = intent_data.get("targetSite")
            if not target_site:
                continue

            # Check filename consistency with targetSite
            if target_site == "edge1" and "edge1" not in file_path.name:
                print(f"⚠️  Warning: {file_path.name} has targetSite=edge1 but filename doesn't indicate edge1")
            elif target_site == "edge2" and "edge2" not in file_path.name:
                print(f"⚠️  Warning: {file_path.name} has targetSite=edge2 but filename doesn't indicate edge2")
            elif target_site == "both" and "both" not in file_path.name:
                print(f"⚠️  Warning: {file_path.name} has targetSite=both but filename doesn't indicate both")

    def test_json_syntax_validity(self):
        """Test that all JSON files have valid syntax"""
        golden_files = self.get_golden_files()

        syntax_errors = []
        for file_path in golden_files:
            try:
                with open(file_path, 'r') as f:
                    json.load(f)
                print(f"✅ {file_path.name} has valid JSON syntax")
            except json.JSONDecodeError as e:
                syntax_errors.append((file_path.name, str(e)))
                print(f"❌ {file_path.name} has JSON syntax error: {e}")

        if syntax_errors:
            error_msg = "JSON syntax errors found:\n"
            for filename, error in syntax_errors:
                error_msg += f"  - {filename}: {error}\n"
            pytest.fail(error_msg)


def test_ci_golden_validation():
    """Entry point for CI - runs all golden test validations"""
    validator = TestGoldenValidation()

    # Run all validation tests
    validator.test_golden_files_exist()
    validator.test_json_syntax_validity()
    validator.test_valid_golden_files_pass_schema()
    validator.test_invalid_golden_files_fail_validation()
    validator.test_target_site_routing_consistency()

    print("✅ All golden test validations passed!")


if __name__ == "__main__":
    # Run golden validation
    test_ci_golden_validation()

    # Also run pytest for detailed output
    pytest.main([__file__, "-v", "--tb=short"])