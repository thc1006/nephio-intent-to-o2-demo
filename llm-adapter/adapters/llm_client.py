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
        self.timeout = int(os.getenv('LLM_TIMEOUT', '10'))  # Reduced from 30s to 10s for faster fallback
        self.max_retries = int(os.getenv('LLM_MAX_RETRIES', '2'))  # Reduced from 3 to 2
        self.retry_backoff = float(os.getenv('LLM_RETRY_BACKOFF', '1.5'))
        self.artifacts_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter')
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)
        self.fallback_count = 0  # Track fallback usage
        self.llm_success_count = 0  # Track successful LLM calls

        if self.use_claude and self.claude_available:
            logger.info("LLM Client: Using Claude CLI with aggressive timeout (10s)")
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
        start_time = time.time()

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
            self.fallback_count += 1
            self._log_artifact("fallback_used", {
                "text": text,
                "result": result,
                "fallback_count": self.fallback_count,
                "success_rate": f"{self.llm_success_count}/{self.llm_success_count + self.fallback_count}"
            })
        else:
            self.llm_success_count += 1
            self._log_artifact("llm_success", {
                "text": text,
                "result": result,
                "response_time_ms": int((time.time() - start_time) * 1000)
            })

        # Cache the result
        CACHE[cache_key] = (time.time(), result)

        return result
    
    def _parse_with_claude(self, text: str) -> Dict[str, Any]:
        """Parse using Claude CLI with optimized deterministic prompt"""
        prompt = f"""You are a TMF921 5G network intent parser. Output ONLY valid JSON.

DETERMINISTIC PARSING RULES:
1. Service Type (check in order):
   - Contains "urllc" or "ultra-reliable" or "critical" or "real-time" → URLLC
   - Contains "mmtc" or "iot" or "sensor" or "machine" or "massive" → mMTC
   - Default or contains "embb" or "video" or "streaming" → eMBB

2. Location:
   - Extract: edge1, edge2, zone1-9, core1-9
   - Default: edge1

3. Target Site:
   - Text contains "edge2" → edge2
   - Text contains "edge1" → edge1
   - Text contains "both" or "multi" → both
   - Service defaults: URLLC→edge2, mMTC→both, eMBB→edge1

4. QoS Parameters:
   - Downlink: Extract number before "mbps"/"gbps" + optional "dl"/"downlink"
   - Uplink: Extract number before "mbps"/"gbps" + "ul"/"uplink" (or null)
   - Latency: Extract number before "ms" (or null)
   - Convert Gbps to Mbps (*1000)

GOLDEN EXAMPLES (exact outputs for these inputs):
"Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency"
→ {{"service":"eMBB","location":"edge1","targetSite":"edge1","qos":{{"downlink_mbps":200,"uplink_mbps":null,"latency_ms":30}}}}

"Create URLLC service in edge2 with 10ms latency and 100Mbps downlink"
→ {{"service":"URLLC","location":"edge2","targetSite":"edge2","qos":{{"downlink_mbps":100,"uplink_mbps":null,"latency_ms":10}}}}

"Setup mMTC network in zone3 for IoT devices with 50Mbps capacity"
→ {{"service":"mMTC","location":"zone3","targetSite":"both","qos":{{"downlink_mbps":50,"uplink_mbps":null,"latency_ms":null}}}}

REQUEST: {text}

JSON:"""
        
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
        """Parse using rule-based extraction with improved pattern matching"""
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

        # Extract QoS with improved pattern matching
        qos = {"downlink_mbps": None, "uplink_mbps": None, "latency_ms": None}

        # Downlink - more flexible pattern
        dl_patterns = [
            r'(\d+)\s*(?:mbps|gbps)\s*(?:dl|downlink|down)',
            r'(?:dl|downlink|down)\s*(?:of\s*)?(\d+)\s*(?:mbps|gbps)',
            r'(\d+)\s*(?:mbps|gbps)\s*(?:bandwidth|capacity|throughput)?'
        ]
        for pattern in dl_patterns:
            dl_match = re.search(pattern, text_lower)
            if dl_match:
                value = int(dl_match.group(1) if '(' in pattern else dl_match.group(1))
                if 'gbps' in text_lower[max(0, dl_match.start()-10):dl_match.end()+10]:
                    value *= 1000
                qos['downlink_mbps'] = value
                break

        # Uplink - explicit pattern
        ul_match = re.search(r'(\d+)\s*(?:mbps|gbps)\s*(?:ul|uplink|up)', text_lower)
        if ul_match:
            value = int(ul_match.group(1))
            if 'gbps' in text_lower[max(0, ul_match.start()-10):ul_match.end()+10]:
                value *= 1000
            qos['uplink_mbps'] = value

        # Latency - improved pattern
        lat_patterns = [
            r'(\d+)\s*ms\s*(?:latency)?',
            r'(?:latency|delay)\s*(?:of\s*)?(\d+)\s*ms',
            r'(?:max|maximum)?\s*(?:latency|delay)\s*[:=]?\s*(\d+)\s*ms'
        ]
        for pattern in lat_patterns:
            lat_match = re.search(pattern, text_lower)
            if lat_match:
                qos['latency_ms'] = int(lat_match.group(1) if '(' in pattern else lat_match.group(1))
                break
        
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