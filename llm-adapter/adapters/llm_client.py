#!/usr/bin/env python3
"""
LLM Client Adapter Layer - Simplified version for Claude CLI integration
"""
import os
import re
import json
import subprocess
import logging
import time
import hashlib
from typing import Dict, Any, Optional
from datetime import datetime
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cache for repeated inputs
CACHE = {}
CACHE_TTL = 300  # 5 minutes


class LLMClient:
    """Pluggable LLM client with Claude CLI support"""

    def __init__(self):
        self.use_claude = os.getenv('CLAUDE_CLI', '0') == '1'
        self.claude_available = self._check_claude_availability()
        self.timeout = int(os.getenv('LLM_TIMEOUT', '30'))
        self.max_retries = int(os.getenv('LLM_MAX_RETRIES', '3'))
        self.retry_backoff = float(os.getenv('LLM_RETRY_BACKOFF', '1.5'))
        self.artifacts_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter')
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)

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
        """Parse natural language text to extract intent with caching and retry"""
        # Check cache first
        cache_key = hashlib.md5(text.encode()).hexdigest()
        if cache_key in CACHE:
            cached_time, cached_result = CACHE[cache_key]
            if time.time() - cached_time < CACHE_TTL:
                logger.info(f"Cache hit for text: {text[:50]}...")
                self._log_artifact("cache_hit", {"text": text, "result": cached_result})
                return cached_result

        # Try with retries
        result = None
        attempt = 0

        if self.use_claude and self.claude_available:
            while attempt < self.max_retries:
                try:
                    result = self._parse_with_claude(text)
                    break
                except Exception as e:
                    attempt += 1
                    if attempt >= self.max_retries:
                        logger.warning(f"Claude parsing failed after {self.max_retries} attempts: {e}, falling back to rules")
                        self._log_artifact("llm_failure", {"text": text, "error": str(e), "attempts": attempt})
                    else:
                        wait_time = self.retry_backoff ** attempt
                        logger.info(f"Retry {attempt}/{self.max_retries} after {wait_time}s...")
                        time.sleep(wait_time)

        if result is None:
            result = self._parse_with_rules(text)
            self._log_artifact("fallback_used", {"text": text, "result": result})
        else:
            self._log_artifact("llm_success", {"text": text, "result": result})

        # Cache the result
        CACHE[cache_key] = (time.time(), result)

        return result
    
    def _parse_with_claude(self, text: str) -> Dict[str, Any]:
        """Parse using Claude CLI with optimized deterministic prompt"""
        prompt = f"""<system>
You are a TMF921-compliant 5G network intent parser. You must output ONLY valid JSON matching the exact schema below. Any non-JSON text will cause system failure.
</system>

<constitutional-rules>
1. CRITICAL: Output must be pure JSON - no explanations, no markdown, no additional text
2. Self-check: Verify all required fields are present before outputting
3. Self-correct: If ambiguous, choose the most conservative/safe option
4. Validation: Ensure all numeric values are positive integers
</constitutional-rules>

<chain-of-thought>
Step 1: Identify service type by keywords
- "video", "streaming", "bandwidth", "throughput" → eMBB
- "reliable", "critical", "latency", "real-time", "mission" → URLLC
- "iot", "sensor", "machine", "device", "massive" → mMTC
- Default if unclear → eMBB

Step 2: Extract location
- Look for: edge1, edge2, zone1-9, core1-9
- Default if not specified → edge1

Step 3: Determine targetSite
- Explicit "edge1" mentioned → edge1
- Explicit "edge2" mentioned → edge2
- "both", "multi", "multiple" sites → both
- Service defaults: eMBB→edge1, URLLC→edge2, mMTC→both

Step 4: Extract QoS parameters
- downlink: Mbps/Gbps with "down"/"DL" (Gbps=value*1000)
- uplink: Mbps/Gbps with "up"/"UL" (default: 50% of downlink)
- latency: ms values (defaults: eMBB=50, URLLC=1, mMTC=100)
</chain-of-thought>

<few-shot-examples>
Input: "Deploy high-bandwidth video streaming service at edge1 with 1Gbps downlink"
Output: {{"service":"eMBB","location":"edge1","targetSite":"edge1","qos":{{"downlink_mbps":1000,"uplink_mbps":500,"latency_ms":50}}}}

Input: "Need ultra-reliable service for autonomous vehicles with 1ms latency"
Output: {{"service":"URLLC","location":"edge1","targetSite":"edge2","qos":{{"downlink_mbps":100,"uplink_mbps":50,"latency_ms":1}}}}

Input: "Setup massive IoT sensor network across both sites, 100 Mbps"
Output: {{"service":"mMTC","location":"edge1","targetSite":"both","qos":{{"downlink_mbps":100,"uplink_mbps":50,"latency_ms":100}}}}
</few-shot-examples>

<request>
{text}
</request>

<instruction>
Apply the chain-of-thought steps to the request above and output ONLY the JSON result:
</instruction>"""
        
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

        # Determine targetSite based on service type and explicit mentions
        targetSite = "edge1"  # default

        # Check for explicit site mentions
        if re.search(r'\b(both|multi|multiple)\s*(site|edge|node)', text_lower):
            targetSite = "both"
        elif 'edge2' in text_lower:
            targetSite = "edge2"
        elif 'edge1' in text_lower:
            targetSite = "edge1"
        else:
            # Use service type defaults
            if service == "URLLC":
                targetSite = "edge2"  # URLLC typically needs edge2 for ultra-low latency
            elif service == "mMTC":
                targetSite = "both"   # mMTC typically needs coverage across both sites
            else:  # eMBB
                targetSite = "edge1"  # eMBB typically uses edge1

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
            "targetSite": targetSite,
            "qos": qos
        }
    
    def get_model_info(self) -> str:
        """Get current model being used"""
        return "claude-cli" if (self.use_claude and self.claude_available) else "rule-based"

    def _log_artifact(self, event_type: str, data: Dict[str, Any]):
        """Log artifacts to artifacts/adapter directory"""
        try:
            timestamp = datetime.utcnow().isoformat()
            log_entry = {
                "timestamp": timestamp,
                "event_type": event_type,
                "model": self.get_model_info(),
                "data": data
            }

            # Scrub any potential secrets
            log_entry_str = json.dumps(log_entry, indent=2)
            for pattern in ['password', 'secret', 'token', 'key', 'credential']:
                if pattern in log_entry_str.lower():
                    logger.warning(f"Potential secret detected in log, skipping artifact for {event_type}")
                    return

            # Write to daily log file
            date_str = datetime.utcnow().strftime('%Y%m%d')
            log_file = self.artifacts_dir / f"adapter_log_{date_str}.jsonl"

            with open(log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')

        except Exception as e:
            logger.warning(f"Failed to log artifact: {e}")
    
    def convert_to_tmf921(self, intent_dict: Dict[str, Any], original_text: str, override_target_site: Optional[str] = None) -> Dict[str, Any]:
        """Convert internal format to TMF921-compliant Intent"""
        from datetime import datetime
        import uuid
        
        # Generate unique ID
        intent_id = str(uuid.uuid4())
        
        # Map service types to TMF921 format
        service_type = intent_dict.get("service", "eMBB")
        location = intent_dict.get("location", "edge1")
        target_site = override_target_site or intent_dict.get("targetSite", "edge1")
        qos = intent_dict.get("qos", {})
        
        # Build TMF921 structure
        tmf921_intent = {
            "intentId": intent_id,
            "intentName": f"{service_type} Service at {location}",
            "intentType": "NETWORK_SLICE_INTENT",
            "intentState": "CREATED",
            "intentPriority": 9 if service_type == "URLLC" else 5,
            "targetSite": target_site,
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
            "expectedOutcome": f"Deploy {service_type} network slice at {location} with specified QoS parameters",
            "intentExpectations": [
                {
                    "expectationId": str(uuid.uuid4()),
                    "expectationName": "Service Quality",
                    "expectationType": "PERFORMANCE",
                    "expectationTargets": [
                        {
                            "targetName": "latency",
                            "targetValue": qos.get("latency_ms") or 50,
                            "targetUnit": "ms",
                            "targetOperator": "<="
                        },
                        {
                            "targetName": "throughput",
                            "targetValue": qos.get("downlink_mbps") or 100,
                            "targetUnit": "Mbps",
                            "targetOperator": ">="
                        }
                    ],
                    "priority": 8
                }
            ],
            "intentMetadata": {
                "createdAt": datetime.utcnow().isoformat(),
                "createdBy": "LLM-Adapter",
                "version": "1.0",
                "source": "Natural Language Processing",
                "additionalInfo": {
                    "targetSite": target_site,
                    "serviceType": service_type
                }
            }
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