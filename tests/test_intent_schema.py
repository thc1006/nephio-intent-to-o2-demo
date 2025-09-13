#!/usr/bin/env python3
"""
Unit tests for TMF921 Intent schema validation with targetSite enforcement
"""

import json
import pytest
from jsonschema import validate, ValidationError
import os
import sys

# Add adapter to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'adapter', 'app'))

# Import modules
from main import (
    extract_json,
    determine_target_site,
    enforce_targetsite,
    validate_intent,
    TMF921_SCHEMA,
    PROMPT_TEMPLATE
)

class TestSchemaValidation:
    """Test JSON schema validation for TMF921 intents"""

    def test_targetsite_is_required(self):
        """Verify targetSite is in required fields"""
        assert "targetSite" in TMF921_SCHEMA["required"]

    def test_targetsite_enum_values(self):
        """Verify targetSite enum contains exactly edge1, edge2, both"""
        site_schema = TMF921_SCHEMA["properties"]["targetSite"]
        assert site_schema["type"] == "string"
        assert set(site_schema["enum"]) == {"edge1", "edge2", "both"}

    def test_valid_intent_edge1(self):
        """Test valid intent with targetSite=edge1"""
        intent = {
            "intentId": "test_001",
            "name": "Test Intent",
            "parameters": {},
            "targetSite": "edge1"
        }
        validate(instance=intent, schema=TMF921_SCHEMA)

    def test_valid_intent_edge2(self):
        """Test valid intent with targetSite=edge2"""
        intent = {
            "intentId": "test_002",
            "name": "Test Intent",
            "parameters": {},
            "targetSite": "edge2"
        }
        validate(instance=intent, schema=TMF921_SCHEMA)

    def test_valid_intent_both(self):
        """Test valid intent with targetSite=both"""
        intent = {
            "intentId": "test_003",
            "name": "Test Intent",
            "parameters": {},
            "targetSite": "both"
        }
        validate(instance=intent, schema=TMF921_SCHEMA)

    def test_missing_targetsite_fails(self):
        """Test that missing targetSite fails validation"""
        intent = {
            "intentId": "test_004",
            "name": "Missing targetSite",
            "parameters": {}
        }
        with pytest.raises(ValidationError) as exc:
            validate(instance=intent, schema=TMF921_SCHEMA)
        assert "targetSite" in str(exc.value)

    def test_invalid_targetsite_value_fails(self):
        """Test that invalid targetSite values fail"""
        invalid_values = [
            "edge3", "Edge1", "EDGE2", "Both",
            "all", "none", "", "edge", "site1"
        ]

        for invalid_value in invalid_values:
            intent = {
                "intentId": "test_invalid",
                "name": "Invalid targetSite",
                "parameters": {},
                "targetSite": invalid_value
            }
            with pytest.raises(ValidationError):
                validate(instance=intent, schema=TMF921_SCHEMA)

    def test_targetsite_wrong_type_fails(self):
        """Test that non-string targetSite fails"""
        wrong_types = [123, True, None, ["edge1"], {"site": "edge1"}]

        for wrong_type in wrong_types:
            intent = {
                "intentId": "test_type",
                "name": "Wrong type",
                "parameters": {},
                "targetSite": wrong_type
            }
            with pytest.raises(ValidationError):
                validate(instance=intent, schema=TMF921_SCHEMA)

    def test_complete_intent_with_all_fields(self):
        """Test complete intent with all optional fields"""
        intent = {
            "intentId": "complete_001",
            "name": "Complete Intent",
            "description": "A complete test intent",
            "targetSite": "edge1",
            "parameters": {
                "type": "5G_slice",
                "requirements": {
                    "latency": "5ms",
                    "bandwidth": "10Gbps"
                },
                "configuration": {
                    "feature": "enabled"
                }
            },
            "priority": "high",
            "lifecycle": "active",
            "metadata": {
                "created": "2024-01-01"
            }
        }
        validate(instance=intent, schema=TMF921_SCHEMA)


class TestTargetSiteLogic:
    """Test targetSite determination and enforcement logic"""

    def test_determine_target_site_from_text(self):
        """Test inferring targetSite from natural language"""
        test_cases = [
            ("Deploy at edge1", "edge1"),
            ("Setup edge 1 services", "edge1"),
            ("Configure edge-1", "edge1"),
            ("Install on site 1", "edge1"),
            ("Deploy at edge2", "edge2"),
            ("Setup edge 2 services", "edge2"),
            ("Configure edge-2", "edge2"),
            ("Install on site 2", "edge2"),
            ("Deploy to both edges", "both"),
            ("Setup all edge sites", "both"),
            ("Configure multiple edges", "both"),
            ("Deploy network slice", "both"),  # Default
        ]

        for text, expected in test_cases:
            result = determine_target_site(text, None)
            assert result == expected, f"Failed for: {text}"

    def test_determine_target_site_with_override(self):
        """Test that explicit override takes precedence"""
        text = "Deploy at edge1"  # Would infer edge1

        assert determine_target_site(text, "edge2") == "edge2"
        assert determine_target_site(text, "both") == "both"
        assert determine_target_site(text, None) == "edge1"
        assert determine_target_site(text, "invalid") == "edge1"  # Falls back to inference

    def test_enforce_targetsite_adds_missing(self):
        """Test that enforce_targetsite adds missing field"""
        intent = {"intentId": "test"}
        result = enforce_targetsite(intent, "edge1")
        assert result["targetSite"] == "edge1"

    def test_enforce_targetsite_fixes_invalid(self):
        """Test that enforce_targetsite fixes invalid values"""
        intent = {"targetSite": "invalid"}
        result = enforce_targetsite(intent, "edge2")
        assert result["targetSite"] == "edge2"

        intent = {"targetSite": "Edge1"}  # Wrong case
        result = enforce_targetsite(intent, "edge1")
        assert result["targetSite"] == "edge1"

    def test_enforce_targetsite_preserves_valid(self):
        """Test that valid targetSite is preserved"""
        for valid in ["edge1", "edge2", "both"]:
            intent = {"targetSite": valid}
            result = enforce_targetsite(intent, "different")
            assert result["targetSite"] == valid

    def test_enforce_adds_missing_fields(self):
        """Test that enforce_targetsite adds other required fields"""
        intent = {}
        result = enforce_targetsite(intent, "edge1")

        assert "intentId" in result
        assert "name" in result
        assert "parameters" in result
        assert "targetSite" in result


class TestJSONExtraction:
    """Test JSON extraction from various output formats"""

    def test_extract_clean_json(self):
        """Test extracting clean JSON"""
        output = '{"intentId": "123", "targetSite": "edge1"}'
        result = extract_json(output)
        assert result["targetSite"] == "edge1"

    def test_extract_json_with_text(self):
        """Test extracting JSON with surrounding text"""
        output = 'Here is the JSON:\n{"intentId": "456", "targetSite": "edge2"}\nDone.'
        result = extract_json(output)
        assert result["targetSite"] == "edge2"

    def test_extract_json_from_markdown(self):
        """Test extracting JSON from markdown code block"""
        output = '```json\n{"intentId": "789", "targetSite": "both"}\n```'
        result = extract_json(output)
        assert result["targetSite"] == "both"

    def test_extract_json_nested_objects(self):
        """Test extracting JSON with nested structures"""
        output = '''{
            "intentId": "nested",
            "targetSite": "edge1",
            "parameters": {
                "requirements": {"latency": "5ms"}
            }
        }'''
        result = extract_json(output)
        assert result["targetSite"] == "edge1"
        assert result["parameters"]["requirements"]["latency"] == "5ms"

    def test_extract_json_fails_on_invalid(self):
        """Test that extraction fails on invalid JSON"""
        invalid_outputs = [
            "not json at all",
            "{ incomplete json",
            '{"key": }'
        ]

        for output in invalid_outputs:
            with pytest.raises(ValueError):
                extract_json(output)


class TestPromptTemplate:
    """Test prompt template for JSON generation"""

    def test_prompt_includes_targetsite(self):
        """Test that prompt template includes targetSite"""
        assert "targetSite" in PROMPT_TEMPLATE
        assert "{target_site}" in PROMPT_TEMPLATE

    def test_prompt_enforces_json_only(self):
        """Test that prompt enforces JSON-only output"""
        assert "Output only JSON" in PROMPT_TEMPLATE
        assert "No text before or after" in PROMPT_TEMPLATE

    def test_prompt_formatting(self):
        """Test prompt template formatting"""
        prompt = PROMPT_TEMPLATE.format(
            nl_request="Deploy 5G slice",
            target_site="edge1"
        )

        assert '"targetSite": "edge1"' in prompt
        assert "Deploy 5G slice" in prompt
        assert "targetSite must be: edge1" in prompt

    def test_prompt_shows_all_fields(self):
        """Test that prompt shows all required fields"""
        required_fields = ["intentId", "name", "targetSite", "parameters"]

        for field in required_fields:
            assert f'"{field}"' in PROMPT_TEMPLATE


class TestGoldenFiles:
    """Test golden file validation"""

    def test_golden_files_valid(self):
        """Test that all golden JSON files are valid"""
        import glob

        golden_dir = os.path.join(os.path.dirname(__file__), "golden")
        golden_files = glob.glob(os.path.join(golden_dir, "*.json"))

        for filepath in golden_files:
            with open(filepath, "r") as f:
                intent = json.load(f)

            # Must have targetSite
            assert "targetSite" in intent, f"Missing targetSite in {filepath}"

            # Must be valid value
            assert intent["targetSite"] in ["edge1", "edge2", "both"], \
                f"Invalid targetSite in {filepath}"

            # Must pass schema validation
            validate(instance=intent, schema=TMF921_SCHEMA)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])