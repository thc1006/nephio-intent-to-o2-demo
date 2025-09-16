#!/bin/bash

# IntentDeployment Phase Monitor
# Real-time monitoring of CR phase transitions
# Version: v1.1.2-rc1

set -euo pipefail

# Configuration
CONTEXT="${1:-kind-nephio-demo}"
NAMESPACE="${2:-default}"
INTERVAL="${3:-2}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Phase colors mapping
get_phase_color() {
    case $1 in
        "Pending")     echo "${YELLOW}" ;;
        "Compiling")   echo "${CYAN}" ;;
        "Rendering")   echo "${BLUE}" ;;
        "Delivering")  echo "${MAGENTA}" ;;
        "Validating")  echo "${YELLOW}" ;;
        "Succeeded")   echo "${GREEN}" ;;
        "Failed")      echo "${RED}" ;;
        "RollingBack") echo "${YELLOW}" ;;
        *)             echo "${NC}" ;;
    esac
}

# Phase icons
get_phase_icon() {
    case $1 in
        "Pending")     echo "⏳" ;;
        "Compiling")   echo "🔨" ;;
        "Rendering")   echo "🎨" ;;
        "Delivering")  echo "🚀" ;;
        "Validating")  echo "🔍" ;;
        "Succeeded")   echo "✅" ;;
        "Failed")      echo "❌" ;;
        "RollingBack") echo "⏪" ;;
        *)             echo "❓" ;;
    esac
}

# Get phase duration
get_phase_duration() {
    local created=$1
    local now=$(date +%s)
    local start=$(date -d "${created}" +%s 2>/dev/null || echo $now)
    local duration=$((now - start))

    if [ $duration -lt 60 ]; then
        echo "${duration}s"
    elif [ $duration -lt 3600 ]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "$((duration / 3600))h $((duration % 3600 / 60))m"
    fi
}

# Header
print_header() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           IntentDeployment Phase Monitor v1.1.2               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "Context: ${CYAN}${CONTEXT}${NC} | Namespace: ${CYAN}${NAMESPACE}${NC} | Interval: ${CYAN}${INTERVAL}s${NC}"
    echo -e "Press ${YELLOW}Ctrl+C${NC} to exit\n"
}

# State tracking
declare -A previous_phases
declare -A phase_start_times
declare -A phase_durations

# Monitor loop
monitor() {
    while true; do
        print_header

        # Table header
        printf "%-30s %-12s %-8s %-12s %s\n" \
            "NAME" "PHASE" "AGE" "DURATION" "MESSAGE"
        echo "────────────────────────────────────────────────────────────────────────────────"

        # Get all IntentDeployments
        local deployments=$(kubectl --context ${CONTEXT} -n ${NAMESPACE} get intentdeployments -o json 2>/dev/null || echo '{"items":[]}')

        # Parse and display each deployment
        echo "$deployments" | jq -r '.items[] | @base64' | while read -r deployment; do
            # Decode deployment
            _jq() {
                echo "$deployment" | base64 -d | jq -r "$1"
            }

            local name=$(_jq '.metadata.name')
            local phase=$(_jq '.status.phase // "Unknown"')
            local message=$(_jq '.status.message // ""')
            local created=$(_jq '.metadata.creationTimestamp')
            local age=$(get_phase_duration "$created")

            # Track phase transitions
            local prev_phase="${previous_phases[$name]:-}"
            if [ "$prev_phase" != "$phase" ]; then
                # Phase changed
                if [ -n "$prev_phase" ]; then
                    # Log transition
                    local transition_time=$(date +'%H:%M:%S')
                    echo -e "\n${YELLOW}[${transition_time}]${NC} ${name}: ${prev_phase} → ${phase}"

                    # Play sound on completion (if available)
                    if [ "$phase" == "Succeeded" ] && command -v paplay >/dev/null 2>&1; then
                        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
                    elif [ "$phase" == "Failed" ] && command -v paplay >/dev/null 2>&1; then
                        paplay /usr/share/sounds/freedesktop/stereo/dialog-error.oga 2>/dev/null &
                    fi
                fi
                previous_phases[$name]=$phase
                phase_start_times[$name]=$(date +%s)
            fi

            # Calculate phase duration
            local phase_duration=""
            if [ -n "${phase_start_times[$name]:-}" ]; then
                local start=${phase_start_times[$name]}
                local now=$(date +%s)
                local dur=$((now - start))
                phase_duration="(${dur}s)"
            fi

            # Get color for phase
            local color=$(get_phase_color "$phase")
            local icon=$(get_phase_icon "$phase")

            # Print row
            printf "%-30s ${color}%-12s${NC} %-8s %-12s %s\n" \
                "$name" \
                "${icon} $phase" \
                "$age" \
                "$phase_duration" \
                "$(echo $message | cut -c1-40)"
        done

        # Statistics
        echo -e "\n────────────────────────────────────────────────────────────────────────────────"
        local total=$(echo "$deployments" | jq '.items | length')
        local succeeded=$(echo "$deployments" | jq '[.items[] | select(.status.phase == "Succeeded")] | length')
        local failed=$(echo "$deployments" | jq '[.items[] | select(.status.phase == "Failed")] | length')
        local pending=$(echo "$deployments" | jq '[.items[] | select(.status.phase == "Pending")] | length')
        local processing=$((total - succeeded - failed - pending))

        echo -e "Total: ${total} | ${GREEN}Succeeded: ${succeeded}${NC} | ${RED}Failed: ${failed}${NC} | ${YELLOW}Processing: ${processing}${NC} | ${CYAN}Pending: ${pending}${NC}"

        # Progress bar
        if [ $total -gt 0 ]; then
            local progress=$((succeeded * 100 / total))
            echo -n "Progress: ["

            local bar_width=50
            local filled=$((progress * bar_width / 100))

            for ((i=0; i<filled; i++)); do
                echo -n "█"
            done
            for ((i=filled; i<bar_width; i++)); do
                echo -n "░"
            done

            echo "] ${progress}%"
        fi

        # Warnings
        if [ $failed -gt 0 ]; then
            echo -e "\n${RED}⚠ Warning: ${failed} deployment(s) failed. Check logs for details.${NC}"
        fi

        # Sleep
        sleep ${INTERVAL}
    done
}

# Extended monitoring with logs
monitor_with_logs() {
    local log_file="monitor-$(date +%Y%m%d-%H%M%S).log"

    echo "Logging to: ${log_file}"

    while true; do
        local timestamp=$(date +'%Y-%m-%d %H:%M:%S')

        # Get deployments
        local deployments=$(kubectl --context ${CONTEXT} -n ${NAMESPACE} get intentdeployments -o json 2>/dev/null)

        # Log to file
        echo "[${timestamp}]" >> ${log_file}
        echo "$deployments" | jq '.items[] | {name: .metadata.name, phase: .status.phase, message: .status.message}' >> ${log_file}

        # Display
        clear
        print_header

        echo "$deployments" | jq -r '.items[] | "\(.metadata.name): \(.status.phase // "Unknown")"'

        # Check for completion
        local total=$(echo "$deployments" | jq '.items | length')
        local completed=$(echo "$deployments" | jq '[.items[] | select(.status.phase == "Succeeded" or .status.phase == "Failed")] | length')

        if [ "$total" -eq "$completed" ] && [ "$total" -gt 0 ]; then
            echo -e "\n${GREEN}All deployments completed!${NC}"
            echo "Log saved to: ${log_file}"
            break
        fi

        sleep ${INTERVAL}
    done
}

# Watch mode with custom command
watch_custom() {
    local command=$1
    watch -n ${INTERVAL} -c "kubectl --context ${CONTEXT} -n ${NAMESPACE} ${command}"
}

# Main menu
show_menu() {
    echo -e "${GREEN}IntentDeployment Phase Monitor${NC}"
    echo "1) Real-time phase monitor"
    echo "2) Monitor with logging"
    echo "3) Watch deployments (simple)"
    echo "4) Watch with custom command"
    echo "5) Exit"
    echo -n "Select option: "
    read -r option

    case $option in
        1) monitor ;;
        2) monitor_with_logs ;;
        3) watch_custom "get intentdeployments -o wide" ;;
        4)
            echo -n "Enter kubectl command (after 'kubectl'): "
            read -r cmd
            watch_custom "$cmd"
            ;;
        5) exit 0 ;;
        *) echo "Invalid option"; show_menu ;;
    esac
}

# Handle cleanup
cleanup() {
    echo -e "\n${YELLOW}Monitoring stopped${NC}"
    exit 0
}

trap cleanup INT TERM

# Main execution
if [ $# -eq 0 ]; then
    show_menu
else
    monitor
fi