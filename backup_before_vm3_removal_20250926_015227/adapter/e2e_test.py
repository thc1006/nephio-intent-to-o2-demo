#!/usr/bin/env python3
"""
E2E Test Script for LLM Adapter Demo Preparation
Warms up cache and validates all endpoints
"""

import json
import time
import sys
import requests
from typing import Dict, List, Tuple
from datetime import datetime

# Configuration
BASE_URL = "http://localhost:8888"
API_KEY = "demo-key-2024"  # If API key is required

# Test cases from golden files
TEST_CASES = [
    {
        "name": "5G Gaming Slice",
        "input": "Deploy a 5G network slice with ultra-low latency for gaming services at edge site 1",
        "target_site": "edge1",
        "expected_fields": ["intentId", "name", "targetSite", "parameters"],
        "expected_site": "edge1"
    },
    {
        "name": "IoT Monitoring",
        "input": "Create IoT monitoring infrastructure with high capacity for industrial sensors across both edge sites",
        "target_site": "both",
        "expected_fields": ["intentId", "name", "targetSite", "parameters"],
        "expected_site": "both"
    },
    {
        "name": "Video Streaming",
        "input": "Set up high-bandwidth video streaming service for edge site 2 with CDN capabilities",
        "target_site": "edge2",
        "expected_fields": ["intentId", "name", "targetSite", "parameters"],
        "expected_site": "edge2"
    },
    {
        "name": "Generic Network Slice",
        "input": "Deploy network slice with low latency",
        "target_site": None,  # Test default
        "expected_fields": ["intentId", "name", "targetSite", "parameters"],
        "expected_site": "both"
    }
]

class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_header(text: str):
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text:^60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}")

def print_test(name: str, status: bool, message: str = "", time_ms: float = 0):
    status_text = f"{Colors.OKGREEN}✓ PASS{Colors.ENDC}" if status else f"{Colors.FAIL}✗ FAIL{Colors.ENDC}"
    time_text = f" ({time_ms:.0f}ms)" if time_ms > 0 else ""
    print(f"  [{status_text}] {name}{time_text}")
    if message:
        print(f"        {Colors.WARNING}{message}{Colors.ENDC}")

def test_health_endpoint() -> bool:
    """Test health check endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        return response.status_code == 200 and response.json()["status"] == "healthy"
    except Exception as e:
        print(f"        {Colors.FAIL}Error: {e}{Colors.ENDC}")
        return False

def test_slo_endpoint() -> bool:
    """Test mock SLO endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/mock/slo", timeout=5)
        data = response.json()
        return (response.status_code == 200 and
                "status" in data and
                "latency_p95" in data and
                "success_rate" in data)
    except Exception as e:
        print(f"        {Colors.FAIL}Error: {e}{Colors.ENDC}")
        return False

def test_ui_endpoint() -> bool:
    """Test UI endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/", timeout=5)
        return response.status_code == 200 and "TMF921" in response.text
    except Exception as e:
        print(f"        {Colors.FAIL}Error: {e}{Colors.ENDC}")
        return False

def test_intent_generation(test_case: Dict) -> Tuple[bool, Dict, float]:
    """Test intent generation endpoint"""
    start_time = time.time()

    payload = {
        "natural_language": test_case["input"]
    }

    if test_case["target_site"]:
        payload["target_site"] = test_case["target_site"]

    headers = {"Content-Type": "application/json"}

    # Add API key if configured
    if API_KEY:
        headers["X-API-Key"] = API_KEY

    try:
        response = requests.post(
            f"{BASE_URL}/generate_intent",
            json=payload,
            headers=headers,
            timeout=30
        )

        elapsed_ms = (time.time() - start_time) * 1000

        if response.status_code != 200:
            return False, {"error": response.text}, elapsed_ms

        data = response.json()
        intent = data.get("intent", {})

        # Validate required fields
        for field in test_case["expected_fields"]:
            if field not in intent:
                return False, {"error": f"Missing field: {field}", "intent": intent}, elapsed_ms

        # Validate target site
        if intent.get("targetSite") != test_case["expected_site"]:
            return False, {
                "error": f"Expected targetSite '{test_case['expected_site']}', got '{intent.get('targetSite')}'",
                "intent": intent
            }, elapsed_ms

        return True, data, elapsed_ms

    except Exception as e:
        elapsed_ms = (time.time() - start_time) * 1000
        return False, {"error": str(e)}, elapsed_ms

def test_rate_limiting() -> bool:
    """Test rate limiting (optional)"""
    # Send multiple rapid requests
    success_count = 0
    rate_limited = False

    for i in range(15):  # Exceed the 10 req/min limit
        try:
            response = requests.post(
                f"{BASE_URL}/generate_intent",
                json={"natural_language": f"Test request {i}"},
                timeout=5
            )

            if response.status_code == 200:
                success_count += 1
            elif response.status_code == 429:
                rate_limited = True
                break

        except:
            pass

    return rate_limited  # Should be rate limited after 10 requests

def warm_cache():
    """Warm up the cache with test cases"""
    print(f"\n{Colors.OKCYAN}Warming up cache...{Colors.ENDC}")

    for test_case in TEST_CASES[:3]:  # Use first 3 golden examples
        print(f"  Caching: {test_case['name']}...", end=" ")
        success, _, time_ms = test_intent_generation(test_case)
        if success:
            print(f"{Colors.OKGREEN}✓{Colors.ENDC} ({time_ms:.0f}ms)")
        else:
            print(f"{Colors.WARNING}✗{Colors.ENDC}")

def run_e2e_tests():
    """Run all E2E tests"""
    print_header("LLM Adapter E2E Test Suite")
    print(f"{Colors.OKCYAN}Timestamp: {datetime.now().isoformat()}{Colors.ENDC}")
    print(f"{Colors.OKCYAN}Base URL: {BASE_URL}{Colors.ENDC}")

    # Track results
    total_tests = 0
    passed_tests = 0

    # Test basic endpoints
    print(f"\n{Colors.BOLD}Basic Endpoints:{Colors.ENDC}")

    tests = [
        ("Health Check", test_health_endpoint()),
        ("Mock SLO", test_slo_endpoint()),
        ("Web UI", test_ui_endpoint())
    ]

    for name, result in tests:
        print_test(name, result)
        total_tests += 1
        if result:
            passed_tests += 1

    # Warm cache
    warm_cache()

    # Test intent generation
    print(f"\n{Colors.BOLD}Intent Generation Tests:{Colors.ENDC}")

    for test_case in TEST_CASES:
        success, data, time_ms = test_intent_generation(test_case)

        message = ""
        if not success and "error" in data:
            message = str(data["error"])[:50]

        print_test(test_case["name"], success, message, time_ms)
        total_tests += 1
        if success:
            passed_tests += 1

            # Show intent preview
            if "intent" in data:
                intent = data["intent"]
                print(f"        ID: {intent.get('intentId', 'N/A')}")
                print(f"        Site: {intent.get('targetSite', 'N/A')}")

    # Test rate limiting (optional)
    print(f"\n{Colors.BOLD}Advanced Tests:{Colors.ENDC}")

    rate_limit_works = test_rate_limiting()
    print_test("Rate Limiting", rate_limit_works)
    total_tests += 1
    if rate_limit_works:
        passed_tests += 1

    # Summary
    print_header("Test Summary")

    success_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0

    if success_rate == 100:
        status_color = Colors.OKGREEN
        status_text = "ALL TESTS PASSED"
    elif success_rate >= 80:
        status_color = Colors.WARNING
        status_text = "MOSTLY PASSED"
    else:
        status_color = Colors.FAIL
        status_text = "FAILURES DETECTED"

    print(f"{status_color}{Colors.BOLD}")
    print(f"  Total Tests: {total_tests}")
    print(f"  Passed: {passed_tests}")
    print(f"  Failed: {total_tests - passed_tests}")
    print(f"  Success Rate: {success_rate:.1f}%")
    print(f"  Status: {status_text}")
    print(f"{Colors.ENDC}")

    # Recommendations
    if success_rate < 100:
        print(f"\n{Colors.WARNING}Recommendations:{Colors.ENDC}")
        if not test_health_endpoint():
            print("  • Check if the service is running on port 8888")
        if total_tests - passed_tests > 2:
            print("  • Review logs for Claude CLI errors")
            print("  • Verify Claude CLI authentication")
            print("  • Check network connectivity")
    else:
        print(f"\n{Colors.OKGREEN}✓ System ready for demo!{Colors.ENDC}")

    return success_rate == 100

if __name__ == "__main__":
    try:
        success = run_e2e_tests()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n{Colors.WARNING}Tests interrupted by user{Colors.ENDC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.FAIL}Test suite error: {e}{Colors.ENDC}")
        sys.exit(1)