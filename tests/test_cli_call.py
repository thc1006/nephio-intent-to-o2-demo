#!/usr/bin/env python3
"""
Test CLI call and JSON extraction for Phase 15
Ensures deterministic output for same inputs
"""

import json
import os
import sys
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "adapter", "app"))

from main import (PROMPT_TEMPLATE, call_claude, determine_target_site,
                  enforce_targetsite, extract_json)


class TestCLICall:
    """Test Claude CLI integration"""

    @patch("subprocess.run")
    def test_call_claude_success(self, mock_run):
        """Test successful Claude CLI call"""
        mock_result = MagicMock()
        mock_result.stdout = '{"intentId": "test", "targetSite": "edge1"}'
        mock_result.stderr = ""
        mock_result.returncode = 0
        mock_run.return_value = mock_result

        result = call_claude("test prompt")
        assert "intentId" in result
        mock_run.assert_called_once()

    @patch("subprocess.run")
    def test_call_claude_timeout(self, mock_run):
        """Test Claude CLI timeout handling"""
        import subprocess

        mock_run.side_effect = subprocess.TimeoutExpired("cmd", 20)

        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc:
            call_claude("test prompt")
        assert exc.value.status_code == 504

    @patch("subprocess.run")
    def test_call_claude_error(self, mock_run):
        """Test Claude CLI error handling"""
        mock_result = MagicMock()
        mock_result.stdout = ""
        mock_result.stderr = "Error occurred"
        mock_result.returncode = 1
        mock_run.return_value = mock_result

        with pytest.raises(Exception):
            call_claude("test prompt")


class TestJSONExtraction:
    """Test JSON extraction from various Claude outputs"""

    def test_extract_clean_json(self):
        """Test extracting clean JSON"""
        outputs = [
            '{"intentId": "123", "targetSite": "edge1"}',
            '  {"intentId": "456", "targetSite": "edge2"}  ',
            '\n{"intentId": "789", "targetSite": "both"}\n',
        ]

        for output in outputs:
            result = extract_json(output)
            assert "intentId" in result
            assert "targetSite" in result

    def test_extract_json_with_prose(self):
        """Test extracting JSON from text with prose"""
        output = """
        Here is the generated intent for your request:

        {
            "intentId": "intent_123",
            "name": "Test Intent",
            "targetSite": "edge1",
            "parameters": {}
        }

        This intent will deploy services to edge1.
        """

        result = extract_json(output)
        assert result["intentId"] == "intent_123"
        assert result["targetSite"] == "edge1"

    def test_extract_json_from_markdown(self):
        """Test extracting JSON from markdown blocks"""
        outputs = [
            '```json\n{"intentId": "md1", "targetSite": "edge1"}\n```',
            '```\n{"intentId": "md2", "targetSite": "edge2"}\n```',
            'Here is the JSON:\n```json\n{"intentId": "md3", "targetSite": "both"}\n```\nDone.',
        ]

        for output in outputs:
            result = extract_json(output)
            assert "intentId" in result
            assert result["targetSite"] in ["edge1", "edge2", "both"]

    def test_extract_json_complex(self):
        """Test extracting complex nested JSON"""
        output = """
        {
            "intentId": "complex_001",
            "name": "Complex Intent",
            "description": "A complex test intent",
            "targetSite": "both",
            "parameters": {
                "type": "5G_slice",
                "requirements": {
                    "latency": "5ms",
                    "bandwidth": "10Gbps",
                    "reliability": 0.999
                },
                "configuration": {
                    "feature_flags": ["auto_scaling", "load_balancing"],
                    "regions": ["us-east", "us-west"]
                }
            },
            "priority": "high",
            "lifecycle": "active"
        }
        """

        result = extract_json(output)
        assert result["intentId"] == "complex_001"
        assert result["targetSite"] == "both"
        assert result["parameters"]["requirements"]["latency"] == "5ms"
        assert "auto_scaling" in result["parameters"]["configuration"]["feature_flags"]

    def test_extract_json_failure(self):
        """Test extraction fails gracefully on invalid JSON"""
        invalid_outputs = [
            "This is not JSON",
            "{ broken json",
            '{"key": }',
            "null",
            "undefined",
        ]

        for output in invalid_outputs:
            with pytest.raises(ValueError) as exc:
                extract_json(output)
            assert "No valid JSON found" in str(exc.value)


class TestDeterministicOutput:
    """Test deterministic output for same inputs (Phase 15)"""

    def test_prompt_deterministic(self):
        """Test that same input produces same prompt"""
        nl_request = "Deploy 5G slice at edge1"
        target_site = "edge1"

        prompt1 = PROMPT_TEMPLATE.format(nl_request=nl_request, target_site=target_site)
        prompt2 = PROMPT_TEMPLATE.format(nl_request=nl_request, target_site=target_site)

        assert prompt1 == prompt2

    def test_targetsite_inference_deterministic(self):
        """Test that targetSite inference is deterministic"""
        test_inputs = [
            "Deploy at edge1",
            "Configure edge site 2",
            "Setup both edges",
            "Install network service",
        ]

        for text in test_inputs:
            result1 = determine_target_site(text, None)
            result2 = determine_target_site(text, None)
            assert result1 == result2, f"Non-deterministic for: {text}"

    def test_enforce_targetsite_deterministic(self):
        """Test that enforcement is deterministic"""
        intent_template = {"intentId": "test_123", "name": "Test"}

        # Test multiple times with same input
        for _ in range(5):
            intent = intent_template.copy()
            result = enforce_targetsite(intent, "edge1")
            assert result["targetSite"] == "edge1"
            assert "parameters" in result

    def test_hash_deterministic(self):
        """Test that hash generation is deterministic"""
        import hashlib

        intent = {
            "intentId": "hash_test",
            "name": "Hash Test",
            "targetSite": "edge1",
            "parameters": {"type": "test", "config": {"key": "value"}},
        }

        # Generate hash multiple times
        hashes = []
        for _ in range(5):
            intent_str = json.dumps(intent, sort_keys=True)
            hash_val = hashlib.sha256(intent_str.encode()).hexdigest()
            hashes.append(hash_val)

        # All hashes should be identical
        assert len(set(hashes)) == 1, "Hash not deterministic"

    def test_golden_inputs_deterministic(self):
        """Test that golden inputs produce consistent targetSite"""
        golden_inputs = [
            ("Deploy 5G network slice with ultra-low latency at edge1", "edge1"),
            ("Configure IoT monitoring for edge site 2", "edge2"),
            ("Setup video streaming CDN across both edge sites", "both"),
            ("Deploy network service", "both"),  # Default
        ]

        for nl_text, expected_site in golden_inputs:
            # Test multiple times
            for _ in range(3):
                result = determine_target_site(nl_text, None)
                assert result == expected_site, f"Non-deterministic for: {nl_text}"


class TestPromptEngineering:
    """Test prompt engineering for JSON-only output"""

    def test_prompt_enforces_json_only(self):
        """Test that prompt explicitly requires JSON-only output"""
        assert "Output only JSON" in PROMPT_TEMPLATE
        assert "No text before or after" in PROMPT_TEMPLATE

    def test_prompt_includes_targetsite(self):
        """Test that prompt includes targetSite field"""
        assert '"targetSite": "{target_site}"' in PROMPT_TEMPLATE
        assert "targetSite must be:" in PROMPT_TEMPLATE

    def test_prompt_shows_structure(self):
        """Test that prompt shows complete JSON structure"""
        required_fields = [
            '"intentId"',
            '"name"',
            '"description"',
            '"targetSite"',
            '"parameters"',
            '"priority"',
            '"lifecycle"',
        ]

        for field in required_fields:
            assert field in PROMPT_TEMPLATE, f"Missing {field} in prompt"

    def test_prompt_formatting_edge_cases(self):
        """Test prompt formatting with edge cases"""
        edge_cases = [
            ('Deploy "quoted" service', "edge1"),
            ("Setup service with {braces}", "edge2"),
            ("Configure\nmultiline\nrequest", "both"),
            ("Deploy with special chars: @#$%", "edge1"),
        ]

        for nl_text, target_site in edge_cases:
            # Should not raise exception
            prompt = PROMPT_TEMPLATE.format(nl_request=nl_text, target_site=target_site)
            assert target_site in prompt
            assert nl_text in prompt


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
