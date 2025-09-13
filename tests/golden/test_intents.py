#!/usr/bin/env python3
"""Golden tests for intent-to-KRM translation."""

import json
import yaml
import os
import sys
import subprocess
import tempfile
from pathlib import Path
import unittest

class TestIntentToKRM(unittest.TestCase):
    """Test intent translation with golden files."""

    def setUp(self):
        """Set up test environment."""
        self.test_dir = Path(__file__).parent
        self.project_root = self.test_dir.parent.parent
        self.translator = self.project_root / "tools" / "intent-compiler" / "translate.py"
        self.output_dir = tempfile.mkdtemp(prefix="test-krm-")

    def tearDown(self):
        """Clean up test files."""
        import shutil
        if os.path.exists(self.output_dir):
            shutil.rmtree(self.output_dir)

    def test_edge1_intent(self):
        """Test translation of edge1 intent."""
        intent_file = self.test_dir.parent / "intent_edge1.json"
        self._run_translation_test(intent_file, ["edge1"])

    def test_edge2_intent(self):
        """Test translation of edge2 intent (URLLC)."""
        # Create edge2 intent
        edge2_intent = {
            "intentId": "test-003",
            "serviceType": "ultra-reliable-low-latency",
            "targetSite": "edge2",
            "resourceProfile": "premium",
            "sla": {
                "availability": 99.999,
                "latency": 1,
                "throughput": 5000
            }
        }

        intent_file = Path(self.output_dir) / "intent_edge2.json"
        with open(intent_file, 'w') as f:
            json.dump(edge2_intent, f, indent=2)

        self._run_translation_test(intent_file, ["edge2"])

    def test_both_sites_intent(self):
        """Test translation of intent targeting both sites."""
        intent_file = self.test_dir.parent / "intent_both.json"
        self._run_translation_test(intent_file, ["edge1", "edge2"])

    def _run_translation_test(self, intent_file, expected_sites):
        """Run translation and validate output."""
        # Run translator
        result = subprocess.run(
            [sys.executable, str(self.translator), str(intent_file), "-o", self.output_dir],
            capture_output=True,
            text=True
        )

        self.assertEqual(result.returncode, 0, f"Translation failed: {result.stderr}")

        # Verify outputs for each expected site
        for site in expected_sites:
            site_dir = Path(self.output_dir) / site
            self.assertTrue(site_dir.exists(), f"Site directory {site} not created")

            # Check required files exist
            self._validate_site_resources(site_dir, site)

    def _validate_site_resources(self, site_dir, site):
        """Validate resources for a specific site."""
        # Find and validate ProvisioningRequest
        pr_files = list(site_dir.glob("*-provisioning-request.yaml"))
        self.assertGreater(len(pr_files), 0, f"No ProvisioningRequest found for {site}")

        with open(pr_files[0], 'r') as f:
            pr = yaml.safe_load(f)
            self._validate_provisioning_request(pr, site)

        # Find and validate ConfigMap
        cm_files = list(site_dir.glob("*-configmap.yaml"))
        self.assertGreater(len(cm_files), 0, f"No ConfigMap found for {site}")

        with open(cm_files[0], 'r') as f:
            cm = yaml.safe_load(f)
            self._validate_configmap(cm, site)

        # Find and validate NetworkSlice
        ns_files = list(site_dir.glob("*-networkslice.yaml"))
        self.assertGreater(len(ns_files), 0, f"No NetworkSlice found for {site}")

        with open(ns_files[0], 'r') as f:
            ns = yaml.safe_load(f)
            self._validate_network_slice(ns, site)

        # Validate Kustomization
        kustomization_file = site_dir / "kustomization.yaml"
        self.assertTrue(kustomization_file.exists(), f"No kustomization.yaml for {site}")

        with open(kustomization_file, 'r') as f:
            kustomization = yaml.safe_load(f)
            self._validate_kustomization(kustomization, site)

    def _validate_provisioning_request(self, pr, site):
        """Validate ProvisioningRequest structure."""
        self.assertEqual(pr["apiVersion"], "o2ims.provisioning.oran.org/v1alpha1")
        self.assertEqual(pr["kind"], "ProvisioningRequest")
        self.assertIn("metadata", pr)
        self.assertIn("spec", pr)

        # Check site-specific values
        self.assertEqual(pr["metadata"]["labels"]["target-site"], site)
        self.assertIn("targetCluster", pr["spec"])
        self.assertIn("networkConfig", pr["spec"])
        self.assertIn("resourceRequirements", pr["spec"])

    def _validate_configmap(self, cm, site):
        """Validate ConfigMap structure."""
        self.assertEqual(cm["apiVersion"], "v1")
        self.assertEqual(cm["kind"], "ConfigMap")
        self.assertIn("data", cm)
        self.assertIn("intent.json", cm["data"])
        self.assertEqual(cm["data"]["site"], site)

    def _validate_network_slice(self, ns, site):
        """Validate NetworkSlice structure."""
        self.assertEqual(ns["apiVersion"], "workload.nephio.org/v1alpha1")
        self.assertEqual(ns["kind"], "NetworkSlice")
        self.assertEqual(ns["metadata"]["labels"]["target-site"], site)
        self.assertIn("sliceType", ns["spec"])
        self.assertIn("plmn", ns["spec"])

    def _validate_kustomization(self, kustomization, site):
        """Validate Kustomization structure."""
        self.assertEqual(kustomization["apiVersion"], "kustomize.config.k8s.io/v1beta1")
        self.assertEqual(kustomization["kind"], "Kustomization")
        self.assertIn("resources", kustomization)
        self.assertEqual(kustomization["commonLabels"]["target-site"], site)


class TestKubeconformValidation(unittest.TestCase):
    """Validate generated KRM with kubeconform."""

    def setUp(self):
        """Check if kubeconform is available."""
        self.kubeconform_available = subprocess.run(
            ["which", "kubeconform"],
            capture_output=True
        ).returncode == 0

    def test_validate_generated_resources(self):
        """Validate all generated YAML files with kubeconform."""
        if not self.kubeconform_available:
            self.skipTest("kubeconform not installed")

        # Generate test resources first
        test_dir = Path(__file__).parent
        project_root = test_dir.parent.parent
        translator = project_root / "tools" / "intent-compiler" / "translate.py"
        output_dir = tempfile.mkdtemp(prefix="test-krm-validation-")

        try:
            # Generate resources for test intent
            intent_file = test_dir.parent / "intent_edge1.json"
            result = subprocess.run(
                [sys.executable, str(translator), str(intent_file), "-o", output_dir],
                capture_output=True,
                text=True
            )
            self.assertEqual(result.returncode, 0)

            # Run kubeconform on generated files
            yaml_files = list(Path(output_dir).glob("**/*.yaml"))
            for yaml_file in yaml_files:
                # Skip kustomization files
                if yaml_file.name == "kustomization.yaml":
                    continue

                result = subprocess.run(
                    ["kubeconform", "-skip-kinds", "NetworkSlice,ProvisioningRequest", str(yaml_file)],
                    capture_output=True,
                    text=True
                )

                self.assertIn("PASS", result.stdout + result.stderr,
                             f"Validation failed for {yaml_file}: {result.stderr}")

        finally:
            import shutil
            if os.path.exists(output_dir):
                shutil.rmtree(output_dir)


if __name__ == "__main__":
    unittest.main()