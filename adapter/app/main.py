#!/usr/bin/env python3
"""
LLM Adapter for TMF921 Intent Generation
Converts natural language to TMF921-compliant JSON with targetSite field
"""

import json
import re
import subprocess
import hashlib
import time
import os
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse
from pydantic import BaseModel, Field
from jsonschema import validate, ValidationError
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="TMF921 Intent Generator", version="1.0.0")

# Load TMF921 schema
SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schema.json")
with open(SCHEMA_PATH, "r") as f:
    TMF921_SCHEMA = json.load(f)

# Request/Response models
class IntentRequest(BaseModel):
    natural_language: str = Field(..., min_length=1, max_length=1000)
    target_site: Optional[str] = Field(None, pattern="^(edge1|edge2|both)$")

class IntentResponse(BaseModel):
    intent: Dict[str, Any]
    execution_time: float
    hash: str

# Strict prompt for JSON-only output with targetSite
PROMPT_TEMPLATE = """Output only JSON. No text before or after.

Convert: "{nl_request}"

Required JSON format:
{{
  "intentId": "intent_<timestamp>",
  "name": "<short name>",
  "description": "<description>",
  "targetSite": "{target_site}",
  "parameters": {{
    "type": "<type>",
    "requirements": {{}},
    "configuration": {{}}
  }},
  "priority": "medium",
  "lifecycle": "draft"
}}

targetSite must be: {target_site}
JSON:"""

def extract_json(output: str) -> Dict[str, Any]:
    """Extract JSON from output with strict parsing"""
    output = output.strip()

    # Remove markdown code blocks if present
    output = re.sub(r'```(?:json)?\s*', '', output)
    output = re.sub(r'```\s*$', '', output)

    # Find JSON object boundaries
    start = output.find('{')
    end = output.rfind('}')

    if start >= 0 and end > start:
        try:
            return json.loads(output[start:end+1])
        except json.JSONDecodeError:
            pass

    # Try direct parse
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        raise ValueError(f"No valid JSON found in output: {output[:200]}")

def call_claude(prompt: str) -> str:
    """Call Claude CLI with subprocess"""
    cmd = ["claude", "--dangerously-skip-permissions", "-p", prompt]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=20,
            check=False
        )

        if result.stdout:
            return result.stdout

        if result.stderr:
            raise RuntimeError(f"Claude error: {result.stderr}")

        raise RuntimeError("No output from Claude")

    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=504, detail="Claude timeout")
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Claude CLI not found")

def determine_target_site(nl_text: str, override: Optional[str]) -> str:
    """Determine target site from text or use override"""
    if override and override in ["edge1", "edge2", "both"]:
        return override

    # Infer from natural language
    text_lower = nl_text.lower()

    if any(x in text_lower for x in ["edge1", "edge 1", "edge-1", "site 1", "first edge"]):
        return "edge1"
    elif any(x in text_lower for x in ["edge2", "edge 2", "edge-2", "site 2", "second edge"]):
        return "edge2"
    elif any(x in text_lower for x in ["both", "all edge", "multiple", "two edge", "edges"]):
        return "both"

    # Default to both if ambiguous
    return "both"

def enforce_targetsite(intent: Dict[str, Any], target_site: str) -> Dict[str, Any]:
    """Ensure targetSite field is present and valid"""
    # Enforce targetSite
    if "targetSite" not in intent or intent["targetSite"] not in ["edge1", "edge2", "both"]:
        intent["targetSite"] = target_site

    # Ensure required fields
    if not intent.get("intentId"):
        intent["intentId"] = f"intent_{int(time.time() * 1000)}"

    if not intent.get("name"):
        intent["name"] = "Generated Intent"

    if not intent.get("parameters"):
        intent["parameters"] = {}

    return intent

def validate_intent(intent: Dict[str, Any]) -> None:
    """Validate intent against TMF921 schema"""
    try:
        validate(instance=intent, schema=TMF921_SCHEMA)
    except ValidationError as e:
        raise HTTPException(status_code=400, detail=f"Schema validation failed: {e.message}")

    # Additional targetSite validation
    if intent.get("targetSite") not in ["edge1", "edge2", "both"]:
        raise HTTPException(status_code=400, detail=f"Invalid targetSite: {intent.get('targetSite')}")

@app.post("/generate_intent", response_model=IntentResponse)
async def generate_intent(request: IntentRequest):
    """Generate TMF921 intent with mandatory targetSite field"""
    start_time = time.time()

    # Determine target site
    target_site = determine_target_site(request.natural_language, request.target_site)

    logger.info(f"Generating intent with targetSite={target_site}")

    # Build prompt
    prompt = PROMPT_TEMPLATE.format(
        nl_request=request.natural_language,
        target_site=target_site
    )

    try:
        # Call Claude
        output = call_claude(prompt)

        # Extract JSON
        intent = extract_json(output)

        # Enforce targetSite
        intent = enforce_targetsite(intent, target_site)

        # Validate
        validate_intent(intent)

        # Generate hash
        intent_str = json.dumps(intent, sort_keys=True)
        intent_hash = hashlib.sha256(intent_str.encode()).hexdigest()

        execution_time = time.time() - start_time

        return IntentResponse(
            intent=intent,
            execution_time=execution_time,
            hash=intent_hash
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Generation failed: {e}")

        # Return fallback intent
        fallback = {
            "intentId": f"intent_{int(time.time() * 1000)}",
            "name": request.natural_language[:50],
            "description": request.natural_language,
            "targetSite": target_site,
            "parameters": {
                "type": "fallback",
                "requirements": {},
                "configuration": {}
            },
            "priority": "medium",
            "lifecycle": "draft"
        }

        fallback_hash = hashlib.sha256(
            json.dumps(fallback, sort_keys=True).encode()
        ).hexdigest()

        return IntentResponse(
            intent=fallback,
            execution_time=time.time() - start_time,
            hash=fallback_hash
        )

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": time.time()}

@app.get("/mock/slo")
async def mock_slo():
    """Mock SLO endpoint for Phase 13 - local E2E testing"""
    import random

    return {
        "status": "operational",
        "metrics": {
            "latency_p50": round(random.uniform(100, 200), 2),
            "latency_p95": round(random.uniform(200, 500), 2),
            "latency_p99": round(random.uniform(500, 1000), 2),
            "success_rate": round(random.uniform(0.95, 0.99), 3),
            "requests_per_minute": random.randint(50, 200)
        },
        "timestamp": time.time(),
        "service": "llm-adapter"
    }

@app.get("/", response_class=HTMLResponse)
async def root():
    """Simple UI with targetSite selector for Phase 17"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>TMF921 Intent Generator - VM3 LLM Adapter</title>
        <style>
            body {
                font-family: 'Segoe UI', Arial, sans-serif;
                max-width: 900px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }
            .container {
                background: white;
                padding: 40px;
                border-radius: 15px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }
            h1 {
                color: #333;
                border-bottom: 3px solid #667eea;
                padding-bottom: 15px;
            }
            .info-box {
                background: #f0f4ff;
                border-left: 4px solid #667eea;
                padding: 15px;
                margin: 20px 0;
                border-radius: 5px;
            }
            textarea {
                width: 100%;
                padding: 12px;
                margin: 15px 0;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                font-size: 14px;
                resize: vertical;
                transition: border-color 0.3s;
            }
            textarea:focus {
                outline: none;
                border-color: #667eea;
            }
            select {
                width: 100%;
                padding: 12px;
                margin: 15px 0;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                font-size: 14px;
                background: white;
                cursor: pointer;
            }
            select:focus {
                outline: none;
                border-color: #667eea;
            }
            button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 14px 32px;
                border: none;
                border-radius: 8px;
                cursor: pointer;
                font-size: 16px;
                font-weight: 600;
                transition: transform 0.2s;
            }
            button:hover {
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
            }
            button:disabled {
                background: #ccc;
                cursor: not-allowed;
                transform: none;
            }
            pre {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                overflow-x: auto;
                border: 1px solid #dee2e6;
                font-size: 13px;
                max-height: 400px;
                overflow-y: auto;
            }
            .loading {
                display: none;
                color: #667eea;
                margin: 15px 0;
                font-weight: 500;
            }
            .metadata {
                background: #e8f5e9;
                padding: 15px;
                border-radius: 8px;
                margin: 15px 0;
                font-size: 14px;
                border-left: 4px solid #4caf50;
            }
            .error {
                background: #ffebee;
                color: #c62828;
                padding: 15px;
                border-radius: 8px;
                margin: 15px 0;
                border-left: 4px solid #f44336;
            }
            .examples {
                background: #fff8e1;
                padding: 15px;
                border-radius: 8px;
                margin: 20px 0;
                font-size: 13px;
            }
            .example-item {
                margin: 8px 0;
                padding: 8px;
                background: white;
                border-radius: 4px;
                cursor: pointer;
                transition: background 0.2s;
            }
            .example-item:hover {
                background: #f5f5f5;
            }
            .badge {
                display: inline-block;
                padding: 3px 8px;
                border-radius: 4px;
                font-size: 11px;
                font-weight: 600;
                margin-left: 10px;
            }
            .badge-edge1 { background: #e3f2fd; color: #1976d2; }
            .badge-edge2 { background: #f3e5f5; color: #7b1fa2; }
            .badge-both { background: #e8f5e9; color: #388e3c; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 TMF921 Intent Generator</h1>
            <div class="info-box">
                <strong>VM-3 LLM Adapter</strong> | Phase 12-17 Implementation<br>
                Endpoint: <code>http://localhost:8888/generate_intent</code><br>
                targetSite values: <code>edge1</code> | <code>edge2</code> | <code>both</code>
            </div>

            <div>
                <label for="nlInput"><strong>Natural Language Request:</strong></label>
                <textarea id="nlInput" rows="4" placeholder="Enter your intent in natural language...
Example: Deploy a 5G network slice with low latency for gaming at edge site 1"></textarea>
            </div>

            <div>
                <label for="targetSite"><strong>Target Site:</strong> (Phase 17 - UI Selector)</label>
                <select id="targetSite">
                    <option value="">🔍 Auto-detect from text</option>
                    <option value="edge1">📍 Edge Site 1</option>
                    <option value="edge2">📍 Edge Site 2</option>
                    <option value="both">🌐 Both Sites</option>
                </select>
            </div>

            <div class="examples">
                <strong>Quick Examples:</strong>
                <div class="example-item" onclick="setExample('Deploy 5G network slice with ultra-low latency at edge1')">
                    Deploy 5G slice at edge1 <span class="badge badge-edge1">edge1</span>
                </div>
                <div class="example-item" onclick="setExample('Configure IoT monitoring for edge site 2')">
                    IoT monitoring at edge2 <span class="badge badge-edge2">edge2</span>
                </div>
                <div class="example-item" onclick="setExample('Setup video streaming CDN across both edge sites')">
                    Video CDN at both sites <span class="badge badge-both">both</span>
                </div>
            </div>

            <button onclick="generateIntent()">Generate TMF921 Intent</button>

            <div class="loading" id="loading">⏳ Calling Claude CLI...</div>
            <div id="error"></div>
            <div id="metadata"></div>
            <pre id="result"></pre>
        </div>

        <script>
            function setExample(text) {
                document.getElementById('nlInput').value = text;
                document.getElementById('targetSite').value = '';
            }

            async function generateIntent() {
                const input = document.getElementById('nlInput').value;
                const targetSite = document.getElementById('targetSite').value;
                const resultDiv = document.getElementById('result');
                const errorDiv = document.getElementById('error');
                const loadingDiv = document.getElementById('loading');
                const metadataDiv = document.getElementById('metadata');
                const button = document.querySelector('button');

                if (!input.trim()) {
                    errorDiv.innerHTML = '<div class="error">⚠️ Please enter a natural language request</div>';
                    return;
                }

                // Clear previous results
                resultDiv.textContent = '';
                errorDiv.innerHTML = '';
                metadataDiv.innerHTML = '';
                loadingDiv.style.display = 'block';
                button.disabled = true;

                const payload = {
                    natural_language: input.trim()
                };

                if (targetSite) {
                    payload.target_site = targetSite;
                }

                try {
                    const startTime = Date.now();
                    const response = await fetch('/generate_intent', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify(payload)
                    });

                    const data = await response.json();
                    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);

                    if (response.ok) {
                        // Display intent JSON
                        resultDiv.textContent = JSON.stringify(data.intent, null, 2);

                        // Display metadata
                        const targetSiteClass = `badge-${data.intent.targetSite === 'both' ? 'both' : data.intent.targetSite}`;
                        metadataDiv.innerHTML = `
                            <div class="metadata">
                                <strong>✅ Success!</strong><br>
                                Intent ID: <code>${data.intent.intentId}</code><br>
                                Target Site: <span class="badge ${targetSiteClass}">${data.intent.targetSite}</span><br>
                                Execution Time: ${data.execution_time.toFixed(2)}s (Total: ${elapsed}s)<br>
                                Hash: <code>${data.hash.substring(0, 16)}...</code>
                            </div>
                        `;
                    } else {
                        errorDiv.innerHTML = `<div class="error">❌ Error: ${data.detail || 'Failed to generate intent'}</div>`;
                    }
                } catch (e) {
                    errorDiv.innerHTML = `<div class="error">❌ Error: ${e.message}</div>`;
                } finally {
                    loadingDiv.style.display = 'none';
                    button.disabled = false;
                }
            }

            // Enter key to submit
            document.getElementById('nlInput').addEventListener('keydown', function(e) {
                if (e.key === 'Enter' && e.ctrlKey) {
                    generateIntent();
                }
            });
        </script>
    </body>
    </html>
    """

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.getenv("PORT", "8889"))
    print(f"Starting LLM Adapter on port {port}...")
    uvicorn.run(app, host="0.0.0.0", port=port)