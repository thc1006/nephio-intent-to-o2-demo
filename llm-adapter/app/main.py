from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import subprocess
import json
import uuid
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import re

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LLM Adapter Service", version="1.0.0")

class IntentRequest(BaseModel):
    text: str
    context: Optional[Dict[str, Any]] = None

class IntentResponse(BaseModel):
    intent: Dict[str, Any]
    metadata: Dict[str, Any]

def call_claude_cli(prompt: str) -> str:
    """Call Claude CLI via subprocess to process the prompt."""
    try:
        cmd = ["claude", "-p", prompt]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            logger.error(f"Claude CLI error: {result.stderr}")
            raise RuntimeError(f"Claude CLI failed: {result.stderr}")
        
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        logger.error("Claude CLI timed out")
        raise RuntimeError("Claude CLI request timed out")
    except Exception as e:
        logger.error(f"Error calling Claude CLI: {e}")
        raise

def extract_json_from_response(response: str) -> Dict[str, Any]:
    """Extract JSON from Claude's response, handling various formats."""
    try:
        return json.loads(response)
    except json.JSONDecodeError:
        json_match = re.search(r'\{[\s\S]*\}', response)
        if json_match:
            try:
                return json.loads(json_match.group())
            except json.JSONDecodeError:
                pass
        
        logger.error(f"Could not parse JSON from response: {response}")
        raise ValueError("Failed to extract valid JSON from Claude response")

def generate_tmf921_intent(user_request: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Generate a TMF921-compliant intent from user request using Claude."""
    
    prompt = f"""You are an expert in 3GPP and TMF921 Intent interpretation. Convert the following user request into a TMF921-compliant Intent in JSON format.

The JSON must include these fields:
- intentId: unique identifier (UUID format)
- intentName: descriptive name for the intent
- intentType: one of "SERVICE_INTENT", "RESOURCE_INTENT", "NETWORK_SLICE_INTENT"
- intentState: "CREATED"
- intentPriority: number 1-10 (10 being highest)
- intentExpectations: array of expectation objects, each containing:
  - expectationId: unique identifier
  - expectationName: name of the expectation
  - expectationType: type of expectation (e.g., "PERFORMANCE", "CAPACITY", "COVERAGE")
  - expectationTargets: array of target objects with targetName, targetValue, targetUnit
- intentMetadata: object with createdAt timestamp and any relevant metadata

Output ONLY valid JSON, no additional text or explanation.

User request: "{user_request}"
"""
    
    if context:
        prompt += f"\nAdditional context: {json.dumps(context)}"
    
    try:
        response = call_claude_cli(prompt)
        intent_json = extract_json_from_response(response)
        
        if "intentId" not in intent_json:
            intent_json["intentId"] = str(uuid.uuid4())
        if "intentMetadata" not in intent_json:
            intent_json["intentMetadata"] = {}
        if "createdAt" not in intent_json["intentMetadata"]:
            intent_json["intentMetadata"]["createdAt"] = datetime.utcnow().isoformat()
        
        return intent_json
    except Exception as e:
        logger.error(f"Failed to generate intent: {e}")
        
        fallback_intent = {
            "intentId": str(uuid.uuid4()),
            "intentName": "Fallback Intent",
            "intentType": "SERVICE_INTENT",
            "intentState": "CREATED",
            "intentPriority": 5,
            "userRequest": user_request,
            "error": str(e),
            "intentMetadata": {
                "createdAt": datetime.utcnow().isoformat(),
                "generationFailed": True
            }
        }
        return fallback_intent

@app.post("/generate_intent", response_model=IntentResponse)
async def generate_intent(request: IntentRequest):
    """Generate TMF921-compliant intent from natural language request."""
    try:
        logger.info(f"Processing intent request: {request.text[:100]}...")
        
        intent = generate_tmf921_intent(request.text, request.context)
        
        metadata = {
            "processedAt": datetime.utcnow().isoformat(),
            "requestLength": len(request.text),
            "success": not intent.get("intentMetadata", {}).get("generationFailed", False)
        }
        
        return IntentResponse(intent=intent, metadata=metadata)
    
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    """Serve the web UI for testing."""
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>LLM Intent Adapter - TMF921 Generator</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }
            .container {
                background: white;
                border-radius: 10px;
                padding: 30px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            }
            h1 {
                color: #333;
                margin-bottom: 10px;
            }
            .subtitle {
                color: #666;
                margin-bottom: 30px;
            }
            .input-group {
                margin-bottom: 20px;
            }
            label {
                display: block;
                margin-bottom: 5px;
                color: #555;
                font-weight: 500;
            }
            textarea {
                width: 100%;
                padding: 12px;
                border: 2px solid #e0e0e0;
                border-radius: 5px;
                font-size: 14px;
                resize: vertical;
                transition: border-color 0.3s;
            }
            textarea:focus {
                outline: none;
                border-color: #667eea;
            }
            button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                padding: 12px 30px;
                border-radius: 5px;
                font-size: 16px;
                cursor: pointer;
                transition: transform 0.2s;
            }
            button:hover {
                transform: translateY(-2px);
            }
            button:disabled {
                opacity: 0.5;
                cursor: not-allowed;
            }
            .output-section {
                margin-top: 30px;
                padding-top: 20px;
                border-top: 2px solid #e0e0e0;
            }
            #output {
                background: #f5f5f5;
                padding: 15px;
                border-radius: 5px;
                white-space: pre-wrap;
                font-family: 'Monaco', 'Menlo', monospace;
                font-size: 12px;
                max-height: 500px;
                overflow-y: auto;
            }
            .loading {
                display: none;
                color: #667eea;
                margin-top: 10px;
            }
            .error {
                color: #e53e3e;
                margin-top: 10px;
                display: none;
            }
            .examples {
                margin-top: 20px;
                padding: 15px;
                background: #f7fafc;
                border-radius: 5px;
            }
            .example-item {
                margin: 5px 0;
                color: #4a5568;
                cursor: pointer;
                padding: 5px;
                border-radius: 3px;
                transition: background 0.2s;
            }
            .example-item:hover {
                background: #e2e8f0;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🤖 LLM Intent Adapter</h1>
            <p class="subtitle">Convert natural language requests to TMF921-compliant intents</p>
            
            <div class="input-group">
                <label for="request">Enter your natural language request:</label>
                <textarea id="request" rows="4" placeholder="e.g., Deploy a 5G network slice with low latency for gaming services in downtown area"></textarea>
            </div>
            
            <div class="examples">
                <strong>Example Requests (click to use):</strong>
                <div class="example-item" onclick="setExample('Deploy a 5G network slice with ultra-low latency for gaming services')">
                    📱 Deploy a 5G network slice with ultra-low latency for gaming services
                </div>
                <div class="example-item" onclick="setExample('Create a network service with 99.99% availability and 10Gbps throughput')">
                    🌐 Create a network service with 99.99% availability and 10Gbps throughput
                </div>
                <div class="example-item" onclick="setExample('Provision edge computing resources for IoT devices in manufacturing plant')">
                    🏭 Provision edge computing resources for IoT devices in manufacturing plant
                </div>
            </div>
            
            <button onclick="generateIntent()">Generate Intent</button>
            <div class="loading">⏳ Processing request...</div>
            <div class="error" id="error"></div>
            
            <div class="output-section">
                <label>Generated TMF921 Intent (JSON):</label>
                <pre id="output">Output will appear here...</pre>
            </div>
        </div>
        
        <script>
            function setExample(text) {
                document.getElementById('request').value = text;
            }
            
            async function generateIntent() {
                const request = document.getElementById('request').value;
                if (!request.trim()) {
                    alert('Please enter a request');
                    return;
                }
                
                const button = document.querySelector('button');
                const loading = document.querySelector('.loading');
                const error = document.getElementById('error');
                const output = document.getElementById('output');
                
                button.disabled = true;
                loading.style.display = 'block';
                error.style.display = 'none';
                output.textContent = 'Generating...';
                
                try {
                    const response = await fetch('/generate_intent', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ text: request })
                    });
                    
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    
                    const data = await response.json();
                    output.textContent = JSON.stringify(data.intent, null, 2);
                } catch (err) {
                    error.textContent = 'Error: ' + err.message;
                    error.style.display = 'block';
                    output.textContent = 'Failed to generate intent';
                } finally {
                    button.disabled = false;
                    loading.style.display = 'none';
                }
            }
        </script>
    </body>
    </html>
    """
    return html_content

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)