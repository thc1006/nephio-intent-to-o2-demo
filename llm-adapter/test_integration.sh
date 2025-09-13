#!/bin/bash

echo "=== LLM Adapter Integration Test ==="
echo ""

SERVICE_URL="http://localhost:8000"

echo "1. Testing health endpoint..."
curl -s "${SERVICE_URL}/health" | python3 -m json.tool
echo ""

echo "2. Testing intent generation with sample request..."
REQUEST_JSON='{
  "text": "Deploy a 5G network slice with low latency requirements for IoT devices in zone-1"
}'

echo "Request:"
echo "$REQUEST_JSON" | python3 -m json.tool
echo ""

echo "Response:"
curl -s -X POST "${SERVICE_URL}/generate_intent" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON" | python3 -m json.tool

echo ""
echo "3. Testing web UI availability..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "${SERVICE_URL}/"

echo ""
echo "=== Test Complete ==='"