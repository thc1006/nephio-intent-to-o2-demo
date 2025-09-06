"""
TMF921 Intent Validation Module.

Provides JSON Schema validation for TMF921 Intent Management API v5.0 with TIO compatibility.
"""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import jsonschema
from jsonschema import Draft202012Validator


class ValidationError(Exception):
    """Exception raised when validation fails."""

    pass


@dataclass
class ValidationResult:
    """Result of intent validation."""

    is_valid: bool
    intent_id: str | None = None
    errors: list[str] = None
    warnings: list[str] = None

    def __post_init__(self):
        if self.errors is None:
            self.errors = []
        if self.warnings is None:
            self.warnings = []


class TMF921Validator:
    """TMF921 Intent JSON Schema validator with TIO mode support."""

    def __init__(self, schema_path: Path):
        """
        Initialize validator with TMF921 schema.

        Args:
            schema_path: Path to the TMF921 JSON schema file
        """
        self.schema_path = schema_path
        self.schema = self._load_schema()
        self.tio_mode: str | None = None

    def _load_schema(self) -> dict[str, Any]:
        """Load and parse the TMF921 JSON schema."""
        try:
            with open(self.schema_path) as f:
                schema = json.load(f)

            # Validate that the schema itself is valid
            Draft202012Validator.check_schema(schema)
            return schema

        except FileNotFoundError:
            raise ValidationError(f"Schema file not found: {self.schema_path}") from None
        except json.JSONDecodeError as e:
            raise ValidationError(f"Invalid JSON in schema file: {e}") from e
        except jsonschema.SchemaError as e:
            raise ValidationError(f"Invalid JSON schema: {e}") from e

    def set_tio_mode(self, mode: str) -> None:
        """
        Set TIO (Test, Integration, Operations) mode.

        Args:
            mode: TIO mode ('fake' bypasses validation, 'strict' for full validation)
        """
        self.tio_mode = mode

    def validate(self, intent_data: Any) -> ValidationResult:
        """
        Validate intent data against TMF921 schema.

        Args:
            intent_data: Intent data to validate

        Returns:
            ValidationResult with validation status and details

        Raises:
            ValidationError: For critical validation failures
        """
        # Check if input is a dictionary
        if not isinstance(intent_data, dict):
            raise ValidationError("Intent data must be a JSON object (dictionary)")

        # Handle TIO fake mode
        if self.tio_mode == "fake":
            intent_id = intent_data.get("id", "fake-intent-id")
            return ValidationResult(
                is_valid=True,
                intent_id=intent_id,
                warnings=["TIO_MODE_FAKE: Validation bypassed in fake mode"],
            )

        # Perform actual schema validation
        validator = Draft202012Validator(self.schema)
        errors = []

        # Collect all validation errors
        for error in validator.iter_errors(intent_data):
            if error.absolute_path:
                path_str = ".".join(str(p) for p in error.absolute_path)
                error_msg = f"Field '{path_str}': {error.message}"
            else:
                error_msg = error.message
            errors.append(error_msg)

        # Handle empty data specially
        if not intent_data:
            raise ValidationError("Intent data cannot be empty - required fields missing")

        # Extract intent ID if present
        intent_id = intent_data.get("id")

        # Check for validation success
        is_valid = len(errors) == 0

        return ValidationResult(is_valid=is_valid, intent_id=intent_id, errors=errors)
