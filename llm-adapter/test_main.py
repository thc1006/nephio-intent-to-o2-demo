#!/usr/bin/env python3
"""
Unit tests for LLM Adapter Service
"""

import json
import unittest
from unittest.mock import patch, MagicMock
from datetime import datetime

from main import (
    create_claude_prompt,
    extract_json_from_response,
    validate_intent_structure,
    IntentRequest,
    TMF921Intent
)


class TestLLMAdapter(unittest.TestCase):
    """Test cases for LLM Adapter functions"""
    
    def test_create_claude_prompt(self):
        """Test prompt creation"""
        user_request = "Deploy a 5G network slice"
        prompt = create_claude_prompt(user_request)
        
        self.assertIn("TMF921-compliant", prompt)
        self.assertIn(user_request, prompt)
        self.assertIn("intentId", prompt)
        self.assertIn("intentName", prompt)
    
    def test_extract_json_from_response_valid(self):
        """Test JSON extraction from valid response"""
        response = '''
        Here is the JSON:
        {
            "intentId": "test-123",
            "intentName": "Test Intent",
            "intentType": "TestType",
            "scope": "TestScope",
            "priority": "high",
            "intentParameters": {}
        }
        '''
        
        result = extract_json_from_response(response)
        self.assertEqual(result['intentId'], 'test-123')
        self.assertEqual(result['intentName'], 'Test Intent')
    
    def test_extract_json_from_response_only_json(self):
        """Test JSON extraction when response is only JSON"""
        response = '''{
            "intentId": "test-456",
            "intentName": "Pure JSON",
            "intentType": "TestType",
            "scope": "TestScope",
            "priority": "medium",
            "intentParameters": {"key": "value"}
        }'''
        
        result = extract_json_from_response(response)
        self.assertEqual(result['intentId'], 'test-456')
        self.assertEqual(result['intentParameters']['key'], 'value')
    
    def test_extract_json_adds_missing_fields(self):
        """Test that missing required fields are added"""
        response = '''{
            "intentName": "Test Intent",
            "intentType": "TestType",
            "scope": "TestScope",
            "priority": "low",
            "intentParameters": {}
        }'''
        
        result = extract_json_from_response(response)
        self.assertIn('intentId', result)
        self.assertIn('requestTime', result)
        self.assertTrue(result['intentId'].startswith('intent-'))
    
    def test_validate_intent_structure_complete(self):
        """Test validation with complete structure"""
        intent = {
            "intentId": "test-789",
            "intentName": "Complete Intent",
            "intentType": "TestType",
            "scope": "TestScope",
            "priority": "high",
            "intentParameters": {"param1": "value1"}
        }
        
        result = validate_intent_structure(intent)
        self.assertEqual(result['intentId'], 'test-789')
        self.assertEqual(result['priority'], 'high')
    
    def test_validate_intent_structure_adds_defaults(self):
        """Test validation adds default values for missing fields"""
        intent = {
            "intentName": "Incomplete Intent",
            "intentType": "TestType",
            "scope": "TestScope"
        }
        
        result = validate_intent_structure(intent)
        self.assertIn('intentId', result)
        self.assertEqual(result['priority'], 'medium')
        self.assertIsInstance(result['intentParameters'], dict)
    
    def test_intent_request_validation(self):
        """Test IntentRequest model validation"""
        valid_request = IntentRequest(text="Deploy network slice")
        self.assertEqual(valid_request.text, "Deploy network slice")
        
        with self.assertRaises(ValueError):
            IntentRequest(text="")
        
        with self.assertRaises(ValueError):
            IntentRequest(text="   ")
    
    def test_tmf921_intent_structure(self):
        """Test TMF921Intent model structure"""
        intent_data = {
            "intentId": "test-intent-001",
            "intentName": "Test Network Deployment",
            "intentType": "NetworkDeployment",
            "scope": "5G-Core",
            "priority": "high",
            "requestTime": datetime.utcnow().isoformat() + 'Z',
            "intentParameters": {
                "capacity": 1000,
                "location": "zone-1"
            },
            "constraints": {
                "maxLatency": "5ms"
            },
            "targetEntities": ["NF1", "NF2"],
            "expectedOutcome": "Network deployed"
        }
        
        intent = TMF921Intent(**intent_data)
        self.assertEqual(intent.intentId, "test-intent-001")
        self.assertEqual(intent.priority, "high")
        self.assertEqual(intent.intentParameters["capacity"], 1000)
    
    @patch('main.subprocess.run')
    def test_call_claude_cli_success(self, mock_run):
        """Test successful Claude CLI call"""
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = '{"intentId": "test", "intentName": "Test"}'
        mock_result.stderr = ""
        mock_run.return_value = mock_result
        
        from main import call_claude_cli
        result = call_claude_cli("Test prompt")
        self.assertIn("intentId", result)
    
    @patch('main.subprocess.run')
    def test_call_claude_cli_failure(self, mock_run):
        """Test Claude CLI call failure"""
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = "Error: Command failed"
        mock_run.return_value = mock_result
        
        from main import call_claude_cli
        from fastapi import HTTPException
        
        with self.assertRaises(HTTPException):
            call_claude_cli("Test prompt")


class TestIntegration(unittest.TestCase):
    """Integration tests for the complete flow"""
    
    def test_sample_intent_structures(self):
        """Test various sample intent structures"""
        sample_intents = [
            {
                "description": "Network Slice Deployment",
                "input": "Deploy a 5G network slice with low latency for IoT",
                "expected_fields": ["intentType", "scope", "intentParameters"]
            },
            {
                "description": "Service Provisioning",
                "input": "Provision service with 100Mbps bandwidth",
                "expected_fields": ["intentType", "constraints", "intentParameters"]
            },
            {
                "description": "Resource Allocation",
                "input": "Allocate 16 vCPUs and 64GB RAM for edge computing",
                "expected_fields": ["intentType", "intentParameters", "scope"]
            }
        ]
        
        for sample in sample_intents:
            prompt = create_claude_prompt(sample["input"])
            self.assertIn(sample["input"], prompt)
            for field in sample["expected_fields"]:
                self.assertIn(field, prompt)


if __name__ == '__main__':
    unittest.main()