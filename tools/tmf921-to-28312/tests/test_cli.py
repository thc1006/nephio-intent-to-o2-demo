"""
Test CLI functionality for TMF921 to 3GPP TS 28.312 converter.

This module tests the command-line interface functionality.
Following TDD: these tests are written first and should FAIL initially.
"""

import json
import tempfile
import sys
import pytest
from pathlib import Path
from unittest.mock import patch, mock_open, MagicMock
from argparse import Namespace

from tmf921_to_28312.cli import (
    main,
    convert_command,
    validate_command,
    create_artifacts_dir
)
from tmf921_to_28312.converter import ConversionError


class TestCreateArtifactsDir:
    """Test artifacts directory creation."""
    
    def test_create_artifacts_dir_success(self):
        """Test successful creation of artifacts directory."""
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            artifacts_dir = create_artifacts_dir(output_dir)
            
            assert artifacts_dir.exists()
            assert artifacts_dir.is_dir()
            assert artifacts_dir.name == "artifacts"
            assert artifacts_dir.parent == output_dir
    
    def test_create_artifacts_dir_already_exists(self):
        """Test artifacts directory creation when it already exists."""
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            existing_artifacts = output_dir / "artifacts"
            existing_artifacts.mkdir()
            
            artifacts_dir = create_artifacts_dir(output_dir)
            
            assert artifacts_dir.exists()
            assert artifacts_dir == existing_artifacts


class TestConvertCommand:
    """Test the convert command functionality."""
    
    def test_convert_command_success(self):
        """Test successful conversion command execution."""
        # This should fail initially - CLI functionality not fully tested
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "input.json"
            output_dir = Path(temp_dir) / "output"
            output_dir.mkdir()
            
            # Create a simple TMF921 intent file
            sample_intent = {
                "id": "test-intent-001",
                "intentType": "ServiceIntent",
                "name": "Test Intent",
                "intentSpecification": {
                    "intentExpectations": [
                        {
                            "expectationType": "deliver",
                            "expectationTargets": [
                                {
                                    "targetName": "latency",
                                    "targetCondition": "lessThan",
                                    "targetValue": "5",
                                    "targetUnit": "ms"
                                }
                            ]
                        }
                    ]
                }
            }
            
            with open(input_file, 'w') as f:
                json.dump(sample_intent, f)
            
            # Create arguments namespace
            args = Namespace(
                input=str(input_file),
                output=str(output_dir),
                mapping=None
            )
            
            # Execute command
            result = convert_command(args)
            
            assert result == 0  # Success exit code
            
            # Check output files exist
            artifacts_dir = output_dir / "artifacts"
            assert (artifacts_dir / "expectation.json").exists()
            assert (artifacts_dir / "report_skeleton.json").exists()
            assert (artifacts_dir / "delta.json").exists()
    
    def test_convert_command_file_not_found(self):
        """Test convert command with non-existent input file."""
        args = Namespace(
            input="/nonexistent/file.json",
            output=None,
            mapping=None
        )
        
        result = convert_command(args)
        assert result == 1  # Error exit code
    
    def test_convert_command_invalid_json(self):
        """Test convert command with invalid JSON input."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "invalid.json"
            
            # Write invalid JSON
            with open(input_file, 'w') as f:
                f.write('{"id": "test", invalid json}')
            
            args = Namespace(
                input=str(input_file),
                output=None,
                mapping=None
            )
            
            result = convert_command(args)
            assert result == 1  # Error exit code
    
    def test_convert_command_conversion_failure(self):
        """Test convert command when conversion fails."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "unsupported.json"
            
            # Create intent with unsupported type
            unsupported_intent = {
                "id": "test-intent-002",
                "intentType": "UnsupportedType",
                "intentSpecification": {}
            }
            
            with open(input_file, 'w') as f:
                json.dump(unsupported_intent, f)
            
            args = Namespace(
                input=str(input_file),
                output=None,
                mapping=None
            )
            
            result = convert_command(args)
            assert result == 1  # Error exit code
    
    def test_convert_command_with_custom_mapping(self):
        """Test convert command with custom mapping file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "input.json"
            mapping_file = Path(temp_dir) / "mapping.yaml"
            
            # Create sample files
            sample_intent = {
                "id": "test-intent-003",
                "intentType": "ServiceIntent",
                "intentSpecification": {"intentExpectations": []}
            }
            
            custom_mapping = """
target_conditions:
  lessThan: "LESS_THAN"
expectation_types:
  deliver: "ServicePerformance"
object_types:
  service: "Service"
unmapped_fields: []
"""
            
            with open(input_file, 'w') as f:
                json.dump(sample_intent, f)
            
            with open(mapping_file, 'w') as f:
                f.write(custom_mapping)
            
            args = Namespace(
                input=str(input_file),
                output=None,
                mapping=str(mapping_file)
            )
            
            result = convert_command(args)
            assert result == 0  # Success exit code


class TestValidateCommand:
    """Test the validate command functionality."""
    
    def test_validate_command_success(self):
        """Test successful validation command execution."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "valid.json"
            
            # Create valid TMF921 intent
            valid_intent = {
                "id": "test-intent-004",
                "intentType": "ServiceIntent",
                "name": "Valid Intent",
                "intentSpecification": {
                    "intentExpectations": [
                        {
                            "expectationType": "deliver",
                            "expectationTargets": [{"targetName": "latency"}]
                        }
                    ]
                }
            }
            
            with open(input_file, 'w') as f:
                json.dump(valid_intent, f)
            
            args = Namespace(input=str(input_file))
            
            result = validate_command(args)
            assert result == 0  # Success exit code
    
    def test_validate_command_missing_required_fields(self):
        """Test validate command with missing required fields."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "invalid.json"
            
            # Create intent missing required fields
            invalid_intent = {
                "name": "Incomplete Intent"
                # Missing id, intentType, intentSpecification
            }
            
            with open(input_file, 'w') as f:
                json.dump(invalid_intent, f)
            
            args = Namespace(input=str(input_file))
            
            result = validate_command(args)
            assert result == 1  # Error exit code
    
    def test_validate_command_no_expectations(self):
        """Test validate command with no expectations."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "no_expectations.json"
            
            # Create intent without expectations
            intent_without_expectations = {
                "id": "test-intent-005",
                "intentType": "ServiceIntent",
                "intentSpecification": {}  # No intentExpectations
            }
            
            with open(input_file, 'w') as f:
                json.dump(intent_without_expectations, f)
            
            args = Namespace(input=str(input_file))
            
            result = validate_command(args)
            assert result == 1  # Error exit code
    
    def test_validate_command_empty_expectations(self):
        """Test validate command with empty expectations array."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "empty_expectations.json"
            
            # Create intent with empty expectations
            intent_empty_expectations = {
                "id": "test-intent-006",
                "intentType": "ServiceIntent",
                "intentSpecification": {
                    "intentExpectations": []  # Empty array
                }
            }
            
            with open(input_file, 'w') as f:
                json.dump(intent_empty_expectations, f)
            
            args = Namespace(input=str(input_file))
            
            result = validate_command(args)
            assert result == 1  # Error exit code
    
    def test_validate_command_file_not_found(self):
        """Test validate command with non-existent file."""
        args = Namespace(input="/nonexistent/file.json")
        
        result = validate_command(args)
        assert result == 1  # Error exit code


class TestMainCLI:
    """Test the main CLI entry point."""
    
    @patch('sys.argv', ['tmf921-to-28312', 'convert', '--input', 'test.json'])
    def test_main_convert_command(self):
        """Test main CLI with convert command."""
        # This should fail initially - main function integration not fully tested
        with patch('tmf921_to_28312.cli.convert_command') as mock_convert:
            mock_convert.return_value = 0
            
            with pytest.raises(SystemExit) as exc_info:
                main()
            
            assert exc_info.value.code == 0
            mock_convert.assert_called_once()
    
    @patch('sys.argv', ['tmf921-to-28312', 'validate', '--input', 'test.json'])
    def test_main_validate_command(self):
        """Test main CLI with validate command."""
        with patch('tmf921_to_28312.cli.validate_command') as mock_validate:
            mock_validate.return_value = 0
            
            with pytest.raises(SystemExit) as exc_info:
                main()
            
            assert exc_info.value.code == 0
            mock_validate.assert_called_once()
    
    @patch('sys.argv', ['tmf921-to-28312'])
    def test_main_no_command(self):
        """Test main CLI with no command - should show help."""
        with patch('argparse.ArgumentParser.print_help') as mock_help:
            with pytest.raises(SystemExit) as exc_info:
                main()
            
            assert exc_info.value.code == 1
            mock_help.assert_called_once()
    
    @patch('sys.argv', ['tmf921-to-28312', '--help'])
    def test_main_help_option(self):
        """Test main CLI with help option."""
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 0


class TestCliIntegration:
    """Integration tests for CLI with real sample files."""
    
    def test_cli_with_sample_file(self):
        """Test CLI conversion with actual sample file."""
        # This should fail initially - integration with actual files not tested
        sample_file = Path("samples/tmf921/valid_01.json")
        
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            
            args = Namespace(
                input=str(sample_file),
                output=str(output_dir),
                mapping=None
            )
            
            result = convert_command(args)
            assert result == 0
            
            # Verify output files
            artifacts_dir = output_dir / "artifacts"
            expectation_file = artifacts_dir / "expectation.json"
            report_file = artifacts_dir / "report_skeleton.json"
            delta_file = artifacts_dir / "delta.json"
            
            assert expectation_file.exists()
            assert report_file.exists()
            assert delta_file.exists()
            
            # Verify file contents are valid JSON
            with open(expectation_file) as f:
                expectations = json.load(f)
                assert isinstance(expectations, list)
                assert len(expectations) > 0
            
            with open(report_file) as f:
                reports = json.load(f)
                assert isinstance(reports, list)
            
            with open(delta_file) as f:
                delta = json.load(f)
                assert "unmapped_fields" in delta
                assert "conversion_summary" in delta


class TestErrorHandling:
    """Test CLI error handling scenarios."""
    
    def test_unexpected_error_handling(self):
        """Test CLI handles unexpected errors gracefully."""
        with patch('tmf921_to_28312.cli.load_tmf921_intent') as mock_load:
            mock_load.side_effect = Exception("Unexpected error")
            
            args = Namespace(
                input="test.json",
                output=None,
                mapping=None
            )
            
            result = convert_command(args)
            assert result == 1  # Error exit code
    
    def test_keyboard_interrupt_handling(self):
        """Test CLI handles keyboard interrupt gracefully."""
        with patch('tmf921_to_28312.cli.load_tmf921_intent') as mock_load:
            mock_load.side_effect = KeyboardInterrupt()
            
            args = Namespace(
                input="test.json",
                output=None,
                mapping=None
            )
            
            with pytest.raises(KeyboardInterrupt):
                convert_command(args)


class TestOutputFormatting:
    """Test CLI output formatting and messaging."""
    
    @patch('builtins.print')
    def test_convert_success_output_formatting(self, mock_print):
        """Test that convert command produces properly formatted output."""
        with tempfile.TemporaryDirectory() as temp_dir:
            input_file = Path(temp_dir) / "test.json"
            
            sample_intent = {
                "id": "test-007",
                "intentType": "ServiceIntent",
                "intentSpecification": {"intentExpectations": []}
            }
            
            with open(input_file, 'w') as f:
                json.dump(sample_intent, f)
            
            args = Namespace(
                input=str(input_file),
                output=None,
                mapping=None
            )
            
            result = convert_command(args)
            assert result == 0
            
            # Check that informative messages were printed
            mock_print.assert_called()
            printed_messages = [call.args[0] for call in mock_print.call_args_list]
            
            # Should contain loading, conversion, and output messages
            loading_msgs = [msg for msg in printed_messages if "Loading TMF921" in msg]
            conversion_msgs = [msg for msg in printed_messages if "Conversion successful" in msg]
            output_msgs = [msg for msg in printed_messages if "Wrote" in msg]
            
            assert len(loading_msgs) > 0
            assert len(conversion_msgs) > 0
            assert len(output_msgs) > 0