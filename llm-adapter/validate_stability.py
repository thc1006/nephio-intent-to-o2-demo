#!/usr/bin/env python3
"""
Stability validation script for LLM Adapter
Tests multiple iterations of golden cases to ensure consistent outputs
"""

import json
import requests
import hashlib
import time
from typing import Dict, Any, List
from pathlib import Path

# API endpoint
API_URL = "http://localhost:8888/generate_intent"

# Golden test cases
GOLDEN_CASES = [
    {
        "id": "golden-001",
        "input": "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency",
        "expected_site": "edge1",
        "expected_service": "eMBB"
    },
    {
        "id": "golden-002",
        "input": "Create URLLC service in edge2 with 10ms latency and 100Mbps downlink",
        "expected_site": "edge2",
        "expected_service": "URLLC"
    },
    {
        "id": "golden-003",
        "input": "Setup mMTC network in zone3 for IoT devices with 50Mbps capacity",
        "expected_site": "both",
        "expected_service": "mMTC"
    }
]

def hash_response(response: Dict[str, Any]) -> str:
    """Create hash of relevant response fields for consistency checking"""
    relevant_fields = {
        "service_type": response.get("intent", {}).get("service", {}).get("type"),
        "target_site": response.get("intent", {}).get("targetSite"),
        "qos": response.get("intent", {}).get("qos")
    }
    return hashlib.md5(json.dumps(relevant_fields, sort_keys=True).encode()).hexdigest()

def test_case(case: Dict[str, Any], iterations: int = 3) -> Dict[str, Any]:
    """Test a single case multiple times for consistency"""
    results = []
    hashes = []

    for i in range(iterations):
        try:
            response = requests.post(
                API_URL,
                json={"natural_language": case["input"]},
                timeout=15
            )
            response.raise_for_status()

            data = response.json()
            results.append(data)
            hashes.append(hash_response(data))

            # Validate expected values
            service_type = data.get("intent", {}).get("service", {}).get("type")
            target_site = data.get("intent", {}).get("targetSite")

            if service_type != case["expected_service"]:
                print(f"  ❌ Service mismatch: {service_type} != {case['expected_service']}")
                return {"success": False, "reason": "service_mismatch"}

            if target_site != case["expected_site"]:
                print(f"  ❌ Target site mismatch: {target_site} != {case['expected_site']}")
                return {"success": False, "reason": "site_mismatch"}

            time.sleep(0.5)  # Small delay between requests

        except Exception as e:
            print(f"  ❌ Request failed: {e}")
            return {"success": False, "reason": str(e)}

    # Check consistency
    if len(set(hashes)) > 1:
        print(f"  ⚠️  Inconsistent outputs detected (different hashes: {set(hashes)})")
        return {"success": False, "reason": "inconsistent_outputs"}

    print(f"  ✅ All {iterations} iterations consistent")
    return {"success": True, "hash": hashes[0]}

def main():
    """Run stability validation tests"""
    print("=" * 60)
    print("LLM Adapter Stability Validation")
    print("=" * 60)

    results = []

    for case in GOLDEN_CASES:
        print(f"\n📋 Testing: {case['id']}")
        print(f"   Input: {case['input']}")

        result = test_case(case, iterations=3)
        results.append({
            "case_id": case["id"],
            **result
        })

    # Summary
    print("\n" + "=" * 60)
    successful = sum(1 for r in results if r["success"])
    print(f"Stability Test Results: {successful}/{len(results)} cases stable")

    if successful == len(results):
        print("✅ All golden cases are producing stable outputs!")
    else:
        print("⚠️  Some cases showed instability. Review logs for details.")

    # Save results to artifacts
    artifacts_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter')
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    timestamp = time.strftime('%Y%m%d_%H%M%S')
    results_file = artifacts_dir / f"stability_test_{timestamp}.json"

    with open(results_file, 'w') as f:
        json.dump({
            "timestamp": timestamp,
            "results": results,
            "summary": {
                "total_cases": len(results),
                "successful": successful,
                "stability_rate": successful / len(results) if results else 0
            }
        }, f, indent=2)

    print(f"\nResults saved to: {results_file}")
    print("=" * 60)

    return 0 if successful == len(results) else 1

if __name__ == "__main__":
    exit(main())