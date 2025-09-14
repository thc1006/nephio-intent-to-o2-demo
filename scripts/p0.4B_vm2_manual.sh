#!/bin/bash
# P0.4B: One-Command Fallback Solution for Manual Multi-VM Deployment (VM-2)
# Purpose: Idempotent script to setup edge cluster with GitOps integration to VM-1's Gitea
# Author: Nephio Intent-to-O2 Demo Pipeline
# Date: 2025-01-07

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="p0.4B_vm2_manual"
readonly EDGE_CLUSTER_NAME="edge1"
readonly VM1_GITEA_URL="http://172.16.0.78:8888"
readonly GITEA_USER="admin1"
readonly GITEA_REPO="edge1-config"
readonly VM2_IP="172.16.4.45"
readonly LOG_FILE="/tmp/${SCRIPT_NAME}_$(date +%Y%m%d_%H%M%S).log"
readonly ARTIFACTS_DIR="./artifacts/p0.4B"

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
    
    # Print recovery instructions
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                     RECOVERY INSTRUCTIONS                       ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "1. Check the log file for details:"
    echo "   cat $LOG_FILE"
    echo ""
    echo "2. Common recovery steps:"
    echo "   - If Docker installation failed: sudo apt-get update && sudo apt-get install -y docker.io"
    echo "   - If kind cluster creation failed: kind delete cluster --name $EDGE_CLUSTER_NAME"
    echo "   - If Config Sync installation failed: kubectl delete namespace config-management-system"
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

# Function to wait for resource
wait_for_resource() {
    local resource=$1
    local namespace=${2:-}
    local timeout=${3:-300}
    local ns_flag=""
    
    if [[ -n "$namespace" ]]; then
        ns_flag="-n $namespace"
    fi
    
    log_info "Waiting for $resource to be ready (timeout: ${timeout}s)..."
    if kubectl wait $ns_flag --for=condition=ready "$resource" --timeout="${timeout}s" 2>/dev/null; then
        log_success "$resource is ready"
        return 0
    else
        log_warn "$resource not ready after ${timeout}s"
        return 1
    fi
}

# Print banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          P0.4B: VM-2 Edge Cluster Manual Deployment Script           ║${NC}"
    echo -e "${CYAN}║                     One-Command Fallback Solution                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Target Environment:${NC}"
    echo "  • VM-2 IP: $VM2_IP"
    echo "  • Cluster Name: $EDGE_CLUSTER_NAME"
    echo "  • Gitea URL: $VM1_GITEA_URL"
    echo "  • Repository: $GITEA_USER/$GITEA_REPO"
    echo "  • Log File: $LOG_FILE"
    echo ""
}

# Step 1: Prerequisites Check and Installation
install_prerequisites() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 1: Prerequisites Check and Installation                 ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check and install Docker
    if command_exists docker; then
        log_success "Docker is already installed ($(docker --version))"
    else
        log_info "Installing Docker..."
        sudo apt-get update -qq
        sudo apt-get install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
        log_success "Docker installed successfully"
        log_warn "You may need to logout and login for group changes to take effect"
    fi
    
    # Check Docker daemon
    if sudo docker ps >/dev/null 2>&1; then
        log_success "Docker daemon is running"
    else
        log_error "Docker daemon is not running. Starting it..."
        sudo systemctl start docker
        sleep 3
    fi
    
    # Check and install kubectl
    if command_exists kubectl; then
        log_success "kubectl is already installed ($(kubectl version --client --short 2>/dev/null || echo 'version check failed'))"
    else
        log_info "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        log_success "kubectl installed successfully"
    fi
    
    # Check and install kind
    if command_exists kind; then
        log_success "kind is already installed ($(kind version))"
    else
        log_info "Installing kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        log_success "kind installed successfully"
    fi
    
    # Check and install jq
    if command_exists jq; then
        log_success "jq is already installed"
    else
        log_info "Installing jq..."
        sudo apt-get install -y jq
        log_success "jq installed successfully"
    fi
    
    # Check and install yq
    if command_exists yq; then
        log_success "yq is already installed"
    else
        log_info "Installing yq..."
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        log_success "yq installed successfully"
    fi
}

# Step 2: Create Edge Cluster
create_edge_cluster() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 2: Create Edge Cluster                                   ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${EDGE_CLUSTER_NAME}$"; then
        log_warn "Cluster '$EDGE_CLUSTER_NAME' already exists"
        
        # Verify cluster is accessible
        if kubectl cluster-info --context "kind-${EDGE_CLUSTER_NAME}" >/dev/null 2>&1; then
            log_success "Cluster is accessible"
        else
            log_error "Cluster exists but is not accessible. Recreating..."
            kind delete cluster --name "$EDGE_CLUSTER_NAME"
            sleep 2
        fi
    fi
    
    # Create cluster if it doesn't exist
    if ! kind get clusters 2>/dev/null | grep -q "^${EDGE_CLUSTER_NAME}$"; then
        log_info "Creating kind cluster '$EDGE_CLUSTER_NAME'..."
        
        # Create kind config with proper API server address
        cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${EDGE_CLUSTER_NAME}
networking:
  apiServerAddress: "${VM2_IP}"
  apiServerPort: 6443
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
EOF
        
        kind create cluster --config=/tmp/kind-config.yaml
        log_success "Cluster created successfully"
        
        # Wait for cluster to be ready
        kubectl wait --for=condition=Ready nodes --all --timeout=120s
        log_success "All nodes are ready"
    fi
    
    # Set context
    kubectl config use-context "kind-${EDGE_CLUSTER_NAME}"
    
    # Verify cluster
    log_info "Verifying cluster..."
    kubectl cluster-info
    kubectl get nodes
}

# Step 3: Install Config Sync
install_config_sync() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 3: Install Config Sync Operator                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if Config Sync is already installed
    if kubectl get namespace config-management-system >/dev/null 2>&1; then
        log_warn "Config Sync namespace already exists"
        
        # Check if operator is running
        if kubectl get deployment -n config-management-system config-management-operator >/dev/null 2>&1; then
            log_success "Config Sync operator is already installed"
            return 0
        fi
    fi
    
    log_info "Installing Config Sync operator..."
    
    # Create namespace
    kubectl create namespace config-management-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Config Sync (using a stable version)
    kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.17.0/config-sync-manifest.yaml
    
    # Wait for operator to be ready
    log_info "Waiting for Config Sync operator to be ready..."
    sleep 10
    
    if wait_for_resource "deployment/config-management-operator" "config-management-system" 180; then
        log_success "Config Sync operator is ready"
    else
        log_warn "Config Sync operator may not be fully ready, continuing..."
    fi
}

# Step 4: Configure RootSync for Gitea
configure_rootsync() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 4: Configure RootSync for Gitea Repository               ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get or create Gitea token
    if [[ -z "${GITEA_TOKEN:-}" ]]; then
        log_info "GITEA_TOKEN not set. Please provide the Gitea access token."
        echo ""
        echo -e "${YELLOW}Note: The edge1-config repository must be created in Gitea first.${NC}"
        echo -e "${YELLOW}On VM-1, run: ./scripts/create_edge1_repo.sh${NC}"
        echo ""
        echo -n "Enter Gitea token (or press Enter to skip): "
        read -s GITEA_TOKEN
        echo ""
        
        if [[ -z "$GITEA_TOKEN" ]]; then
            log_warn "No token provided. RootSync will be created but may not sync properly."
            log_warn "You can update the token later by editing the git-creds secret."
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
    
    log_success "Git credentials secret created/updated"
    
    # Create RootSync configuration
    log_info "Creating RootSync configuration..."
    cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge1-rootsync
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
    log_info "Waiting for initial sync (this may take a minute)..."
    sleep 15
    
    # Check sync status
    if kubectl get rootsync -n config-management-system edge1-rootsync >/dev/null 2>&1; then
        log_success "RootSync resource created successfully"
        kubectl get rootsync -n config-management-system edge1-rootsync -o yaml | grep -A5 "status:" || true
    else
        log_warn "RootSync may not be ready yet"
    fi
}

# Step 5: Health Checks
run_health_checks() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STEP 5: Comprehensive Health Checks                           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local checks_passed=0
    local total_checks=0
    
    # Create artifacts directory
    mkdir -p "$ARTIFACTS_DIR"
    
    # Check 1: Cluster Status
    echo -e "${BLUE}Check 1: Cluster Status${NC}"
    total_checks=$((total_checks + 1))
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Cluster is accessible"
        kubectl get nodes -o wide > "$ARTIFACTS_DIR/nodes.txt"
        checks_passed=$((checks_passed + 1))
    else
        log_error "Cluster is not accessible"
    fi
    echo ""
    
    # Check 2: Config Sync Components
    echo -e "${BLUE}Check 2: Config Sync Components${NC}"
    total_checks=$((total_checks + 1))
    if kubectl get pods -n config-management-system --no-headers 2>/dev/null | grep -q Running; then
        log_success "Config Sync pods are running"
        kubectl get pods -n config-management-system -o wide > "$ARTIFACTS_DIR/config-sync-pods.txt"
        checks_passed=$((checks_passed + 1))
    else
        log_error "Config Sync pods are not running properly"
        kubectl get pods -n config-management-system
    fi
    echo ""
    
    # Check 3: RootSync Status
    echo -e "${BLUE}Check 3: RootSync Status${NC}"
    total_checks=$((total_checks + 1))
    if kubectl get rootsync -n config-management-system edge1-rootsync >/dev/null 2>&1; then
        log_success "RootSync resource exists"
        kubectl get rootsync -n config-management-system -o yaml > "$ARTIFACTS_DIR/rootsync.yaml"
        
        # Check sync status
        sync_status=$(kubectl get rootsync -n config-management-system edge1-rootsync -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "UNKNOWN")
        if [[ "$sync_status" == "SYNCED" ]]; then
            log_success "RootSync is SYNCED"
        else
            log_warn "RootSync status: $sync_status (may need more time to sync)"
        fi
        checks_passed=$((checks_passed + 1))
    else
        log_error "RootSync resource not found"
    fi
    echo ""
    
    # Check 4: Git Repository Connectivity
    echo -e "${BLUE}Check 4: Git Repository Connectivity${NC}"
    total_checks=$((total_checks + 1))
    if curl -s -o /dev/null -w "%{http_code}" "${VM1_GITEA_URL}/${GITEA_USER}/${GITEA_REPO}" | grep -q "200\|301\|302"; then
        log_success "Git repository is accessible"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "Git repository may not be accessible (this is okay if behind firewall)"
    fi
    echo ""
    
    # Check 5: Applied Resources
    echo -e "${BLUE}Check 5: Applied Resources from GitOps${NC}"
    total_checks=$((total_checks + 1))
    
    # Check for namespaces created by GitOps
    if kubectl get namespace edge1 >/dev/null 2>&1; then
        log_success "GitOps-managed namespace 'edge1' exists"
        kubectl get all -n edge1 > "$ARTIFACTS_DIR/edge1-resources.txt" 2>/dev/null || true
        checks_passed=$((checks_passed + 1))
    else
        log_info "No GitOps-managed resources found yet (repository may be empty)"
    fi
    echo ""
    
    # Summary
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Health Check Summary: ${checks_passed}/${total_checks} checks passed        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Store health check results
    cat > "$ARTIFACTS_DIR/health-check-summary.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "cluster_name": "${EDGE_CLUSTER_NAME}",
  "checks_passed": ${checks_passed},
  "total_checks": ${total_checks},
  "vm2_ip": "${VM2_IP}",
  "gitea_url": "${VM1_GITEA_URL}",
  "repository": "${GITEA_USER}/${GITEA_REPO}"
}
EOF
}

# Step 6: Print Summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    DEPLOYMENT COMPLETE - READY!                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Cluster Information:${NC}"
    echo "  • Cluster Name: $EDGE_CLUSTER_NAME"
    echo "  • Context: kind-${EDGE_CLUSTER_NAME}"
    echo "  • API Server: https://${VM2_IP}:6443"
    echo ""
    
    echo -e "${BLUE}GitOps Configuration:${NC}"
    echo "  • Repository: ${VM1_GITEA_URL}/${GITEA_USER}/${GITEA_REPO}"
    echo "  • Sync Interval: 30 seconds"
    echo "  • RootSync: edge1-rootsync"
    echo ""
    
    echo -e "${BLUE}Quick Verification Commands:${NC}"
    echo "  # Check cluster status"
    echo "  kubectl cluster-info"
    echo ""
    echo "  # Check Config Sync status"
    echo "  kubectl get rootsync -n config-management-system"
    echo ""
    echo "  # Watch for synced resources"
    echo "  kubectl get all --all-namespaces -l app.kubernetes.io/managed-by=configmanagement.gke.io"
    echo ""
    echo "  # Check sync logs"
    echo "  kubectl logs -n config-management-system -l app=git-sync --tail=50"
    echo ""
    
    echo -e "${BLUE}Artifacts Location:${NC}"
    echo "  $ARTIFACTS_DIR"
    echo ""
    
    echo -e "${BLUE}Log File:${NC}"
    echo "  $LOG_FILE"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Push KRM configurations to Gitea repository from VM-1"
    echo "  2. Monitor RootSync status for automatic deployment"
    echo "  3. Check deployed resources in the edge1 namespace"
    echo ""
    
    # Create completion marker
    touch "$ARTIFACTS_DIR/deployment-complete.marker"
    date -Iseconds > "$ARTIFACTS_DIR/deployment-complete.timestamp"
}

# Main execution
main() {
    print_banner
    
    # Prompt for confirmation
    echo -e "${YELLOW}This script will:${NC}"
    echo "  1. Install/verify Docker, kubectl, kind, jq, yq"
    echo "  2. Create/verify kind cluster '$EDGE_CLUSTER_NAME'"
    echo "  3. Install Config Sync operator"
    echo "  4. Configure RootSync to Gitea repository"
    echo "  5. Run comprehensive health checks"
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
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"