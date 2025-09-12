#!/usr/bin/env python3
"""
VM-1 Integration Example for LLM Adapter Service
This script demonstrates how VM-1 can integrate with the LLM Adapter service.
"""

import requests
import json
import sys

# Configuration
LLM_ADAPTER_URL = "http://localhost:8000"  # Replace with VM-3's IP if different

def generate_intent(text, context=None):
    """
    Call the LLM Adapter service to generate a TMF921-compliant intent.
    
    Args:
        text: Natural language request
        context: Optional context dictionary
    
    Returns:
        Dictionary containing the generated intent
    """
    try:
        payload = {"text": text}
        if context:
            payload["context"] = context
        
        response = requests.post(
            f"{LLM_ADAPTER_URL}/generate_intent",
            json=payload,
            timeout=30
        )
        response.raise_for_status()
        
        result = response.json()
        return result.get("intent", result)
    
    except requests.exceptions.ConnectionError:
        print(f"Error: Cannot connect to LLM Adapter at {LLM_ADAPTER_URL}")
        print("Ensure the service is running on VM-3")
        return None
    except requests.exceptions.Timeout:
        print("Error: Request timed out")
        return None
    except Exception as e:
        print(f"Error generating intent: {e}")
        return None

def main():
    """Example usage of the LLM Adapter integration."""
    
    # Example 1: Network Slice Deployment
    print("Example 1: Network Slice Deployment")
    print("-" * 40)
    request1 = "Deploy a 5G network slice with ultra-low latency for autonomous vehicles"
    intent1 = generate_intent(request1)
    if intent1:
        print(f"Request: {request1}")
        print(f"Generated Intent ID: {intent1.get('intentId')}")
        print(f"Intent Name: {intent1.get('intentName')}")
        print(f"Intent Type: {intent1.get('intentType')}")
        print()
    
    # Example 2: Service Provisioning
    print("Example 2: Service Provisioning")
    print("-" * 40)
    request2 = "Provision edge computing resources with 64 vCPUs and 256GB RAM for AI workloads"
    intent2 = generate_intent(request2)
    if intent2:
        print(f"Request: {request2}")
        print(f"Generated Intent ID: {intent2.get('intentId')}")
        print(f"Intent Name: {intent2.get('intentName')}")
        print(f"Intent Type: {intent2.get('intentType')}")
        print()
    
    # Example 3: With context
    print("Example 3: With Additional Context")
    print("-" * 40)
    request3 = "Create a backup service for critical data"
    context3 = {
        "region": "us-west-2",
        "priority": "critical",
        "compliance": ["HIPAA", "SOC2"]
    }
    intent3 = generate_intent(request3, context3)
    if intent3:
        print(f"Request: {request3}")
        print(f"Context: {context3}")
        print(f"Generated Intent ID: {intent3.get('intentId')}")
        print(f"Intent Name: {intent3.get('intentName')}")
        print(f"Full Intent JSON:")
        print(json.dumps(intent3, indent=2))

def process_batch_requests(requests_list):
    """
    Process multiple intent requests in batch.
    
    Args:
        requests_list: List of natural language requests
    
    Returns:
        List of generated intents
    """
    intents = []
    for request_text in requests_list:
        intent = generate_intent(request_text)
        if intent:
            intents.append(intent)
    return intents

if __name__ == "__main__":
    # Check if service is available
    try:
        health_response = requests.get(f"{LLM_ADAPTER_URL}/health", timeout=5)
        if health_response.status_code == 200:
            print("✓ LLM Adapter service is healthy\n")
            main()
        else:
            print("✗ LLM Adapter service is not responding correctly")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print(f"✗ Cannot connect to LLM Adapter at {LLM_ADAPTER_URL}")
        print("Please ensure the service is running:")
        print("  cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter")
        print("  ./start_service.sh")
        sys.exit(1)