#!/bin/bash
# Start script for LLM Adapter service

SERVICE_NAME="llm-adapter"
SERVICE_DIR="/home/ubuntu/nephio-intent-to-o2-demo/llm-adapter"
VENV_PATH="${SERVICE_DIR}/.venv"

# Check if service is already running
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "Service ${SERVICE_NAME} is already running"
    systemctl status ${SERVICE_NAME} --no-pager
    exit 0
fi

# Try systemd first
if [ -f /etc/systemd/system/${SERVICE_NAME}.service ]; then
    echo "Starting ${SERVICE_NAME} via systemd..."
    sudo systemctl daemon-reload
    sudo systemctl start ${SERVICE_NAME}
    sleep 2
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo "✓ Service started successfully via systemd"
        systemctl status ${SERVICE_NAME} --no-pager
    else
        echo "✗ Failed to start service via systemd"
        exit 1
    fi
else
    # Fallback to manual start
    echo "Starting ${SERVICE_NAME} manually..."
    cd ${SERVICE_DIR}
    
    # Kill any existing process on port 8000
    existing_pid=$(sudo lsof -t -i:8000)
    if [ ! -z "$existing_pid" ]; then
        echo "Stopping existing process on port 8000 (PID: $existing_pid)"
        kill -9 $existing_pid
        sleep 1
    fi
    
    # Start service
    source ${VENV_PATH}/bin/activate
    nohup uvicorn main:app --host 0.0.0.0 --port 8000 >> service.log 2>&1 &
    echo $! > service.pid
    sleep 2
    
    # Check if started
    if ps -p $(cat service.pid) > /dev/null; then
        echo "✓ Service started manually (PID: $(cat service.pid))"
    else
        echo "✗ Failed to start service"
        exit 1
    fi
fi