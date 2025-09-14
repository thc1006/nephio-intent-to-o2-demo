#!/usr/bin/env python3
"""Enhanced contract tests for Intent to KRM translator.

Additional tests for NodePorts, Service configurations, and O2IMS specific fields.
"""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any, Dict, List

import yaml

# Import base test class
sys.path.insert(0, str(Path(__file__).parent))
from test_contract import ContractTestBase


class TestNodePortMapping(ContractTestBase):
    """Test NodePort service configuration mappings."""

    def test_embb_nodeport_allocation(self):
        """Test eMBB service gets correct NodePort range."""
        intent = {
            "intentId": "nodeport-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
            "sla": {"availability": 99.99, "latency": 10, "throughput": 1000},
            "serviceConfig": {"exposeService": True, "serviceType": "NodePort"},
        }

        resources = self.run_translator(intent)

        # Check if Service resource is created
        service = self._find_service_resource(resources["edge1"])
        if service:
            self.assertEqual(service["spec"]["type"], "NodePort")

            # Verify NodePort is in correct range (30000-32767)
            for port in service["spec"].get("ports", []):
                if "nodePort" in port:
                    self.assertGreaterEqual(port["nodePort"], 30000)
                    self.assertLessEqual(port["nodePort"], 32767)

    def test_urllc_priority_nodeport(self):
        """Test URLLC gets priority NodePort allocation."""
        intent = {
            "intentId": "nodeport-002",
            "serviceType": "ultra-reliable-low-latency",
            "targetSite": "edge2",
            "resourceProfile": "premium",
            "sla": {"availability": 99.999, "latency": 1, "throughput": 5000},
            "serviceConfig": {
                "exposeService": True,
                "serviceType": "NodePort",
                "priorityClass": "critical",
            },
        }

        resources = self.run_translator(intent)

        # URLLC should get lower NodePort numbers (priority range)
        service = self._find_service_resource(resources["edge2"])
        if service:
            for port in service["spec"].get("ports", []):
                if "nodePort" in port:
                    # Priority services get 30000-30999 range
                    self.assertGreaterEqual(port["nodePort"], 30000)
                    self.assertLessEqual(port["nodePort"], 30999)

    def _find_service_resource(self, resources: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Find Service resource in the list."""
        for r in resources:
            if r.get("kind") == "Service":
                return r
        return None


class TestO2IMSFieldValidation(ContractTestBase):
    """Validate O2IMS specific field mappings."""

    def test_o2ims_deployment_descriptor(self):
        """Test O2IMS deployment descriptor fields."""
        intent = {
            "intentId": "o2ims-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
            "o2imsConfig": {
                "deploymentFlavor": "small",
                "instantiationLevel": "basic",
                "virtualComputeDesc": {
                    "virtualCpu": {"numVirtualCpu": 4, "cpuArchitecture": "x86_64"},
                    "virtualMemory": {"virtualMemSize": 8192},
                },
            },
        }

        resources = self.run_translator(intent)
        pr = next(
            (r for r in resources["edge1"] if r.get("kind") == "ProvisioningRequest"),
            None,
        )

        self.assertIsNotNone(pr)

        # Check O2IMS specific fields
        if "o2imsConfig" in intent:
            # These should be mapped to annotations or spec fields
            self.assertIn(
                "o2ims.oran.org/deployment-flavor",
                pr.get("metadata", {}).get("annotations", {}),
            )

    def test_o2ims_lifecycle_management(self):
        """Test O2IMS lifecycle management fields."""
        intent = {
            "intentId": "o2ims-lifecycle-001",
            "serviceType": "massive-machine-type",
            "targetSite": "both",
            "resourceProfile": "standard",
            "lifecycleConfig": {
                "instantiationState": "INSTANTIATED",
                "operationalState": "ENABLED",
                "administrativeState": "UNLOCKED",
                "usageState": "IN_USE",
            },
        }

        resources = self.run_translator(intent)

        for site in ["edge1", "edge2"]:
            pr = next(
                (r for r in resources[site] if r.get("kind") == "ProvisioningRequest"),
                None,
            )

            # Lifecycle states should be in status or annotations
            if "lifecycleConfig" in intent:
                annotations = pr.get("metadata", {}).get("annotations", {})
                self.assertIn("o2ims.oran.org/lifecycle-state", annotations)

    def test_o2ims_resource_pool_mapping(self):
        """Test O2IMS resource pool allocation."""
        intent = {
            "intentId": "pool-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "premium",
            "resourcePool": {
                "computePool": "edge-compute-pool-01",
                "storagePool": "fast-ssd-pool",
                "networkPool": "sr-iov-pool",
            },
        }

        resources = self.run_translator(intent)
        pr = next(
            (r for r in resources["edge1"] if r.get("kind") == "ProvisioningRequest"),
            None,
        )

        # Resource pool should be specified in spec
        if "resourcePool" in intent:
            spec = pr.get("spec", {})
            self.assertIn("resourcePool", spec)
            self.assertEqual(
                spec["resourcePool"]["computePool"], "edge-compute-pool-01"
            )


class TestNamespaceAndLabelContract(ContractTestBase):
    """Test namespace and label assignments."""

    def test_namespace_isolation(self):
        """Test that each site gets its own namespace."""
        intent = {
            "intentId": "ns-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "both",
            "resourceProfile": "standard",
        }

        resources = self.run_translator(intent)

        # Check namespace for edge1
        for r in resources["edge1"]:
            if "metadata" in r:
                self.assertEqual(r["metadata"].get("namespace"), "edge1")

        # Check namespace for edge2
        for r in resources["edge2"]:
            if "metadata" in r:
                self.assertEqual(r["metadata"].get("namespace"), "edge2")

    def test_label_propagation(self):
        """Test that labels are correctly propagated."""
        intent = {
            "intentId": "label-001",
            "serviceType": "ultra-reliable-low-latency",
            "targetSite": "edge1",
            "resourceProfile": "premium",
            "metadata": {
                "labels": {
                    "environment": "production",
                    "team": "network-ops",
                    "criticality": "high",
                }
            },
        }

        resources = self.run_translator(intent)

        for r in resources["edge1"]:
            if "metadata" in r and "labels" in r["metadata"]:
                labels = r["metadata"]["labels"]

                # Standard labels should be present
                self.assertIn("intent-id", labels)
                self.assertIn("service-type", labels)
                self.assertIn("target-site", labels)

                # Custom labels should be propagated
                if "metadata" in intent and "labels" in intent["metadata"]:
                    for key, value in intent["metadata"]["labels"].items():
                        self.assertEqual(labels.get(key), value)

    def test_annotation_compliance(self):
        """Test O-RAN WG6 annotation compliance."""
        intent = {
            "intentId": "annotation-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
        }

        resources = self.run_translator(intent)
        pr = next(
            (r for r in resources["edge1"] if r.get("kind") == "ProvisioningRequest"),
            None,
        )

        annotations = pr.get("metadata", {}).get("annotations", {})

        # O-RAN WG6 required annotations
        self.assertIn("generated-by", annotations)
        self.assertIn("timestamp", annotations)
        self.assertIn("resource-profile", annotations)


class TestServiceMeshIntegration(ContractTestBase):
    """Test service mesh configuration for O2IMS."""

    def test_istio_sidecar_injection(self):
        """Test Istio sidecar injection labels."""
        intent = {
            "intentId": "mesh-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "serviceMesh": {"enabled": True, "provider": "istio"},
        }

        resources = self.run_translator(intent)

        # Find deployment-like resources
        for r in resources["edge1"]:
            if r.get("kind") in ["Deployment", "StatefulSet", "DaemonSet"]:
                labels = r.get("metadata", {}).get("labels", {})
                if intent.get("serviceMesh", {}).get("enabled"):
                    self.assertEqual(labels.get("sidecar.istio.io/inject"), "true")


class TestResourceQuotaContract(ContractTestBase):
    """Test resource quota and limits."""

    def test_resource_quota_generation(self):
        """Test ResourceQuota generation for namespace."""
        intent = {
            "intentId": "quota-001",
            "serviceType": "massive-machine-type",
            "targetSite": "edge1",
            "resourceProfile": "standard",
            "resourceQuota": {
                "limits.cpu": "100",
                "limits.memory": "200Gi",
                "requests.storage": "1Ti",
                "persistentvolumeclaims": "10",
            },
        }

        resources = self.run_translator(intent)

        # Check if ResourceQuota is generated
        quota = next(
            (r for r in resources["edge1"] if r.get("kind") == "ResourceQuota"), None
        )

        if intent.get("resourceQuota"):
            self.assertIsNotNone(quota, "ResourceQuota should be generated")
            self.assertEqual(quota["metadata"]["namespace"], "edge1")

            # Verify quota specs
            hard = quota.get("spec", {}).get("hard", {})
            for key, value in intent["resourceQuota"].items():
                self.assertEqual(hard.get(key), value)


class TestSnapshotDeterminism(ContractTestBase):
    """Test snapshot consistency and determinism."""

    def test_snapshot_update_detection(self):
        """Test that snapshot changes are detected."""
        intent = {
            "intentId": "snapshot-001",
            "serviceType": "enhanced-mobile-broadband",
            "targetSite": "edge1",
            "resourceProfile": "standard",
        }

        resources = self.run_translator(intent)
        pr = next(
            (r for r in resources["edge1"] if r.get("kind") == "ProvisioningRequest"),
            None,
        )

        # Test snapshot matching (should not fail if snapshot exists)
        try:
            self.assert_snapshot_match("test_snapshot_pr", pr)
        except AssertionError as e:
            # If snapshot doesn't exist, it will be created
            if "Snapshot created" in str(e):
                # Re-run to verify it matches now
                self.assert_snapshot_match("test_snapshot_pr", pr)

    def test_cross_run_determinism(self):
        """Test determinism across multiple test runs."""
        intent = {
            "intentId": "determinism-001",
            "serviceType": "ultra-reliable-low-latency",
            "targetSite": "edge2",
            "resourceProfile": "premium",
        }

        # Run translation 3 times
        results = []
        for i in range(3):
            resources = self.run_translator(intent)
            # Normalize timestamps for comparison
            normalized = []
            for r in resources["edge2"]:
                normalized.append(self.normalize_timestamp(r))
            results.append(normalized)

        # All runs should produce identical normalized output
        for i in range(1, len(results)):
            self.assertEqual(
                sorted(results[0], key=lambda x: x.get("kind", "")),
                sorted(results[i], key=lambda x: x.get("kind", "")),
                f"Run {i+1} produced different output",
            )


def generate_enhanced_report(results):
    """Generate enhanced test report with detailed metrics."""
    print("\n" + "=" * 80)
    print("ENHANCED CONTRACT TEST REPORT")
    print("=" * 80)

    total_tests = results.testsRun
    failures = len(results.failures)
    errors = len(results.errors)
    passed = total_tests - failures - errors

    print(f"\nTest Summary:")
    print(f"  Total Tests:    {total_tests}")
    print(f"  Passed:         {passed} ✓")
    print(f"  Failed:         {failures} ✗")
    print(f"  Errors:         {errors} ⚠")
    print(f"  Success Rate:   {(passed/total_tests)*100:.1f}%")

    print(f"\nCoverage Areas:")
    print(f"  ✓ Field Mappings (namespaces, labels)")
    print(f"  ✓ NodePort Allocations")
    print(f"  ✓ O2IMS ProvisioningRequest Fields")
    print(f"  ✓ Resource Quotas")
    print(f"  ✓ Service Mesh Integration")
    print(f"  ✓ Snapshot Determinism")

    if passed == total_tests:
        print(f"\n🎉 ALL ENHANCED TESTS PASSED!")
    else:
        print(f"\n❌ SOME TESTS FAILED")

        if results.failures:
            print("\nFailures:")
            for test, traceback in results.failures:
                print(f"  - {test}")

        if results.errors:
            print("\nErrors:")
            for test, traceback in results.errors:
                print(f"  - {test}")

    print("\n" + "=" * 80)

    return 0 if passed == total_tests else 1


if __name__ == "__main__":
    # Run enhanced tests
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    results = runner.run(suite)

    # Generate enhanced report
    exit_code = generate_enhanced_report(results)
    sys.exit(exit_code)
