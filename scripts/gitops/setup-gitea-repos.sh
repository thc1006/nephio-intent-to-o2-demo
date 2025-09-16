#!/bin/bash

# Gitea Repository Setup Script for GitOps
# Creates and initializes GitOps repositories in Gitea

set -euo pipefail

# Configuration
GITEA_URL="${GITEA_URL:-http://172.16.0.78:8888}"
GITEA_USER="${GITEA_USER:-admin1}"
GITEA_TOKEN="${GITEA_TOKEN:-}"
WORK_DIR="/tmp/gitops-setup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if required tools are available
    for tool in curl jq git; do
        if ! command -v $tool &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done

    # Check if Gitea token is provided
    if [ -z "$GITEA_TOKEN" ]; then
        error "Gitea token is required. Set GITEA_TOKEN environment variable."
    fi

    # Test Gitea connectivity
    if ! curl -sf "$GITEA_URL/api/v1/version" &> /dev/null; then
        error "Cannot connect to Gitea at $GITEA_URL"
    fi

    log "Prerequisites check passed"
}

create_repository() {
    local repo_name="$1"
    local description="$2"

    log "Creating repository: $repo_name"

    local response
    response=$(curl -s -w "%{http_code}" -X POST "$GITEA_URL/api/v1/user/repos" \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$repo_name\",
            \"description\": \"$description\",
            \"private\": false,
            \"auto_init\": true,
            \"default_branch\": \"main\"
        }")

    local http_code="${response: -3}"
    local body="${response%???}"

    case $http_code in
        201)
            log "Repository $repo_name created successfully"
            ;;
        409)
            warn "Repository $repo_name already exists"
            ;;
        *)
            error "Failed to create repository $repo_name (HTTP $http_code): $body"
            ;;
    esac
}

clone_and_setup_repo() {
    local repo_name="$1"
    local site_name="$2"

    log "Setting up repository structure for $repo_name"

    local repo_dir="$WORK_DIR/$repo_name"
    local repo_url="$GITEA_URL/$GITEA_USER/$repo_name.git"

    # Clean up existing directory
    rm -rf "$repo_dir"
    mkdir -p "$repo_dir"

    # Clone repository
    if ! git clone "$repo_url" "$repo_dir" 2>/dev/null; then
        error "Failed to clone repository $repo_url"
    fi

    cd "$repo_dir"

    # Configure git user (if not already configured)
    git config user.name "GitOps Automation" 2>/dev/null || true
    git config user.email "gitops@nephio.local" 2>/dev/null || true

    # Create basic directory structure
    mkdir -p {apps,infrastructure,monitoring,security}

    # Create namespace configuration
    cat > namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${site_name}-workloads
  labels:
    site: ${site_name}
    managed-by: gitops
    tier: workloads
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${site_name}-monitoring
  labels:
    site: ${site_name}
    managed-by: gitops
    tier: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${site_name}-security
  labels:
    site: ${site_name}
    managed-by: gitops
    tier: security
EOF

    # Create Kustomization file for the root
    cat > kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: ${site_name}-root
  annotations:
    config.kubernetes.io/local-config: "true"

resources:
- namespace.yaml
- apps/
- infrastructure/
- monitoring/
- security/

commonLabels:
  site: ${site_name}
  managed-by: gitops

patches:
- target:
    kind: Namespace
  patch: |-
    - op: add
      path: /metadata/labels/config.kubernetes.io~1sync-hash
      value: placeholder
EOF

    # Create apps directory with sample application
    mkdir -p apps/sample-app
    cat > apps/sample-app/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: ${site_name}-workloads
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app-service
  namespace: ${site_name}-workloads
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    cat > apps/sample-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

commonLabels:
  app: sample-app
  site: ${site_name}
EOF

    cat > apps/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- sample-app/
EOF

    # Create infrastructure directory
    cat > infrastructure/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Infrastructure components will be added here
# Examples: ingress controllers, service mesh, storage classes
EOF

    # Create monitoring directory
    cat > monitoring/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Monitoring components will be added here
# Examples: Prometheus, Grafana, alerting rules
EOF

    # Create security directory
    cat > security/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Security components will be added here
# Examples: Network policies, pod security policies, RBAC
EOF

    # Create README
    cat > README.md <<EOF
# ${repo_name^} GitOps Configuration

This repository contains the GitOps configuration for the ${site_name} site.

## Structure

- \`namespace.yaml\`: Site namespaces
- \`apps/\`: Application deployments
- \`infrastructure/\`: Infrastructure components
- \`monitoring/\`: Monitoring and observability
- \`security/\`: Security policies and configurations

## Sync Information

- **Site**: ${site_name}
- **Sync Tool**: Google Cloud Config Sync
- **Branch**: main
- **Sync Path**: /

## Usage

This repository is automatically synchronized to the ${site_name} Kubernetes cluster using Config Sync.
Changes pushed to the main branch will be automatically applied to the cluster.

## Validation

All manifests should be validated before committing:

\`\`\`bash
kubectl apply --dry-run=client -f .
\`\`\`
EOF

    # Commit and push changes
    git add .
    if git diff --staged --quiet; then
        info "No changes to commit for $repo_name"
    else
        git commit -m "feat: Initialize ${site_name} GitOps repository structure

- Add namespace definitions for workloads, monitoring, and security
- Create directory structure for apps, infrastructure, monitoring, security
- Add sample application deployment
- Include Kustomization files for proper structure
- Add README with usage instructions"

        if git push origin main; then
            log "Changes pushed to $repo_name successfully"
        else
            error "Failed to push changes to $repo_name"
        fi
    fi

    log "Repository $repo_name setup completed"
}

setup_gitops_repositories() {
    log "Setting up GitOps repositories..."

    # Clean up work directory
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"

    # Create repositories
    create_repository "edge1-config" "GitOps configuration for Edge1 cluster"
    create_repository "edge2-config" "GitOps configuration for Edge2 cluster"

    # Setup repository structures
    clone_and_setup_repo "edge1-config" "edge1"
    clone_and_setup_repo "edge2-config" "edge2"

    # Clean up
    rm -rf "$WORK_DIR"

    log "✅ GitOps repositories setup completed"
}

show_status() {
    log "GitOps Repository Status:"
    echo ""
    info "Edge1 Config: $GITEA_URL/$GITEA_USER/edge1-config"
    info "Edge2 Config: $GITEA_URL/$GITEA_USER/edge2-config"
    echo ""
    info "Next steps:"
    echo "1. Install Config Sync on Edge1: ssh ubuntu@172.16.4.45"
    echo "2. Install Config Sync on Edge2: ssh ubuntu@172.16.4.176"
    echo "3. Run: GITEA_TOKEN=\$TOKEN ./install-config-sync.sh edge1 $GITEA_URL/$GITEA_USER edge1-config"
    echo "4. Run: GITEA_TOKEN=\$TOKEN ./install-config-sync.sh edge2 $GITEA_URL/$GITEA_USER edge2-config"
}

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Setup GitOps repositories in Gitea for edge sites

Options:
  -h, --help          Show this help message
  -u, --url URL       Gitea base URL (default: $GITEA_URL)
  -U, --user USER     Gitea username (default: $GITEA_USER)
  -t, --token TOKEN   Gitea access token (required)

Environment Variables:
  GITEA_URL          Gitea base URL
  GITEA_USER         Gitea username
  GITEA_TOKEN        Gitea access token (required)

Examples:
  GITEA_TOKEN=your_token $0
  $0 -t your_token -u http://172.16.0.78:8888 -U admin1
EOF
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--url)
                GITEA_URL="$2"
                shift 2
                ;;
            -U|--user)
                GITEA_USER="$2"
                shift 2
                ;;
            -t|--token)
                GITEA_TOKEN="$2"
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                error "Unexpected argument: $1"
                ;;
        esac
    done

    log "Starting GitOps repository setup"
    log "Gitea URL: $GITEA_URL"
    log "Gitea User: $GITEA_USER"

    check_prerequisites
    setup_gitops_repositories
    show_status
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi