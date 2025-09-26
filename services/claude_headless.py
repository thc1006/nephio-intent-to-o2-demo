#!/usr/bin/env python3
"""
Claude Headless Service for VM-1
Integrates Claude CLI in headless mode for intent processing
"""

import subprocess
import json
import asyncio
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Any, Optional, List
import logging
import os
import time
from datetime import datetime
import hashlib

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Claude Headless Intent Service",
    version="1.0.0",
    description="Integrated Claude CLI service for Intent-to-O2 orchestration"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except:
                pass

manager = ConnectionManager()

# Request models
class IntentRequest(BaseModel):
    text: str
    context: Optional[Dict[str, Any]] = None
    target_sites: Optional[List[str]] = ["edge01", "edge02"]

class ClaudeHeadlessService:
    """Claude CLI wrapper for headless operation"""

    def __init__(self):
        # Detect Claude CLI path
        self.claude_path = self._detect_claude_cli()
        self.timeout = 30
        self.cache = {}  # Simple in-memory cache

    def _detect_claude_cli(self) -> str:
        """Auto-detect Claude CLI installation"""
        paths = [
            "/home/ubuntu/.npm-global/bin/claude",
            "/usr/local/bin/claude",
            "/opt/claude/bin/claude",
            "claude"  # Try PATH
        ]

        for path in paths:
            try:
                result = subprocess.run(
                    [path, "--version"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    logger.info(f"Claude CLI found at: {path}")
                    return path
            except:
                continue

        raise RuntimeError("Claude CLI not found. Please install it first.")

    def _generate_cache_key(self, prompt: str) -> str:
        """Generate cache key from prompt"""
        return hashlib.md5(prompt.encode()).hexdigest()

    async def process_intent(self, prompt: str, use_cache: bool = True) -> Dict[str, Any]:
        """Process intent using Claude CLI in headless mode"""

        # Check cache
        cache_key = self._generate_cache_key(prompt)
        if use_cache and cache_key in self.cache:
            logger.info(f"Cache hit for prompt: {prompt[:50]}...")
            return self.cache[cache_key]

        # Build headless command
        cmd = [
            self.claude_path,
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions"
        ]

        try:
            # Notify WebSocket clients
            await manager.broadcast({
                "stage": "claude_processing",
                "message": "Processing with Claude CLI...",
                "timestamp": datetime.utcnow().isoformat()
            })

            # Execute Claude CLI
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=self.timeout
            )

            if process.returncode != 0:
                logger.error(f"Claude CLI error: {stderr.decode()}")
                # Fallback to rule-based processing
                return await self._fallback_processing(prompt)

            # Parse JSON response
            try:
                response = json.loads(stdout.decode())
                # Cache successful response
                self.cache[cache_key] = response
                return response
            except json.JSONDecodeError:
                # Try to extract JSON from stream
                lines = stdout.decode().split('\n')
                for line in lines:
                    try:
                        return json.loads(line)
                    except:
                        continue
                raise

        except asyncio.TimeoutError:
            logger.error(f"Claude timeout after {self.timeout}s")
            return await self._fallback_processing(prompt)
        except Exception as e:
            logger.error(f"Claude processing error: {e}")
            return await self._fallback_processing(prompt)

    async def _fallback_processing(self, prompt: str) -> Dict[str, Any]:
        """Fallback rule-based processing when Claude is unavailable"""
        logger.warning("Using fallback rule-based processing")

        # Simple pattern matching for common intents
        intent = {
            "intentId": f"intent-{int(time.time())}",
            "timestamp": datetime.utcnow().isoformat(),
            "_fallback": True
        }

        # Extract service type
        if "eMBB" in prompt or "embb" in prompt.lower():
            intent["intentType"] = "eMBB"
            intent["serviceProfile"] = {
                "bandwidth": "200Mbps",
                "latency": "30ms"
            }
        elif "URLLC" in prompt or "urllc" in prompt.lower():
            intent["intentType"] = "URLLC"
            intent["serviceProfile"] = {
                "bandwidth": "50Mbps",
                "latency": "1ms",
                "reliability": "99.999%"
            }
        elif "mMTC" in prompt or "miot" in prompt.lower() or "mmtc" in prompt.lower():
            intent["intentType"] = "mMTC"
            intent["serviceProfile"] = {
                "deviceDensity": "1000000/km2",
                "bandwidth": "10Mbps"
            }
        else:
            intent["intentType"] = "generic"

        # Extract target sites
        sites = []
        if "edge1" in prompt.lower() or "edge01" in prompt.lower():
            sites.append("edge01")
        if "edge2" in prompt.lower() or "edge02" in prompt.lower():
            sites.append("edge02")
        if "all" in prompt.lower() or "both" in prompt.lower():
            sites = ["edge01", "edge02"]

        intent["targetSites"] = sites if sites else ["edge01"]

        # Extract bandwidth if specified
        import re
        bandwidth_match = re.search(r'(\d+)\s*(Mbps|Gbps|mbps|gbps)', prompt, re.IGNORECASE)
        if bandwidth_match:
            value = bandwidth_match.group(1)
            unit = bandwidth_match.group(2).upper()
            if "serviceProfile" not in intent:
                intent["serviceProfile"] = {}
            intent["serviceProfile"]["bandwidth"] = f"{value}{unit}"

        # Extract latency if specified
        latency_match = re.search(r'(\d+)\s*(ms|milliseconds?)', prompt, re.IGNORECASE)
        if latency_match:
            value = latency_match.group(1)
            if "serviceProfile" not in intent:
                intent["serviceProfile"] = {}
            intent["serviceProfile"]["latency"] = f"{value}ms"

        return intent

# Initialize service
service = ClaudeHeadlessService()

@app.get("/")
async def root():
    """Root endpoint with service information"""
    return {
        "service": "Claude Headless Intent Service",
        "version": "1.0.0",
        "status": "operational",
        "endpoints": {
            "health": "/health",
            "process_intent": "/api/v1/intent",
            "batch_intent": "/api/v1/intent/batch",
            "websocket": "/ws"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Check if Claude CLI is accessible
        result = subprocess.run(
            [service.claude_path, "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        claude_status = "healthy" if result.returncode == 0 else "degraded"
    except:
        claude_status = "unhealthy"

    return {
        "status": "healthy" if claude_status == "healthy" else "degraded",
        "mode": "headless",
        "claude": claude_status,
        "cache_size": len(service.cache),
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/api/v1/intent")
async def process_intent(request: IntentRequest):
    """Process natural language intent to TMF921 format"""

    # Build TMF921-compliant prompt
    prompt = f"""
You are an Intent-to-KRM converter for O-RAN network orchestration.
Convert the following natural language request to TMF921-compliant JSON format.

Natural Language Request: {request.text}

Context: {json.dumps(request.context) if request.context else 'Default deployment context'}
Target Sites: {', '.join(request.target_sites)}

Generate a valid JSON response with these exact fields:
{{
  "intentId": "unique identifier",
  "intentType": "eMBB|URLLC|mMTC",
  "description": "human readable description",
  "targetSites": ["edge01", "edge02"],
  "serviceProfile": {{
    "bandwidth": "value in Mbps/Gbps",
    "latency": "value in ms",
    "reliability": "percentage if URLLC",
    "deviceDensity": "devices per km2 if mMTC"
  }},
  "sloRequirements": {{
    "availability": "99.9%",
    "latencyP95": "10ms",
    "throughputMin": "100Mbps"
  }},
  "lifecycle": "draft|active|suspended|terminated",
  "priority": 1-10,
  "constraints": {{
    "temporal": "time window if any",
    "geographical": "location constraints if any"
  }}
}}

Return ONLY the JSON object, no explanations or markdown.
"""

    try:
        # Process with Claude
        result = await service.process_intent(prompt)

        # Notify via WebSocket
        await manager.broadcast({
            "stage": "intent_generated",
            "intentId": result.get("intentId"),
            "message": "Intent successfully generated",
            "timestamp": datetime.utcnow().isoformat()
        })

        return {
            "status": "success",
            "intent": result,
            "metadata": {
                "processedAt": datetime.utcnow().isoformat(),
                "fallback": result.get("_fallback", False)
            }
        }

    except Exception as e:
        logger.error(f"Intent processing failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/intent/batch")
async def process_batch_intents(requests: List[IntentRequest]):
    """Process multiple intents in batch"""
    results = []

    for req in requests:
        try:
            result = await process_intent(req)
            results.append(result)
        except Exception as e:
            results.append({
                "status": "failed",
                "error": str(e),
                "request": req.text
            })

    return {
        "total": len(requests),
        "successful": sum(1 for r in results if r.get("status") == "success"),
        "results": results
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            data = await websocket.receive_text()

            # Process intent via WebSocket
            try:
                request = json.loads(data)
                if request.get("type") == "intent":
                    intent_req = IntentRequest(
                        text=request.get("text", ""),
                        context=request.get("context")
                    )
                    result = await process_intent(intent_req)
                    await websocket.send_json(result)
            except Exception as e:
                await websocket.send_json({
                    "error": str(e)
                })

    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002, log_level="info")