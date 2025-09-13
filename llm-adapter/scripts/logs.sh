#!/bin/bash
# Logs viewing script for LLM Adapter service

SERVICE_NAME="llm-adapter"
SERVICE_DIR="/home/ubuntu/nephio-intent-to-o2-demo/llm-adapter"
LOG_FILE="${SERVICE_DIR}/service.log"

# Parse arguments
LINES=50
FOLLOW=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-f|--follow] [-n|--lines NUMBER]"
            exit 1
            ;;
    esac
done

echo "=== LLM Adapter Service Logs ==="

# Check if using systemd
if systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
    echo "Showing systemd logs..."
    if [ "$FOLLOW" = true ]; then
        sudo journalctl -u ${SERVICE_NAME} -n ${LINES} -f
    else
        sudo journalctl -u ${SERVICE_NAME} -n ${LINES}
    fi
elif [ -f ${LOG_FILE} ]; then
    echo "Showing file logs from: ${LOG_FILE}"
    if [ "$FOLLOW" = true ]; then
        tail -n ${LINES} -f ${LOG_FILE}
    else
        tail -n ${LINES} ${LOG_FILE}
    fi
else
    echo "No log file found at ${LOG_FILE}"
    echo "Service might not be running or logs might be elsewhere"
    exit 1
fi