# Edge Site SSH Control Guide

**Purpose**: Enable Claude Code to control edge sites via SSH for automation and troubleshooting

---

## 🎯 Overview

This guide explains how to configure SSH access so Claude Code (running on VM-1) can control edge sites for:
- Initial edge site setup
- Emergency troubleshooting
- System status monitoring
- Kubernetes operations

**GitOps Principle**: SSH is used for setup and emergency operations only. Normal deployments use GitOps pull model.

---

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Run setup script for new edge site
./scripts/edge-management/setup_edge_ssh.sh edge3 172.16.4.200 ubuntu

# Follow prompts to add public key to edge site
# Script will create everything needed automatically
```

### Option 2: Manual Setup

See "Manual Configuration" section below.

---

## 📋 Prerequisites

**On VM-1 (Orchestrator)**:
- SSH client installed (`ssh`, `scp`)
- Bash shell access
- Network connectivity to edge sites

**On Edge Site**:
- SSH server running (`sshd`)
- User account with sudo access
- Network connectivity to VM-1
- Firewall allows SSH (port 22) from VM-1

---

## 🔧 Automated Setup Process

### Step 1: Run Setup Script

```bash
cd /home/ubuntu/nephio-intent-to-o2-demo

./scripts/edge-management/setup_edge_ssh.sh edge3 172.16.4.200 ubuntu
```

**Parameters**:
- `edge3` - Edge site name (used as SSH alias)
- `172.16.4.200` - Edge site IP address
- `ubuntu` - SSH username on edge site

### Step 2: Install Public Key on Edge Site

The script will display a public key. Copy it and run on the edge site:

```bash
# SSH to edge site
ssh ubuntu@172.16.4.200

# Add public key
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAA...your-public-key... vm1-edge-management' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Step 3: Verify Connection

```bash
# Test SSH connection
ssh edge3 "hostname; whoami"

# Test management script
./scripts/edge-management/edges/edge3.sh status
```

---

## 🗂️ What Gets Created

### 1. SSH Key Pair

**Location**: `~/.ssh/edge_sites_key` (private), `~/.ssh/edge_sites_key.pub` (public)

**Type**: ED25519 (modern, secure, fast)

**Usage**: Authentication to all edge sites

### 2. SSH Config Entry

**Location**: `~/.ssh/config`

**Example**:
```
Host edge3
  HostName 172.16.4.200
  User ubuntu
  IdentityFile /home/ubuntu/.ssh/edge_sites_key
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ConnectTimeout 10
  ServerAliveInterval 60
  ServerAliveCountMax 3
```

### 3. Management Script

**Location**: `scripts/edge-management/edges/edge3.sh`

**Capabilities**:
- Execute commands on edge site
- Copy files to edge site
- Run scripts on edge site
- Open SSH shell
- Check system status
- Check Kubernetes status

### 4. Registry Entry

**Location**: `config/edge-sites-registry.yaml`

**Format**:
```yaml
edgeSites:
  - name: edge3
    ip: 172.16.4.200
    user: ubuntu
    sshAlias: edge3
    k8sApiPort: 6443
    prometheusPort: 30090
    o2imsPort: 31280
    addedDate: 2025-09-26
    status: active
```

---

## 🎮 Usage Examples

### Basic SSH Commands

```bash
# Direct SSH (using alias)
ssh edge3

# Execute single command
ssh edge3 "hostname"

# Execute multiple commands
ssh edge3 "cd /tmp && ls -la"

# Copy file to edge
scp ./config.yaml edge3:/tmp/config.yaml

# Copy file from edge
scp edge3:/tmp/data.json ./data.json
```

### Using Management Script

```bash
# System status
./scripts/edge-management/edges/edge3.sh status

# Kubernetes status
./scripts/edge-management/edges/edge3.sh k8s

# Execute command
./scripts/edge-management/edges/edge3.sh exec "df -h"
./scripts/edge-management/edges/edge3.sh exec "free -h"
./scripts/edge-management/edges/edge3.sh exec "kubectl get pods -A"

# Copy file
./scripts/edge-management/edges/edge3.sh copy ./deploy.yaml /tmp/deploy.yaml

# Run local script on edge
./scripts/edge-management/edges/edge3.sh script ./scripts/setup-monitoring.sh

# Open interactive shell
./scripts/edge-management/edges/edge3.sh shell
```

### Claude Code Integration

When I (Claude Code) need to manage edge sites in conversation:

```bash
# Check edge site status
ssh edge3 "kubectl cluster-info && kubectl get nodes"

# Deploy configuration
ssh edge3 "kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: test
EOF"

# Copy and apply manifest
scp ./manifest.yaml edge3:/tmp/manifest.yaml
ssh edge3 "kubectl apply -f /tmp/manifest.yaml"

# Run initialization script
ssh edge3 'bash -s' < ./scripts/init-edge.sh

# Use wrapper for complex operations
./scripts/edge-management/edges/edge3.sh exec "
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/.../prometheus.yaml
"
```

---

## 🔄 GitOps Integration

### Principle

**SSH is for setup/emergency only. Normal operations use GitOps pull.**

### Setup GitOps on Edge

```bash
# Initialize Config Sync on edge site
ssh edge3 'kubectl apply -f - << EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/nephio/deployments
    branch: main
    dir: clusters/edge3
    auth: token
    secretRef:
      name: gitea-token
EOF'

# Verify sync status
ssh edge3 "kubectl get rootsync -n config-management-system"
```

### Workflow

```
┌─────────────────────────────────────────────────────────┐
│ VM-1 (Orchestrator)                                      │
│                                                          │
│  Claude Code → Generate Config → Push to Gitea          │
│       ↓ (SSH for setup/emergency only)                  │
└───────┼──────────────────────────────────────────────────┘
        │
        │ GitOps Pull (Config Sync)
        ↓
┌─────────────────────────────────────────────────────────┐
│ Edge Site (edge3)                                        │
│                                                          │
│  Config Sync → Pull from Gitea → Apply to Kubernetes    │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠️ Manual Configuration

If you prefer manual setup instead of using the script:

### 1. Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "vm1-edge-management" -f ~/.ssh/edge_sites_key -N ""
```

### 2. Add Public Key to Edge Site

```bash
# Copy public key
cat ~/.ssh/edge_sites_key.pub

# On edge site
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '<paste-public-key-here>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3. Update SSH Config

Add to `~/.ssh/config`:

```
Host edge3
  HostName 172.16.4.200
  User ubuntu
  IdentityFile /home/ubuntu/.ssh/edge_sites_key
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

### 4. Test Connection

```bash
ssh edge3 "hostname"
```

---

## 🚨 Troubleshooting

### Problem: Permission Denied

```bash
# Check key permissions on VM-1
ls -la ~/.ssh/edge_sites_key
chmod 600 ~/.ssh/edge_sites_key  # If wrong

# Check authorized_keys on edge
ssh edge3 "ls -la ~/.ssh/authorized_keys"
ssh edge3 "chmod 600 ~/.ssh/authorized_keys"  # If wrong
```

### Problem: Connection Timeout

```bash
# Test network connectivity
ping -c 3 172.16.4.200

# Check SSH service on edge
ssh edge3 "sudo systemctl status sshd"

# Check firewall
ssh edge3 "sudo ufw status"
```

### Problem: Host Key Verification Failed

```bash
# Remove old host key
ssh-keygen -R 172.16.4.200
ssh-keygen -R edge3

# Try again
ssh edge3 "hostname"
```

### Problem: Agent Connection Failed

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add key
ssh-add ~/.ssh/edge_sites_key

# List loaded keys
ssh-add -l
```

---

## 🔒 Security Best Practices

### 1. Use Key-Based Authentication

✅ **DO**: Use SSH keys
❌ **DON'T**: Use password authentication

### 2. Limit Key Scope

- Use separate keys for different environments (dev/staging/prod)
- Use separate keys for different purposes (setup/operations)
- Rotate keys regularly (every 90 days)

### 3. Principle of Least Privilege

```bash
# Create dedicated user on edge site
sudo useradd -m -s /bin/bash nephio-ops
sudo usermod -aG docker nephio-ops  # If needed

# Add public key to nephio-ops
sudo -u nephio-ops bash -c '
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
'
```

### 4. SSH Hardening

On edge sites, edit `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
AllowUsers ubuntu nephio-ops
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

### 5. Audit Logging

```bash
# Enable SSH logging on edge sites
sudo auditctl -w /home -p wa -k ssh_changes

# View SSH access logs
sudo journalctl -u sshd -f
```

---

## 📊 Monitoring SSH Access

### Log SSH Sessions

```bash
# On VM-1, log all SSH commands
cat >> ~/.bashrc << 'EOF'
# Log SSH commands
ssh() {
    echo "[$(date)] SSH to $@" >> ~/.ssh_access.log
    command ssh "$@"
}
EOF

source ~/.bashrc
```

### View Access Log

```bash
tail -f ~/.ssh_access.log
```

---

## 🔄 Key Rotation

### Every 90 Days

```bash
# 1. Generate new key
ssh-keygen -t ed25519 -C "vm1-edge-management-$(date +%Y%m)" -f ~/.ssh/edge_sites_key.new -N ""

# 2. Add new public key to all edge sites
for edge in edge1 edge2 edge3 edge4; do
    ssh $edge "echo '$(cat ~/.ssh/edge_sites_key.new.pub)' >> ~/.ssh/authorized_keys"
done

# 3. Test new key
ssh -i ~/.ssh/edge_sites_key.new edge3 "hostname"

# 4. Replace old key
mv ~/.ssh/edge_sites_key ~/.ssh/edge_sites_key.old
mv ~/.ssh/edge_sites_key.new ~/.ssh/edge_sites_key
mv ~/.ssh/edge_sites_key.new.pub ~/.ssh/edge_sites_key.pub

# 5. Remove old public key from edge sites
for edge in edge1 edge2 edge3 edge4; do
    ssh $edge "grep -v '$(cat ~/.ssh/edge_sites_key.old.pub)' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.new && mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys"
done
```

---

## 📚 Related Documentation

- **Setup Script**: `scripts/edge-management/setup_edge_ssh.sh`
- **README**: `scripts/edge-management/README.md`
- **Network Config**: `docs/network/AUTHORITATIVE_NETWORK_CONFIG.md`
- **GitOps Setup**: `templates/configsync-root.yaml`
- **CLAUDE.md**: Project guidelines

---

## ✅ Checklist

After setup, verify:

- [ ] SSH key pair created
- [ ] Public key added to edge site
- [ ] SSH config updated
- [ ] Can SSH to edge site: `ssh edge3 "hostname"`
- [ ] Management script created
- [ ] Management script works: `./scripts/edge-management/edges/edge3.sh status`
- [ ] Edge site added to registry
- [ ] GitOps configured (Config Sync)
- [ ] Can deploy via GitOps
- [ ] Monitoring configured (Prometheus remote_write)

---

**Status**: Production Ready
**Last Updated**: 2025-09-26
**Maintainer**: Orchestrator (Claude Code)