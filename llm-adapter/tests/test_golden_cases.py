#!/usr/bin/env python3
"""
Golden test cases for LLM Adapter
Ensures stable outputs for known inputs
"""

import json
import sys
import os
from pathlib import Path
from typing import Dict, Any

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from adapters.llm_client import get_llm_client

def load_golden_cases():
    """Load golden test cases from JSON file"""
    golden_file = Path(__file__).parent / "golden_cases.json"
    with open(golden_file) as f:
        return json.load(f)["golden_cases"]

def validate_output(actual: Dict[str, Any], expected: Dict[str, Any], rules: Dict[str, Any]) -> bool:
    """Validate actual output against expected and rules"""
    # Check required fields exist
    for field in rules.get("must_have_fields", []):
        if field not in actual:
            print(f"  ❌ Missing required field: {field}")
            return False

    # Check intent type
    if "intent_type" in rules:
        if actual.get("intentType") != rules["intent_type"]:
            print(f"  ❌ Intent type mismatch: {actual.get('intentType')} != {rules['intent_type']}")
            return False

    # Check priority range
    if "priority_range" in rules:
        priority = actual.get("intentPriority", 5)
        min_p, max_p = rules["priority_range"]
        if not (min_p <= priority <= max_p):
            print(f"  ❌ Priority {priority} not in range [{min_p}, {max_p}]")
            return False

    # Check expected output fields in intentParameters
    params = actual.get("intentParameters", {})

    # Check service type
    if params.get("serviceType") != expected["serviceType"]:
        print(f"  ❌ Service type mismatch: {params.get('serviceType')} != {expected['serviceType']}")
        return False

    # Check target site
    if actual.get("targetSite") != expected["targetSite"]:
        print(f"  ❌ Target site mismatch: {actual.get('targetSite')} != {expected['targetSite']}")
        return False

    # Check QoS parameters
    qos = params.get("qosParameters", {})
    expected_qos = expected["qosParameters"]

    for key in ["downlinkMbps", "uplinkMbps", "latencyMs"]:
        if expected_qos.get(key) is not None:
            if qos.get(key) != expected_qos[key]:
                print(f"  ❌ QoS {key} mismatch: {qos.get(key)} != {expected_qos[key]}")
                return False

    return True

def run_golden_tests():
    """Run all golden test cases"""
    print("=" * 60)
    print("Running Golden Test Cases for LLM Adapter")
    print("=" * 60)

    # Load cases
    cases = load_golden_cases()
    client = get_llm_client()

    # Track results
    passed = 0
    failed = 0

    for case in cases:
        case_id = case["id"]
        case_name = case["name"]
        input_text = case["input"]
        expected = case["expected_output"]
        rules = case["validation_rules"]

        print(f"\n📋 Test Case: {case_id} - {case_name}")
        print(f"   Input: {input_text}")

        try:
            # Parse with LLM client
            parsed = client.parse_text(input_text)

            # Convert to TMF921 format
            tmf921 = client.convert_to_tmf921(parsed, input_text)

            # Validate output
            if validate_output(tmf921, expected, rules):
                print(f"   ✅ PASSED")
                passed += 1
            else:
                print(f"   ❌ FAILED")
                failed += 1
                print(f"   Actual output: {json.dumps(tmf921.get('intentParameters', {}), indent=2)}")

        except Exception as e:
            print(f"   ❌ FAILED with exception: {e}")
            failed += 1

    # Summary
    print("\n" + "=" * 60)
    print(f"Test Results: {passed} passed, {failed} failed")
    print("=" * 60)

    # Return exit code
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    exit_code = run_golden_tests()
    sys.exit(exit_code)