#!/bin/bash

echo "========================================="
echo "External Access Test for Intent-to-O2"
echo "========================================="
echo ""

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo "IP Addresses:"
echo "  Public IP:  $PUBLIC_IP"
echo "  Local IP:   $LOCAL_IP"
echo ""

echo "Service Access URLs:"
echo "========================================="
echo ""

# Gitea
echo "1. Gitea (Git Server):"
echo "   URL: http://$PUBLIC_IP:8888"
echo "   Local: http://$LOCAL_IP:8888"
if nc -z localhost 8888 2>/dev/null; then
    echo "   Status: ✓ Running"
    echo "   Login: First visit to set admin credentials"
    echo "          Or try: admin / admin123456"
else
    echo "   Status: ✗ Not running"
fi
echo ""

# Claude Headless API
echo "2. Claude Headless API:"
echo "   URL: http://$PUBLIC_IP:8002"
echo "   Local: http://$LOCAL_IP:8002"
if nc -z localhost 8002 2>/dev/null; then
    echo "   Status: ✓ Running"
    echo "   Endpoint: /api/v1/intent (POST)"
    echo "   Health: /health (GET)"
else
    echo "   Status: ✗ Not running"
fi
echo ""

# Real-time Monitor
echo "3. Real-time Monitor:"
echo "   URL: http://$PUBLIC_IP:8001"
echo "   Local: http://$LOCAL_IP:8001"
if nc -z localhost 8001 2>/dev/null; then
    echo "   Status: ✓ Running"
    echo "   WebSocket: ws://$PUBLIC_IP:8001/ws"
else
    echo "   Status: ✗ Not running"
fi
echo ""

# TMux WebSocket Bridge
echo "4. TMux Terminal Interface:"
echo "   URL: http://$PUBLIC_IP:8004"
echo "   Local: http://$LOCAL_IP:8004"
if nc -z localhost 8004 2>/dev/null; then
    echo "   Status: ✓ Running"
    echo "   Features: Claude CLI in browser with tmux"
    # Check tmux session
    if tmux has-session -t claude-intent 2>/dev/null; then
        echo "   TMux Session: ✓ Active (claude-intent)"
        echo "   Claude Mode: --dangerously-skip-permissions"
    else
        echo "   TMux Session: ✗ Not found"
    fi
else
    echo "   Status: ✗ Not running"
fi
echo ""

# Web Frontend
echo "5. Web Frontend:"
echo "   URL: http://$PUBLIC_IP:8005"
echo "   Local: http://$LOCAL_IP:8005"
if nc -z localhost 8005 2>/dev/null; then
    echo "   Status: ✓ Running"
    echo "   File: /web/index.html"
else
    echo "   Status: ✗ Not running"
    echo "   Start with: cd /home/ubuntu/nephio-intent-to-o2-demo/web && python3 -m http.server 8005"
fi
echo ""

echo "========================================="
echo "Quick Test Commands:"
echo "========================================="
echo ""
echo "# Test Claude API:"
echo "curl -X POST http://$PUBLIC_IP:8002/api/v1/intent \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"text\": \"Deploy eMBB on edge01\"}'"
echo ""
echo "# Test WebSocket:"
echo "wscat -c ws://$PUBLIC_IP:8001/ws"
echo ""
echo "# Check TMux session:"
echo "tmux attach -t claude-intent"
echo ""

echo "========================================="
echo "Firewall Status:"
echo "========================================="
# Check if ufw is installed and active
if command -v ufw &> /dev/null; then
    sudo ufw status numbered 2>/dev/null | grep -E "8888|8001|8002|8004|8005" || echo "No UFW rules for our ports"
else
    echo "UFW not installed"
fi

# Check iptables
echo ""
echo "IPTables rules for our ports:"
sudo iptables -L INPUT -n --line-numbers 2>/dev/null | grep -E "8888|8001|8002|8004|8005" || echo "No specific iptables rules found"

echo ""
echo "========================================="
echo "Note: If external access fails, check:"
echo "  1. Cloud provider security groups/firewall"
echo "  2. VM network security settings"
echo "  3. Port forwarding configuration"
echo "========================================="