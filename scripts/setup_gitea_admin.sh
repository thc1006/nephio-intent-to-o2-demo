#!/bin/bash

echo "Setting up Gitea admin account..."

# Check if Gitea is initialized
if curl -s http://localhost:8888/api/v1/version > /dev/null 2>&1; then
    echo "Gitea is running on port 8888"

    # Create admin user via API or web interface
    echo "Please access Gitea at:"
    echo ""
    echo "  http://<VM-1-IP>:8888"
    echo ""
    echo "If this is first time setup:"
    echo "  1. Access http://<VM-1-IP>:8888"
    echo "  2. Click 'Register' or go to initial setup"
    echo "  3. Create admin account with:"
    echo "     Username: admin"
    echo "     Password: admin123456"
    echo "     Email: admin@summit-demo.local"
    echo ""
    echo "If already initialized, default credentials might be:"
    echo "  Username: gitea"
    echo "  Password: gitea"
else
    echo "Gitea is not accessible on port 8888"
    exit 1
fi

# Test external access
echo ""
echo "Testing external access..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
echo "Public IP: $PUBLIC_IP"

echo ""
echo "Port accessibility test:"
echo "  Port 8888 (Gitea):      http://$PUBLIC_IP:8888"
echo "  Port 8001 (Claude API): http://$PUBLIC_IP:8001"
echo "  Port 8002 (Monitoring):  http://$PUBLIC_IP:8002"
echo "  Port 8004 (Terminal UI): http://$PUBLIC_IP:8004"

# Check if ports are open
for port in 8888 8001 8002 8004; do
    if nc -z localhost $port 2>/dev/null; then
        echo "  ✓ Port $port is listening locally"
    else
        echo "  ✗ Port $port is not listening"
    fi
done