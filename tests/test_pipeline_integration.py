"""End-to-end pipeline integration tests.

This module provides comprehensive integration tests that validate the entire
intent-to-KRM compilation pipeline from input to output.
"""

import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# Add the intent-compiler to the path for testing
sys.path.insert(0, str(Path(__file__).parent.parent / "tools" / "intent-compiler"))

from translate import IntentToKRMTranslator


class TestPipelineIntegration:
    """End-to-end integration tests for the complete pipeline."""

    @pytest.fixture
    def pipeline_workspace(self):
        """Create workspace for pipeline testing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            workspace = Path(tmpdir)
            (workspace / "input").mkdir()
            (workspace / "output").mkdir()
            yield workspace

    def test_full_pipeline_edge1_embb(self, pipeline_workspace, fixed_timestamp):
        """Test complete pipeline for edge1 eMBB service."""
        # Create comprehensive intent
        intent = {
            "intentId": "pipeline-embb-edge1-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "premium",
            "description": "Premium eMBB service for edge1 with comprehensive SLA",
            "sla": {
                "availability": 99.95,
                "latency": 8,
                "throughput": 1500,
                "connections": 10000,
                "reliability": 99.9,
            },
            "metadata": {
                "customer": "enterprise-premium-001",
                "priority": "high",
                "deployment": "production",
            },
        }

        intent_file = pipeline_workspace / "input" / "pipeline_embb.json"
        with open(intent_file, "w") as f:
            json.dump(intent, f, indent=2)

        # Initialize translator
        translator = IntentToKRMTranslator(
            str(pipeline_workspace / "output"), enable_caching=True
        )
        translator._manifest_data["timestamp"] = fixed_timestamp

        # Execute translation
        resources = translator.translate(str(intent_file))
        checksums = translator.get_resource_checksums(resources)
        manifest_path = translator.save_resources(resources)

        # Validate pipeline results
        self._validate_pipeline_results(
            resources,
            checksums,
            manifest_path,
            expected_sites=["edge1"],
            expected_intent_id="pipeline-embb-edge1-001",
        )

        # Validate specific eMBB characteristics
        edge1_resources = resources["edge1"]

        # Find and validate ProvisioningRequest
        pr = next(r for r in edge1_resources if r["kind"] == "ProvisioningRequest")
        assert pr["spec"]["targetCluster"] == "edge-cluster-01"

        sla_reqs = pr["spec"]["slaRequirements"]
        assert sla_reqs["availability"] == "99.95%"
        assert sla_reqs["maxLatency"] == "8ms"
        assert sla_reqs["minThroughput"] == "1500Mbps"
        assert sla_reqs["maxConnections"] == "10000"
        assert sla_reqs["reliability"] == "99.9%"

        # Find and validate NetworkSlice
        ns = next(r for r in edge1_resources if r["kind"] == "NetworkSlice")
        assert ns["spec"]["sliceType"] == "eMBB"
        assert ns["spec"]["qos"]["5qi"] == 5  # Low latency for 8ms
        assert ns["spec"]["qos"]["gfbr"] == "1500Mbps"

    def test_full_pipeline_both_sites_urllc(self, pipeline_workspace, fixed_timestamp):
        """Test complete pipeline for both sites URLLC service."""
        intent = {
            "intentId": "pipeline-urllc-both-001",
            "serviceType": "ultra-reliable-low-latency",
            "targetSite": "both",
            "resourceProfile": "ultra-performance",
            "description": "Critical URLLC service across both edge sites",
            "sla": {
                "availability": 99.999,
                "latency": 1,
                "throughput": 800,
                "connections": 5000,
                "reliability": 99.9999,
            },
            "metadata": {
                "customer": "critical-systems-001",
                "priority": "critical",
                "deployment": "multi-site",
            },
        }

        intent_file = pipeline_workspace / "input" / "pipeline_urllc.json"
        with open(intent_file, "w") as f:
            json.dump(intent, f, indent=2)

        translator = IntentToKRMTranslator(
            str(pipeline_workspace / "output"), enable_caching=True
        )
        translator._manifest_data["timestamp"] = fixed_timestamp

        # Execute translation
        resources = translator.translate(str(intent_file))
        checksums = translator.get_resource_checksums(resources)
        manifest_path = translator.save_resources(resources)

        # Validate multi-site deployment
        self._validate_pipeline_results(
            resources,
            checksums,
            manifest_path,
            expected_sites=["edge1", "edge2"],
            expected_intent_id="pipeline-urllc-both-001",
        )

        # Validate URLLC characteristics for both sites
        for site in ["edge1", "edge2"]:
            site_resources = resources[site]

            # Find ProvisioningRequest
            pr = next(r for r in site_resources if r["kind"] == "ProvisioningRequest")
            expected_cluster = f"edge-cluster-0{1 if site == 'edge1' else 2}"
            assert pr["spec"]["targetCluster"] == expected_cluster

            # Validate ultra-low latency SLA
            sla_reqs = pr["spec"]["slaRequirements"]
            assert sla_reqs["maxLatency"] == "1ms"
            assert sla_reqs["reliability"] == "99.9999%"

            # Find NetworkSlice
            ns = next(r for r in site_resources if r["kind"] == "NetworkSlice")
            assert ns["spec"]["sliceType"] == "URLLC"
            assert ns["spec"]["qos"]["5qi"] == 1  # Ultra-low latency

    def test_full_pipeline_mmt_no_sla(self, pipeline_workspace, fixed_timestamp):
        """Test complete pipeline for mMTC service without SLA."""
        intent = {
            "intentId": "pipeline-mmt-basic-001",
            "serviceType": "massive-machine-type",
            "targetSite": "edge2",
            "resourceProfile": "basic",
            "description": "Basic mMTC service without SLA requirements",
            "metadata": {"customer": "iot-basic-001", "priority": "low"},
        }

        intent_file = pipeline_workspace / "input" / "pipeline_mmt.json"
        with open(intent_file, "w") as f:
            json.dump(intent, f, indent=2)

        translator = IntentToKRMTranslator(str(pipeline_workspace / "output"))
        translator._manifest_data["timestamp"] = fixed_timestamp

        # Execute translation
        resources = translator.translate(str(intent_file))
        checksums = translator.get_resource_checksums(resources)
        manifest_path = translator.save_resources(resources)

        # Validate basic service without SLA
        assert "edge2" in resources
        edge2_resources = resources["edge2"]

        # Should have 3 resources (no NetworkSlice without SLA)
        assert len(edge2_resources) == 3

        resource_kinds = [r["kind"] for r in edge2_resources]
        expected_kinds = ["ProvisioningRequest", "ConfigMap", "Kustomization"]
        assert sorted(resource_kinds) == sorted(expected_kinds)

        # ProvisioningRequest should not have SLA requirements
        pr = next(r for r in edge2_resources if r["kind"] == "ProvisioningRequest")
        assert "slaRequirements" not in pr["spec"]

    def test_pipeline_error_handling(self, pipeline_workspace):
        """Test pipeline error handling for various failure scenarios."""
        translator = IntentToKRMTranslator(str(pipeline_workspace / "output"))

        # Test missing file
        with pytest.raises(Exception):  # Should be FileSystemError
            translator.translate(str(pipeline_workspace / "nonexistent.json"))

        # Test malformed JSON
        malformed_file = pipeline_workspace / "input" / "malformed.json"
        malformed_file.write_text('{"intentId": "test", invalid}')

        with pytest.raises(Exception):  # Should be IntentValidationError
            translator.translate(str(malformed_file))

        # Test invalid intent structure
        invalid_intent = {"invalidField": "value"}
        invalid_file = pipeline_workspace / "input" / "invalid.json"
        with open(invalid_file, "w") as f:
            json.dump(invalid_intent, f)

        with pytest.raises(Exception):  # Should be IntentValidationError
            translator.translate(str(invalid_file))

    def test_pipeline_idempotency(self, pipeline_workspace, fixed_timestamp):
        """Test that pipeline is idempotent across multiple runs."""
        intent = {
            "intentId": "idempotency-test-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "sla": {"availability": 99.9, "latency": 10, "throughput": 100},
        }

        intent_file = pipeline_workspace / "input" / "idempotency.json"
        with open(intent_file, "w") as f:
            json.dump(intent, f)

        # Run pipeline multiple times
        results = []
        for i in range(3):
            output_dir = pipeline_workspace / f"output_{i}"
            translator = IntentToKRMTranslator(str(output_dir))
            translator._manifest_data["timestamp"] = fixed_timestamp

            resources = translator.translate(str(intent_file))
            checksums = translator.get_resource_checksums(resources)
            results.append((resources, checksums))

        # All results should be identical
        base_resources, base_checksums = results[0]
        for i, (resources, checksums) in enumerate(results[1:], 1):
            assert checksums == base_checksums, f"Checksums differ in run {i+1}"

            # Compare resource content
            for site in base_resources:
                assert site in resources, f"Site {site} missing in run {i+1}"

                base_site_resources = sorted(
                    base_resources[site],
                    key=lambda r: (r["kind"], r.get("metadata", {}).get("name", "")),
                )
                site_resources = sorted(
                    resources[site],
                    key=lambda r: (r["kind"], r.get("metadata", {}).get("name", "")),
                )

                assert len(base_site_resources) == len(
                    site_resources
                ), f"Resource count differs for {site} in run {i+1}"

                for j, (base_resource, resource) in enumerate(
                    zip(base_site_resources, site_resources)
                ):
                    # Normalize for comparison
                    base_json = json.dumps(base_resource, sort_keys=True)
                    resource_json = json.dumps(resource, sort_keys=True)
                    assert (
                        base_json == resource_json
                    ), f"Resource {j} differs for {site} in run {i+1}"

    def _validate_pipeline_results(
        self, resources, checksums, manifest_path, expected_sites, expected_intent_id
    ):
        """Validate common pipeline result structure."""
        # Validate sites
        assert set(resources.keys()) == set(expected_sites)

        # Validate each site has resources
        for site in expected_sites:
            site_resources = resources[site]
            assert len(site_resources) > 0

            # Validate resource structure
            for resource in site_resources:
                assert "kind" in resource
                assert "apiVersion" in resource
                if resource["kind"] != "Kustomization":
                    assert "metadata" in resource
                    assert "name" in resource["metadata"]

        # Validate checksums
        assert len(checksums) > 0
        for resource_id, checksum in checksums.items():
            assert len(checksum) == 64  # SHA256 hex
            parts = resource_id.split("/")
            assert len(parts) >= 3
            assert parts[0] in expected_sites

        # Validate manifest file exists and has correct structure
        assert Path(manifest_path).exists()
        with open(manifest_path, "r") as f:
            manifest = json.load(f)

        assert manifest["intent_id"] == expected_intent_id
        assert sorted(manifest["target_sites"]) == sorted(expected_sites)
        assert "summary" in manifest
        assert manifest["summary"]["total_sites"] == len(expected_sites)


class TestPipelinePerformance:
    """Performance tests for the pipeline."""

    @pytest.mark.slow
    def test_large_intent_performance(self, pipeline_workspace, fixed_timestamp):
        """Test pipeline performance with complex intent."""
        import time

        # Create complex intent with many SLA parameters
        intent = {
            "intentId": "performance-test-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "both",
            "resourceProfile": "ultra-performance",
            "description": "Complex intent for performance testing " * 10,
            "sla": {
                "availability": 99.999,
                "latency": 1,
                "throughput": 10000,
                "connections": 100000,
                "reliability": 99.9999,
                "packetLoss": 0.001,
                "jitter": 0.5,
            },
            "metadata": {
                "customer": "performance-customer-001",
                "priority": "critical",
                "deployment": "multi-site",
                "environment": "production",
                "version": "1.0.0",
                "tags": ["high-performance", "critical", "multi-site"],
            },
        }

        intent_file = pipeline_workspace / "input" / "performance.json"
        with open(intent_file, "w") as f:
            json.dump(intent, f, indent=2)

        translator = IntentToKRMTranslator(str(pipeline_workspace / "output"))
        translator._manifest_data["timestamp"] = fixed_timestamp

        # Measure translation time
        start_time = time.time()
        resources = translator.translate(str(intent_file))
        checksums = translator.get_resource_checksums(resources)
        manifest_path = translator.save_resources(resources)
        end_time = time.time()

        translation_time = end_time - start_time
        print(f"Translation time: {translation_time:.3f} seconds")

        # Should complete within reasonable time (adjust threshold as needed)
        assert (
            translation_time < 5.0
        ), f"Translation took too long: {translation_time:.3f}s"

        # Validate results were generated correctly
        assert len(resources) == 2  # Both sites
        assert len(checksums) == 8  # 4 resources per site
        assert Path(manifest_path).exists()

    @pytest.mark.slow
    def test_multiple_intent_batch_performance(
        self, pipeline_workspace, fixed_timestamp
    ):
        """Test pipeline performance with multiple intents."""
        import time

        # Create multiple intents
        intents = []
        for i in range(10):
            intent = {
                "intentId": f"batch-test-{i:03d}",
                "serviceType": "enhanced-mobile-broadband",
                "targetSite": "edge1",
                "sla": {
                    "availability": 99.9,
                    "latency": 10,
                    "throughput": 100 + i * 10,
                },
            }
            intents.append(intent)

        # Process all intents
        start_time = time.time()
        results = []

        for i, intent in enumerate(intents):
            intent_file = pipeline_workspace / "input" / f"batch_{i:03d}.json"
            with open(intent_file, "w") as f:
                json.dump(intent, f)

            output_dir = pipeline_workspace / f"output_{i:03d}"
            translator = IntentToKRMTranslator(str(output_dir))
            translator._manifest_data["timestamp"] = fixed_timestamp

            resources = translator.translate(str(intent_file))
            checksums = translator.get_resource_checksums(resources)
            manifest_path = translator.save_resources(resources)

            results.append((resources, checksums, manifest_path))

        end_time = time.time()
        batch_time = end_time - start_time
        avg_time_per_intent = batch_time / len(intents)

        print(f"Batch processing time: {batch_time:.3f} seconds")
        print(f"Average time per intent: {avg_time_per_intent:.3f} seconds")

        # Should process intents efficiently
        assert (
            avg_time_per_intent < 1.0
        ), f"Average processing time too high: {avg_time_per_intent:.3f}s"

        # Validate all results
        assert len(results) == len(intents)
        for i, (resources, checksums, manifest_path) in enumerate(results):
            assert "edge1" in resources
            assert len(checksums) > 0
            assert Path(manifest_path).exists()
