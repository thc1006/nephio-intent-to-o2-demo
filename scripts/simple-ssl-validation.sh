#!/bin/bash
# Simple SSL/TLS Setup Validation Script
# Basic validation without special characters

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "SSL/TLS Infrastructure Validation"
echo "=================================="
echo ""

# Check prerequisites
echo "1. Checking Prerequisites..."
echo "----------------------------"

# Check required commands
for cmd in openssl docker kubectl curl nc; do
    if command -v "${cmd}" >/dev/null 2>&1; then
        echo "[OK] ${cmd} is available"
    else
        echo "[MISSING] ${cmd} is not available"
    fi
done

# Check Docker daemon
if docker ps >/dev/null 2>&1; then
    echo "[OK] Docker daemon is accessible"
else
    echo "[WARNING] Docker daemon not accessible"
fi

echo ""

# Test network connectivity
echo "2. Testing Network Connectivity..."
echo "-----------------------------------"

# Test Gitea
if nc -z -w 3 172.16.0.78 8888 2>/dev/null; then
    echo "[OK] Gitea (172.16.0.78:8888) is accessible"
else
    echo "[WARNING] Gitea (172.16.0.78:8888) is not accessible"
fi

# Test Edge1
if nc -z -w 3 172.16.4.45 6443 2>/dev/null; then
    echo "[OK] Edge1 K8s API (172.16.4.45:6443) is accessible"
else
    echo "[WARNING] Edge1 K8s API (172.16.4.45:6443) is not accessible"
fi

# Test Edge2
if nc -z -w 3 172.16.4.176 6443 2>/dev/null; then
    echo "[OK] Edge2 K8s API (172.16.4.176:6443) is accessible"
else
    echo "[WARNING] Edge2 K8s API (172.16.4.176:6443) is not accessible"
fi

echo ""

# Check scripts
echo "3. Checking Setup Scripts..."
echo "----------------------------"

scripts=(
    "${PROJECT_ROOT}/scripts/setup/setup-ssl-certificates.sh"
    "${PROJECT_ROOT}/scripts/setup/deploy-gitea-https.sh"
    "${PROJECT_ROOT}/scripts/setup/configure-k8s-tls.sh"
    "${PROJECT_ROOT}/scripts/deploy-ssl-infrastructure.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "${script}" && -x "${script}" ]]; then
        echo "[OK] $(basename "${script}") found and executable"
    else
        echo "[MISSING] $(basename "${script}") missing or not executable"
    fi
done

echo ""

# Check current Gitea status
echo "4. Checking Current Gitea Status..."
echo "----------------------------------"

gitea_containers=$(docker ps --filter "name=gitea" --format "{{.Names}}" 2>/dev/null || echo "")
if [[ -n "${gitea_containers}" ]]; then
    echo "[OK] Running Gitea containers: ${gitea_containers}"
else
    echo "[WARNING] No Gitea containers found running"
fi

# Test Gitea HTTP
if curl -s -f http://172.16.0.78:8888 >/dev/null 2>&1; then
    echo "[OK] Gitea HTTP endpoint is responding"
else
    echo "[WARNING] Gitea HTTP endpoint is not responding"
fi

# Test Gitea HTTPS
if curl -s -k -f https://172.16.0.78:8443 >/dev/null 2>&1; then
    echo "[OK] Gitea HTTPS endpoint is responding"
else
    echo "[INFO] Gitea HTTPS endpoint not configured (will be set up)"
fi

echo ""

# Check existing certificates
echo "5. Checking Existing Certificates..."
echo "-----------------------------------"

cert_dir="${PROJECT_ROOT}/certs"
if [[ -d "${cert_dir}" ]]; then
    echo "[OK] Certificate directory exists: ${cert_dir}"
    
    if [[ -f "${cert_dir}/nephio-ca.crt" ]]; then
        echo "[OK] CA certificate found"
    else
        echo "[INFO] CA certificate not found (will be generated)"
    fi
    
    for service in gitea k8s-edge1 k8s-edge2; do
        if [[ -f "${cert_dir}/${service}/${service}.crt" ]]; then
            echo "[OK] ${service} certificate found"
        else
            echo "[INFO] ${service} certificate not found (will be generated)"
        fi
    done
else
    echo "[INFO] Certificate directory not found (will be created)"
fi

echo ""

# Summary
echo "6. Validation Summary"
echo "====================="

# Check if environment is ready
ready=true

# Check essential prerequisites
if ! command -v openssl >/dev/null 2>&1; then
    echo "[ERROR] OpenSSL is required but not available"
    ready=false
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is required but not available"
    ready=false
fi

if ! docker ps >/dev/null 2>&1; then
    echo "[ERROR] Docker daemon is not accessible"
    ready=false
fi

if ! nc -z -w 3 172.16.0.78 8888 2>/dev/null; then
    echo "[ERROR] Gitea service is not accessible"
    ready=false
fi

if [[ ! -x "${PROJECT_ROOT}/scripts/deploy-ssl-infrastructure.sh" ]]; then
    echo "[ERROR] Main deployment script is not available"
    ready=false
fi

if [[ "${ready}" == "true" ]]; then
    echo ""
    echo "[SUCCESS] Environment is ready for SSL/TLS deployment!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./scripts/deploy-ssl-infrastructure.sh"
    echo "  2. Monitor deployment progress"
    echo "  3. Test endpoints after deployment"
    echo "  4. Update GitOps configurations"
else
    echo ""
    echo "[ERROR] Environment is NOT ready for deployment!"
    echo ""
    echo "Please fix the errors above before proceeding."
fi

echo ""
echo "For detailed deployment guide, see: docs/SSL_TLS_INFRASTRUCTURE.md"
echo ""
