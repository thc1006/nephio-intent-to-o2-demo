#!/bin/bash
# Start LLM Adapter with Claude CLI enabled

echo "Starting LLM Adapter with Claude CLI..."

# Set environment variables
export CLAUDE_CLI=1
export LLM_TIMEOUT=30
export LLM_MAX_RETRIES=3
export LLM_RETRY_BACKOFF=1.5

echo "Environment settings:"
echo "  CLAUDE_CLI=$CLAUDE_CLI"
echo "  LLM_TIMEOUT=$LLM_TIMEOUT"
echo "  LLM_MAX_RETRIES=$LLM_MAX_RETRIES"
echo "  LLM_RETRY_BACKOFF=$LLM_RETRY_BACKOFF"

# Check Claude CLI availability
if command -v claude &> /dev/null; then
    echo "✓ Claude CLI found: $(which claude)"
    echo "  Version: $(claude --version 2>/dev/null || echo 'unknown')"
else
    echo "✗ Claude CLI not found!"
fi

# Change to the adapter directory
cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter

# Kill any existing service
echo "Stopping any existing service..."
pkill -f "python3 main.py" 2>/dev/null || true
sleep 2

# Start the service
echo "Starting LLM Adapter service on port 8888..."
python3 main.py