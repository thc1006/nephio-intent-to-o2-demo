#!/bin/bash
# 常駐狀態監控 - 極簡版本

# Colors
G='\033[0;32m'  # Green
R='\033[0;31m'  # Red
Y='\033[1;33m'  # Yellow
C='\033[0;36m'  # Cyan
N='\033[0m'      # No color

# Hide cursor and setup cleanup
tput civis
trap 'tput cnorm; echo -e "\n${N}監控已停止"; exit' INT TERM

echo -e "${C}╔════════════════════════════════════════╗${N}"
echo -e "${C}║     Intent-to-O2 即時狀態監控          ║${N}"
echo -e "${C}╚════════════════════════════════════════╝${N}"
echo

# Main monitoring loop
while true; do
    # Check services
    LLM=$(curl -s --max-time 1 http://172.16.2.10:8888/health &>/dev/null && echo "${G}✓${N}" || echo "${R}✗${N}")
    E1=$(curl -s --max-time 1 http://172.16.4.45:31280 &>/dev/null && echo "${G}✓${N}" || echo "${R}✗${N}")
    E2=$(nc -zv -w 1 172.16.4.176 31280 &>/dev/null && echo "${G}✓${N}" || echo "${R}✗${N}")
    GIT=$(curl -s --max-time 1 http://localhost:8888 &>/dev/null && echo "${G}✓${N}" || echo "${R}✗${N}")

    # Display on single line with carriage return
    echo -ne "\r${Y}[$(date +%H:%M:%S)]${N} LLM:$LLM Edge1:$E1 Edge2:$E2 Git:$GIT  "

    sleep 2
done