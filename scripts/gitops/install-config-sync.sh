#!/bin/bash

# Config Sync Installation Script for Edge Sites
# This script installs Google Cloud Config Sync on K3s clusters

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SYNC_VERSION="${CONFIG_SYNC_VERSION:-1.17.2}"
NAMESPACE="config-management-system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
    fi

    # Check if running as admin/root or have sufficient permissions
    if ! kubectl auth can-i create namespace &> /dev/null; then
        error "Insufficient permissions to create namespaces"
    fi

    log "Prerequisites check passed"
}

install_config_sync_operator() {
    log "Installing Config Sync operator..."

    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # Install Config Sync operator
    kubectl apply -f https://github.com/GoogleCloudPlatform/anthos-config-management/releases/download/v${CONFIG_SYNC_VERSION}/config-sync-operator.yaml

    # Wait for operator to be ready
    log "Waiting for Config Sync operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/config-management-operator -n $NAMESPACE

    log "Config Sync operator installed successfully"
}

create_gitea_secret() {
    local site_name="$1"
    local gitea_url="$2"
    local gitea_user="$3"
    local gitea_token="$4"

    log "Creating Gitea credentials secret for $site_name..."

    # Create secret for Gitea authentication
    kubectl create secret generic git-creds \
        --namespace=$NAMESPACE \
        --from-literal=username="$gitea_user" \
        --from-literal=password="$gitea_token" \
        --dry-run=client -o yaml | kubectl apply -f -

    log "Gitea credentials secret created"
}

install_rootsync() {
    local site_name="$1"
    local gitea_url="$2"
    local repo_name="$3"
    local sync_path="${4:-}"

    log "Installing RootSync for $site_name..."

    cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: ${site_name}-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${gitea_url}/${repo_name}.git
    branch: main
    dir: ${sync_path}
    auth: basic
    secretRef:
      name: git-creds
    noSSLVerify: true
  override:
    logLevel: 5
    reconcileTimeout: 60s
    statusMode: enabled
EOF

    log "RootSync for $site_name installed"
}

verify_installation() {
    local site_name="$1"

    log "Verifying Config Sync installation for $site_name..."

    # Check if RootSync is created
    if kubectl get rootsync ${site_name}-sync -n $NAMESPACE &> /dev/null; then
        log "RootSync ${site_name}-sync found"
    else
        error "RootSync ${site_name}-sync not found"
    fi

    # Wait for sync to be ready
    log "Waiting for sync to be ready (this may take a few minutes)..."
    timeout 300 bash -c "
        while true; do
            if kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type==\"Synced\")].status}' | grep -q True; then
                break
            fi
            echo 'Waiting for sync to complete...'
            sleep 10
        done
    " || warn "Sync status check timed out, but installation may still succeed"

    # Show sync status
    log "Current sync status:"
    kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o yaml | grep -A 10 "status:" || true

    log "Config Sync installation verification completed"
}

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] SITE_NAME GITEA_URL REPO_NAME

Install Google Cloud Config Sync on Kubernetes cluster

Arguments:
  SITE_NAME   Name of the site (e.g., edge1, edge2)
  GITEA_URL   Gitea base URL (e.g., http://172.16.0.78:8888/admin1)
  REPO_NAME   Repository name (e.g., edge1-config)

Options:
  -h, --help          Show this help message
  -p, --path PATH     Sync path within repository (default: /)
  -u, --user USER     Gitea username (default: admin1)
  -t, --token TOKEN   Gitea access token (required)
  -v, --version VER   Config Sync version (default: $CONFIG_SYNC_VERSION)

Examples:
  $0 edge1 http://172.16.0.78:8888/admin1 edge1-config -t your_token
  $0 edge2 http://172.16.0.78:8888/admin1 edge2-config -t your_token -p edge2/

Environment Variables:
  GITEA_TOKEN         Gitea access token (alternative to -t flag)
  CONFIG_SYNC_VERSION Config Sync version to install
EOF
}

main() {
    local site_name=""
    local gitea_url=""
    local repo_name=""
    local sync_path="/"
    local gitea_user="admin1"
    local gitea_token="${GITEA_TOKEN:-}"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--path)
                sync_path="$2"
                shift 2
                ;;
            -u|--user)
                gitea_user="$2"
                shift 2
                ;;
            -t|--token)
                gitea_token="$2"
                shift 2
                ;;
            -v|--version)
                CONFIG_SYNC_VERSION="$2"
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [ -z "$site_name" ]; then
                    site_name="$1"
                elif [ -z "$gitea_url" ]; then
                    gitea_url="$1"
                elif [ -z "$repo_name" ]; then
                    repo_name="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$site_name" ] || [ -z "$gitea_url" ] || [ -z "$repo_name" ]; then
        error "Missing required arguments. Use -h for help."
    fi

    if [ -z "$gitea_token" ]; then
        error "Gitea token is required. Use -t flag or set GITEA_TOKEN environment variable."
    fi

    log "Starting Config Sync installation for $site_name"
    log "Repository: $gitea_url/$repo_name.git"
    log "Sync path: $sync_path"

    check_prerequisites
    install_config_sync_operator
    create_gitea_secret "$site_name" "$gitea_url" "$gitea_user" "$gitea_token"
    install_rootsync "$site_name" "$gitea_url" "$repo_name" "$sync_path"
    verify_installation "$site_name"

    log "✅ Config Sync installation completed successfully for $site_name"
    log ""
    log "Next steps:"
    log "1. Verify sync status: kubectl get rootsync ${site_name}-sync -n $NAMESPACE"
    log "2. Check logs: kubectl logs -n $NAMESPACE -l app=root-reconciler"
    log "3. Monitor sync: kubectl describe rootsync ${site_name}-sync -n $NAMESPACE"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi