#!/bin/bash
# VM-1 Integration Check Script

echo "========================================="
echo "VM-3 LLM Adapter Integration Status Check"
echo "========================================="
echo ""

# 1. Service Status
echo "1. SERVICE STATUS"
echo "-----------------"
if sudo systemctl is-active --quiet llm-adapter; then
    echo "✅ Service: Running"
    uptime=$(sudo systemctl show llm-adapter --property=ActiveEnterTimestamp | cut -d'=' -f2)
    echo "   Started: $uptime"
else
    echo "❌ Service: Not running"
fi
echo ""

# 2. Network Configuration
echo "2. NETWORK CONFIGURATION"
echo "------------------------"
echo "Available IPs for VM-1 to connect:"
ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "  - "$2}' | cut -d'/' -f1
echo ""
echo "Listening on port: 8888"
sudo lsof -nP -iTCP:8888 -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print "  Process: "$1" (PID: "$2")"}'
echo ""

# 3. Recent Connections
echo "3. RECENT CONNECTIONS (last 2 hours)"
echo "------------------------------------"
connections=$(sudo journalctl -u llm-adapter --since "2 hours ago" 2>/dev/null | grep -c "POST\|GET")
if [ "$connections" -gt 0 ]; then
    echo "Found $connections HTTP requests:"
    sudo journalctl -u llm-adapter --since "2 hours ago" 2>/dev/null | grep -E "POST|GET" | tail -5 | while read line; do
        echo "  - $line"
    done
else
    echo "⚠️  No HTTP requests found from VM-1 yet"
fi
echo ""

# 4. API Endpoints Status
echo "4. API ENDPOINTS STATUS"
echo "-----------------------"
# Health check
if curl -s -f http://localhost:8888/health >/dev/null 2>&1; then
    echo "✅ /health endpoint: Working"
    mode=$(curl -s http://localhost:8888/health | jq -r '.llm_mode')
    echo "   LLM Mode: $mode"
else
    echo "❌ /health endpoint: Not responding"
fi

# Intent parse endpoint
test_response=$(curl -s -X POST http://localhost:8888/api/v1/intent/parse \
    -H "Content-Type: application/json" \
    -d '{"text": "Integration test"}' 2>/dev/null)
    
if echo "$test_response" | jq -e '.intent' >/dev/null 2>&1; then
    echo "✅ /api/v1/intent/parse: Working"
else
    echo "❌ /api/v1/intent/parse: Not working properly"
fi
echo ""

# 5. VM-1 Connection Instructions
echo "5. FOR VM-1 TO CONNECT"
echo "----------------------"
echo "VM-1 should use these commands to test:"
echo ""
echo "# Test connectivity:"
echo "curl -s http://172.16.2.10:8888/health | jq ."
echo ""
echo "# Parse intent:"
echo 'curl -s -X POST http://172.16.2.10:8888/api/v1/intent/parse \'
echo '  -H "Content-Type: application/json" \'
echo '  -d '"'"'{"text": "Deploy eMBB slice with 200Mbps"}'"'"' | jq .'
echo ""

# 6. Integration Status Summary
echo "6. INTEGRATION STATUS SUMMARY"
echo "-----------------------------"
if [ "$connections" -gt 0 ]; then
    echo "🟢 VM-1 Integration: POSSIBLY ACTIVE (found HTTP requests)"
else
    echo "🟡 VM-1 Integration: WAITING FOR CONNECTION"
    echo "   VM-3 service is ready and waiting for VM-1 to connect"
fi
echo ""
echo "========================================="
echo "Report generated: $(date)"
echo "========================================="