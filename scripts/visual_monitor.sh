#!/bin/bash
# Real-time Visual Monitor for Intent-to-O2 Demo
# Displays live status of the entire pipeline

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

# Configuration
source /home/ubuntu/nephio-intent-to-o2-demo/scripts/env.sh 2>/dev/null || true
VM2_IP="${VM2_IP:-172.16.4.45}"
VM1_IP="${VM1_IP:-172.16.0.78}"
VM4_IP="${VM4_IP:-172.16.4.176}"
LLM_PORT="${LLM_PORT:-8888}"
GITEA_PORT="${GITEA_PORT:-8888}"
REFRESH_RATE="${REFRESH_RATE:-2}"

# Clear screen and set up terminal
clear
trap 'tput cnorm; echo -e "${NC}"; exit' INT TERM
tput civis  # Hide cursor

# Control variables
PAUSED=false
AUTO_REFRESH=true

# Function to draw box
draw_box() {
    local title="$1"
    local width=50
    echo -e "${CYAN}┌─${WHITE}${title}${CYAN}$(printf '─%.0s' $(seq $((width-${#title}-2))))┐${NC}"
}

draw_box_end() {
    local width=50
    echo -e "${CYAN}└$(printf '─%.0s' $(seq $width))┘${NC}"
}

# Function to check service status
check_service() {
    local url="$1"
    local timeout=2
    # Check if service responds with any HTTP status code
    if curl -s --max-time $timeout -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -q "^[23]"; then
        echo -e "${GREEN}●${NC} Online"
    else
        echo -e "${RED}●${NC} Offline"
    fi
}

# Function to get latest intent
get_latest_intent() {
    if [[ -f artifacts/latest-intent.json ]]; then
        jq -r '.intentType // "None"' artifacts/latest-intent.json 2>/dev/null || echo "None"
    else
        echo "None"
    fi
}

# Function to monitor GitOps sync
check_gitops_sync() {
    local site="$1"
    kubectl get rootsync -n config-management-system 2>/dev/null | grep -q "True" && echo -e "${GREEN}✓${NC} Synced" || echo -e "${YELLOW}⟳${NC} Syncing"
}

# Function to get deployment phase
get_deployment_phase() {
    if [[ -f artifacts/demo-llm/current-phase.txt ]]; then
        cat artifacts/demo-llm/current-phase.txt 2>/dev/null || echo "Idle"
    else
        echo "Idle"
    fi
}

# Main monitoring loop
while true; do
    clear

    # Header
    echo -e "${WHITE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║     ${MAGENTA}Intent-to-O2 Pipeline Visual Monitor${WHITE}           ║${NC}"
    echo -e "${WHITE}║     $(date '+%Y-%m-%d %H:%M:%S')                      ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════╝${NC}"
    echo

    # Pipeline Flow Visualization
    echo -e "${WHITE}Pipeline Flow:${NC}"
    echo -e "  ${BLUE}[User]${NC}"
    echo -e "     ↓"
    echo -e "  ${CYAN}[Web UI]${NC} → ${YELLOW}[LLM Adapter]${NC} $(check_service "http://${VM1_IP}:${LLM_PORT}/health")"
    echo -e "     ↓"
    echo -e "  ${GREEN}[Intent Parser]${NC}"
    echo -e "     ↓"
    echo -e "  ${MAGENTA}[KRM Renderer]${NC} (Phase: $(get_deployment_phase))"
    echo -e "     ↓"
    echo -e "  ${WHITE}[GitOps]${NC}"
    echo -e "    ├→ ${BLUE}[Edge1]${NC} $(check_gitops_sync edge1)"
    echo -e "    └→ ${BLUE}[Edge2]${NC} $(check_gitops_sync edge2)"
    echo

    # Service Status Panel
    draw_box "Service Status"
    echo -e "  LLM Adapter (VM-1 (Integrated)): $(check_service "http://${VM1_IP}:${LLM_PORT}/health")"
    echo -e "  O2IMS Edge1 (VM-2): $(check_service "http://${VM2_IP}:31280/o2ims")"
    echo -e "  O2IMS Edge2 (VM-4): $(check_service "http://${VM4_IP}:31280/o2ims")"
    echo -e "  Gitea Repository:   $(check_service "http://localhost:${GITEA_PORT}")"
    draw_box_end
    echo

    # Current Activity
    draw_box "Current Activity"
    echo -e "  Latest Intent: ${YELLOW}$(get_latest_intent)${NC}"
    echo -e "  Active Phase:  ${CYAN}$(get_deployment_phase)${NC}"

    # Check for active deployments
    if kubectl get deployments -A 2>/dev/null | grep -q "intent-"; then
        echo -e "  Deployments:   ${GREEN}Active${NC}"
        kubectl get deployments -A 2>/dev/null | grep "intent-" | head -3 | while read line; do
            echo -e "    ${WHITE}→${NC} $line"
        done
    else
        echo -e "  Deployments:   ${WHITE}None${NC}"
    fi
    draw_box_end
    echo

    # Recent Logs
    draw_box "Recent Activity Logs"
    if [[ -d artifacts/demo-llm ]]; then
        tail -n 5 artifacts/demo-llm/deployment.log 2>/dev/null | while read line; do
            if [[ "$line" == *ERROR* ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" == *SUCCESS* ]]; then
                echo -e "  ${GREEN}$line${NC}"
            elif [[ "$line" == *WARN* ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  ${WHITE}$line${NC}"
            fi
        done || echo -e "  ${WHITE}No recent activity${NC}"
    else
        echo -e "  ${WHITE}Waiting for activity...${NC}"
    fi
    draw_box_end
    echo

    # SLO Status
    draw_box "SLO Metrics"
    if [[ -f reports/latest/postcheck_report.json ]]; then
        echo -e "  Availability: $(jq -r '.slo.availability // "N/A"' reports/latest/postcheck_report.json 2>/dev/null)"
        echo -e "  Latency:      $(jq -r '.slo.latency // "N/A"' reports/latest/postcheck_report.json 2>/dev/null)"
        echo -e "  Success Rate: $(jq -r '.slo.success_rate // "N/A"' reports/latest/postcheck_report.json 2>/dev/null)"
    else
        echo -e "  ${WHITE}No metrics available${NC}"
    fi
    draw_box_end
    echo

    # Footer
    echo -e "${WHITE}─────────────────────────────────────────────────────${NC}"
    echo -e "Press ${RED}Ctrl+C${NC} to exit | Refreshing every ${YELLOW}${REFRESH_RATE}s${NC}"

    sleep $REFRESH_RATE
done