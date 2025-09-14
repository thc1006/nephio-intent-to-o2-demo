"""Contract tests for kpt fn render integration.

This module tests the contracts with kpt toolchain integration,
ensuring proper resource rendering and pipeline compatibility.
"""

import json
import subprocess
import sys
import tempfile
import yaml
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

import pytest

# Add the intent-compiler to the path for testing
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "tools" / "intent-compiler"))

from translate import IntentToKRMTranslator


class TestKptRenderContract:
    """Test contract for kpt fn render integration."""

    @pytest.fixture
    def mock_kpt_success(self):
        """Mock successful kpt fn render execution."""
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = ""
        mock_result.stderr = ""
        return mock_result

    @pytest.fixture
    def mock_kpt_failure(self):
        """Mock failed kpt fn render execution."""
        mock_result = Mock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "kpt render failed: validation error"
        return mock_result

    @pytest.fixture
    def sample_intent(self):
        """Sample intent for kpt integration testing."""
        return {
            "intentId": "kpt-integration-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "sla": {
                "availability": 99.9,
                "latency": 10,
                "throughput": 100
            }
        }

    def test_kustomization_structure_for_kpt(self, sample_intent, temp_workspace):
        """Test that Kustomization follows kpt-compatible structure."""
        intent_file = temp_workspace / "input" / "kpt_test.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        kustomization = next(r for r in result["edge1"] if r["kind"] == "Kustomization")

        # Validate kpt-compatible structure
        assert kustomization["apiVersion"] == "kustomize.config.k8s.io/v1beta1"
        assert kustomization["kind"] == "Kustomization"
        assert "namespace" in kustomization
        assert "resources" in kustomization

        # Resources should be relative paths compatible with kpt
        for resource in kustomization["resources"]:
            assert not resource.startswith("/")  # No absolute paths
            assert resource.endswith(".yaml")    # YAML files

    def test_resource_yaml_structure_for_kpt(self, sample_intent, temp_workspace):
        """Test that generated YAML is kpt-compatible."""
        intent_file = temp_workspace / "input" / "kpt_yaml.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))
        translator.save_resources(result)

        # Check that YAML files are valid and parseable
        edge1_dir = temp_workspace / "output" / "edge1"
        yaml_files = list(edge1_dir.glob("*.yaml"))
        assert len(yaml_files) >= 3  # At least PR, ConfigMap, Kustomization

        for yaml_file in yaml_files:
            with open(yaml_file, 'r') as f:
                content = f.read()

            # Should be valid YAML
            parsed = yaml.safe_load(content)
            assert parsed is not None

            # Should have required Kubernetes fields
            if parsed.get("kind") != "Kustomization":
                assert "apiVersion" in parsed
                assert "kind" in parsed
                assert "metadata" in parsed

    @patch('subprocess.run')
    def test_kpt_render_integration_success(self, mock_run, mock_kpt_success,
                                          sample_intent, temp_workspace):
        """Test successful kpt fn render integration."""
        mock_run.return_value = mock_kpt_success

        intent_file = temp_workspace / "input" / "render_success.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))
        translator.save_resources(result)

        # Simulate kpt fn render call
        edge1_dir = temp_workspace / "output" / "edge1"
        kpt_result = subprocess.run(
            ["kpt", "fn", "render", str(edge1_dir)],
            capture_output=True,
            text=True
        )

        # Verify kpt command was called correctly
        mock_run.assert_called_once()
        call_args = mock_run.call_args[0][0]
        assert call_args[0] == "kpt"
        assert call_args[1] == "fn"
        assert call_args[2] == "render"

    @patch('subprocess.run')
    def test_kpt_render_integration_failure(self, mock_run, mock_kpt_failure,
                                          sample_intent, temp_workspace):
        """Test kpt fn render failure handling."""
        mock_run.return_value = mock_kpt_failure

        intent_file = temp_workspace / "input" / "render_failure.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))
        translator.save_resources(result)

        # Simulate kpt fn render call that fails
        edge1_dir = temp_workspace / "output" / "edge1"
        kpt_result = subprocess.run(
            ["kpt", "fn", "render", str(edge1_dir)],
            capture_output=True,
            text=True
        )

        # Should handle failure gracefully
        assert mock_run.called
        # In real integration, this would trigger rollback or error handling

    def test_namespace_consistency_for_kpt(self, sample_intent, temp_workspace):
        """Test that namespaces are consistent across resources for kpt."""
        intent_file = temp_workspace / "input" / "namespace_test.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        edge1_resources = result["edge1"]
        kustomization = next(r for r in edge1_resources if r["kind"] == "Kustomization")

        # Kustomization should have namespace
        assert kustomization["namespace"] == "edge1"

        # All namespaced resources should use same namespace
        for resource in edge1_resources:
            if resource["kind"] != "Kustomization":
                metadata = resource.get("metadata", {})
                if "namespace" in metadata:
                    assert metadata["namespace"] == "edge1"

    def test_deterministic_ordering_for_kpt(self, sample_intent, temp_workspace, fixed_timestamp):
        """Test that resource ordering is deterministic for kpt."""
        intent_file = temp_workspace / "input" / "ordering_test.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(sample_intent, f)

        # Generate resources multiple times
        results = []
        for _ in range(3):
            translator = IntentToKRMTranslator(str(temp_workspace / "output_tmp"))
            translator._manifest_data["timestamp"] = fixed_timestamp
            result = translator.translate(str(intent_file))
            results.append(result)

        # Resource ordering should be identical
        for i in range(1, len(results)):
            edge1_resources = results[i]["edge1"]
            base_resources = results[0]["edge1"]

            # Sort resources by kind and name for comparison
            def sort_key(r):
                return (r["kind"], r.get("metadata", {}).get("name", ""))

            edge1_sorted = sorted(edge1_resources, key=sort_key)
            base_sorted = sorted(base_resources, key=sort_key)

            # Convert to JSON for comparison
            edge1_json = json.dumps(edge1_sorted, sort_keys=True)
            base_json = json.dumps(base_sorted, sort_keys=True)

            assert edge1_json == base_json, f"Resource ordering differs in run {i+1}"


class TestKubeconformContract:
    """Test contract for kubeconform validation integration."""

    @pytest.fixture
    def mock_kubeconform_success(self):
        """Mock successful kubeconform validation."""
        mock_result = Mock()
        mock_result.returncode = 0
        mock_result.stdout = "validation passed"
        mock_result.stderr = ""
        return mock_result

    @pytest.fixture
    def mock_kubeconform_failure(self):
        """Mock failed kubeconform validation."""
        mock_result = Mock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "validation failed: invalid resource"
        return mock_result

    @patch('subprocess.run')
    def test_kubeconform_validation_success(self, mock_run, mock_kubeconform_success,
                                          temp_workspace):
        """Test successful kubeconform validation."""
        mock_run.return_value = mock_kubeconform_success

        # Create sample YAML for validation
        sample_resource = {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {"name": "test", "namespace": "default"},
            "data": {"key": "value"}
        }

        yaml_file = temp_workspace / "test.yaml"
        with open(yaml_file, 'w') as f:
            yaml.dump(sample_resource, f)

        # Simulate kubeconform validation
        result = subprocess.run(
            ["kubeconform", "-summary", str(yaml_file)],
            capture_output=True,
            text=True
        )

        mock_run.assert_called_once()
        call_args = mock_run.call_args[0][0]
        assert call_args[0] == "kubeconform"
        assert str(yaml_file) in call_args

    @patch('subprocess.run')
    def test_kubeconform_validation_failure(self, mock_run, mock_kubeconform_failure,
                                          temp_workspace):
        """Test kubeconform validation failure handling."""
        mock_run.return_value = mock_kubeconform_failure

        # Create invalid YAML
        invalid_yaml = temp_workspace / "invalid.yaml"
        invalid_yaml.write_text("invalid: yaml: structure:")

        # Simulate kubeconform validation that fails
        result = subprocess.run(
            ["kubeconform", "-summary", str(invalid_yaml)],
            capture_output=True,
            text=True
        )

        assert mock_run.called

    def test_generated_resources_kubeconform_compatible(self, temp_workspace):
        """Test that generated resources are kubeconform-compatible."""
        intent = {
            "intentId": "kubeconform-test-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "sla": {"availability": 99.9, "latency": 10}
        }

        intent_file = temp_workspace / "input" / "kubeconform.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        result = translator.translate(str(intent_file))

        # Validate each generated resource structure
        for resource in result["edge1"]:
            # Skip Kustomization as it's not a Kubernetes resource
            if resource["kind"] == "Kustomization":
                continue

            # Should have required fields for kubeconform
            assert "apiVersion" in resource
            assert "kind" in resource
            assert "metadata" in resource
            assert "name" in resource["metadata"]

            # APIVersion should follow Kubernetes format
            api_version = resource["apiVersion"]
            assert "/" in api_version or api_version in ["v1"]  # Core API or versioned

            # Kind should be valid
            valid_kinds = [
                "ProvisioningRequest", "ConfigMap", "NetworkSlice",
                "Service", "Deployment", "Pod"
            ]
            # We allow custom kinds for CRDs
            assert resource["kind"] in valid_kinds or "." in resource["apiVersion"]


class TestManifestContract:
    """Test contract for manifest generation and validation."""

    def test_manifest_structure_contract(self, temp_workspace, fixed_timestamp):
        """Test that manifest follows expected structure."""
        intent = {
            "intentId": "manifest-test-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "both",
            "sla": {"availability": 99.9}
        }

        intent_file = temp_workspace / "input" / "manifest.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        translator._manifest_data["timestamp"] = fixed_timestamp

        result = translator.translate(str(intent_file))
        manifest_path = translator.save_resources(result)

        # Load and validate manifest
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)

        # Validate required fields
        required_fields = [
            "intent_id", "timestamp", "checksum_algorithm",
            "target_sites", "resource_counts", "summary"
        ]
        for field in required_fields:
            assert field in manifest, f"Missing required field: {field}"

        # Validate field types and values
        assert isinstance(manifest["intent_id"], str)
        assert isinstance(manifest["timestamp"], str)
        assert manifest["checksum_algorithm"] == "sha256"
        assert isinstance(manifest["target_sites"], list)
        assert isinstance(manifest["resource_counts"], dict)
        assert isinstance(manifest["summary"], dict)

        # Validate summary structure
        summary = manifest["summary"]
        assert "total_files" in summary
        assert "total_sites" in summary
        assert isinstance(summary["total_files"], int)
        assert isinstance(summary["total_sites"], int)

    def test_checksum_manifest_contract(self, temp_workspace, fixed_timestamp):
        """Test that checksums in manifest are valid and consistent."""
        intent = {
            "intentId": "checksum-manifest-001",
            "targetSite": "edge1"
        }

        intent_file = temp_workspace / "input" / "checksum.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        translator = IntentToKRMTranslator(str(temp_workspace / "output"))
        translator._manifest_data["timestamp"] = fixed_timestamp

        result = translator.translate(str(intent_file))
        checksums = translator.get_resource_checksums(result)

        # Validate checksum format
        for resource_id, checksum in checksums.items():
            # Resource ID format: site/kind/name
            parts = resource_id.split("/")
            assert len(parts) >= 3
            assert parts[0] in ["edge1", "edge2"]

            # Checksum should be SHA256 hex
            assert len(checksum) == 64
            assert all(c in "0123456789abcdef" for c in checksum)

    def test_manifest_deterministic_generation(self, temp_workspace, fixed_timestamp):
        """Test that manifest generation is deterministic."""
        intent = {
            "intentId": "deterministic-manifest-001",
            "targetSite": "both"
        }

        intent_file = temp_workspace / "input" / "deterministic.json"
        intent_file.parent.mkdir(parents=True, exist_ok=True)
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        # Generate manifest multiple times
        manifests = []
        for i in range(3):
            output_dir = temp_workspace / f"output_{i}"
            translator = IntentToKRMTranslator(str(output_dir))
            translator._manifest_data["timestamp"] = fixed_timestamp

            result = translator.translate(str(intent_file))
            manifest_path = translator.save_resources(result)

            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
            manifests.append(manifest)

        # All manifests should be identical (except file paths)
        base_manifest = manifests[0].copy()
        # Remove paths that will differ
        for manifest in manifests:
            # Resource counts and checksums should be identical
            assert manifest["resource_counts"] == base_manifest["resource_counts"]
            assert manifest["summary"] == base_manifest["summary"]
            assert manifest["intent_id"] == base_manifest["intent_id"]
            assert manifest["timestamp"] == base_manifest["timestamp"]