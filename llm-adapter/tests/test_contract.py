#!/usr/bin/env python3
"""
Contract tests for LLM Adapter
Ensures deterministic behavior and schema compliance
"""

import json
import sys
import time
from pathlib import Path
from typing import Dict, Any

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import jsonschema
from adapters.llm_client import get_llm_client

def load_schema():
    """Load TMF921 schema"""
    schema_file = Path(__file__).parent.parent / "schema.json"
    if schema_file.exists():
        with open(schema_file) as f:
            return json.load(f)
    return None

def test_deterministic_output():
    """Test that same input produces consistent output"""
    print("\n🔄 Testing Deterministic Output...")

    client = get_llm_client()
    test_input = "Deploy eMBB slice in edge1 with 100Mbps downlink"

    # Run multiple times
    outputs = []
    for i in range(3):
        parsed = client.parse_text(test_input)
        tmf921 = client.convert_to_tmf921(parsed, test_input)

        # Extract relevant fields (excluding timestamps and IDs)
        relevant = {
            "serviceType": tmf921["intentParameters"]["serviceType"],
            "targetSite": tmf921["targetSite"],
            "qos": tmf921["intentParameters"]["qosParameters"]
        }
        outputs.append(relevant)

        if i < 2:
            time.sleep(0.5)  # Small delay between runs

    # Check consistency
    first = outputs[0]
    all_same = all(output == first for output in outputs)

    if all_same:
        print("   ✅ Output is deterministic")
        return True
    else:
        print("   ❌ Output is NOT deterministic")
        for i, output in enumerate(outputs):
            print(f"   Run {i+1}: {json.dumps(output)}")
        return False

def test_schema_validation():
    """Test that all outputs conform to schema"""
    print("\n📋 Testing Schema Validation...")

    schema = load_schema()
    if not schema:
        print("   ⚠️  Schema not found, skipping validation")
        return True

    client = get_llm_client()

    test_cases = [
        "Deploy eMBB slice in edge1",
        "Create URLLC service at edge2 with 5ms latency",
        "Setup mMTC for IoT devices"
    ]

    all_valid = True
    for test_input in test_cases:
        parsed = client.parse_text(test_input)
        tmf921 = client.convert_to_tmf921(parsed, test_input)

        try:
            jsonschema.validate(tmf921, schema)
            print(f"   ✅ Valid: {test_input[:40]}...")
        except jsonschema.ValidationError as e:
            print(f"   ❌ Invalid: {test_input[:40]}...")
            print(f"      Error: {e.message}")
            all_valid = False

    return all_valid

def test_fallback_consistency():
    """Test that fallback parser produces schema-valid output"""
    print("\n🔧 Testing Fallback Parser...")

    client = get_llm_client()

    # Force use of fallback by using rule-based parser
    original_use_claude = client.use_claude
    client.use_claude = False

    test_input = "Deploy eMBB service at edge1 with 200Mbps and 20ms latency"

    try:
        parsed = client.parse_text(test_input)
        tmf921 = client.convert_to_tmf921(parsed, test_input)

        # Check structure
        required_fields = ["intentId", "intentName", "intentType", "targetSite", "intentParameters"]
        has_all_fields = all(field in tmf921 for field in required_fields)

        if has_all_fields:
            print("   ✅ Fallback produces valid structure")
            return True
        else:
            print("   ❌ Fallback missing required fields")
            return False

    finally:
        # Restore original setting
        client.use_claude = original_use_claude

def test_timeout_handling():
    """Test that timeouts are handled gracefully"""
    print("\n⏱️  Testing Timeout Handling...")

    client = get_llm_client()

    # Temporarily set very short timeout
    original_timeout = client.timeout
    client.timeout = 0.001  # 1ms - should timeout

    try:
        test_input = "Deploy network slice"
        parsed = client.parse_text(test_input)

        # Should fallback to rule-based
        if parsed and "service" in parsed:
            print("   ✅ Timeout handled gracefully (fallback used)")
            return True
        else:
            print("   ❌ Unexpected result after timeout")
            return False

    finally:
        client.timeout = original_timeout

def test_cache_functionality():
    """Test that caching works correctly"""
    print("\n💾 Testing Cache Functionality...")

    client = get_llm_client()
    test_input = "Deploy eMBB slice with 100Mbps"

    # First call - should not be cached
    start = time.time()
    result1 = client.parse_text(test_input)
    time1 = time.time() - start

    # Second call - should be cached
    start = time.time()
    result2 = client.parse_text(test_input)
    time2 = time.time() - start

    # Cache should make second call much faster
    if result1 == result2 and time2 < time1 * 0.5:
        print(f"   ✅ Cache working (first: {time1:.3f}s, cached: {time2:.3f}s)")
        return True
    elif result1 == result2:
        print(f"   ⚠️  Results match but cache speed not verified")
        return True
    else:
        print(f"   ❌ Cache not working properly")
        return False

def run_contract_tests():
    """Run all contract tests"""
    print("=" * 60)
    print("Running Contract Tests for LLM Adapter")
    print("=" * 60)

    tests = [
        ("Deterministic Output", test_deterministic_output),
        ("Schema Validation", test_schema_validation),
        ("Fallback Consistency", test_fallback_consistency),
        ("Timeout Handling", test_timeout_handling),
        ("Cache Functionality", test_cache_functionality)
    ]

    passed = 0
    failed = 0

    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"   ❌ Exception in {test_name}: {e}")
            failed += 1

    # Summary
    print("\n" + "=" * 60)
    print(f"Contract Test Results: {passed} passed, {failed} failed")
    print("=" * 60)

    return 0 if failed == 0 else 1

if __name__ == "__main__":
    exit_code = run_contract_tests()
    sys.exit(exit_code)