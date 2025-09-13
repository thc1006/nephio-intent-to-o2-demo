#!/bin/bash
# Stop script for LLM Adapter service

SERVICE_NAME="llm-adapter"
SERVICE_DIR="/home/ubuntu/nephio-intent-to-o2-demo/llm-adapter"

# Try systemd first
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "Stopping ${SERVICE_NAME} via systemd..."
    sudo systemctl stop ${SERVICE_NAME}
    sleep 1
    if ! systemctl is-active --quiet ${SERVICE_NAME}; then
        echo "✓ Service stopped successfully"
    else
        echo "✗ Failed to stop service via systemd"
        exit 1
    fi
else
    # Check for manual process
    if [ -f ${SERVICE_DIR}/service.pid ]; then
        pid=$(cat ${SERVICE_DIR}/service.pid)
        if ps -p $pid > /dev/null 2>&1; then
            echo "Stopping manual process (PID: $pid)..."
            kill -15 $pid
            sleep 2
            if ! ps -p $pid > /dev/null 2>&1; then
                echo "✓ Process stopped successfully"
                rm ${SERVICE_DIR}/service.pid
            else
                echo "Force killing process..."
                kill -9 $pid
                rm ${SERVICE_DIR}/service.pid
            fi
        else
            echo "Process not found for PID: $pid"
            rm ${SERVICE_DIR}/service.pid
        fi
    fi
    
    # Also check port 8000
    existing_pid=$(sudo lsof -t -i:8000)
    if [ ! -z "$existing_pid" ]; then
        echo "Stopping process on port 8000 (PID: $existing_pid)..."
        sudo kill -15 $existing_pid
        sleep 1
        if ! sudo lsof -i:8000 > /dev/null 2>&1; then
            echo "✓ Port 8000 released"
        else
            sudo kill -9 $existing_pid
        fi
    else
        echo "No service running on port 8000"
    fi
fi