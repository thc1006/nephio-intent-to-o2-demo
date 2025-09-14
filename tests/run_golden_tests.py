#!/usr/bin/env python3
"""Golden test runner for intent compilation pipeline.

This script provides a comprehensive test runner for the golden test suite,
with options for different test modes and reporting.
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

import pytest


def run_golden_tests(test_type: Optional[str] = None,
                    generate_golden: bool = False,
                    update_golden: bool = False,
                    verbose: bool = False,
                    output_dir: Optional[str] = None) -> int:
    """Run golden tests with specified options.

    Args:
        test_type: Type of tests to run (golden, contract, all)
        generate_golden: Generate new golden outputs
        update_golden: Update existing golden outputs
        verbose: Enable verbose output
        output_dir: Directory for test outputs

    Returns:
        Exit code (0 for success, non-zero for failure)
    """
    test_root = Path(__file__).parent
    args = []

    # Determine which tests to run
    if test_type == "golden":
        args.append(str(test_root / "golden"))
    elif test_type == "contract":
        args.append(str(test_root / "contract"))
    elif test_type == "framework":
        args.extend(["-k", "TestGoldenFramework"])
    else:
        # Run all tests
        args.append(str(test_root))

    # Configure pytest options
    if verbose:
        args.append("-v")

    if generate_golden:
        args.append("--generate-golden")

    if update_golden:
        args.append("--update-golden")

    if output_dir:
        args.extend(["--output-dir", output_dir])

    # Add coverage reporting
    args.extend([
        "--cov=translate",
        "--cov-report=term-missing",
        "--cov-report=html:htmlcov"
    ])

    # Run tests
    print(f"Running golden tests with args: {args}")
    return pytest.main(args)


def generate_golden_outputs(test_scenarios: List[str],
                          output_dir: Optional[str] = None) -> Dict[str, bool]:
    """Generate golden outputs for specified test scenarios.

    Args:
        test_scenarios: List of test scenario names
        output_dir: Directory for outputs

    Returns:
        Dictionary mapping scenario names to success status
    """
    results = {}

    # Import test framework
    sys.path.insert(0, str(Path(__file__).parent))
    from golden.test_framework import GoldenTestFramework

    test_data_dir = Path(__file__).parent / "fixtures"
    framework = GoldenTestFramework(test_data_dir)

    fixed_timestamp = "2024-01-01T00:00:00+00:00"

    for scenario in test_scenarios:
        print(f"Generating golden output for scenario: {scenario}")
        try:
            result = framework.generate_test_scenario(scenario, fixed_timestamp)
            framework.save_golden_output(
                scenario,
                result["resources"],
                result["checksums"],
                result["manifest"]
            )
            results[scenario] = True
            print(f"✓ Generated golden output for {scenario}")
        except Exception as e:
            print(f"✗ Failed to generate golden output for {scenario}: {e}")
            results[scenario] = False

    return results


def validate_golden_outputs(test_scenarios: List[str]) -> Dict[str, bool]:
    """Validate existing golden outputs against current implementation.

    Args:
        test_scenarios: List of test scenario names

    Returns:
        Dictionary mapping scenario names to validation status
    """
    results = {}

    # Import test framework
    sys.path.insert(0, str(Path(__file__).parent))
    from golden.test_framework import GoldenTestFramework

    test_data_dir = Path(__file__).parent / "fixtures"
    framework = GoldenTestFramework(test_data_dir)

    fixed_timestamp = "2024-01-01T00:00:00+00:00"

    for scenario in test_scenarios:
        print(f"Validating golden output for scenario: {scenario}")
        try:
            # Generate current output
            current = framework.generate_test_scenario(scenario, fixed_timestamp)

            # Load golden output
            expected_resources, expected_checksums, expected_manifest = \
                framework.load_golden_output(scenario)

            # Compare outputs
            differences = framework.compare_outputs(
                current["resources"], expected_resources
            )

            if not differences and current["checksums"] == expected_checksums:
                results[scenario] = True
                print(f"✓ Golden output valid for {scenario}")
            else:
                results[scenario] = False
                print(f"✗ Golden output differs for {scenario}")
                for diff in differences[:5]:  # Show first 5 differences
                    print(f"  - {diff}")

        except Exception as e:
            print(f"✗ Failed to validate golden output for {scenario}: {e}")
            results[scenario] = False

    return results


def main():
    """Main entry point for test runner."""
    parser = argparse.ArgumentParser(description="Golden test runner")

    parser.add_argument(
        "--type", "-t",
        choices=["golden", "contract", "framework", "all"],
        default="all",
        help="Type of tests to run"
    )

    parser.add_argument(
        "--generate-golden", "-g",
        action="store_true",
        help="Generate new golden outputs"
    )

    parser.add_argument(
        "--update-golden", "-u",
        action="store_true",
        help="Update existing golden outputs"
    )

    parser.add_argument(
        "--validate-golden", "-V",
        action="store_true",
        help="Validate existing golden outputs"
    )

    parser.add_argument(
        "--scenarios", "-s",
        nargs="*",
        default=[
            "edge1-embb-with-sla",
            "edge2-urllc-with-sla",
            "both-sites-mmt-with-sla",
            "edge1-embb-no-sla",
            "minimal-intent"
        ],
        help="Test scenarios to process"
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    parser.add_argument(
        "--output-dir", "-o",
        help="Directory for test outputs"
    )

    parser.add_argument(
        "--report-file",
        help="File to write test report"
    )

    args = parser.parse_args()

    start_time = time.time()

    # Handle golden output generation/validation
    if args.generate_golden or args.update_golden:
        print("Generating golden outputs...")
        results = generate_golden_outputs(args.scenarios, args.output_dir)

        success_count = sum(results.values())
        total_count = len(results)

        print(f"\nGenerated golden outputs: {success_count}/{total_count} succeeded")

        if success_count < total_count:
            print("Some golden output generation failed. Check logs above.")
            return 1

    if args.validate_golden:
        print("Validating golden outputs...")
        results = validate_golden_outputs(args.scenarios)

        success_count = sum(results.values())
        total_count = len(results)

        print(f"\nValidated golden outputs: {success_count}/{total_count} valid")

        if success_count < total_count:
            print("Some golden outputs are invalid. Check logs above.")
            return 1

    # Run tests
    exit_code = run_golden_tests(
        test_type=args.type,
        generate_golden=args.generate_golden,
        update_golden=args.update_golden,
        verbose=args.verbose,
        output_dir=args.output_dir
    )

    elapsed_time = time.time() - start_time
    print(f"\nTest execution completed in {elapsed_time:.2f} seconds")

    # Generate test report if requested
    if args.report_file:
        report = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "elapsed_time": elapsed_time,
            "exit_code": exit_code,
            "test_type": args.type,
            "scenarios": args.scenarios,
            "generate_golden": args.generate_golden,
            "update_golden": args.update_golden
        }

        with open(args.report_file, 'w') as f:
            json.dump(report, f, indent=2)

        print(f"Test report written to {args.report_file}")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())