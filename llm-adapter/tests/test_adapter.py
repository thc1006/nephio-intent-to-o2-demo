#!/usr/bin/env python3
"""
Unit tests for the LLM Adapter Service
"""

import json
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app, create_claude_prompt, extract_json_from_response, validate_intent_structure

client = TestClient(app)


def test_health_check():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "service" in data
    assert "version" in data


def test_home_page():
    """Test that the home page returns HTML"""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "LLM Intent Adapter" in response.text


def test_create_claude_prompt():
    """Test prompt creation"""
    user_request = "Deploy a network slice for IoT"
    prompt = create_claude_prompt(user_request)
    
    assert "TMF921-compliant" in prompt
    assert user_request in prompt
    assert "intentId" in prompt
    assert "intentName" in prompt
    assert "intentType" in prompt


def test_extract_json_from_response():
    """Test JSON extraction from various response formats"""
    # Test clean JSON
    clean_json = '{"intentId": "test-123", "intentName": "Test Intent"}'
    result = extract_json_from_response(clean_json)
    assert result["intentId"] == "test-123"
    assert result["intentName"] == "Test Intent"
    
    # Test JSON with surrounding text
    mixed_response = 'Here is the JSON: {"intentId": "test-456", "intentName": "Another Intent"} That\'s it!'
    result = extract_json_from_response(mixed_response)
    assert result["intentId"] == "test-456"
    
    # Test JSON without intentId (should add one)
    no_id_json = '{"intentName": "No ID Intent", "intentType": "TestType"}'
    result = extract_json_from_response(no_id_json)
    assert "intentId" in result
    assert result["intentId"].startswith("intent-")
    
    # Test JSON without requestTime (should add one)
    no_time_json = '{"intentId": "test-789", "intentName": "No Time Intent"}'
    result = extract_json_from_response(no_time_json)
    assert "requestTime" in result
    assert result["requestTime"].endswith("Z")


def test_validate_intent_structure():
    """Test intent structure validation"""
    # Test with missing fields
    incomplete_intent = {
        "intentName": "Test Intent",
        "intentType": "TestType"
    }
    
    validated = validate_intent_structure(incomplete_intent)
    
    # Check that missing fields are added
    assert "intentId" in validated
    assert "priority" in validated
    assert validated["priority"] == "medium"
    assert "intentParameters" in validated
    assert isinstance(validated["intentParameters"], dict)
    
    # Test with complete intent
    complete_intent = {
        "intentId": "test-123",
        "intentName": "Complete Intent",
        "intentType": "NetworkSlice",
        "scope": "5G",
        "priority": "high",
        "intentParameters": {"sliceType": "eMBB"}
    }
    
    validated = validate_intent_structure(complete_intent)
    assert validated == complete_intent  # Should remain unchanged


def test_generate_intent_empty_request():
    """Test generate_intent with empty request"""
    response = client.post(
        "/generate_intent",
        json={"text": ""}
    )
    assert response.status_code == 422  # Validation error


def test_generate_intent_missing_text():
    """Test generate_intent with missing text field"""
    response = client.post(
        "/generate_intent",
        json={}
    )
    assert response.status_code == 422  # Validation error


@patch('main.call_claude_cli')
def test_generate_intent_success(mock_claude):
    """Test successful intent generation"""
    # Mock Claude's response
    mock_claude.return_value = json.dumps({
        "intentId": "intent-test-123",
        "intentName": "Deploy Network Slice",
        "intentType": "NetworkSliceDeployment",
        "scope": "5G-NetworkSlice",
        "priority": "high",
        "requestTime": "2025-01-12T10:30:00Z",
        "intentParameters": {
            "sliceType": "eMBB",
            "capacity": 1000
        }
    })
    
    response = client.post(
        "/generate_intent",
        json={"text": "Deploy a 5G network slice"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["intentId"] == "intent-test-123"
    assert data["intentName"] == "Deploy Network Slice"
    assert data["intentType"] == "NetworkSliceDeployment"
    assert data["priority"] == "high"
    assert "intentParameters" in data


@patch('main.call_claude_cli')
def test_generate_intent_claude_error(mock_claude):
    """Test handling of Claude CLI errors"""
    mock_claude.side_effect = Exception("Claude CLI not available")
    
    response = client.post(
        "/generate_intent",
        json={"text": "Deploy a network slice"}
    )
    
    assert response.status_code == 500
    data = response.json()
    assert "error" in data["detail"].lower() or "unexpected" in data["detail"].lower()


@patch('main.subprocess.run')
def test_call_claude_cli_timeout(mock_run):
    """Test handling of Claude CLI timeout"""
    import subprocess
    mock_run.side_effect = subprocess.TimeoutExpired("claude", 30)
    
    response = client.post(
        "/generate_intent",
        json={"text": "Deploy a network slice"}
    )
    
    assert response.status_code == 504
    data = response.json()
    assert "timeout" in data["detail"].lower() or "timed out" in data["detail"].lower()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])