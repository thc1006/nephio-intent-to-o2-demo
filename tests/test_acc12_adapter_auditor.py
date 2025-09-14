#!/usr/bin/env python3
"""
ACC-12 Test Suite: JSON-only & Schema Validation (含 targetSite) - TDD Implementation
Role: @adapter-auditor

This test suite follows Test-Driven Development principles:
1. Write failing tests first (RED phase)
2. Implement minimal functionality to make tests pass (GREEN phase)
3. Refactor while keeping tests green (REFACTOR phase)

Goal: Validate /generate_intent returns JSON-only and matches schema (service, qos, slice, targetSite).
Expected artifact: artifacts/adapter/acc12_schema_report.json
"""

import json
import os
import uuid
from datetime import datetime
from typing import Any, Dict, List

import jsonschema
import pytest
import requests
from jsonschema import ValidationError, validate


class TestACC12AdapterAuditor:
    """Test suite for ACC-12: JSON-only & Schema validation with targetSite"""

    BASE_URL = "http://localhost:8888"  # VM-3 LLM Adapter endpoint
    SCHEMA_PATH = "/home/ubuntu/nephio-intent-to-o2-demo/adapter/app/schema.json"
    ARTIFACTS_DIR = "/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter"
    REPORT_FILE = "acc12_schema_report.json"

    @pytest.fixture(autouse=True)
    def setup_test_environment(self):
        """Setup test environment and load schema"""
        # Ensure artifacts directory exists
        os.makedirs(self.ARTIFACTS_DIR, exist_ok=True)

        # Load TMF921 schema
        with open(self.SCHEMA_PATH, "r") as f:
            self.schema = json.load(f)

    def get_nl_test_examples(self) -> List[Dict[str, Any]]:
        """Get 3 natural language examples for testing"""
        return [
            {
                "id": "nl_001",
                "description": "eMBB service for edge1",
                "natural_language": "Deploy a 5G network slice with high bandwidth for video streaming at edge site 1",
                "expected_target_site": "edge1",
                "expected_service_type": "eMBB",
            },
            {
                "id": "nl_002",
                "description": "URLLC service for edge2",
                "natural_language": "Create ultra-low latency service for autonomous driving at edge2 with 1ms latency",
                "expected_target_site": "edge2",
                "expected_service_type": "URLLC",
            },
            {
                "id": "nl_003",
                "description": "mMTC service for both sites",
                "natural_language": "Setup IoT monitoring network for massive sensor deployment across both edge sites",
                "expected_target_site": "both",
                "expected_service_type": "mMTC",
            },
        ]

    def test_endpoint_exists_and_responds(self):
        """TDD RED: Test that /generate_intent endpoint exists (will fail initially)"""
        try:
            response = requests.get(f"{self.BASE_URL}/health", timeout=5)
            # This test will FAIL initially until the endpoint is implemented
            assert response.status_code == 200, "Health endpoint should be available"
        except requests.exceptions.ConnectionError:
            pytest.fail("LLM Adapter service is not running at http://localhost:8888")

    def test_generate_intent_endpoint_accepts_post(self):
        """TDD RED: Test that /generate_intent accepts POST requests (will fail initially)"""
        test_payload = {"natural_language": "test request", "target_site": "edge1"}

        try:
            response = requests.post(
                f"{self.BASE_URL}/generate_intent", json=test_payload, timeout=10
            )
            # This test will FAIL initially until POST endpoint is implemented
            assert response.status_code in [200, 400, 422], "POST endpoint should exist"
        except requests.exceptions.ConnectionError:
            pytest.fail("Cannot connect to /generate_intent endpoint")

    def test_json_only_response_nl_001(self):
        """TDD RED: Test NL example 1 returns JSON-only response (will fail initially)"""
        examples = self.get_nl_test_examples()
        example = examples[0]  # eMBB for edge1

        payload = {
            "natural_language": example["natural_language"],
            "target_site": example["expected_target_site"],
        }

        response = requests.post(
            f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
        )

        # This test will FAIL initially
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert response.headers.get("content-type", "").startswith("application/json")

        # Verify response is valid JSON
        try:
            intent_data = response.json()
        except json.JSONDecodeError:
            pytest.fail("Response is not valid JSON")

        # Store for schema validation
        self._store_response_for_validation(
            "nl_001", intent_data.get("intent", intent_data), example
        )

    def test_json_only_response_nl_002(self):
        """TDD RED: Test NL example 2 returns JSON-only response (will fail initially)"""
        examples = self.get_nl_test_examples()
        example = examples[1]  # URLLC for edge2

        payload = {
            "natural_language": example["natural_language"],
            "target_site": example["expected_target_site"],
        }

        response = requests.post(
            f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
        )

        # This test will FAIL initially
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert response.headers.get("content-type", "").startswith("application/json")

        try:
            intent_data = response.json()
        except json.JSONDecodeError:
            pytest.fail("Response is not valid JSON")

        self._store_response_for_validation(
            "nl_002", intent_data.get("intent", intent_data), example
        )

    def test_json_only_response_nl_003(self):
        """TDD RED: Test NL example 3 returns JSON-only response (will fail initially)"""
        examples = self.get_nl_test_examples()
        example = examples[2]  # mMTC for both sites

        payload = {
            "natural_language": example["natural_language"],
            "target_site": example["expected_target_site"],
        }

        response = requests.post(
            f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
        )

        # This test will FAIL initially
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert response.headers.get("content-type", "").startswith("application/json")

        try:
            intent_data = response.json()
        except json.JSONDecodeError:
            pytest.fail("Response is not valid JSON")

        self._store_response_for_validation(
            "nl_003", intent_data.get("intent", intent_data), example
        )

    def test_schema_validation_service_field(self):
        """TDD RED: Test that response contains valid 'service' field (will fail initially)"""
        examples = self.get_nl_test_examples()

        for i, example in enumerate(examples):
            payload = {
                "natural_language": example["natural_language"],
                "target_site": example["expected_target_site"],
            }

            response = requests.post(
                f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
            )

            assert response.status_code == 200
            intent_data = response.json()
            intent = intent_data.get("intent", intent_data)
            test_id = f"nl_{i+1:03d}"

            # This test will FAIL initially until service field is properly implemented
            assert "service" in intent, f"Missing 'service' field in {test_id}"
            assert isinstance(
                intent["service"], dict
            ), f"'service' must be object in {test_id}"
            assert "name" in intent["service"], f"Missing service.name in {test_id}"
            assert "type" in intent["service"], f"Missing service.type in {test_id}"
            assert intent["service"]["type"] in [
                "eMBB",
                "URLLC",
                "mMTC",
                "generic",
            ], f"Invalid service.type in {test_id}"

    def test_schema_validation_qos_field(self):
        """TDD RED: Test that response contains valid 'qos' field (will fail initially)"""
        examples = self.get_nl_test_examples()

        for i, example in enumerate(examples):
            payload = {
                "natural_language": example["natural_language"],
                "target_site": example["expected_target_site"],
            }

            response = requests.post(
                f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
            )

            assert response.status_code == 200
            intent_data = response.json()
            intent = intent_data.get("intent", intent_data)
            test_id = f"nl_{i+1:03d}"

            # This test will FAIL initially until qos field is properly implemented
            if "qos" in intent:
                qos = intent["qos"]
                assert isinstance(qos, dict), f"'qos' must be object in {test_id}"

                # Check QoS field types if present
                numeric_fields = [
                    "dl_mbps",
                    "ul_mbps",
                    "latency_ms",
                    "jitter_ms",
                    "packet_loss_rate",
                ]
                for field in numeric_fields:
                    if field in qos:
                        assert isinstance(
                            qos[field], (int, float, type(None))
                        ), f"qos.{field} must be numeric in {test_id}"

    def test_schema_validation_slice_field(self):
        """TDD RED: Test that response contains valid 'slice' field (will fail initially)"""
        examples = self.get_nl_test_examples()

        for i, example in enumerate(examples):
            payload = {
                "natural_language": example["natural_language"],
                "target_site": example["expected_target_site"],
            }

            response = requests.post(
                f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
            )

            assert response.status_code == 200
            intent_data = response.json()
            intent = intent_data.get("intent", intent_data)
            test_id = f"nl_{i+1:03d}"

            # This test will FAIL initially until slice field is properly implemented
            if "slice" in intent:
                slice_info = intent["slice"]
                assert isinstance(
                    slice_info, dict
                ), f"'slice' must be object in {test_id}"

                if "sst" in slice_info:
                    assert isinstance(
                        slice_info["sst"], int
                    ), f"slice.sst must be integer in {test_id}"
                    assert (
                        0 <= slice_info["sst"] <= 255
                    ), f"slice.sst out of range in {test_id}"

    def test_schema_validation_target_site_field(self):
        """TDD RED: Test that response contains valid 'targetSite' field (will fail initially)"""
        examples = self.get_nl_test_examples()

        for i, example in enumerate(examples):
            payload = {
                "natural_language": example["natural_language"],
                "target_site": example["expected_target_site"],
            }

            response = requests.post(
                f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
            )

            assert response.status_code == 200
            intent_data = response.json()
            intent = intent_data.get("intent", intent_data)
            test_id = f"nl_{i+1:03d}"

            # This test will FAIL initially until targetSite is properly implemented
            assert "targetSite" in intent, f"Missing 'targetSite' field in {test_id}"
            assert intent["targetSite"] in [
                "edge1",
                "edge2",
                "both",
            ], f"Invalid targetSite value in {test_id}"
            assert (
                intent["targetSite"] == example["expected_target_site"]
            ), f"targetSite mismatch in {test_id}"

    def test_full_schema_validation_all_examples(self):
        """TDD RED: Test full schema validation against TMF921 schema (will fail initially)"""
        examples = self.get_nl_test_examples()
        validation_results = {}

        for i, example in enumerate(examples):
            test_id = f"nl_{i+1:03d}"
            payload = {
                "natural_language": example["natural_language"],
                "target_site": example["expected_target_site"],
            }

            response = requests.post(
                f"{self.BASE_URL}/generate_intent", json=payload, timeout=15
            )

            assert response.status_code == 200
            intent_data = response.json()
            intent = intent_data.get("intent", intent_data)

            try:
                # This will FAIL initially until full TMF921 compliance is achieved
                validate(instance=intent, schema=self.schema)
                validation_results[test_id] = {"status": "PASS", "errors": None}
            except ValidationError as e:
                validation_results[test_id] = {"status": "FAIL", "errors": str(e)}

        # Generate report
        self._generate_acc12_report(validation_results)

        # Assert all validations passed
        failed_tests = [
            tid
            for tid, result in validation_results.items()
            if result["status"] == "FAIL"
        ]
        assert len(failed_tests) == 0, f"Schema validation failed for: {failed_tests}"

    def test_non_json_input_returns_400(self):
        """TDD RED: Test that non-JSON input returns HTTP 400 (will fail initially)"""
        # Test with invalid JSON
        response = requests.post(
            f"{self.BASE_URL}/generate_intent",
            data="invalid json input",
            headers={"Content-Type": "application/json"},
            timeout=10,
        )

        # FastAPI returns 422 for validation errors, which is correct for invalid JSON
        assert response.status_code in [
            400,
            422,
        ], f"Expected 400 or 422 for invalid JSON, got {response.status_code}"

    def test_empty_natural_language_returns_400(self):
        """TDD RED: Test that empty natural_language returns HTTP 400 (will fail initially)"""
        payload = {"natural_language": "", "target_site": "edge1"}

        response = requests.post(
            f"{self.BASE_URL}/generate_intent", json=payload, timeout=10
        )

        # FastAPI/Pydantic returns 422 for validation errors, which is correct for empty input
        assert response.status_code in [
            400,
            422,
        ], f"Expected 400 or 422 for empty input, got {response.status_code}"

    def _store_response_for_validation(
        self, test_id: str, response_data: Dict[str, Any], expected: Dict[str, Any]
    ):
        """Store response data for schema validation"""
        if not hasattr(self, "_validation_data"):
            self._validation_data = {}

        self._validation_data[test_id] = {
            "response": response_data,
            "expected": expected,
        }

    def _generate_acc12_report(self, validation_results: Dict[str, Dict[str, Any]]):
        """Generate ACC-12 validation report"""
        report = {
            "test_suite": "ACC-12",
            "role": "@adapter-auditor",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "goal": "Validate /generate_intent returns JSON-only and matches schema (service, qos, slice, targetSite)",
            "endpoint": f"{self.BASE_URL}/generate_intent",
            "schema_path": self.SCHEMA_PATH,
            "test_results": validation_results,
            "summary": {
                "total_tests": len(validation_results),
                "passed": len(
                    [r for r in validation_results.values() if r["status"] == "PASS"]
                ),
                "failed": len(
                    [r for r in validation_results.values() if r["status"] == "FAIL"]
                ),
                "success_rate": len(
                    [r for r in validation_results.values() if r["status"] == "PASS"]
                )
                / len(validation_results)
                if validation_results
                else 0,
            },
            "natural_language_examples": self.get_nl_test_examples(),
            "schema_requirements": {
                "required_fields": ["intentId", "name", "service", "targetSite"],
                "service_types": ["eMBB", "URLLC", "mMTC", "generic"],
                "target_sites": ["edge1", "edge2", "both"],
                "qos_fields": [
                    "dl_mbps",
                    "ul_mbps",
                    "latency_ms",
                    "jitter_ms",
                    "packet_loss_rate",
                ],
                "slice_fields": ["sst", "sd", "plmn"],
            },
        }

        report_path = os.path.join(self.ARTIFACTS_DIR, self.REPORT_FILE)
        with open(report_path, "w") as f:
            json.dump(report, f, indent=2)

        print(f"ACC-12 validation report generated: {report_path}")


if __name__ == "__main__":
    # Run tests with detailed output
    pytest.main([__file__, "-v", "--tb=short"])
