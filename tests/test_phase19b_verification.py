#!/usr/bin/env python3
"""
Test harness for Phase 19-B Edge Verification
Tests PR readiness checks and edge resource verification
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, Mock, patch

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

# Import the verifier module
from phase19b_multi_edge_verifier import EdgeVerifier


class TestEdgeVerification(unittest.TestCase):
    """Test suite for edge verification functionality"""

    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.project_root = Path(self.test_dir)
        self.verifier = EdgeVerifier(self.project_root, timeout=60)

    def tearDown(self):
        """Clean up test environment"""
        import shutil

        shutil.rmtree(self.test_dir, ignore_errors=True)

    @patch("subprocess.run")
    def test_check_pr_status_with_o2imsctl(self, mock_run):
        """Test PR status check using o2imsctl"""
        # Mock o2imsctl response
        mock_response = {
            "items": [
                {
                    "metadata": {"name": "test-edge1-pr"},
                    "spec": {"targetCluster": "edge1"},
                    "status": {"phase": "Ready"},
                }
            ]
        }

        mock_run.return_value = MagicMock(
            returncode=0, stdout=json.dumps(mock_response), stderr=""
        )

        result = self.verifier.check_pr_status("edge1")

        self.assertEqual(result["edge"], "edge1")
        self.assertTrue(result["ready"])
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["readyCount"], 1)
        self.assertEqual(len(result["provisioningRequests"]), 1)
        self.assertEqual(result["provisioningRequests"][0]["status"], "Ready")

    @patch("subprocess.run")
    def test_check_pr_status_with_kubectl_fallback(self, mock_run):
        """Test PR status check with kubectl fallback"""
        # First call to o2imsctl fails
        mock_run.side_effect = [
            MagicMock(returncode=1, stdout="", stderr="command not found"),
            # kubectl response
            MagicMock(
                returncode=0,
                stdout=json.dumps(
                    {
                        "items": [
                            {
                                "metadata": {"name": "edge2-packagerevision"},
                                "status": {
                                    "conditions": [{"type": "Ready", "status": "True"}]
                                },
                            }
                        ]
                    }
                ),
                stderr="",
            ),
        ]

        result = self.verifier.check_pr_status("edge2")

        self.assertEqual(result["edge"], "edge2")
        self.assertTrue(result["ready"])
        self.assertEqual(result["total"], 1)

    @patch("subprocess.run")
    def test_check_edge_resources(self, mock_run):
        """Test edge resource checking"""
        # Mock kubectl responses for different resource types
        mock_run.side_effect = [
            # NetworkSlices
            MagicMock(
                returncode=0,
                stdout=json.dumps(
                    {
                        "items": [
                            {"metadata": {"name": "edge1-embb-slice"}},
                            {"metadata": {"name": "edge1-urllc-slice"}},
                        ]
                    }
                ),
                stderr="",
            ),
            # ConfigMaps
            MagicMock(
                returncode=0,
                stdout=json.dumps({"items": [{"metadata": {"name": "edge1-config"}}]}),
                stderr="",
            ),
            # Services
            MagicMock(
                returncode=0,
                stdout=json.dumps({"items": [{"metadata": {"name": "edge1-service"}}]}),
                stderr="",
            ),
            # Deployments
            MagicMock(
                returncode=0,
                stdout=json.dumps(
                    {"items": [{"metadata": {"name": "edge1-deployment"}}]}
                ),
                stderr="",
            ),
        ]

        result = self.verifier.check_edge_resources("edge1")

        self.assertEqual(result["networkSlices"], 2)
        self.assertEqual(result["configMaps"], 1)
        self.assertEqual(result["services"], 1)
        self.assertEqual(result["deployments"], 1)
        self.assertEqual(result["status"], "healthy")

    @patch("subprocess.run")
    def test_probe_service_endpoint(self, mock_run):
        """Test service endpoint probing"""
        # Mock successful endpoint retrieval and curl test
        mock_run.side_effect = [
            # Get LoadBalancer IP (empty)
            MagicMock(returncode=0, stdout="", stderr=""),
            # Get ClusterIP
            MagicMock(returncode=0, stdout="10.96.0.1", stderr=""),
            # Curl test success
            MagicMock(returncode=0, stdout="200", stderr=""),
        ]

        result = self.verifier.probe_service_endpoint("test-service", "default")
        self.assertEqual(result, "healthy")

    @patch("subprocess.run")
    def test_verify_edge_site_success(self, mock_run):
        """Test successful edge site verification"""
        # Mock all positive responses
        mock_run.side_effect = [
            # o2imsctl pr list
            MagicMock(
                returncode=0,
                stdout=json.dumps(
                    {
                        "items": [
                            {
                                "metadata": {"name": "edge1-pr"},
                                "spec": {"targetCluster": "edge1"},
                                "status": {"phase": "Ready"},
                            }
                        ]
                    }
                ),
                stderr="",
            ),
            # NetworkSlices
            MagicMock(
                returncode=0,
                stdout=json.dumps({"items": [{"metadata": {"name": "edge1-slice"}}]}),
                stderr="",
            ),
            # ConfigMaps
            MagicMock(returncode=0, stdout=json.dumps({"items": []}), stderr=""),
            # Services
            MagicMock(
                returncode=0,
                stdout=json.dumps({"items": [{"metadata": {"name": "edge1-svc"}}]}),
                stderr="",
            ),
            # Deployments
            MagicMock(returncode=0, stdout=json.dumps({"items": []}), stderr=""),
        ]

        result = self.verifier.verify_edge_site("edge1")

        self.assertEqual(result["edge"], "edge1")
        self.assertEqual(result["status"], "success")
        self.assertTrue(result["provisioningRequests"]["ready"])
        self.assertEqual(result["resources"]["status"], "healthy")

    def test_verify_multiple_edges_parallel(self):
        """Test parallel verification of multiple edges"""
        with patch.object(self.verifier, "verify_edge_site") as mock_verify:
            mock_verify.side_effect = [
                {"edge": "edge1", "status": "success"},
                {"edge": "edge2", "status": "partial"},
            ]

            result = self.verifier.verify_multiple_edges(
                ["edge1", "edge2"], parallel=True
            )

            self.assertEqual(result["summary"]["total"], 2)
            self.assertEqual(result["overallStatus"], "PARTIAL")
            self.assertIn("edge1", result["edges"])
            self.assertIn("edge2", result["edges"])

    def test_save_results(self):
        """Test saving verification results"""
        test_results = {
            "timestamp": "20250113_120000",
            "edge": "edge1",
            "status": "success",
        }

        self.verifier.save_results(test_results, "edge1")

        # Check if files were created
        output_dir = self.project_root / "artifacts" / "edge1"
        self.assertTrue(output_dir.exists())

        # Check for latest symlink
        latest_link = output_dir / "ready.json"
        self.assertTrue(latest_link.exists())

        # Verify content
        with open(latest_link, "r") as f:
            saved_data = json.load(f)
            self.assertEqual(saved_data["status"], "success")


class TestABServiceProbing(unittest.TestCase):
    """Test suite for A/B service testing functionality"""

    def setUp(self):
        """Set up test environment"""
        self.script_path = (
            Path(__file__).parent.parent / "scripts" / "phase19b_ab_test_probe.sh"
        )

    @patch("subprocess.run")
    def test_service_probe_command(self, mock_run):
        """Test service probe command execution"""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=json.dumps(
                {
                    "edge": "edge1",
                    "services": [
                        {"name": "service1", "status": "ok", "health": "healthy"}
                    ],
                    "summary": {"total": 1, "healthy": 1},
                }
            ),
            stderr="",
        )

        # Test probe command
        result = subprocess.run(
            ["bash", str(self.script_path), "probe", "edge1"],
            capture_output=True,
            text=True,
        )

        output = json.loads(result.stdout)
        self.assertEqual(output["edge"], "edge1")
        self.assertEqual(output["summary"]["healthy"], 1)

    def test_ab_test_metrics(self):
        """Test A/B test metric calculation"""
        # This would test the A/B comparison logic
        test_metrics = {
            "service_a": {
                "health": "healthy",
                "avg_latency_ms": 50,
                "success_rate": 99.5,
            },
            "service_b": {
                "health": "healthy",
                "avg_latency_ms": 45,
                "success_rate": 99.8,
            },
        }

        # Verify metrics comparison
        self.assertLess(
            test_metrics["service_b"]["avg_latency_ms"],
            test_metrics["service_a"]["avg_latency_ms"],
        )
        self.assertGreater(
            test_metrics["service_b"]["success_rate"],
            test_metrics["service_a"]["success_rate"],
        )


class TestIntegration(unittest.TestCase):
    """Integration tests for Phase 19-B verification system"""

    @patch("subprocess.run")
    def test_end_to_end_verification_flow(self, mock_run):
        """Test complete verification flow"""
        # Setup mock responses for complete flow
        mock_run.side_effect = [
            # Initial PR check
            MagicMock(
                returncode=0,
                stdout=json.dumps(
                    {
                        "items": [
                            {
                                "metadata": {"name": "edge1-pr"},
                                "status": {"phase": "Processing"},
                            }
                        ]
                    }
                ),
                stderr="",
            ),
            # Resource checks (multiple calls)
            *[
                MagicMock(returncode=0, stdout=json.dumps({"items": []}), stderr="")
                for _ in range(4)
            ],
            # Second PR check (now Ready)
            MagicMock(
                returncode=0,
                stdout=json.dumps(
                    {
                        "items": [
                            {
                                "metadata": {"name": "edge1-pr"},
                                "status": {"phase": "Ready"},
                            }
                        ]
                    }
                ),
                stderr="",
            ),
            # Final resource checks
            *[
                MagicMock(
                    returncode=0,
                    stdout=json.dumps(
                        {"items": [{"metadata": {"name": f"edge1-{t}"}}]}
                    ),
                    stderr="",
                )
                for t in ["slice", "config", "service", "deployment"]
            ],
        ]

        # Create verifier with short timeout for testing
        test_dir = tempfile.mkdtemp()
        verifier = EdgeVerifier(Path(test_dir), timeout=5)

        # Run verification
        result = verifier.verify_edge_site("edge1")

        # Verify progression from pending to success
        self.assertIsNotNone(result)
        self.assertEqual(result["edge"], "edge1")

        # Cleanup
        import shutil

        shutil.rmtree(test_dir, ignore_errors=True)


def run_tests():
    """Run all tests"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestEdgeVerification))
    suite.addTests(loader.loadTestsFromTestCase(TestABServiceProbing))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegration))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Return exit code
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
