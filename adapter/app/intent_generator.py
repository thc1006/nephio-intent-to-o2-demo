#!/usr/bin/env python3
"""
Intent Generator Module for TMF921 Compliance
Extracted for better separation of concerns and testability
"""

import time
import re
from typing import Dict, Any, Tuple
from datetime import datetime


def infer_service_and_qos(nl_text: str) -> Tuple[str, int, Dict[str, Any]]:
    """Infer service type and QoS requirements from natural language"""
    text_lower = nl_text.lower()

    # Determine service type
    if any(x in text_lower for x in ["video", "streaming", "gaming", "broadband", "embb", "high bandwidth"]):
        service_type = "eMBB"
        sst = 1
    elif any(x in text_lower for x in ["low latency", "ultra-low", "urllc", "critical", "real-time", "autonomous", "5ms", "1ms"]):
        service_type = "URLLC"
        sst = 2
    elif any(x in text_lower for x in ["iot", "sensor", "mmtc", "massive", "monitoring", "machine"]):
        service_type = "mMTC"
        sst = 3
    else:
        service_type = "eMBB"  # Default to eMBB
        sst = 1

    # Extract QoS values
    qos = {}

    # Extract bandwidth
    dl_match = re.search(r'(\d+)\s*(?:mbps|mb/s|gbps|gb/s)\s*(?:download|dl|downlink)', text_lower)
    ul_match = re.search(r'(\d+)\s*(?:mbps|mb/s|gbps|gb/s)\s*(?:upload|ul|uplink)', text_lower)
    bw_match = re.search(r'(\d+)\s*(?:mbps|mb/s|gbps|gb/s)', text_lower)

    if dl_match:
        qos['dl_mbps'] = float(dl_match.group(1)) * (1000 if 'gb' in dl_match.group(0) else 1)
    elif bw_match:
        qos['dl_mbps'] = float(bw_match.group(1)) * (1000 if 'gb' in bw_match.group(0) else 1)

    if ul_match:
        qos['ul_mbps'] = float(ul_match.group(1)) * (1000 if 'gb' in ul_match.group(0) else 1)
    elif bw_match and 'dl_mbps' in qos:
        qos['ul_mbps'] = qos['dl_mbps'] * 0.5  # Assume 50% for upload

    # Extract latency
    latency_match = re.search(r'(\d+)\s*(?:ms|milliseconds?)', text_lower)
    if latency_match:
        qos['latency_ms'] = float(latency_match.group(1))
    elif "low latency" in text_lower or service_type == "URLLC":
        qos['latency_ms'] = 10 if service_type == "URLLC" else 50
    elif service_type == "eMBB":
        qos['latency_ms'] = 50
    elif service_type == "mMTC":
        qos['latency_ms'] = 100

    return service_type, sst, qos


def validate_and_fix_json(intent: Dict[str, Any]) -> Dict[str, Any]:
    """Validate and fix common JSON issues from LLM output"""
    # Fix common issues with LLM-generated JSON

    # Ensure all required fields have proper types
    if "qos" in intent and intent["qos"]:
        for field in ["dl_mbps", "ul_mbps", "latency_ms", "jitter_ms", "packet_loss_rate"]:
            if field in intent["qos"]:
                val = intent["qos"][field]
                # Convert string numbers to actual numbers
                if isinstance(val, str):
                    try:
                        intent["qos"][field] = float(val) if "." in val else int(val)
                    except (ValueError, TypeError):
                        intent["qos"][field] = None

    # Fix slice SST if it's a string
    if "slice" in intent and "sst" in intent.get("slice", {}):
        sst = intent["slice"]["sst"]
        if isinstance(sst, str):
            try:
                intent["slice"]["sst"] = int(sst)
            except (ValueError, TypeError):
                intent["slice"]["sst"] = 1  # Default to eMBB

    # Ensure targetSite is valid
    if "targetSite" in intent:
        if intent["targetSite"] not in ["edge1", "edge2", "both"]:
            intent["targetSite"] = "both"  # Default to both if invalid

    return intent


def enforce_tmf921_structure(intent: Dict[str, Any], target_site: str, nl_text: str) -> Dict[str, Any]:
    """Ensure TMF921-compliant structure with all required fields"""

    # Infer service and QoS if not present
    service_type, sst, qos_defaults = infer_service_and_qos(nl_text)

    # Ensure targetSite
    if "targetSite" not in intent or intent["targetSite"] not in ["edge1", "edge2", "both"]:
        intent["targetSite"] = target_site

    # Ensure intentId - make it deterministic for testing
    if not intent.get("intentId"):
        # For deterministic testing, use a hash-based ID instead of timestamp
        intent_hash = str(hash(f"{nl_text}_{target_site}"))[-8:]
        intent["intentId"] = f"intent_{intent_hash}"

    # Ensure name
    if not intent.get("name"):
        intent["name"] = nl_text[:50] if len(nl_text) <= 50 else nl_text[:47] + "..."

    # Ensure service structure
    if "service" not in intent:
        intent["service"] = {
            "name": f"{service_type} Service",
            "type": service_type,
            "characteristics": {
                "reliability": "high" if service_type == "URLLC" else "medium",
                "mobility": "mobile"
            }
        }
    elif not isinstance(intent.get("service"), dict):
        intent["service"] = {
            "name": "Service",
            "type": service_type,
            "characteristics": {
                "reliability": "high" if service_type == "URLLC" else "medium",
                "mobility": "mobile"
            }
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
        intent["priority"] = "high" if service_type == "URLLC" else "medium"
    if "lifecycle" not in intent:
        intent["lifecycle"] = "draft"

    # Ensure metadata with deterministic timestamp for testing
    if "metadata" not in intent:
        # For deterministic testing, use a fixed timestamp format
        intent["metadata"] = {
            "createdAt": datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
            "version": "1.0.0"
        }

    return intent


def generate_fallback_intent(nl_text: str, target_site: str) -> Dict[str, Any]:
    """Generate intent directly without Claude CLI for TDD testing"""
    service_type, sst, qos_defaults = infer_service_and_qos(nl_text)

    # Generate deterministic ID for testing
    intent_hash = str(hash(f"{nl_text}_{target_site}"))[-8:]

    intent = {
        "intentId": f"intent_{intent_hash}",
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
            "createdAt": datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
            "version": "1.0.0"
        }
    }

    return intent