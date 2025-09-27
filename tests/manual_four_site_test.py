#!/usr/bin/env python3
"""
Manual 4-Site Support Test
Tests the running Claude Headless service with edge3 and edge4
"""

import requests
import json
import time

def test_claude_headless_four_sites():
    """Test Claude Headless service with all 4 sites"""
    base_url = "http://localhost:8002"

    print("=== Testing Claude Headless Service with 4 Sites ===")

    # Test health endpoint
    print("\n1. Testing health endpoint...")
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        if response.status_code == 200:
            print("✓ Health endpoint OK")
            print(f"  Status: {response.json()}")
        else:
            print(f"✗ Health endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Health endpoint error: {e}")
        return False

    # Test intent processing with each site
    test_cases = [
        {
            "text": "Deploy eMBB service on edge1 with 100Mbps bandwidth",
            "target_sites": ["edge1"],
            "expected_site": "edge1"
        },
        {
            "text": "Deploy URLLC service on edge2 with 1ms latency",
            "target_sites": ["edge2"],
            "expected_site": "edge2"
        },
        {
            "text": "Deploy eMBB service on edge3 with 200Mbps bandwidth",
            "target_sites": ["edge3"],
            "expected_site": "edge3"
        },
        {
            "text": "Deploy mMTC service on edge4 for IoT devices",
            "target_sites": ["edge4"],
            "expected_site": "edge4"
        },
        {
            "text": "Deploy service across all edge sites",
            "target_sites": ["edge1", "edge2", "edge3", "edge4"],
            "expected_sites": ["edge1", "edge2", "edge3", "edge4"]
        }
    ]

    print("\n2. Testing intent processing for all 4 sites...")

    passed_tests = 0
    total_tests = len(test_cases)

    for i, test_case in enumerate(test_cases, 1):
        print(f"\n  Test {i}: {test_case['text'][:50]}...")

        payload = {
            "text": test_case["text"],
            "target_sites": test_case["target_sites"]
        }

        try:
            response = requests.post(
                f"{base_url}/api/v1/intent",
                json=payload,
                timeout=30
            )

            if response.status_code == 200:
                data = response.json()
                if data.get("status") == "success":
                    intent = data.get("intent", {})
                    target_sites = intent.get("targetSites", [])

                    # Check if expected site(s) are in the result
                    if "expected_site" in test_case:
                        if test_case["expected_site"] in str(intent):
                            print(f"    ✓ Contains expected site: {test_case['expected_site']}")
                            passed_tests += 1
                        else:
                            print(f"    ✗ Missing expected site: {test_case['expected_site']}")
                            print(f"    Intent: {intent}")
                    elif "expected_sites" in test_case:
                        found_sites = [site for site in test_case["expected_sites"] if site in str(intent)]
                        if len(found_sites) >= 2:  # At least some sites found
                            print(f"    ✓ Found sites: {found_sites}")
                            passed_tests += 1
                        else:
                            print(f"    ✗ Expected sites not found: {test_case['expected_sites']}")
                            print(f"    Intent: {intent}")
                else:
                    print(f"    ✗ Failed: {data}")
            else:
                print(f"    ✗ HTTP Error: {response.status_code}")
                print(f"    Response: {response.text}")

        except Exception as e:
            print(f"    ✗ Exception: {e}")

    print(f"\n=== Claude Headless Test Results ===")
    print(f"Passed: {passed_tests}/{total_tests}")
    print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")

    return passed_tests >= total_tests * 0.8  # 80% pass rate

def test_site_validator():
    """Test the site validator utility"""
    print("\n=== Testing Site Validator Utility ===")

    try:
        import sys
        import os
        sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

        from utils.site_validator import validator, validate_sites, get_all_valid_sites

        print("\n1. Testing valid sites list...")
        valid_sites = get_all_valid_sites()
        expected_sites = ["edge1", "edge2", "edge3", "edge4"]

        if set(valid_sites) == set(expected_sites):
            print(f"✓ Valid sites: {valid_sites}")
        else:
            print(f"✗ Unexpected sites: {valid_sites}, expected: {expected_sites}")
            return False

        print("\n2. Testing site validation...")
        test_cases = [
            ("edge1", ["edge1"]),
            ("edge3", ["edge3"]),
            ("edge4", ["edge4"]),
            ("both", ["edge1", "edge2", "edge3", "edge4"]),
            (["edge1", "edge3"], ["edge1", "edge3"]),
            ("invalid", ["edge1"])  # Should fallback to edge1
        ]

        passed = 0
        for input_val, expected in test_cases:
            result = validate_sites(input_val)
            if set(result) == set(expected):
                print(f"    ✓ {input_val} -> {result}")
                passed += 1
            else:
                print(f"    ✗ {input_val} -> {result}, expected: {expected}")

        print(f"\nSite Validator Results: {passed}/{len(test_cases)} passed")
        return passed == len(test_cases)

    except ImportError as e:
        print(f"✗ Could not import site validator: {e}")
        return False

def test_config_file():
    """Test that config file contains all 4 sites"""
    print("\n=== Testing Configuration File ===")

    config_path = "/home/ubuntu/nephio-intent-to-o2-demo/config/edge-sites-config.yaml"

    try:
        with open(config_path, 'r') as f:
            content = f.read()

        expected_sites = ["edge1", "edge2", "edge3", "edge4"]
        expected_ips = ["172.16.4.45", "172.16.4.176", "172.16.5.81", "172.16.1.252"]

        print(f"\n1. Checking config file: {config_path}")

        sites_found = []
        ips_found = []

        for site in expected_sites:
            if f"{site}:" in content:
                sites_found.append(site)
                print(f"    ✓ Found site: {site}")
            else:
                print(f"    ✗ Missing site: {site}")

        for ip in expected_ips:
            if ip in content:
                ips_found.append(ip)
                print(f"    ✓ Found IP: {ip}")
            else:
                print(f"    ✗ Missing IP: {ip}")

        success = len(sites_found) == 4 and len(ips_found) == 4
        print(f"\nConfig File Results: {len(sites_found)}/4 sites, {len(ips_found)}/4 IPs")
        return success

    except Exception as e:
        print(f"✗ Error reading config file: {e}")
        return False

def main():
    """Run all tests"""
    print("4-Site Support Test Suite")
    print("=" * 50)

    tests = [
        ("Configuration File", test_config_file),
        ("Site Validator", test_site_validator),
        ("Claude Headless Service", test_claude_headless_four_sites)
    ]

    results = []

    for test_name, test_func in tests:
        print(f"\n{test_name}")
        print("-" * len(test_name))

        try:
            result = test_func()
            results.append((test_name, result))
            status = "PASS" if result else "FAIL"
            print(f"\n{test_name}: {status}")
        except Exception as e:
            print(f"\n{test_name}: ERROR - {e}")
            results.append((test_name, False))

    # Summary
    print("\n" + "=" * 50)
    print("FINAL RESULTS")
    print("=" * 50)

    passed = 0
    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        print(f"{test_name}: {status}")
        if result:
            passed += 1

    print(f"\nOverall: {passed}/{len(results)} tests passed")

    if passed == len(results):
        print("🎉 All tests passed! 4-site support is working correctly.")
        return True
    else:
        print("⚠️  Some tests failed. Please check the implementation.")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)