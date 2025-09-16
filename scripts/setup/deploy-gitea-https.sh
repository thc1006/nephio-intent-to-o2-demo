#!/bin/bash
# Deploy Gitea with HTTPS Configuration
# This script deploys or updates Gitea to use HTTPS certificates

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CERT_DIR="${PROJECT_ROOT}/certs"
CONFIG_DIR="${PROJECT_ROOT}/configs/ssl"

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $*${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $*${NC}"; }
error() { echo -e "${RED}[ERROR] $*${NC}"; exit 1; }

# Check if certificates exist
check_certificates() {
    log "Checking certificate availability..."
    
    local gitea_cert="${CERT_DIR}/gitea/gitea.crt"
    local gitea_key="${CERT_DIR}/gitea/gitea.key"
    local ca_cert="${CERT_DIR}/nephio-ca.crt"
    
    if [[ ! -f "${gitea_cert}" ]] || [[ ! -f "${gitea_key}" ]]; then
        error "Gitea certificates not found. Run setup-ssl-certificates.sh first."
    fi
    
    if [[ ! -f "${ca_cert}" ]]; then
        error "CA certificate not found. Run setup-ssl-certificates.sh first."
    fi
    
    log "Certificates found and ready for deployment"
}

# Stop existing Gitea container
stop_existing_gitea() {
    log "Stopping existing Gitea containers..."
    
    # Stop and remove any existing Gitea containers
    docker stop gitea 2>/dev/null || true
    docker stop gitea-https 2>/dev/null || true
    docker rm gitea 2>/dev/null || true
    docker rm gitea-https 2>/dev/null || true
    
    log "Existing containers stopped"
}

# Deploy Gitea with HTTPS
deploy_gitea_https() {
    log "Deploying Gitea with HTTPS configuration..."
    
    local gitea_cert="${CERT_DIR}/gitea/gitea.crt"
    local gitea_key="${CERT_DIR}/gitea/gitea.key"
    local gitea_config="${CONFIG_DIR}/gitea/app.ini"
    
    # Ensure Gitea data directory exists
    sudo mkdir -p /var/lib/gitea
    sudo chown -R 1000:1000 /var/lib/gitea
    
    # Copy certificates to Gitea data directory
    sudo mkdir -p /var/lib/gitea/cert
    sudo cp "${gitea_cert}" /var/lib/gitea/cert/
    sudo cp "${gitea_key}" /var/lib/gitea/cert/
    sudo chown -R 1000:1000 /var/lib/gitea/cert
    sudo chmod 600 /var/lib/gitea/cert/gitea.key
    sudo chmod 644 /var/lib/gitea/cert/gitea.crt
    
    # Copy configuration if it exists
    if [[ -f "${gitea_config}" ]]; then
        sudo mkdir -p /var/lib/gitea/conf
        sudo cp "${gitea_config}" /var/lib/gitea/conf/
        sudo chown -R 1000:1000 /var/lib/gitea/conf
    fi
    
    # Start Gitea container with HTTPS support
    docker run -d \
        --name gitea-https \
        --restart unless-stopped \
        -p 8888:3000 \
        -p 8443:3443 \
        -p 2222:22 \
        -v /var/lib/gitea:/data \
        -e USER_UID=1000 \
        -e USER_GID=1000 \
        -e GITEA__server__PROTOCOL=https \
        -e GITEA__server__HTTP_PORT=3000 \
        -e GITEA__server__HTTPS_PORT=3443 \
        -e GITEA__server__CERT_FILE=/data/cert/gitea.crt \
        -e GITEA__server__KEY_FILE=/data/cert/gitea.key \
        -e GITEA__server__DOMAIN=172.16.0.78 \
        -e GITEA__server__ROOT_URL=https://172.16.0.78:8443/ \
        gitea/gitea:latest
    
    log "Gitea HTTPS container started"
}

# Test HTTPS connectivity
test_https_connectivity() {
    log "Testing HTTPS connectivity..."
    
    # Wait for Gitea to start
    sleep 10
    
    # Test HTTP (should still work for compatibility)
    if curl -s -f http://172.16.0.78:8888 >/dev/null; then
        log "✅ HTTP endpoint (port 8888) is accessible"
    else
        warn "⚠️ HTTP endpoint (port 8888) is not accessible"
    fi
    
    # Test HTTPS with self-signed certificate
    if curl -s -k -f https://172.16.0.78:8443 >/dev/null; then
        log "✅ HTTPS endpoint (port 8443) is accessible"
    else
        warn "⚠️ HTTPS endpoint (port 8443) is not accessible"
    fi
    
    # Test HTTPS with CA verification
    local ca_cert="${CERT_DIR}/nephio-ca.crt"
    if curl -s --cacert "${ca_cert}" -f https://172.16.0.78:8443 >/dev/null; then
        log "✅ HTTPS endpoint with CA verification is accessible"
    else
        warn "⚠️ HTTPS endpoint with CA verification failed"
    fi
}

# Generate test script for clients
generate_client_test_script() {
    log "Generating client test script..."
    
    cat > "${PROJECT_ROOT}/scripts/test-gitea-https.sh" << 'EOF'
#!/bin/bash
# Test Gitea HTTPS connectivity from different perspectives

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CA_CERT="${PROJECT_ROOT}/certs/nephio-ca.crt"
GITEA_IP="172.16.0.78"

echo "Testing Gitea HTTPS Connectivity"
echo "================================="
echo ""

# Test 1: HTTP endpoint (backward compatibility)
echo "1. Testing HTTP endpoint (port 8888)..."
if curl -s -f "http://${GITEA_IP}:8888" >/dev/null; then
    echo "   ✅ HTTP endpoint accessible"
else
    echo "   ❌ HTTP endpoint not accessible"
fi
echo ""

# Test 2: HTTPS endpoint (insecure)
echo "2. Testing HTTPS endpoint (port 8443, insecure)..."
if curl -s -k -f "https://${GITEA_IP}:8443" >/dev/null; then
    echo "   ✅ HTTPS endpoint accessible (insecure)"
else
    echo "   ❌ HTTPS endpoint not accessible"
fi
echo ""

# Test 3: HTTPS endpoint with CA verification
echo "3. Testing HTTPS endpoint with CA verification..."
if [[ -f "${CA_CERT}" ]]; then
    if curl -s --cacert "${CA_CERT}" -f "https://${GITEA_IP}:8443" >/dev/null; then
        echo "   ✅ HTTPS endpoint accessible with CA verification"
    else
        echo "   ❌ HTTPS endpoint failed CA verification"
    fi
else
    echo "   ❌ CA certificate not found at ${CA_CERT}"
fi
echo ""

# Test 4: Git clone over HTTPS (if CA cert exists)
if [[ -f "${CA_CERT}" ]]; then
    echo "4. Testing Git clone over HTTPS..."
    cd /tmp
    # Configure git to use our CA certificate
    git config --global http.sslCAInfo "${CA_CERT}"
    
    # Try to clone a test repository (this will fail if repo doesn't exist, but will test HTTPS)
    if git ls-remote "https://${GITEA_IP}:8443/admin1/edge1-config.git" >/dev/null 2>&1; then
        echo "   ✅ Git HTTPS access working"
    else
        echo "   ⚠️  Git HTTPS access may not be configured (or repo doesn't exist)"
    fi
    
    # Reset git config
    git config --global --unset http.sslCAInfo || true
    cd - >/dev/null
else
    echo "4. Skipping Git clone test (CA certificate not found)"
fi
echo ""

echo "Test completed."
echo ""
echo "Usage examples:"
echo "  # HTTP (backward compatibility):"
echo "  curl http://${GITEA_IP}:8888"
echo ""
echo "  # HTTPS (insecure, for testing):"
echo "  curl -k https://${GITEA_IP}:8443"
echo ""
echo "  # HTTPS (with CA verification):"
echo "  curl --cacert ${CA_CERT} https://${GITEA_IP}:8443"
echo ""
echo "  # Git clone with HTTPS:"
echo "  git -c http.sslCAInfo=${CA_CERT} clone https://${GITEA_IP}:8443/user/repo.git"
EOF
    
    chmod +x "${PROJECT_ROOT}/scripts/test-gitea-https.sh"
    log "Client test script created: ${PROJECT_ROOT}/scripts/test-gitea-https.sh"
}

# Create backup and rollback script
create_rollback_script() {
    log "Creating rollback script..."
    
    cat > "${PROJECT_ROOT}/scripts/rollback-gitea-http.sh" << 'EOF'
#!/bin/bash
# Rollback Gitea to HTTP-only configuration

set -euo pipefail

log() { echo "[$(date +'%H:%M:%S')] $*"; }

log "Rolling back Gitea to HTTP-only configuration..."

# Stop HTTPS container
docker stop gitea-https 2>/dev/null || true
docker rm gitea-https 2>/dev/null || true

# Start original HTTP container
docker run -d \
    --name gitea \
    --restart unless-stopped \
    -p 8888:3000 \
    -p 2222:22 \
    -v /var/lib/gitea:/data \
    -e USER_UID=1000 \
    -e USER_GID=1000 \
    gitea/gitea:latest

log "Gitea rolled back to HTTP configuration"
log "Service available at: http://172.16.0.78:8888"
EOF
    
    chmod +x "${PROJECT_ROOT}/scripts/rollback-gitea-http.sh"
    log "Rollback script created: ${PROJECT_ROOT}/scripts/rollback-gitea-http.sh"
}

# Main function
main() {
    log "Starting Gitea HTTPS deployment..."
    
    check_certificates
    stop_existing_gitea
    deploy_gitea_https
    test_https_connectivity
    generate_client_test_script
    create_rollback_script
    
    log "Gitea HTTPS deployment completed successfully!"
    echo ""
    echo "Gitea is now available at:"
    echo "  HTTP:  http://172.16.0.78:8888 (backward compatibility)"
    echo "  HTTPS: https://172.16.0.78:8443 (new secure endpoint)"
    echo ""
    echo "Test connectivity with: ${PROJECT_ROOT}/scripts/test-gitea-https.sh"
    echo "Rollback if needed with: ${PROJECT_ROOT}/scripts/rollback-gitea-http.sh"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
