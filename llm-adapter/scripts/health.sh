#!/bin/bash
# Health check script for LLM Adapter service

SERVICE_URL="http://localhost:8000"

echo "Checking LLM Adapter service health..."

# Check health endpoint
response=$(curl -s -w "\n%{http_code}" ${SERVICE_URL}/health 2>/dev/null)
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    echo "✓ Service is healthy"
    echo "Response: $body"
    exit 0
else
    echo "✗ Service is not responding or unhealthy"
    echo "HTTP Code: $http_code"
    echo "Response: $body"
    exit 1
fi