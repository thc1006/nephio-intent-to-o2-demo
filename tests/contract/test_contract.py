#!/usr/bin/env python3
"""Contract tests for Intent to KRM translator.

Ensures exact field mappings and deterministic outputs for all service types.
"""

import json
import yaml
import os
import sys
import hashlib
import tempfile
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Tuple
import unittest
from datetime import datetime
import difflib

class ContractTestBase(unittest.TestCase):
    """Base class for contract tests with snapshot support."""

    @classmethod
    def setUpClass(cls):
        """Set up test environment."""
        cls.test_dir = Path(__file__).parent
        cls.project_root = cls.test_dir.parent.parent
        cls.translator = cls.project_root / "tools" / "intent-compiler" / "translate.py"
        cls.fixtures_dir = cls.test_dir / "fixtures"
        cls.snapshots_dir = cls.test_dir / "snapshots"

        # Ensure directories exist
        cls.fixtures_dir.mkdir(exist_ok=True)
        cls.snapshots_dir.mkdir(exist_ok=True)

    def setUp(self):
        """Set up individual test."""
        self.temp_dir = tempfile.mkdtemp(prefix="contract-test-")
        self.maxDiff = None  # Show full diffs

    def tearDown(self):
        """Clean up test."""
        import shutil
        if os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)

    def normalize_timestamp(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize timestamps for deterministic comparison."""
        if isinstance(data, dict):
            result = {}
            for key, value in data.items():
                if key == "timestamp":
                    result[key] = "2025-01-01T00:00:00.000000Z"
                elif isinstance(value, dict):
                    result[key] = self.normalize_timestamp(value)
                elif isinstance(value, list):
                    result[key] = [self.normalize_timestamp(item) if isinstance(item, dict) else item for item in value]
                else:
                    result[key] = value
            return result
        return data

    def load_and_normalize_yaml(self, filepath: Path) -> Dict[str, Any]:
        """Load YAML and normalize for comparison."""
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
        return self.normalize_timestamp(data)

    def assert_snapshot_match(self, name: str, actual: Dict[str, Any], update: bool = False):
        """Assert that actual matches snapshot or update if requested."""
        snapshot_file = self.snapshots_dir / f"{name}.yaml"
        actual_normalized = self.normalize_timestamp(actual)

        if update or not snapshot_file.exists():
            # Create/update snapshot
            with open(snapshot_file, 'w') as f:
                yaml.dump(actual_normalized, f, default_flow_style=False, sort_keys=True)
            if not snapshot_file.exists():
                self.fail(f"Snapshot created: {snapshot_file}")
        else:
            # Compare with snapshot
            with open(snapshot_file, 'r') as f:
                expected = yaml.safe_load(f)

            if actual_normalized != expected:
                # Generate detailed diff
                actual_yaml = yaml.dump(actual_normalized, default_flow_style=False, sort_keys=True)
                expected_yaml = yaml.dump(expected, default_flow_style=False, sort_keys=True)
                diff = '\n'.join(difflib.unified_diff(
                    expected_yaml.splitlines(),
                    actual_yaml.splitlines(),
                    fromfile=f"{name}_expected",
                    tofile=f"{name}_actual",
                    lineterm=''
                ))
                self.fail(f"Snapshot mismatch for {name}:\n{diff}")

    def run_translator(self, intent: Dict[str, Any]) -> Dict[str, List[Dict[str, Any]]]:
        """Run translator and return generated resources."""
        intent_file = Path(self.temp_dir) / "intent.json"
        with open(intent_file, 'w') as f:
            json.dump(intent, f, indent=2)

        output_dir = Path(self.temp_dir) / "output"

        result = subprocess.run(
            [sys.executable, str(self.translator), str(intent_file), "-o", str(output_dir)],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0, f"Translation failed: {result.stderr}")

        # Load all generated resources
        resources = {}
        for site_dir in output_dir.glob("*"):
            if site_dir.is_dir():
                site = site_dir.name
                resources[site] = []
                for yaml_file in sorted(site_dir.glob("*.yaml")):
                    resources[site].append(self.load_and_normalize_yaml(yaml_file))

        return resources


class TestEMBBContract(ContractTestBase):
    """Contract tests for eMBB service type."""

    def test_embb_edge1_contract(self):
        """Test eMBB intent for edge1 with exact field mappings."""
        intent = {
            "intentId": "embb-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
            "sla": {
                "availability": 99.99,
                "latency": 10,
                "throughput": 1000
            }
        }

        resources = self.run_translator(intent)

        # Verify edge1 resources exist
        self.assertIn("edge1", resources)
        edge1_resources = resources["edge1"]

        # Find ProvisioningRequest
        pr = next((r for r in edge1_resources if r.get("kind") == "ProvisioningRequest"), None)
        self.assertIsNotNone(pr, "ProvisioningRequest not found")

        # Assert exact field mappings for ProvisioningRequest
        self.assertEqual(pr["apiVersion"], "o2ims.provisioning.oran.org/v1alpha1")
        self.assertEqual(pr["metadata"]["name"], "embb-001-edge1")
        self.assertEqual(pr["metadata"]["namespace"], "edge1")
        self.assertEqual(pr["metadata"]["labels"]["intent-id"], "embb-001")
        self.assertEqual(pr["metadata"]["labels"]["service-type"], "enhanced-mobile-broadband")
        self.assertEqual(pr["metadata"]["labels"]["target-site"], "edge1")
        self.assertEqual(pr["spec"]["targetCluster"], "edge-cluster-01")
        self.assertEqual(pr["spec"]["networkConfig"]["plmnId"], "00101")
        self.assertEqual(pr["spec"]["networkConfig"]["gnbId"], "00001")
        self.assertEqual(pr["spec"]["networkConfig"]["tac"], "0001")
        self.assertEqual(pr["spec"]["networkConfig"]["sliceType"], "eMBB")
        self.assertEqual(pr["spec"]["resourceRequirements"]["cpu"], "8")
        self.assertEqual(pr["spec"]["resourceRequirements"]["memory"], "16Gi")
        self.assertEqual(pr["spec"]["resourceRequirements"]["storage"], "100Gi")
        self.assertEqual(pr["spec"]["slaRequirements"]["availability"], "99.99%")
        self.assertEqual(pr["spec"]["slaRequirements"]["maxLatency"], "10ms")
        self.assertEqual(pr["spec"]["slaRequirements"]["minThroughput"], "1000Mbps")

        # Snapshot test for full resource
        self.assert_snapshot_match("embb_edge1_pr", pr)

        # Find ConfigMap
        cm = next((r for r in edge1_resources if r.get("kind") == "ConfigMap"), None)
        self.assertIsNotNone(cm, "ConfigMap not found")

        # Assert ConfigMap fields
        self.assertEqual(cm["metadata"]["name"], "intent-embb-001-edge1")
        self.assertEqual(cm["data"]["site"], "edge1")
        self.assertEqual(cm["data"]["serviceType"], "enhanced-mobile-broadband")
        self.assertIn("intent.json", cm["data"])

        # Find NetworkSlice
        ns = next((r for r in edge1_resources if r.get("kind") == "NetworkSlice"), None)
        self.assertIsNotNone(ns, "NetworkSlice not found")

        # Assert NetworkSlice fields
        self.assertEqual(ns["apiVersion"], "workload.nephio.org/v1alpha1")
        self.assertEqual(ns["metadata"]["name"], "slice-embb-001-edge1")
        self.assertEqual(ns["spec"]["sliceType"], "eMBB")
        self.assertEqual(ns["spec"]["plmn"]["mcc"], "001")
        self.assertEqual(ns["spec"]["plmn"]["mnc"], "01")
        self.assertEqual(ns["spec"]["qos"]["5qi"], 5)
        self.assertEqual(ns["spec"]["qos"]["gfbr"], "1000Mbps")

        # Snapshot test for NetworkSlice
        self.assert_snapshot_match("embb_edge1_ns", ns)


class TestURLLCContract(ContractTestBase):
    """Contract tests for URLLC service type."""

    def test_urllc_edge2_contract(self):
        """Test URLLC intent for edge2 with exact field mappings."""
        intent = {
            "intentId": "urllc-001",
            "serviceType": "ultra-reliable-low-latency",
            "targetSite": "edge2",
            "resourceProfile": "premium",
            "sla": {
                "availability": 99.999,
                "latency": 1,
                "throughput": 5000
            }
        }

        resources = self.run_translator(intent)

        # Verify edge2 resources exist
        self.assertIn("edge2", resources)
        edge2_resources = resources["edge2"]

        # Find ProvisioningRequest
        pr = next((r for r in edge2_resources if r.get("kind") == "ProvisioningRequest"), None)
        self.assertIsNotNone(pr, "ProvisioningRequest not found")

        # Assert URLLC-specific mappings
        self.assertEqual(pr["metadata"]["namespace"], "edge2")
        self.assertEqual(pr["spec"]["targetCluster"], "edge-cluster-02")
        self.assertEqual(pr["spec"]["networkConfig"]["plmnId"], "00102")
        self.assertEqual(pr["spec"]["networkConfig"]["gnbId"], "00002")
        self.assertEqual(pr["spec"]["networkConfig"]["tac"], "0002")
        self.assertEqual(pr["spec"]["networkConfig"]["sliceType"], "URLLC")
        self.assertEqual(pr["spec"]["resourceRequirements"]["cpu"], "16")
        self.assertEqual(pr["spec"]["resourceRequirements"]["memory"], "32Gi")
        self.assertEqual(pr["spec"]["resourceRequirements"]["storage"], "200Gi")
        self.assertEqual(pr["spec"]["slaRequirements"]["maxLatency"], "1ms")

        # Find NetworkSlice and verify QoS for URLLC
        ns = next((r for r in edge2_resources if r.get("kind") == "NetworkSlice"), None)
        self.assertIsNotNone(ns, "NetworkSlice not found")
        self.assertEqual(ns["spec"]["qos"]["5qi"], 1)  # URLLC 5QI

        # Snapshot test
        self.assert_snapshot_match("urllc_edge2_pr", pr)


class TestMMTCContract(ContractTestBase):
    """Contract tests for mMTC service type."""

    def test_mmtc_both_sites_contract(self):
        """Test mMTC intent for both sites with exact field mappings."""
        intent = {
            "intentId": "mmtc-001",
            "serviceType": "massive-machine-type",
            "targetSite": "both",
            "resourceProfile": "standard",
            "sla": {
                "availability": 99.9,
                "connections": 1000000
            }
        }

        resources = self.run_translator(intent)

        # Verify both sites have resources
        self.assertIn("edge1", resources)
        self.assertIn("edge2", resources)

        # Test edge1 mMTC resources
        edge1_pr = next((r for r in resources["edge1"] if r.get("kind") == "ProvisioningRequest"), None)
        self.assertIsNotNone(edge1_pr)
        self.assertEqual(edge1_pr["spec"]["networkConfig"]["sliceType"], "mMTC")
        self.assertEqual(edge1_pr["spec"]["resourceRequirements"]["cpu"], "4")
        self.assertEqual(edge1_pr["spec"]["resourceRequirements"]["memory"], "8Gi")
        self.assertEqual(edge1_pr["spec"]["slaRequirements"]["maxConnections"], "1000000")

        # Test edge2 mMTC resources
        edge2_pr = next((r for r in resources["edge2"] if r.get("kind") == "ProvisioningRequest"), None)
        self.assertIsNotNone(edge2_pr)
        self.assertEqual(edge2_pr["spec"]["networkConfig"]["sliceType"], "mMTC")
        self.assertEqual(edge2_pr["spec"]["targetCluster"], "edge-cluster-02")

        # Ensure deterministic ordering
        self.assertEqual(len(resources["edge1"]), 4)  # PR, CM, NS, Kustomization
        self.assertEqual(len(resources["edge2"]), 4)

        # Snapshot tests for both sites
        self.assert_snapshot_match("mmtc_edge1_pr", edge1_pr)
        self.assert_snapshot_match("mmtc_edge2_pr", edge2_pr)


class TestKustomizationContract(ContractTestBase):
    """Contract tests for Kustomization generation."""

    def test_kustomization_fields(self):
        """Test Kustomization has correct resource references."""
        intent = {
            "intentId": "kust-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard"
        }

        resources = self.run_translator(intent)

        # Find Kustomization
        kustomization = next((r for r in resources["edge1"] if r.get("kind") == "Kustomization"), None)
        self.assertIsNotNone(kustomization)

        # Verify fields
        self.assertEqual(kustomization["apiVersion"], "kustomize.config.k8s.io/v1beta1")
        self.assertEqual(kustomization["namespace"], "edge1")
        self.assertEqual(kustomization["commonLabels"]["target-site"], "edge1")
        self.assertEqual(kustomization["commonLabels"]["intent-id"], "kust-001")

        # Verify resource references
        expected_resources = [
            "kust-001-edge1-provisioning-request.yaml",
            "intent-kust-001-edge1-configmap.yaml",
            "slice-kust-001-edge1-networkslice.yaml"
        ]
        self.assertEqual(kustomization["resources"], expected_resources)

        # Verify annotation
        self.assertEqual(
            kustomization["metadata"]["annotations"]["config.kubernetes.io/local-config"],
            "true"
        )


class TestDeterministicOutput(ContractTestBase):
    """Test output determinism and ordering."""

    def test_deterministic_generation(self):
        """Test that multiple runs produce identical outputs."""
        intent = {
            "intentId": "det-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
            "sla": {
                "availability": 99.99,
                "latency": 10,
                "throughput": 1000
            }
        }

        # Run translator twice
        resources1 = self.run_translator(intent)
        resources2 = self.run_translator(intent)

        # Normalize and compare
        for site in resources1:
            self.assertIn(site, resources2)

            # Sort resources by kind and name for comparison
            sorted1 = sorted(resources1[site], key=lambda r: (r.get("kind", ""), r.get("metadata", {}).get("name", "")))
            sorted2 = sorted(resources2[site], key=lambda r: (r.get("kind", ""), r.get("metadata", {}).get("name", "")))

            self.assertEqual(len(sorted1), len(sorted2))

            for r1, r2 in zip(sorted1, sorted2):
                # Compare normalized versions
                self.assertEqual(
                    self.normalize_timestamp(r1),
                    self.normalize_timestamp(r2),
                    f"Non-deterministic output for {r1.get('kind')}"
                )

    def test_file_ordering(self):
        """Test that generated files have consistent naming and ordering."""
        intent = {
            "intentId": "ord-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "both",
            "sla": {
                "availability": 99.99,
                "latency": 10,
                "throughput": 1000
            }
        }

        intent_file = Path(self.temp_dir) / "intent.json"
        with open(intent_file, 'w') as f:
            json.dump(intent, f)

        output_dir = Path(self.temp_dir) / "output"

        subprocess.run(
            [sys.executable, str(self.translator), str(intent_file), "-o", str(output_dir)],
            capture_output=True
        )

        # Check file naming conventions
        for site in ["edge1", "edge2"]:
            site_dir = output_dir / site
            self.assertTrue(site_dir.exists())

            files = sorted([f.name for f in site_dir.glob("*.yaml")])

            # Verify consistent naming pattern
            expected_patterns = [
                f"intent-ord-001-{site}-configmap.yaml",
                "kustomization.yaml",
                f"ord-001-{site}-provisioning-request.yaml",
                f"slice-ord-001-{site}-networkslice.yaml"
            ]

            self.assertEqual(files, expected_patterns)


class TestFieldMappingValidation(ContractTestBase):
    """Validate specific field mappings across service types."""

    def test_resource_profile_mapping(self):
        """Test resource profile affects resource allocations."""
        profiles = ["standard", "premium", "basic"]

        for profile in profiles:
            intent = {
                "intentId": f"prof-{profile}",
                "serviceType": "enhanced-mobile-broadband",
                "targetSite": "edge1",
                "resourceProfile": profile
            }

            resources = self.run_translator(intent)
            pr = next((r for r in resources["edge1"] if r.get("kind") == "ProvisioningRequest"), None)

            # Verify profile is in annotations
            self.assertEqual(pr["metadata"]["annotations"]["resource-profile"], profile)

            # Standard profile should have standard resources
            if profile == "standard":
                self.assertEqual(pr["spec"]["resourceRequirements"]["cpu"], "8")

    def test_sla_to_qos_mapping(self):
        """Test SLA parameters map correctly to QoS settings."""
        # Test cases match the actual translator logic
        test_cases = [
            (1, 1),    # latency <= 1 -> 5QI=1 (URLLC)
            (5, 5),    # latency <= 10 -> 5QI=5 (Low latency)
            (20, 7),   # latency <= 50 -> 5QI=7 (Voice)
            (100, 9),  # latency > 50 -> 5QI=9 (Best effort)
        ]

        for latency_value, expected_5qi in test_cases:
            with self.subTest(latency=latency_value, expected_5qi=expected_5qi):
                # Create a fresh temp directory for each test
                import tempfile
                import shutil

                temp_dir = tempfile.mkdtemp(prefix=f"qos-test-{latency_value}-")

                try:
                    intent = {
                        "intentId": f"qos-{latency_value}",
                        "serviceType": "enhanced-mobile-broadband",
                        "targetSite": "edge1",
                        "sla": {"latency": latency_value}
                    }

                    # Save the original temp_dir and replace it
                    original_temp = self.temp_dir
                    self.temp_dir = temp_dir

                    resources = self.run_translator(intent)

                    # Restore original temp_dir
                    self.temp_dir = original_temp

                    ns = next((r for r in resources["edge1"] if r.get("kind") == "NetworkSlice"), None)

                    self.assertIsNotNone(ns, f"NetworkSlice not found for latency {latency_value}")

                    actual_5qi = ns["spec"]["qos"]["5qi"]
                    self.assertEqual(
                        actual_5qi,
                        expected_5qi,
                        f"Latency {latency_value}ms should map to 5QI {expected_5qi}, got {actual_5qi}"
                    )

                finally:
                    # Clean up the test-specific temp directory
                    if os.path.exists(temp_dir):
                        shutil.rmtree(temp_dir)


def generate_test_report(results):
    """Generate detailed test report."""
    print("\n" + "="*80)
    print("CONTRACT TEST REPORT")
    print("="*80)

    total_tests = results.testsRun
    failures = len(results.failures)
    errors = len(results.errors)
    passed = total_tests - failures - errors

    print(f"\nTest Summary:")
    print(f"  Total Tests: {total_tests}")
    print(f"  Passed:      {passed} ✓")
    print(f"  Failed:      {failures} ✗")
    print(f"  Errors:      {errors} ⚠")

    if passed == total_tests:
        print(f"\n🎉 ALL TESTS PASSED!")
    else:
        print(f"\n❌ SOME TESTS FAILED")

        if results.failures:
            print("\nFailures:")
            for test, traceback in results.failures:
                print(f"  - {test}: {traceback.split('AssertionError:')[-1].strip()[:100]}")

        if results.errors:
            print("\nErrors:")
            for test, traceback in results.errors:
                print(f"  - {test}: {traceback.split('Error:')[-1].strip()[:100]}")

    print("\n" + "="*80)

    # Return exit code
    return 0 if passed == total_tests else 1


if __name__ == "__main__":
    # Run tests with custom result handling
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    results = runner.run(suite)

    # Generate report and exit
    exit_code = generate_test_report(results)
    sys.exit(exit_code)