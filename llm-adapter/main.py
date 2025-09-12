#!/usr/bin/env python3
"""
LLM Adapter Service for VM-3
Converts natural language requests to TMF921-compliant JSON intents using Claude
"""

import json
import subprocess
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path
import tempfile
import re

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field, validator
import uvicorn


app = FastAPI(
    title="LLM Intent Adapter",
    description="Converts natural language to TMF921-compliant JSON intents",
    version="1.0.0"
)


class IntentRequest(BaseModel):
    """Request model for intent generation"""
    text: str = Field(..., description="Natural language request text")
    
    @validator('text')
    def text_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Request text cannot be empty')
        return v.strip()


class TMF921Intent(BaseModel):
    """TMF921-compliant Intent structure"""
    intentId: str
    intentName: str
    intentType: str
    scope: str
    priority: str
    requestTime: str
    constraints: Optional[Dict[str, Any]] = None
    intentParameters: Dict[str, Any]
    targetEntities: Optional[list] = None
    expectedOutcome: Optional[str] = None
    
    class Config:
        schema_extra = {
            "example": {
                "intentId": "intent-123e4567-e89b",
                "intentName": "Deploy Network Slice",
                "intentType": "NetworkSliceDeployment",
                "scope": "5G-NetworkSlice",
                "priority": "high",
                "requestTime": "2025-01-12T10:30:00Z",
                "constraints": {
                    "maxLatency": "10ms",
                    "minBandwidth": "100Mbps"
                },
                "intentParameters": {
                    "sliceType": "eMBB",
                    "capacity": 1000,
                    "location": "zone-1"
                },
                "targetEntities": ["NetworkFunction1", "NetworkFunction2"],
                "expectedOutcome": "Network slice deployed and operational"
            }
        }


def create_claude_prompt(user_request: str) -> str:
    """Create a structured prompt for Claude"""
    prompt = f"""You are an expert in 3GPP and TMF921 Intent interpretation. Convert the following user request into a TMF921-compliant Intent in JSON format.

The JSON must include these required fields:
- intentId: A unique identifier (use UUID format)
- intentName: A descriptive name for the intent
- intentType: The type of intent (e.g., NetworkSliceDeployment, ServiceProvisioning, ResourceAllocation)
- scope: The scope of the intent (e.g., 5G-NetworkSlice, ServiceLevel, Infrastructure)
- priority: Priority level (high, medium, low)
- requestTime: Current timestamp in ISO format
- intentParameters: Object containing specific parameters for the intent
- constraints: (optional) Any constraints or requirements
- targetEntities: (optional) List of target entities or resources
- expectedOutcome: (optional) Expected outcome description

Output ONLY valid JSON with no additional text or explanation.

User request: "{user_request}"
"""
    return prompt


def call_claude_cli(prompt: str) -> str:
    """Call Claude CLI to process the prompt"""
    try:
        # Use --print flag to get non-interactive output
        cmd = [
            'claude',
            '--print',
            prompt
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"Claude CLI error: {result.stderr}")
        
        return result.stdout.strip()
        
    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Claude request timed out")
    except FileNotFoundError:
        raise HTTPException(
            status_code=503, 
            detail="Claude CLI not found. Please ensure Claude is installed and logged in."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error calling Claude: {str(e)}")


def extract_json_from_response(response: str) -> Dict[str, Any]:
    """Extract JSON from Claude's response"""
    response = response.strip()
    
    json_match = re.search(r'\{[\s\S]*\}', response)
    if json_match:
        json_str = json_match.group()
    else:
        json_str = response
    
    try:
        intent_json = json.loads(json_str)
        
        if 'intentId' not in intent_json:
            intent_json['intentId'] = f"intent-{uuid.uuid4()}"
        if 'requestTime' not in intent_json:
            intent_json['requestTime'] = datetime.utcnow().isoformat() + 'Z'
        
        return intent_json
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to parse Claude's response as JSON: {str(e)}"
        )


def validate_intent_structure(intent_json: Dict[str, Any]) -> Dict[str, Any]:
    """Validate the intent structure against TMF921 requirements"""
    required_fields = [
        'intentId', 'intentName', 'intentType', 
        'scope', 'priority', 'intentParameters'
    ]
    
    missing_fields = [field for field in required_fields if field not in intent_json]
    if missing_fields:
        for field in missing_fields:
            if field == 'intentId':
                intent_json['intentId'] = f"intent-{uuid.uuid4()}"
            elif field == 'requestTime':
                intent_json['requestTime'] = datetime.utcnow().isoformat() + 'Z'
            elif field == 'priority':
                intent_json['priority'] = 'medium'
            elif field == 'intentParameters':
                intent_json['intentParameters'] = {}
    
    return intent_json


@app.post("/generate_intent", response_model=TMF921Intent)
async def generate_intent(request: IntentRequest):
    """Generate TMF921-compliant intent from natural language request"""
    try:
        prompt = create_claude_prompt(request.text)
        
        claude_response = call_claude_cli(prompt)
        
        intent_json = extract_json_from_response(claude_response)
        
        validated_intent = validate_intent_structure(intent_json)
        
        return JSONResponse(content=validated_intent)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")


@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    """Serve the minimal web UI for testing"""
    html_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LLM Intent Adapter</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #007bff;
            padding-bottom: 10px;
        }
        .container {
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 600;
            color: #555;
        }
        textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
            resize: vertical;
            min-height: 100px;
        }
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            margin-top: 10px;
        }
        button:hover {
            background: #0056b3;
        }
        button:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        #result {
            margin-top: 20px;
            white-space: pre-wrap;
            background: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            border: 1px solid #dee2e6;
            font-family: 'Courier New', monospace;
            font-size: 13px;
            max-height: 500px;
            overflow-y: auto;
        }
        .error {
            color: #dc3545;
            background: #f8d7da;
            border-color: #f5c6cb;
        }
        .success {
            color: #155724;
            background: #d4edda;
            border-color: #c3e6cb;
        }
        .loading {
            color: #004085;
            background: #cce5ff;
            border-color: #b8daff;
        }
        .examples {
            margin-top: 20px;
            padding: 15px;
            background: #f0f8ff;
            border-radius: 4px;
            border: 1px solid #b0d4ff;
        }
        .example-item {
            margin: 10px 0;
            padding: 8px;
            background: white;
            border-radius: 4px;
            cursor: pointer;
            transition: background 0.2s;
        }
        .example-item:hover {
            background: #e7f3ff;
        }
    </style>
</head>
<body>
    <h1>🤖 LLM Intent Adapter - TMF921 Compliant</h1>
    
    <div class="container">
        <label for="request">Natural Language Request:</label>
        <textarea 
            id="request" 
            placeholder="Enter your request in natural language, e.g., 'Deploy a 5G network slice with low latency for IoT devices in zone-1'"
        ></textarea>
        <button onclick="generateIntent()" id="submitBtn">Generate Intent JSON</button>
    </div>
    
    <div class="examples">
        <strong>Example Requests (click to use):</strong>
        <div class="example-item" onclick="useExample(this)">
            Deploy a 5G network slice with low latency requirements for IoT devices in zone-1
        </div>
        <div class="example-item" onclick="useExample(this)">
            Provision a new service with 100Mbps bandwidth and 99.9% availability SLA
        </div>
        <div class="example-item" onclick="useExample(this)">
            Allocate compute resources for edge computing with 16 vCPUs and 64GB RAM
        </div>
        <div class="example-item" onclick="useExample(this)">
            Configure network function with auto-scaling enabled and max instances of 10
        </div>
    </div>
    
    <div class="container">
        <label>Generated Intent JSON:</label>
        <div id="result">Result will appear here...</div>
    </div>
    
    <script>
        function useExample(element) {
            document.getElementById('request').value = element.textContent.trim();
        }
        
        async function generateIntent() {
            const requestText = document.getElementById('request').value.trim();
            const resultDiv = document.getElementById('result');
            const submitBtn = document.getElementById('submitBtn');
            
            if (!requestText) {
                resultDiv.className = 'error';
                resultDiv.textContent = 'Please enter a request';
                return;
            }
            
            submitBtn.disabled = true;
            submitBtn.textContent = 'Generating...';
            resultDiv.className = 'loading';
            resultDiv.textContent = 'Processing request with Claude...';
            
            try {
                const response = await fetch('/generate_intent', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ text: requestText })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    resultDiv.className = 'success';
                    resultDiv.textContent = JSON.stringify(data, null, 2);
                } else {
                    resultDiv.className = 'error';
                    resultDiv.textContent = `Error: ${data.detail || 'Failed to generate intent'}`;
                }
            } catch (error) {
                resultDiv.className = 'error';
                resultDiv.textContent = `Error: ${error.message}`;
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Generate Intent JSON';
            }
        }
        
        document.getElementById('request').addEventListener('keydown', function(e) {
            if (e.ctrlKey && e.key === 'Enter') {
                generateIntent();
            }
        });
    </script>
</body>
</html>
"""
    return html_content


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "LLM Intent Adapter", "version": "1.0.0"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)