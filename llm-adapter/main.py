#!/usr/bin/env python3
"""
LLM Adapter Service for VM-3
Converts natural language requests to structured intents
"""

from datetime import datetime
from typing import Dict, Any, Optional

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, Field, validator
import uvicorn

# Import the LLM client
from adapters.llm_client import get_llm_client


app = FastAPI(
    title="LLM Intent Adapter",
    description="Converts natural language to structured intents",
    version="1.0.0"
)

# Initialize LLM client
llm_client = get_llm_client()


class IntentRequest(BaseModel):
    """Request model for intent generation"""
    text: str = Field(..., description="Natural language request text")
    
    @validator('text')
    def text_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Request text cannot be empty')
        return v.strip()


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


async def parse_intent(request: IntentRequest) -> UnifiedIntentResponse:
    """
    Common handler for intent parsing using pluggable LLM client
    """
    try:
        # Use the LLM client to parse text
        intent_dict = llm_client.parse_text(request.text)
        
        # Get model information
        model_info = llm_client.get_model_info()
        
        # Build response
        return UnifiedIntentResponse(
            intent=IntentContent(
                service=intent_dict["service"],
                location=intent_dict["location"],
                qos=QoSParameters(**intent_dict["qos"])
            ),
            raw_text=request.text,
            model=model_info,
            version="1.0.0"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Intent parsing failed: {str(e)}")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "LLM Intent Adapter",
        "version": "1.0.0",
        "llm_mode": llm_client.get_model_info()
    }


@app.post("/generate_intent", response_model=UnifiedIntentResponse)
async def generate_intent(request: IntentRequest):
    """
    Generate intent from natural language text.
    Legacy endpoint for backward compatibility.
    """
    return await parse_intent(request)


@app.post("/api/v1/intent/parse", response_model=UnifiedIntentResponse)
async def parse_intent_v1(request: IntentRequest):
    """
    Parse intent from natural language text.
    Standard API v1 endpoint.
    """
    return await parse_intent(request)


@app.get("/", response_class=HTMLResponse)
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