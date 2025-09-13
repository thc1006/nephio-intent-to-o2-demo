#!/usr/bin/env python3
"""
Integration tests for targetSite functionality across the LLM adapter stack
"""

import pytest
import sys
import os

# Add the llm-adapter to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../llm-adapter'))

from adapters.llm_client import get_llm_client
from tests.test_intent_schema import validate_intent_json


class TestTargetSiteIntegration:
    """Integration tests for targetSite field functionality"""

    def setup_method(self):
        """Setup test method"""
        self.llm_client = get_llm_client()

    def test_embb_defaults_to_edge1(self):
        """Test that eMBB service defaults to edge1"""
        request = "Deploy enhanced mobile broadband service with 500Mbps"
        intent_dict = self.llm_client.parse_text(request)
        tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

        assert intent_dict["service"] == "eMBB"
        assert intent_dict["targetSite"] == "edge1"
        assert tmf921_intent["targetSite"] == "edge1"
        assert validate_intent_json(tmf921_intent)

    def test_urllc_defaults_to_edge2(self):
        """Test that URLLC service defaults to edge2"""
        request = "Create ultra-reliable low latency communication with 1ms latency"
        intent_dict = self.llm_client.parse_text(request)
        tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

        assert intent_dict["service"] == "URLLC"
        assert intent_dict["targetSite"] == "edge2"
        assert tmf921_intent["targetSite"] == "edge2"
        assert validate_intent_json(tmf921_intent)

    def test_mmtc_defaults_to_both(self):
        """Test that mMTC service defaults to both sites"""
        request = "Setup massive machine type communication for IoT sensors"
        intent_dict = self.llm_client.parse_text(request)
        tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

        assert intent_dict["service"] == "mMTC"
        assert intent_dict["targetSite"] == "both"
        assert tmf921_intent["targetSite"] == "both"
        assert validate_intent_json(tmf921_intent)

    def test_explicit_edge1_override(self):
        """Test explicit edge1 site specification overrides defaults"""
        request = "Deploy URLLC service in edge1 with 5ms latency"
        intent_dict = self.llm_client.parse_text(request)
        tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

        assert intent_dict["service"] == "URLLC"
        assert intent_dict["targetSite"] == "edge1"  # Should override default edge2
        assert tmf921_intent["targetSite"] == "edge1"
        assert validate_intent_json(tmf921_intent)

    def test_explicit_edge2_override(self):
        """Test explicit edge2 site specification overrides defaults"""
        request = "Deploy eMBB service in edge2 with 1Gbps throughput"
        intent_dict = self.llm_client.parse_text(request)
        tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

        assert intent_dict["service"] == "eMBB"
        assert intent_dict["targetSite"] == "edge2"  # Should override default edge1
        assert tmf921_intent["targetSite"] == "edge2"
        assert validate_intent_json(tmf921_intent)

    def test_both_sites_specification(self):
        """Test explicit both sites specification"""
        test_cases = [
            "Deploy service across both edge1 and edge2",
            "Setup network in multiple sites",
            "Create service for both edge nodes"
        ]

        for request in test_cases:
            intent_dict = self.llm_client.parse_text(request)
            tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

            assert intent_dict["targetSite"] == "both"
            assert tmf921_intent["targetSite"] == "both"
            assert validate_intent_json(tmf921_intent)

    def test_tmf921_schema_compliance(self):
        """Test that all generated intents comply with TMF921 schema including targetSite"""
        test_requests = [
            "Deploy eMBB slice for mobile users",
            "Create URLLC service for autonomous vehicles",
            "Setup mMTC network for smart city sensors",
            "Deploy gaming service in edge2",
            "Create IoT network across both sites"
        ]

        for request in test_requests:
            intent_dict = self.llm_client.parse_text(request)
            tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

            # Check basic structure
            assert "targetSite" in tmf921_intent
            assert tmf921_intent["targetSite"] in ["edge1", "edge2", "both"]

            # Check schema compliance
            assert validate_intent_json(tmf921_intent), f"Schema validation failed for: {request}"

            # Check metadata includes targetSite info
            assert "additionalInfo" in tmf921_intent["intentMetadata"]
            assert "targetSite" in tmf921_intent["intentMetadata"]["additionalInfo"]

    def test_backward_compatibility(self):
        """Test that the API maintains backward compatibility"""
        # Even without explicit targetSite handling in requests,
        # the system should assign reasonable defaults
        basic_requests = [
            "Deploy network slice",
            "Create 5G service",
            "Setup network"
        ]

        for request in basic_requests:
            intent_dict = self.llm_client.parse_text(request)
            tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

            # Should have valid targetSite even for basic requests
            assert "targetSite" in intent_dict
            assert intent_dict["targetSite"] in ["edge1", "edge2", "both"]
            assert validate_intent_json(tmf921_intent)

    def test_priority_mapping_with_target_site(self):
        """Test that intent priority is correctly mapped based on service type and targetSite"""
        request = "Deploy URLLC service in edge2 with 1ms latency"
        intent_dict = self.llm_client.parse_text(request)
        tmf921_intent = self.llm_client.convert_to_tmf921(intent_dict, request)

        # URLLC should get high priority
        assert tmf921_intent["intentPriority"] == 9
        assert tmf921_intent["targetSite"] == "edge2"
        assert validate_intent_json(tmf921_intent)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])