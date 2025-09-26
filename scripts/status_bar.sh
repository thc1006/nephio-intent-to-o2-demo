#!/bin/bash
# 常駐狀態列 - 顯示在終端頂部

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
source /home/ubuntu/nephio-intent-to-o2-demo/scripts/env.sh 2>/dev/null || true
VM2_IP="${VM2_IP:-172.16.4.45}"
VM3_IP="${VM3_IP:-172.16.2.10}"
VM4_IP="${VM4_IP:-172.16.4.176}"

# Service check function (more lenient)
check_service() {
    local url="$1"
    local service_name="$2"

    # Special handling for different services
    case "$service_name" in
        "VM4")
            # VM-4 returns nginx page, just check if port is open
            if nc -zv -w 1 172.16.4.176 31280 &>/dev/null; then
                echo -e "${GREEN}●${NC}"
            else
                echo -e "${RED}●${NC}"
            fi
            ;;
        *)
            # Normal HTTP check for other services
            if curl -s --max-time 1 -o /dev/null "$url" 2>/dev/null; then
                echo -e "${GREEN}●${NC}"
            else
                echo -e "${RED}●${NC}"
            fi
            ;;
    esac
}

# Function to display status bar
display_status_bar() {
    # Save cursor position
    tput sc

    # Move to top of screen
    tput cup 0 0

    # Clear line
    tput el

    # Display status
    echo -ne "${CYAN}[Intent-to-O2]${NC} "
    echo -ne "LLM:$(check_service "http://${VM3_IP}:8888/health" "VM3") "
    echo -ne "Edge1:$(check_service "http://${VM2_IP}:31280" "VM2") "
    echo -ne "Edge2:$(check_service "" "VM4") "
    echo -ne "Git:$(check_service "http://localhost:8888" "Git") "
    echo -ne "| $(date '+%H:%M:%S')"

    # Restore cursor position
    tput rc
}

# Clear screen and prepare
clear
echo -e "\n\n"  # Leave space for status bar

# Main display area
echo "========================================="
echo "    Intent-to-O2 監控系統 (常駐模式)"
echo "========================================="
echo
echo "狀態列說明："
echo "  ${GREEN}●${NC} = 服務正常"
echo "  ${RED}●${NC} = 服務離線"
echo
echo "服務對應："
echo "  LLM   = VM-3 LLM Adapter (172.16.2.10)"
echo "  Edge1 = VM-2 O2IMS (172.16.4.45)"
echo "  Edge2 = VM-4 O2IMS (172.16.4.176)"
echo "  Git   = Gitea Repository (localhost)"
echo
echo "========================================="
echo
echo "按 Ctrl+C 退出"
echo

# Hide cursor
tput civis

# Restore cursor on exit
trap 'tput cnorm; tput cup $(tput lines) 0; echo' EXIT INT TERM

# Main loop - update status bar
while true; do
    display_status_bar
    sleep 2
done