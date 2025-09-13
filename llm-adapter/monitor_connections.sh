#!/bin/bash
# Real-time connection monitor for VM-1 integration

echo "================================================"
echo "VM-3 LLM Adapter - Real-time Connection Monitor"
echo "================================================"
echo "Waiting for connections from VM-1..."
echo "Press Ctrl+C to stop monitoring"
echo ""
echo "Service endpoint: http://172.16.2.10:8888"
echo "================================================"
echo ""

# Function to check for new connections
check_connections() {
    # Monitor journal for HTTP requests
    sudo journalctl -u llm-adapter -f --no-pager | while read line; do
        # Check for HTTP requests
        if echo "$line" | grep -qE "GET|POST|HTTP"; then
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # Extract IP if present
            ip=$(echo "$line" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1)
            
            # Check for specific endpoints
            if echo "$line" | grep -q "/health"; then
                echo "[$timestamp] 🟢 Health check from ${ip:-unknown}"
            elif echo "$line" | grep -q "/api/v1/intent/parse"; then
                echo "[$timestamp] 🔵 Intent parse request from ${ip:-unknown}"
                echo "   Full log: $line"
            elif echo "$line" | grep -q "/generate_intent"; then
                echo "[$timestamp] 🔵 Legacy intent request from ${ip:-unknown}"
                echo "   Full log: $line"
            elif echo "$line" | grep -qE "GET /|POST /"; then
                echo "[$timestamp] 🟡 HTTP request: $line"
            fi
            
            # Check if it's from VM-1's expected IP range
            if echo "$ip" | grep -qE "^172\.16\.|^192\.168\."; then
                echo "   ⚡ Possible VM-1 connection detected!"
            fi
        fi
        
        # Check for errors
        if echo "$line" | grep -qiE "error|failed|exception"; then
            echo "[$timestamp] ❌ Error detected: $line"
        fi
        
        # Check for LLM processing
        if echo "$line" | grep -qi "claude"; then
            echo "[$timestamp] 🤖 Claude processing: $line"
        fi
    done
}

# Start monitoring
echo "Starting monitor at $(date)..."
echo ""
check_connections