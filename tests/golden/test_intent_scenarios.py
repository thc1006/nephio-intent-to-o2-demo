"""Golden tests for different intent compilation scenarios.

This module contains comprehensive golden tests for various intent scenarios,
ensuring the intent-to-KRM pipeline produces consistent, correct output.
"""

import json
import sys
from pathlib import Path

import pytest

# Add the intent-compiler to the path for testing
sys.path.insert(
    0, str(Path(__file__).parent.parent.parent / "tools" / "intent-compiler")
)

from golden.test_framework import GoldenTestFramework


class TestIntentScenarioGolden:
    """Golden tests for various intent scenarios."""

    @pytest.fixture(autouse=True)
    def setup_method(self, golden_framework, fixed_timestamp):
        """Setup for each test method."""
        self.framework = golden_framework
        self.fixed_timestamp = fixed_timestamp

    def test_edge1_embb_with_sla_golden(self):
        """Test edge1 eMBB service with SLA requirements."""
        intent_name = "edge1-embb-with-sla"
        scenario = self.framework.generate_test_scenario(
            intent_name, fixed_timestamp=self.fixed_timestamp
        )

        resources = scenario["resources"]
        checksums = scenario["checksums"]
        manifest = scenario["manifest"]

        # Validate basic structure
        assert "edge1" in resources
        assert len(resources) == 1  # Only edge1 site

        edge1_resources = resources["edge1"]
        assert len(edge1_resources) == 4  # PR, ConfigMap, NetworkSlice, Kustomization

        # Validate resource types
        resource_kinds = [r["kind"] for r in edge1_resources]
        expected_kinds = [
            "ProvisioningRequest",
            "ConfigMap",
            "NetworkSlice",
            "Kustomization",
        ]
        assert sorted(resource_kinds) == sorted(expected_kinds)

        # Validate ProvisioningRequest specifics
        pr = next(r for r in edge1_resources if r["kind"] == "ProvisioningRequest")
        assert pr["metadata"]["name"] == "edge1-embb-001-edge1"
        assert pr["metadata"]["namespace"] == "edge1"
        assert pr["spec"]["targetCluster"] == "edge-cluster-01"
        assert "slaRequirements" in pr["spec"]

        # Validate SLA conversion
        sla_reqs = pr["spec"]["slaRequirements"]
        assert sla_reqs["availability"] == "99.9%"
        assert sla_reqs["maxLatency"] == "10ms"
        assert sla_reqs["minThroughput"] == "1000Mbps"

        # Validate NetworkSlice QoS mapping
        ns = next(r for r in edge1_resources if r["kind"] == "NetworkSlice")
        assert ns["spec"]["sliceType"] == "eMBB"
        assert "qos" in ns["spec"]
        qos = ns["spec"]["qos"]
        assert qos["5qi"] == 5  # Low latency for 10ms
        assert qos["gfbr"] == "1000Mbps"

        # Validate checksums
        assert len(checksums) == 4
        for resource_id, checksum in checksums.items():
            assert "edge1/" in resource_id
            assert len(checksum) == 64  # SHA256 hex length

        # Validate manifest
        assert manifest["intent_id"] == "edge1-embb-001"
        assert manifest["target_sites"] == ["edge1"]
        assert manifest["resource_counts"]["edge1"] == 4

    def test_edge2_urllc_with_sla_golden(self):
        """Test edge2 URLLC service with strict SLA requirements."""
        intent_name = "edge2-urllc-with-sla"
        scenario = self.framework.generate_test_scenario(
            intent_name, fixed_timestamp=self.fixed_timestamp
        )

        resources = scenario["resources"]
        checksums = scenario["checksums"]
        manifest = scenario["manifest"]

        # Validate basic structure
        assert "edge2" in resources
        assert len(resources) == 1  # Only edge2 site

        edge2_resources = resources["edge2"]
        assert len(edge2_resources) == 4

        # Validate ProvisioningRequest for edge2
        pr = next(r for r in edge2_resources if r["kind"] == "ProvisioningRequest")
        assert pr["metadata"]["name"] == "edge2-urllc-001-edge2"
        assert pr["metadata"]["namespace"] == "edge2"
        assert pr["spec"]["targetCluster"] == "edge-cluster-02"

        # Validate ultra-low latency SLA
        sla_reqs = pr["spec"]["slaRequirements"]
        assert sla_reqs["availability"] == "99.999%"
        assert sla_reqs["maxLatency"] == "1ms"
        assert sla_reqs["reliability"] == "99.9999%"

        # Validate NetworkSlice for URLLC
        ns = next(r for r in edge2_resources if r["kind"] == "NetworkSlice")
        assert ns["spec"]["sliceType"] == "URLLC"
        qos = ns["spec"]["qos"]
        assert qos["5qi"] == 1  # Ultra-low latency for 1ms
        assert qos["gfbr"] == "500Mbps"

        # Validate manifest
        assert manifest["intent_id"] == "edge2-urllc-001"
        assert manifest["target_sites"] == ["edge2"]

    def test_both_sites_mmt_with_sla_golden(self):
        """Test both sites mMTC service with relaxed SLA."""
        intent_name = "both-sites-mmt-with-sla"
        scenario = self.framework.generate_test_scenario(
            intent_name, fixed_timestamp=self.fixed_timestamp
        )

        resources = scenario["resources"]
        checksums = scenario["checksums"]
        manifest = scenario["manifest"]

        # Validate multi-site deployment
        assert "edge1" in resources
        assert "edge2" in resources
        assert len(resources) == 2

        # Both sites should have same number of resources
        assert len(resources["edge1"]) == 4
        assert len(resources["edge2"]) == 4

        # Validate edge1 ProvisioningRequest
        edge1_pr = next(
            r for r in resources["edge1"] if r["kind"] == "ProvisioningRequest"
        )
        assert edge1_pr["metadata"]["name"] == "both-mmt-001-edge1"
        assert edge1_pr["metadata"]["namespace"] == "edge1"

        # Validate edge2 ProvisioningRequest
        edge2_pr = next(
            r for r in resources["edge2"] if r["kind"] == "ProvisioningRequest"
        )
        assert edge2_pr["metadata"]["name"] == "both-mmt-001-edge2"
        assert edge2_pr["metadata"]["namespace"] == "edge2"

        # Both should have same SLA requirements
        for pr in [edge1_pr, edge2_pr]:
            sla_reqs = pr["spec"]["slaRequirements"]
            assert sla_reqs["availability"] == "99.5%"
            assert sla_reqs["maxLatency"] == "100ms"
            assert sla_reqs["maxConnections"] == "100000"

        # Validate NetworkSlice for mMTC
        edge1_ns = next(r for r in resources["edge1"] if r["kind"] == "NetworkSlice")
        edge2_ns = next(r for r in resources["edge2"] if r["kind"] == "NetworkSlice")

        for ns in [edge1_ns, edge2_ns]:
            assert ns["spec"]["sliceType"] == "mMTC"
            qos = ns["spec"]["qos"]
            assert qos["5qi"] == 9  # Best effort for 100ms latency

        # Validate checksums for both sites
        edge1_checksums = {k: v for k, v in checksums.items() if k.startswith("edge1/")}
        edge2_checksums = {k: v for k, v in checksums.items() if k.startswith("edge2/")}
        assert len(edge1_checksums) == 4
        assert len(edge2_checksums) == 4

        # Validate manifest
        assert manifest["intent_id"] == "both-mmt-001"
        assert sorted(manifest["target_sites"]) == ["edge1", "edge2"]
        assert manifest["resource_counts"]["edge1"] == 4
        assert manifest["resource_counts"]["edge2"] == 4

    def test_edge1_embb_no_sla_golden(self):
        """Test edge1 eMBB service without SLA requirements."""
        intent_name = "edge1-embb-no-sla"
        scenario = self.framework.generate_test_scenario(
            intent_name, fixed_timestamp=self.fixed_timestamp
        )

        resources = scenario["resources"]
        manifest = scenario["manifest"]

        # Should generate fewer resources without SLA
        edge1_resources = resources["edge1"]
        assert (
            len(edge1_resources) == 3
        )  # PR, ConfigMap, Kustomization (no NetworkSlice)

        resource_kinds = [r["kind"] for r in edge1_resources]
        expected_kinds = ["ProvisioningRequest", "ConfigMap", "Kustomization"]
        assert sorted(resource_kinds) == sorted(expected_kinds)

        # ProvisioningRequest should not have SLA requirements
        pr = next(r for r in edge1_resources if r["kind"] == "ProvisioningRequest")
        assert "slaRequirements" not in pr["spec"]

        # Kustomization should not reference NetworkSlice
        kustomization = next(r for r in edge1_resources if r["kind"] == "Kustomization")
        networkslice_ref = any(
            "networkslice" in resource for resource in kustomization["resources"]
        )
        assert not networkslice_ref

        # Validate manifest
        assert manifest["resource_counts"]["edge1"] == 3

    def test_minimal_intent_golden(self):
        """Test minimal intent with default values."""
        intent_name = "minimal-intent"
        scenario = self.framework.generate_test_scenario(
            intent_name, fixed_timestamp=self.fixed_timestamp
        )

        resources = scenario["resources"]
        manifest = scenario["manifest"]

        # Should default to both sites
        assert "edge1" in resources
        assert "edge2" in resources

        # Each site should have minimal resources (no SLA)
        for site in ["edge1", "edge2"]:
            site_resources = resources[site]
            assert len(site_resources) == 3  # PR, ConfigMap, Kustomization

            # Validate ProvisioningRequest uses defaults
            pr = next(r for r in site_resources if r["kind"] == "ProvisioningRequest")
            assert pr["metadata"]["name"] == f"minimal-001-{site}"
            assert "slaRequirements" not in pr["spec"]

        # Validate manifest
        assert manifest["intent_id"] == "minimal-001"
        assert sorted(manifest["target_sites"]) == ["edge1", "edge2"]


class TestDeterministicOutput:
    """Tests for deterministic output generation."""

    def test_same_input_same_output(self, golden_framework, fixed_timestamp):
        """Test that identical inputs produce identical outputs."""
        intent_name = "edge1-embb-with-sla"

        # Generate scenario twice with same fixed timestamp
        scenario1 = golden_framework.generate_test_scenario(
            intent_name, fixed_timestamp=fixed_timestamp
        )
        scenario2 = golden_framework.generate_test_scenario(
            intent_name, fixed_timestamp=fixed_timestamp
        )

        # Checksums should be identical
        assert scenario1["checksums"] == scenario2["checksums"]

        # Resources should be identical when normalized
        for site in scenario1["resources"]:
            resources1 = scenario1["resources"][site]
            resources2 = scenario2["resources"][site]

            # Sort resources for comparison
            resources1_sorted = golden_framework._sort_resources_for_comparison(
                resources1
            )
            resources2_sorted = golden_framework._sort_resources_for_comparison(
                resources2
            )

            # Convert to JSON for comparison
            json1 = json.dumps(resources1_sorted, sort_keys=True, indent=2)
            json2 = json.dumps(resources2_sorted, sort_keys=True, indent=2)

            assert json1 == json2, f"Resources differ for site {site}"

    def test_key_ordering_deterministic(self, golden_framework, fixed_timestamp):
        """Test that all resource keys are consistently ordered."""
        intent_name = "both-sites-mmt-with-sla"
        scenario = golden_framework.generate_test_scenario(
            intent_name, fixed_timestamp=fixed_timestamp
        )

        for site, resources in scenario["resources"].items():
            for resource in resources:
                # Check that all dict keys are sorted at top level
                if isinstance(resource, dict):
                    keys = list(resource.keys())
                    assert keys == sorted(
                        keys
                    ), f"Keys not sorted in {site} resource: {keys}"

                # Check metadata keys are sorted
                if "metadata" in resource:
                    metadata_keys = list(resource["metadata"].keys())
                    assert metadata_keys == sorted(
                        metadata_keys
                    ), f"Metadata keys not sorted in {site} resource: {metadata_keys}"


class TestIdempotency:
    """Tests for idempotent behavior."""

    def test_translation_idempotency(self, golden_framework, fixed_timestamp):
        """Test that multiple translations of same intent are idempotent."""
        intent_name = "edge1-embb-with-sla"

        # Generate multiple scenarios
        scenarios = []
        for _ in range(3):
            scenario = golden_framework.generate_test_scenario(
                intent_name, fixed_timestamp=fixed_timestamp
            )
            scenarios.append(scenario)

        # All scenarios should have identical checksums
        base_checksums = scenarios[0]["checksums"]
        for i, scenario in enumerate(scenarios[1:], 1):
            assert (
                scenario["checksums"] == base_checksums
            ), f"Checksums differ in run {i+1}"

        # All scenarios should have identical resource counts
        base_manifest = scenarios[0]["manifest"]
        for i, scenario in enumerate(scenarios[1:], 1):
            assert (
                scenario["manifest"]["resource_counts"]
                == base_manifest["resource_counts"]
            ), f"Resource counts differ in run {i+1}"

    def test_checksum_consistency(self, golden_framework, fixed_timestamp):
        """Test that checksums are consistent across runs."""
        intent_name = "edge2-urllc-with-sla"

        # Generate scenario
        scenario = golden_framework.generate_test_scenario(
            intent_name, fixed_timestamp=fixed_timestamp
        )

        checksums = scenario["checksums"]
        resources = scenario["resources"]

        # Verify that checksums match actual resource content
        import tempfile

        from translate import IntentToKRMTranslator

        with tempfile.TemporaryDirectory() as tmpdir:
            translator = IntentToKRMTranslator(str(Path(tmpdir) / "output"))

            for resource_id, expected_checksum in checksums.items():
                # Find the corresponding resource
                site, kind, name = resource_id.split("/", 2)
                resource = next(
                    r
                    for r in resources[site]
                    if r["kind"] == kind and r["metadata"]["name"] == name
                )

                # Calculate checksum for the resource
                import yaml

                resource_yaml = yaml.dump(
                    translator._sort_resource_keys(resource),
                    sort_keys=True,
                    default_flow_style=False,
                )
                actual_checksum = translator._calculate_checksum(resource_yaml)

                assert (
                    actual_checksum == expected_checksum
                ), f"Checksum mismatch for {resource_id}"
