#!/usr/bin/env python3
"""
Claude Intent Processor - VM-1 Integrated Version
Incorporates VM-1 (Integrated)'s deterministic rules and structured output format
"""

import json
import re
import subprocess
import uuid
import hashlib
import time
import logging
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cache for repeated inputs
CACHE = {}
CACHE_TTL = 300  # 5 minutes

# TMF921 Schema (from VM-1 (Integrated))
TMF921_SCHEMA = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "TMF921 Intent Schema",
    "type": "object",
    "required": ["intentId", "intentName", "intentType", "intentState", "intentPriority", "targetSite", "intentParameters"],
    "properties": {
        "intentId": {"type": "string", "pattern": "^[a-zA-Z0-9-]+$"},
        "intentName": {"type": "string", "minLength": 1, "maxLength": 255},
        "intentType": {"type": "string", "enum": ["NETWORK_SLICE_INTENT", "SERVICE_INTENT", "RESOURCE_INTENT"]},
        "intentState": {"type": "string", "enum": ["CREATED", "ACTIVE", "SUSPENDED", "TERMINATED"]},
        "intentPriority": {"type": "integer", "minimum": 0, "maximum": 10},
        "targetSite": {"type": "string", "enum": ["edge1", "edge2", "both", "edge01", "edge02"]},
        "intentParameters": {
            "type": "object",
            "required": ["serviceType"],
            "properties": {
                "serviceType": {"type": "string", "enum": ["eMBB", "URLLC", "mMTC"]},
                "location": {"type": "string"},
                "qosParameters": {"type": "object"}
            }
        }
    }
}

class ClaudeIntentProcessor:
    """
    Unified Intent processor using Claude CLI with VM-1 (Integrated)'s proven rules
    """

    def __init__(self):
        self.claude_path = self._find_claude_cli()
        self.timeout = 15
        self.artifacts_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/artifacts/intent-processor')
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)

        # Stats tracking
        self.llm_success_count = 0
        self.fallback_count = 0

    def _find_claude_cli(self) -> str:
        """Find Claude CLI executable"""
        paths = [
            '/home/ubuntu/.npm-global/bin/claude',
            '/home/ubuntu/.local/bin/claude',
            '/usr/local/bin/claude'
        ]

        for path in paths:
            if Path(path).exists():
                logger.info(f"Found Claude CLI at: {path}")
                return path

        # Try which command
        try:
            result = subprocess.run(['which', 'claude'], capture_output=True, text=True)
            if result.returncode == 0:
                path = result.stdout.strip()
                logger.info(f"Found Claude CLI via which: {path}")
                return path
        except:
            pass

        logger.warning("Claude CLI not found, will use rule-based fallback")
        return None

    def process_natural_language(self, text: str) -> Dict[str, Any]:
        """
        Main entry point - process natural language to TMF921 intent
        Uses Claude CLI with structured prompt or falls back to rules
        """

        # Check cache
        cache_key = hashlib.md5(text.encode()).hexdigest()
        if cache_key in CACHE:
            cached_time, cached_result = CACHE[cache_key]
            if time.time() - cached_time < CACHE_TTL:
                logger.info(f"Cache hit for: {text[:50]}...")
                return cached_result

        # Try Claude CLI first
        result = None
        if self.claude_path:
            try:
                result = self._parse_with_claude(text)
                self.llm_success_count += 1
            except Exception as e:
                logger.warning(f"Claude parsing failed: {e}, using fallback")
                self.fallback_count += 1

        # Fallback to deterministic rules
        if result is None:
            result = self._parse_with_rules(text)
            self.fallback_count += 1

        # Convert to TMF921 format
        tmf921_intent = self._convert_to_tmf921(result, text)

        # Validate against schema
        if not self._validate_tmf921(tmf921_intent):
            logger.error("Generated intent failed TMF921 validation")
            # Log for debugging
            self._log_artifact("validation_failure", {
                "input": text,
                "parsed": result,
                "tmf921": tmf921_intent
            })

        # Cache the result
        CACHE[cache_key] = (time.time(), tmf921_intent)

        # Log successful processing
        self._log_artifact("intent_processed", {
            "input": text,
            "output": tmf921_intent,
            "method": "claude" if self.claude_path and self.llm_success_count > self.fallback_count else "rules"
        })

        return tmf921_intent

    def _parse_with_claude(self, text: str) -> Dict[str, Any]:
        """
        Parse using Claude CLI with VM-1 (Integrated)'s deterministic prompt
        """
        prompt = f"""You are a TMF921 5G network intent parser. Output ONLY valid JSON.

DETERMINISTIC PARSING RULES:
1. Service Type (check in order):
   - Contains "urllc" or "ultra-reliable" or "critical" or "real-time" → URLLC
   - Contains "mmtc" or "iot" or "sensor" or "machine" or "massive" → mMTC
   - Default or contains "embb" or "video" or "streaming" → eMBB

2. Location:
   - Extract: edge1, edge2, edge01, edge02, zone1-9, core1-9
   - Map edge01→edge1, edge02→edge2
   - Default: edge1

3. Target Site:
   - Text contains "edge02" or "edge2" → edge02
   - Text contains "edge01" or "edge1" → edge01
   - Text contains "both" or "multi" → both
   - Service defaults: URLLC→edge02, mMTC→both, eMBB→edge01

4. QoS Parameters:
   - Downlink: Extract number before "mbps"/"gbps" + optional "dl"/"downlink"
   - Uplink: Extract number before "mbps"/"gbps" + "ul"/"uplink" (or null)
   - Latency: Extract number before "ms" (or null)
   - Bandwidth: If just "Mbps" without UL/DL, treat as downlink
   - Convert Gbps to Mbps (*1000)

GOLDEN EXAMPLES:
"Deploy eMBB service on edge01 with 100Mbps"
→ {{"service":"eMBB","location":"edge01","targetSite":"edge01","qos":{{"downlink_mbps":100,"uplink_mbps":null,"latency_ms":null}}}}

"Deploy URLLC with 1ms latency"
→ {{"service":"URLLC","location":"edge1","targetSite":"edge02","qos":{{"downlink_mbps":null,"uplink_mbps":null,"latency_ms":1}}}}

"Deploy mMTC for 10000 IoT devices"
→ {{"service":"mMTC","location":"edge1","targetSite":"both","qos":{{"downlink_mbps":null,"uplink_mbps":null,"latency_ms":null,"device_density":10000}}}}

REQUEST: {text}

JSON:"""

        # Use --output-format json if available, otherwise parse output
        cmd = [
            self.claude_path,
            '--dangerously-skip-permissions',
            '-p', prompt
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=self.timeout
            )

            if result.returncode == 0:
                # Extract JSON from response
                response = result.stdout.strip()

                # Try to find JSON in the response
                json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', response)
                if json_match:
                    parsed = json.loads(json_match.group(0))
                    return parsed

                # If no JSON found, try parsing the whole response
                try:
                    return json.loads(response)
                except:
                    pass

            raise Exception(f"Failed to parse Claude response: {result.stderr or 'No valid JSON found'}")

        except subprocess.TimeoutExpired:
            raise Exception(f"Claude CLI timed out after {self.timeout}s")
        except Exception as e:
            raise Exception(f"Claude CLI error: {e}")

    def _parse_with_rules(self, text: str) -> Dict[str, Any]:
        """
        Deterministic rule-based parser (from VM-1 (Integrated))
        """
        text_lower = text.lower()

        # 1. Service Type Detection
        if any(kw in text_lower for kw in ['urllc', 'ultra-reliable', 'critical', 'real-time', 'low latency']):
            service = "URLLC"
        elif any(kw in text_lower for kw in ['mmtc', 'iot', 'sensor', 'machine', 'massive', 'device']):
            service = "mMTC"
        else:
            service = "eMBB"

        # 2. Location Extraction
        location_match = re.search(r'(edge\d+|edge0\d|zone\d+|core\d+)', text_lower)
        if location_match:
            location = location_match.group(1)
            # Normalize edge names
            location = location.replace('edge01', 'edge1').replace('edge02', 'edge2')
        else:
            location = "edge1"

        # 3. Target Site Determination
        if 'both' in text_lower or 'multi' in text_lower:
            target_site = "both"
        elif 'edge02' in text_lower or 'edge2' in text_lower:
            target_site = "edge02"
        elif 'edge01' in text_lower or 'edge1' in text_lower:
            target_site = "edge01"
        else:
            # Service-based defaults
            if service == "URLLC":
                target_site = "edge02"
            elif service == "mMTC":
                target_site = "both"
            else:
                target_site = "edge01"

        # 4. QoS Parameter Extraction
        qos = {"downlink_mbps": None, "uplink_mbps": None, "latency_ms": None}

        # Bandwidth extraction
        bandwidth_patterns = [
            r'(\d+)\s*(?:gbps|mbps)',  # General bandwidth
            r'(\d+)\s*(?:gbps|mbps)\s*(?:dl|downlink|download)',  # Explicit downlink
            r'(?:dl|downlink|download)\s*(?:of\s*)?(\d+)\s*(?:gbps|mbps)',
        ]

        for pattern in bandwidth_patterns:
            match = re.search(pattern, text_lower)
            if match:
                value = int(match.group(1) if '(' not in pattern else match.group(1))
                if 'gbps' in text_lower[max(0, match.start()-5):match.end()+5]:
                    value *= 1000
                qos['downlink_mbps'] = value
                break

        # Uplink extraction (explicit only)
        ul_match = re.search(r'(\d+)\s*(?:gbps|mbps)\s*(?:ul|uplink|upload)', text_lower)
        if ul_match:
            value = int(ul_match.group(1))
            if 'gbps' in text_lower[max(0, ul_match.start()-5):ul_match.end()+5]:
                value *= 1000
            qos['uplink_mbps'] = value

        # Latency extraction
        lat_match = re.search(r'(\d+)\s*ms', text_lower)
        if lat_match:
            qos['latency_ms'] = int(lat_match.group(1))

        # Device density for mMTC
        if service == "mMTC":
            device_match = re.search(r'(\d+)\s*(?:devices?|sensors?|iot)', text_lower)
            if device_match:
                qos['device_density'] = int(device_match.group(1))

        return {
            "service": service,
            "location": location,
            "targetSite": target_site,
            "qos": qos
        }

    def _convert_to_tmf921(self, parsed: Dict[str, Any], original_text: str) -> Dict[str, Any]:
        """
        Convert parsed intent to TMF921 format
        """
        intent_id = f"intent-{uuid.uuid4().hex[:8]}"
        service_type = parsed.get("service", "eMBB")
        location = parsed.get("location", "edge1")
        target_site = parsed.get("targetSite", "edge01")
        qos = parsed.get("qos", {})

        # Ensure target_site uses edge01/edge02 format
        if target_site == "edge1":
            target_site = "edge01"
        elif target_site == "edge2":
            target_site = "edge02"

        # Build TMF921 structure
        tmf921_intent = {
            "intentId": intent_id,
            "intentName": f"{service_type} Service at {location}",
            "intentType": "NETWORK_SLICE_INTENT",
            "intentState": "CREATED",
            "intentPriority": 9 if service_type == "URLLC" else (7 if service_type == "mMTC" else 5),
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
            "intentMetadata": {
                "createdAt": datetime.utcnow().isoformat(),
                "createdBy": "claude-intent-processor",
                "version": "1.0.0",
                "source": "vm1-integrated",
                "processingMethod": "claude" if self.claude_path else "rules"
            }
        }

        # Add device density for mMTC
        if service_type == "mMTC" and "device_density" in qos:
            tmf921_intent["intentParameters"]["deviceDensity"] = qos["device_density"]

        # Add constraints based on service type
        if service_type == "URLLC":
            tmf921_intent["constraints"] = {
                "reliability": "99.999%",
                "maxLatency": "1ms"
            }
        elif service_type == "mMTC":
            tmf921_intent["constraints"] = {
                "connectionDensity": "1000000 devices/km²"
            }

        return tmf921_intent

    def _validate_tmf921(self, intent: Dict[str, Any]) -> bool:
        """
        Validate intent against TMF921 schema
        """
        try:
            import jsonschema
            jsonschema.validate(intent, TMF921_SCHEMA)
            return True
        except Exception as e:
            logger.error(f"TMF921 validation failed: {e}")
            return False

    def _log_artifact(self, event_type: str, data: Dict[str, Any]):
        """
        Log processing artifacts for debugging and analysis
        """
        try:
            timestamp = datetime.utcnow().isoformat()
            log_entry = {
                "timestamp": timestamp,
                "event_type": event_type,
                "stats": {
                    "llm_success": self.llm_success_count,
                    "fallback": self.fallback_count,
                    "success_rate": f"{self.llm_success_count}/{self.llm_success_count + self.fallback_count}"
                },
                "data": data
            }

            date_str = datetime.utcnow().strftime('%Y%m%d')
            log_file = self.artifacts_dir / f"processor_log_{date_str}.jsonl"

            with open(log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            logger.warning(f"Failed to log artifact: {e}")


# Singleton instance
processor = ClaudeIntentProcessor()

def process_intent(text: str) -> Dict[str, Any]:
    """
    Global function for processing intents
    """
    return processor.process_natural_language(text)


if __name__ == "__main__":
    # Test examples
    test_cases = [
        "Deploy eMBB service on edge01 with 100Mbps",
        "Deploy URLLC with 1ms latency",
        "Deploy mMTC for 10000 IoT devices",
        "Create ultra-reliable service on edge2 with 5ms latency",
        "Setup video streaming with 500Mbps on both edges"
    ]

    print("Testing Claude Intent Processor...")
    print("-" * 50)

    for text in test_cases:
        print(f"\nInput: {text}")
        try:
            result = process_intent(text)
            print(f"Output: {json.dumps(result, indent=2)}")
        except Exception as e:
            print(f"Error: {e}")
        print("-" * 50)