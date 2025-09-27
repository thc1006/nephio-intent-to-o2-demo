#!/bin/bash
# TMF921 Adapter Installation Script
# Installs and configures TMF921 adapter as a systemd service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="tmf921-adapter"

echo "🚀 Installing TMF921 Adapter Service..."

# Check if running as root (for systemd operations)
if [[ $EUID -eq 0 ]]; then
    echo "⚠️  Running as root - this will install system-wide service"
    INSTALL_MODE="system"
    SERVICE_DIR="/etc/systemd/system"
else
    echo "👤 Running as user - this will install user service"
    INSTALL_MODE="user"
    SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
cd "$PROJECT_DIR/adapter"
pip3 install -r requirements.txt --user

# Copy and install systemd service
echo "⚙️  Installing systemd service..."
if [[ "$INSTALL_MODE" == "system" ]]; then
    cp "$SCRIPT_DIR/${SERVICE_NAME}.service" "$SERVICE_DIR/"
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    echo "🔧 Service installed as system service"
else
    cp "$SCRIPT_DIR/${SERVICE_NAME}.service" "$SERVICE_DIR/"
    systemctl --user daemon-reload
    systemctl --user enable "$SERVICE_NAME"
    echo "🔧 Service installed as user service"
fi

# Test configuration
echo "🧪 Testing service configuration..."
if [[ "$INSTALL_MODE" == "system" ]]; then
    systemctl is-enabled "$SERVICE_NAME"
else
    systemctl --user is-enabled "$SERVICE_NAME"
fi

echo "✅ TMF921 Adapter service installed successfully!"
echo ""
echo "📋 Service Management Commands:"
if [[ "$INSTALL_MODE" == "system" ]]; then
    echo "  Start:    sudo systemctl start $SERVICE_NAME"
    echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
    echo "  Status:   sudo systemctl status $SERVICE_NAME"
    echo "  Logs:     sudo journalctl -u $SERVICE_NAME -f"
    echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
else
    echo "  Start:    systemctl --user start $SERVICE_NAME"
    echo "  Stop:     systemctl --user stop $SERVICE_NAME"
    echo "  Status:   systemctl --user status $SERVICE_NAME"
    echo "  Logs:     journalctl --user -u $SERVICE_NAME -f"
    echo "  Restart:  systemctl --user restart $SERVICE_NAME"
fi
echo ""
echo "🌐 Service URL: http://172.16.0.78:8889"
echo "❤️  Health Check: http://172.16.0.78:8889/health"
echo "📝 Web UI: http://172.16.0.78:8889/"