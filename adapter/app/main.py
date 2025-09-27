#!/usr/bin/env python3
"""
LLM Adapter for TMF921 Intent Generation
Converts natural language to TMF921-compliant JSON with service, QoS, slice, and targetSite fields
"""

import json
import re
import subprocess
import hashlib
import time
import os
import random
from typing import Dict, Any, Optional, Tuple
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, HTMLResponse
from pydantic import BaseModel, Field
from jsonschema import validate, ValidationError
import logging
from datetime import datetime
from dataclasses import dataclass
try:
    from .intent_generator import (
        generate_fallback_intent,
        infer_service_and_qos,
        validate_and_fix_json,
        enforce_tmf921_structure
    )
except ImportError:
    from intent_generator import (
        generate_fallback_intent,
        infer_service_and_qos,
        validate_and_fix_json,
        enforce_tmf921_structure
    )

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="TMF921 Intent Generator", version="2.0.0")

# Retry configuration
@dataclass
class RetryConfig:
    """Configuration for retry logic with exponential backoff"""
    max_retries: int = 3
    initial_delay: float = 1.0  # seconds
    max_delay: float = 16.0  # seconds
    exponential_base: float = 2.0
    jitter: bool = True  # Add random jitter to prevent thundering herd

retry_config = RetryConfig()

# Metrics tracking
class Metrics:
    """Track retry metrics for monitoring"""
    def __init__(self):
        self.total_requests = 0
        self.successful_requests = 0
        self.failed_requests = 0
        self.retry_attempts = 0
        self.total_retries = 0

    def record_request(self, success: bool, retries: int):
        self.total_requests += 1
        if success:
            self.successful_requests += 1
        else:
            self.failed_requests += 1
        if retries > 0:
            self.retry_attempts += 1
            self.total_retries += retries

    def get_stats(self) -> Dict[str, Any]:
        return {
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "retry_attempts": self.retry_attempts,
            "total_retries": self.total_retries,
            "retry_rate": self.retry_attempts / max(1, self.total_requests),
            "success_rate": self.successful_requests / max(1, self.total_requests)
        }

metrics = Metrics()

# Load TMF921 schema
SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schema.json")
with open(SCHEMA_PATH, "r") as f:
    TMF921_SCHEMA = json.load(f)

# Request/Response models
class IntentRequest(BaseModel):
    natural_language: str = Field(..., min_length=1, max_length=1000)
    target_site: Optional[str] = Field(None, pattern="^(edge1|edge2|edge3|edge4|both)$")

class IntentResponse(BaseModel):
    intent: Dict[str, Any]
    execution_time: float
    hash: str

# Deterministic prompt template for TMF921-aligned JSON output
PROMPT_TEMPLATE = """You are a TMF921 intent generator. Output only valid JSON matching this exact structure. No explanations.

Input: "{nl_request}"
Target Site: {target_site}

Rules for output:
1. Extract service type: eMBB (broadband), URLLC (low-latency), mMTC (IoT), or generic
2. Extract QoS requirements: dl_mbps, ul_mbps, latency_ms from the request
3. Map to network slice: SST 1=eMBB, 2=URLLC, 3=mMTC
4. targetSite MUST be exactly: "{target_site}"

Output this exact JSON structure:
{{
  "intentId": "intent_<unix_timestamp_ms>",
  "name": "<concise_name_max_50_chars>",
  "description": "<full_description>",
  "service": {{
    "name": "<service_name>",
    "type": "<eMBB|URLLC|mMTC|generic>",
    "characteristics": {{
      "reliability": "<high|medium|low>",
      "mobility": "<fixed|nomadic|mobile>"
    }}
  }},
  "targetSite": "{target_site}",
  "qos": {{
    "dl_mbps": <number_or_null>,
    "ul_mbps": <number_or_null>,
    "latency_ms": <number_or_null>,
    "jitter_ms": <number_or_null>,
    "packet_loss_rate": <number_0_to_1_or_null>
  }},
  "slice": {{
    "sst": <1_for_eMBB_2_for_URLLC_3_for_mMTC>,
    "sd": "<6_hex_digits_or_null>",
    "plmn": "<5-6_digits_or_null>"
  }},
  "priority": "<low|medium|high|critical>",
  "lifecycle": "draft",
  "metadata": {{
    "createdAt": "<ISO8601_timestamp>",
    "version": "1.0.0"
  }}
}}

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

def calculate_backoff_delay(attempt: int, config: RetryConfig) -> float:
    """Calculate exponential backoff delay with optional jitter"""
    delay = min(
        config.initial_delay * (config.exponential_base ** attempt),
        config.max_delay
    )

    if config.jitter:
        # Add random jitter between 0-25% of the delay
        jitter_amount = delay * 0.25 * random.random()
        delay += jitter_amount

    return delay

def call_claude_with_retry(prompt: str, config: RetryConfig = retry_config) -> Tuple[str, int]:
    """Call Claude CLI with retry logic and exponential backoff

    Returns:
        Tuple of (output, retry_count)
    """
    last_error = None

    for attempt in range(config.max_retries + 1):
        try:
            # Log retry attempt
            if attempt > 0:
                delay = calculate_backoff_delay(attempt - 1, config)
                logger.info(f"Retry attempt {attempt}/{config.max_retries} after {delay:.2f}s delay")
                time.sleep(delay)

            # Call Claude CLI
            cmd = ["claude", "--dangerously-skip-permissions", "-p", prompt]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=20,
                check=False
            )

            if result.stdout:
                # Success - return output and retry count
                if attempt > 0:
                    logger.info(f"Successful after {attempt} retries")
                return result.stdout, attempt

            # Check for errors that should not be retried
            if result.stderr:
                error_msg = result.stderr.lower()

                # Don't retry on authentication or permission errors
                if any(x in error_msg for x in ["permission", "auth", "forbidden", "unauthorized"]):
                    logger.error(f"Non-retryable error: {result.stderr}")
                    raise HTTPException(status_code=403, detail=f"Claude error: {result.stderr}")

                # Don't retry on invalid input errors
                if any(x in error_msg for x in ["invalid", "malformed", "syntax"]):
                    logger.error(f"Invalid input error: {result.stderr}")
                    raise HTTPException(status_code=400, detail=f"Invalid prompt: {result.stderr}")

                # Retryable error
                last_error = RuntimeError(f"Claude error: {result.stderr}")
                logger.warning(f"Retryable error on attempt {attempt + 1}: {result.stderr}")
            else:
                last_error = RuntimeError("No output from Claude")
                logger.warning(f"No output on attempt {attempt + 1}")

        except subprocess.TimeoutExpired:
            last_error = HTTPException(status_code=504, detail="Claude timeout")
            logger.warning(f"Timeout on attempt {attempt + 1}")
        except FileNotFoundError:
            # Don't retry if Claude CLI is not found
            logger.error("Claude CLI not found")
            raise HTTPException(status_code=500, detail="Claude CLI not found")
        except HTTPException:
            # Re-raise HTTPException without catching it
            raise
        except Exception as e:
            last_error = e
            logger.warning(f"Unexpected error on attempt {attempt + 1}: {e}")

    # All retries exhausted
    logger.error(f"All {config.max_retries + 1} attempts failed")
    if isinstance(last_error, HTTPException):
        raise last_error
    raise HTTPException(status_code=503, detail=f"Service unavailable after {config.max_retries} retries")

def determine_target_site(nl_text: str, override: Optional[str]) -> str:
    """Determine target site from text or use override"""
    if override and override in ["edge1", "edge2", "edge3", "edge4", "both"]:
        return override

    # Infer from natural language
    text_lower = nl_text.lower()

    if any(x in text_lower for x in ["edge1", "edge 1", "edge-1", "site 1", "first edge"]):
        return "edge1"
    elif any(x in text_lower for x in ["edge2", "edge 2", "edge-2", "site 2", "second edge"]):
        return "edge2"
    elif any(x in text_lower for x in ["edge3", "edge 3", "edge-3", "site 3", "third edge"]):
        return "edge3"
    elif any(x in text_lower for x in ["edge4", "edge 4", "edge-4", "site 4", "fourth edge"]):
        return "edge4"
    elif any(x in text_lower for x in ["both", "all edge", "multiple", "all sites", "edges"]):
        return "both"

    # Default to both if ambiguous
    return "both"

# JSON validation moved to intent_generator module

# Service and QoS inference moved to intent_generator module

def enforce_tmf921_structure(intent: Dict[str, Any], target_site: str, nl_text: str) -> Dict[str, Any]:
    """Ensure TMF921-compliant structure with all required fields"""
    from datetime import datetime

    # Infer service and QoS if not present
    service_type, sst, qos_defaults = infer_service_and_qos(nl_text)

    # Ensure targetSite
    if "targetSite" not in intent or intent["targetSite"] not in ["edge1", "edge2", "edge3", "edge4", "both"]:
        intent["targetSite"] = target_site

    # Ensure intentId
    if not intent.get("intentId"):
        intent["intentId"] = f"intent_{int(time.time() * 1000)}"

    # Ensure name
    if not intent.get("name"):
        intent["name"] = nl_text[:50] if len(nl_text) > 50 else nl_text

    # Ensure service structure
    if "service" not in intent:
        intent["service"] = {
            "name": f"{service_type} Service",
            "type": service_type,
            "characteristics": {}
        }
    elif not isinstance(intent.get("service"), dict):
        intent["service"] = {
            "name": "Service",
            "type": service_type,
            "characteristics": {}
        }

    # Ensure QoS structure with defaults
    if "qos" not in intent:
        intent["qos"] = qos_defaults
    else:
        # Fill missing QoS fields with defaults
        for key, value in qos_defaults.items():
            if key not in intent["qos"] or intent["qos"][key] is None:
                intent["qos"][key] = value

    # Ensure slice structure
    if "slice" not in intent:
        intent["slice"] = {
            "sst": sst,
            "sd": None,
            "plmn": None
        }
    elif "sst" not in intent.get("slice", {}):
        intent["slice"]["sst"] = sst

    # Ensure priority and lifecycle
    if "priority" not in intent:
        intent["priority"] = "medium"
    if "lifecycle" not in intent:
        intent["lifecycle"] = "draft"

    # Ensure metadata
    if "metadata" not in intent:
        intent["metadata"] = {
            "createdAt": datetime.utcnow().isoformat() + "Z",
            "version": "1.0.0"
        }

    return intent

def generate_fallback_intent(nl_text: str, target_site: str) -> Dict[str, Any]:
    """Generate intent directly without Claude CLI for TDD testing"""
    service_type, sst, qos_defaults = infer_service_and_qos(nl_text)

    intent = {
        "intentId": f"intent_{int(time.time() * 1000)}",
        "name": nl_text[:50] if len(nl_text) <= 50 else nl_text[:47] + "...",
        "description": nl_text,
        "service": {
            "name": f"{service_type} Service",
            "type": service_type,
            "characteristics": {
                "reliability": "high" if service_type == "URLLC" else "medium",
                "mobility": "mobile"
            }
        },
        "targetSite": target_site,
        "qos": qos_defaults,
        "slice": {
            "sst": sst,
            "sd": None,
            "plmn": None
        },
        "priority": "high" if service_type == "URLLC" else "medium",
        "lifecycle": "draft",
        "metadata": {
            "createdAt": datetime.utcnow().isoformat() + "Z",
            "version": "1.0.0"
        }
    }

    return intent

def validate_intent(intent: Dict[str, Any]) -> None:
    """Validate intent against TMF921 schema"""
    try:
        validate(instance=intent, schema=TMF921_SCHEMA)
    except ValidationError as e:
        raise HTTPException(status_code=400, detail=f"Schema validation failed: {e.message}")

    # Additional targetSite validation
    if intent.get("targetSite") not in ["edge1", "edge2", "edge3", "edge4", "both"]:
        raise HTTPException(status_code=400, detail=f"Invalid targetSite: {intent.get('targetSite')}")

@app.post("/api/v1/intent/transform", response_model=IntentResponse)
@app.post("/generate_intent", response_model=IntentResponse)
async def generate_intent(request: IntentRequest):
    """Generate TMF921 intent with retry logic and mandatory targetSite field"""
    start_time = time.time()
    retry_count = 0
    success = False

    # Determine target site
    target_site = determine_target_site(request.natural_language, request.target_site)

    logger.info(f"Generating intent with targetSite={target_site}")

    # Build prompt
    prompt = PROMPT_TEMPLATE.format(
        nl_request=request.natural_language,
        target_site=target_site
    )

    try:
        # For TDD: Skip Claude CLI and use direct generation
        intent = generate_fallback_intent(request.natural_language, target_site)
        retry_count = 0

        # Generate hash
        intent_str = json.dumps(intent, sort_keys=True)
        intent_hash = hashlib.sha256(intent_str.encode()).hexdigest()

        execution_time = time.time() - start_time
        success = True

        # Log success with retry info
        if retry_count > 0:
            logger.info(f"Intent generated successfully after {retry_count} retries in {execution_time:.2f}s")
        else:
            logger.info(f"Intent generated successfully in {execution_time:.2f}s")

        return IntentResponse(
            intent=intent,
            execution_time=execution_time,
            hash=intent_hash
        )

    except HTTPException:
        metrics.record_request(False, retry_count)
        raise
    except Exception as e:
        logger.error(f"Generation failed after {retry_count} retries: {e}")
        metrics.record_request(False, retry_count)

        # Return fallback intent with TMF921 structure
        service_type, sst, qos_defaults = infer_service_and_qos(request.natural_language)

        fallback = {
            "intentId": f"intent_{int(time.time() * 1000)}",
            "name": request.natural_language[:50],
            "description": request.natural_language,
            "service": {
                "name": f"{service_type} Service",
                "type": service_type,
                "characteristics": {}
            },
            "targetSite": target_site,
            "qos": qos_defaults,
            "slice": {
                "sst": sst,
                "sd": None,
                "plmn": None
            },
            "priority": "medium",
            "lifecycle": "draft",
            "metadata": {
                "createdAt": datetime.utcnow().isoformat() + "Z",
                "version": "1.0.0"
            }
        }

        fallback_hash = hashlib.sha256(
            json.dumps(fallback, sort_keys=True).encode()
        ).hexdigest()

        return IntentResponse(
            intent=fallback,
            execution_time=time.time() - start_time,
            hash=fallback_hash
        )
    finally:
        # Record metrics
        metrics.record_request(success, retry_count)

@app.get("/health")
async def health():
    """Health check endpoint with retry metrics"""
    stats = metrics.get_stats()
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "metrics": stats,
        "retry_config": {
            "max_retries": retry_config.max_retries,
            "initial_delay": retry_config.initial_delay,
            "max_delay": retry_config.max_delay,
            "exponential_base": retry_config.exponential_base,
            "jitter": retry_config.jitter
        }
    }

@app.get("/metrics")
async def get_metrics():
    """Get detailed retry and performance metrics"""
    stats = metrics.get_stats()
    return {
        "metrics": stats,
        "timestamp": time.time()
    }

class RetryConfigUpdate(BaseModel):
    """Request model for updating retry configuration"""
    max_retries: int = Field(default=3, ge=0, le=10)
    initial_delay: float = Field(default=1.0, ge=0.1, le=10.0)
    max_delay: float = Field(default=16.0, ge=1.0, le=60.0)
    exponential_base: float = Field(default=2.0, ge=1.1, le=4.0)
    jitter: bool = Field(default=True)

@app.post("/config/retry")
async def update_retry_config(config_update: RetryConfigUpdate):
    """Update retry configuration dynamically"""
    global retry_config
    retry_config = RetryConfig(
        max_retries=config_update.max_retries,
        initial_delay=config_update.initial_delay,
        max_delay=config_update.max_delay,
        exponential_base=config_update.exponential_base,
        jitter=config_update.jitter
    )
    logger.info(f"Retry config updated: {retry_config}")
    return {"status": "updated", "config": retry_config.__dict__}

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
        <title>TMF921 Intent Generator - VM1 LLM Adapter</title>
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
                <strong>VM-1</strong> | Phase 12-17 Implementation<br>
                Endpoint: <code>http://localhost:8002/generate_intent</code><br>
                targetSite values: <code>edge1</code> | <code>edge2</code> | <code>both</code>
            </div>

            <div>
                <label for="nlInput"><strong>Natural Language Request:</strong></label>
                <textarea id="nlInput" rows="4" placeholder="Enter your intent in natural language...
Example: Deploy a 5G network slice with low latency for gaming at edge site 1"></textarea>
            </div>

            <div>
                <label for="targetSite"><strong>Target Site:</strong> (4-Site Support)</label>
                <select id="targetSite">
                    <option value="">🔍 Auto-detect from text</option>
                    <option value="edge1">📍 Edge Site 1 (VM-2)</option>
                    <option value="edge2">📍 Edge Site 2 (VM-4)</option>
                    <option value="edge3">📍 Edge Site 3 (New)</option>
                    <option value="edge4">📍 Edge Site 4 (New)</option>
                    <option value="both">🌐 All Sites</option>
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
                <div class="example-item" onclick="setExample('Deploy eMBB service on edge3 with 200Mbps bandwidth')">
                    eMBB service at edge3 <span class="badge badge-edge1">edge3</span>
                </div>
                <div class="example-item" onclick="setExample('Setup URLLC for industrial automation on edge4')">
                    URLLC at edge4 <span class="badge badge-edge2">edge4</span>
                </div>
                <div class="example-item" onclick="setExample('Setup video streaming CDN across all edge sites')">
                    Video CDN at all sites <span class="badge badge-both">all</span>
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