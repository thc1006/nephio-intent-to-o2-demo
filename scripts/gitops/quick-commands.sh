#!/bin/bash

# GitOps Quick Commands Reference
# Provides easy access to common GitOps operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_status() {
    echo -e "${BLUE}=== GitOps Status ===${NC}"
    echo ""
    echo "📍 Gitea Repository: http://172.18.0.2:30924/admin1/edge2-config"
    echo "🖥️  Edge-1: 172.16.4.45 (edge-control-plane)"
    echo "🖥️  Edge-2: 172.16.4.176 (edge2-control-plane)"
    echo ""
    echo -e "${GREEN}✅ Applications Running:${NC}"
    echo "  - Edge-1: nginx demo app on port 30080"
    echo "  - Edge-2: nginx demo app on port 30080"
    echo "  - Edge-2: O2IMS service on port 31280"
    echo "  - Edge-2: SLO services (dynamic, exporter)"
    echo ""
}

check_clusters() {
    echo -e "${BLUE}=== Cluster Status ===${NC}"
    echo ""
    echo "Edge-1 (172.16.4.45):"
    ssh ubuntu@172.16.4.45 'export KUBECONFIG=~/.kubeconfig && kubectl get nodes && echo "Workloads:" && kubectl get pods -n edge1-workloads'
    echo ""
    echo "Edge-2 (172.16.4.176):"
    ssh ubuntu@172.16.4.176 'export KUBECONFIG=~/.kubeconfig && kubectl get nodes && echo "Workloads:" && kubectl get pods -n edge2-workloads'
}

check_services() {
    echo -e "${BLUE}=== Service Status ===${NC}"
    echo ""
    echo "Edge-1 Services:"
    ssh ubuntu@172.16.4.45 'export KUBECONFIG=~/.kubeconfig && kubectl get services -n edge1-workloads'
    echo ""
    echo "Edge-2 Services:"
    ssh ubuntu@172.16.4.176 'export KUBECONFIG=~/.kubeconfig && kubectl get services -n edge2-workloads'
}

test_o2ims() {
    echo -e "${BLUE}=== Testing O2IMS Service ===${NC}"
    echo ""
    echo "O2IMS Health Check:"
    curl -s -m 10 http://172.16.4.176:31280/health || echo "Service not accessible"
    echo ""
    echo "O2IMS Endpoints:"
    curl -s -m 10 http://172.16.4.176:31280/ || echo "Root endpoint not accessible"
}

clone_repo() {
    echo -e "${BLUE}=== Cloning GitOps Repository ===${NC}"
    echo ""
    local work_dir="/tmp/gitops-work-$(date +%s)"
    mkdir -p "$work_dir"
    cd "$work_dir"

    if git clone http://172.18.0.2:30924/admin1/edge2-config.git; then
        echo -e "${GREEN}✅ Repository cloned to: $work_dir/edge2-config${NC}"
        echo ""
        echo "Available files:"
        ls -la edge2-config/
        echo ""
        echo "To make changes:"
        echo "1. cd $work_dir/edge2-config"
        echo "2. Edit files as needed"
        echo "3. git add . && git commit -m 'Your changes' && git push"
        echo "4. Apply manually: kubectl apply -f updated-files.yaml"
    else
        echo "Failed to clone repository"
    fi
}

deploy_test_app() {
    echo -e "${BLUE}=== Deploying Test Application ===${NC}"
    echo ""

    local app_name="test-app-$(date +%s)"
    local site="${1:-edge1}"
    local target_ip

    case $site in
        edge1) target_ip="172.16.4.45" ;;
        edge2) target_ip="172.16.4.176" ;;
        *) echo "Invalid site. Use 'edge1' or 'edge2'"; return 1 ;;
    esac

    echo "Deploying $app_name to $site..."

    ssh "ubuntu@$target_ip" "
        export KUBECONFIG=~/.kubeconfig
        cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
  namespace: ${site}-workloads
  labels:
    app: $app_name
    site: $site
    test: gitops-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app_name
  template:
    metadata:
      labels:
        app: $app_name
        site: $site
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: TEST_APP
          value: '$app_name'
        - name: SITE
          value: '$site'
EOF
        echo 'Deployment created. Checking status...'
        kubectl get pods -n ${site}-workloads -l app=$app_name
    "

    echo -e "${GREEN}✅ Test app deployed: $app_name${NC}"
}

show_logs() {
    local site="${1:-edge1}"
    local app="${2:-demo-app}"
    local target_ip

    case $site in
        edge1) target_ip="172.16.4.45" ;;
        edge2) target_ip="172.16.4.176" ;;
        *) echo "Invalid site. Use 'edge1' or 'edge2'"; return 1 ;;
    esac

    echo -e "${BLUE}=== Logs for $site-$app ===${NC}"
    ssh "ubuntu@$target_ip" "
        export KUBECONFIG=~/.kubeconfig
        kubectl logs -n ${site}-workloads deployment/${site}-${app} --tail=20
    "
}

run_validation() {
    echo -e "${BLUE}=== Running Full Validation ===${NC}"
    "$SCRIPT_DIR/validate-deployments.sh" "$@"
}

show_help() {
    cat <<EOF
GitOps Quick Commands

Usage: $0 COMMAND [OPTIONS]

Commands:
  status          Show GitOps infrastructure status
  clusters        Check Kubernetes cluster status
  services        Show service status across sites
  o2ims          Test O2IMS service on Edge-2
  clone          Clone GitOps repository for editing
  deploy SITE     Deploy test application (edge1 or edge2)
  logs SITE APP   Show application logs
  validate        Run full validation suite
  help            Show this help message

Examples:
  $0 status                    # Show overall status
  $0 clusters                  # Check cluster health
  $0 deploy edge1             # Deploy test app to Edge-1
  $0 logs edge2 demo-app      # Show Edge-2 demo app logs
  $0 validate --summary       # Quick validation summary

Quick Reference:
  Gitea:   http://172.18.0.2:30924/admin1/edge2-config
  Edge-1:  ssh ubuntu@172.16.4.45
  Edge-2:  ssh ubuntu@172.16.4.176
  O2IMS:   http://172.16.4.176:31280/health
EOF
}

main() {
    case "${1:-help}" in
        status) show_status ;;
        clusters) check_clusters ;;
        services) check_services ;;
        o2ims) test_o2ims ;;
        clone) clone_repo ;;
        deploy) deploy_test_app "${2:-edge1}" ;;
        logs) show_logs "${2:-edge1}" "${3:-demo-app}" ;;
        validate) shift; run_validation "$@" ;;
        help|*) show_help ;;
    esac
}

main "$@"