#!/bin/bash
# Start Natural Language Interface with Visual Monitoring
# This is the main entry point for the integrated system

set -euo pipefail

# Configuration
BASE_DIR="/home/ubuntu/nephio-intent-to-o2-demo"
NL_INTERFACE="${BASE_DIR}/scripts/nl_interface.sh"

# Colors for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Function to check prerequisites
check_prerequisites() {
    local missing_deps=()

    # Check required scripts
    if [[ ! -f "$NL_INTERFACE" ]]; then
        missing_deps+=("nl_interface.sh")
    fi

    if [[ ! -f "${BASE_DIR}/scripts/status_bar.sh" ]]; then
        missing_deps+=("status_bar.sh")
    fi

    if [[ ! -f "${BASE_DIR}/scripts/visual_monitor_interactive.sh" ]]; then
        missing_deps+=("visual_monitor_interactive.sh")
    fi

    # Check required commands
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_deps+=("kubectl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Function to setup environment
setup_environment() {
    # Create necessary directories
    mkdir -p "${BASE_DIR}/artifacts"
    mkdir -p "${BASE_DIR}/reports"

    # Source environment variables
    if [[ -f "${BASE_DIR}/scripts/env.sh" ]]; then
        source "${BASE_DIR}/scripts/env.sh"
    fi

    # Ensure proper permissions
    chmod +x "${BASE_DIR}/scripts/"*.sh 2>/dev/null || true
}

# Main function
main() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Intent-to-O2 Natural Language Interface Launcher   ║${NC}"
    echo -e "${CYAN}║  VM-1 (Orchestrator & Operator)                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo

    # Check prerequisites
    echo -e "${WHITE}Checking prerequisites...${NC}"
    if ! check_prerequisites; then
        echo -e "Please install missing dependencies and try again."
        exit 1
    fi
    echo -e "${GREEN}✓ All prerequisites met${NC}"

    # Setup environment
    echo -e "${WHITE}Setting up environment...${NC}"
    setup_environment
    echo -e "${GREEN}✓ Environment ready${NC}"

    echo
    echo -e "${WHITE}Starting Natural Language Interface...${NC}"
    echo -e "${CYAN}You can now use natural language commands to control the Intent-to-O2 pipeline${NC}"
    echo

    # Start the main interface
    exec "$NL_INTERFACE"
}

# Run main function
main "$@"