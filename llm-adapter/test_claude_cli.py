#!/usr/bin/env python3
"""
Test script to verify Claude CLI is being called for NL conversion
"""

import os
import sys
import json
import time
import subprocess
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent))

# Force Claude CLI mode
os.environ['CLAUDE_CLI'] = '1'

from adapters.llm_client import get_llm_client

def test_claude_cli_direct():
    """Test Claude CLI directly"""
    print("=" * 60)
    print("Testing Claude CLI Direct Call")
    print("=" * 60)

    # Test if claude command exists
    try:
        result = subprocess.run(['which', 'claude'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ Claude CLI found at: {result.stdout.strip()}")
        else:
            print("❌ Claude CLI not found in PATH")
            return False
    except Exception as e:
        print(f"❌ Error checking Claude CLI: {e}")
        return False

    # Test simple Claude CLI call
    try:
        test_prompt = "Output only the JSON: {\"test\": \"success\"}"
        result = subprocess.run(
            ['claude', '-p', test_prompt],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            print(f"✅ Claude CLI responds successfully")
            print(f"   Response: {result.stdout[:100]}...")
        else:
            print(f"❌ Claude CLI failed with code {result.returncode}")
            print(f"   Error: {result.stderr}")
    except subprocess.TimeoutExpired:
        print("❌ Claude CLI timed out")
    except Exception as e:
        print(f"❌ Error calling Claude CLI: {e}")

    return True

def test_llm_client_mode():
    """Test LLM client mode detection"""
    print("\n" + "=" * 60)
    print("Testing LLM Client Mode")
    print("=" * 60)

    client = get_llm_client()

    print(f"Mode: {client.get_model_info()}")
    print(f"Claude Available: {client.claude_available}")
    print(f"Use Claude Flag: {client.use_claude}")
    print(f"Timeout: {client.timeout}s")
    print(f"Max Retries: {client.max_retries}")

    if client.get_model_info() == "claude-cli":
        print("✅ LLM Client is configured to use Claude CLI")
    else:
        print("❌ LLM Client is NOT using Claude CLI (using rule-based)")

    return client.get_model_info() == "claude-cli"

def test_actual_parsing():
    """Test actual parsing to see if Claude is called"""
    print("\n" + "=" * 60)
    print("Testing Actual NL Parsing")
    print("=" * 60)

    client = get_llm_client()

    # Test cases that should trigger Claude
    test_cases = [
        "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency",
        "Create URLLC service with ultra-low 1ms latency requirement",
        "Setup massive IoT network for smart city sensors"
    ]

    for i, text in enumerate(test_cases, 1):
        print(f"\nTest {i}: {text[:50]}...")

        # Clear cache to force fresh parsing
        from adapters.llm_client import CACHE
        CACHE.clear()

        start_time = time.time()

        try:
            # Add temporary logging to track Claude calls
            original_parse_claude = client._parse_with_claude
            claude_was_called = False

            def wrapped_parse_claude(text):
                nonlocal claude_was_called
                claude_was_called = True
                print("   🔄 Claude CLI is being called...")
                return original_parse_claude(text)

            client._parse_with_claude = wrapped_parse_claude

            # Parse the text
            result = client.parse_text(text)
            elapsed = time.time() - start_time

            # Restore original method
            client._parse_with_claude = original_parse_claude

            if claude_was_called:
                print(f"   ✅ Claude CLI was called (took {elapsed:.2f}s)")
            else:
                print(f"   ⚠️  Claude CLI was NOT called - fallback used (took {elapsed:.2f}s)")

            print(f"   Result: {json.dumps(result, indent=2)[:200]}...")

        except Exception as e:
            print(f"   ❌ Error: {e}")

    return True

def test_fallback_behavior():
    """Test fallback when Claude fails"""
    print("\n" + "=" * 60)
    print("Testing Fallback Behavior")
    print("=" * 60)

    # Temporarily set very short timeout to force fallback
    os.environ['LLM_TIMEOUT'] = '0.1'  # 100ms timeout

    # Recreate client with new timeout
    from adapters.llm_client import _client
    _client = None  # Reset singleton

    client = get_llm_client()
    print(f"Timeout set to: {client.timeout}s (should trigger fallback)")

    from adapters.llm_client import CACHE
    CACHE.clear()

    text = "Deploy high-performance video streaming at edge1 with 1Gbps"

    start_time = time.time()
    result = client.parse_text(text)
    elapsed = time.time() - start_time

    print(f"Parsing completed in {elapsed:.2f}s")
    print(f"Model used: {client.get_model_info()}")
    print(f"Fallback count: {client.fallback_count}")
    print(f"Success count: {client.llm_success_count}")

    if client.fallback_count > 0:
        print("✅ Fallback mechanism working correctly")
    else:
        print("⚠️  Fallback was not triggered")

    # Reset timeout
    os.environ['LLM_TIMEOUT'] = '10'

    return True

def main():
    """Run all tests"""
    print("🔍 Claude CLI Integration Test Suite")
    print("=" * 60)

    # Check environment variable
    print(f"CLAUDE_CLI env var: {os.environ.get('CLAUDE_CLI', 'not set')}")

    # Run tests
    tests_passed = 0
    total_tests = 4

    if test_claude_cli_direct():
        tests_passed += 1

    if test_llm_client_mode():
        tests_passed += 1

    if test_actual_parsing():
        tests_passed += 1

    if test_fallback_behavior():
        tests_passed += 1

    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    print(f"Tests Passed: {tests_passed}/{total_tests}")

    if tests_passed == total_tests:
        print("✅ All tests passed - Claude CLI integration confirmed!")
    else:
        print("⚠️  Some tests did not pass - check configuration")

    return 0 if tests_passed == total_tests else 1

if __name__ == "__main__":
    exit(main())