#!/bin/bash
set -e

# TMF921 Adapter Automated Startup Script

echo "🚀 Starting TMF921 Adapter in Automated Mode"

# Change to adapter directory
cd /home/ubuntu/nephio-intent-to-o2-demo/adapter

# Source environment
if [ -f "set_automation_env.sh" ]; then
    source set_automation_env.sh
fi

# Check if Claude CLI is available (optional)
if command -v claude &> /dev/null; then
    echo "✅ Claude CLI available"
else
    echo "⚠️  Claude CLI not found - using fallback mode only"
fi

# Install Python dependencies
if [ -f "requirements.txt" ]; then
    echo "📦 Installing Python dependencies..."
    pip3 install -r requirements.txt
fi

# Kill any existing adapter process
pkill -f "uvicorn.*main:app" || true
sleep 2

# Start the adapter service
echo "🔄 Starting TMF921 adapter service..."
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8889 --reload &

# Wait for service to start
sleep 5

# Test the service
echo "🧪 Testing service health..."
if curl -s http://localhost:8889/health > /dev/null; then
    echo "✅ TMF921 adapter is running and healthy"
    echo "📍 Service available at: http://localhost:8889"
    echo "📍 API endpoint: http://localhost:8889/api/v1/intent/transform"
    echo "📍 Web UI: http://localhost:8889/"
else
    echo "❌ Service health check failed"
    exit 1
fi

echo "🎉 TMF921 adapter started successfully in automated mode"
