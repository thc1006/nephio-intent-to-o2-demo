#!/bin/bash
# SSL/TLS Setup Validation Script
# Validates the complete SSL/TLS infrastructure before deployment

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $*${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $*${NC}"; }
error() { echo -e "${RED}[ERROR] $*${NC}"; }
info() { echo -e "${BLUE}[INFO] $*${NC}"; }

# Check if all scripts are present and executable
check_scripts() {
    log "Validating SSL/TLS setup scripts..."
    
    local scripts=(
        "${PROJECT_ROOT}/scripts/setup/setup-ssl-certificates.sh"
        "${PROJECT_ROOT}/scripts/setup/deploy-gitea-https.sh"
        "${PROJECT_ROOT}/scripts/setup/configure-k8s-tls.sh"
        "${PROJECT_ROOT}/scripts/deploy-ssl-infrastructure.sh"
    )
    
    local missing_scripts=()
    
    for script in "${scripts[@]}"; do
        if [[ -f "${script}" && -x "${script}" ]]; then
            info "✅ $(basename "${script}") found and executable"
        else
            missing_scripts+=("$(basename "${script})")
            error "❌ $(basename "${script}") missing or not executable"
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        error "Missing or non-executable scripts: ${missing_scripts[*]}"
        return 1
    fi
    
    log "All SSL/TLS setup scripts validated successfully"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check required commands
    for cmd in openssl docker kubectl curl nc jq; do
        if command -v "${cmd}" &> /dev/null; then
            info "✅ ${cmd} is available"
        else
            missing_deps+=("${cmd}")
            warn "⚠️ ${cmd} is not available"
        fi
    done
    
    # Check Docker daemon
    if docker ps &> /dev/null; then
        info "✅ Docker daemon is accessible"
    else
        warn "⚠️ Docker daemon not accessible"
    fi
    
    # Check OpenSSL version
    local openssl_version=$(openssl version 2>/dev/null || echo "unknown")
    info "OpenSSL version: ${openssl_version}"
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warn "Missing optional dependencies: ${missing_deps[*]}"
        warn "Some features may not work correctly"
    fi
    
    log "Prerequisites check completed"
}

# Test network connectivity
test_network() {
    log "Testing network connectivity..."
    
    local endpoints=(
        "172.16.0.78:8888:Gitea HTTP"
        "172.16.4.45:6443:Edge1 K8s API"
        "172.16.4.176:6443:Edge2 K8s API"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local ip_port=$(echo "${endpoint}" | cut -d: -f1,2)
        local description=$(echo "${endpoint}" | cut -d: -f3)
        
        local ip=$(echo "${ip_port}" | cut -d: -f1)
        local port=$(echo "${ip_port}" | cut -d: -f2)
        if nc -z -w 3 "${ip}" "${port}" 2>/dev/null; then
            info "[OK] ${description} (${ip_port}) is accessible"
        else
            warn "[WARNING] ${description} (${ip_port}) is not accessible"
        fi
    done
    
    log "Network connectivity test completed"
}

# Check current Gitea status
check_gitea_status() {
    log "Checking current Gitea status..."
    
    # Check for running Gitea containers
    local gitea_containers=$(docker ps --filter "name=gitea" --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [[ -n "${gitea_containers}" ]]; then
        info "Running Gitea containers: ${gitea_containers}"
        
        # Test HTTP endpoint
        if curl -s -f http://172.16.0.78:8888 >/dev/null 2>&1; then
            info "✅ Gitea HTTP endpoint (8888) is responding"
        else
            warn "⚠️ Gitea HTTP endpoint (8888) is not responding"
        fi
        
        # Test HTTPS endpoint if it exists
        if curl -s -k -f https://172.16.0.78:8443 >/dev/null 2>&1; then
            info "✅ Gitea HTTPS endpoint (8443) is responding"
        else
            info "Gitea HTTPS endpoint (8443) not configured (will be set up)"
        fi
    else
        warn "⚠️ No Gitea containers found running"
    fi
    
    log "Gitea status check completed"
}

# Check Kubernetes cluster access
check_k8s_access() {
    log "Checking Kubernetes cluster access..."
    
    local clusters=(
        "172.16.4.45:Edge1"
        "172.16.4.176:Edge2"
    )
    
    for cluster in "${clusters[@]}"; do
        local ip=$(echo "${cluster}" | cut -d: -f1)
        local name=$(echo "${cluster}" | cut -d: -f2)
        
        if nc -z -w 3 "${ip}" 6443 2>/dev/null; then
            info "✅ ${name} cluster (${ip}) is accessible"
            
            # Try to get basic cluster info
            if kubectl --server="https://${ip}:6443" --insecure-skip-tls-verify version --short 2>/dev/null; then
                info "✅ ${name} cluster API is responding"
            else
                warn "⚠️ ${name} cluster API not responding properly"
            fi
        else
            warn "⚠️ ${name} cluster (${ip}) is not accessible"
        fi
    done
    
    log "Kubernetes cluster access check completed"
}

# Check existing certificates
check_existing_certificates() {
    log "Checking for existing certificates..."
    
    local cert_dir="${PROJECT_ROOT}/certs"
    
    if [[ -d "${cert_dir}" ]]; then
        info "Certificate directory exists: ${cert_dir}"
        
        # Check for CA certificate
        if [[ -f "${cert_dir}/nephio-ca.crt" ]]; then
            info "✅ CA certificate found"
            
            # Check CA certificate validity
            local ca_expiry=$(openssl x509 -in "${cert_dir}/nephio-ca.crt" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "unknown")
            info "CA certificate expires: ${ca_expiry}"
        else
            info "CA certificate not found (will be generated)"
        fi
        
        # Check service certificates
        for service in gitea k8s-edge1 k8s-edge2; do
            if [[ -f "${cert_dir}/${service}/${service}.crt" ]]; then
                info "✅ ${service} certificate found"
            else
                info "${service} certificate not found (will be generated)"
            fi
        done
    else
        info "Certificate directory not found (will be created)"
    fi
    
    log "Certificate check completed"
}

# Generate validation report
generate_report() {
    log "Generating validation report..."
    
    local report_file="${PROJECT_ROOT}/reports/ssl-validation-report-$(date +%Y%m%d-%H%M%S).md"
    
    mkdir -p "$(dirname "${report_file}")"
    
    cat > "${report_file}" << EOF
# SSL/TLS Setup Validation Report

**Validation Date**: $(date)
**Environment**: Nephio Intent-to-O2 Demo
**Validation Script**: $(basename "${0}")

## Summary

This report validates the readiness of the environment for SSL/TLS infrastructure deployment.

## Prerequisites Status

### Required Tools

- **OpenSSL**: $(command -v openssl >/dev/null && echo "✅ Available" || echo "❌ Missing")
- **Docker**: $(command -v docker >/dev/null && echo "✅ Available" || echo "❌ Missing")
- **kubectl**: $(command -v kubectl >/dev/null && echo "✅ Available" || echo "❌ Missing")
- **curl**: $(command -v curl >/dev/null && echo "✅ Available" || echo "❌ Missing")
- **netcat**: $(command -v nc >/dev/null && echo "✅ Available" || echo "❌ Missing")

### Docker Status

- **Daemon**: $(docker ps >/dev/null 2>&1 && echo "✅ Accessible" || echo "❌ Not accessible")
- **Gitea Container**: $(docker ps --filter "name=gitea" --format "{{.Names}}" 2>/dev/null | head -1 || echo "Not running")

## Network Connectivity

### Service Endpoints

- **Gitea HTTP**: $(nc -z -w 3 172.16.0.78 8888 2>/dev/null && echo "✅ Accessible" || echo "❌ Not accessible")
- **Edge1 K8s API**: $(nc -z -w 3 172.16.4.45 6443 2>/dev/null && echo "✅ Accessible" || echo "❌ Not accessible")
- **Edge2 K8s API**: $(nc -z -w 3 172.16.4.176 6443 2>/dev/null && echo "✅ Accessible" || echo "❌ Not accessible")

### HTTP Response Tests

- **Gitea HTTP**: $(curl -s -f http://172.16.0.78:8888 >/dev/null 2>&1 && echo "✅ Responding" || echo "❌ Not responding")
- **Gitea HTTPS**: $(curl -s -k -f https://172.16.0.78:8443 >/dev/null 2>&1 && echo "✅ Responding" || echo "⚠️ Not configured")

## Existing Certificates

### Certificate Directory

- **Location**: \`${PROJECT_ROOT}/certs\`
- **Status**: $(if [[ -d "${PROJECT_ROOT}/certs" ]]; then echo "✅ Exists"; else echo "⚠️ Will be created"; fi)

### CA Certificate

- **File**: \`certs/nephio-ca.crt\`
- **Status**: $(if [[ -f "${PROJECT_ROOT}/certs/nephio-ca.crt" ]]; then echo "✅ Exists"; else echo "⚠️ Will be generated"; fi)

### Service Certificates

- **Gitea**: $(if [[ -f "${PROJECT_ROOT}/certs/gitea/gitea.crt" ]]; then echo "✅ Exists"; else echo "⚠️ Will be generated"; fi)
- **Edge1 K8s**: $(if [[ -f "${PROJECT_ROOT}/certs/k8s-edge1/k8s-edge1.crt" ]]; then echo "✅ Exists"; else echo "⚠️ Will be generated"; fi)
- **Edge2 K8s**: $(if [[ -f "${PROJECT_ROOT}/certs/k8s-edge2/k8s-edge2.crt" ]]; then echo "✅ Exists"; else echo "⚠️ Will be generated"; fi)

## Setup Scripts

### Script Availability

- **SSL Setup**: $(if [[ -x "${PROJECT_ROOT}/scripts/setup/setup-ssl-certificates.sh" ]]; then echo "✅ Ready"; else echo "❌ Missing"; fi)
- **Gitea HTTPS**: $(if [[ -x "${PROJECT_ROOT}/scripts/setup/deploy-gitea-https.sh" ]]; then echo "✅ Ready"; else echo "❌ Missing"; fi)
- **K8s TLS**: $(if [[ -x "${PROJECT_ROOT}/scripts/setup/configure-k8s-tls.sh" ]]; then echo "✅ Ready"; else echo "❌ Missing"; fi)
- **Master Deployment**: $(if [[ -x "${PROJECT_ROOT}/scripts/deploy-ssl-infrastructure.sh" ]]; then echo "✅ Ready"; else echo "❌ Missing"; fi)

## Recommendations

### Immediate Actions

1. **If all prerequisites are met**: Proceed with SSL/TLS deployment
   \`\`\`bash
   ./scripts/deploy-ssl-infrastructure.sh
   \`\`\`

2. **If prerequisites are missing**: Install missing tools first
   \`\`\`bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install -y openssl curl netcat-openbsd
   
   # Install Docker if needed
   curl -fsSL https://get.docker.com | sh
   
   # Install kubectl if needed
   curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   \`\`\`

3. **If network connectivity issues exist**: Check firewall rules and network configuration

### Post-Deployment

1. **Test all endpoints** after deployment
2. **Update GitOps configurations** to use HTTPS
3. **Configure monitoring** for certificate expiration
4. **Set up automated renewal** processes

## Validation Summary

- **Prerequisites**: $(if command -v openssl >/dev/null && command -v docker >/dev/null; then echo "✅ Ready"; else echo "⚠️ Issues detected"; fi)
- **Network**: $(if nc -z -w 3 172.16.0.78 8888 2>/dev/null; then echo "✅ Ready"; else echo "⚠️ Issues detected"; fi)
- **Scripts**: $(if [[ -x "${PROJECT_ROOT}/scripts/deploy-ssl-infrastructure.sh" ]]; then echo "✅ Ready"; else echo "⚠️ Issues detected"; fi)
- **Overall**: $(if command -v openssl >/dev/null && command -v docker >/dev/null && nc -z -w 3 172.16.0.78 8888 2>/dev/null; then echo "✅ Ready for deployment"; else echo "⚠️ Review issues before deployment"; fi)

EOF
    
    info "Validation report generated: ${report_file}"
    
    # Display summary
    echo ""
    echo "Validation Summary:"
    echo "=================="
    if command -v openssl >/dev/null && command -v docker >/dev/null && nc -z -w 3 172.16.0.78 8888 2>/dev/null; then
        info "✅ Environment is ready for SSL/TLS deployment"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ./scripts/deploy-ssl-infrastructure.sh"
        echo "  2. Monitor deployment progress"
        echo "  3. Test endpoints after deployment"
        echo "  4. Update GitOps configurations"
    else
        warn "⚠️ Issues detected - review validation report before deployment"
        echo ""
        echo "Required actions:"
        if ! command -v openssl >/dev/null; then
            echo "  - Install OpenSSL"
        fi
        if ! command -v docker >/dev/null; then
            echo "  - Install Docker"
        fi
        if ! nc -z -w 3 172.16.0.78 8888 2>/dev/null; then
            echo "  - Check Gitea service and network connectivity"
        fi
    fi
    echo ""
}

# Main function
main() {
    echo "SSL/TLS Infrastructure Validation"
    echo "=================================="
    echo ""
    
    check_scripts
    echo ""
    check_prerequisites
    echo ""
    test_network
    echo ""
    check_gitea_status
    echo ""
    check_k8s_access
    echo ""
    check_existing_certificates
    echo ""
    generate_report
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
