"""Contract tests for API boundaries and integration points.

This module tests the contracts between different components of the intent
compilation pipeline, ensuring API compatibility and proper error handling.
"""

import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict
from unittest.mock import Mock, patch

import pytest

# Add the intent-compiler to the path for testing
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "tools" / "intent-compiler"))

from translate import (
    IntentToKRMTranslator,
    IntentTranslationError,
    IntentValidationError,
    ResourceGenerationError,
    FileSystemError
)


class TestIntentValidationContract:
    """Test contract for intent validation."""

    def test_valid_intent_contract(self, temp_workspace):
        """Test that valid intents are accepted according to contract."""
        valid_intent = {
            "intentId": "contract-test-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "sla": {
                "availability": 99.9,
                "latency": 10,
                "throughput": 100
            }
        }

        intent_file = temp_workspace / "input" / "valid_intent.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(valid_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        # Should not raise any validation errors
        result = translator.translate(str(intent_file))
        assert "edge1" in result

    def test_missing_intent_id_contract(self, temp_workspace):
        """Test that missing intentId raises IntentValidationError."""
        invalid_intent = {
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1"
        }

        intent_file = temp_workspace / "input" / "no_id.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(invalid_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        with pytest.raises(IntentValidationError) as exc_info:
            translator.translate(str(intent_file))

        assert "Missing required fields" in str(exc_info.value)
        assert "intentId" in str(exc_info.value)

    def test_invalid_target_site_contract(self, temp_workspace):
        """Test that invalid targetSite raises IntentValidationError."""
        invalid_intent = {
            "intentId": "test-001",
            "targetSite": "invalid-site"
        }

        intent_file = temp_workspace / "input" / "invalid_site.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(invalid_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        with pytest.raises(IntentValidationError) as exc_info:
            translator.translate(str(intent_file))

        assert "Invalid targetSite" in str(exc_info.value)

    def test_malformed_json_contract(self, temp_workspace):
        """Test that malformed JSON raises IntentValidationError."""
        intent_file = temp_workspace / "input" / "malformed.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        intent_file.write_text('{ "intentId": "test", invalid json }')

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        with pytest.raises(IntentValidationError) as exc_info:
            translator.translate(str(intent_file))

        assert "Invalid JSON" in str(exc_info.value)

    def test_nonexistent_file_contract(self, temp_workspace):
        """Test that nonexistent file raises FileSystemError."""
        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        with pytest.raises(FileSystemError) as exc_info:
            translator.translate(str(temp_workspace / "nonexistent.json"))

        assert "Failed to read intent file" in str(exc_info.value)


class TestResourceGenerationContract:
    """Test contract for resource generation."""

    @pytest.fixture
    def basic_intent(self):
        """Basic valid intent for testing."""
        return {
            "intentId": "resource-test-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1"
        }

    def test_provisioning_request_contract(self, basic_intent, temp_workspace):
        """Test ProvisioningRequest generation contract."""
        intent_file = temp_workspace / "input" / "basic.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(basic_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        # Find ProvisioningRequest
        pr = next(r for r in result["edge1"] if r["kind"] == "ProvisioningRequest")

        # Validate contract fields
        assert pr["apiVersion"] == "o2ims.provisioning.oran.org/v1alpha1"
        assert pr["kind"] == "ProvisioningRequest"
        assert "metadata" in pr
        assert "name" in pr["metadata"]
        assert "namespace" in pr["metadata"]
        assert "spec" in pr
        assert "targetCluster" in pr["spec"]

    def test_configmap_contract(self, basic_intent, temp_workspace):
        """Test ConfigMap generation contract."""
        intent_file = temp_workspace / "input" / "basic.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(basic_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        # Find ConfigMap
        cm = next(r for r in result["edge1"] if r["kind"] == "ConfigMap")

        # Validate contract fields
        assert cm["apiVersion"] == "v1"
        assert cm["kind"] == "ConfigMap"
        assert "metadata" in cm
        assert "data" in cm
        assert "intent.json" in cm["data"]
        assert "site" in cm["data"]

        # Validate intent.json is valid JSON
        intent_json = json.loads(cm["data"]["intent.json"])
        assert intent_json["intentId"] == basic_intent["intentId"]

    def test_network_slice_contract_with_sla(self, basic_intent, temp_workspace):
        """Test NetworkSlice generation contract when SLA is present."""
        basic_intent["sla"] = {
            "availability": 99.9,
            "latency": 10,
            "throughput": 100
        }

        intent_file = temp_workspace / "input" / "with_sla.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(basic_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        # Find NetworkSlice
        ns = next(r for r in result["edge1"] if r["kind"] == "NetworkSlice")

        # Validate contract fields
        assert ns["apiVersion"] == "workload.nephio.org/v1alpha1"
        assert ns["kind"] == "NetworkSlice"
        assert "metadata" in ns
        assert "spec" in ns
        assert "sliceType" in ns["spec"]
        assert "plmn" in ns["spec"]
        assert "qos" in ns["spec"]

        # Validate PLMN structure
        plmn = ns["spec"]["plmn"]
        assert "mcc" in plmn
        assert "mnc" in plmn

        # Validate QoS structure
        qos = ns["spec"]["qos"]
        assert "5qi" in qos
        assert "gfbr" in qos

    def test_network_slice_contract_without_sla(self, basic_intent, temp_workspace):
        """Test that NetworkSlice is not generated without SLA."""
        intent_file = temp_workspace / "input" / "no_sla.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(basic_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        # NetworkSlice should not be present
        network_slices = [r for r in result["edge1"] if r["kind"] == "NetworkSlice"]
        assert len(network_slices) == 0

    def test_kustomization_contract(self, basic_intent, temp_workspace):
        """Test Kustomization generation contract."""
        intent_file = temp_workspace / "input" / "basic.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(basic_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        # Find Kustomization
        kust = next(r for r in result["edge1"] if r["kind"] == "Kustomization")

        # Validate contract fields
        assert kust["apiVersion"] == "kustomize.config.k8s.io/v1beta1"
        assert kust["kind"] == "Kustomization"
        assert "namespace" in kust
        assert "resources" in kust

        # Resources should be sorted
        resources = kust["resources"]
        assert resources == sorted(resources)


class TestSLAConversionContract:
    """Test contract for SLA conversion."""

    def test_sla_to_o2ims_conversion_contract(self, temp_workspace):
        """Test SLA to O2IMS format conversion."""
        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        sla = {
            "availability": 99.9,
            "latency": 10,
            "throughput": 100,
            "connections": 1000,
            "reliability": 99.99
        }

        converted = translator._convert_sla(sla)

        # Validate conversion contract
        assert converted["availability"] == "99.9%"
        assert converted["maxLatency"] == "10ms"
        assert converted["minThroughput"] == "100Mbps"
        assert converted["maxConnections"] == "1000"
        assert converted["reliability"] == "99.99%"

    def test_sla_to_qos_conversion_contract(self, temp_workspace):
        """Test SLA to QoS conversion contract."""
        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        test_cases = [
            {"latency": 1, "expected_5qi": 1},    # URLLC
            {"latency": 5, "expected_5qi": 5},    # Low latency
            {"latency": 30, "expected_5qi": 7},   # Voice
            {"latency": 100, "expected_5qi": 9}   # Best effort
        ]

        for case in test_cases:
            sla = {"latency": case["latency"], "throughput": 100}
            qos = translator._convert_sla_to_qos(sla)

            assert qos["5qi"] == case["expected_5qi"]
            assert qos["gfbr"] == "100Mbps"

    def test_sla_conversion_with_missing_fields(self, temp_workspace):
        """Test SLA conversion handles missing fields gracefully."""
        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        # Test with minimal SLA
        sla = {"availability": 99.0}
        converted = translator._convert_sla(sla)

        assert converted["availability"] == "99.0%"
        # Other fields should not be present if not in input
        assert "maxLatency" not in converted
        assert "minThroughput" not in converted


class TestFileSystemContract:
    """Test contract for file system operations."""

    def test_output_directory_creation_contract(self, temp_workspace):
        """Test that output directories are created as needed."""
        output_dir = temp_workspace / "deep" / "nested" / "output"
        translator = IntentToKRMTranslator(str(output_dir))

        intent = {"intentId": "fs-test-001", "targetSite": "edge1"}
        intent_file = temp_workspace / "input" / "fs_test.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        result = translator.translate(str(intent_file))
        manifest_path = translator.save_resources(result)

        # Directories should be created
        assert output_dir.exists()
        assert (output_dir / "edge1").exists()
        assert Path(manifest_path).exists()

    def test_checksum_calculation_contract(self, temp_workspace):
        """Test checksum calculation contract."""
        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        test_content = "test content for checksum"
        checksum = translator._calculate_checksum(test_content)

        # Should be SHA256 hex
        assert len(checksum) == 64
        assert all(c in "0123456789abcdef" for c in checksum)

        # Same content should produce same checksum
        checksum2 = translator._calculate_checksum(test_content)
        assert checksum == checksum2

    def test_resource_filename_contract(self, temp_workspace):
        """Test resource filename generation contract."""
        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        test_cases = [
            {
                "resource": {
                    "kind": "ProvisioningRequest",
                    "metadata": {"name": "test-pr"}
                },
                "expected": "test-pr-provisioning-request.yaml"
            },
            {
                "resource": {
                    "kind": "ConfigMap",
                    "metadata": {"name": "test-cm"}
                },
                "expected": "test-cm-config-map.yaml"
            },
            {
                "resource": {
                    "kind": "NetworkSlice",
                    "metadata": {"name": "test-ns"}
                },
                "expected": "test-ns-network-slice.yaml"
            },
            {
                "resource": {
                    "kind": "Kustomization",
                    "metadata": {"name": "kustomization-edge1"}
                },
                "expected": "kustomization.yaml"
            }
        ]

        for case in test_cases:
            filename = translator._get_resource_filename(case["resource"])
            assert filename == case["expected"]


class TestErrorHandlingContract:
    """Test contract for error handling."""

    def test_custom_exception_hierarchy(self):
        """Test that custom exceptions follow correct hierarchy."""
        # All custom exceptions should inherit from IntentTranslationError
        assert issubclass(IntentValidationError, IntentTranslationError)
        assert issubclass(ResourceGenerationError, IntentTranslationError)
        assert issubclass(FileSystemError, IntentTranslationError)

        # Should be instances of base Exception
        assert issubclass(IntentTranslationError, Exception)

    def test_validation_error_details(self, temp_workspace):
        """Test that validation errors include helpful details."""
        invalid_intent = {"serviceType": "enhanced-mobile-broadband"}
        intent_file = temp_workspace / "input" / "validation_error.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(invalid_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        with pytest.raises(IntentValidationError) as exc_info:
            translator.translate(str(intent_file))

        error_message = str(exc_info.value)
        # Should include which fields are missing
        assert "intentId" in error_message
        assert "Missing required fields" in error_message

    @patch('builtins.open')
    def test_filesystem_error_handling(self, mock_open, temp_workspace):
        """Test that filesystem errors are properly handled."""
        mock_open.side_effect = PermissionError("Permission denied")

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))

        with pytest.raises(FileSystemError) as exc_info:
            translator.translate("some_file.json")

        assert "Failed to read intent file" in str(exc_info.value)