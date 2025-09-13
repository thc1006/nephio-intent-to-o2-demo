#!/usr/bin/env python3
"""
LLM Client Adapter Layer - Simplified version for Claude CLI integration
"""
import os
import re
import json
import subprocess
import logging
from typing import Dict, Any, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class LLMClient:
    """Pluggable LLM client with Claude CLI support"""
    
    def __init__(self):
        self.use_claude = os.getenv('CLAUDE_CLI', '0') == '1'
        self.claude_available = self._check_claude_availability()
        self.timeout = int(os.getenv('LLM_TIMEOUT', '30'))
        
        if self.use_claude and self.claude_available:
            logger.info("LLM Client: Using Claude CLI")
        else:
            logger.info("LLM Client: Using rule-based parser")
    
    def _check_claude_availability(self) -> bool:
        """Check if Claude CLI is available"""
        if not self.use_claude:
            return False
        try:
            result = subprocess.run(['which', 'claude'], capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False
    
    def parse_text(self, text: str) -> Dict[str, Any]:
        """Parse natural language text to extract intent"""
        if self.use_claude and self.claude_available:
            try:
                return self._parse_with_claude(text)
            except Exception as e:
                logger.warning(f"Claude parsing failed: {e}, falling back to rules")
        
        return self._parse_with_rules(text)
    
    def _parse_with_claude(self, text: str) -> Dict[str, Any]:
        """Parse using Claude CLI"""
        prompt = f"""Convert this 5G network request to JSON with ONLY this structure (no other text):
{{"service": "eMBB/URLLC/mMTC", "location": "edge1/zone1/etc", "qos": {{"downlink_mbps": int, "uplink_mbps": int, "latency_ms": int}}}}

Request: {text}"""
        
        result = subprocess.run(
            ['claude', '-p', prompt],
            capture_output=True,
            text=True,
            timeout=self.timeout
        )
        
        if result.returncode == 0:
            # Extract JSON from response
            response = result.stdout.strip()
            json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', response)
            if json_match:
                return json.loads(json_match.group(0))
        
        raise Exception("Failed to parse Claude response")
    
    def _parse_with_rules(self, text: str) -> Dict[str, Any]:
        """Parse using rule-based extraction"""
        text_lower = text.lower()
        
        # Extract service type
        if 'urllc' in text_lower or 'ultra-reliable' in text_lower:
            service = "URLLC"
        elif 'mmtc' in text_lower or 'iot' in text_lower:
            service = "mMTC"
        else:
            service = "eMBB"
        
        # Extract location
        location_match = re.search(r'(edge\d+|zone\d+|core\d+)', text_lower)
        location = location_match.group(1) if location_match else "edge1"
        
        # Extract QoS
        qos = {"downlink_mbps": None, "uplink_mbps": None, "latency_ms": None}
        
        # Downlink
        dl_match = re.search(r'(\d+)\s*(?:mbps|gbps).*?(?:dl|downlink)', text_lower)
        if not dl_match:
            dl_match = re.search(r'(\d+)\s*(?:mbps|gbps)', text_lower)
        if dl_match:
            value = int(dl_match.group(1))
            if 'gbps' in text_lower:
                value *= 1000
            qos['downlink_mbps'] = value
        
        # Latency
        lat_match = re.search(r'(\d+)\s*ms', text_lower)
        if lat_match:
            qos['latency_ms'] = int(lat_match.group(1))
        
        return {
            "service": service,
            "location": location,
            "qos": qos
        }
    
    def get_model_info(self) -> str:
        """Get current model being used"""
        return "claude-cli" if (self.use_claude and self.claude_available) else "rule-based"
    
    def convert_to_tmf921(self, intent_dict: Dict[str, Any], original_text: str) -> Dict[str, Any]:
        """Convert internal format to TMF921-compliant Intent"""
        from datetime import datetime
        import uuid
        
        # Generate unique ID
        intent_id = str(uuid.uuid4())
        
        # Map service types to TMF921 format
        service_type = intent_dict.get("service", "eMBB")
        location = intent_dict.get("location", "edge1")
        qos = intent_dict.get("qos", {})
        
        # Build TMF921 structure
        tmf921_intent = {
            "intentId": intent_id,
            "intentName": f"{service_type} Service at {location}",
            "intentType": "5G_NETWORK_SLICE",
            "scope": "NETWORK_SLICE",
            "priority": "HIGH" if service_type == "URLLC" else "MEDIUM",
            "requestTime": datetime.utcnow().isoformat() + "Z",
            "intentParameters": {
                "serviceType": service_type,
                "location": location,
                "qosParameters": {
                    "downlinkMbps": qos.get("downlink_mbps"),
                    "uplinkMbps": qos.get("uplink_mbps"),
                    "latencyMs": qos.get("latency_ms")
                },
                "originalRequest": original_text
            },
            "constraints": {
                "resourceConstraints": {
                    "maxLatency": qos.get("latency_ms"),
                    "minBandwidth": qos.get("downlink_mbps")
                }
            },
            "targetEntities": [
                {
                    "entityType": "NETWORK_SLICE",
                    "entityId": f"slice_{service_type.lower()}_{location}"
                }
            ],
            "expectedOutcome": f"Deploy {service_type} network slice at {location} with specified QoS parameters"
        }
        
        return tmf921_intent


# Singleton
_client = None

def get_llm_client() -> LLMClient:
    """Get singleton LLM client"""
    global _client
    if _client is None:
        _client = LLMClient()
    return _client