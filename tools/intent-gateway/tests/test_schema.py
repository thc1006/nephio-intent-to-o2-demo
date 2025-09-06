"""
Test suite for TMF921 Intent schema validation.

This module tests JSON schema validation against the TMF921 v5.0 specification.
All tests should FAIL initially (RED phase of TDD) until validation logic is implemented.
"""

import json
from pathlib import Path
from typing import Any

import pytest

# These imports will fail until the implementation exists (TDD RED phase)
from intent_gateway.validator import TMF921Validator, ValidationError


class TestTMF921SchemaValidation:
    """Test TMF921 v5.0 JSON Schema validation functionality."""

    @pytest.fixture
    def validator(self) -> TMF921Validator:
        """Create TMF921Validator instance with schema loaded from guardrails."""
        schema_path = (
            Path(__file__).parent.parent.parent.parent / "guardrails" / "schemas" / "tmf921.json"
        )
        return TMF921Validator(schema_path)

    @pytest.fixture
    def valid_intent_data(self) -> dict[str, Any]:
        """Load valid TMF921 intent sample."""
        sample_path = Path(__file__).parent.parent / "samples" / "tmf921" / "valid_01.json"
        with open(sample_path) as f:
            return json.load(f)

    @pytest.fixture
    def invalid_intent_data(self) -> dict[str, Any]:
        """Load invalid TMF921 intent sample."""
        sample_path = Path(__file__).parent.parent / "samples" / "tmf921" / "invalid_01.json"
        with open(sample_path) as f:
            return json.load(f)

    def test_validator_loads_schema_successfully(self, validator: TMF921Validator):
        """Test that validator can load TMF921 schema from guardrails."""
        assert validator.schema is not None
        assert isinstance(validator.schema, dict)
        # TMF921 Intent schema should have required fields
        assert "properties" in validator.schema
        assert "required" in validator.schema

    def test_valid_intent_passes_validation(
        self, validator: TMF921Validator, valid_intent_data: dict[str, Any]
    ):
        """Test that a valid TMF921 intent passes schema validation."""
        result = validator.validate(valid_intent_data)
        assert result.is_valid is True
        assert len(result.errors) == 0
        assert result.intent_id is not None

    def test_invalid_intent_fails_validation(
        self, validator: TMF921Validator, invalid_intent_data: dict[str, Any]
    ):
        """Test that an invalid TMF921 intent fails schema validation."""
        result = validator.validate(invalid_intent_data)
        assert result.is_valid is False
        assert len(result.errors) > 0
        assert all(isinstance(error, str) for error in result.errors)

    def test_empty_payload_fails_validation(self, validator: TMF921Validator):
        """Test that empty JSON payload fails validation."""
        with pytest.raises(ValidationError) as exc_info:
            validator.validate({})

        assert "required" in str(exc_info.value).lower()

    def test_malformed_json_raises_validation_error(self, validator: TMF921Validator):
        """Test that malformed data raises ValidationError."""
        with pytest.raises(ValidationError):
            validator.validate("not a dict")

    def test_missing_required_fields_fails_validation(self, validator: TMF921Validator):
        """Test that intent missing required TMF921 fields fails validation."""
        minimal_invalid = {"someField": "someValue"}
        result = validator.validate(minimal_invalid)

        assert result.is_valid is False
        assert any("required" in error.lower() for error in result.errors)

    def test_intent_id_extraction(
        self, validator: TMF921Validator, valid_intent_data: dict[str, Any]
    ):
        """Test that intent ID is correctly extracted from valid intent."""
        result = validator.validate(valid_intent_data)
        assert result.intent_id == valid_intent_data.get("id")

    def test_schema_validation_performance(
        self, validator: TMF921Validator, valid_intent_data: dict[str, Any]
    ):
        """Test that schema validation completes within reasonable time."""
        import time

        start_time = time.time()
        result = validator.validate(valid_intent_data)
        end_time = time.time()

        # Validation should complete within 100ms
        assert (end_time - start_time) < 0.1
        assert result.is_valid is True

    def test_tio_mode_fake_bypasses_validation(self, validator: TMF921Validator):
        """Test that TIO mode 'fake' bypasses actual schema validation."""
        # This should pass even with invalid data when in fake mode
        validator.set_tio_mode("fake")
        result = validator.validate({"invalid": "data"})

        assert result.is_valid is True
        assert "TIO_MODE_FAKE" in result.warnings[0] if result.warnings else True
