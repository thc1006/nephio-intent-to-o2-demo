#!/usr/bin/env python3
"""
VM-1 Integration Script for LLM Adapter Service
Example of how VM-1 can integrate with the LLM adapter service
"""

import requests
import json
import sys


def call_llm_adapter(text: str, adapter_url: str = "http://localhost:8000") -> dict:
    """
    Call the LLM adapter service to convert natural language to TMF921 intent
    
    Args:
        text: Natural language request
        adapter_url: URL of the LLM adapter service
    
    Returns:
        TMF921-compliant intent JSON
    """
    try:
        response = requests.post(
            f"{adapter_url}/generate_intent",
            json={"text": text},
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error calling LLM adapter: {e}", file=sys.stderr)
        return None


def main():
    """Example usage for VM-1 integration"""
    
    # Example requests
    test_requests = [
        "Deploy a 5G network slice with low latency for IoT devices in zone-1",
        "Provision a high-availability service with 100Mbps bandwidth",
        "Configure edge computing resources with 16 vCPUs and 64GB RAM"
    ]
    
    # Process each request
    for request_text in test_requests:
        print(f"\n{'='*60}")
        print(f"Request: {request_text}")
        print(f"{'='*60}")
        
        intent = call_llm_adapter(request_text)
        
        if intent:
            print(f"Generated Intent:")
            print(json.dumps(intent, indent=2))
            
            # Example of how VM-1 would process the intent
            print(f"\nIntent Summary:")
            print(f"  - ID: {intent.get('intentId', 'N/A')}")
            print(f"  - Name: {intent.get('intentName', 'N/A')}")
            print(f"  - Type: {intent.get('intentType', 'N/A')}")
            print(f"  - Priority: {intent.get('priority', 'N/A')}")
            
            # Forward to Nephio or other systems
            # nephio_api.submit_intent(intent)
        else:
            print("Failed to generate intent")


if __name__ == "__main__":
    # Check if service is available
    try:
        health_check = requests.get("http://localhost:8000/health", timeout=5)
        if health_check.status_code == 200:
            print("LLM Adapter Service is healthy")
            main()
        else:
            print("LLM Adapter Service health check failed")
    except requests.exceptions.RequestException:
        print("LLM Adapter Service is not available. Please start it with: python main.py")
        sys.exit(1)