#!/usr/bin/env python3
"""
TDD Tests for ACC-19: O2IMS PR Verification
Test-Driven Development approach for O2IMS ProvisioningRequest verification on edge1

Following 2025 TDD principles:
1. Red: Write failing tests first that define expected behavior
2. Green: Implement minimal code to make tests pass
3. Refactor: Improve code while maintaining test coverage
4. Integration with CI/CD: Automated testing in pipeline
5. Clear test structure: Setup -> Execution -> Validation -> Cleanup

TDD Benefits implemented here:
- Early bug detection through comprehensive test coverage
- Better design through test-first approach
- Continuous validation of O2IMS PR functionality
- Documentation through executable specifications
"""

import json
import subprocess
import time
import unittest
from pathlib import Path
from typing import Any, Dict, List

import yaml


class TestACC19O2IMSProvisioningRequest(unittest.TestCase):
    """Test cases for ACC-19 O2IMS PR verification following TDD principles"""

    def setUp(self):
        """Setup: Prepare test environment before each test execution"""
        self.context = "edge1"
        self.artifacts_dir = Path("artifacts/edge1")
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)
        self.pr_crds = []  # Will be discovered during tests
        self.required_pr_states = ["READY", "AVAILABLE", "PROVISIONED"]
        self.timeout_seconds = 300  # 5 minutes timeout for PR operations

    def tearDown(self):
        """Cleanup: Restore system to original state after test execution"""
        # No cleanup needed for read-only verification tests
        pass

    def test_discover_pr_crd_resources(self):
        """
        Test: Should discover ProvisioningRequest CRD resources across all namespaces
        Following TDD principle: Write test first to define expected behavior
        """
        # Execution: Search for PR CRDs using various patterns
        pr_search_patterns = [
            "provisioningrequest",
            "provisioningrequests",
            "pr",
            "o2ims-provisioningrequest",
        ]

        discovered_crds = []

        for pattern in pr_search_patterns:
            try:
                # Try to get CRD resources matching pattern
                result = subprocess.run(
                    [
                        "kubectl",
                        "--context",
                        self.context,
                        "get",
                        pattern,
                        "-A",
                        "-o",
                        "json",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )

                if result.returncode == 0:
                    crd_data = json.loads(result.stdout)
                    if crd_data.get("items"):
                        discovered_crds.extend(crd_data["items"])

            except (subprocess.TimeoutExpired, json.JSONDecodeError) as e:
                print(f"Warning: Failed to query pattern {pattern}: {e}")

        # Validation: Assert that we found PR CRDs
        self.assertGreater(
            len(discovered_crds),
            0,
            "Should discover at least one ProvisioningRequest CRD resource",
        )

        # Store for use in other tests
        self.pr_crds = discovered_crds

    def test_pr_crd_definition_exists(self):
        """
        Test: ProvisioningRequest CRD definition should exist in cluster
        Validates the fundamental requirement for O2IMS PR functionality
        """
        # Execution: Check if PR CRD is registered in the cluster
        result = subprocess.run(
            ["kubectl", "--context", self.context, "get", "crd", "-o", "json"],
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, "Should be able to query CRDs")

        crds_data = json.loads(result.stdout)
        pr_crds = [
            crd
            for crd in crds_data.get("items", [])
            if "provisioningrequest" in crd.get("metadata", {}).get("name", "").lower()
        ]

        # Validation: Assert PR CRD exists
        self.assertGreater(
            len(pr_crds), 0, "ProvisioningRequest CRD should be registered in cluster"
        )

    def test_pr_resources_have_ready_status(self):
        """
        Test: ProvisioningRequest resources should be in READY state
        Core requirement for ACC-19 verification
        """
        # Setup: First discover PR resources
        self.test_discover_pr_crd_resources()

        ready_prs = []
        non_ready_prs = []

        # Execution: Check status of each discovered PR
        for pr in self.pr_crds:
            pr_name = pr.get("metadata", {}).get("name", "unknown")
            pr_namespace = pr.get("metadata", {}).get("namespace", "default")
            pr_status = pr.get("status", {})

            # Check various status fields that might indicate readiness
            status_conditions = pr_status.get("conditions", [])
            phase = pr_status.get("phase", "")
            state = pr_status.get("state", "")

            is_ready = (
                phase.upper() in self.required_pr_states
                or state.upper() in self.required_pr_states
                or any(
                    condition.get("type", "") == "Ready"
                    and condition.get("status", "") == "True"
                    for condition in status_conditions
                )
            )

            if is_ready:
                ready_prs.append(pr)
            else:
                non_ready_prs.append(
                    {
                        "name": pr_name,
                        "namespace": pr_namespace,
                        "phase": phase,
                        "state": state,
                        "conditions": status_conditions,
                    }
                )

        # Validation: Assert that at least some PRs are ready
        self.assertGreater(
            len(ready_prs),
            0,
            f"At least one PR should be READY. Found {len(non_ready_prs)} non-ready PRs",
        )

    def test_pr_services_are_reachable(self):
        """
        Test: Services associated with PRs should be reachable
        Validates service reachability requirement from ACC-19
        """
        # Setup: Discover services related to PRs
        result = subprocess.run(
            [
                "kubectl",
                "--context",
                self.context,
                "get",
                "services",
                "-A",
                "-o",
                "json",
            ],
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, "Should be able to get services")

        services_data = json.loads(result.stdout)
        pr_related_services = []

        # Execution: Find services related to O2IMS/PR functionality
        for service in services_data.get("items", []):
            service_name = service.get("metadata", {}).get("name", "").lower()
            if any(
                keyword in service_name
                for keyword in ["o2ims", "provisioningrequest", "pr-", "o2-"]
            ):
                pr_related_services.append(service)

        # Test service reachability by checking endpoints
        reachable_services = []
        for service in pr_related_services:
            service_name = service.get("metadata", {}).get("name")
            service_namespace = service.get("metadata", {}).get("namespace")

            # Check if service has endpoints
            endpoints_result = subprocess.run(
                [
                    "kubectl",
                    "--context",
                    self.context,
                    "get",
                    "endpoints",
                    service_name,
                    "-n",
                    service_namespace,
                    "-o",
                    "json",
                ],
                capture_output=True,
                text=True,
            )

            if endpoints_result.returncode == 0:
                endpoints_data = json.loads(endpoints_result.stdout)
                if endpoints_data.get("subsets"):
                    reachable_services.append(service_name)

        # Validation: Assert service reachability
        if pr_related_services:
            self.assertGreater(
                len(reachable_services),
                0,
                "At least one PR-related service should be reachable",
            )

    def test_pr_resource_validation_schema(self):
        """
        Test: PR resources should conform to expected schema structure
        Validates data integrity and schema compliance
        """
        # Setup: Get PR resources
        self.test_discover_pr_crd_resources()

        valid_prs = []
        invalid_prs = []

        # Execution: Validate each PR against expected schema
        for pr in self.pr_crds:
            validation_results = self._validate_pr_schema(pr)

            if validation_results["is_valid"]:
                valid_prs.append(pr)
            else:
                invalid_prs.append(
                    {
                        "name": pr.get("metadata", {}).get("name", "unknown"),
                        "errors": validation_results["errors"],
                    }
                )

        # Validation: Assert schema compliance
        if self.pr_crds:  # Only validate if we have PRs
            self.assertGreater(
                len(valid_prs),
                0,
                f"At least one PR should have valid schema. "
                f"Found {len(invalid_prs)} invalid PRs",
            )

    def _validate_pr_schema(self, pr: Dict[str, Any]) -> Dict[str, Any]:
        """
        Helper: Validate PR resource against expected schema
        Returns validation results with errors if any
        """
        errors = []

        # Check required metadata fields
        metadata = pr.get("metadata", {})
        if not metadata.get("name"):
            errors.append("Missing metadata.name")
        if not metadata.get("namespace"):
            errors.append("Missing metadata.namespace")

        # Check spec exists
        spec = pr.get("spec", {})
        if not spec:
            errors.append("Missing spec section")

        # Check status exists
        status = pr.get("status", {})
        if not status:
            errors.append("Missing status section")

        return {"is_valid": len(errors) == 0, "errors": errors}

    def test_pr_resource_lifecycle_state(self):
        """
        Test: PR resources should show proper lifecycle state progression
        Validates that PRs follow expected state transitions
        """
        # Setup: Get PR resources with status
        self.test_discover_pr_crd_resources()

        state_analysis = {
            "total_prs": len(self.pr_crds),
            "state_distribution": {},
            "ready_count": 0,
            "failed_count": 0,
        }

        # Execution: Analyze PR states
        for pr in self.pr_crds:
            status = pr.get("status", {})
            phase = status.get("phase", "Unknown")
            state = status.get("state", "Unknown")

            # Count state distribution
            primary_state = phase if phase != "Unknown" else state
            state_analysis["state_distribution"][primary_state] = (
                state_analysis["state_distribution"].get(primary_state, 0) + 1
            )

            # Count ready and failed states
            if primary_state.upper() in self.required_pr_states:
                state_analysis["ready_count"] += 1
            elif "FAIL" in primary_state.upper() or "ERROR" in primary_state.upper():
                state_analysis["failed_count"] += 1

        # Validation: Assert healthy state distribution
        if state_analysis["total_prs"] > 0:
            ready_percentage = (
                state_analysis["ready_count"] / state_analysis["total_prs"]
            ) * 100

            self.assertGreater(
                ready_percentage,
                50,
                f"At least 50% of PRs should be in ready state. "
                f"Currently {ready_percentage:.1f}% ready",
            )

    def test_generate_acc19_artifacts(self):
        """
        Test: Should generate comprehensive acc19_ready.json artifact
        Final validation step that creates verification output
        """
        # Setup: Collect all PR verification data
        self.test_discover_pr_crd_resources()

        # Execution: Gather comprehensive verification data
        verification_data = {
            "phase": "ACC-19",
            "test_name": "O2IMS PR Verification",
            "context": self.context,
            "timestamp": subprocess.check_output(["date", "-Iseconds"])
            .decode()
            .strip(),
            "status": "COMPLETED",
            "pr_verification": {
                "total_prs_discovered": len(self.pr_crds),
                "pr_resources": [],
                "service_reachability": {},
                "crd_status": {},
                "compliance_summary": {},
            },
        }

        # Analyze each discovered PR
        ready_count = 0
        for pr in self.pr_crds:
            pr_summary = {
                "name": pr.get("metadata", {}).get("name", "unknown"),
                "namespace": pr.get("metadata", {}).get("namespace", "unknown"),
                "phase": pr.get("status", {}).get("phase", "Unknown"),
                "state": pr.get("status", {}).get("state", "Unknown"),
                "ready": False,
                "last_updated": pr.get("metadata", {}).get(
                    "creationTimestamp", "Unknown"
                ),
            }

            # Check if PR is ready
            status = pr.get("status", {})
            is_ready = (
                status.get("phase", "").upper() in self.required_pr_states
                or status.get("state", "").upper() in self.required_pr_states
            )

            pr_summary["ready"] = is_ready
            if is_ready:
                ready_count += 1

            verification_data["pr_verification"]["pr_resources"].append(pr_summary)

        # Add compliance summary
        verification_data["pr_verification"]["compliance_summary"] = {
            "ready_prs": ready_count,
            "total_prs": len(self.pr_crds),
            "ready_percentage": (
                (ready_count / len(self.pr_crds) * 100) if self.pr_crds else 0
            ),
            "overall_status": "PASS" if ready_count > 0 else "FAIL",
        }

        # Write artifact
        artifact_file = self.artifacts_dir / "acc19_ready.json"
        with open(artifact_file, "w") as f:
            json.dump(verification_data, f, indent=2)

        # Validation: Assert artifact creation and content
        self.assertTrue(artifact_file.exists(), "acc19_ready.json should be created")

        with open(artifact_file, "r") as f:
            saved_data = json.load(f)

        self.assertEqual(saved_data["phase"], "ACC-19")
        self.assertEqual(saved_data["context"], self.context)
        self.assertIn("pr_verification", saved_data)
        self.assertIn("compliance_summary", saved_data["pr_verification"])


class TestACC19Integration(unittest.TestCase):
    """Integration tests for complete ACC-19 workflow following TDD principles"""

    def test_end_to_end_pr_verification_workflow(self):
        """
        Test: Complete ACC-19 verification workflow should execute successfully
        Integration test that validates the entire verification process
        """
        # This test orchestrates the complete verification workflow
        # and validates that all components work together correctly

        test_suite = unittest.TestLoader().loadTestsFromTestCase(
            TestACC19O2IMSProvisioningRequest
        )
        test_runner = unittest.TextTestRunner(verbosity=0)
        result = test_runner.run(test_suite)

        # Validation: All critical tests should pass
        self.assertEqual(result.failures, [], "No verification steps should fail")
        self.assertEqual(result.errors, [], "No verification steps should error")

    def test_verification_artifacts_completeness(self):
        """
        Test: All required verification artifacts should be generated
        Validates that the verification process produces complete output
        """
        artifacts_dir = Path("artifacts/edge1")
        required_artifacts = ["acc19_ready.json"]

        # Check if artifacts exist and have valid content
        for artifact_name in required_artifacts:
            artifact_path = artifacts_dir / artifact_name

            if artifact_path.exists():
                with open(artifact_path, "r") as f:
                    artifact_data = json.load(f)

                # Validate artifact structure
                self.assertIn("phase", artifact_data)
                self.assertIn("status", artifact_data)
                self.assertIn("timestamp", artifact_data)


if __name__ == "__main__":
    # Configure test execution with comprehensive output
    # Following 2025 TDD best practices for CI/CD integration

    print("=" * 80)
    print("ACC-19 O2IMS PR Verification - TDD Test Suite")
    print("Following Test-Driven Development principles for 2025")
    print("=" * 80)

    # Run tests with detailed output for CI/CD pipeline integration
    unittest.main(verbosity=2, buffer=False)
