#!/usr/bin/env python3
"""
Unit tests for TMF921 adapter with JSON schema validation and golden test cases
"""

import json
import pytest
import sys
import os
from pathlib import Path
from jsonschema import validate, ValidationError
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.main import (
    infer_service_and_qos,
    determine_target_site,
    enforce_tmf921_structure,
    extract_json
)

# Load TMF921 schema
SCHEMA_PATH = Path(__file__).parent.parent / "app" / "schema.json"
with open(SCHEMA_PATH, "r") as f:
    TMF921_SCHEMA = json.load(f)


class TestServiceInference:
    """Test service type and QoS inference from natural language"""

    def test_embb_service_detection(self):
        """Test eMBB service type detection"""
        test_cases = [
            "Deploy high-speed video streaming service",
            "Setup 4K gaming platform with broadband",
            "Configure eMBB slice for entertainment"
        ]

        for text in test_cases:
            service_type, sst, qos = infer_service_and_qos(text)
            assert service_type == "eMBB"
            assert sst == 1

    def test_urllc_service_detection(self):
        """Test URLLC service type detection"""
        test_cases = [
            "Deploy ultra-low latency service for robotics",
            "Setup critical real-time communication",
            "Configure URLLC slice for autonomous vehicles"
        ]

        for text in test_cases:
            service_type, sst, qos = infer_service_and_qos(text)
            assert service_type == "URLLC"
            assert sst == 2

    def test_mmtc_service_detection(self):
        """Test mMTC service type detection"""
        test_cases = [
            "Deploy IoT sensor network",
            "Setup massive machine type communication",
            "Configure mMTC slice for smart city monitoring"
        ]

        for text in test_cases:
            service_type, sst, qos = infer_service_and_qos(text)
            assert service_type == "mMTC"
            assert sst == 3

    def test_qos_extraction(self):
        """Test QoS parameter extraction from text"""
        text = "Deploy service with 100 Mbps download, 50 Mbps upload, 10ms latency"
        service_type, sst, qos = infer_service_and_qos(text)

        assert qos.get('dl_mbps') == 100
        assert qos.get('ul_mbps') == 50
        assert qos.get('latency_ms') == 10

    def test_gbps_conversion(self):
        """Test Gbps to Mbps conversion"""
        text = "Deploy 5 Gbps broadband service"
        service_type, sst, qos = infer_service_and_qos(text)

        assert qos.get('dl_mbps') == 5000


class TestTargetSiteDetection:
    """Test target site determination logic"""

    def test_edge1_detection(self):
        """Test edge1 site detection"""
        test_cases = [
            "Deploy at edge1",
            "Setup service on edge 1",
            "Configure first edge site"
        ]

        for text in test_cases:
            site = determine_target_site(text, None)
            assert site == "edge1"

    def test_edge2_detection(self):
        """Test edge2 site detection"""
        test_cases = [
            "Deploy at edge2",
            "Setup service on edge 2",
            "Configure second edge site"
        ]

        for text in test_cases:
            site = determine_target_site(text, None)
            assert site == "edge2"

    def test_both_sites_detection(self):
        """Test both sites detection"""
        test_cases = [
            "Deploy across both edge sites",
            "Setup service on all edges",
            "Configure multiple edge sites"
        ]

        for text in test_cases:
            site = determine_target_site(text, None)
            assert site == "both"

    def test_override_priority(self):
        """Test that override takes priority"""
        site = determine_target_site("Deploy at edge1", "edge2")
        assert site == "edge2"


class TestTMF921Structure:
    """Test TMF921 structure enforcement and validation"""

    def test_minimal_intent_completion(self):
        """Test that minimal intent is completed with required fields"""
        minimal_intent = {}
        nl_text = "Deploy 5G service"

        result = enforce_tmf921_structure(minimal_intent, "edge1", nl_text)

        # Check required fields exist
        assert "intentId" in result
        assert "name" in result
        assert "service" in result
        assert "targetSite" in result
        assert "qos" in result
        assert "slice" in result
        assert "priority" in result
        assert "lifecycle" in result
        assert "metadata" in result

        # Validate against schema
        validate(instance=result, schema=TMF921_SCHEMA)

    def test_service_structure_enforcement(self):
        """Test service structure is properly enforced"""
        intent = {"service": "invalid"}
        nl_text = "Deploy eMBB service"

        result = enforce_tmf921_structure(intent, "edge1", nl_text)

        assert isinstance(result["service"], dict)
        assert "name" in result["service"]
        assert "type" in result["service"]
        assert result["service"]["type"] == "eMBB"

    def test_metadata_generation(self):
        """Test metadata is properly generated"""
        intent = {}
        nl_text = "Deploy service"

        result = enforce_tmf921_structure(intent, "edge1", nl_text)

        assert "metadata" in result
        assert "createdAt" in result["metadata"]
        assert "version" in result["metadata"]
        assert result["metadata"]["version"] == "1.0.0"


class TestJSONExtraction:
    """Test JSON extraction from LLM output"""

    def test_clean_json_extraction(self):
        """Test extraction of clean JSON"""
        output = '{"test": "value"}'
        result = extract_json(output)
        assert result == {"test": "value"}

    def test_markdown_wrapped_json(self):
        """Test extraction from markdown code blocks"""
        output = '```json\n{"test": "value"}\n```'
        result = extract_json(output)
        assert result == {"test": "value"}

    def test_json_with_text(self):
        """Test extraction when JSON is mixed with text"""
        output = 'Here is the result:\n{"test": "value"}\nEnd of output'
        result = extract_json(output)
        assert result == {"test": "value"}

    def test_invalid_json_raises_error(self):
        """Test that invalid JSON raises ValueError"""
        output = 'This is not JSON at all'
        with pytest.raises(ValueError):
            extract_json(output)


class TestGoldenCases:
    """Golden test cases for complete intent generation"""

    def get_golden_cases(self):
        """Return golden test cases"""
        return [
            {
                "input": {
                    "nl_text": "Deploy 5G eMBB service with 1Gbps download and 500Mbps upload at edge1 for video streaming",
                    "target_site": "edge1"
                },
                "expected": {
                    "service": {"type": "eMBB"},
                    "targetSite": "edge1",
                    "qos": {
                        "dl_mbps": 1000,
                        "ul_mbps": 500
                    },
                    "slice": {"sst": 1}
                }
            },
            {
                "input": {
                    "nl_text": "Setup ultra-low latency URLLC slice with 5ms latency for autonomous vehicles at edge2",
                    "target_site": "edge2"
                },
                "expected": {
                    "service": {"type": "URLLC"},
                    "targetSite": "edge2",
                    "qos": {
                        "latency_ms": 5
                    },
                    "slice": {"sst": 2}
                }
            },
            {
                "input": {
                    "nl_text": "Configure IoT monitoring network for smart city sensors across both edge sites",
                    "target_site": "both"
                },
                "expected": {
                    "service": {"type": "mMTC"},
                    "targetSite": "both",
                    "slice": {"sst": 3}
                }
            }
        ]

    def test_golden_case_1_embb(self):
        """Test golden case 1: eMBB service"""
        case = self.get_golden_cases()[0]

        # Infer service and QoS
        service_type, sst, qos = infer_service_and_qos(case["input"]["nl_text"])

        # Check service type
        assert service_type == case["expected"]["service"]["type"]
        assert sst == case["expected"]["slice"]["sst"]

        # Check QoS values
        assert qos.get("dl_mbps") == case["expected"]["qos"]["dl_mbps"]
        assert qos.get("ul_mbps") == case["expected"]["qos"]["ul_mbps"]

        # Build complete intent
        intent = enforce_tmf921_structure({}, case["input"]["target_site"], case["input"]["nl_text"])

        # Validate structure
        assert intent["targetSite"] == case["expected"]["targetSite"]
        assert intent["service"]["type"] == case["expected"]["service"]["type"]
        assert intent["slice"]["sst"] == case["expected"]["slice"]["sst"]

        # Validate against schema
        validate(instance=intent, schema=TMF921_SCHEMA)

    def test_golden_case_2_urllc(self):
        """Test golden case 2: URLLC service"""
        case = self.get_golden_cases()[1]

        # Infer service and QoS
        service_type, sst, qos = infer_service_and_qos(case["input"]["nl_text"])

        # Check service type
        assert service_type == case["expected"]["service"]["type"]
        assert sst == case["expected"]["slice"]["sst"]

        # Check QoS values
        assert qos.get("latency_ms") == case["expected"]["qos"]["latency_ms"]

        # Build complete intent
        intent = enforce_tmf921_structure({}, case["input"]["target_site"], case["input"]["nl_text"])

        # Validate structure
        assert intent["targetSite"] == case["expected"]["targetSite"]
        assert intent["service"]["type"] == case["expected"]["service"]["type"]
        assert intent["slice"]["sst"] == case["expected"]["slice"]["sst"]

        # Validate against schema
        validate(instance=intent, schema=TMF921_SCHEMA)

    def test_golden_case_3_mmtc(self):
        """Test golden case 3: mMTC service"""
        case = self.get_golden_cases()[2]

        # Determine target site
        site = determine_target_site(case["input"]["nl_text"], None)
        assert site == case["expected"]["targetSite"]

        # Infer service and QoS
        service_type, sst, qos = infer_service_and_qos(case["input"]["nl_text"])

        # Check service type
        assert service_type == case["expected"]["service"]["type"]
        assert sst == case["expected"]["slice"]["sst"]

        # Build complete intent
        intent = enforce_tmf921_structure({}, case["input"]["target_site"], case["input"]["nl_text"])

        # Validate structure
        assert intent["targetSite"] == case["expected"]["targetSite"]
        assert intent["service"]["type"] == case["expected"]["service"]["type"]
        assert intent["slice"]["sst"] == case["expected"]["slice"]["sst"]

        # Validate against schema
        validate(instance=intent, schema=TMF921_SCHEMA)


class TestSchemaCompliance:
    """Test compliance with TMF921 schema"""

    def test_valid_intent_passes_validation(self):
        """Test that a valid intent passes schema validation"""
        valid_intent = {
            "intentId": "intent_123456",
            "name": "Test Intent",
            "service": {
                "name": "Test Service",
                "type": "eMBB"
            },
            "targetSite": "edge1",
            "qos": {
                "dl_mbps": 100,
                "ul_mbps": 50,
                "latency_ms": 20
            },
            "slice": {
                "sst": 1
            },
            "priority": "medium",
            "lifecycle": "draft"
        }

        # Should not raise
        validate(instance=valid_intent, schema=TMF921_SCHEMA)

    def test_missing_required_field_fails(self):
        """Test that missing required fields fail validation"""
        invalid_intent = {
            "intentId": "intent_123456",
            "name": "Test Intent",
            # Missing "service" and "targetSite"
        }

        with pytest.raises(ValidationError):
            validate(instance=invalid_intent, schema=TMF921_SCHEMA)

    def test_invalid_targetsite_fails(self):
        """Test that invalid targetSite value fails validation"""
        invalid_intent = {
            "intentId": "intent_123456",
            "name": "Test Intent",
            "service": {
                "name": "Test Service",
                "type": "eMBB"
            },
            "targetSite": "invalid_site",  # Invalid value
        }

        with pytest.raises(ValidationError):
            validate(instance=invalid_intent, schema=TMF921_SCHEMA)

    def test_invalid_service_type_fails(self):
        """Test that invalid service type fails validation"""
        invalid_intent = {
            "intentId": "intent_123456",
            "name": "Test Intent",
            "service": {
                "name": "Test Service",
                "type": "invalid_type"  # Invalid service type
            },
            "targetSite": "edge1"
        }

        with pytest.raises(ValidationError):
            validate(instance=invalid_intent, schema=TMF921_SCHEMA)

    def test_qos_boundary_values(self):
        """Test QoS boundary values"""
        intent = {
            "intentId": "intent_123456",
            "name": "Test Intent",
            "service": {
                "name": "Test Service",
                "type": "eMBB"
            },
            "targetSite": "edge1",
            "qos": {
                "dl_mbps": 10000,  # Max value
                "ul_mbps": 0,      # Min value
                "latency_ms": 1000,  # Max value
                "packet_loss_rate": 1  # Max value
            }
        }

        # Should pass validation
        validate(instance=intent, schema=TMF921_SCHEMA)

    def test_slice_sst_range(self):
        """Test SST value range (0-255)"""
        intent_base = {
            "intentId": "intent_123456",
            "name": "Test Intent",
            "service": {
                "name": "Test Service",
                "type": "eMBB"
            },
            "targetSite": "edge1"
        }

        # Valid SST values
        for sst in [0, 1, 128, 255]:
            intent = intent_base.copy()
            intent["slice"] = {"sst": sst}
            validate(instance=intent, schema=TMF921_SCHEMA)

        # Invalid SST values
        for sst in [-1, 256, 1000]:
            intent = intent_base.copy()
            intent["slice"] = {"sst": sst}
            with pytest.raises(ValidationError):
                validate(instance=intent, schema=TMF921_SCHEMA)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])