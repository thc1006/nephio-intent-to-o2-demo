#!/bin/bash
# SSL/TLS Certificate Setup Script for Nephio Intent-to-O2 Demo
# Version: 1.0.0
# Purpose: Configure SSL/TLS certificates for Gitea and Kubernetes API endpoints

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CERT_DIR="${PROJECT_ROOT}/certs"
CONFIG_DIR="${PROJECT_ROOT}/configs/ssl"

# Network configuration from AUTHORITATIVE_NETWORK_CONFIG.md
VM1_INTERNAL_IP="172.16.0.78"
VM2_IP="172.16.4.45"
VM4_IP="172.16.4.176"
GITEA_PORT="8888"
K8S_API_PORT="6443"

# Certificate configuration
CA_NAME="nephio-ca"
CA_KEY="${CERT_DIR}/${CA_NAME}.key"
CA_CERT="${CERT_DIR}/${CA_NAME}.crt"
VALIDITY_DAYS=365

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $*${NC}"
}

error() {
    echo -e "${RED}[ERROR] $*${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $*${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL is required but not installed"
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        warn "kubectl not found - K8s certificate management will be limited"
    fi
    
    # Check if docker is running (for Gitea)
    if ! docker ps &> /dev/null; then
        warn "Docker not accessible - Gitea certificate setup may fail"
    fi
    
    log "Prerequisites check completed"
}

# Create directory structure
setup_directories() {
    log "Setting up certificate directory structure..."
    
    mkdir -p "${CERT_DIR}/ca"
    mkdir -p "${CERT_DIR}/gitea"
    mkdir -p "${CERT_DIR}/k8s"
    mkdir -p "${CONFIG_DIR}"
    
    # Set appropriate permissions
    chmod 700 "${CERT_DIR}"
    chmod 755 "${CONFIG_DIR}"
    
    log "Directory structure created"
}

# Generate CA certificate
generate_ca_certificate() {
    log "Generating CA certificate..."
    
    if [[ -f "${CA_CERT}" ]]; then
        warn "CA certificate already exists, skipping generation"
        return 0
    fi
    
    # Generate CA private key
    openssl genrsa -out "${CA_KEY}" 4096
    
    # Generate CA certificate
    openssl req -new -x509 -days ${VALIDITY_DAYS} -key "${CA_KEY}" -out "${CA_CERT}" \
        -subj "/C=TW/ST=Taipei/L=Taipei/O=Nephio Demo/OU=IT Department/CN=Nephio CA"
    
    # Set permissions
    chmod 600 "${CA_KEY}"
    chmod 644 "${CA_CERT}"
    
    log "CA certificate generated successfully"
}

# Generate certificate for a specific service
generate_service_certificate() {
    local service_name="$1"
    local common_name="$2"
    local san_entries="$3"
    local output_dir="${CERT_DIR}/${service_name}"
    
    log "Generating certificate for ${service_name}..."
    
    mkdir -p "${output_dir}"
    
    local key_file="${output_dir}/${service_name}.key"
    local csr_file="${output_dir}/${service_name}.csr"
    local cert_file="${output_dir}/${service_name}.crt"
    local config_file="${output_dir}/${service_name}.conf"
    
    # Create OpenSSL config file
    cat > "${config_file}" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = TW
ST = Taipei
L = Taipei
O = Nephio Demo
OU = IT Department
CN = ${common_name}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
${san_entries}
EOF
    
    # Generate private key
    openssl genrsa -out "${key_file}" 2048
    
    # Generate certificate signing request
    openssl req -new -key "${key_file}" -out "${csr_file}" -config "${config_file}"
    
    # Generate certificate signed by CA
    openssl x509 -req -in "${csr_file}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
        -CAcreateserial -out "${cert_file}" -days ${VALIDITY_DAYS} \
        -extensions v3_req -extfile "${config_file}"
    
    # Set permissions
    chmod 600 "${key_file}"
    chmod 644 "${cert_file}"
    
    # Clean up CSR file
    rm -f "${csr_file}"
    
    log "Certificate for ${service_name} generated successfully"
}

# Generate Gitea certificate
generate_gitea_certificate() {
    log "Generating Gitea HTTPS certificate..."
    
    local san_entries="DNS.1 = gitea.local
DNS.2 = gitea.nephio.local
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = ${VM1_INTERNAL_IP}"
    
    generate_service_certificate "gitea" "gitea.nephio.local" "${san_entries}"
}

# Generate K8s API certificates
generate_k8s_certificates() {
    log "Generating Kubernetes API certificates..."
    
    # Edge1 (VM-2) certificate
    local edge1_san="DNS.1 = edge1.nephio.local
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = localhost
IP.1 = 127.0.0.1
IP.2 = ${VM2_IP}
IP.3 = 10.43.0.1"
    
    generate_service_certificate "k8s-edge1" "edge1.nephio.local" "${edge1_san}"
    
    # Edge2 (VM-4) certificate
    local edge2_san="DNS.1 = edge2.nephio.local
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = localhost
IP.1 = 127.0.0.1
IP.2 = ${VM4_IP}
IP.3 = 10.43.0.1"
    
    generate_service_certificate "k8s-edge2" "edge2.nephio.local" "${edge2_san}"
}

# Configure Gitea with HTTPS
configure_gitea_https() {
    log "Configuring Gitea for HTTPS..."
    
    local gitea_cert_dir="${CERT_DIR}/gitea"
    local gitea_config_dir="${CONFIG_DIR}/gitea"
    
    mkdir -p "${gitea_config_dir}"
    
    # Create Gitea app.ini configuration for HTTPS
    cat > "${gitea_config_dir}/app.ini" << EOF
[server]
PROTOCOL = https
HTTP_PORT = 3000
HTTPS_PORT = 3443
CERT_FILE = /data/gitea/cert/gitea.crt
KEY_FILE = /data/gitea/cert/gitea.key
DOMAIN = ${VM1_INTERNAL_IP}
ROOT_URL = https://${VM1_INTERNAL_IP}:8443/

[database]
DB_TYPE = sqlite3
PATH = /data/gitea/gitea.db

[repository]
ROOT = /data/git/repositories

[log]
MODE = file
LEVEL = Info
ROOT_PATH = /data/gitea/log
EOF
    
    # Create docker-compose override for HTTPS
    cat > "${gitea_config_dir}/docker-compose.https.yml" << EOF
version: '3.8'

services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea-https
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    volumes:
      - /var/lib/gitea:/data
      - ${gitea_cert_dir}/gitea.crt:/data/gitea/cert/gitea.crt:ro
      - ${gitea_cert_dir}/gitea.key:/data/gitea/cert/gitea.key:ro
      - ${gitea_config_dir}/app.ini:/data/gitea/conf/app.ini:ro
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "8888:3000"   # HTTP (for compatibility)
      - "8443:3443"   # HTTPS
      - "2222:22"     # SSH
EOF
    
    log "Gitea HTTPS configuration created"
}

# Deploy certificates to K8s clusters
deploy_k8s_certificates() {
    log "Deploying certificates to Kubernetes clusters..."
    
    # Deploy to Edge1 if accessible
    if nc -z -w 3 "${VM2_IP}" "${K8S_API_PORT}" 2>/dev/null; then
        info "Deploying certificate to Edge1 cluster..."
        
        # Create namespace for certificates
        kubectl --server="https://${VM2_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify \
            create namespace cert-manager --dry-run=client -o yaml | \
            kubectl --server="https://${VM2_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify apply -f -
        
        # Create secret with CA certificate
        kubectl --server="https://${VM2_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify \
            create secret tls ca-certificate \
            --cert="${CA_CERT}" \
            --key="${CA_KEY}" \
            --namespace=cert-manager \
            --dry-run=client -o yaml | \
            kubectl --server="https://${VM2_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify apply -f -
            
        log "Edge1 certificate deployment completed"
    else
        warn "Edge1 cluster not accessible, skipping certificate deployment"
    fi
    
    # Deploy to Edge2 if accessible
    if nc -z -w 3 "${VM4_IP}" "${K8S_API_PORT}" 2>/dev/null; then
        info "Deploying certificate to Edge2 cluster..."
        
        # Create namespace for certificates
        kubectl --server="https://${VM4_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify \
            create namespace cert-manager --dry-run=client -o yaml | \
            kubectl --server="https://${VM4_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify apply -f -
        
        # Create secret with CA certificate
        kubectl --server="https://${VM4_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify \
            create secret tls ca-certificate \
            --cert="${CA_CERT}" \
            --key="${CA_KEY}" \
            --namespace=cert-manager \
            --dry-run=client -o yaml | \
            kubectl --server="https://${VM4_IP}:${K8S_API_PORT}" --insecure-skip-tls-verify apply -f -
            
        log "Edge2 certificate deployment completed"
    else
        warn "Edge2 cluster not accessible, skipping certificate deployment"
    fi
}

# Create certificate management scripts
create_management_scripts() {
    log "Creating certificate management scripts..."
    
    # Certificate renewal script
    cat > "${PROJECT_ROOT}/scripts/renew-certificates.sh" << 'EOF'
#!/bin/bash
# Certificate Renewal Script
# This script renews all certificates before they expire

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="${SCRIPT_DIR}/setup/setup-ssl-certificates.sh"

if [[ -f "${SETUP_SCRIPT}" ]]; then
    echo "Renewing certificates..."
    "${SETUP_SCRIPT}" --renew
else
    echo "Error: Setup script not found at ${SETUP_SCRIPT}"
    exit 1
fi
EOF
    
    # Certificate status check script
    cat > "${PROJECT_ROOT}/scripts/check-certificate-status.sh" << 'EOF'
#!/bin/bash
# Certificate Status Check Script
# This script checks the expiration status of all certificates

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_DIR="${PROJECT_ROOT}/certs"

echo "Certificate Status Report"
echo "========================"
echo ""

for cert_file in $(find "${CERT_DIR}" -name "*.crt" -type f); do
    echo "Certificate: $(basename "${cert_file}")"
    echo "Path: ${cert_file}"
    
    if openssl x509 -in "${cert_file}" -noout -dates 2>/dev/null; then
        expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate 2>/dev/null | cut -d= -f2)
        expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || echo "0")
        current_epoch=$(date +%s)
        days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [[ ${days_remaining} -lt 30 ]]; then
            echo "⚠️  WARNING: Certificate expires in ${days_remaining} days"
        elif [[ ${days_remaining} -lt 7 ]]; then
            echo "🚨 CRITICAL: Certificate expires in ${days_remaining} days"
        else
            echo "✅ OK: Certificate expires in ${days_remaining} days"
        fi
    else
        echo "❌ ERROR: Unable to read certificate"
    fi
    echo ""
done
EOF
    
    # Make scripts executable
    chmod +x "${PROJECT_ROOT}/scripts/renew-certificates.sh"
    chmod +x "${PROJECT_ROOT}/scripts/check-certificate-status.sh"
    
    log "Management scripts created"
}

# Update configurations to use HTTPS
update_configurations() {
    log "Updating configurations to use HTTPS endpoints..."
    
    # Update GitOps configurations
    local gitops_config_dir="${PROJECT_ROOT}/gitops"
    
    if [[ -d "${gitops_config_dir}" ]]; then
        # Create updated RootSync configurations
        cat > "${CONFIG_DIR}/edge1-rootsync-https.yaml" << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync-https
  namespace: config-management-system
spec:
  git:
    repo: https://${VM1_INTERNAL_IP}:8443/admin1/edge1-config
    branch: main
    auth: token
    secretRef:
      name: gitea-token-https
    caCertSecretRef:
      name: gitea-ca-cert
EOF
        
        cat > "${CONFIG_DIR}/edge2-rootsync-https.yaml" << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge2-rootsync-https
  namespace: config-management-system
spec:
  git:
    repo: https://${VM1_INTERNAL_IP}:8443/admin1/edge2-config
    branch: main
    directory: /edge2
    auth: token
    secretRef:
      name: git-creds-https
    caCertSecretRef:
      name: gitea-ca-cert
EOF
        
        log "GitOps configurations updated for HTTPS"
    fi
    
    # Create kubeconfig with proper TLS settings
    cat > "${CONFIG_DIR}/kubeconfig-edge1-tls.yaml" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${CERT_DIR}/ca/${CA_NAME}.crt
    server: https://${VM2_IP}:${K8S_API_PORT}
  name: edge1-secure
contexts:
- context:
    cluster: edge1-secure
    user: admin
  name: edge1-secure
current-context: edge1-secure
users:
- name: admin
  user:
    client-certificate: ${CERT_DIR}/k8s/k8s-edge1.crt
    client-key: ${CERT_DIR}/k8s/k8s-edge1.key
EOF
    
    cat > "${CONFIG_DIR}/kubeconfig-edge2-tls.yaml" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${CERT_DIR}/ca/${CA_NAME}.crt
    server: https://${VM4_IP}:${K8S_API_PORT}
  name: edge2-secure
contexts:
- context:
    cluster: edge2-secure
    user: admin
  name: edge2-secure
current-context: edge2-secure
users:
- name: admin
  user:
    client-certificate: ${CERT_DIR}/k8s/k8s-edge2.crt
    client-key: ${CERT_DIR}/k8s/k8s-edge2.key
EOF
    
    log "Kubeconfig files with TLS settings created"
}

# Generate certificate inventory
generate_certificate_inventory() {
    log "Generating certificate inventory..."
    
    local inventory_file="${PROJECT_ROOT}/reports/certificate-inventory-$(date +%Y%m%d-%H%M%S).md"
    
    mkdir -p "$(dirname "${inventory_file}")"
    
    cat > "${inventory_file}" << EOF
# SSL/TLS Certificate Inventory

**Generated**: $(date)
**System**: Nephio Intent-to-O2 Demo
**Version**: 1.0.0

## Certificate Authority (CA)

- **Certificate**: ${CA_CERT}
- **Private Key**: ${CA_KEY}
- **Validity**: ${VALIDITY_DAYS} days
- **Status**: $(if [[ -f "${CA_CERT}" ]]; then echo "✅ Generated"; else echo "❌ Missing"; fi)

## Service Certificates

### Gitea HTTPS Certificate

- **Service**: Gitea Web Interface
- **Endpoint**: https://${VM1_INTERNAL_IP}:8443
- **Certificate**: ${CERT_DIR}/gitea/gitea.crt
- **Private Key**: ${CERT_DIR}/gitea/gitea.key
- **Common Name**: gitea.nephio.local
- **Subject Alternative Names**:
  - DNS: gitea.local
  - DNS: gitea.nephio.local
  - DNS: localhost
  - IP: 127.0.0.1
  - IP: ${VM1_INTERNAL_IP}
- **Status**: $(if [[ -f "${CERT_DIR}/gitea/gitea.crt" ]]; then echo "✅ Generated"; else echo "❌ Missing"; fi)

### Edge1 Kubernetes API Certificate

- **Service**: Kubernetes API Server (Edge1)
- **Endpoint**: https://${VM2_IP}:${K8S_API_PORT}
- **Certificate**: ${CERT_DIR}/k8s-edge1/k8s-edge1.crt
- **Private Key**: ${CERT_DIR}/k8s-edge1/k8s-edge1.key
- **Common Name**: edge1.nephio.local
- **Subject Alternative Names**:
  - DNS: edge1.nephio.local
  - DNS: kubernetes.default
  - DNS: kubernetes.default.svc
  - DNS: kubernetes.default.svc.cluster.local
  - DNS: localhost
  - IP: 127.0.0.1
  - IP: ${VM2_IP}
  - IP: 10.43.0.1
- **Status**: $(if [[ -f "${CERT_DIR}/k8s-edge1/k8s-edge1.crt" ]]; then echo "✅ Generated"; else echo "❌ Missing"; fi)

### Edge2 Kubernetes API Certificate

- **Service**: Kubernetes API Server (Edge2)
- **Endpoint**: https://${VM4_IP}:${K8S_API_PORT}
- **Certificate**: ${CERT_DIR}/k8s-edge2/k8s-edge2.crt
- **Private Key**: ${CERT_DIR}/k8s-edge2/k8s-edge2.key
- **Common Name**: edge2.nephio.local
- **Subject Alternative Names**:
  - DNS: edge2.nephio.local
  - DNS: kubernetes.default
  - DNS: kubernetes.default.svc
  - DNS: kubernetes.default.svc.cluster.local
  - DNS: localhost
  - IP: 127.0.0.1
  - IP: ${VM4_IP}
  - IP: 10.43.0.1
- **Status**: $(if [[ -f "${CERT_DIR}/k8s-edge2/k8s-edge2.crt" ]]; then echo "✅ Generated"; else echo "❌ Missing"; fi)

## Configuration Files

### Gitea HTTPS Configuration

- **Docker Compose**: ${CONFIG_DIR}/gitea/docker-compose.https.yml
- **App Configuration**: ${CONFIG_DIR}/gitea/app.ini

### Kubernetes TLS Configuration

- **Edge1 Kubeconfig**: ${CONFIG_DIR}/kubeconfig-edge1-tls.yaml
- **Edge2 Kubeconfig**: ${CONFIG_DIR}/kubeconfig-edge2-tls.yaml
- **Edge1 RootSync**: ${CONFIG_DIR}/edge1-rootsync-https.yaml
- **Edge2 RootSync**: ${CONFIG_DIR}/edge2-rootsync-https.yaml

## Management Scripts

- **Certificate Renewal**: ${PROJECT_ROOT}/scripts/renew-certificates.sh
- **Status Check**: ${PROJECT_ROOT}/scripts/check-certificate-status.sh
- **Setup Script**: ${PROJECT_ROOT}/scripts/setup/setup-ssl-certificates.sh

## Security Notes

1. All private keys are stored with 600 permissions (owner read/write only)
2. Certificates are stored with 644 permissions (owner read/write, others read only)
3. CA private key should be protected and backed up securely
4. Certificates are valid for ${VALIDITY_DAYS} days from generation date
5. Set up automated renewal before certificates expire

## Next Steps

1. Deploy certificates to production environments
2. Update all client configurations to use HTTPS endpoints
3. Set up certificate monitoring and alerting
4. Implement automated certificate renewal
5. Configure proper firewall rules for HTTPS ports

EOF
    
    log "Certificate inventory generated: ${inventory_file}"
}

# Main execution function
main() {
    local operation="${1:-install}"
    
    case "${operation}" in
        "install"|"setup")
            log "Starting SSL/TLS certificate setup..."
            check_prerequisites
            setup_directories
            generate_ca_certificate
            generate_gitea_certificate
            generate_k8s_certificates
            configure_gitea_https
            deploy_k8s_certificates
            create_management_scripts
            update_configurations
            generate_certificate_inventory
            log "SSL/TLS certificate setup completed successfully!"
            ;;
        "renew")
            log "Renewing certificates..."
            check_prerequisites
            # Remove existing certificates to force regeneration
            find "${CERT_DIR}" -name "*.crt" -not -path "*/ca/*" -delete 2>/dev/null || true
            find "${CERT_DIR}" -name "*.key" -not -path "*/ca/*" -delete 2>/dev/null || true
            generate_gitea_certificate
            generate_k8s_certificates
            deploy_k8s_certificates
            generate_certificate_inventory
            log "Certificate renewal completed successfully!"
            ;;
        "status")
            if [[ -f "${PROJECT_ROOT}/scripts/check-certificate-status.sh" ]]; then
                "${PROJECT_ROOT}/scripts/check-certificate-status.sh"
            else
                error "Certificate status script not found. Run setup first."
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [install|renew|status|help]"
            echo ""
            echo "Commands:"
            echo "  install  - Initial SSL/TLS certificate setup (default)"
            echo "  renew    - Renew existing certificates"
            echo "  status   - Check certificate expiration status"
            echo "  help     - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 install  # Initial setup"
            echo "  $0 renew    # Renew certificates"
            echo "  $0 status   # Check status"
            ;;
        *)
            error "Unknown operation: ${operation}. Use 'help' for usage information."
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
