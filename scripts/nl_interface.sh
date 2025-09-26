#!/bin/bash
# Natural Language Interface with Visual Monitoring
# Processes natural language commands and visualizes the pipeline

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
source /home/ubuntu/nephio-intent-to-o2-demo/scripts/env.sh 2>/dev/null || true
VM2_IP="${VM2_IP:-172.16.4.45}"
VM1_IP="${VM1_IP:-172.16.0.78}"
VM4_IP="${VM4_IP:-172.16.4.176}"
LLM_PORT="${LLM_PORT:-8888}"

# Visual monitoring PID
MONITOR_PID=""
VISUAL_MODE="interactive"  # Can be: status_bar, interactive, full

# Function to start visual monitoring
start_visual_monitoring() {
    local mode="$1"

    # Kill any existing monitor
    stop_visual_monitoring

    case "$mode" in
        status_bar)
            # Start status bar in background
            /home/ubuntu/nephio-intent-to-o2-demo/scripts/status_bar.sh &
            MONITOR_PID=$!
            # Clear space for main content
            clear
            echo -e "\n\n"
            ;;
        interactive)
            # Start interactive monitor in new terminal if available
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal -- bash -c "/home/ubuntu/nephio-intent-to-o2-demo/scripts/visual_monitor_interactive.sh; exec bash" &
            else
                /home/ubuntu/nephio-intent-to-o2-demo/scripts/visual_monitor_interactive.sh &
            fi
            MONITOR_PID=$!
            ;;
        full)
            # Start full monitoring
            /home/ubuntu/nephio-intent-to-o2-demo/scripts/visual_monitor.sh &
            MONITOR_PID=$!
            ;;
    esac

    VISUAL_MODE="$mode"
}

# Function to stop visual monitoring
stop_visual_monitoring() {
    if [[ -n "$MONITOR_PID" ]] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null || true
        wait "$MONITOR_PID" 2>/dev/null || true
    fi
    MONITOR_PID=""
}

# Function to show visual progress
show_progress() {
    local message="$1"
    local status="${2:-info}"

    case "$status" in
        start)
            echo -e "\n${CYAN}╔══════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ ${WHITE}${BOLD}$message${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════╝${NC}\n"
            ;;
        success)
            echo -e "${GREEN}✓${NC} $message"
            ;;
        error)
            echo -e "${RED}✗${NC} $message"
            ;;
        info)
            echo -e "${BLUE}→${NC} $message"
            ;;
        warning)
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
    esac
}

# Function to visualize pipeline flow
visualize_pipeline() {
    local step="$1"

    echo -e "\n${WHITE}Pipeline Status:${NC}"

    # User Input
    if [[ "$step" == "input" ]]; then
        echo -e "  ${GREEN}●${NC} ${BOLD}[User Input]${NC}"
    else
        echo -e "  ${CYAN}○${NC} [User Input]"
    fi
    echo -e "       ↓"

    # LLM Processing
    if [[ "$step" == "llm" ]]; then
        echo -e "  ${GREEN}●${NC} ${BOLD}[LLM Adapter]${NC} → Processing..."
    elif [[ "$step" == "post-llm" ]]; then
        echo -e "  ${CYAN}✓${NC} [LLM Adapter]"
    else
        echo -e "  ${CYAN}○${NC} [LLM Adapter]"
    fi
    echo -e "       ↓"

    # Intent Generation
    if [[ "$step" == "intent" ]]; then
        echo -e "  ${GREEN}●${NC} ${BOLD}[Intent Generation]${NC} → Creating KRM..."
    elif [[ "$step" == "post-intent" ]]; then
        echo -e "  ${CYAN}✓${NC} [Intent Generation]"
    else
        echo -e "  ${CYAN}○${NC} [Intent Generation]"
    fi
    echo -e "       ↓"

    # Deployment
    if [[ "$step" == "deploy" ]]; then
        echo -e "  ${GREEN}●${NC} ${BOLD}[Deployment]${NC} → Applying to clusters..."
    elif [[ "$step" == "post-deploy" ]]; then
        echo -e "  ${CYAN}✓${NC} [Deployment]"
    else
        echo -e "  ${CYAN}○${NC} [Deployment]"
    fi
    echo -e "       ↓"

    # Edge Sites
    if [[ "$step" == "edges" ]]; then
        echo -e "  ${GREEN}●${NC} ${BOLD}[Edge Sites]${NC}"
        echo -e "     ├→ Edge1 (VM-2): Deploying..."
        echo -e "     └→ Edge2 (VM-4): Deploying..."
    elif [[ "$step" == "complete" ]]; then
        echo -e "  ${CYAN}✓${NC} [Edge Sites]"
        echo -e "     ├→ Edge1 (VM-2): ${GREEN}✓ Deployed${NC}"
        echo -e "     └→ Edge2 (VM-4): ${GREEN}✓ Deployed${NC}"
    else
        echo -e "  ${CYAN}○${NC} [Edge Sites]"
        echo -e "     ├→ Edge1 (VM-2)"
        echo -e "     └→ Edge2 (VM-4)"
    fi
    echo ""
}

# Function to process natural language command
process_nl_command() {
    local command="$1"

    show_progress "Processing Natural Language Command" "start"
    visualize_pipeline "input"

    # Parse command intent
    case "$command" in
        *"deploy"*|*"部署"*)
            handle_deployment_intent "$command"
            ;;
        *"status"*|*"狀態"*|*"monitor"*|*"監控"*)
            handle_status_intent "$command"
            ;;
        *"test"*|*"測試"*)
            handle_test_intent "$command"
            ;;
        *"rollback"*|*"回滾"*)
            handle_rollback_intent "$command"
            ;;
        *"visual"*|*"視覺"*)
            handle_visual_intent "$command"
            ;;
        *)
            # Send to LLM for processing
            handle_llm_intent "$command"
            ;;
    esac
}

# Function to handle deployment intent
handle_deployment_intent() {
    local command="$1"

    show_progress "Detected deployment intent" "info"
    visualize_pipeline "llm"

    # Extract service type and location
    local service_type="eMBB"  # Default
    local location="edge1"      # Default
    local bandwidth="100Mbps"   # Default

    if [[ "$command" == *"uRLLC"* ]]; then
        service_type="uRLLC"
        bandwidth="50Mbps"
    elif [[ "$command" == *"mIoT"* ]]; then
        service_type="mIoT"
        bandwidth="10Mbps"
    fi

    if [[ "$command" == *"edge2"* ]] || [[ "$command" == *"Edge2"* ]]; then
        location="edge2"
    elif [[ "$command" == *"both"* ]] || [[ "$command" == *"all"* ]]; then
        location="all"
    fi

    show_progress "Service: $service_type, Location: $location, Bandwidth: $bandwidth" "info"

    # Send to LLM Adapter
    visualize_pipeline "intent"

    local intent_json=$(cat <<EOF
{
  "text": "Deploy $service_type service on $location with $bandwidth",
  "service_type": "$service_type",
  "location": "$location",
  "bandwidth": "$bandwidth"
}
EOF
)

    echo -e "${CYAN}Sending to LLM Adapter...${NC}"

    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$intent_json" \
        "http://${VM1_IP}:${LLM_PORT}/api/v1/intent/parse" 2>/dev/null || echo "{\"error\": \"Failed to connect\"}")

    if [[ "$response" == *"error"* ]]; then
        show_progress "Failed to process intent" "error"
        echo "$response"
        return 1
    fi

    visualize_pipeline "deploy"

    # Trigger deployment
    show_progress "Triggering deployment pipeline..." "info"

    # Run deployment script
    if [[ -f /home/ubuntu/nephio-intent-to-o2-demo/demo_llm.sh ]]; then
        bash /home/ubuntu/nephio-intent-to-o2-demo/demo_llm.sh "$service_type" "$location"
        visualize_pipeline "edges"
        sleep 2
        visualize_pipeline "complete"
        show_progress "Deployment completed successfully" "success"
    else
        show_progress "Deployment script not found" "error"
    fi
}

# Function to handle status intent
handle_status_intent() {
    local command="$1"

    show_progress "Checking system status..." "info"

    echo -e "\n${WHITE}═══ Service Status ═══${NC}"

    # Check LLM Adapter
    if curl -s --max-time 2 "http://${VM1_IP}:${LLM_PORT}/health" &>/dev/null; then
        echo -e "LLM Adapter (VM-1 (Integrated)): ${GREEN}● Online${NC}"
    else
        echo -e "LLM Adapter (VM-1 (Integrated)): ${RED}● Offline${NC}"
    fi

    # Check Edge Sites
    if curl -s --max-time 2 "http://${VM2_IP}:31280" &>/dev/null; then
        echo -e "Edge1 O2IMS (VM-2): ${GREEN}● Online${NC}"
    else
        echo -e "Edge1 O2IMS (VM-2): ${RED}● Offline${NC}"
    fi

    if nc -zv -w 1 ${VM4_IP} 31280 &>/dev/null; then
        echo -e "Edge2 O2IMS (VM-4): ${GREEN}● Online${NC}"
    else
        echo -e "Edge2 O2IMS (VM-4): ${RED}● Offline${NC}"
    fi

    # Check deployments
    echo -e "\n${WHITE}═══ Active Deployments ═══${NC}"
    kubectl get deployments -A 2>/dev/null | grep -E "intent-|eMBB|uRLLC|mIoT" || echo "No active deployments"
}

# Function to handle test intent
handle_test_intent() {
    local command="$1"

    show_progress "Running test deployment..." "info"
    visualize_pipeline "input"

    # Test with a simple eMBB deployment
    local test_command="Deploy eMBB service on edge1 with 100Mbps for testing"
    process_nl_command "$test_command"
}

# Function to handle rollback intent
handle_rollback_intent() {
    local command="$1"

    show_progress "Initiating rollback..." "warning"

    if [[ -f /home/ubuntu/nephio-intent-to-o2-demo/tools/rollback.sh ]]; then
        bash /home/ubuntu/nephio-intent-to-o2-demo/tools/rollback.sh
        show_progress "Rollback completed" "success"
    else
        show_progress "Rollback script not found" "error"
    fi
}

# Function to handle visual mode changes
handle_visual_intent() {
    local command="$1"

    if [[ "$command" == *"status bar"* ]] || [[ "$command" == *"狀態列"* ]]; then
        show_progress "Switching to status bar mode" "info"
        start_visual_monitoring "status_bar"
    elif [[ "$command" == *"interactive"* ]] || [[ "$command" == *"互動"* ]]; then
        show_progress "Switching to interactive mode" "info"
        start_visual_monitoring "interactive"
    elif [[ "$command" == *"full"* ]] || [[ "$command" == *"完整"* ]]; then
        show_progress "Switching to full monitoring mode" "info"
        start_visual_monitoring "full"
    elif [[ "$command" == *"stop"* ]] || [[ "$command" == *"關閉"* ]]; then
        show_progress "Stopping visual monitoring" "info"
        stop_visual_monitoring
    fi
}

# Function to handle general LLM intent
handle_llm_intent() {
    local command="$1"

    show_progress "Sending to LLM for interpretation..." "info"
    visualize_pipeline "llm"

    # Send to LLM Adapter for general processing
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$command\"}" \
        "http://${VM1_IP}:${LLM_PORT}/api/v1/intent/parse" 2>/dev/null)

    if [[ -n "$response" ]]; then
        echo -e "\n${WHITE}LLM Response:${NC}"
        echo "$response" | jq . 2>/dev/null || echo "$response"
        visualize_pipeline "post-llm"
    else
        show_progress "Failed to get LLM response" "error"
    fi
}

# Function to show help
show_help() {
    echo -e "${WHITE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║     Natural Language Interface - Help             ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Available Commands:${NC}"
    echo -e "  ${WHITE}deploy${NC} <service> on <location> - Deploy a service"
    echo -e "  ${WHITE}status${NC} - Check system status"
    echo -e "  ${WHITE}test${NC} - Run test deployment"
    echo -e "  ${WHITE}rollback${NC} - Rollback last deployment"
    echo -e "  ${WHITE}visual${NC} <mode> - Change visual mode"
    echo
    echo -e "${CYAN}Visual Modes:${NC}"
    echo -e "  ${WHITE}status bar${NC} - Top status bar only"
    echo -e "  ${WHITE}interactive${NC} - Interactive monitor"
    echo -e "  ${WHITE}full${NC} - Full real-time monitor"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  Deploy eMBB service on edge1 with 100Mbps"
    echo -e "  Show system status"
    echo -e "  Start visual monitoring in interactive mode"
    echo -e "  Rollback the last deployment"
}

# Main interface
main() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║   Intent-to-O2 Natural Language Interface         ║${NC}"
    echo -e "${MAGENTA}║   VM-1 Orchestrator                                ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}Type natural language commands or 'help' for assistance${NC}"
    echo -e "${WHITE}Type 'exit' or 'quit' to leave${NC}"
    echo

    # Start default visual monitoring
    show_progress "Starting status bar monitoring..." "info"
    start_visual_monitoring "status_bar"

    # Main command loop
    while true; do
        echo -ne "\n${CYAN}intent>${NC} "
        read -r user_input

        # Handle special commands
        case "$user_input" in
            exit|quit|q)
                show_progress "Shutting down..." "info"
                stop_visual_monitoring
                exit 0
                ;;
            help|h|?)
                show_help
                ;;
            clear|cls)
                clear
                if [[ "$VISUAL_MODE" == "status_bar" ]]; then
                    echo -e "\n\n"  # Leave space for status bar
                fi
                ;;
            "")
                continue
                ;;
            *)
                process_nl_command "$user_input"
                ;;
        esac
    done
}

# Cleanup on exit
cleanup() {
    stop_visual_monitoring
    tput cnorm  # Show cursor
    echo -e "${NC}"
}

trap cleanup EXIT INT TERM

# Start the interface
main