#!/bin/bash
# P0.4C: VM-4 Edge2 Cluster Deployment with External Access
# Purpose: Deploy edge2 cluster on VM-4 with external port bindings for VM-1 connectivity
# Author: Nephio Intent-to-O2 Demo Pipeline
# Date: 2025-01-13

set -euo pipefail

# Configuration - Updated for VM-1 connectivity
readonly SCRIPT_NAME="p0.4C_vm4_edge2"
readonly EDGE_CLUSTER_NAME="edge2"
readonly VM1_GITEA_URL="http://147.251.115.143:8888"
readonly GITEA_USER="admin1"
readonly GITEA_REPO="edge2-config"
readonly VM4_EXTERNAL_IP="147.251.115.193"
readonly VM4_INTERNAL_IP="172.16.0.89"
readonly LOG_FILE="/tmp/${SCRIPT_NAME}_$(date +%Y%m%d_%H%M%S).log"
readonly ARTIFACTS_DIR="./artifacts/phase12/edge2"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  WARNING:${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR:${NC} $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  INFO:${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ SUCCESS:${NC} $*" | tee -a "$LOG_FILE"
}

# Error handler
error_handler() {
    local line_no=$1
    local exit_code=$2
    log_error "Script failed at line $line_no with exit code $exit_code"
    log_error "Check log file: $LOG_FILE"

    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                     RECOVERY INSTRUCTIONS                       ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "1. Check the log file for details:"
    echo "   cat $LOG_FILE"
    echo ""
    echo "2. Common recovery steps:"
    echo "   - If cluster creation failed: kind delete cluster --name $EDGE_CLUSTER_NAME"
    echo "   - If port binding failed: check if ports are already in use with 'netstat -tlnp'"
    echo "   - If firewall issues: sudo ufw allow 30090/tcp && sudo ufw allow 31280/tcp"
    echo ""
    echo "3. Re-run the script after fixing the issue:"
    echo "   $0"
    echo ""
    exit "$exit_code"
}

trap 'error_handler ${LINENO} $?' ERR

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          P0.4C: VM-4 Edge2 Cluster with External Access              ║${NC}"
    echo -e "${CYAN}║                     Multi-Site Edge Deployment                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Target Environment:${NC}"
    echo "  • VM-4 External IP: $VM4_EXTERNAL_IP"
    echo "  • VM-4 Internal IP: $VM4_INTERNAL_IP"
    echo "  • Cluster Name: $EDGE_CLUSTER_NAME"
    echo "  • Gitea URL: $VM1_GITEA_URL"
    echo "  • Repository: $GITEA_USER/$GITEA_REPO"
    echo "  • External Ports: 30090 (SLO), 31280 (O2IMS), 6443 (API)"
    echo ""
}

# Step 1: Prerequisites Check
install_prerequisites() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 1: Prerequisites Check and Installation                 ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Check required tools
    local missing_tools=()
    for tool in docker kubectl kind jq yq; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        else
            log_success "$tool is available"
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and re-run the script"
        exit 1
    fi

    # Check Docker daemon
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker daemon is not running or not accessible"
        log_info "Try: sudo systemctl start docker"
        exit 1
    fi

    log_success "All prerequisites are met"
}

# Step 2: Create Edge2 Cluster with External Access
create_edge_cluster() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 2: Create Edge2 Cluster with External Access            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${EDGE_CLUSTER_NAME}$"; then
        log_warn "Cluster '$EDGE_CLUSTER_NAME' already exists"

        # Verify cluster is accessible
        if kubectl cluster-info --context "kind-${EDGE_CLUSTER_NAME}" >/dev/null 2>&1; then
            log_success "Cluster is accessible"
            return 0
        else
            log_error "Cluster exists but is not accessible. Recreating..."
            kind delete cluster --name "$EDGE_CLUSTER_NAME"
            sleep 2
        fi
    fi

    # Create cluster with external access configuration
    log_info "Creating kind cluster '$EDGE_CLUSTER_NAME' with external access..."

    # Create kind config with external port bindings
    cat > /tmp/kind-config-edge2.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${EDGE_CLUSTER_NAME}
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
      - "${VM4_EXTERNAL_IP}"
      - "${VM4_INTERNAL_IP}"
      - "localhost"
      - "127.0.0.1"
  extraPortMappings:
  # SLO endpoint - critical for VM-1 connectivity
  - containerPort: 30090
    hostPort: 30090
    protocol: TCP
    listenAddress: "0.0.0.0"
  # O2IMS endpoint
  - containerPort: 31280
    hostPort: 31280
    protocol: TCP
    listenAddress: "0.0.0.0"
  # HTTP NodePort
  - containerPort: 31080
    hostPort: 31080
    protocol: TCP
    listenAddress: "0.0.0.0"
  # HTTPS NodePort
  - containerPort: 31443
    hostPort: 31443
    protocol: TCP
    listenAddress: "0.0.0.0"
  # API Server for external access
  - containerPort: 6443
    hostPort: 6443
    protocol: TCP
    listenAddress: "0.0.0.0"
EOF

    kind create cluster --config=/tmp/kind-config-edge2.yaml
    log_success "Cluster created successfully with external access"

    # Wait for cluster to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=120s
    log_success "All nodes are ready"

    # Set context
    kubectl config use-context "kind-${EDGE_CLUSTER_NAME}"

    # Update kubeconfig for external access
    log_info "Updating kubeconfig for external access..."
    kubectl config set-cluster "kind-${EDGE_CLUSTER_NAME}" --server="https://${VM4_EXTERNAL_IP}:6443"

    log_success "Cluster configured for external access"
}

# Step 3: Install Config Sync
install_config_sync() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 3: Install Config Sync v1.17.0                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Check if Config Sync is already installed
    if kubectl get namespace config-management-system >/dev/null 2>&1 && \
       kubectl get deployment -n config-management-system config-management-operator >/dev/null 2>&1; then
        log_success "Config Sync is already installed"
        return 0
    fi

    log_info "Installing Config Sync v1.17.0..."

    # Create namespace
    kubectl create namespace config-management-system --dry-run=client -o yaml | kubectl apply -f -

    # Install Config Sync
    kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.17.0/config-sync-manifest.yaml

    # Wait for operator to be ready
    log_info "Waiting for Config Sync operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/config-management-operator -n config-management-system

    log_success "Config Sync operator is ready"
}

# Step 4: Configure RootSync
configure_rootsync() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 4: Configure RootSync for VM-1 Gitea Repository          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get Gitea token
    if [[ -z "${GITEA_TOKEN:-}" ]]; then
        log_info "GITEA_TOKEN not set. Please provide the Gitea access token."
        echo -n "Enter Gitea token: "
        read -s GITEA_TOKEN
        echo ""

        if [[ -z "$GITEA_TOKEN" ]]; then
            log_warn "No token provided. Using dummy token (update later if needed)"
            GITEA_TOKEN="dummy-token-replace-me"
        fi
    fi

    # Create secret for Git authentication
    log_info "Creating Git authentication secret..."
    kubectl create secret generic git-creds \
        --namespace=config-management-system \
        --from-literal=username="$GITEA_USER" \
        --from-literal=token="$GITEA_TOKEN" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Create RootSync configuration
    log_info "Creating RootSync configuration..."
    cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: intent-to-o2-rootsync
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: ${VM1_GITEA_URL}/${GITEA_USER}/${GITEA_REPO}.git
    branch: main
    dir: /
    period: 30s
    auth: token
    secretRef:
      name: git-creds
EOF

    log_success "RootSync configuration created"

    # Wait for initial sync
    log_info "Waiting for initial sync..."
    sleep 30
}

# Step 5: Health Checks
run_health_checks() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 5: Health Checks and Validation                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Create artifacts directory
    mkdir -p "$ARTIFACTS_DIR"

    # Check cluster status
    log_info "Checking cluster status..."
    kubectl cluster-info
    kubectl get nodes -o wide

    # Check Config Sync status
    log_info "Checking Config Sync status..."
    kubectl get pods -n config-management-system

    # Check RootSync status
    log_info "Checking RootSync status..."
    kubectl get rootsync -n config-management-system

    # Test external connectivity
    log_info "Testing external port accessibility..."

    # Save status to log file
    cat > "$ARTIFACTS_DIR/edge2_sync.log" <<EOF
# Edge2 Cluster Health Check - $(date)
# VM-4 External IP: $VM4_EXTERNAL_IP
# Cluster: $EDGE_CLUSTER_NAME

## Cluster Info
$(kubectl cluster-info 2>&1)

## Node Status
$(kubectl get nodes -o wide 2>&1)

## Config Sync Status
$(kubectl get pods -n config-management-system 2>&1)

## RootSync Status
$(kubectl get rootsync -n config-management-system -o wide 2>&1)

## Port Test Results
API Server (6443): $(nc -z -v -w3 ${VM4_EXTERNAL_IP} 6443 2>&1 || echo "FAILED")
SLO Endpoint (30090): $(nc -z -v -w3 ${VM4_EXTERNAL_IP} 30090 2>&1 || echo "FAILED")
O2IMS Endpoint (31280): $(nc -z -v -w3 ${VM4_EXTERNAL_IP} 31280 2>&1 || echo "FAILED")
EOF

    log_success "Health check completed. Results saved to $ARTIFACTS_DIR/edge2_sync.log"
}

# Step 6: Print Summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║             VM-4 EDGE2 DEPLOYMENT COMPLETE - READY!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BLUE}Cluster Information:${NC}"
    echo "  • Cluster Name: $EDGE_CLUSTER_NAME"
    echo "  • External API: https://${VM4_EXTERNAL_IP}:6443"
    echo "  • Context: kind-${EDGE_CLUSTER_NAME}"
    echo ""

    echo -e "${BLUE}External Endpoints for VM-1:${NC}"
    echo "  • SLO Metrics: http://${VM4_EXTERNAL_IP}:30090/metrics/api/v1/slo"
    echo "  • O2IMS API: http://${VM4_EXTERNAL_IP}:31280/o2ims/measurement/v1/slo"
    echo ""

    echo -e "${BLUE}GitOps Configuration:${NC}"
    echo "  • Repository: ${VM1_GITEA_URL}/${GITEA_USER}/${GITEA_REPO}"
    echo "  • RootSync: intent-to-o2-rootsync"
    echo "  • Sync Interval: 30 seconds"
    echo ""

    echo -e "${BLUE}VM-1 Integration Commands:${NC}"
    echo "  # Test SLO endpoint from VM-1"
    echo "  curl http://${VM4_EXTERNAL_IP}:30090/metrics/api/v1/slo"
    echo ""
    echo "  # Test O2IMS endpoint from VM-1"
    echo "  curl http://${VM4_EXTERNAL_IP}:31280/o2ims/measurement/v1/slo"
    echo ""

    echo -e "${BLUE}Verification Commands:${NC}"
    echo "  kubectl get rootsync -n config-management-system"
    echo "  kubectl logs -n config-management-system -l app=git-sync --tail=20"
    echo ""

    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Deploy SLO workload to make endpoints available"
    echo "  2. Configure firewall: sudo ufw allow 30090/tcp && sudo ufw allow 31280/tcp"
    echo "  3. Update VM-1 postcheck.sh to use VM-4 endpoints"
    echo "  4. Test multi-site connectivity from VM-1"
    echo ""
}

# Main execution
main() {
    print_banner

    echo -e "${YELLOW}This script will deploy edge2 cluster on VM-4 with external access for VM-1 connectivity.${NC}"
    echo ""
    echo -n "Do you want to proceed? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        exit 0
    fi

    # Execute steps
    install_prerequisites
    create_edge_cluster
    install_config_sync
    configure_rootsync
    run_health_checks
    print_summary

    log_success "VM-4 Edge2 deployment completed successfully! Ready for VM-1 integration."
}

# Run main function
main "$@"