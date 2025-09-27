# Edge Site Management Framework

This framework enables Claude Code to control edge sites via SSH from VM-1.

## 🎯 Overview

**Architecture**:
```
VM-1 (Orchestrator)
  ↓ SSH with key-based auth
Edge Sites (edge1, edge2, edge3, ...)
  ↓ Pull GitOps configs
Deployments
```

## 🚀 Quick Start

### Add New Edge Site

```bash
# Syntax
./scripts/edge-management/setup_edge_ssh.sh <edge_name> <edge_ip> [ssh_user]

# Examples
./scripts/edge-management/setup_edge_ssh.sh edge3 172.16.4.200 ubuntu
./scripts/edge-management/setup_edge_ssh.sh edge4 10.0.1.50 ubuntu
```

### What It Does

1. ✅ Generates SSH key pair (`~/.ssh/edge_sites_key`)
2. ✅ Displays public key for manual installation on edge site
3. ✅ Updates `~/.ssh/config` with edge site entry
4. ✅ Tests SSH connectivity
5. ✅ Creates edge-specific management script
6. ✅ Registers edge site in `config/edge-sites-registry.yaml`

## 📋 Manual Steps on Edge Site

After running setup script, you need to add the public key to the edge site:

```bash
# On edge site (e.g., edge3)
ssh ubuntu@172.16.4.200

# Create .ssh directory if not exists
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add public key (copy from VM-1 output)
echo 'ssh-ed25519 AAAA...your-public-key... vm1-edge-management' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Verify
cat ~/.ssh/authorized_keys
```

## 🔧 Usage

### Direct SSH Access

```bash
# SSH config alias (recommended)
ssh edge3

# Or full command
ssh -i ~/.ssh/edge_sites_key ubuntu@172.16.4.200
```

### Management Script

Each edge site gets a dedicated management script:

```bash
# Location
./scripts/edge-management/edges/<edge_name>.sh

# Commands
./scripts/edge-management/edges/edge3.sh status      # System status
./scripts/edge-management/edges/edge3.sh k8s         # Kubernetes status
./scripts/edge-management/edges/edge3.sh shell       # Open SSH shell
./scripts/edge-management/edges/edge3.sh exec "cmd"  # Run command
./scripts/edge-management/edges/edge3.sh copy src dst # Copy file
./scripts/edge-management/edges/edge3.sh script file.sh # Run script
```

### Examples

```bash
# Check system status
./scripts/edge-management/edges/edge3.sh status

# Check Kubernetes cluster
./scripts/edge-management/edges/edge3.sh k8s

# Execute command
./scripts/edge-management/edges/edge3.sh exec "df -h"
./scripts/edge-management/edges/edge3.sh exec "kubectl get pods -A"

# Copy file
./scripts/edge-management/edges/edge3.sh copy ./config.yaml /tmp/config.yaml

# Run local script on edge
./scripts/edge-management/edges/edge3.sh script ./scripts/setup/install-k8s.sh

# Open interactive shell
./scripts/edge-management/edges/edge3.sh shell
```

## 🗂️ Edge Sites Registry

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

**Query Registry**:
```bash
# List all edge sites
cat config/edge-sites-registry.yaml

# Get specific edge IP
yq '.edgeSites[] | select(.name == "edge3") | .ip' config/edge-sites-registry.yaml
```

## 🔐 SSH Configuration

**SSH Config Location**: `~/.ssh/config`

**Example Entry**:
```
# edge3 - Added 2025-09-26
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

## 🧪 Testing Connectivity

```bash
# Test basic SSH
ssh edge3 "echo 'Connection OK'; hostname"

# Test with management script
./scripts/edge-management/edges/edge3.sh status

# Test Kubernetes access
./scripts/edge-management/edges/edge3.sh k8s

# Test file copy
echo "test" > /tmp/test.txt
./scripts/edge-management/edges/edge3.sh copy /tmp/test.txt /tmp/test.txt
./scripts/edge-management/edges/edge3.sh exec "cat /tmp/test.txt"
```

## 🛠️ Claude Code Integration

When Claude Code needs to manage edge sites:

```bash
# In conversation, I can now execute:

# Check edge status
ssh edge3 "kubectl get nodes"

# Deploy configuration
ssh edge3 "kubectl apply -f https://raw.githubusercontent.com/.../config.yaml"

# Copy files
scp ./config.yaml edge3:/etc/kubernetes/config.yaml

# Run scripts
ssh edge3 'bash -s' < ./scripts/setup-edge.sh

# Use management wrapper
./scripts/edge-management/edges/edge3.sh k8s
```

## 🔄 GitOps Workflow

**Recommended Flow**:

1. **Claude Code** generates configuration on VM-1
2. **Gitea** stores configuration in repository
3. **Edge Site** pulls configuration via Config Sync
4. **SSH** used only for:
   - Initial setup
   - Troubleshooting
   - Emergency operations

**GitOps Pull Setup**:
```bash
# Initialize Config Sync on edge site
./scripts/edge-management/edges/edge3.sh exec "
kubectl apply -f - << 'EOF'
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
EOF
"
```

## 🚨 Troubleshooting

### SSH Connection Fails

```bash
# Check SSH config
cat ~/.ssh/config | grep -A 10 "Host edge3"

# Check SSH key
ls -la ~/.ssh/edge_sites_key*

# Test connection with verbose
ssh -v edge3

# Check from edge site
ssh edge3 "cat ~/.ssh/authorized_keys"
```

### Permission Denied

```bash
# On edge site, fix permissions
ssh edge3 "
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R \$(whoami):\$(whoami) ~/.ssh
"
```

### Timeout / Connection Refused

```bash
# Check network connectivity
ping 172.16.4.200

# Check SSH service on edge
ssh edge3 "sudo systemctl status sshd"

# Check firewall (from edge)
ssh edge3 "sudo ufw status"
```

## 📚 Related Documentation

- **Network Config**: `docs/network/AUTHORITATIVE_NETWORK_CONFIG.md`
- **GitOps Setup**: `templates/configsync-root.yaml`
- **Edge Deployment**: `docs/architecture/THREE_VM_INTEGRATION_PLAN.md`
- **CLAUDE.md**: Root project guidelines

## 🎯 Next Steps After Setup

1. **Verify SSH**: `ssh edge3 "hostname; whoami"`
2. **Check Kubernetes**: `./scripts/edge-management/edges/edge3.sh k8s`
3. **Setup GitOps**: Deploy Config Sync to pull from Gitea
4. **Deploy Monitoring**: Setup Prometheus with remote_write to VM-1
5. **Test Intent**: Deploy test intent to verify end-to-end flow

## 💡 Best Practices

1. **Use SSH Config Aliases** - Cleaner and easier to manage
2. **Key-Based Auth Only** - Never use passwords
3. **Limit SSH Usage** - Prefer GitOps pull for deployment
4. **Monitor Access** - Track SSH sessions via audit logs
5. **Regular Key Rotation** - Rotate keys every 90 days
6. **Backup Keys** - Store keys securely in password manager

## 🔒 Security Notes

- SSH keys stored in `~/.ssh/edge_sites_key` (private key)
- Public key must be manually added to edge sites
- `StrictHostKeyChecking no` for automation (adjust for production)
- Consider using jump host / bastion for production
- Implement key rotation policy
- Use separate keys for different environments

---

**Status**: Ready for use
**Last Updated**: 2025-09-26
**Maintainer**: Orchestrator (Claude Code)