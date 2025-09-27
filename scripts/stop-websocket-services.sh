#!/bin/bash
# WebSocket Services Stop Script
# Gracefully stops all WebSocket services and cleans up resources
# VM-1 Orchestrator & Operator Environment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
PID_DIR="${PROJECT_ROOT}/logs/services/pids"
LOGS_DIR="${PROJECT_ROOT}/logs/services"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Service configuration
declare -A SERVICES=(
    ["tmux-websocket-bridge"]="8004"
    ["claude-headless"]="8002"
    ["realtime-monitor"]="8003"
)

# Logging functions
log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if process is running
is_process_running() {
    local pid=$1
    ps -p "$pid" > /dev/null 2>&1
}

# Stop a single service
stop_service() {
    local service_name=$1
    local port=${SERVICES[$service_name]}
    local pid_file="${PID_DIR}/${service_name}.pid"
    local stopped=false

    log "Stopping ${service_name}..."

    # Method 1: Use PID file
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if is_process_running "$pid"; then
            info "Sending TERM signal to ${service_name} (PID: ${pid})..."
            kill -TERM "$pid" 2>/dev/null || true

            # Wait for graceful shutdown (up to 10 seconds)
            local count=0
            while is_process_running "$pid" && [ $count -lt 10 ]; do
                sleep 1
                ((count++))
                if [ $((count % 3)) -eq 0 ]; then
                    info "Waiting for ${service_name} to stop... (${count}/10)"
                fi
            done

            # Force kill if still running
            if is_process_running "$pid"; then
                warning "Force killing ${service_name} (PID: ${pid})..."
                kill -KILL "$pid" 2>/dev/null || true
                sleep 1
            fi

            if ! is_process_running "$pid"; then
                success "${service_name} stopped (PID: ${pid})"
                stopped=true
            else
                error "Failed to stop ${service_name} (PID: ${pid})"
            fi
        else
            warning "${service_name} PID file exists but process not running"
            stopped=true
        fi

        # Clean up PID file
        rm -f "$pid_file"
    fi

    # Method 2: Find by port if PID method didn't work
    if ! $stopped; then
        local port_pids=$(lsof -ti :${port} 2>/dev/null || true)
        if [[ -n "$port_pids" ]]; then
            for pid in $port_pids; do
                info "Found process on port ${port} (PID: ${pid}), stopping..."
                kill -TERM "$pid" 2>/dev/null || true
                sleep 2

                if is_process_running "$pid"; then
                    warning "Force killing process on port ${port} (PID: ${pid})..."
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            done
            stopped=true
        fi
    fi

    if ! $stopped; then
        info "${service_name} was not running"
    fi
}

# Clean up tmux sessions (specifically for tmux-websocket-bridge)
cleanup_tmux_sessions() {
    log "Cleaning up TMux sessions..."

    # Check for claude-intent session
    if tmux has-session -t claude-intent 2>/dev/null; then
        info "Killing tmux session: claude-intent"
        tmux kill-session -t claude-intent 2>/dev/null || true
        success "TMux session claude-intent terminated"
    else
        info "TMux session claude-intent not found"
    fi
}

# Clean up log files (optional)
cleanup_logs() {
    local should_clean="${1:-no}"

    if [[ "$should_clean" == "yes" ]]; then
        log "Cleaning up log files..."
        if [[ -d "$LOGS_DIR" ]]; then
            find "$LOGS_DIR" -name "*.log" -type f -delete 2>/dev/null || true
            success "Log files cleaned up"
        fi
    else
        info "Log files preserved in: $LOGS_DIR"
    fi
}

# Check remaining processes
check_remaining_processes() {
    log "Checking for remaining processes..."

    local remaining_found=false

    for service_name in "${!SERVICES[@]}"; do
        local port=${SERVICES[$service_name]}
        local port_pids=$(lsof -ti :${port} 2>/dev/null || true)

        if [[ -n "$port_pids" ]]; then
            warning "Port ${port} (${service_name}) still has processes:"
            for pid in $port_pids; do
                local cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                echo "  PID ${pid}: ${cmd}"
            done
            remaining_found=true
        fi
    done

    if ! $remaining_found; then
        success "All services stopped successfully"
    else
        warning "Some processes may still be running. Manual cleanup might be needed."
    fi
}

# Main function
main() {
    local clean_logs="${1:-no}"
    local force="${2:-no}"

    echo -e "${PURPLE}"
    echo "==============================================="
    echo "    WebSocket Services Stop Script v1.0"
    echo "    VM-1 Intent-to-O2 Demo Environment"
    echo "==============================================="
    echo -e "${NC}"

    # Handle command line arguments
    case "${clean_logs}" in
        "--clean-logs"|"-c")
            clean_logs="yes"
            ;;
        "--force"|"-f")
            force="yes"
            ;;
        "--help"|"-h")
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --clean-logs, -c    Also remove log files"
            echo "  --force, -f         Force kill all processes immediately"
            echo "  --help, -h          Show this help message"
            echo
            echo "Services that will be stopped:"
            for service_name in "${!SERVICES[@]}"; do
                local port=${SERVICES[$service_name]}
                echo "  • ${service_name} (port ${port})"
            done
            exit 0
            ;;
    esac

    # Create PID directory if it doesn't exist
    mkdir -p "$PID_DIR"

    # Stop services in reverse order (opposite of start order)
    local services_to_stop=("tmux-websocket-bridge" "realtime-monitor" "claude-headless")

    if [[ "$force" == "yes" ]]; then
        warning "Force mode enabled - processes will be killed immediately"

        # In force mode, kill all processes on the ports immediately
        for service_name in "${services_to_stop[@]}"; do
            local port=${SERVICES[$service_name]}
            local port_pids=$(lsof -ti :${port} 2>/dev/null || true)

            if [[ -n "$port_pids" ]]; then
                info "Force killing all processes on port ${port}..."
                for pid in $port_pids; do
                    kill -KILL "$pid" 2>/dev/null || true
                done
            fi

            # Clean up PID file
            local pid_file="${PID_DIR}/${service_name}.pid"
            rm -f "$pid_file"
        done
    else
        # Graceful shutdown
        for service_name in "${services_to_stop[@]}"; do
            stop_service "$service_name"
        done
    fi

    # Clean up tmux sessions
    cleanup_tmux_sessions

    # Clean up logs if requested
    cleanup_logs "$clean_logs"

    # Check for remaining processes
    check_remaining_processes

    echo
    success "WebSocket services shutdown complete"

    # Show status if processes might still be running
    if [[ -d "$PID_DIR" ]]; then
        local remaining_pids=$(find "$PID_DIR" -name "*.pid" 2>/dev/null | wc -l)
        if [ "$remaining_pids" -gt 0 ]; then
            warning "Some PID files remain. Run status check to verify."
            info "Use: ${SCRIPT_DIR}/start-websocket-services.sh status"
        fi
    fi

    echo
    info "To restart services: ${SCRIPT_DIR}/start-websocket-services.sh"
}

# Run main function with all arguments
main "$@"