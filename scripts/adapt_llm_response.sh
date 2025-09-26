#!/usr/bin/env bash
# Adapter script to bridge VM-1 LLM response format to VM-1 expected format
# This handles the format mismatch between the two systems

set -euo pipefail

# Configuration
LLM_ADAPTER_URL="${LLM_ADAPTER_URL:-http://172.16.0.78:8888}"
OUTPUT_FILE="${1:-}"
NATURAL_LANGUAGE="${2:-Deploy eMBB slice at edge1}"
TARGET_SITE="${3:-edge1}"

# Function to call VM-1 and transform response
call_llm_and_transform() {
    local nl_text="$1"
    local target="$2"

    # Call VM-1 LLM Adapter
    local vm1_response
    vm1_response=$(curl -s --connect-timeout 10 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"natural_language\": \"$nl_text\", \"target_site\": \"$target\"}" \
        "${LLM_ADAPTER_URL}/generate_intent" 2>/dev/null)

    # Check if response has nested 'intent' object (VM-1 format)
    if echo "$vm1_response" | jq -e '.intent' >/dev/null 2>&1; then
        # Extract the intent object and flatten it
        local intent_obj=$(echo "$vm1_response" | jq '.intent')

        # Transform VM-1 format to VM-1 expected TMF921 format
        echo "$intent_obj" | jq --arg target "$target" '
        {
            "intentId": .intentId,
            "intentName": .name,
            "intentType": "NETWORK_SLICE_INTENT",
            "intentState": "CREATED",
            "intentPriority": (if .priority == "high" then 1
                             elif .priority == "medium" then 5
                             else 10 end),
            "targetSite": .targetSite,
            "serviceType": (if .service.type == "eMBB" then "enhanced-mobile-broadband"
                           elif .service.type == "URLLC" then "ultra-reliable-low-latency"
                           elif .service.type == "mMTC" then "massive-machine-type"
                           else .service.type end),
            "intentExpectationId": (.intentId + "-exp"),
            "intentExpectationType": "SERVICE_EXPECTATION",
            "intentParameters": {
                "serviceType": .service.type,
                "location": .targetSite,
                "qosParameters": {
                    "downlinkMbps": (.qos.dl_mbps // 100),
                    "uplinkMbps": (.qos.ul_mbps // 50),
                    "latencyMs": (.qos.latency_ms // 10),
                    "reliability": (if .service.characteristics.reliability == "high" then 99.999 else 99.9 end)
                },
                "resourceProfile": "standard",
                "sliceType": .service.type
            },
            "sla": {
                "availability": 99.9,
                "latency": (.qos.latency_ms // 10),
                "throughput": (.qos.dl_mbps // 100),
                "connections": 1000
            },
            "intentMetadata": {
                "createdAt": .metadata.createdAt,
                "createdBy": "LLM-Adapter-VM1",
                "version": .metadata.version,
                "originalRequest": .description
            }
        }'
    else
        # Response is already in correct format or error
        echo "$vm1_response"
    fi
}

# Main execution
main() {
    local transformed_response
    transformed_response=$(call_llm_and_transform "$NATURAL_LANGUAGE" "$TARGET_SITE")

    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$transformed_response" > "$OUTPUT_FILE"
        echo "Intent saved to: $OUTPUT_FILE"
    else
        echo "$transformed_response"
    fi
}

main "$@"