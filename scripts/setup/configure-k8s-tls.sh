#!/bin/bash
# Configure Kubernetes Clusters with TLS Certificates
# This script configures cert-manager and deploys certificates to K8s clusters

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CERT_DIR="${PROJECT_ROOT}/certs"
CONFIG_DIR="${PROJECT_ROOT}/configs/ssl"

# Network configuration
VM2_IP="172.16.4.45"
VM4_IP="172.16.4.176"
K8S_API_PORT="6443"

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $*${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $*${NC}"; }
error() { echo -e "${RED}[ERROR] $*${NC}"; exit 1; }
info() { echo -e "${BLUE}[INFO] $*${NC}"; }

# Check cluster connectivity
check_cluster_connectivity() {
    local cluster_name="$1"
    local cluster_ip="$2"
    
    log "Checking connectivity to ${cluster_name} (${cluster_ip})..."
    
    if nc -z -w 3 "${cluster_ip}" "${K8S_API_PORT}" 2>/dev/null; then
        log "✅ ${cluster_name} cluster is accessible"
        return 0
    else
        warn "⚠️ ${cluster_name} cluster is not accessible"
        return 1
    fi
}

# Install cert-manager on a cluster
install_cert_manager() {
    local cluster_name="$1"
    local cluster_ip="$2"
    local kubeconfig_args="--server=https://${cluster_ip}:${K8S_API_PORT} --insecure-skip-tls-verify"
    
    log "Installing cert-manager on ${cluster_name}..."
    
    # Create cert-manager namespace
    kubectl ${kubeconfig_args} create namespace cert-manager --dry-run=client -o yaml | \
        kubectl ${kubeconfig_args} apply -f -
    
    # Add cert-manager Helm repository and install
    # Since we can't use Helm directly, we'll use the static YAML install
    local cert_manager_version="v1.13.3"
    
    # Download and apply cert-manager
    if curl -s -L "https://github.com/cert-manager/cert-manager/releases/download/${cert_manager_version}/cert-manager.yaml" | \
        kubectl ${kubeconfig_args} apply -f -; then
        log "cert-manager installed on ${cluster_name}"
    else
        warn "Failed to install cert-manager on ${cluster_name}"
        return 1
    fi
    
    # Wait for cert-manager to be ready
    log "Waiting for cert-manager to be ready on ${cluster_name}..."
    kubectl ${kubeconfig_args} wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s || true
    kubectl ${kubeconfig_args} wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s || true
    kubectl ${kubeconfig_args} wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s || true
    
    log "cert-manager installation completed on ${cluster_name}"
}

# Deploy CA certificate to cluster
deploy_ca_certificate() {
    local cluster_name="$1"
    local cluster_ip="$2"
    local kubeconfig_args="--server=https://${cluster_ip}:${K8S_API_PORT} --insecure-skip-tls-verify"
    
    log "Deploying CA certificate to ${cluster_name}..."
    
    local ca_cert="${CERT_DIR}/nephio-ca.crt"
    local ca_key="${CERT_DIR}/nephio-ca.key"
    
    if [[ ! -f "${ca_cert}" ]] || [[ ! -f "${ca_key}" ]]; then
        error "CA certificate or key not found. Run setup-ssl-certificates.sh first."
    fi
    
    # Create secret with CA certificate
    kubectl ${kubeconfig_args} create secret tls ca-certificate \
        --cert="${ca_cert}" \
        --key="${ca_key}" \
        --namespace=cert-manager \
        --dry-run=client -o yaml | \
        kubectl ${kubeconfig_args} apply -f -
    
    log "CA certificate deployed to ${cluster_name}"
}

# Create cluster issuer
create_cluster_issuer() {
    local cluster_name="$1"
    local cluster_ip="$2"
    local kubeconfig_args="--server=https://${cluster_ip}:${K8S_API_PORT} --insecure-skip-tls-verify"
    
    log "Creating cluster issuer on ${cluster_name}..."
    
    # Create self-signed cluster issuer
    cat << EOF | kubectl ${kubeconfig_args} apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-root-cert
  namespace: cert-manager
spec:
  isCA: true
  commonName: ca-root
  secretName: ca-root-secret
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-cluster-issuer
spec:
  ca:
    secretName: ca-root-secret
EOF
    
    log "Cluster issuer created on ${cluster_name}"
}

# Create ingress certificate
create_ingress_certificate() {
    local cluster_name="$1"
    local cluster_ip="$2"
    local kubeconfig_args="--server=https://${cluster_ip}:${K8S_API_PORT} --insecure-skip-tls-verify"
    
    log "Creating ingress certificate for ${cluster_name}..."
    
    local cert_name="${cluster_name,,}-ingress-cert"
    local dns_name="${cluster_name,,}.nephio.local"
    
    cat << EOF | kubectl ${kubeconfig_args} apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${cert_name}
  namespace: default
spec:
  secretName: ${cert_name}-tls
  issuerRef:
    name: ca-cluster-issuer
    kind: ClusterIssuer
  commonName: ${dns_name}
  dnsNames:
  - ${dns_name}
  - localhost
  ipAddresses:
  - ${cluster_ip}
  - 127.0.0.1
EOF
    
    log "Ingress certificate created for ${cluster_name}"
}

# Deploy GitOps certificates
deploy_gitops_certificates() {
    local cluster_name="$1"
    local cluster_ip="$2"
    local kubeconfig_args="--server=https://${cluster_ip}:${K8S_API_PORT} --insecure-skip-tls-verify"
    
    log "Deploying GitOps certificates to ${cluster_name}..."
    
    # Create config-management-system namespace if it doesn't exist
    kubectl ${kubeconfig_args} create namespace config-management-system --dry-run=client -o yaml | \
        kubectl ${kubeconfig_args} apply -f -
    
    # Deploy Gitea CA certificate for GitOps
    local gitea_ca_cert="${CERT_DIR}/nephio-ca.crt"
    
    if [[ -f "${gitea_ca_cert}" ]]; then
        kubectl ${kubeconfig_args} create secret generic gitea-ca-cert \
            --from-file=ca.crt="${gitea_ca_cert}" \
            --namespace=config-management-system \
            --dry-run=client -o yaml | \
            kubectl ${kubeconfig_args} apply -f -
        
        log "Gitea CA certificate deployed to ${cluster_name}"
    else
        warn "Gitea CA certificate not found, skipping GitOps certificate deployment"
    fi
}

# Create updated GitOps configuration
create_gitops_https_config() {
    local cluster_name="$1"
    
    log "Creating HTTPS GitOps configuration for ${cluster_name}..."
    
    local config_file="${CONFIG_DIR}/${cluster_name,,}-rootsync-https.yaml"
    local repo_name="${cluster_name,,}-config"
    
    mkdir -p "$(dirname "${config_file}")"
    
    cat > "${config_file}" << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: ${cluster_name,,}-rootsync-https
  namespace: config-management-system
spec:
  git:
    repo: https://172.16.0.78:8443/admin1/${repo_name}
    branch: main
    auth: token
    secretRef:
      name: gitea-token-https
    caCertSecretRef:
      name: gitea-ca-cert
  override:
    logLevel: 2
    reconcileTimeout: 300s
    statusMode: enabled
EOF
    
    log "GitOps HTTPS configuration created: ${config_file}"
}

# Test certificate deployment
test_certificate_deployment() {
    local cluster_name="$1"
    local cluster_ip="$2"
    local kubeconfig_args="--server=https://${cluster_ip}:${K8S_API_PORT} --insecure-skip-tls-verify"
    
    log "Testing certificate deployment on ${cluster_name}..."
    
    # Check cert-manager pods
    if kubectl ${kubeconfig_args} get pods -n cert-manager --no-headers 2>/dev/null | grep -q Running; then
        log "✅ cert-manager pods are running on ${cluster_name}"
    else
        warn "⚠️ cert-manager pods not running on ${cluster_name}"
    fi
    
    # Check cluster issuers
    if kubectl ${kubeconfig_args} get clusterissuer 2>/dev/null | grep -q "True"; then
        log "✅ Cluster issuers are ready on ${cluster_name}"
    else
        warn "⚠️ Cluster issuers not ready on ${cluster_name}"
    fi
    
    # Check certificates
    if kubectl ${kubeconfig_args} get certificates -A 2>/dev/null | grep -q "True"; then
        log "✅ Certificates are ready on ${cluster_name}"
    else
        warn "⚠️ Certificates not ready on ${cluster_name}"
    fi
}

# Generate cluster management script
generate_cluster_management_script() {
    log "Generating cluster management script..."
    
    cat > "${PROJECT_ROOT}/scripts/manage-k8s-tls.sh" << 'EOF'
#!/bin/bash
# Kubernetes TLS Management Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/setup/configure-k8s-tls.sh"

show_usage() {
    echo "Usage: $0 [edge1|edge2|all] [install|status|test]"
    echo ""
    echo "Clusters:"
    echo "  edge1  - Configure Edge1 cluster (172.16.4.45)"
    echo "  edge2  - Configure Edge2 cluster (172.16.4.176)"
    echo "  all    - Configure both clusters"
    echo ""
    echo "Operations:"
    echo "  install - Install cert-manager and certificates"
    echo "  status  - Check certificate status"
    echo "  test    - Test certificate functionality"
    echo ""
    echo "Examples:"
    echo "  $0 edge1 install"
    echo "  $0 all status"
    echo "  $0 edge2 test"
}

if [[ $# -lt 2 ]]; then
    show_usage
    exit 1
fi

CLUSTER="$1"
OPERATION="$2"

case "${CLUSTER}" in
    "edge1")
        "${SETUP_SCRIPT}" edge1 "${OPERATION}"
        ;;
    "edge2")
        "${SETUP_SCRIPT}" edge2 "${OPERATION}"
        ;;
    "all")
        "${SETUP_SCRIPT}" edge1 "${OPERATION}"
        "${SETUP_SCRIPT}" edge2 "${OPERATION}"
        ;;
    *)
        echo "Error: Unknown cluster '${CLUSTER}'"
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x "${PROJECT_ROOT}/scripts/manage-k8s-tls.sh"
    log "Cluster management script created: ${PROJECT_ROOT}/scripts/manage-k8s-tls.sh"
}

# Main function
main() {
    local cluster_name="${1:-all}"
    local operation="${2:-install}"
    
    case "${cluster_name}" in
        "edge1")
            if check_cluster_connectivity "Edge1" "${VM2_IP}"; then
                case "${operation}" in
                    "install")
                        install_cert_manager "Edge1" "${VM2_IP}"
                        deploy_ca_certificate "Edge1" "${VM2_IP}"
                        create_cluster_issuer "Edge1" "${VM2_IP}"
                        create_ingress_certificate "Edge1" "${VM2_IP}"
                        deploy_gitops_certificates "Edge1" "${VM2_IP}"
                        create_gitops_https_config "Edge1"
                        ;;
                    "test")
                        test_certificate_deployment "Edge1" "${VM2_IP}"
                        ;;
                    "status")
                        kubectl --server="https://${VM2_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify \
                            get certificates,clusterissuers -A
                        ;;
                esac
            fi
            ;;
        "edge2")
            if check_cluster_connectivity "Edge2" "${VM4_IP}"; then
                case "${operation}" in
                    "install")
                        install_cert_manager "Edge2" "${VM4_IP}"
                        deploy_ca_certificate "Edge2" "${VM4_IP}"
                        create_cluster_issuer "Edge2" "${VM4_IP}"
                        create_ingress_certificate "Edge2" "${VM4_IP}"
                        deploy_gitops_certificates "Edge2" "${VM4_IP}"
                        create_gitops_https_config "Edge2"
                        ;;
                    "test")
                        test_certificate_deployment "Edge2" "${VM4_IP}"
                        ;;
                    "status")
                        kubectl --server="https://${VM4_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify \
                            get certificates,clusterissuers -A
                        ;;
                esac
            fi
            ;;
        "all")
            main "edge1" "${operation}"
            main "edge2" "${operation}"
            ;;
        "help"|"--help"|"-h")
            echo "Usage: $0 [edge1|edge2|all] [install|test|status]"
            echo ""
            echo "This script configures TLS certificates on Kubernetes clusters"
            echo ""
            echo "Examples:"
            echo "  $0 edge1 install  # Install cert-manager and certificates on Edge1"
            echo "  $0 all test       # Test certificate deployment on both clusters"
            echo "  $0 edge2 status   # Check certificate status on Edge2"
            ;;
        *)
            error "Unknown cluster: ${cluster_name}. Use 'edge1', 'edge2', 'all', or 'help'."
            ;;
    esac
    
    # Generate management script if this is the first run
    if [[ ! -f "${PROJECT_ROOT}/scripts/manage-k8s-tls.sh" ]]; then
        generate_cluster_management_script
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
