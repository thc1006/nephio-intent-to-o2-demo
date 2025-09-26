#!/usr/bin/env python3
"""
Quick test script to verify the /generate_intent endpoint
"""

import json
import requests

BASE_URL = "http://localhost:8888"

def test_generate_intent():
    """Test the /generate_intent endpoint"""

    test_cases = [
        {
            "input": {
                "natural_language": "Deploy 5G network slice at edge1"
            },
            "expected_site": "edge1"
        },
        {
            "input": {
                "natural_language": "Configure services for edge site 2"
            },
            "expected_site": "edge2"
        },
        {
            "input": {
                "natural_language": "Setup infrastructure across both edge sites"
            },
            "expected_site": "both"
        },
        {
            "input": {
                "natural_language": "Deploy network service",
                "target_site": "edge1"  # Explicit override
            },
            "expected_site": "edge1"
        }
    ]

    for i, test in enumerate(test_cases, 1):
        print(f"\nTest {i}: {test['input']['natural_language'][:50]}")

        response = requests.post(
            f"{BASE_URL}/generate_intent",
            json=test["input"],
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            intent = data["intent"]

            # Check targetSite
            target_site = intent.get("targetSite")
            if target_site == test["expected_site"]:
                print(f"✓ targetSite correct: {target_site}")
            else:
                print(f"✗ targetSite mismatch: got {target_site}, expected {test['expected_site']}")

            # Check required fields
            required = ["intentId", "name", "parameters", "targetSite"]
            for field in required:
                if field in intent:
                    print(f"✓ {field} present")
                else:
                    print(f"✗ {field} missing")

            print(f"Execution time: {data['execution_time']:.2f}s")
        else:
            print(f"✗ Request failed: {response.status_code}")
            print(response.text)

if __name__ == "__main__":
    print("Testing /generate_intent endpoint...")
    print(f"URL: {BASE_URL}")

    # Check health first
    try:
        health = requests.get(f"{BASE_URL}/health", timeout=5)
        if health.status_code == 200:
            print("✓ Service is healthy")
        else:
            print("✗ Service health check failed")
    except:
        print("✗ Service not reachable. Start with: python3 services/tmf921_processor.py")
        exit(1)

    test_generate_intent()