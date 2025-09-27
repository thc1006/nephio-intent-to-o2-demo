#!/bin/bash
# Unified WebSocket Services Launcher
# Starts all three WebSocket services: TMux Bridge, Claude Headless, and Realtime Monitor
# VM-1 Orchestrator & Operator Environment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
SERVICES_DIR="${PROJECT_ROOT}/services"
LOGS_DIR="${PROJECT_ROOT}/logs/services"
PID_DIR="${PROJECT_ROOT}/logs/services/pids"

# Service configuration
declare -A SERVICES=(
    ["tmux-websocket-bridge"]="tmux_websocket_bridge.py:8004"
    ["claude-headless"]="claude_headless.py:8002"
    ["realtime-monitor"]="realtime_monitor.py:8003"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
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

# Setup directories
setup_directories() {
    log "Setting up directory structure..."
    mkdir -p "${LOGS_DIR}" "${PID_DIR}"

    # Create .gitkeep for empty directories
    touch "${LOGS_DIR}/.gitkeep"
    touch "${PID_DIR}/.gitkeep"
}

# Check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :${port} -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Check service health
check_service_health() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    info "Checking health for ${service_name} on port ${port}..."

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://localhost:${port}/health" >/dev/null 2>&1; then
            success "${service_name} is healthy (attempt ${attempt}/${max_attempts})"
            return 0
        fi

        if [ $((attempt % 5)) -eq 0 ]; then
            info "Still waiting for ${service_name} health check... (${attempt}/${max_attempts})"
        fi

        sleep 1
        ((attempt++))
    done

    error "${service_name} failed health check after ${max_attempts} attempts"
    return 1
}

# Start a single service
start_service() {
    local service_name=$1
    local config=${SERVICES[$service_name]}
    local script_name=$(echo $config | cut -d: -f1)
    local port=$(echo $config | cut -d: -f2)
    local script_path="${SERVICES_DIR}/${script_name}"
    local log_file="${LOGS_DIR}/${service_name}.log"
    local pid_file="${PID_DIR}/${service_name}.pid"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        error "Service script not found: $script_path"
        return 1
    fi

    # Check if port is already in use
    if check_port $port; then
        local existing_pid=$(lsof -ti :${port} | head -1)
        warning "Port ${port} is already in use by PID ${existing_pid}"

        # Check if it's our service
        if [[ -f "$pid_file" ]]; then
            local stored_pid=$(cat "$pid_file")
            if ps -p "$stored_pid" > /dev/null 2>&1; then
                warning "${service_name} is already running (PID: ${stored_pid})"
                return 0
            else
                warning "Stale PID file found, removing..."
                rm -f "$pid_file"
            fi
        fi

        error "Port ${port} is occupied by another process. Stop it first or use different port."
        return 1
    fi

    log "Starting ${service_name}..."

    # Start the service in background
    cd "${PROJECT_ROOT}"
    nohup python3 "$script_path" > "$log_file" 2>&1 &
    local service_pid=$!

    # Store PID
    echo "$service_pid" > "$pid_file"

    # Wait a moment for the service to start
    sleep 2

    # Check if process is still running
    if ! ps -p "$service_pid" > /dev/null 2>&1; then
        error "${service_name} failed to start. Check logs: ${log_file}"
        rm -f "$pid_file"
        return 1
    fi

    success "${service_name} started (PID: ${service_pid}, Port: ${port})"

    # Perform health check
    if check_service_health "$service_name" "$port"; then
        return 0
    else
        error "${service_name} started but failed health check"
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "python3 is required but not installed"
        return 1
    fi

    # Check tmux (required for tmux-websocket-bridge)
    if ! command -v tmux &> /dev/null; then
        error "tmux is required but not installed. Install with: sudo apt-get install tmux"
        return 1
    fi

    # Check required Python packages
    local required_packages=("fastapi" "uvicorn" "websockets")
    for package in "${required_packages[@]}"; do
        if ! python3 -c "import ${package}" 2>/dev/null; then
            error "Required Python package '${package}' is not installed"
            info "Install with: pip install ${package}"
            return 1
        fi
    done

    # Check Claude CLI (for claude-headless service)
    if ! command -v claude &> /dev/null; then
        warning "Claude CLI not found in PATH. Claude Headless service will use fallback mode."
    fi

    success "All prerequisites satisfied"
    return 0
}

# Stop all services
stop_all_services() {
    log "Stopping all WebSocket services..."

    for service_name in "${!SERVICES[@]}"; do
        local pid_file="${PID_DIR}/${service_name}.pid"

        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                log "Stopping ${service_name} (PID: ${pid})..."
                kill "$pid"

                # Wait for graceful shutdown
                local count=0
                while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 10 ]; do
                    sleep 1
                    ((count++))
                done

                # Force kill if still running
                if ps -p "$pid" > /dev/null 2>&1; then
                    warning "Force killing ${service_name}..."
                    kill -9 "$pid"
                fi

                success "${service_name} stopped"
            fi
            rm -f "$pid_file"
        fi
    done
}

# Display service status
show_status() {
    echo
    echo "=== WebSocket Services Status ==="
    echo

    for service_name in "${!SERVICES[@]}"; do
        local config=${SERVICES[$service_name]}
        local port=$(echo $config | cut -d: -f2)
        local pid_file="${PID_DIR}/${service_name}.pid"

        printf "%-25s" "${service_name}:"

        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                if curl -s -f "http://localhost:${port}/health" >/dev/null 2>&1; then
                    echo -e "${GREEN}RUNNING${NC} (PID: ${pid}, Port: ${port}) ✓"
                else
                    echo -e "${YELLOW}RUNNING${NC} (PID: ${pid}, Port: ${port}) ⚠️  Health check failed"
                fi
            else
                echo -e "${RED}STOPPED${NC} (Stale PID file)"
                rm -f "$pid_file"
            fi
        else
            if check_port $port; then
                echo -e "${YELLOW}UNKNOWN${NC} (Port ${port} in use by external process)"
            else
                echo -e "${RED}STOPPED${NC}"
            fi
        fi
    done

    echo
    echo "=== Service URLs ==="
    echo
    echo "TMux WebSocket Bridge:  http://localhost:8004"
    echo "Claude Headless API:    http://localhost:8002"
    echo "Realtime Monitor:       http://localhost:8003"
    echo "WebSocket Endpoints:"
    echo "  - TMux Bridge:        ws://localhost:8004/ws"
    echo "  - Claude Headless:    ws://localhost:8002/ws"
    echo "  - Realtime Monitor:   ws://localhost:8003/ws"
    echo
}

# Main function
main() {
    echo -e "${PURPLE}"
    echo "==============================================="
    echo "    WebSocket Services Launcher v1.0"
    echo "    VM-1 Intent-to-O2 Demo Environment"
    echo "==============================================="
    echo -e "${NC}"

    # Handle command line arguments
    case "${1:-start}" in
        "start")
            log "Starting WebSocket Services..."

            # Setup
            setup_directories

            # Check prerequisites
            if ! check_prerequisites; then
                error "Prerequisites check failed"
                exit 1
            fi

            # Start services in order
            local failed_services=()

            for service_name in "claude-headless" "realtime-monitor" "tmux-websocket-bridge"; do
                if ! start_service "$service_name"; then
                    failed_services+=("$service_name")
                fi
            done

            # Show final status
            show_status

            if [ ${#failed_services[@]} -eq 0 ]; then
                echo
                success "All WebSocket services started successfully!"
                echo
                info "Access the services:"
                echo "  • TMux Terminal UI:     http://localhost:8004"
                echo "  • Pipeline Monitor:     http://localhost:8003"
                echo "  • Claude Headless API:  http://localhost:8002/docs"
                echo
                info "Logs are available in: ${LOGS_DIR}/"
                info "To stop services: ${SCRIPT_DIR}/stop-websocket-services.sh"
            else
                echo
                error "Some services failed to start: ${failed_services[*]}"
                warning "Check logs in ${LOGS_DIR}/ for details"
                exit 1
            fi
            ;;

        "stop")
            stop_all_services
            success "All services stopped"
            ;;

        "restart")
            log "Restarting all services..."
            stop_all_services
            sleep 2
            exec "$0" start
            ;;

        "status")
            show_status
            ;;

        "logs")
            local service_name="${2:-}"
            if [[ -n "$service_name" && -f "${LOGS_DIR}/${service_name}.log" ]]; then
                tail -f "${LOGS_DIR}/${service_name}.log"
            else
                echo "Available log files:"
                ls -la "${LOGS_DIR}"/*.log 2>/dev/null || echo "No log files found"
                echo
                echo "Usage: $0 logs <service-name>"
                echo "Services: ${!SERVICES[*]}"
            fi
            ;;

        "help"|"-h"|"--help")
            echo "Usage: $0 [COMMAND]"
            echo
            echo "Commands:"
            echo "  start     Start all WebSocket services (default)"
            echo "  stop      Stop all services"
            echo "  restart   Restart all services"
            echo "  status    Show service status"
            echo "  logs      Show available logs or tail specific service log"
            echo "  help      Show this help message"
            echo
            echo "Services managed:"
            for service_name in "${!SERVICES[@]}"; do
                local config=${SERVICES[$service_name]}
                local port=$(echo $config | cut -d: -f2)
                echo "  • ${service_name} (port ${port})"
            done
            ;;

        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"