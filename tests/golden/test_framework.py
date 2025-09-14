"""Golden test framework for intent compilation pipeline.

This module provides the core infrastructure for golden testing the intent-to-KRM
translation pipeline, ensuring deterministic and consistent output generation.
"""

import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from unittest.mock import patch

import pytest
import yaml

# Add the intent-compiler to the path for testing
sys.path.insert(
    0, str(Path(__file__).parent.parent.parent / "tools" / "intent-compiler")
)

from translate import IntentToKRMTranslator


class GoldenTestFramework:
    """Framework for golden testing intent compilation pipeline."""

    def __init__(self, test_data_dir: Path):
        """Initialize the golden test framework.

        Args:
            test_data_dir: Path to test data directory containing fixtures
        """
        self.test_data_dir = test_data_dir
        self.intent_fixtures = test_data_dir / "intents"
        self.expected_outputs = test_data_dir / "expected"

    def load_intent(self, intent_name: str) -> Dict[str, Any]:
        """Load an intent fixture by name.

        Args:
            intent_name: Name of the intent file (without .json extension)

        Returns:
            Loaded intent data

        Raises:
            FileNotFoundError: If intent fixture doesn't exist
        """
        intent_file = self.intent_fixtures / f"{intent_name}.json"
        if not intent_file.exists():
            raise FileNotFoundError(f"Intent fixture not found: {intent_file}")

        with open(intent_file, "r") as f:
            return json.load(f)

    def save_golden_output(
        self,
        intent_name: str,
        output: Dict[str, List[Dict]],
        checksums: Dict[str, str],
        manifest_data: Dict[str, Any],
    ) -> None:
        """Save golden output for an intent scenario.

        Args:
            intent_name: Name of the intent being tested
            output: Generated KRM resources by site
            checksums: Resource checksums
            manifest_data: Manifest metadata
        """
        golden_dir = self.expected_outputs / intent_name
        golden_dir.mkdir(parents=True, exist_ok=True)

        # Save generated resources
        for site, resources in output.items():
            site_dir = golden_dir / site
            site_dir.mkdir(exist_ok=True)

            for resource in resources:
                filename = self._get_resource_filename(resource)
                resource_file = site_dir / filename

                # Sort keys for deterministic output
                sorted_resource = self._sort_keys_recursively(resource)

                with open(resource_file, "w") as f:
                    yaml.dump(
                        sorted_resource, f, sort_keys=True, default_flow_style=False
                    )

        # Save checksums
        checksums_file = golden_dir / "checksums.json"
        with open(checksums_file, "w") as f:
            json.dump(checksums, f, sort_keys=True, indent=2)

        # Save manifest data
        manifest_file = golden_dir / "manifest.json"
        with open(manifest_file, "w") as f:
            json.dump(manifest_data, f, sort_keys=True, indent=2)

    def load_golden_output(
        self, intent_name: str
    ) -> Tuple[Dict[str, List[Dict]], Dict[str, str], Dict[str, Any]]:
        """Load golden output for comparison.

        Args:
            intent_name: Name of the intent being tested

        Returns:
            Tuple of (resources, checksums, manifest_data)

        Raises:
            FileNotFoundError: If golden output doesn't exist
        """
        golden_dir = self.expected_outputs / intent_name
        if not golden_dir.exists():
            raise FileNotFoundError(f"Golden output not found for: {intent_name}")

        # Load resources
        resources = {}
        for site_dir in golden_dir.iterdir():
            if site_dir.is_dir() and site_dir.name in ["edge1", "edge2"]:
                site_resources = []
                for resource_file in site_dir.glob("*.yaml"):
                    with open(resource_file, "r") as f:
                        resource = yaml.safe_load(f)
                        site_resources.append(resource)
                resources[site_dir.name] = site_resources

        # Load checksums
        checksums_file = golden_dir / "checksums.json"
        with open(checksums_file, "r") as f:
            checksums = json.load(f)

        # Load manifest
        manifest_file = golden_dir / "manifest.json"
        with open(manifest_file, "r") as f:
            manifest_data = json.load(f)

        return resources, checksums, manifest_data

    def compare_outputs(
        self, actual: Dict[str, List[Dict]], expected: Dict[str, List[Dict]]
    ) -> List[str]:
        """Compare actual vs expected outputs and return differences.

        Args:
            actual: Actual generated resources
            expected: Expected golden resources

        Returns:
            List of difference descriptions (empty if no differences)
        """
        differences = []

        # Check if sites match
        actual_sites = set(actual.keys())
        expected_sites = set(expected.keys())

        if actual_sites != expected_sites:
            differences.append(
                f"Site mismatch: actual={actual_sites}, expected={expected_sites}"
            )

        # Compare resources for each site
        for site in expected_sites:
            if site not in actual:
                differences.append(f"Missing site in actual output: {site}")
                continue

            actual_resources = actual[site]
            expected_resources = expected[site]

            # Sort resources by kind and name for comparison
            actual_sorted = self._sort_resources_for_comparison(actual_resources)
            expected_sorted = self._sort_resources_for_comparison(expected_resources)

            if len(actual_sorted) != len(expected_sorted):
                differences.append(
                    f"Resource count mismatch for {site}: "
                    f"actual={len(actual_sorted)}, expected={len(expected_sorted)}"
                )

            # Compare each resource
            for i, (actual_res, expected_res) in enumerate(
                zip(actual_sorted, expected_sorted)
            ):
                resource_diff = self._compare_resources(
                    actual_res, expected_res, f"{site}[{i}]"
                )
                differences.extend(resource_diff)

        return differences

    def generate_test_scenario(
        self, intent_name: str, fixed_timestamp: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate KRM resources for a given intent scenario.

        Args:
            intent_name: Name of the intent fixture to test
            fixed_timestamp: Optional fixed timestamp for deterministic testing

        Returns:
            Dictionary containing generated resources, checksums, and manifest
        """
        intent_data = self.load_intent(intent_name)

        with tempfile.TemporaryDirectory() as tmpdir:
            # Create translator with temporary output directory
            translator = IntentToKRMTranslator(str(Path(tmpdir) / "output"))

            # Set fixed timestamp for deterministic testing
            if fixed_timestamp:
                translator._manifest_data["timestamp"] = fixed_timestamp

            # Create temporary intent file
            intent_file = Path(tmpdir) / "intent.json"
            with open(intent_file, "w") as f:
                json.dump(intent_data, f)

            # Generate resources
            resources = translator.translate(str(intent_file))
            checksums = translator.get_resource_checksums(resources)
            manifest_data = translator._manifest_data.copy()

            return {
                "resources": resources,
                "checksums": checksums,
                "manifest": manifest_data,
            }

    def _get_resource_filename(self, resource: Dict[str, Any]) -> str:
        """Get filename for a resource based on its kind and name."""
        kind = resource.get("kind", "unknown")
        name = resource.get("metadata", {}).get("name", "unnamed")

        # Special handling for Kustomization
        if kind == "Kustomization":
            return "kustomization.yaml"

        # Convert kind to lowercase with dashes
        kind_lower = kind.lower()
        # Handle camelCase to kebab-case conversion
        import re

        kind_kebab = re.sub(r"([a-z0-9])([A-Z])", r"\1-\2", kind_lower).lower()

        return f"{name}-{kind_kebab}.yaml"

    def _sort_keys_recursively(self, obj: Any) -> Any:
        """Recursively sort dictionary keys for deterministic output."""
        if isinstance(obj, dict):
            return {k: self._sort_keys_recursively(v) for k, v in sorted(obj.items())}
        elif isinstance(obj, list):
            return [self._sort_keys_recursively(item) for item in obj]
        else:
            return obj

    def _sort_resources_for_comparison(
        self, resources: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Sort resources for consistent comparison."""

        def sort_key(resource):
            kind = resource.get("kind", "")
            name = resource.get("metadata", {}).get("name", "")
            return (kind, name)

        return sorted(resources, key=sort_key)

    def _compare_resources(
        self, actual: Dict[str, Any], expected: Dict[str, Any], context: str
    ) -> List[str]:
        """Compare two resources and return differences."""
        differences = []

        # Normalize both resources by sorting keys
        actual_normalized = self._sort_keys_recursively(actual)
        expected_normalized = self._sort_keys_recursively(expected)

        # Convert to JSON strings for comparison
        actual_json = json.dumps(actual_normalized, sort_keys=True, indent=2)
        expected_json = json.dumps(expected_normalized, sort_keys=True, indent=2)

        if actual_json != expected_json:
            differences.append(f"Resource mismatch at {context}")
            # Could add more detailed diff analysis here

        return differences


@pytest.fixture
def golden_framework(test_data_dir):
    """Provide golden test framework instance."""
    return GoldenTestFramework(test_data_dir)


class TestGoldenFramework:
    """Tests for the golden test framework itself."""

    def test_framework_initialization(self, test_data_dir):
        """Test that framework initializes correctly."""
        framework = GoldenTestFramework(test_data_dir)
        assert framework.test_data_dir == test_data_dir
        assert framework.intent_fixtures == test_data_dir / "intents"
        assert framework.expected_outputs == test_data_dir / "expected"

    def test_load_intent(self, golden_framework):
        """Test loading intent fixtures."""
        intent = golden_framework.load_intent("edge1-embb-with-sla")
        assert intent["intentId"] == "edge1-embb-001"
        assert intent["serviceType"] == "enhanced-mobile-broadband"
        assert intent["targetSite"] == "edge1"

    def test_load_nonexistent_intent(self, golden_framework):
        """Test loading non-existent intent raises error."""
        with pytest.raises(FileNotFoundError):
            golden_framework.load_intent("nonexistent-intent")

    def test_generate_test_scenario(self, golden_framework, fixed_timestamp):
        """Test generating test scenario."""
        scenario = golden_framework.generate_test_scenario(
            "edge1-embb-with-sla", fixed_timestamp=fixed_timestamp
        )

        assert "resources" in scenario
        assert "checksums" in scenario
        assert "manifest" in scenario

        # Check that resources were generated for edge1
        assert "edge1" in scenario["resources"]
        assert len(scenario["resources"]["edge1"]) > 0

        # Check that checksums were generated
        assert len(scenario["checksums"]) > 0

        # Check manifest contains expected fields
        manifest = scenario["manifest"]
        assert manifest["intent_id"] == "edge1-embb-001"
        assert manifest["timestamp"] == fixed_timestamp

    def test_sort_keys_recursively(self, golden_framework):
        """Test recursive key sorting."""
        unsorted = {
            "z": {"y": "value", "a": {"c": 1, "b": 2}},
            "a": [{"z": 1, "a": 2}],
            "m": "middle",
        }

        sorted_obj = golden_framework._sort_keys_recursively(unsorted)

        # Check top-level keys are sorted
        assert list(sorted_obj.keys()) == ["a", "m", "z"]

        # Check nested dict keys are sorted
        assert list(sorted_obj["z"].keys()) == ["a", "y"]
        assert list(sorted_obj["z"]["a"].keys()) == ["b", "c"]

        # Check list items are sorted
        assert list(sorted_obj["a"][0].keys()) == ["a", "z"]
