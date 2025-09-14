#!/bin/bash

# LLM Adapter Interactive Demo Script
# For VM-3 (147.251.115.156) SSH demonstrations

# Colors for better visualization
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
API_URL="http://localhost:8888"
LOG_FILE="/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter/demo_$(date +%Y%m%d_%H%M%S).log"

# Clear screen and show header
clear_and_header() {
    clear
    echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║         LLM Intent Adapter Demo - VM-3 (localhost)        ║${NC}"
    echo -e "${BLUE}${BOLD}║           Natural Language → TMF921 Intent JSON           ║${NC}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Check service status
check_service() {
    echo -e "${YELLOW}Checking service status...${NC}"
    response=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/health)
    if [ "$response" = "200" ]; then
        health=$(curl -s $API_URL/health)
        echo -e "${GREEN}✓ Service is running${NC}"
        echo -e "${CYAN}  Mode: $(echo $health | jq -r .llm_mode)${NC}"
        echo -e "${CYAN}  Version: $(echo $health | jq -r .version)${NC}"
        return 0
    else
        echo -e "${RED}✗ Service is not running${NC}"
        echo -e "${YELLOW}Starting service...${NC}"
        cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter
        export CLAUDE_CLI=1
        nohup python3 main.py > service.log 2>&1 &
        sleep 3
        return 1
    fi
}

# Send intent request
send_intent() {
    local text="$1"
    local endpoint="$2"

    echo -e "\n${CYAN}Request:${NC} $text"
    echo -e "${YELLOW}Processing...${NC}"

    # Log request
    echo "$(date): Request: $text" >> "$LOG_FILE"

    # Send request and capture response
    response=$(curl -s -X POST $API_URL$endpoint \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" 2>&1)

    # Log response
    echo "$(date): Response: $response" >> "$LOG_FILE"

    # Check if response is valid JSON
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Response received:${NC}"
        echo "$response" | jq --color-output .
    else
        echo -e "${RED}✗ Error: Invalid response${NC}"
        echo "$response"
    fi

    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read
}

# Predefined scenarios
run_scenario() {
    local scenario="$1"

    case "$scenario" in
        1)  # eMBB English
            send_intent "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency" "/generate_intent"
            ;;
        2)  # eMBB Chinese
            send_intent "在edge1部署eMBB切片，下行200Mbps，延遲30ms" "/generate_intent"
            ;;
        3)  # URLLC English
            send_intent "Create URLLC service in edge2 with 10ms latency and 100Mbps downlink" "/generate_intent"
            ;;
        4)  # URLLC Chinese
            send_intent "在edge2創建URLLC服務，延遲10ms，下行100Mbps" "/generate_intent"
            ;;
        5)  # mMTC English
            send_intent "Setup mMTC network for IoT devices across both edge sites with 50Mbps capacity" "/generate_intent"
            ;;
        6)  # mMTC Chinese
            send_intent "在兩個邊緣站點設置mMTC網絡用於IoT設備，容量50Mbps" "/generate_intent"
            ;;
        7)  # Complex scenario
            send_intent "Deploy high-performance enhanced mobile broadband at primary edge with 500Mbps throughput and ultra-low 5ms latency for AR/VR applications" "/generate_intent"
            ;;
        8)  # API v1 test
            send_intent "Deploy eMBB service at edge1 with QoS requirements" "/api/v1/intent/parse"
            ;;
    esac
}

# Custom input
custom_input() {
    clear_and_header
    echo -e "${CYAN}${BOLD}Custom Natural Language Input${NC}"
    echo -e "${YELLOW}Enter your natural language request:${NC}"
    echo -e "${CYAN}Example: Deploy eMBB slice at edge1 with 100Mbps${NC}"
    echo
    read -p "> " custom_text

    echo -e "\n${YELLOW}Select endpoint:${NC}"
    echo "1) /generate_intent (TMF921 format)"
    echo "2) /api/v1/intent/parse (Standard v1 API)"
    read -p "Choice [1-2]: " endpoint_choice

    case "$endpoint_choice" in
        1) endpoint="/generate_intent" ;;
        2) endpoint="/api/v1/intent/parse" ;;
        *) endpoint="/generate_intent" ;;
    esac

    send_intent "$custom_text" "$endpoint"
}

# Batch test
batch_test() {
    clear_and_header
    echo -e "${CYAN}${BOLD}Running Batch Test Suite${NC}"
    echo -e "${YELLOW}This will test multiple scenarios automatically${NC}"
    echo

    scenarios=(
        "Deploy eMBB slice in edge1 with 100Mbps downlink"
        "Create URLLC service at edge2 with 5ms latency"
        "Setup mMTC for IoT devices"
        "Deploy network slice at both edges"
        "Create ultra-reliable service with minimal latency"
    )

    for i in "${!scenarios[@]}"; do
        echo -e "\n${BLUE}Test $((i+1))/${#scenarios[@]}${NC}"
        send_intent "${scenarios[$i]}" "/generate_intent"
    done

    echo -e "\n${GREEN}Batch test completed!${NC}"
    echo -e "${CYAN}Results logged to: $LOG_FILE${NC}"
}

# View logs
view_logs() {
    clear_and_header
    echo -e "${CYAN}${BOLD}Recent Activity Logs${NC}"
    echo

    if [ -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}Current session log:${NC}"
        tail -20 "$LOG_FILE"
    fi

    echo -e "\n${YELLOW}Adapter logs:${NC}"
    tail -10 /home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter/adapter_log_$(date +%Y%m%d).jsonl 2>/dev/null || echo "No logs for today"

    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read
}

# Main menu
main_menu() {
    while true; do
        clear_and_header
        check_service

        echo -e "\n${CYAN}${BOLD}Demo Options:${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "1) ${BOLD}eMBB Demo${NC} - Enhanced Mobile Broadband (English)"
        echo "2) ${BOLD}eMBB 演示${NC} - 增強型移動寬頻 (中文)"
        echo "3) ${BOLD}URLLC Demo${NC} - Ultra-Reliable Low Latency (English)"
        echo "4) ${BOLD}URLLC 演示${NC} - 超可靠低延遲 (中文)"
        echo "5) ${BOLD}mMTC Demo${NC} - Massive Machine Type (English)"
        echo "6) ${BOLD}mMTC 演示${NC} - 大規模機器類型 (中文)"
        echo "7) ${BOLD}Complex Scenario${NC} - Advanced use case"
        echo "8) ${BOLD}API v1 Test${NC} - Test standard API endpoint"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "C) ${BOLD}Custom Input${NC} - Enter your own request"
        echo "B) ${BOLD}Batch Test${NC} - Run multiple tests"
        echo "L) ${BOLD}View Logs${NC} - Check recent activity"
        echo "H) ${BOLD}Health Check${NC} - Service status"
        echo "Q) ${BOLD}Quit${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        read -p "Select option [1-8/C/B/L/H/Q]: " choice

        case "$choice" in
            [1-8]) run_scenario "$choice" ;;
            [Cc]) custom_input ;;
            [Bb]) batch_test ;;
            [Ll]) view_logs ;;
            [Hh])
                curl -s $API_URL/health | jq .
                echo -e "\n${CYAN}Press Enter to continue...${NC}"
                read
                ;;
            [Qq])
                echo -e "${GREEN}Thank you for using LLM Adapter Demo!${NC}"
                echo -e "${CYAN}Log saved to: $LOG_FILE${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Start demo
echo -e "${BLUE}${BOLD}Starting LLM Adapter Demo...${NC}"

# Create log directory if needed
mkdir -p /home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq for JSON formatting...${NC}"
    sudo apt-get update && sudo apt-get install -y jq
fi

# Run main menu
main_menu