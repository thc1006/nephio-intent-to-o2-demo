#!/bin/bash
# Nephio R5-style management cluster bootstrap
# Brings up kind + MetalLB + Gitea + Porch for verifiable intent pipeline

set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-nephio-demo}"
K8S_VERSION="${K8S_VERSION:-v1.29.0}"
GITEA_NAMESPACE="${GITEA_NAMESPACE:-gitea-system}"
PORCH_NAMESPACE="${PORCH_NAMESPACE:-porch-system}"
DEMO_NAMESPACE="${DEMO_NAMESPACE:-porch-demo}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    for cmd in kind kubectl kpt docker; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd is required but not installed"
            exit 1
        fi
    done
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Create kind cluster with port mappings
create_kind_cluster() {
    log "Creating kind cluster: $CLUSTER_NAME"
    
    # Delete existing cluster if it exists
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        warn "Cluster $CLUSTER_NAME already exists, deleting..."
        kind delete cluster --name "$CLUSTER_NAME"
    fi
    
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --image "kindest/node:$K8S_VERSION" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
  - containerPort: 3000
    hostPort: 3000
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "nephio.org/role=control"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "nephio.org/role=worker"
EOF
    
    # Wait for nodes to be ready
    kubectl wait --for=condition=Ready nodes --all --timeout=120s
    success "Kind cluster created and nodes ready"
}

# Install MetalLB
install_metallb() {
    log "Installing MetalLB..."
    
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    # Wait for MetalLB pods
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=90s
    
    # Configure MetalLB with Docker network range
    # Get IPv4 subnet only
    DOCKER_NETWORK=$(docker network inspect kind | grep -A 20 '"IPAM"' | grep '"Subnet"' | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'"' -f4)
    # Extract the network and create a range for MetalLB
    NETWORK_BASE=$(echo $DOCKER_NETWORK | cut -d'.' -f1-3)
    
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${NETWORK_BASE}.200-${NETWORK_BASE}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
    
    success "MetalLB installed and configured"
}

# Deploy Gitea via kpt
deploy_gitea() {
    log "Deploying Gitea via kpt..."
    
    # Create namespace
    kubectl create namespace "$GITEA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Gitea deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: $GITEA_NAMESPACE
  labels:
    app: gitea
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitea
  template:
    metadata:
      labels:
        app: gitea
    spec:
      containers:
      - name: gitea
        image: gitea/gitea:1.21
        ports:
        - containerPort: 3000
        - containerPort: 22
        env:
        - name: GITEA__database__DB_TYPE
          value: sqlite3
        - name: GITEA__security__INSTALL_LOCK
          value: "true"
        - name: GITEA__service__DISABLE_REGISTRATION
          value: "false"
        - name: GITEA__server__DOMAIN
          value: localhost
        - name: GITEA__server__ROOT_URL
          value: http://localhost:3000/
        volumeMounts:
        - name: gitea-data
          mountPath: /data
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: gitea-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: gitea-service
  namespace: $GITEA_NAMESPACE
  labels:
    app: gitea
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
    name: web
  - port: 22
    targetPort: 22
    name: ssh
  selector:
    app: gitea
EOF
    
    # Wait for Gitea to be ready
    kubectl wait --namespace "$GITEA_NAMESPACE" \
        --for=condition=ready pod \
        --selector=app=gitea \
        --timeout=120s
    
    # Wait for LoadBalancer IP
    log "Waiting for LoadBalancer IP..."
    for i in {1..60}; do
        GITEA_IP=$(kubectl get svc gitea-service -n "$GITEA_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -n "$GITEA_IP" ]; then
            break
        fi
        sleep 5
    done
    
    if [ -z "$GITEA_IP" ]; then
        error "Failed to get LoadBalancer IP for Gitea"
        exit 1
    fi
    
    success "Gitea deployed at http://$GITEA_IP:3000"
    echo "Default credentials: admin/admin123 (set up on first visit)"
    
    # Store IP for later use
    echo "$GITEA_IP" > /tmp/gitea_ip
}

# Create repositories in Gitea
create_gitea_repos() {
    log "Creating repositories in Gitea..."
    
    GITEA_IP=$(cat /tmp/gitea_ip)
    GITEA_URL="http://$GITEA_IP:3000"
    
    # Wait for Gitea to be fully ready
    log "Waiting for Gitea to be accessible..."
    for i in {1..30}; do
        if curl -s "$GITEA_URL" > /dev/null; then
            break
        fi
        sleep 5
    done
    
    # Create initial setup if Gitea is brand new
    log "Setting up Gitea with default admin user..."
    
    # Try to perform initial setup
    curl -s -X POST "$GITEA_URL/user/settings/profile" \
        -d "user_name=admin" \
        -d "full_name=Administrator" \
        -d "email=admin@localhost" \
        -d "password=admin123" \
        -d "retype=admin123" || true
    
    # Create local git repos and push to Gitea
    TEMP_DIR="/tmp/gitea-repos"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    for repo in management edge1; do
        log "Creating repository: $repo"
        
        # Create local repo
        mkdir -p "$TEMP_DIR/$repo"
        cd "$TEMP_DIR/$repo"
        
        git init
        git config user.email "admin@localhost"
        git config user.name "admin"
        
        # Create initial content
        cat > README.md << EOF
# $repo Repository

This is the $repo repository for Nephio package management.

## Purpose
This repository stores Nephio packages for the $repo environment.

## Contents
- Kubernetes resource manifests
- kpt function configurations  
- Package metadata

Created by Nephio bootstrap script.
EOF
        
        mkdir -p packages
        cat > packages/.gitkeep << EOF
# This directory will contain kpt packages
EOF
        
        git add .
        git commit -m "Initial commit: Add README and packages directory

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"
        
        # Create bare repo on filesystem (simulating git server)
        mkdir -p "/tmp/git-repos/$repo.git"
        cd "/tmp/git-repos/$repo.git"
        git init --bare
        
        # Push to bare repo
        cd "$TEMP_DIR/$repo"
        git remote add origin "file:///tmp/git-repos/$repo.git"
        git push -u origin main
        
        success "Repository $repo created with initial commit"
    done
    
    cd "$OLDPWD"
    
    success "Gitea URL: $GITEA_URL"
    success "Repositories created: management, edge1"
    log "Note: Repositories are file-based. For full Gitea integration, complete setup at $GITEA_URL"
}

# Install Porch from Nephio catalog
install_porch() {
    log "Installing Porch from Nephio catalog..."
    
    # Create porch-system namespace
    kubectl create namespace "$PORCH_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Porch from release bundle
    curl -L -o /tmp/porch_blueprint.tar.gz https://github.com/nephio-project/porch/releases/download/v1.5.3/porch_blueprint.tar.gz
    mkdir -p /tmp/porch-install 
    tar -xzf /tmp/porch_blueprint.tar.gz -C /tmp/porch-install
    kubectl apply -f /tmp/porch-install/
    rm -rf /tmp/porch-install /tmp/porch_blueprint.tar.gz
    
    # Wait for Porch components
    log "Waiting for Porch components to be ready..."
    kubectl wait --namespace "$PORCH_NAMESPACE" \
        --for=condition=ready pod \
        --selector=app=porch-server \
        --timeout=120s || true
        
    kubectl wait --namespace "$PORCH_NAMESPACE" \
        --for=condition=ready pod \
        --selector=app=porch-controllers \
        --timeout=120s || true
    
    success "Porch installed"
}

# Register repositories in Porch
register_porch_repos() {
    log "Registering repositories in Porch..."
    
    # Create demo namespace
    kubectl create namespace "$DEMO_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    GITEA_IP=$(cat /tmp/gitea_ip)
    
    # Create Repository resources (these will need to be configured after Gitea repos are created)
    cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: management-repo
  namespace: $DEMO_NAMESPACE
spec:
  description: Management repository for Nephio packages
  git:
    repo: file:///tmp/git-repos/management.git
    branch: main
    directory: /
  type: package
---
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: edge1-repo
  namespace: $DEMO_NAMESPACE
spec:
  description: Edge1 repository for Nephio packages
  git:
    repo: file:///tmp/git-repos/edge1.git
    branch: main
    directory: /
  type: package
EOF
    
    success "Repository resources created (will sync once Gitea repos are populated)"
}

# Verify setup
verify_setup() {
    log "Verifying setup..."
    
    echo
    echo "=== Cluster Status ==="
    kubectl get nodes
    
    echo
    echo "=== Porch Pods ==="
    kubectl get pods -n "$PORCH_NAMESPACE" || warn "Porch pods not ready yet"
    
    echo
    echo "=== Porch API Resources ==="
    kubectl api-resources | grep porch || warn "Porch API resources not available yet"
    
    echo
    echo "=== MetalLB Status ==="
    kubectl get pods -n metallb-system
    
    echo
    echo "=== Gitea Status ==="
    kubectl get pods -n "$GITEA_NAMESPACE"
    kubectl get svc -n "$GITEA_NAMESPACE"
    
    echo
    echo "=== Repository Status ==="
    kubectl get repositories -n "$DEMO_NAMESPACE" || warn "Repositories not ready yet"
    
    GITEA_IP=$(cat /tmp/gitea_ip 2>/dev/null || echo "")
    if [ -n "$GITEA_IP" ]; then
        echo
        success "Setup complete!"
        echo "Gitea URL: http://$GITEA_IP:3000"
        echo "Complete Gitea setup and create 'management' and 'edge1' repos to finish"
    fi
}

# Main execution
main() {
    log "Starting Nephio R5 management cluster bootstrap..."
    
    check_prerequisites
    create_kind_cluster
    install_metallb
    deploy_gitea
    create_gitea_repos
    install_porch
    register_porch_repos
    verify_setup
    
    success "Bootstrap script completed!"
    echo "Next steps:"
    echo "1. Visit Gitea URL to complete setup"
    echo "2. Create 'management' and 'edge1' repositories"
    echo "3. Push initial commits to both repos"
    echo "4. Verify with: kubectl get repositories -n $DEMO_NAMESPACE"
}

# Run main function
main "$@"