#!/bin/bash

# LLM Adapter Demo Runner Script
# Starts service, runs tests, and prepares for demo

set -e

echo "========================================"
echo "    LLM Adapter Demo Preparation"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${ADAPTER_DIR}/demo.log"
PID_FILE="${ADAPTER_DIR}/adapter.pid"

# Function to check if service is running
check_service() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Function to start the service
start_service() {
    echo -e "${YELLOW}Starting LLM Adapter service...${NC}"

    # Check if already running
    if check_service; then
        echo -e "${GREEN}Service already running (PID: $(cat $PID_FILE))${NC}"
        return 0
    fi

    # Install dependencies if needed
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
        source venv/bin/activate
        pip install -q -r requirements.txt
    else
        source venv/bin/activate
    fi

    # Set environment variables
    export REQUIRE_API_KEY=false
    export CLAUDE_HEADLESS=true

    # Start the service in background
    nohup python app/main.py > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    # Wait for service to start
    echo -n "Waiting for service to start"
    for i in {1..10}; do
        if curl -s http://localhost:8888/health > /dev/null 2>&1; then
            echo -e "\n${GREEN}✓ Service started successfully${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
    done

    echo -e "\n${RED}✗ Service failed to start${NC}"
    echo "Check logs at: $LOG_FILE"
    return 1
}

# Function to stop the service
stop_service() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}Stopping service (PID: $PID)...${NC}"
            kill "$PID"
            rm -f "$PID_FILE"
            echo -e "${GREEN}✓ Service stopped${NC}"
        else
            rm -f "$PID_FILE"
        fi
    fi
}

# Function to run E2E tests
run_tests() {
    echo -e "\n${YELLOW}Running E2E tests...${NC}"

    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
    fi

    python e2e_test.py
    return $?
}

# Function to show service info
show_info() {
    echo -e "\n${GREEN}========================================"
    echo "    Service Information"
    echo "========================================${NC}"
    echo "  Web UI: http://localhost:8888"
    echo "  API Endpoint: http://localhost:8888/generate_intent"
    echo "  Health Check: http://localhost:8888/health"
    echo "  Mock SLO: http://localhost:8888/mock/slo"
    echo "  Log File: $LOG_FILE"

    if check_service; then
        echo -e "  Status: ${GREEN}Running (PID: $(cat $PID_FILE))${NC}"
    else
        echo -e "  Status: ${RED}Not running${NC}"
    fi
}

# Function to tail logs
tail_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Recent logs:${NC}"
        tail -n 20 "$LOG_FILE"
    fi
}

# Main menu
case "${1:-start}" in
    start)
        cd "$ADAPTER_DIR"
        start_service
        if [ $? -eq 0 ]; then
            sleep 2
            run_tests
            show_info
        fi
        ;;

    stop)
        cd "$ADAPTER_DIR"
        stop_service
        ;;

    restart)
        cd "$ADAPTER_DIR"
        stop_service
        sleep 1
        start_service
        if [ $? -eq 0 ]; then
            sleep 2
            run_tests
            show_info
        fi
        ;;

    test)
        cd "$ADAPTER_DIR"
        if ! check_service; then
            echo -e "${RED}Service not running. Starting...${NC}"
            start_service
            sleep 2
        fi
        run_tests
        ;;

    status)
        cd "$ADAPTER_DIR"
        show_info
        ;;

    logs)
        cd "$ADAPTER_DIR"
        tail_logs
        ;;

    demo)
        cd "$ADAPTER_DIR"
        echo -e "${GREEN}========================================"
        echo "    DEMO MODE ACTIVATED"
        echo "========================================${NC}"

        # Stop any existing service
        stop_service

        # Start fresh
        start_service
        if [ $? -eq 0 ]; then
            sleep 2

            # Run tests to warm cache
            echo -e "\n${YELLOW}Warming up cache for demo...${NC}"
            run_tests > /dev/null 2>&1

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Cache warmed successfully${NC}"
            else
                echo -e "${YELLOW}⚠ Some tests failed, but service is running${NC}"
            fi

            show_info

            echo -e "\n${GREEN}✓ DEMO READY!${NC}"
            echo "The service is running and cache is warmed."
            echo "Open http://localhost:8888 in your browser."
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|test|status|logs|demo}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the adapter service and run tests"
        echo "  stop    - Stop the adapter service"
        echo "  restart - Restart the service"
        echo "  test    - Run E2E tests"
        echo "  status  - Show service status"
        echo "  logs    - Show recent logs"
        echo "  demo    - Prepare for demo (fresh start + cache warm)"
        exit 1
        ;;
esac