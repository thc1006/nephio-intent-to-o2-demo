"""
Test suite for intent-gateway CLI interface.

This module tests the command-line interface behavior including exit codes,
JSON error output, and deterministic CLI operations.
All tests should FAIL initially (RED phase of TDD) until CLI is implemented.
"""

import json
import os
import subprocess
from pathlib import Path

import pytest


class TestIntentGatewayCLI:
    """Test intent-gateway CLI command behavior and exit codes."""

    @pytest.fixture
    def cli_path(self) -> Path:
        """Path to the intent-gateway CLI script."""
        return Path(__file__).parent.parent / "intent_gateway" / "cli.py"

    @pytest.fixture
    def valid_sample_path(self) -> Path:
        """Path to valid TMF921 sample file."""
        return Path(__file__).parent.parent / "samples" / "tmf921" / "valid_01.json"

    @pytest.fixture
    def invalid_sample_path(self) -> Path:
        """Path to invalid TMF921 sample file."""
        return Path(__file__).parent.parent / "samples" / "tmf921" / "invalid_01.json"

    def run_cli(self, args: list[str], deterministic: bool = False) -> subprocess.CompletedProcess:
        """Helper to run CLI with given arguments."""
        cmd = ["python3", "-m", "intent_gateway.cli"] + args
        env = {**os.environ, "PYTHONPATH": str(Path(__file__).parent.parent)}
        if deterministic:
            env["INTENT_GATEWAY_DETERMINISTIC"] = "true"
        return subprocess.run(
            cmd, capture_output=True, text=True, cwd=Path(__file__).parent.parent, env=env
        )

    def test_cli_help_command_exits_zero(self):
        """Test that --help command exits with code 0."""
        result = self.run_cli(["--help"])
        assert result.returncode == 0
        assert "intent-gateway" in result.stdout
        assert "validate" in result.stdout

    def test_cli_version_command_exits_zero(self):
        """Test that --version command exits with code 0."""
        result = self.run_cli(["--version"])
        assert result.returncode == 0
        assert "intent-gateway" in result.stdout

    def test_valid_file_with_fake_tio_exits_zero(self, valid_sample_path: Path):
        """Test that valid file with --tio-mode fake exits with code 0."""
        result = self.run_cli(["validate", "--file", str(valid_sample_path), "--tio-mode", "fake"])

        assert result.returncode == 0

        # Should output JSON with success status
        output_data = json.loads(result.stdout)
        assert output_data["status"] == "valid"
        assert output_data["intent_id"] is not None
        assert output_data["tio_mode"] == "fake"

    def test_valid_file_without_tio_mode_exits_zero(self, valid_sample_path: Path):
        """Test that valid file without --tio-mode exits with code 0."""
        result = self.run_cli(["validate", "--file", str(valid_sample_path)])

        assert result.returncode == 0

        # Should output JSON with success status
        output_data = json.loads(result.stdout)
        assert output_data["status"] == "valid"
        assert output_data["intent_id"] is not None
        assert "tio_mode" not in output_data or output_data["tio_mode"] == "strict"

    def test_invalid_file_exits_two_with_json_error(self, invalid_sample_path: Path):
        """Test that invalid file exits with code 2 and outputs JSON error."""
        result = self.run_cli(["validate", "--file", str(invalid_sample_path)])

        assert result.returncode == 2

        # Should output JSON with error details
        output_data = json.loads(result.stdout)
        assert output_data["status"] == "invalid"
        assert "errors" in output_data
        assert len(output_data["errors"]) > 0
        assert all(isinstance(error, str) for error in output_data["errors"])

    def test_missing_file_exits_one_with_error(self):
        """Test that missing file exits with code 1 and outputs JSON error."""
        result = self.run_cli(["validate", "--file", "/nonexistent/file.json"])

        assert result.returncode == 1

        # Should output JSON with file error
        output_data = json.loads(result.stdout)
        assert output_data["status"] == "error"
        assert "file not found" in output_data["message"].lower()

    def test_malformed_json_file_exits_one_with_error(self, tmp_path: Path):
        """Test that malformed JSON file exits with code 1 and outputs JSON error."""
        malformed_file = tmp_path / "malformed.json"
        malformed_file.write_text("{ invalid json ")

        result = self.run_cli(["validate", "--file", str(malformed_file)])

        assert result.returncode == 1

        # Should output JSON with parse error
        output_data = json.loads(result.stdout)
        assert output_data["status"] == "error"
        assert "json" in output_data["message"].lower()

    def test_no_arguments_shows_usage_exits_one(self):
        """Test that CLI with no arguments shows usage and exits with code 1."""
        result = self.run_cli([])

        assert result.returncode == 1
        assert "usage" in result.stderr.lower() or "usage" in result.stdout.lower()

    def test_unknown_command_exits_one(self):
        """Test that unknown command exits with code 1."""
        result = self.run_cli(["unknown-command"])

        assert result.returncode == 1

    def test_validate_command_without_file_exits_one(self):
        """Test that validate command without --file exits with code 1."""
        result = self.run_cli(["validate"])

        assert result.returncode == 1

        # Should show error about missing --file argument
        error_output = result.stderr or result.stdout
        assert "--file" in error_output.lower() or "required" in error_output.lower()

    def test_cli_output_is_deterministic(self, valid_sample_path: Path):
        """Test that CLI output is deterministic across multiple runs."""
        results = []
        for _ in range(3):
            result = self.run_cli(
                ["validate", "--file", str(valid_sample_path), "--tio-mode", "fake"],
                deterministic=True,
            )
            results.append(result.stdout)

        # All outputs should be identical (deterministic)
        assert all(output == results[0] for output in results[1:])

    def test_cli_json_output_format(self, valid_sample_path: Path):
        """Test that CLI outputs valid JSON format."""
        result = self.run_cli(["validate", "--file", str(valid_sample_path), "--tio-mode", "fake"])

        assert result.returncode == 0

        # Should be valid JSON
        output_data = json.loads(result.stdout)

        # Required fields in JSON output
        assert "status" in output_data
        assert "intent_id" in output_data

        # Timestamp should be ISO 8601 format if present
        if "timestamp" in output_data:
            from datetime import datetime

            datetime.fromisoformat(output_data["timestamp"].replace("Z", "+00:00"))

    def test_verbose_flag_provides_additional_output(self, valid_sample_path: Path):
        """Test that --verbose flag provides additional diagnostic output."""
        result_normal = self.run_cli(["validate", "--file", str(valid_sample_path)])

        result_verbose = self.run_cli(["validate", "--file", str(valid_sample_path), "--verbose"])

        assert result_normal.returncode == 0
        assert result_verbose.returncode == 0

        # Verbose output should contain additional information
        normal_data = json.loads(result_normal.stdout)
        verbose_data = json.loads(result_verbose.stdout)

        assert len(verbose_data.keys()) >= len(normal_data.keys())
        assert "validation_details" in verbose_data or "debug_info" in verbose_data
