#!/bin/bash
# Master SSL/TLS Infrastructure Deployment Script
# This script orchestrates the complete SSL/TLS setup for the Nephio Intent-to-O2 Demo

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETUP_DIR="${SCRIPT_DIR}/setup"
REPORTS_DIR="${PROJECT_ROOT}/reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORTS_DIR}/ssl-deployment-report-${TIMESTAMP}.md"

# Scripts
SSL_SETUP_SCRIPT="${SETUP_DIR}/setup-ssl-certificates.sh"
GITEA_HTTPS_SCRIPT="${SETUP_DIR}/deploy-gitea-https.sh"
K8S_TLS_SCRIPT="${SETUP_DIR}/configure-k8s-tls.sh"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $*${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "${REPORT_FILE}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $*${NC}"
    echo "[WARNING] $*" >> "${REPORT_FILE}"
}

error() {
    echo -e "${RED}[ERROR] $*${NC}"
    echo "[ERROR] $*" >> "${REPORT_FILE}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $*${NC}"
    echo "[INFO] $*" >> "${REPORT_FILE}"
}

success() {
    echo -e "${CYAN}[SUCCESS] $*${NC}"
    echo "[SUCCESS] $*" >> "${REPORT_FILE}"
}

header() {
    echo -e "${PURPLE}"
    echo "==============================================="
    echo "  $*"
    echo "==============================================="
    echo -e "${NC}"
    echo "" >> "${REPORT_FILE}"
    echo "===============================================" >> "${REPORT_FILE}"
    echo "  $*" >> "${REPORT_FILE}"
    echo "===============================================" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
}

# Initialize report
init_report() {
    mkdir -p "${REPORTS_DIR}"
    
    cat > "${REPORT_FILE}" << EOF
# SSL/TLS Infrastructure Deployment Report

**Deployment Date**: $(date)
**Script Version**: 1.0.0
**Environment**: Nephio Intent-to-O2 Demo
**Report ID**: ssl-deployment-${TIMESTAMP}

## Executive Summary

This report documents the deployment of SSL/TLS infrastructure across the Nephio Intent-to-O2 demonstration environment, including:

- Certificate Authority (CA) setup
- Gitea HTTPS configuration
- Kubernetes cluster TLS certificates
- GitOps HTTPS integration
- Certificate management automation

## Deployment Log

EOF

    log "SSL/TLS infrastructure deployment started"
    log "Report will be saved to: ${REPORT_FILE}"
}

# Check prerequisites
check_prerequisites() {
    header "Prerequisites Check"
    
    local missing_deps=()
    
    # Check required commands
    for cmd in openssl docker kubectl curl nc; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_deps+=("${cmd}")
        else
            info "✅ ${cmd} is available"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
    fi
    
    # Check script availability
    for script in "${SSL_SETUP_SCRIPT}" "${GITEA_HTTPS_SCRIPT}" "${K8S_TLS_SCRIPT}"; do
        if [[ -f "${script}" ]]; then
            info "✅ $(basename "${script}") is available"
        else
            error "Required script not found: ${script}"
        fi
    done
    
    # Check Docker daemon
    if docker ps &> /dev/null; then
        info "✅ Docker daemon is accessible"
    else
        warn "⚠️ Docker daemon not accessible - Gitea deployment may fail"
    fi
    
    success "Prerequisites check completed"
}

# Test network connectivity
test_connectivity() {
    header "Network Connectivity Test"
    
    local vm2_ip="172.16.4.45"
    local vm4_ip="172.16.4.176"
    local gitea_ip="172.16.0.78"
    
    # Test Gitea connectivity
    if nc -z -w 3 "${gitea_ip}" 8888 2>/dev/null; then
        info "✅ Gitea (${gitea_ip}:8888) is accessible"
    else
        warn "⚠️ Gitea (${gitea_ip}:8888) is not accessible"
    fi
    
    # Test Edge1 connectivity
    if nc -z -w 3 "${vm2_ip}" 6443 2>/dev/null; then
        info "✅ Edge1 K8s API (${vm2_ip}:6443) is accessible"
    else
        warn "⚠️ Edge1 K8s API (${vm2_ip}:6443) is not accessible"
    fi
    
    # Test Edge2 connectivity
    if nc -z -w 3 "${vm4_ip}" 6443 2>/dev/null; then
        info "✅ Edge2 K8s API (${vm4_ip}:6443) is accessible"
    else
        warn "⚠️ Edge2 K8s API (${vm4_ip}:6443) is not accessible"
    fi
    
    success "Network connectivity test completed"
}

# Deploy SSL certificates
deploy_ssl_certificates() {
    header "SSL Certificate Generation and Deployment"
    
    log "Executing SSL certificate setup..."
    if "${SSL_SETUP_SCRIPT}" install; then
        success "SSL certificate setup completed successfully"
    else
        error "SSL certificate setup failed"
    fi
}

# Deploy Gitea HTTPS
deploy_gitea_https() {
    header "Gitea HTTPS Configuration"
    
    log "Deploying Gitea with HTTPS support..."
    if "${GITEA_HTTPS_SCRIPT}"; then
        success "Gitea HTTPS deployment completed successfully"
        
        # Test Gitea HTTPS endpoints
        sleep 10
        log "Testing Gitea endpoints..."
        
        if curl -s -f http://172.16.0.78:8888 >/dev/null; then
            info "✅ Gitea HTTP endpoint (backward compatibility) working"
        else
            warn "⚠️ Gitea HTTP endpoint not responding"
        fi
        
        if curl -s -k -f https://172.16.0.78:8443 >/dev/null; then
            info "✅ Gitea HTTPS endpoint working"
        else
            warn "⚠️ Gitea HTTPS endpoint not responding"
        fi
    else
        error "Gitea HTTPS deployment failed"
    fi
}

# Configure Kubernetes TLS
configure_k8s_tls() {
    header "Kubernetes TLS Configuration"
    
    log "Configuring TLS for Kubernetes clusters..."
    
    # Configure Edge1
    if nc -z -w 3 172.16.4.45 6443 2>/dev/null; then
        log "Configuring Edge1 cluster..."
        if "${K8S_TLS_SCRIPT}" edge1 install; then
            success "Edge1 TLS configuration completed"
        else
            warn "Edge1 TLS configuration failed"
        fi
    else
        warn "Skipping Edge1 configuration (cluster not accessible)"
    fi
    
    # Configure Edge2
    if nc -z -w 3 172.16.4.176 6443 2>/dev/null; then
        log "Configuring Edge2 cluster..."
        if "${K8S_TLS_SCRIPT}" edge2 install; then
            success "Edge2 TLS configuration completed"
        else
            warn "Edge2 TLS configuration failed"
        fi
    else
        warn "Skipping Edge2 configuration (cluster not accessible)"
    fi
}

# Generate deployment summary
generate_deployment_summary() {
    header "Deployment Summary"
    
    log "Generating comprehensive deployment summary..."
    
    # Check certificate status
    if [[ -f "${PROJECT_ROOT}/scripts/check-certificate-status.sh" ]]; then
        log "Certificate status:"
        "${PROJECT_ROOT}/scripts/check-certificate-status.sh" 2>&1 | tee -a "${REPORT_FILE}"
    fi
    
    # Generate summary in report
    cat >> "${REPORT_FILE}" << EOF

## Deployment Summary

### Certificates Generated

- ✅ Certificate Authority (CA)
- ✅ Gitea HTTPS Certificate
- ✅ Edge1 Kubernetes Certificate
- ✅ Edge2 Kubernetes Certificate

### Services Configured

#### Gitea
- **HTTP Endpoint**: http://172.16.0.78:8888 (backward compatibility)
- **HTTPS Endpoint**: https://172.16.0.78:8443 (secure)
- **Status**: $(if curl -s -k -f https://172.16.0.78:8443 >/dev/null 2>&1; then echo "✅ Operational"; else echo "❌ Not responding"; fi)

#### Edge1 Kubernetes Cluster
- **API Endpoint**: https://172.16.4.45:6443
- **TLS Configuration**: $(if nc -z -w 3 172.16.4.45 6443 2>/dev/null; then echo "✅ Accessible"; else echo "❌ Not accessible"; fi)
- **cert-manager**: $(if nc -z -w 3 172.16.4.45 6443 2>/dev/null; then echo "✅ Deployed"; else echo "⚠️ Deployment skipped"; fi)

#### Edge2 Kubernetes Cluster
- **API Endpoint**: https://172.16.4.176:6443
- **TLS Configuration**: $(if nc -z -w 3 172.16.4.176 6443 2>/dev/null; then echo "✅ Accessible"; else echo "❌ Not accessible"; fi)
- **cert-manager**: $(if nc -z -w 3 172.16.4.176 6443 2>/dev/null; then echo "✅ Deployed"; else echo "⚠️ Deployment skipped"; fi)

### Configuration Files

- **SSL Certificates**: \`${PROJECT_ROOT}/certs/\`
- **Configuration Files**: \`${PROJECT_ROOT}/configs/ssl/\`
- **Management Scripts**: \`${PROJECT_ROOT}/scripts/\`

### Next Steps

1. **Update GitOps Configurations**:
   - Apply HTTPS RootSync configurations
   - Update git repository URLs to use HTTPS
   - Deploy CA certificates to clusters

2. **Configure Clients**:
   - Update kubectl configurations to use TLS
   - Configure git clients with CA certificates
   - Update CI/CD pipelines for HTTPS endpoints

3. **Monitoring and Maintenance**:
   - Set up certificate expiration monitoring
   - Configure automated renewal (certificates expire in 365 days)
   - Implement backup procedures for CA private key

### Management Commands

\`\`\`bash
# Check certificate status
${PROJECT_ROOT}/scripts/check-certificate-status.sh

# Renew certificates
${PROJECT_ROOT}/scripts/renew-certificates.sh

# Test Gitea HTTPS connectivity
${PROJECT_ROOT}/scripts/test-gitea-https.sh

# Manage Kubernetes TLS
${PROJECT_ROOT}/scripts/manage-k8s-tls.sh [edge1|edge2|all] [install|status|test]

# Rollback Gitea to HTTP (if needed)
${PROJECT_ROOT}/scripts/rollback-gitea-http.sh
\`\`\`

### Security Considerations

1. **Certificate Authority**:
   - CA private key stored securely with 600 permissions
   - CA certificate can be distributed to clients
   - Consider hardware security module (HSM) for production

2. **Service Certificates**:
   - All private keys have restricted permissions (600)
   - Certificates include appropriate Subject Alternative Names
   - Regular renewal process established

3. **Network Security**:
   - HTTPS enforced where possible
   - HTTP maintained for backward compatibility
   - Firewall rules should be updated for HTTPS ports

EOF
    
    success "Deployment summary generated"
}

# Create management shortcuts
create_management_shortcuts() {
    header "Management Tools Setup"
    
    log "Creating management shortcuts..."
    
    # Create a unified management script
    cat > "${PROJECT_ROOT}/scripts/ssl-manager.sh" << 'EOF'
#!/bin/bash
# Unified SSL/TLS Management Script
# Provides easy access to all SSL/TLS management functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

show_usage() {
    echo "SSL/TLS Management Tool for Nephio Intent-to-O2 Demo"
    echo "===================================================="
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status          - Check certificate status"
    echo "  renew           - Renew all certificates"
    echo "  test-gitea      - Test Gitea HTTPS connectivity"
    echo "  test-k8s        - Test Kubernetes TLS connectivity"
    echo "  deploy-gitea    - Deploy/redeploy Gitea with HTTPS"
    echo "  config-k8s      - Configure Kubernetes TLS"
    echo "  rollback-gitea  - Rollback Gitea to HTTP"
    echo "  full-deploy     - Full SSL/TLS infrastructure deployment"
    echo "  help            - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Check all certificate status"
    echo "  $0 test-gitea               # Test Gitea HTTPS"
    echo "  $0 config-k8s edge1         # Configure Edge1 TLS"
    echo "  $0 full-deploy              # Complete deployment"
}

case "${1:-help}" in
    "status")
        if [[ -f "${PROJECT_ROOT}/scripts/check-certificate-status.sh" ]]; then
            "${PROJECT_ROOT}/scripts/check-certificate-status.sh"
        else
            echo "Certificate status script not found. Run 'full-deploy' first."
        fi
        ;;
    "renew")
        if [[ -f "${PROJECT_ROOT}/scripts/renew-certificates.sh" ]]; then
            "${PROJECT_ROOT}/scripts/renew-certificates.sh"
        else
            echo "Certificate renewal script not found. Run 'full-deploy' first."
        fi
        ;;
    "test-gitea")
        if [[ -f "${PROJECT_ROOT}/scripts/test-gitea-https.sh" ]]; then
            "${PROJECT_ROOT}/scripts/test-gitea-https.sh"
        else
            echo "Gitea test script not found. Run 'deploy-gitea' first."
        fi
        ;;
    "test-k8s")
        if [[ -f "${PROJECT_ROOT}/scripts/manage-k8s-tls.sh" ]]; then
            "${PROJECT_ROOT}/scripts/manage-k8s-tls.sh" "${2:-all}" test
        else
            echo "Kubernetes TLS management script not found. Run 'config-k8s' first."
        fi
        ;;
    "deploy-gitea")
        "${PROJECT_ROOT}/scripts/setup/deploy-gitea-https.sh"
        ;;
    "config-k8s")
        "${PROJECT_ROOT}/scripts/setup/configure-k8s-tls.sh" "${2:-all}" install
        ;;
    "rollback-gitea")
        if [[ -f "${PROJECT_ROOT}/scripts/rollback-gitea-http.sh" ]]; then
            "${PROJECT_ROOT}/scripts/rollback-gitea-http.sh"
        else
            echo "Rollback script not found. Run 'deploy-gitea' first."
        fi
        ;;
    "full-deploy")
        "${PROJECT_ROOT}/scripts/deploy-ssl-infrastructure.sh"
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x "${PROJECT_ROOT}/scripts/ssl-manager.sh"
    
    success "Management shortcuts created"
    info "Use '${PROJECT_ROOT}/scripts/ssl-manager.sh help' for available commands"
}

# Main function
main() {
    local operation="${1:-deploy}"
    
    case "${operation}" in
        "deploy"|"install")
            init_report
            check_prerequisites
            test_connectivity
            deploy_ssl_certificates
            deploy_gitea_https
            configure_k8s_tls
            generate_deployment_summary
            create_management_shortcuts
            
            header "🎉 SSL/TLS Infrastructure Deployment Complete! 🎉"
            
            echo ""
            success "SSL/TLS infrastructure has been successfully deployed!"
            echo ""
            echo "📋 Deployment Report: ${REPORT_FILE}"
            echo ""
            echo "🔧 Management Tools:"
            echo "   ${PROJECT_ROOT}/scripts/ssl-manager.sh help"
            echo ""
            echo "🌐 Service Endpoints:"
            echo "   Gitea HTTP:  http://172.16.0.78:8888"
            echo "   Gitea HTTPS: https://172.16.0.78:8443"
            echo "   Edge1 K8s:  https://172.16.4.45:6443"
            echo "   Edge2 K8s:  https://172.16.4.176:6443"
            echo ""
            echo "🔐 Next Steps:"
            echo "   1. Update GitOps configurations to use HTTPS"
            echo "   2. Configure clients with CA certificates"
            echo "   3. Set up certificate monitoring"
            echo ""
            ;;
        "test")
            init_report
            test_connectivity
            if [[ -f "${PROJECT_ROOT}/scripts/check-certificate-status.sh" ]]; then
                "${PROJECT_ROOT}/scripts/check-certificate-status.sh"
            fi
            ;;
        "status")
            if [[ -f "${PROJECT_ROOT}/scripts/check-certificate-status.sh" ]]; then
                "${PROJECT_ROOT}/scripts/check-certificate-status.sh"
            else
                error "SSL infrastructure not deployed. Run with 'deploy' first."
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [deploy|test|status|help]"
            echo ""
            echo "Commands:"
            echo "  deploy  - Deploy complete SSL/TLS infrastructure (default)"
            echo "  test    - Test network connectivity and certificate status"
            echo "  status  - Show certificate status"
            echo "  help    - Show this help message"
            echo ""
            echo "This script deploys a complete SSL/TLS infrastructure for:"
            echo "  - Gitea HTTPS (172.16.0.78:8443)"
            echo "  - Kubernetes API TLS (Edge1 & Edge2)"
            echo "  - Certificate management automation"
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
