#!/bin/bash
# Interactive Visual Monitor with Manual Refresh Control

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

# Clear screen
clear

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
    if curl -s --max-time $timeout -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -q "^[23]"; then
        echo -e "${GREEN}●${NC} Online"
    else
        echo -e "${RED}●${NC} Offline"
    fi
}

# Function to display status
display_status() {
    clear

    # Header
    echo -e "${WHITE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║     ${MAGENTA}Intent-to-O2 Pipeline Monitor (Interactive)${WHITE}    ║${NC}"
    echo -e "${WHITE}║     $(date '+%Y-%m-%d %H:%M:%S')                      ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════╝${NC}"
    echo

    # Pipeline Flow
    echo -e "${WHITE}Pipeline Flow:${NC}"
    echo -e "  ${BLUE}[User]${NC}"
    echo -e "     ↓"
    echo -e "  ${CYAN}[Web UI]${NC} → ${YELLOW}[LLM Adapter]${NC} $(check_service "http://${VM1_IP}:${LLM_PORT}/health")"
    echo -e "     ↓"
    echo -e "  ${GREEN}[Intent Parser]${NC}"
    echo -e "     ↓"
    echo -e "  ${MAGENTA}[KRM Renderer]${NC}"
    echo -e "     ↓"
    echo -e "  ${WHITE}[GitOps]${NC}"
    echo -e "    ├→ ${BLUE}[Edge1]${NC}"
    echo -e "    └→ ${BLUE}[Edge2]${NC}"
    echo

    # Service Status
    draw_box "Service Status"
    echo -e "  LLM Adapter (VM-1 (Integrated)): $(check_service "http://${VM1_IP}:${LLM_PORT}/health")"
    echo -e "  O2IMS Edge1 (VM-2): $(check_service "http://${VM2_IP}:31280")"
    echo -e "  O2IMS Edge2 (VM-4): $(check_service "http://${VM4_IP}:31280")"
    echo -e "  Gitea Repository:   $(check_service "http://localhost:${GITEA_PORT}")"
    draw_box_end
    echo

    # Quick Access URLs
    draw_box "Quick Access"
    echo -e "  ${WHITE}Web UI:${NC} http://${VM1_IP}:${LLM_PORT}"
    echo -e "  ${WHITE}Gitea:${NC} http://localhost:${GITEA_PORT}"
    echo -e "  ${WHITE}API Health:${NC} http://${VM1_IP}:${LLM_PORT}/health"
    draw_box_end
    echo

    # Control Instructions
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    控制選項                           ║${NC}"
    echo -e "${YELLOW}╟───────────────────────────────────────────────────────╢${NC}"
    echo -e "${YELLOW}║  ${WHITE}[R]${YELLOW} 手動刷新狀態                                    ║${NC}"
    echo -e "${YELLOW}║  ${WHITE}[L]${YELLOW} 查看最新日誌                                    ║${NC}"
    echo -e "${YELLOW}║  ${WHITE}[T]${YELLOW} 測試部署流程                                    ║${NC}"
    echo -e "${YELLOW}║  ${WHITE}[W]${YELLOW} 開啟 Web UI (瀏覽器)                           ║${NC}"
    echo -e "${YELLOW}║  ${WHITE}[Q]${YELLOW} 退出監控                                        ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to show logs
show_logs() {
    clear
    echo -e "${WHITE}=== 最新活動日誌 ===${NC}"
    echo

    if [[ -d artifacts/demo-llm ]]; then
        echo -e "${CYAN}Deployment Logs:${NC}"
        tail -n 10 artifacts/demo-llm/deployment.log 2>/dev/null || echo "No deployment logs"
    fi

    echo
    echo -e "${CYAN}LLM Adapter Logs:${NC}"
    tail -n 5 llm-adapter/service.log 2>/dev/null || echo "No LLM adapter logs"

    echo
    echo -e "${YELLOW}按 Enter 返回主畫面${NC}"
    read
}

# Function to test deployment
test_deployment() {
    clear
    echo -e "${WHITE}=== 測試部署流程 ===${NC}"
    echo

    echo -e "${CYAN}1. 測試 Intent 生成:${NC}"
    local test_intent="Deploy eMBB service on edge1 with 100Mbps"
    echo "   輸入: $test_intent"

    if curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$test_intent\"}" \
        "http://${VM1_IP}:${LLM_PORT}/api/v1/intent/parse" 2>/dev/null; then
        echo -e "   ${GREEN}✓ Intent 生成成功${NC}"
    else
        echo -e "   ${RED}✗ Intent 生成失敗${NC}"
    fi

    echo
    echo -e "${YELLOW}按 Enter 返回主畫面${NC}"
    read
}

# Function to open web UI
open_web_ui() {
    local url="http://${VM1_IP}:${LLM_PORT}"
    echo -e "${CYAN}嘗試開啟 Web UI: $url${NC}"

    # Try different methods to open browser
    if command -v xdg-open > /dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v gnome-open > /dev/null; then
        gnome-open "$url" 2>/dev/null &
    elif command -v firefox > /dev/null; then
        firefox "$url" 2>/dev/null &
    elif command -v chromium-browser > /dev/null; then
        chromium-browser "$url" 2>/dev/null &
    else
        echo -e "${YELLOW}無法自動開啟瀏覽器${NC}"
        echo -e "${WHITE}請手動訪問: $url${NC}"
    fi

    sleep 2
}

# Main loop
while true; do
    display_status

    # Read user input with timeout
    echo -n "選擇操作 [R/L/T/W/Q]: "
    read -t 30 -n 1 key || key="r"  # Auto-refresh after 30 seconds
    echo

    case "${key,,}" in
        r)
            echo -e "${GREEN}刷新中...${NC}"
            sleep 0.5
            ;;
        l)
            show_logs
            ;;
        t)
            test_deployment
            ;;
        w)
            open_web_ui
            ;;
        q)
            echo -e "${WHITE}退出監控系統${NC}"
            tput cnorm  # Show cursor
            exit 0
            ;;
        *)
            echo -e "${YELLOW}未知選項，請重試${NC}"
            sleep 1
            ;;
    esac
done