#!/usr/bin/env python3
"""
LLM Adapter Service for VM-3
Converts natural language requests to structured intents
"""

import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field, validator
import uvicorn
import jsonschema

# Import the LLM client
from adapters.llm_client import get_llm_client

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load JSON schema
SCHEMA_PATH = Path(__file__).parent / "schema.json"
if SCHEMA_PATH.exists():
    with open(SCHEMA_PATH) as f:
        TMF921_SCHEMA = json.load(f)
else:
    TMF921_SCHEMA = None
    logger.warning("TMF921 schema not found, validation disabled")


app = FastAPI(
    title="LLM Intent Adapter",
    description="Converts natural language to structured intents",
    version="1.0.0"
)

# Initialize LLM client
llm_client = get_llm_client()


class IntentRequest(BaseModel):
    """Request model for intent generation"""
    text: Optional[str] = Field(None, description="Natural language request text (legacy)")
    natural_language: Optional[str] = Field(None, description="Natural language request text (ACC-12 format)")
    target_site: Optional[str] = Field(None, description="Target deployment site (edge1, edge2, both)")

    @validator('text', 'natural_language')
    def text_not_empty(cls, v):
        if v is not None and (not v or not v.strip()):
            raise ValueError('Request text cannot be empty')
        return v.strip() if v else None

    def get_text(self) -> str:
        """Get the actual text content from either field"""
        if self.natural_language:
            return self.natural_language
        elif self.text:
            return self.text
        else:
            raise ValueError('Either text or natural_language field is required')


class QoSParameters(BaseModel):
    """QoS parameters for the intent"""
    downlink_mbps: Optional[int] = None
    uplink_mbps: Optional[int] = None
    latency_ms: Optional[int] = None


class IntentContent(BaseModel):
    """The actual intent content"""
    service: str = Field(..., description="Service type: eMBB, URLLC, or mMTC")
    location: str = Field(..., description="Location identifier")
    qos: QoSParameters


class UnifiedIntentResponse(BaseModel):
    """Unified response format for all intent endpoints"""
    intent: IntentContent
    raw_text: str
    model: str = "rule-based"
    version: str = "1.0.0"


class TMF921Intent(BaseModel):
    """TMF921-compliant Intent structure (pure JSON format)"""
    intentId: str
    intentName: str
    intentType: str
    scope: str
    priority: str
    requestTime: str
    intentParameters: Dict[str, Any]
    constraints: Optional[Dict[str, Any]] = None
    targetEntities: Optional[list] = None
    expectedOutcome: Optional[str] = None


async def parse_intent(request: IntentRequest) -> UnifiedIntentResponse:
    """
    Common handler for intent parsing using pluggable LLM client
    """
    try:
        text = request.get_text()
        # Use the LLM client to parse text
        intent_dict = llm_client.parse_text(text)

        # Get model information
        model_info = llm_client.get_model_info()

        # Build response
        return UnifiedIntentResponse(
            intent=IntentContent(
                service=intent_dict["service"],
                location=intent_dict["location"],
                qos=QoSParameters(**intent_dict["qos"])
            ),
            raw_text=text,
            model=model_info,
            version="1.0.0"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Intent parsing failed: {str(e)}")


async def generate_tmf921_intent(request: IntentRequest) -> TMF921Intent:
    """
    Generate TMF921-compliant Intent from natural language text
    """
    try:
        text = request.get_text()
        # Use the LLM client to parse text
        intent_dict = llm_client.parse_text(text)

        # Convert to TMF921 format
        tmf921_dict = llm_client.convert_to_tmf921(intent_dict, text, request.target_site)

        # Validate against schema if available
        if TMF921_SCHEMA:
            try:
                jsonschema.validate(tmf921_dict, TMF921_SCHEMA)
                logger.info("TMF921 intent validated successfully")
            except jsonschema.ValidationError as ve:
                logger.error(f"Schema validation failed: {ve.message}")
                # Log to artifacts for debugging
                _log_validation_error(text, tmf921_dict, str(ve))
                raise HTTPException(status_code=400, detail=f"Schema validation failed: {ve.message}")

        return TMF921Intent(**tmf921_dict)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"TMF921 intent generation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"TMF921 intent generation failed: {str(e)}")


def _log_validation_error(text: str, intent_dict: Dict[str, Any], error: str):
    """Log validation errors to artifacts"""
    try:
        artifacts_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter')
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.utcnow().isoformat()
        error_log = {
            "timestamp": timestamp,
            "event": "validation_error",
            "input_text": text,
            "generated_intent": intent_dict,
            "error": error
        }

        error_file = artifacts_dir / f"validation_errors_{datetime.utcnow().strftime('%Y%m%d')}.jsonl"
        with open(error_file, 'a') as f:
            f.write(json.dumps(error_log) + '\n')
    except Exception as e:
        logger.warning(f"Failed to log validation error: {e}")


@app.get("/health")
@app.head("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "LLM Intent Adapter",
        "version": "1.0.0",
        "llm_mode": llm_client.get_model_info()
    }


@app.post("/generate_intent", response_model=TMF921Intent)
async def generate_intent(request: IntentRequest):
    """
    Generate TMF921-compliant Intent from natural language text.
    Returns pure JSON TMF921/3GPP Intent format.
    Validates against TMF921 schema and returns 400 on invalid.
    """
    return await generate_tmf921_intent(request)


@app.post("/api/v1/intent/parse", response_model=UnifiedIntentResponse)
async def parse_intent_v1(request: IntentRequest):
    """
    Parse intent from natural language text.
    Standard API v1 endpoint.
    """
    return await parse_intent(request)


@app.get("/", response_class=HTMLResponse)
@app.head("/", response_class=HTMLResponse)
async def root():
    """Serve the web UI"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>LLM Intent Adapter</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                max-width: 1200px;
                margin: 0 auto;
                padding: 40px 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }
            .container {
                background: white;
                border-radius: 12px;
                padding: 30px;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            }
            h1 {
                color: #333;
                border-bottom: 3px solid #667eea;
                padding-bottom: 10px;
                margin-bottom: 30px;
            }
            .status-info {
                background: #f0f4ff;
                padding: 10px 15px;
                border-radius: 8px;
                margin-bottom: 20px;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .status-badge {
                background: #667eea;
                color: white;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 14px;
                font-weight: 600;
            }
            .input-group {
                margin-bottom: 20px;
            }
            label {
                display: block;
                margin-bottom: 8px;
                color: #555;
                font-weight: 600;
            }
            textarea {
                width: 100%;
                padding: 12px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                font-size: 16px;
                resize: vertical;
                min-height: 120px;
                transition: border-color 0.3s;
            }
            textarea:focus {
                outline: none;
                border-color: #667eea;
            }
            .button-group {
                display: flex;
                gap: 10px;
                margin-bottom: 20px;
            }
            button {
                flex: 1;
                padding: 12px 24px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                border-radius: 8px;
                font-size: 16px;
                font-weight: 600;
                cursor: pointer;
                transition: transform 0.2s, box-shadow 0.2s;
            }
            button:hover {
                transform: translateY(-2px);
                box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
            }
            .output-section {
                margin-top: 30px;
            }
            .output-box {
                background: #f8f9fa;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                padding: 20px;
                min-height: 200px;
                font-family: 'Courier New', monospace;
                white-space: pre-wrap;
                word-wrap: break-word;
                max-height: 600px;
                overflow-y: auto;
            }
            .example-section {
                margin-top: 30px;
                padding: 20px;
                background: #f0f4ff;
                border-radius: 8px;
            }
            .example-section h3 {
                color: #667eea;
                margin-top: 0;
            }
            .example {
                background: white;
                padding: 10px;
                margin: 8px 0;
                border-radius: 6px;
                cursor: pointer;
                transition: background 0.2s;
            }
            .example:hover {
                background: #f8f9fa;
            }
            .api-info {
                margin-top: 30px;
                padding: 20px;
                background: #fff9e6;
                border-radius: 8px;
                border: 1px solid #ffe082;
            }
            .api-info h3 {
                color: #f57c00;
                margin-top: 0;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 LLM Intent Adapter Service</h1>
            
            <div class="status-info">
                <span>Service Status: <strong>Online</strong></span>
                <span class="status-badge" id="llm-mode">Loading...</span>
            </div>
            
            <div class="input-group">
                <label for="intentText">Enter Natural Language Request:</label>
                <textarea id="intentText" placeholder="Example: Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency"></textarea>
            </div>
            
            <div class="button-group">
                <button onclick="generateIntent('/generate_intent')">Generate Intent (Legacy)</button>
                <button onclick="generateIntent('/api/v1/intent/parse')">Parse Intent (API v1)</button>
            </div>
            
            <div class="output-section">
                <h2>Output:</h2>
                <div id="output" class="output-box">Response will appear here...</div>
            </div>
            
            <div class="example-section">
                <h3>📝 Example Requests (Click to use):</h3>
                <div class="example" onclick="setExample('Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency')">
                    Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency
                </div>
                <div class="example" onclick="setExample('Create URLLC service in edge2 with 10ms latency and 100Mbps downlink')">
                    Create URLLC service in edge2 with 10ms latency and 100Mbps downlink
                </div>
                <div class="example" onclick="setExample('Setup mMTC network in zone3 for IoT devices with 50Mbps capacity')">
                    Setup mMTC network in zone3 for IoT devices with 50Mbps capacity
                </div>
            </div>
            
            <div class="api-info">
                <h3>🔌 API Endpoints (Port 8888):</h3>
                <p><strong>GET /health</strong> - Health check with LLM mode status</p>
                <p><strong>POST /generate_intent</strong> - Legacy intent generation</p>
                <p><strong>POST /api/v1/intent/parse</strong> - Standard v1 API</p>
                <p><strong>GET /docs</strong> - Swagger documentation</p>
            </div>
        </div>
        
        <script>
            // Check LLM mode on load
            fetch('/health')
                .then(res => res.json())
                .then(data => {
                    const badge = document.getElementById('llm-mode');
                    badge.textContent = 'Mode: ' + (data.llm_mode || 'rule-based');
                    if (data.llm_mode === 'claude-cli') {
                        badge.style.background = '#4caf50';
                    }
                });
            
            function setExample(text) {
                document.getElementById('intentText').value = text;
            }
            
            async function generateIntent(endpoint) {
                const text = document.getElementById('intentText').value;
                const output = document.getElementById('output');
                
                if (!text.trim()) {
                    output.textContent = 'Please enter a request text';
                    return;
                }
                
                output.textContent = 'Processing...';
                
                try {
                    const response = await fetch(endpoint, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({ text: text })
                    });
                    
                    const data = await response.json();
                    output.textContent = JSON.stringify(data, null, 2);
                    
                } catch (error) {
                    output.textContent = 'Error: ' + error.message;
                }
            }
        </script>
    </body>
    </html>
    """
    return html_content


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8888)