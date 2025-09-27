#!/usr/bin/env python3
"""
TMF921 Adapter API Usage Examples
Comprehensive examples showing automated usage patterns
"""

import requests
import json
import time
from typing import Dict, Any, Optional


class TMF921Client:
    """Client for TMF921 Adapter API"""

    def __init__(self, base_url: str = "http://localhost:8889"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'TMF921-Client/1.0'
        })

    def health_check(self) -> Dict[str, Any]:
        """Check service health"""
        response = self.session.get(f"{self.base_url}/health")
        response.raise_for_status()
        return response.json()

    def generate_intent(self, natural_language: str, target_site: Optional[str] = None) -> Dict[str, Any]:
        """Generate TMF921 intent from natural language"""
        payload = {"natural_language": natural_language}
        if target_site:
            payload["target_site"] = target_site

        response = self.session.post(f"{self.base_url}/generate_intent", json=payload)
        response.raise_for_status()
        return response.json()

    def get_metrics(self) -> Dict[str, Any]:
        """Get service metrics"""
        response = self.session.get(f"{self.base_url}/metrics")
        response.raise_for_status()
        return response.json()


def example_basic_usage():
    """Example 1: Basic intent generation"""
    print("🔸 Example 1: Basic Intent Generation")

    client = TMF921Client()

    # Check if service is healthy
    health = client.health_check()
    print(f"Service status: {health['status']}")

    # Generate a simple intent
    result = client.generate_intent("Deploy 5G network slice at edge1")
    intent = result['intent']

    print(f"Generated Intent:")
    print(f"  ID: {intent['intentId']}")
    print(f"  Service Type: {intent['service']['type']}")
    print(f"  Target Site: {intent['targetSite']}")
    print(f"  SST: {intent['slice']['sst']}")
    print(f"  Execution Time: {result['execution_time']:.3f}s")


def example_service_types():
    """Example 2: Different service types"""
    print("\n🔸 Example 2: Different Service Types")

    client = TMF921Client()

    service_examples = [
        ("eMBB for video streaming", "eMBB", 1),
        ("URLLC for autonomous vehicles", "URLLC", 2),
        ("mMTC for IoT sensors", "mMTC", 3),
        ("Real-time gaming with low latency", "URLLC", 2),
        ("Massive IoT monitoring", "mMTC", 3)
    ]

    for nl_text, expected_type, expected_sst in service_examples:
        result = client.generate_intent(nl_text)
        intent = result['intent']

        service_type = intent['service']['type']
        sst = intent['slice']['sst']

        status = "✅" if (service_type == expected_type and sst == expected_sst) else "❌"
        print(f"{status} '{nl_text}' → {service_type} (SST {sst})")


def example_target_sites():
    """Example 3: Target site specification"""
    print("\n🔸 Example 3: Target Site Specification")

    client = TMF921Client()

    site_examples = [
        ("Deploy service at edge1", "edge1"),
        ("Configure edge site 2", "edge2"),
        ("Setup infrastructure on edge3", "edge3"),
        ("Deploy to edge site 4", "edge4"),
        ("Configure across all edge sites", "both"),
        ("Multi-site deployment", "both")
    ]

    for nl_text, expected_site in site_examples:
        result = client.generate_intent(nl_text)
        intent = result['intent']

        target_site = intent['targetSite']
        status = "✅" if target_site == expected_site else "❌"
        print(f"{status} '{nl_text}' → {target_site}")


def example_explicit_site_override():
    """Example 4: Explicit site override"""
    print("\n🔸 Example 4: Explicit Site Override")

    client = TMF921Client()

    # Same text, different target sites
    base_text = "Deploy network service"

    for site in ["edge1", "edge2", "edge3", "edge4", "both"]:
        result = client.generate_intent(base_text, target_site=site)
        intent = result['intent']
        print(f"Override to {site} → {intent['targetSite']}")


def example_qos_extraction():
    """Example 5: QoS parameter extraction"""
    print("\n🔸 Example 5: QoS Parameter Extraction")

    client = TMF921Client()

    qos_examples = [
        "Deploy service with 100 Mbps bandwidth",
        "Setup low latency service under 10ms",
        "Configure high-speed connection 1 Gbps",
        "Real-time service with 5ms latency",
        "IoT service for sensor monitoring"
    ]

    for nl_text in qos_examples:
        result = client.generate_intent(nl_text)
        qos = result['intent']['qos']

        qos_info = []
        if qos.get('dl_mbps'):
            qos_info.append(f"DL: {qos['dl_mbps']} Mbps")
        if qos.get('ul_mbps'):
            qos_info.append(f"UL: {qos['ul_mbps']} Mbps")
        if qos.get('latency_ms'):
            qos_info.append(f"Latency: {qos['latency_ms']}ms")

        qos_str = ", ".join(qos_info) if qos_info else "Default QoS"
        print(f"'{nl_text}' → {qos_str}")


def example_batch_processing():
    """Example 6: Batch processing multiple intents"""
    print("\n🔸 Example 6: Batch Processing")

    client = TMF921Client()

    batch_requests = [
        ("Gaming service at edge1", "edge1"),
        ("IoT monitoring at edge2", "edge2"),
        ("Video streaming at edge3", "edge3"),
        ("Industrial automation at edge4", "edge4"),
        ("Multi-site CDN deployment", "both")
    ]

    print("Processing batch of intents...")
    start_time = time.time()
    results = []

    for nl_text, site in batch_requests:
        result = client.generate_intent(nl_text, target_site=site)
        results.append({
            'input': nl_text,
            'intent_id': result['intent']['intentId'],
            'service_type': result['intent']['service']['type'],
            'target_site': result['intent']['targetSite']
        })

    total_time = time.time() - start_time

    print(f"Processed {len(results)} intents in {total_time:.3f}s")
    for r in results:
        print(f"  {r['intent_id']}: {r['service_type']} → {r['target_site']}")


def example_error_handling():
    """Example 7: Error handling"""
    print("\n🔸 Example 7: Error Handling")

    client = TMF921Client()

    # Test with invalid input
    try:
        result = client.generate_intent("")  # Empty string
        print("❌ Should have failed with empty input")
    except requests.exceptions.HTTPError as e:
        print(f"✅ Correctly handled empty input: {e.response.status_code}")

    # Test with very long input
    try:
        long_text = "x" * 2000  # Exceeds max length
        result = client.generate_intent(long_text)
        print("❌ Should have failed with long input")
    except requests.exceptions.HTTPError as e:
        print(f"✅ Correctly handled long input: {e.response.status_code}")


def example_performance_monitoring():
    """Example 8: Performance monitoring"""
    print("\n🔸 Example 8: Performance Monitoring")

    client = TMF921Client()

    # Generate several intents to create metrics
    test_requests = [
        "Deploy eMBB service",
        "Setup URLLC network",
        "Configure mMTC sensors"
    ]

    for req in test_requests:
        client.generate_intent(req)

    # Get metrics
    metrics = client.get_metrics()
    stats = metrics['metrics']

    print(f"Service Metrics:")
    print(f"  Total Requests: {stats['total_requests']}")
    print(f"  Success Rate: {stats['success_rate']:.1%}")
    print(f"  Retry Rate: {stats['retry_rate']:.1%}")


def example_json_output():
    """Example 9: Raw JSON output for automation"""
    print("\n🔸 Example 9: Raw JSON Output")

    client = TMF921Client()

    result = client.generate_intent("Deploy URLLC service for autonomous vehicles at edge1")

    # Pretty print the complete JSON structure
    print("Complete TMF921 Intent JSON:")
    print(json.dumps(result['intent'], indent=2))


def example_curl_commands():
    """Example 10: Equivalent curl commands"""
    print("\n🔸 Example 10: Equivalent curl Commands")

    print("Health check:")
    print("curl -X GET http://localhost:8889/health")

    print("\nBasic intent generation:")
    print("curl -X POST http://localhost:8889/generate_intent \\")
    print("  -H 'Content-Type: application/json' \\")
    print("  -d '{\"natural_language\": \"Deploy 5G service at edge1\"}'")

    print("\nWith explicit target site:")
    print("curl -X POST http://localhost:8889/generate_intent \\")
    print("  -H 'Content-Type: application/json' \\")
    print("  -d '{\"natural_language\": \"Deploy service\", \"target_site\": \"edge2\"}'")

    print("\nGet metrics:")
    print("curl -X GET http://localhost:8889/metrics")


def main():
    """Run all examples"""
    print("🚀 TMF921 Adapter API Usage Examples")
    print("=====================================")

    try:
        example_basic_usage()
        example_service_types()
        example_target_sites()
        example_explicit_site_override()
        example_qos_extraction()
        example_batch_processing()
        example_error_handling()
        example_performance_monitoring()
        example_json_output()
        example_curl_commands()

        print("\n🎉 All examples completed successfully!")

    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to TMF921 adapter service.")
        print("Please start the service with:")
        print("cd /home/ubuntu/nephio-intent-to-o2-demo/adapter")
        print("python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8889")

    except Exception as e:
        print(f"❌ Error running examples: {e}")


if __name__ == "__main__":
    main()