#!/usr/bin/env python3
"""Unit tests for TMF921 Intent to KRM Translator.

Comprehensive test suite covering:
- Intent validation and error handling
- Resource generation and deterministic output
- Manifest generation and checksums
- Idempotency and file operations
- Edge cases and error conditions
"""

import hashlib
import json
import logging
import os
import tempfile
import yaml
from pathlib import Path
from unittest.mock import Mock, patch
from typing import Any, Dict

import pytest

from translate import (
    IntentToKRMTranslator,
    IntentTranslationError,
    IntentValidationError,
    ResourceGenerationError,
    FileSystemError
)


class TestIntentToKRMTranslator:
    """Test cases for IntentToKRMTranslator class."""

    @pytest.fixture
    def temp_dir(self):
        """Create temporary directory for test outputs."""
        with tempfile.TemporaryDirectory() as tmpdir:
            yield Path(tmpdir)

    @pytest.fixture
    def sample_intent(self):
        """Sample valid intent for testing."""
        return {
            "intentId": "test-intent-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
            "sla": {
                "availability": 99.9,
                "latency": 10,
                "throughput": 100,
                "connections": 1000
            }
        }

    @pytest.fixture
    def intent_file(self, sample_intent, temp_dir):
        """Create temporary intent file."""
        intent_file = temp_dir / "intent.json"
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)
        return str(intent_file)

    @pytest.fixture
    def translator(self, temp_dir):
        """Create translator instance with temp directory."""
        return IntentToKRMTranslator(str(temp_dir / "output"))

    def test_initialization(self, temp_dir):
        """Test translator initialization."""
        translator = IntentToKRMTranslator(str(temp_dir / "output"))

        assert translator.output_dir == temp_dir / "output"
        assert translator.enable_caching is True
        assert isinstance(translator.logger, logging.Logger)
        assert translator._manifest_data["checksum_algorithm"] == "sha256"
        assert "timestamp" in translator._manifest_data

    def test_initialization_with_caching_disabled(self, temp_dir):
        """Test translator initialization with caching disabled."""
        translator = IntentToKRMTranslator(
            str(temp_dir / "output"),
            enable_caching=False
        )

        assert translator.enable_caching is False

    def test_load_and_validate_intent_valid(self, translator, intent_file):
        """Test loading and validating a valid intent."""
        intent = translator._load_and_validate_intent(intent_file)

        assert intent["intentId"] == "test-intent-001"
        assert intent["serviceType"] == "enhanced-mobile-broadband"
        assert intent["targetSite"] == "edge1"

    def test_load_and_validate_intent_missing_file(self, translator):
        """Test loading non-existent intent file."""
        with pytest.raises(FileSystemError, match="Failed to read intent file"):
            translator.translate("nonexistent.json")

    def test_load_and_validate_intent_invalid_json(self, translator, temp_dir):
        """Test loading invalid JSON file."""
        invalid_file = temp_dir / "invalid.json"
        invalid_file.write_text("{ invalid json")

        with pytest.raises(IntentValidationError, match="Invalid JSON in intent file"):
            translator.translate(str(invalid_file))

    def test_load_and_validate_intent_missing_required_field(self, translator, temp_dir):
        """Test intent missing required fields."""
        invalid_intent = {"serviceType": "enhanced-mobile-broadband"}
        invalid_file = temp_dir / "invalid_intent.json"

        with open(invalid_file, 'w') as f:
            json.dump(invalid_intent, f)

        with pytest.raises(IntentValidationError, match="Missing required fields"):
            translator._load_and_validate_intent(str(invalid_file))

    def test_load_and_validate_intent_invalid_target_site(self, translator, temp_dir):
        """Test intent with invalid target site."""
        invalid_intent = {
            "intentId": "test-001",
            "targetSite": "invalid-site"
        }
        invalid_file = temp_dir / "invalid_site.json"

        with open(invalid_file, 'w') as f:
            json.dump(invalid_intent, f)

        with pytest.raises(IntentValidationError, match="Invalid targetSite"):
            translator._load_and_validate_intent(str(invalid_file))

    def test_get_target_sites_both(self, translator, sample_intent):
        """Test target site resolution for 'both'."""
        sample_intent["targetSite"] = "both"
        sites = translator._get_target_sites(sample_intent)

        assert sorted(sites) == ["edge1", "edge2"]

    def test_get_target_sites_single(self, translator, sample_intent):
        """Test target site resolution for single site."""
        sample_intent["targetSite"] = "edge1"
        sites = translator._get_target_sites(sample_intent)

        assert sites == ["edge1"]

    def test_sort_resource_keys_dict(self, translator):
        """Test recursive key sorting for dictionaries."""
        unsorted = {
            "z": "last",
            "a": {"c": "value", "b": "another"},
            "m": "middle"
        }

        sorted_dict = translator._sort_resource_keys(unsorted)

        # Check top-level keys are sorted
        assert list(sorted_dict.keys()) == ["a", "m", "z"]
        # Check nested keys are sorted
        assert list(sorted_dict["a"].keys()) == ["b", "c"]

    def test_sort_resource_keys_list(self, translator):
        """Test key sorting with lists."""
        data = [
            {"z": "last", "a": "first"},
            {"b": "second", "x": "value"}
        ]

        sorted_data = translator._sort_resource_keys(data)

        assert list(sorted_data[0].keys()) == ["a", "z"]
        assert list(sorted_data[1].keys()) == ["b", "x"]

    def test_create_provisioning_request(self, translator, sample_intent):
        """Test ProvisioningRequest generation."""
        pr = translator._create_provisioning_request(sample_intent, "edge1")

        assert pr["apiVersion"] == "o2ims.provisioning.oran.org/v1alpha1"
        assert pr["kind"] == "ProvisioningRequest"
        assert pr["metadata"]["name"] == "test-intent-001-edge1"
        assert pr["metadata"]["namespace"] == "edge1"
        assert pr["spec"]["targetCluster"] == "edge-cluster-01"
        assert "slaRequirements" in pr["spec"]

        # Check deterministic key ordering in metadata
        metadata_keys = list(pr["metadata"].keys())
        assert metadata_keys == sorted(metadata_keys)

    def test_create_intent_configmap(self, translator, sample_intent):
        """Test ConfigMap generation."""
        cm = translator._create_intent_configmap(sample_intent, "edge1")

        assert cm["apiVersion"] == "v1"
        assert cm["kind"] == "ConfigMap"
        assert cm["metadata"]["name"] == "intent-test-intent-001-edge1"
        assert cm["data"]["site"] == "edge1"

        # Check that intent JSON is sorted
        intent_json = json.loads(cm["data"]["intent.json"])
        expected_json = json.dumps(sample_intent, indent=2, sort_keys=True)
        assert cm["data"]["intent.json"] == expected_json

    def test_create_network_slice(self, translator, sample_intent):
        """Test NetworkSlice generation."""
        ns = translator._create_network_slice(sample_intent, "edge1")

        assert ns["apiVersion"] == "workload.nephio.org/v1alpha1"
        assert ns["kind"] == "NetworkSlice"
        assert ns["metadata"]["name"] == "slice-test-intent-001-edge1"
        assert ns["spec"]["sliceType"] == "eMBB"
        assert "qos" in ns["spec"]

        # Check PLMN parsing
        assert ns["spec"]["plmn"]["mcc"] == "001"
        assert ns["spec"]["plmn"]["mnc"] == "01"

    def test_create_kustomization(self, translator, sample_intent):
        """Test Kustomization generation."""
        kustomization = translator._create_kustomization(sample_intent, "edge1")

        assert kustomization["apiVersion"] == "kustomize.config.k8s.io/v1beta1"
        assert kustomization["kind"] == "Kustomization"
        assert kustomization["namespace"] == "edge1"

        # Check resources are sorted
        resources = kustomization["resources"]
        assert resources == sorted(resources)

    def test_convert_sla(self, translator):
        """Test SLA conversion to O2IMS format."""
        sla = {
            "availability": 99.9,
            "latency": 10,
            "throughput": 100,
            "connections": 1000
        }

        converted = translator._convert_sla(sla)

        assert converted["availability"] == "99.9%"
        assert converted["maxLatency"] == "10ms"
        assert converted["minThroughput"] == "100Mbps"
        assert converted["maxConnections"] == "1000"

    def test_convert_sla_to_qos(self, translator):
        """Test SLA to QoS parameter conversion."""
        # Test URLLC (ultra-low latency)
        sla_urllc = {"latency": 1, "throughput": 50}
        qos = translator._convert_sla_to_qos(sla_urllc)
        assert qos["5qi"] == 1
        assert qos["gfbr"] == "50Mbps"

        # Test low latency
        sla_low = {"latency": 5}
        qos = translator._convert_sla_to_qos(sla_low)
        assert qos["5qi"] == 5

        # Test voice
        sla_voice = {"latency": 30}
        qos = translator._convert_sla_to_qos(sla_voice)
        assert qos["5qi"] == 7

        # Test best effort
        sla_best = {"latency": 100}
        qos = translator._convert_sla_to_qos(sla_best)
        assert qos["5qi"] == 9

    def test_get_resource_filename(self, translator):
        """Test resource filename generation."""
        # Test ProvisioningRequest
        pr = {"kind": "ProvisioningRequest", "metadata": {"name": "test-edge1"}}
        assert translator._get_resource_filename(pr) == "test-edge1-provisioning-request.yaml"

        # Test Kustomization
        kustomization = {"kind": "Kustomization", "metadata": {"name": "kustomization-edge1"}}
        assert translator._get_resource_filename(kustomization) == "kustomization.yaml"

        # Test unknown kind
        unknown = {"kind": "Unknown", "metadata": {"name": "test"}}
        assert translator._get_resource_filename(unknown) == "test-unknown.yaml"

    def test_calculate_checksum(self, translator):
        """Test SHA256 checksum calculation."""
        content = "test content"
        expected = hashlib.sha256(content.encode('utf-8')).hexdigest()

        assert translator._calculate_checksum(content) == expected

    def test_translate_success(self, translator, intent_file):
        """Test successful translation."""
        results = translator.translate(intent_file)

        assert "edge1" in results
        assert len(results["edge1"]) == 4  # PR, ConfigMap, NetworkSlice, Kustomization

        # Check manifest data was updated
        assert translator._manifest_data["intent_id"] == "test-intent-001"
        assert translator._manifest_data["target_sites"] == ["edge1"]
        assert translator._manifest_data["resource_counts"]["edge1"] == 4

    def test_translate_both_sites(self, translator, sample_intent, temp_dir):
        """Test translation for both sites."""
        sample_intent["targetSite"] = "both"
        intent_file = temp_dir / "both_intent.json"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        results = translator.translate(str(intent_file))

        assert "edge1" in results
        assert "edge2" in results
        assert len(results["edge1"]) == 4
        assert len(results["edge2"]) == 4

    def test_save_resources(self, translator, sample_intent, temp_dir):
        """Test resource saving with manifest generation."""
        sample_intent["targetSite"] = "edge1"
        intent_file = temp_dir / "save_intent.json"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        results = translator.translate(str(intent_file))
        manifest_path = translator.save_resources(results)

        # Check files were created
        edge1_dir = translator.output_dir / "edge1"
        assert edge1_dir.exists()
        assert (edge1_dir / "kustomization.yaml").exists()

        # Check manifest was created
        manifest_file = Path(manifest_path)
        assert manifest_file.exists()

        with open(manifest_file, 'r') as f:
            manifest = json.load(f)

        assert manifest["intent_id"] == "test-intent-001"
        assert manifest["summary"]["total_files"] > 0
        assert manifest["summary"]["total_sites"] == 1

    def test_save_resources_idempotency(self, translator, sample_intent, temp_dir):
        """Test that unchanged files are not rewritten."""
        sample_intent["targetSite"] = "edge1"
        intent_file = temp_dir / "idempotent_intent.json"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        results = translator.translate(str(intent_file))

        # First save
        translator.save_resources(results)
        edge1_dir = translator.output_dir / "edge1"
        kustomization_file = edge1_dir / "kustomization.yaml"

        # Record modification time
        first_mtime = kustomization_file.stat().st_mtime

        # Second save (should skip unchanged files)
        translator.save_resources(results)
        second_mtime = kustomization_file.stat().st_mtime

        # File should not be modified (same mtime)
        assert first_mtime == second_mtime

    def test_get_resource_checksums(self, translator, sample_intent, temp_dir):
        """Test checksum calculation without saving files."""
        intent_file = temp_dir / "checksum_intent.json"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        results = translator.translate(str(intent_file))
        checksums = translator.get_resource_checksums(results)

        assert len(checksums) == 4  # 4 resources for edge1

        # Check checksum format
        for resource_id, checksum in checksums.items():
            assert "/" in resource_id  # Should be in format "site/kind/name"
            assert len(checksum) == 64  # SHA256 hex length

    def test_deterministic_output(self, sample_intent, temp_dir):
        """Test that identical inputs produce identical outputs."""
        intent_file = temp_dir / "deterministic_intent.json"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        # Create translators with fixed timestamp for deterministic output
        fixed_timestamp = "2024-01-01T00:00:00+00:00"

        translator1 = IntentToKRMTranslator(str(temp_dir / "output1"))
        translator1._manifest_data["timestamp"] = fixed_timestamp

        translator2 = IntentToKRMTranslator(str(temp_dir / "output2"))
        translator2._manifest_data["timestamp"] = fixed_timestamp

        # Generate resources with both translators
        results1 = translator1.translate(str(intent_file))
        checksums1 = translator1.get_resource_checksums(results1)

        results2 = translator2.translate(str(intent_file))
        checksums2 = translator2.get_resource_checksums(results2)

        # Checksums should be identical
        assert checksums1 == checksums2

    def test_unknown_service_type_warning(self, translator, sample_intent, temp_dir):
        """Test handling of unknown service types."""
        sample_intent["serviceType"] = "unknown-service-type"
        intent_file = temp_dir / "unknown_service.json"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        with patch.object(translator.logger, 'warning') as mock_warning:
            results = translator.translate(str(intent_file))
            mock_warning.assert_called_once()

        # Should still generate resources using default mapping
        assert len(results["edge1"]) == 4

    def test_unknown_site_error(self, translator, sample_intent, temp_dir):
        """Test error handling for unknown sites."""
        # Set invalid site in intent (this should be caught during validation)
        intent_file = temp_dir / "bad_site.json"
        sample_intent["targetSite"] = "invalid-site"

        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        # Should raise validation error, not generation error
        with pytest.raises(IntentValidationError, match="Invalid targetSite"):
            translator.translate(str(intent_file))


class TestIntentTranslationErrors:
    """Test custom exception classes."""

    def test_intent_translation_error(self):
        """Test base exception class."""
        error = IntentTranslationError("Base error")
        assert str(error) == "Base error"
        assert isinstance(error, Exception)

    def test_intent_validation_error(self):
        """Test validation error inheritance."""
        error = IntentValidationError("Validation failed")
        assert isinstance(error, IntentTranslationError)

    def test_resource_generation_error(self):
        """Test resource generation error inheritance."""
        error = ResourceGenerationError("Generation failed")
        assert isinstance(error, IntentTranslationError)

    def test_filesystem_error(self):
        """Test filesystem error inheritance."""
        error = FileSystemError("File operation failed")
        assert isinstance(error, IntentTranslationError)


class TestEdgeCases:
    """Test edge cases and boundary conditions."""

    @pytest.fixture
    def translator(self, tmp_path):
        """Create translator with temporary directory."""
        return IntentToKRMTranslator(str(tmp_path / "output"))

    def test_intent_without_sla(self, translator, tmp_path):
        """Test intent without SLA requirements."""
        intent = {
            "intentId": "no-sla-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1"
        }

        intent_file = tmp_path / "no_sla.json"
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        results = translator.translate(str(intent_file))

        # Should generate 3 resources (no NetworkSlice without SLA)
        assert len(results["edge1"]) == 3

        # Check kustomization doesn't reference NetworkSlice
        kustomization = next(r for r in results["edge1"] if r["kind"] == "Kustomization")
        networkslice_ref = any("networkslice" in resource for resource in kustomization["resources"])
        assert not networkslice_ref

    def test_minimal_intent(self, translator, tmp_path):
        """Test minimal valid intent."""
        intent = {"intentId": "minimal-001"}

        intent_file = tmp_path / "minimal.json"
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        results = translator.translate(str(intent_file))

        # Should use defaults and generate resources for both sites
        assert "edge1" in results
        assert "edge2" in results

    def test_empty_output_directory_creation(self, tmp_path):
        """Test that output directory is created if it doesn't exist."""
        nonexistent_dir = tmp_path / "deeply" / "nested" / "path"
        translator = IntentToKRMTranslator(str(nonexistent_dir))

        intent = {"intentId": "create-dir-001", "targetSite": "edge1"}
        intent_file = tmp_path / "create_dir.json"

        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        results = translator.translate(str(intent_file))
        translator.save_resources(results)

        # Directory should be created
        assert nonexistent_dir.exists()
        assert (nonexistent_dir / "edge1").exists()

    def test_special_characters_in_intent_id(self, translator, tmp_path):
        """Test handling of special characters in intent IDs."""
        intent = {
            "intentId": "test-intent_001.v2",
            "targetSite": "edge1"
        }

        intent_file = tmp_path / "special_chars.json"
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        results = translator.translate(str(intent_file))

        # Should handle special characters without errors
        pr = next(r for r in results["edge1"] if r["kind"] == "ProvisioningRequest")
        assert pr["metadata"]["name"] == "test-intent_001.v2-edge1"

    def test_unicode_content(self, translator, tmp_path):
        """Test handling of Unicode content in intents."""
        intent = {
            "intentId": "unicode-テスト-001",
            "description": "Intent with Unicode: 中文, العربية, русский",
            "targetSite": "edge1"
        }

        intent_file = tmp_path / "unicode.json"
        with open(intent_file, 'w', encoding='utf-8') as f:
            json.dump(intent, f, ensure_ascii=False)

        results = translator.translate(str(intent_file))
        translator.save_resources(results)

        # Should handle Unicode without errors
        assert len(results["edge1"]) == 3


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v"])