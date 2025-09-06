"""CLI entry point for TMF921 to 3GPP TS 28.312 converter.

This module provides the command-line interface for the intent converter.
Generates three outputs:
- expectation.json: 3GPP 28.312 minimal IntentExpectation structure
- report_skeleton.json: 3GPP IntentReport stub
- delta.json: Field-by-field gaps with textual rationale
"""

import json
import sys
import argparse
from pathlib import Path
from typing import NoReturn, Optional

from .converter import TMF921To28312Converter, load_tmf921_intent, ConversionError


def create_artifacts_dir(output_dir: Path) -> Path:
    """Create artifacts directory for outputs."""
    artifacts_dir = output_dir / "artifacts"
    artifacts_dir.mkdir(exist_ok=True)
    return artifacts_dir


def convert_command(args: argparse.Namespace) -> int:
    """Handle the convert command."""
    try:
        # Load TMF921 intent
        print(f"Loading TMF921 intent from: {args.input}")
        tmf921_intent = load_tmf921_intent(Path(args.input))
        print(f"Loaded intent: {tmf921_intent.get('id', 'unknown')} ({tmf921_intent.get('intentType', 'unknown')})")
        
        # Initialize converter
        mapping_file = Path(args.mapping) if args.mapping else None
        converter = TMF921To28312Converter(mapping_file=mapping_file)
        print(f"Initialized converter with mapping rules from: {mapping_file or 'default'}")
        
        # Perform conversion
        print("Converting TMF921 to 3GPP TS 28.312 format...")
        result = converter.convert(tmf921_intent)
        
        if not result.success:
            print(f"Conversion failed: {result.error_message}", file=sys.stderr)
            return 1
        
        print(f"Conversion successful: {len(result.expectations)} expectation(s) generated")
        
        # Create output directory
        output_path = Path(args.output) if args.output else Path.cwd()
        artifacts_dir = create_artifacts_dir(output_path)
        
        # Write expectation.json
        expectation_file = artifacts_dir / "expectation.json"
        with open(expectation_file, 'w') as f:
            json.dump(result.expectations, f, indent=2)
        print(f"Wrote expectations to: {expectation_file}")
        
        # Write report_skeleton.json
        report_file = artifacts_dir / "report_skeleton.json"
        with open(report_file, 'w') as f:
            json.dump(result.reports, f, indent=2)
        print(f"Wrote report skeletons to: {report_file}")
        
        # Write delta.json
        delta_file = artifacts_dir / "delta.json"
        with open(delta_file, 'w') as f:
            json.dump(result.delta_report, f, indent=2)
        print(f"Wrote delta report to: {delta_file}")
        
        # Print summary
        print("\\nConversion Summary:")
        summary = result.delta_report.get("conversion_summary", {})
        print(f"  Total fields processed: {summary.get('total_fields_processed', 0)}")
        print(f"  Successfully mapped: {summary.get('successfully_mapped', 0)}")
        print(f"  Unmapped fields: {summary.get('unmapped_count', 0)}")
        print(f"  Mapping coverage: {summary.get('mapping_coverage', 0.0):.2%}")
        
        return 0
        
    except FileNotFoundError as e:
        print(f"File not found: {e}", file=sys.stderr)
        return 1
    except ConversionError as e:
        print(f"Conversion error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1


def validate_command(args: argparse.Namespace) -> int:
    """Handle the validate command."""
    try:
        # Load and validate TMF921 intent
        print(f"Validating TMF921 intent from: {args.input}")
        tmf921_intent = load_tmf921_intent(Path(args.input))
        
        # Basic validation
        required_fields = ["id", "intentType", "intentSpecification"]
        missing_fields = [field for field in required_fields if field not in tmf921_intent]
        
        if missing_fields:
            print(f"Validation failed: Missing required fields: {missing_fields}", file=sys.stderr)
            return 1
        
        intent_spec = tmf921_intent.get("intentSpecification", {})
        if "intentExpectations" not in intent_spec:
            print("Validation failed: No intentExpectations found", file=sys.stderr)
            return 1
        
        expectations = intent_spec["intentExpectations"]
        if not expectations:
            print("Validation failed: Empty intentExpectations array", file=sys.stderr)
            return 1
        
        print(f"Validation successful: {len(expectations)} expectation(s) found")
        print(f"Intent ID: {tmf921_intent['id']}")
        print(f"Intent Type: {tmf921_intent['intentType']}")
        
        return 0
        
    except FileNotFoundError as e:
        print(f"File not found: {e}", file=sys.stderr)
        return 1
    except ConversionError as e:
        print(f"Validation error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1


def main() -> NoReturn:
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Convert TMF921 Intent to 3GPP TS 28.312 IntentExpectation format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert TMF921 intent to 28.312 format
  tmf921-to-28312 convert --input samples/tmf921/valid_01.json
  
  # Convert with custom mapping file
  tmf921-to-28312 convert --input intent.json --mapping custom_mapping.yaml --output ./results
  
  # Validate TMF921 intent format
  tmf921-to-28312 validate --input samples/tmf921/valid_01.json

Output Files:
  artifacts/expectation.json      - 3GPP 28.312 IntentExpectation structures
  artifacts/report_skeleton.json - 3GPP 28.312 IntentReport stubs
  artifacts/delta.json           - Field mapping gaps and rationale
        """
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Convert command
    convert_parser = subparsers.add_parser("convert", help="Convert TMF921 to 28.312 format")
    convert_parser.add_argument(
        "--input", "-i",
        required=True,
        help="Path to TMF921 intent JSON file"
    )
    convert_parser.add_argument(
        "--output", "-o",
        help="Output directory for generated files (default: current directory)"
    )
    convert_parser.add_argument(
        "--mapping", "-m",
        help="Path to custom mapping YAML file (default: built-in mapping)"
    )
    convert_parser.set_defaults(func=convert_command)
    
    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate TMF921 intent format")
    validate_parser.add_argument(
        "--input", "-i",
        required=True,
        help="Path to TMF921 intent JSON file"
    )
    validate_parser.set_defaults(func=validate_command)
    
    # Parse arguments
    args = parser.parse_args()
    
    if not hasattr(args, 'func'):
        parser.print_help()
        sys.exit(1)
    
    # Execute command
    exit_code = args.func(args)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()