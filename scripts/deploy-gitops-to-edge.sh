#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VM1_IP="172.16.0.78"
VM2_IP="172.16.4.45"
VM4_IP="172.16.4.176"
GITEA_NODEPORT="30924"
GITEA_USER="${GITEA_USER:-gitea_admin}"
GITEA_PASS="${GITEA_PASS:-r8sA8CPHD9!bt6d}"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Deploy GitOps Configuration to Edge Clusters${NC}"
echo -e "${BLUE}=========================================${NC}"

# Function to check prerequisites
check_prerequisites() {
    local cluster=$1
    local context=$2

    echo -e "\n${YELLOW}Checking prerequisites for $cluster...${NC}"

    # Check kubectl context
    if kubectl config get-contexts "$context" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} kubectl context exists: $context"
    else
        echo -e "  ${RED}✗${NC} kubectl context not found: $context"
        echo -e "  ${YELLOW}Run: kubectl config set-context $context --cluster=$cluster --user=$cluster-admin${NC}"
        return 1
    fi

    # Check cluster connectivity
    if kubectl --context="$context" cluster-info >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Cluster is reachable"
    else
        echo -e "  ${RED}✗${NC} Cannot reach cluster"
        return 1
    fi

    # Check if Config Sync is installed
    if kubectl --context="$context" get crd rootsyncs.configsync.gke.io >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Config Sync CRD found"
    else
        echo -e "  ${YELLOW}⚠${NC} Config Sync not installed"
        echo -e "  ${CYAN}Installing Config Sync...${NC}"

        # Install Config Sync operator
        kubectl --context="$context" apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/latest/download/config-sync-manifest.yaml

        # Wait for operator to be ready
        echo -n "  Waiting for Config Sync operator..."
        kubectl --context="$context" wait --for=condition=Available --timeout=300s \
            deployment/config-management-operator -n config-management-system >/dev/null 2>&1 || true
        echo -e " ${GREEN}Ready${NC}"
    fi

    # Check if namespace exists
    if kubectl --context="$context" get ns config-management-system >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} config-management-system namespace exists"
    else
        echo -e "  ${CYAN}Creating config-management-system namespace...${NC}"
        kubectl --context="$context" create ns config-management-system
    fi

    return 0
}

# Function to deploy credentials
deploy_credentials() {
    local cluster=$1
    local context=$2

    echo -e "\n${YELLOW}Deploying Gitea credentials to $cluster...${NC}"

    # Generate credentials if not exists
    if [ ! -f "./gitops/credentials/gitea-secret-token.yaml" ]; then
        echo -e "  ${CYAN}Generating credentials...${NC}"
        bash scripts/generate-gitea-credentials.sh
    fi

    # Apply credentials
    if [ -f "./gitops/credentials/gitea-secret-token.yaml" ]; then
        kubectl --context="$context" apply -f ./gitops/credentials/gitea-secret-token.yaml
        echo -e "  ${GREEN}✓${NC} Token-based credentials deployed"
    elif [ -f "./gitops/credentials/gitea-secret-password.yaml" ]; then
        kubectl --context="$context" apply -f ./gitops/credentials/gitea-secret-password.yaml
        echo -e "  ${GREEN}✓${NC} Password-based credentials deployed"
    else
        echo -e "  ${RED}✗${NC} No credentials file found"
        return 1
    fi
}

# Function to deploy RootSync
deploy_rootsync() {
    local cluster=$1
    local context=$2
    local site=$3

    echo -e "\n${YELLOW}Deploying RootSync configuration to $cluster...${NC}"

    # Check if Gitea repository exists
    echo -n "  Checking if Gitea repository exists... "
    REPO_URL="http://${VM1_IP}:${GITEA_NODEPORT}/admin1/${site}-config"
    if curl -s -o /dev/null -w "%{http_code}" "$REPO_URL" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}Not found${NC}"
        echo -e "  ${CYAN}Creating repository...${NC}"

        # Create repository via API
        if [ -n "${GITEA_TOKEN:-}" ]; then
            curl -s -X POST \
                -H "Authorization: token ${GITEA_TOKEN}" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"${site}-config\", \"private\": false, \"auto_init\": true}" \
                "${GITEA_URL}/api/v1/user/repos" >/dev/null 2>&1
        else
            curl -s -X POST \
                -u "${GITEA_USER}:${GITEA_PASS}" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"${site}-config\", \"private\": false, \"auto_init\": true}" \
                "http://${VM1_IP}:${GITEA_NODEPORT}/api/v1/user/repos" >/dev/null 2>&1
        fi
        echo -e "  ${GREEN}✓${NC} Repository created"
    fi

    # Apply RootSync configuration
    if [ -f "./gitops/${site}-config/rootsync-gitea.yaml" ]; then
        kubectl --context="$context" apply -f "./gitops/${site}-config/rootsync-gitea.yaml"
        echo -e "  ${GREEN}✓${NC} RootSync configuration deployed"
    else
        echo -e "  ${RED}✗${NC} RootSync configuration not found"
        return 1
    fi

    # Wait for sync to start
    echo -n "  Waiting for RootSync to initialize..."
    for i in {1..30}; do
        if kubectl --context="$context" get rootsync -n config-management-system "${site}-root-sync" >/dev/null 2>&1; then
            echo -e " ${GREEN}Ready${NC}"
            break
        fi
        sleep 2
    done
}

# Function to verify sync status
verify_sync() {
    local cluster=$1
    local context=$2
    local site=$3

    echo -e "\n${YELLOW}Verifying sync status for $cluster...${NC}"

    # Get RootSync status
    echo -e "  ${CYAN}RootSync Status:${NC}"
    kubectl --context="$context" get rootsync -n config-management-system 2>/dev/null || echo "    No RootSync found"

    # Check for sync errors
    echo -e "  ${CYAN}Checking for errors:${NC}"
    ERRORS=$(kubectl --context="$context" get rootsync -n config-management-system "${site}-root-sync" \
        -o jsonpath='{.status.conditions[?(@.type=="Syncing")].message}' 2>/dev/null || echo "")

    if [ -z "$ERRORS" ]; then
        echo -e "    ${GREEN}✓${NC} No sync errors"
    else
        echo -e "    ${RED}✗${NC} Sync errors: $ERRORS"
    fi

    # Check reconciler pods
    echo -e "  ${CYAN}Reconciler Pods:${NC}"
    kubectl --context="$context" get pods -n config-management-system -l app=reconciler 2>/dev/null || echo "    No reconciler pods found"

    # Test git connectivity from pod
    echo -e "  ${CYAN}Testing Git connectivity from pod:${NC}"
    POD=$(kubectl --context="$context" get pods -n config-management-system -l app=reconciler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$POD" ]; then
        REPO_URL="http://${VM1_IP}:${GITEA_NODEPORT}/admin1/${site}-config.git"
        if kubectl --context="$context" exec -n config-management-system "$POD" -- \
            git ls-remote "$REPO_URL" >/dev/null 2>&1; then
            echo -e "    ${GREEN}✓${NC} Git repository accessible from pod"
        else
            echo -e "    ${RED}✗${NC} Cannot access Git repository from pod"
            echo -e "    ${YELLOW}Troubleshooting: Check network policies and firewall rules${NC}"
        fi
    else
        echo -e "    ${YELLOW}⚠${NC} No reconciler pod found to test"
    fi
}

# Function to setup SSH tunnel (alternative method)
setup_ssh_tunnel() {
    local target_vm=$1
    local target_ip=$2

    echo -e "\n${YELLOW}Setting up SSH tunnel to $target_vm ($target_ip)...${NC}"

    # Kill existing tunnel
    pkill -f "ssh.*-L.*8888:172.18.0.2:${GITEA_NODEPORT}.*${target_ip}" 2>/dev/null || true

    # Create SSH tunnel
    ssh -f -N -L 8888:172.18.0.2:${GITEA_NODEPORT} ubuntu@${target_ip} 2>/dev/null

    if pgrep -f "ssh.*-L.*8888" >/dev/null; then
        echo -e "  ${GREEN}✓${NC} SSH tunnel established"
        echo -e "  ${CYAN}Gitea accessible at: http://localhost:8888${NC}"
    else
        echo -e "  ${RED}✗${NC} Failed to establish SSH tunnel"
    fi
}

# Main deployment flow
main() {
    echo -e "\n${CYAN}Select deployment target:${NC}"
    echo "1) Edge-1 (VM-2: $VM2_IP)"
    echo "2) Edge-2 (VM-4: $VM4_IP)"
    echo "3) Both Edge clusters"
    echo "4) Setup SSH tunnels only"
    echo "5) Verify existing deployments"
    echo ""
    read -p "Enter choice [1-5]: " CHOICE

    case $CHOICE in
        1)
            echo -e "\n${BLUE}Deploying to Edge-1${NC}"
            if check_prerequisites "edge1" "edge1-context"; then
                deploy_credentials "edge1" "edge1-context"
                deploy_rootsync "edge1" "edge1-context" "edge1"
                verify_sync "edge1" "edge1-context" "edge1"
            fi
            ;;
        2)
            echo -e "\n${BLUE}Deploying to Edge-2${NC}"
            if check_prerequisites "edge2" "edge2-context"; then
                deploy_credentials "edge2" "edge2-context"
                deploy_rootsync "edge2" "edge2-context" "edge2"
                verify_sync "edge2" "edge2-context" "edge2"
            fi
            ;;
        3)
            echo -e "\n${BLUE}Deploying to Both Edge Clusters${NC}"
            if check_prerequisites "edge1" "edge1-context"; then
                deploy_credentials "edge1" "edge1-context"
                deploy_rootsync "edge1" "edge1-context" "edge1"
                verify_sync "edge1" "edge1-context" "edge1"
            fi
            if check_prerequisites "edge2" "edge2-context"; then
                deploy_credentials "edge2" "edge2-context"
                deploy_rootsync "edge2" "edge2-context" "edge2"
                verify_sync "edge2" "edge2-context" "edge2"
            fi
            ;;
        4)
            echo -e "\n${BLUE}Setting up SSH Tunnels${NC}"
            setup_ssh_tunnel "VM-2" "$VM2_IP"
            setup_ssh_tunnel "VM-4" "$VM4_IP"
            ;;
        5)
            echo -e "\n${BLUE}Verifying Existing Deployments${NC}"
            verify_sync "edge1" "edge1-context" "edge1"
            verify_sync "edge2" "edge2-context" "edge2"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac

    echo -e "\n${BLUE}=========================================${NC}"
    echo -e "${BLUE}Deployment Summary${NC}"
    echo -e "${BLUE}=========================================${NC}"

    echo -e "\n${YELLOW}Quick Commands:${NC}"
    echo ""
    echo "# Check sync status:"
    echo "kubectl get rootsync -A"
    echo ""
    echo "# View sync logs:"
    echo "kubectl logs -n config-management-system -l app=reconciler"
    echo ""
    echo "# Test Gitea connectivity:"
    echo "curl http://${VM1_IP}:${GITEA_NODEPORT}/api/v1/version"
    echo ""
    echo "# Manual sync trigger:"
    echo "kubectl annotate rootsync -n config-management-system edge1-root-sync sync.gke.io/force-sync=\$(date +%s) --overwrite"
    echo ""

    echo -e "${GREEN}Deployment script completed!${NC}"
}

# Run main function
main "$@"