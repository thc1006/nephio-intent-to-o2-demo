import json
import pytest
import glob
import os
from jsonschema import validate

with open("adapter/app/schema.json", "r") as f:
    TMF921_SCHEMA = json.load(f)

class TestGoldenFiles:
    """Test golden file consistency and deterministic outputs"""

    def test_golden_files_exist(self):
        """Test that golden files exist in pairs"""
        input_files = glob.glob("tests/golden/*.in")
        json_files = glob.glob("tests/golden/*.json")

        assert len(input_files) > 0, "No golden input files found"
        assert len(json_files) > 0, "No golden JSON files found"

        for input_file in input_files:
            base_name = input_file.replace(".in", "")
            json_file = base_name + ".json"
            assert os.path.exists(json_file), f"Missing JSON file for {input_file}"

    def test_golden_json_valid(self):
        """Test that all golden JSON files are valid TMF921 intents"""
        json_files = glob.glob("tests/golden/*.json")

        for json_file in json_files:
            with open(json_file, "r") as f:
                intent = json.load(f)

            validate(instance=intent, schema=TMF921_SCHEMA)

            assert "intentId" in intent
            assert "name" in intent
            assert "parameters" in intent
            assert "targetSite" in intent
            assert intent["targetSite"] in ["edge1", "edge2", "both"]

    def test_golden_json_structure_consistency(self):
        """Test that golden JSON files have consistent structure"""
        json_files = glob.glob("tests/golden/*.json")
        required_keys = {"intentId", "name", "parameters", "targetSite"}

        for json_file in json_files:
            with open(json_file, "r") as f:
                intent = json.load(f)

            assert all(key in intent for key in required_keys), \
                f"Missing required keys in {json_file}"

            if "requirements" in intent["parameters"]:
                requirements = intent["parameters"]["requirements"]
                assert isinstance(requirements, dict)

            if "configuration" in intent["parameters"]:
                configuration = intent["parameters"]["configuration"]
                assert isinstance(configuration, dict)

    def test_golden_target_site_mapping(self):
        """Test that target sites map correctly to input descriptions"""
        test_cases = [
            ("deploy_5g_gaming", "edge1"),
            ("iot_monitoring", "both"),
            ("video_streaming", "edge2")
        ]

        for base_name, expected_site in test_cases:
            json_file = f"tests/golden/{base_name}.json"
            assert os.path.exists(json_file), f"Missing file: {json_file}"

            with open(json_file, "r") as f:
                intent = json.load(f)

            assert intent["targetSite"] == expected_site, \
                f"Expected targetSite '{expected_site}' for {base_name}"

    def test_golden_intent_types(self):
        """Test that intent types match the input descriptions"""
        test_cases = [
            ("deploy_5g_gaming", "5G_network_slice"),
            ("iot_monitoring", "iot_infrastructure"),
            ("video_streaming", "video_streaming")
        ]

        for base_name, expected_type in test_cases:
            json_file = f"tests/golden/{base_name}.json"
            with open(json_file, "r") as f:
                intent = json.load(f)

            if "type" in intent["parameters"]:
                assert intent["parameters"]["type"] == expected_type, \
                    f"Expected type '{expected_type}' for {base_name}"

    def test_golden_requirements_present(self):
        """Test that requirements are properly populated"""
        json_files = glob.glob("tests/golden/*.json")

        for json_file in json_files:
            with open(json_file, "r") as f:
                intent = json.load(f)

            if "requirements" in intent["parameters"]:
                requirements = intent["parameters"]["requirements"]
                assert len(requirements) > 0, f"Empty requirements in {json_file}"

                if "gaming" in json_file:
                    assert "latency" in requirements
                elif "iot" in json_file:
                    assert "capacity" in requirements
                elif "video" in json_file:
                    assert "bandwidth" in requirements