#!/bin/bash

# Complete GitOps Deployment Script
# Orchestrates the full GitOps setup for Edge sites

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITEA_URL="${GITEA_URL:-http://172.16.0.78:8888}"
GITEA_USER="${GITEA_USER:-admin1}"
GITEA_TOKEN="${GITEA_TOKEN:-}"

# Edge site configurations
EDGE1_IP="172.16.4.45"
EDGE2_IP="172.16.4.176"
SSH_USER="ubuntu"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

step() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] STEP: $1${NC}"
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check required tools
    for tool in curl jq git ssh scp; do
        if ! command -v $tool &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done

    # Check Gitea token
    if [ -z "$GITEA_TOKEN" ]; then
        error "Gitea token is required. Set GITEA_TOKEN environment variable."
    fi

    # Check SSH connectivity to edge sites
    for site in edge1:$EDGE1_IP edge2:$EDGE2_IP; do
        IFS=':' read -r site_name site_ip <<< "$site"
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$site_ip" 'echo "SSH OK"' &> /dev/null; then
            error "Cannot SSH to $site_name ($site_ip). Check SSH keys and connectivity."
        fi
        info "SSH connectivity to $site_name ($site_ip) verified"
    done

    # Check Gitea connectivity
    if ! curl -sf "$GITEA_URL/api/v1/version" &> /dev/null; then
        error "Cannot connect to Gitea at $GITEA_URL"
    fi

    log "Prerequisites check passed"
}

setup_gitea_repositories() {
    step "Setting up Gitea repositories..."

    if ! "$SCRIPT_DIR/setup-gitea-repos.sh" -t "$GITEA_TOKEN" -u "$GITEA_URL" -U "$GITEA_USER"; then
        error "Failed to setup Gitea repositories"
    fi

    log "Gitea repositories setup completed"
}

deploy_to_edge_site() {
    local site_name="$1"
    local site_ip="$2"
    local repo_name="$3"

    step "Deploying Config Sync to $site_name ($site_ip)..."

    # Copy installation script to edge site
    info "Copying installation script to $site_name..."
    scp "$SCRIPT_DIR/install-config-sync.sh" "$SSH_USER@$site_ip:/tmp/"

    # Install Config Sync on edge site
    info "Installing Config Sync on $site_name..."
    ssh "$SSH_USER@$site_ip" "
        export GITEA_TOKEN='$GITEA_TOKEN'
        chmod +x /tmp/install-config-sync.sh
        /tmp/install-config-sync.sh '$site_name' '$GITEA_URL/$GITEA_USER' '$repo_name'
    " || error "Failed to install Config Sync on $site_name"

    log "Config Sync deployed to $site_name successfully"
}

verify_sync_status() {
    local site_name="$1"
    local site_ip="$2"

    step "Verifying sync status for $site_name..."

    # Copy monitoring script to edge site
    scp "$SCRIPT_DIR/monitor-sync-status.sh" "$SSH_USER@$site_ip:/tmp/"

    # Wait for sync to complete
    info "Waiting for $site_name sync to complete..."
    ssh "$SSH_USER@$site_ip" "
        chmod +x /tmp/monitor-sync-status.sh
        /tmp/monitor-sync-status.sh wait '$site_name' 600
    " || warn "Sync verification timed out for $site_name, but deployment may still succeed"

    # Get sync status
    info "Getting sync status for $site_name..."
    ssh "$SSH_USER@$site_ip" "
        /tmp/monitor-sync-status.sh status '$site_name' --detailed
    " || warn "Could not get detailed status for $site_name"

    log "Sync verification completed for $site_name"
}

test_demo_application() {
    local site_name="$1"
    local site_ip="$2"

    step "Testing demo application on $site_name..."

    # Check if sample app is deployed
    info "Checking sample application deployment..."
    ssh "$SSH_USER@$site_ip" "
        kubectl get deployment sample-app -n ${site_name}-workloads || true
        kubectl get service sample-app-service -n ${site_name}-workloads || true
        kubectl get pods -n ${site_name}-workloads -l app=sample-app || true
    " || warn "Could not check sample application on $site_name"

    log "Demo application test completed for $site_name"
}

create_test_deployment() {
    step "Creating test deployment to verify GitOps workflow..."

    local test_app_name="gitops-test-$(date +%s)"
    local work_dir="/tmp/gitops-test"

    # Clean up and create work directory
    rm -rf "$work_dir"
    mkdir -p "$work_dir"

    # Clone edge1-config repo
    git clone "$GITEA_URL/$GITEA_USER/edge1-config.git" "$work_dir/edge1-config"
    cd "$work_dir/edge1-config"

    # Create test application
    mkdir -p "apps/$test_app_name"
    cat > "apps/$test_app_name/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $test_app_name
  namespace: edge1-workloads
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $test_app_name
  template:
    metadata:
      labels:
        app: $test_app_name
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: $test_app_name-service
  namespace: edge1-workloads
spec:
  selector:
    app: $test_app_name
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    cat > "apps/$test_app_name/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

commonLabels:
  app: $test_app_name
  test: gitops-workflow
EOF

    # Update apps kustomization
    if ! grep -q "$test_app_name/" apps/kustomization.yaml; then
        cat >> apps/kustomization.yaml <<EOF
- $test_app_name/
EOF
    fi

    # Commit and push
    git config user.name "GitOps Test"
    git config user.email "test@nephio.local"
    git add .
    git commit -m "test: Add GitOps workflow test application $test_app_name"
    git push origin main

    log "Test deployment created and pushed to GitOps repository"

    # Clean up
    rm -rf "$work_dir"

    # Wait for sync and verify
    info "Waiting for test application to be synced..."
    sleep 60

    # Verify on edge1
    ssh "$SSH_USER@$EDGE1_IP" "
        kubectl get deployment $test_app_name -n edge1-workloads
        kubectl get pods -n edge1-workloads -l app=$test_app_name
    " || warn "Test application verification failed"

    log "GitOps workflow test completed"
}

generate_report() {
    step "Generating deployment report..."

    local report_file="/tmp/gitops-deployment-report-$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" <<EOF
GitOps Deployment Report
Generated: $(date)

== Configuration ==
Gitea URL: $GITEA_URL
Gitea User: $GITEA_USER
Edge1 IP: $EDGE1_IP
Edge2 IP: $EDGE2_IP

== Repositories ==
Edge1 Config: $GITEA_URL/$GITEA_USER/edge1-config
Edge2 Config: $GITEA_URL/$GITEA_USER/edge2-config

== Deployment Status ==
EOF

    # Check repositories
    for repo in edge1-config edge2-config; do
        local status
        if curl -sf "$GITEA_URL/api/v1/repos/$GITEA_USER/$repo" &> /dev/null; then
            status="✅ Available"
        else
            status="❌ Not found"
        fi
        echo "$repo: $status" >> "$report_file"
    done

    # Check edge sites
    for site in edge1:$EDGE1_IP edge2:$EDGE2_IP; do
        IFS=':' read -r site_name site_ip <<< "$site"
        echo "" >> "$report_file"
        echo "== $site_name ($site_ip) Status ==" >> "$report_file"

        if ssh "$SSH_USER@$site_ip" 'kubectl get rootsync -n config-management-system' &>> "$report_file"; then
            echo "Config Sync: ✅ Installed" >> "$report_file"
        else
            echo "Config Sync: ❌ Not found" >> "$report_file"
        fi

        # Get resource counts
        local ns_count
        ns_count=$(ssh "$SSH_USER@$site_ip" "kubectl get namespaces -l site=$site_name --no-headers | wc -l" 2>/dev/null || echo "0")
        echo "Namespaces: $ns_count" >> "$report_file"

        local deploy_count
        deploy_count=$(ssh "$SSH_USER@$site_ip" "kubectl get deployments -A -l site=$site_name --no-headers | wc -l" 2>/dev/null || echo "0")
        echo "Deployments: $deploy_count" >> "$report_file"
    done

    echo "" >> "$report_file"
    echo "== Next Steps ==" >> "$report_file"
    echo "1. Monitor sync status: ./monitor-sync-status.sh all" >> "$report_file"
    echo "2. Add applications to repositories and push changes" >> "$report_file"
    echo "3. Verify automatic synchronization" >> "$report_file"

    info "Report generated: $report_file"
    cat "$report_file"
}

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Deploy complete GitOps setup for edge sites

Options:
  -h, --help          Show this help message
  -t, --token TOKEN   Gitea access token (required)
  -u, --gitea-url URL Gitea base URL (default: $GITEA_URL)
  -U, --user USER     Gitea username (default: $GITEA_USER)
  --edge1-ip IP       Edge1 IP address (default: $EDGE1_IP)
  --edge2-ip IP       Edge2 IP address (default: $EDGE2_IP)
  --ssh-user USER     SSH username (default: $SSH_USER)
  --skip-test         Skip workflow test deployment
  --report-only       Only generate report, skip deployment

Environment Variables:
  GITEA_TOKEN         Gitea access token (required)
  GITEA_URL          Gitea base URL
  GITEA_USER         Gitea username
  SSH_KEY_PATH       SSH private key path

Examples:
  GITEA_TOKEN=your_token $0
  $0 -t your_token --edge1-ip 192.168.1.10
EOF
}

main() {
    local skip_test=false
    local report_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--token)
                GITEA_TOKEN="$2"
                shift 2
                ;;
            -u|--gitea-url)
                GITEA_URL="$2"
                shift 2
                ;;
            -U|--user)
                GITEA_USER="$2"
                shift 2
                ;;
            --edge1-ip)
                EDGE1_IP="$2"
                shift 2
                ;;
            --edge2-ip)
                EDGE2_IP="$2"
                shift 2
                ;;
            --ssh-user)
                SSH_USER="$2"
                shift 2
                ;;
            --skip-test)
                skip_test=true
                shift
                ;;
            --report-only)
                report_only=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                error "Unexpected argument: $1"
                ;;
        esac
    done

    echo ""
    echo "🚀 Starting Complete GitOps Deployment"
    echo "======================================"
    echo "Gitea URL: $GITEA_URL"
    echo "Edge1: $EDGE1_IP"
    echo "Edge2: $EDGE2_IP"
    echo ""

    if [ "$report_only" = "true" ]; then
        generate_report
        exit 0
    fi

    check_prerequisites

    # Step 1: Setup Gitea repositories
    setup_gitea_repositories

    # Step 2: Deploy to Edge1
    deploy_to_edge_site "edge1" "$EDGE1_IP" "edge1-config"

    # Step 3: Deploy to Edge2
    deploy_to_edge_site "edge2" "$EDGE2_IP" "edge2-config"

    # Step 4: Verify sync status
    verify_sync_status "edge1" "$EDGE1_IP"
    verify_sync_status "edge2" "$EDGE2_IP"

    # Step 5: Test demo applications
    test_demo_application "edge1" "$EDGE1_IP"
    test_demo_application "edge2" "$EDGE2_IP"

    # Step 6: Test GitOps workflow (optional)
    if [ "$skip_test" = "false" ]; then
        create_test_deployment
    fi

    # Step 7: Generate report
    generate_report

    echo ""
    log "🎉 GitOps deployment completed successfully!"
    echo ""
    info "Access your GitOps repositories:"
    echo "  Edge1: $GITEA_URL/$GITEA_USER/edge1-config"
    echo "  Edge2: $GITEA_URL/$GITEA_USER/edge2-config"
    echo ""
    info "Monitor sync status:"
    echo "  ./monitor-sync-status.sh all"
    echo ""
    info "Test workflow:"
    echo "  1. Make changes to repository files"
    echo "  2. Commit and push to main branch"
    echo "  3. Observe automatic synchronization"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi