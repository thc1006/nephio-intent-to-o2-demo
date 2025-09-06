"""
RED tests for TMF921 Intent validation (WF-A)
TDD: These tests must fail initially
"""


class TestTMF921Validation:
    """TMF921 Intent structure validation"""

    def test_validate_intent_schema(self):
        """Validate TMF921 intent against JSON schema"""
        # RED: validator module doesn't exist yet
        from intent_gateway.validator import TMF921Validator

        validator = TMF921Validator()
        valid_intent = {
            "id": "intent-001",
            "href": "/intentManagement/v1/intent/intent-001",
            "name": "Deploy 5G Network Slice",
            "description": "Intent for ultra-reliable low latency slice",
            "intentType": "NetworkSliceIntent",
            "state": "acknowledged",
            "@baseType": "Intent",
            "@type": "NetworkSliceIntent",
            "intentSpecification": {
                "id": "spec-urllc-slice",
                "name": "URLLC_Slice_Spec",
                "version": "1.0.0"
            },
        }

        result = validator.validate(valid_intent)
        assert result.is_valid is True
        assert result.errors == []

    def test_reject_invalid_intent_missing_required(self):
        """Reject intent missing required fields"""
        # RED: validator module doesn't exist yet
        from intent_gateway.validator import TMF921Validator

        validator = TMF921Validator()
        invalid_intent = {
            "name": "Incomplete Intent"
            # Missing: id, href, category, intentSpecification
        }

        result = validator.validate(invalid_intent)
        assert result.is_valid is False
        assert "id" in str(result.errors)
        assert "intentType" in str(result.errors)

    def test_validate_intent_expectations(self):
        """Validate intent expectations/outcomes"""
        # RED: expectations parser doesn't exist yet
        from intent_gateway.expectations import ExpectationParser

        parser = ExpectationParser()
        intent_with_expectations = {
            "id": "intent-002",
            "expectation": [
                {
                    "id": "exp-001",
                    "name": "Latency Expectation",
                    "expectationType": "DeliveryExpectation",
                    "targetCondition": "latency <= 1 ms",
                    "targetValue": {
                        "value": "1",
                        "unit": "ms"
                    },
                }
            ],
        }

        expectations = parser.parse(intent_with_expectations)
        assert len(expectations) == 1
        assert expectations[0].kpi_name == "latency"
        assert expectations[0].is_measurable() is True

    def test_tio_ctk_compliance(self):
        """Validate against TM Forum Intent NRM CTK"""
        # RED: TIO compliance checker doesn't exist yet
        from intent_gateway.compliance import TIOComplianceChecker

        checker = TIOComplianceChecker(mode="fake")  # Use fake mode for testing
        intent = {
            "id": "intent-003",
            "@type": "Intent",
            "@schemaLocation": "https://mycsp.com/tmf921/intent.schema.json",
            "lifecycleStatus": "feasibilityChecked",
        }

        result = checker.check_compliance(intent)
        assert result.compliant is True
        assert result.api_version == "TMF921-v4.0.0"

    def test_cli_validation_command(self):
        """Test CLI validates and returns proper exit codes"""
        # RED: CLI doesn't exist yet
        import subprocess

        # Valid intent should exit 0
        result = subprocess.run(
            [
                "python3",
                "-m",
                "intent_gateway",
                "validate",
                "--file",
                "samples/tmf921/valid_01.json",
                "--tio-mode",
                "fake",
            ],
            capture_output=True,
        )
        assert result.returncode == 0

        # Invalid intent should exit 2 (validation error)
        result = subprocess.run(
            [
                "python3",
                "-m",
                "intent_gateway",
                "validate",
                "--file",
                "samples/tmf921/invalid_01.json",
                "--tio-mode",
                "strict",  # Use strict mode to actually validate
            ],
            capture_output=True,
        )
        assert result.returncode == 2
