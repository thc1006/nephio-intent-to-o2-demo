#!/bin/bash

# O2IMS Mock Service Deployment Script for Edge3 and Edge4
# This script automatically deploys O2IMS mock servers to edge sites using sshpass
# Author: Backend API Developer Agent
# Date: 2025-09-27

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/o2ims-deployment-$(date +%Y%m%d-%H%M%S).log"

# Edge site configurations
declare -A EDGE_SITES=(
    ["edge3"]="172.16.5.81"
    ["edge4"]="172.16.1.252"
)

EDGE_USER="thc1006"
EDGE_PASSWORD="1006"
O2IMS_PORT="31280"
SERVICE_NAME="o2ims-mock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

# Create logs directory
mkdir -p "$(dirname "$LOG_FILE")"

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v sshpass &> /dev/null; then
        log_error "sshpass is required but not installed. Install with: sudo apt-get install sshpass"
        exit 1
    fi

    if [[ ! -f "${PROJECT_ROOT}/mock-services/o2ims-mock-server.py" ]]; then
        log_error "O2IMS mock server source file not found at ${PROJECT_ROOT}/mock-services/o2ims-mock-server.py"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    local edge_name=$1

    log_info "Testing SSH connectivity to ${edge_name}..."

    if ssh -o ConnectTimeout=10 "$edge_name" "echo 'SSH connection successful'" &>/dev/null; then
        log_success "SSH connectivity to ${edge_name} OK"
        return 0
    else
        log_error "SSH connectivity to ${edge_name} FAILED"
        return 1
    fi
}

# Function to create customized O2IMS server for each edge
create_customized_server() {
    local edge_name=$1
    local temp_dir="/tmp/o2ims-deployment"

    log_info "Creating customized O2IMS server for ${edge_name}..."

    # Create temporary directory
    mkdir -p "$temp_dir"

    # Copy and customize the server
    cp "${PROJECT_ROOT}/mock-services/o2ims-mock-server.py" "${temp_dir}/o2ims-mock-server-${edge_name}.py"

    # Update the server configuration for the specific edge
    sed -i "s/port=30205/port=${O2IMS_PORT}/g" "${temp_dir}/o2ims-mock-server-${edge_name}.py"
    sed -i "s/localhost:30205/localhost:${O2IMS_PORT}/g" "${temp_dir}/o2ims-mock-server-${edge_name}.py"

    # Add edge-specific identification in the mock data
    cat >> "${temp_dir}/o2ims-mock-server-${edge_name}.py" << EOF

# Edge-specific configuration override
if __name__ == "__main__":
    # Update mock data for edge site
    mock_data.current_edge_site = "${edge_name}"

    logger.info(f"Starting O2IMS Mock Server for ${edge_name} on port ${O2IMS_PORT}")
    uvicorn.run(
        "__main__:app",
        host="0.0.0.0",
        port=${O2IMS_PORT},
        reload=False,
        log_level="info",
        access_log=True
    )
EOF

    log_success "Customized O2IMS server created for ${edge_name}"
    echo "${temp_dir}/o2ims-mock-server-${edge_name}.py"
}

# Function to create systemd service configuration
create_systemd_service() {
    local edge_name=$1

    cat << EOF
[Unit]
Description=O2IMS Mock Server for ${edge_name}
After=network.target
Wants=network.target

[Service]
Type=simple
User=${EDGE_USER}
WorkingDirectory=/home/${EDGE_USER}
ExecStart=/usr/bin/python3 /home/${EDGE_USER}/o2ims-mock-server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp /var/log
PrivateTmp=true

# Resource limits
LimitNOFILE=65535
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
}

# Function to deploy to a single edge
deploy_to_edge() {
    local edge_name=$1

    log_info "Starting deployment to ${edge_name}..."

    # Test connectivity first
    if ! test_ssh_connectivity "$edge_name"; then
        log_error "Skipping deployment to ${edge_name} due to connectivity issues"
        return 1
    fi

    # Create customized server
    local custom_server_path
    custom_server_path=$(create_customized_server "$edge_name")

    # Copy server file to edge
    log_info "Copying O2IMS server to ${edge_name}..."
    if scp "$custom_server_path" "${edge_name}:/home/${EDGE_USER}/o2ims-mock-server.py"; then
        log_success "O2IMS server copied to ${edge_name}"
    else
        log_error "Failed to copy O2IMS server to ${edge_name}"
        return 1
    fi

    # Install Python dependencies
    log_info "Installing Python dependencies on ${edge_name}..."
    if ssh "$edge_name" "python3 -m pip install --user fastapi uvicorn pydantic"; then
        log_success "Python dependencies installed on ${edge_name}"
    else
        log_warning "Some dependencies might already be installed on ${edge_name}"
    fi

    # Create systemd service file
    log_info "Creating systemd service for ${edge_name}..."
    local service_content
    service_content=$(create_systemd_service "$edge_name")

    if ssh "$edge_name" "echo '$service_content' | sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null"; then
        log_success "Systemd service created on ${edge_name}"
    else
        log_error "Failed to create systemd service on ${edge_name}"
        return 1
    fi

    # Enable and start the service
    log_info "Enabling and starting O2IMS service on ${edge_name}..."
    if ssh "$edge_name" "sudo systemctl daemon-reload && sudo systemctl enable ${SERVICE_NAME} && sudo systemctl restart ${SERVICE_NAME}"; then
        log_success "O2IMS service started on ${edge_name}"
    else
        log_error "Failed to start O2IMS service on ${edge_name}"
        return 1
    fi

    # Wait for service to start
    log_info "Waiting for service to start on ${edge_name}..."
    sleep 5

    # Verify service status
    if ssh "$edge_name" "sudo systemctl is-active --quiet ${SERVICE_NAME}"; then
        log_success "O2IMS service is active on ${edge_name}"
    else
        log_warning "O2IMS service might not be fully started yet on ${edge_name}"
    fi

    # Clean up temporary files
    rm -f "$custom_server_path"

    log_success "Deployment to ${edge_name} completed"
    return 0
}

# Function to verify health endpoints
verify_health_endpoints() {
    log_info "Verifying health endpoints..."

    for edge_name in "${!EDGE_SITES[@]}"; do
        local edge_ip="${EDGE_SITES[$edge_name]}"

        log_info "Testing health endpoint for ${edge_name}..."

        # Test health endpoint
        if curl -s --connect-timeout 10 --max-time 30 \
            "http://${edge_ip}:${O2IMS_PORT}/health" > /dev/null; then
            log_success "Health endpoint responding on ${edge_name}"

            # Test O2IMS status endpoint
            if curl -s --connect-timeout 10 --max-time 30 \
                "http://${edge_ip}:${O2IMS_PORT}/o2ims_infrastructureInventory/v1/status" > /dev/null; then
                log_success "O2IMS status endpoint responding on ${edge_name}"
            else
                log_warning "O2IMS status endpoint not responding on ${edge_name}"
            fi
        else
            log_warning "Health endpoint not responding on ${edge_name}"
        fi
    done
}

# Function to display deployment summary
display_summary() {
    log_info "Deployment Summary:"
    echo "===========================================" | tee -a "$LOG_FILE"

    for edge_name in "${!EDGE_SITES[@]}"; do
        local edge_ip="${EDGE_SITES[$edge_name]}"
        echo "Edge Site: ${edge_name}" | tee -a "$LOG_FILE"
        echo "  IP Address: ${edge_ip}" | tee -a "$LOG_FILE"
        echo "  Health URL: http://${edge_ip}:${O2IMS_PORT}/health" | tee -a "$LOG_FILE"
        echo "  O2IMS Status URL: http://${edge_ip}:${O2IMS_PORT}/o2ims_infrastructureInventory/v1/status" | tee -a "$LOG_FILE"
        echo "  API Docs: http://${edge_ip}:${O2IMS_PORT}/docs" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    done

    echo "Service Management Commands:" | tee -a "$LOG_FILE"
    echo "  Check status: sudo systemctl status ${SERVICE_NAME}" | tee -a "$LOG_FILE"
    echo "  View logs: sudo journalctl -u ${SERVICE_NAME} -f" | tee -a "$LOG_FILE"
    echo "  Restart: sudo systemctl restart ${SERVICE_NAME}" | tee -a "$LOG_FILE"
    echo "===========================================" | tee -a "$LOG_FILE"
}

# Main deployment function
main() {
    log_info "Starting O2IMS deployment to edge sites..."
    log_info "Log file: $LOG_FILE"

    check_prerequisites

    local success_count=0
    local total_count=${#EDGE_SITES[@]}

    # Deploy to each edge site
    for edge_name in "${!EDGE_SITES[@]}"; do
        if deploy_to_edge "$edge_name"; then
            ((success_count++))
        fi

        echo "" # Add spacing between deployments
    done

    # Verify health endpoints
    sleep 10  # Give services time to fully start
    verify_health_endpoints

    # Display summary
    display_summary

    # Final status
    if [[ $success_count -eq $total_count ]]; then
        log_success "All deployments successful! ($success_count/$total_count)"
        exit 0
    else
        log_warning "Some deployments failed. Successful: $success_count/$total_count"
        exit 1
    fi
}

# Run main function
main "$@"