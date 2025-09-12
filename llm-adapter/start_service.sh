#!/bin/bash

# LLM Adapter Service Startup Script

echo "Starting LLM Adapter Service..."

# Kill any existing instances
pkill -f "uvicorn app.main:app" 2>/dev/null

# Navigate to the service directory
cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter

# Start the service
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info &

echo "Service starting on port 8000..."
sleep 3

# Check if service is running
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✓ Service is running successfully!"
    echo "  - Web UI: http://localhost:8000/"
    echo "  - API: http://localhost:8000/generate_intent"
    echo "  - Health: http://localhost:8000/health"
else
    echo "✗ Service failed to start. Check logs."
    exit 1
fi