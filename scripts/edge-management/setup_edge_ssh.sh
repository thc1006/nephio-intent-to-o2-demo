#!/bin/bash
# Edge Site SSH Setup Script
# Purpose: Configure SSH access for new edge sites from VM-1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SSH_KEY_PATH="${HOME}/.ssh/edge_sites_key"
SSH_CONFIG_PATH="${HOME}/.ssh/config"

usage() {
    cat << EOF
Usage: $0 <edge_name> <edge_ip> <ssh_user>

Setup SSH access for a new edge site.

Arguments:
  edge_name    Name of the edge site (e.g., edge3, edge4)
  edge_ip      IP address of the edge site (e.g., 172.16.4.200)
  ssh_user     SSH username (default: ubuntu)

Examples:
  $0 edge3 172.16.4.200 ubuntu
  $0 edge4 10.0.1.50 ubuntu

This script will:
  1. Generate SSH key pair if not exists
  2. Display public key for manual installation on edge site
  3. Update SSH config with edge site entry
  4. Test SSH connectivity
  5. Create edge site management scripts

EOF
    exit 1
}

# Parse arguments
if [ $# -lt 2 ]; then
    usage
fi

EDGE_NAME="$1"
EDGE_IP="$2"
SSH_USER="${3:-ubuntu}"

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Edge Site SSH Setup: ${EDGE_NAME}${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "  Edge Name: ${EDGE_NAME}"
echo "  Edge IP:   ${EDGE_IP}"
echo "  SSH User:  ${SSH_USER}"
echo ""

# Step 1: Generate SSH key if not exists
echo -e "${YELLOW}[Step 1/5]${NC} Checking SSH key..."
if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "Generating new SSH key pair for edge sites..."
    ssh-keygen -t ed25519 -C "vm1-edge-management" -f "${SSH_KEY_PATH}" -N ""
    echo -e "${GREEN}✓${NC} SSH key generated: ${SSH_KEY_PATH}"
else
    echo -e "${GREEN}✓${NC} SSH key exists: ${SSH_KEY_PATH}"
fi

# Step 2: Display public key for manual installation
echo ""
echo -e "${YELLOW}[Step 2/5]${NC} SSH Public Key Setup"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}IMPORTANT:${NC} Copy the following public key and add it to the edge site:"
echo ""
echo -e "${GREEN}Public Key:${NC}"
cat "${SSH_KEY_PATH}.pub"
echo ""
echo -e "${YELLOW}On the edge site (${EDGE_IP}), run:${NC}"
echo ""
echo "  ssh ${SSH_USER}@${EDGE_IP}"
echo "  mkdir -p ~/.ssh"
echo "  chmod 700 ~/.ssh"
echo "  echo '$(cat ${SSH_KEY_PATH}.pub)' >> ~/.ssh/authorized_keys"
echo "  chmod 600 ~/.ssh/authorized_keys"
echo ""
read -p "Press ENTER after you've added the public key to ${EDGE_NAME}..."

# Step 3: Update SSH config
echo ""
echo -e "${YELLOW}[Step 3/5]${NC} Updating SSH config..."

# Backup existing config
if [ -f "${SSH_CONFIG_PATH}" ]; then
    cp "${SSH_CONFIG_PATH}" "${SSH_CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Check if entry already exists
if grep -q "Host ${EDGE_NAME}" "${SSH_CONFIG_PATH}" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} Entry for ${EDGE_NAME} already exists in SSH config"
    read -p "Overwrite? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "Skipping SSH config update"
    else
        # Remove existing entry
        sed -i "/Host ${EDGE_NAME}/,/^$/d" "${SSH_CONFIG_PATH}"
        # Add new entry
        cat >> "${SSH_CONFIG_PATH}" << SSHCONFIG

# ${EDGE_NAME} - Added $(date +%Y-%m-%d)
Host ${EDGE_NAME}
  HostName ${EDGE_IP}
  User ${SSH_USER}
  IdentityFile ${SSH_KEY_PATH}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ConnectTimeout 10
  ServerAliveInterval 60
  ServerAliveCountMax 3
SSHCONFIG
        echo -e "${GREEN}✓${NC} SSH config updated"
    fi
else
    # Add new entry
    cat >> "${SSH_CONFIG_PATH}" << SSHCONFIG

# ${EDGE_NAME} - Added $(date +%Y-%m-%d)
Host ${EDGE_NAME}
  HostName ${EDGE_IP}
  User ${SSH_USER}
  IdentityFile ${SSH_KEY_PATH}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ConnectTimeout 10
  ServerAliveInterval 60
  ServerAliveCountMax 3
SSHCONFIG
    echo -e "${GREEN}✓${NC} SSH config updated"
fi

# Step 4: Test SSH connectivity
echo ""
echo -e "${YELLOW}[Step 4/5]${NC} Testing SSH connectivity..."
if ssh -o ConnectTimeout=5 ${EDGE_NAME} "echo 'SSH connection successful'; hostname; whoami" 2>&1; then
    echo -e "${GREEN}✓${NC} SSH connection successful to ${EDGE_NAME}"
else
    echo -e "${RED}✗${NC} SSH connection failed to ${EDGE_NAME}"
    echo "Please verify:"
    echo "  1. Public key is correctly added to ${EDGE_IP}:~/.ssh/authorized_keys"
    echo "  2. SSH service is running on ${EDGE_IP}"
    echo "  3. Firewall allows SSH (port 22) from VM-1"
    exit 1
fi

# Step 5: Create edge site management scripts
echo ""
echo -e "${YELLOW}[Step 5/5]${NC} Creating management scripts..."

mkdir -p "${SCRIPT_DIR}/edges"

# Create edge-specific wrapper script
cat > "${SCRIPT_DIR}/edges/${EDGE_NAME}.sh" << 'EDGESCRIPT'
#!/bin/bash
# Management script for EDGE_NAME_PLACEHOLDER
# Generated: DATE_PLACEHOLDER

EDGE_NAME="EDGE_NAME_PLACEHOLDER"
EDGE_IP="EDGE_IP_PLACEHOLDER"

# Execute command on edge site
exec_on_edge() {
    echo "→ Executing on ${EDGE_NAME} (${EDGE_IP}): $*"
    ssh ${EDGE_NAME} "$@"
}

# Copy file to edge site
copy_to_edge() {
    local src="$1"
    local dest="$2"
    echo "→ Copying ${src} to ${EDGE_NAME}:${dest}"
    scp "${src}" ${EDGE_NAME}:"${dest}"
}

# Execute script on edge site
run_script_on_edge() {
    local script="$1"
    echo "→ Running script ${script} on ${EDGE_NAME}"
    ssh ${EDGE_NAME} 'bash -s' < "${script}"
}

# Main command dispatcher
case "${1:-}" in
    exec|run)
        shift
        exec_on_edge "$@"
        ;;
    copy|scp)
        shift
        copy_to_edge "$@"
        ;;
    script)
        shift
        run_script_on_edge "$@"
        ;;
    shell|ssh)
        ssh ${EDGE_NAME}
        ;;
    status)
        echo "Edge Site Status: ${EDGE_NAME}"
        echo "═══════════════════════════════════════"
        exec_on_edge "
            echo 'Hostname:    \$(hostname)'
            echo 'Uptime:      \$(uptime -p)'
            echo 'Kernel:      \$(uname -r)'
            echo 'Memory:      \$(free -h | grep Mem | awk \"{print \\\$3\\\"/\\\"\\\$2}\")'
            echo 'Disk:        \$(df -h / | tail -1 | awk \"{print \\\$3\\\"/\\\"\\\$2\\\" (\\\"\\\$5\\\")}\")'"
        ;;
    k8s)
        echo "Kubernetes Status on ${EDGE_NAME}"
        echo "═══════════════════════════════════════"
        exec_on_edge "kubectl cluster-info && kubectl get nodes && kubectl get pods -A"
        ;;
    *)
        cat << EOF
Usage: $0 <command> [args...]

Commands:
  exec|run <cmd>        Execute command on edge site
  copy|scp <src> <dst>  Copy file to edge site
  script <file>         Run local script on edge site
  shell|ssh             Open SSH shell to edge site
  status                Display edge site status
  k8s                   Display Kubernetes status

Examples:
  $0 exec "df -h"
  $0 copy ./config.yaml /etc/config.yaml
  $0 script ./setup.sh
  $0 shell
  $0 status
  $0 k8s
EOF
        exit 1
        ;;
esac
EDGESCRIPT

# Replace placeholders
sed -i "s/EDGE_NAME_PLACEHOLDER/${EDGE_NAME}/g" "${SCRIPT_DIR}/edges/${EDGE_NAME}.sh"
sed -i "s/EDGE_IP_PLACEHOLDER/${EDGE_IP}/g" "${SCRIPT_DIR}/edges/${EDGE_NAME}.sh"
sed -i "s/DATE_PLACEHOLDER/$(date +%Y-%m-%d)/g" "${SCRIPT_DIR}/edges/${EDGE_NAME}.sh"

chmod +x "${SCRIPT_DIR}/edges/${EDGE_NAME}.sh"

echo -e "${GREEN}✓${NC} Created management script: ${SCRIPT_DIR}/edges/${EDGE_NAME}.sh"

# Update edge sites registry
REGISTRY_FILE="${PROJECT_ROOT}/config/edge-sites-registry.yaml"
mkdir -p "$(dirname ${REGISTRY_FILE})"

if [ ! -f "${REGISTRY_FILE}" ]; then
    cat > "${REGISTRY_FILE}" << REGHEADER
# Edge Sites Registry
# Auto-generated and maintained by setup_edge_ssh.sh
---
edgeSites:
REGHEADER
fi

# Add or update entry
if grep -q "name: ${EDGE_NAME}" "${REGISTRY_FILE}"; then
    echo -e "${YELLOW}⚠${NC} ${EDGE_NAME} already in registry"
else
    cat >> "${REGISTRY_FILE}" << REGENTRY
  - name: ${EDGE_NAME}
    ip: ${EDGE_IP}
    user: ${SSH_USER}
    sshAlias: ${EDGE_NAME}
    k8sApiPort: 6443
    prometheusPort: 30090
    o2imsPort: 31280
    addedDate: $(date +%Y-%m-%d)
    status: active
REGENTRY
    echo -e "${GREEN}✓${NC} Added ${EDGE_NAME} to edge sites registry"
fi

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo "Edge Site: ${EDGE_NAME}"
echo "IP:        ${EDGE_IP}"
echo "User:      ${SSH_USER}"
echo ""
echo "Management Commands:"
echo "  Direct SSH:        ssh ${EDGE_NAME}"
echo "  Management Script: ${SCRIPT_DIR}/edges/${EDGE_NAME}.sh"
echo "  Registry:          ${REGISTRY_FILE}"
echo ""
echo "Quick Tests:"
echo "  ./scripts/edge-management/edges/${EDGE_NAME}.sh status"
echo "  ./scripts/edge-management/edges/${EDGE_NAME}.sh k8s"
echo "  ./scripts/edge-management/edges/${EDGE_NAME}.sh exec 'uname -a'"
echo ""
echo -e "${GREEN}✓${NC} You can now use SSH to control ${EDGE_NAME} from Claude Code"