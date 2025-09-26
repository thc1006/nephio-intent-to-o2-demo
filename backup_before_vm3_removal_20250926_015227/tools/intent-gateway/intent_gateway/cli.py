"""
Intent Gateway CLI Module.

Command-line interface for TMF921 intent validation with deterministic exit codes.
Exit codes: 0 (success), 1 (unexpected error), 2 (validation error).
"""

import json
import os
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import click

from .validator import TMF921Validator, ValidationError


def intent_exit(code: int) -> None:
    """Custom exit function to mark our exits."""
    exc = SystemExit(code)
    exc._intent_gateway_exit = True  # type: ignore
    raise exc


class CLIError(Exception):
    """CLI-specific error with exit code."""

    def __init__(self, message: str, exit_code: int = 1):
        super().__init__(message)
        self.exit_code = exit_code


def output_json(data: dict[str, Any]) -> None:
    """Output JSON data deterministically."""
    click.echo(json.dumps(data, indent=2, sort_keys=True))


def create_error_output(message: str, status: str = "error") -> dict[str, Any]:
    """Create standardized error output."""
    output = {
        "status": status,
        "message": message,
    }

    # Add timestamp unless in deterministic mode (for testing)
    if os.getenv("INTENT_GATEWAY_DETERMINISTIC") != "true":
        output["timestamp"] = datetime.now(timezone.utc).isoformat()

    return output


def create_success_output(
    intent_id: str, tio_mode: str | None = None, verbose: bool = False
) -> dict[str, Any]:
    """Create standardized success output."""
    output = {
        "status": "valid",
        "intent_id": intent_id,
    }

    # Add timestamp unless in deterministic mode (for testing)
    if os.getenv("INTENT_GATEWAY_DETERMINISTIC") != "true":
        output["timestamp"] = datetime.now(timezone.utc).isoformat()

    if tio_mode:
        output["tio_mode"] = tio_mode

    if verbose:
        output["validation_details"] = {
            "schema_version": "TMF921 v5.0.0",
            "validation_mode": tio_mode or "strict",
        }

    return output


def create_validation_error_output(errors: list, intent_id: str | None = None) -> dict[str, Any]:
    """Create standardized validation error output."""
    output = {
        "status": "invalid",
        "errors": errors,
        "intent_id": intent_id,
    }

    # Add timestamp unless in deterministic mode (for testing)
    if os.getenv("INTENT_GATEWAY_DETERMINISTIC") != "true":
        output["timestamp"] = datetime.now(timezone.utc).isoformat()

    return output


@click.group()
@click.version_option(version="0.1.0", prog_name="intent-gateway")
def cli():
    """TMF921 Intent Gateway - Validate TMF921 intents with TIO compatibility."""
    pass


@cli.command()
@click.option(
    "--file",
    "-f",
    required=True,
    type=click.Path(path_type=Path),
    help="Path to JSON file containing TMF921 intent",
)
@click.option(
    "--tio-mode",
    type=click.Choice(["fake", "strict"]),
    help="TIO mode: 'fake' bypasses validation, 'strict' enforces full validation",
)
@click.option(
    "--verbose", "-v", is_flag=True, help="Enable verbose output with additional validation details"
)
def validate(file: Path, tio_mode: str | None, verbose: bool):
    """Validate TMF921 intent against JSON schema."""
    try:
        # Load schema
        schema_path = (
            Path(__file__).parent.parent.parent.parent / "guardrails" / "schemas" / "tmf921.json"
        )
        validator = TMF921Validator(schema_path)

        # Set TIO mode if specified
        if tio_mode:
            validator.set_tio_mode(tio_mode)

        # Check if file exists
        if not file.exists():
            output_json(create_error_output(f"File not found: {file}"))
            intent_exit(1)

        # Load intent file
        try:
            with open(file) as f:
                intent_data = json.load(f)
        except json.JSONDecodeError as e:
            output_json(create_error_output(f"Invalid JSON in file: {e}"))
            intent_exit(1)

        # Validate intent
        result = validator.validate(intent_data)

        if result.is_valid:
            # Success case
            output_json(create_success_output(result.intent_id, tio_mode or "strict", verbose))
            intent_exit(0)
        else:
            # Validation error case
            output_json(create_validation_error_output(result.errors, result.intent_id))
            intent_exit(2)

    except ValidationError as e:
        output_json(create_error_output(str(e)))
        intent_exit(1)
    except Exception as e:
        # Unexpected error
        error_msg = f"Unexpected error: {str(e)}"
        if verbose:
            error_msg += f"\n{traceback.format_exc()}"
        output_json(create_error_output(error_msg))
        intent_exit(1)


def main():
    """Main CLI entry point."""
    try:
        cli(prog_name="intent-gateway")
    except SystemExit as e:
        # Only convert Click's usage error exit code 2 to 1
        # Our validation error exit code 2 should remain as 2
        # We can distinguish them by checking if we've already called sys.exit(2)
        # in our code vs Click's usage errors
        if e.code == 2 and not hasattr(e, "_intent_gateway_exit"):
            # This is a Click usage error, convert to exit code 1
            sys.exit(1)
        else:
            # This is our validation error or other exit, preserve it
            raise
    except Exception as e:
        # Catch any other unexpected exceptions
        output_json(create_error_output(f"Unexpected CLI error: {str(e)}"))
        sys.exit(1)


if __name__ == "__main__":
    main()
