# Security Documentation

**Version**: 1.2.0
**Last Updated**: 2025-09-27
**Status**: Production Ready - 4 Edge Sites Operational

## Overview

This document outlines comprehensive security measures, access controls, and compliance requirements for the multi-site O-RAN deployment with Nephio GitOps orchestration across VM-1 (SMO/Orchestrator) and 4 operational edge sites.

**Security Architecture v1.2.0:**
- VM-1 (SMO): 172.16.0.78 - Zero-trust orchestrator with TMF921 Adapter, Gitea, WebSocket services
- Edge1: 172.16.4.45 - SSH key-based authentication (ubuntu user)
- Edge2: 172.16.4.176 - SSH key-based authentication (ubuntu user)
- Edge3: 172.16.5.81 - Enhanced SSH authentication (thc1006 user + password)
- Edge4: 172.16.1.252 - Enhanced SSH authentication (thc1006 user + password)

---

## 1. Access Control

### 1.1 LLM Adapter IP Whitelist Configuration

**Critical Ports Security Matrix (v1.2.0):**
| Port | Service | Protocol | Security Level | Access Control |
|------|---------|----------|----------------|----------------|
| 6443 | K8s API | HTTPS | Critical | mTLS + RBAC (all sites) |
| 8889 | TMF921 Adapter | HTTP | Critical | Automated authentication bypass |
| 8888 | Gitea Repository | HTTP | High | SSH key + IP whitelist |
| 8002 | Claude Headless | WebSocket | Medium | Internal network only |
| 8003 | Realtime Monitor | WebSocket | Medium | Internal network only |
| 8004 | TMux Bridge | WebSocket | Medium | Internal network only |
| 31280 | Edge1 O2IMS | HTTP | High | Zero-trust networking |
| 31281 | Edge2 O2IMS | HTTP | High | Zero-trust networking |
| 32080 | Edge3/4 O2IMS | HTTP | High | Zero-trust networking |
| 30090 | Prometheus | HTTP | Medium | Metrics collection (all sites) |
| 22 | SSH | SSH | Critical | Multi-key authentication strategy |

**Whitelist Implementation (v1.2.0):**
```bash
# /etc/security/tmf921-adapter-whitelist.conf
# VM-1 SMO Controller (self)
172.16.0.78/32
# Edge1 Cluster (VM-2)
172.16.4.45/32
# Edge2 Cluster (VM-4) - CORRECTED IP
172.16.4.176/32
# Edge3 Cluster
172.16.5.81/32
# Edge4 Cluster
172.16.1.252/32
# Internal cluster networks
10.244.0.0/16
# Service mesh networks
172.17.0.0/16
# Management networks
192.168.1.0/24
```

**iptables Rules for 4-Site Security (VM-1):**
```bash
#!/bin/bash
# Apply TMF921 adapter security rules for port 8889 (automated mode)
iptables -A INPUT -p tcp --dport 8889 -s 172.16.0.78 -j ACCEPT   # VM-1 (self)
iptables -A INPUT -p tcp --dport 8889 -s 172.16.4.45 -j ACCEPT   # Edge1
iptables -A INPUT -p tcp --dport 8889 -s 172.16.4.176 -j ACCEPT  # Edge2 (corrected IP)
iptables -A INPUT -p tcp --dport 8889 -s 172.16.5.81 -j ACCEPT   # Edge3
iptables -A INPUT -p tcp --dport 8889 -s 172.16.1.252 -j ACCEPT  # Edge4
iptables -A INPUT -p tcp --dport 8889 -j DROP  # Deny all others

# Secure Gitea repository (port 8888)
iptables -A INPUT -p tcp --dport 8888 -s 172.16.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 8888 -j DROP

# WebSocket services (internal only)
iptables -A INPUT -p tcp --dport 8002 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 8003 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 8004 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 8002:8004 -j DROP

# Secure O2IMS endpoints (multiple ports per site)
iptables -A INPUT -p tcp --dport 31280 -s 172.16.0.0/16 -j ACCEPT  # Edge1
iptables -A INPUT -p tcp --dport 31281 -s 172.16.0.0/16 -j ACCEPT  # Edge2
iptables -A INPUT -p tcp --dport 32080 -s 172.16.0.0/16 -j ACCEPT  # Edge3/4
iptables -A INPUT -p tcp --dport 31280:32080 -j DROP

# Secure Prometheus metrics (port 30090 on all sites)
iptables -A INPUT -p tcp --dport 30090 -s 172.16.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 30090 -j DROP

# Allow internal cluster communication
iptables -A INPUT -s 10.244.0.0/16 -j ACCEPT
iptables -A INPUT -s 172.17.0.0/16 -j ACCEPT

# Log dropped connections
iptables -A INPUT -j LOG --log-prefix "DROPPED: "
iptables -A INPUT -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### 1.2 Rate Limiting Implementation

**TMF921 Adapter Rate Limiting (requests/minute):**
```yaml
# /etc/nginx/sites-available/tmf921-adapter-proxy
upstream tmf921_backend {
    server localhost:8889;
}

server {
    listen 80;
    server_name tmf921-adapter.local;

    # Rate limiting zones (4 sites)
    limit_req_zone $remote_addr zone=vm1:10m rate=50r/m;     # VM-1 self
    limit_req_zone $remote_addr zone=edge1:10m rate=30r/m;   # Edge1
    limit_req_zone $remote_addr zone=edge2:10m rate=30r/m;   # Edge2
    limit_req_zone $remote_addr zone=edge3:10m rate=25r/m;   # Edge3
    limit_req_zone $remote_addr zone=edge4:10m rate=25r/m;   # Edge4
    limit_req_zone $remote_addr zone=general:10m rate=10r/m;

    location /api/v1/intent/transform {
        # Apply different limits based on source (4 sites)
        if ($remote_addr = "172.16.0.78") {
            limit_req zone=vm1 burst=15 nodelay;
        }
        if ($remote_addr = "172.16.4.45") {
            limit_req zone=edge1 burst=10 nodelay;
        }
        if ($remote_addr = "172.16.4.176") {
            limit_req zone=edge2 burst=10 nodelay;
        }
        if ($remote_addr = "172.16.5.81") {
            limit_req zone=edge3 burst=8 nodelay;
        }
        if ($remote_addr = "172.16.1.252") {
            limit_req zone=edge4 burst=8 nodelay;
        }
        limit_req zone=general burst=2 nodelay;

        proxy_pass http://tmf921_backend;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

**Kubernetes Rate Limiting with Istio:**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: tmf921-adapter-rate-limit
  namespace: tmf921-system
spec:
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          stat_prefix: tmf921_adapter_rate_limiter
          token_bucket:
            max_tokens: 100
            tokens_per_fill: 60
            fill_interval: 60s
          filter_enabled:
            runtime_key: tmf921_adapter_rate_limit_enabled
            default_value:
              numerator: 100
              denominator: HUNDRED
```

### 1.3 Authentication/Authorization Matrix

| Component | Authentication | Authorization | Ports | Access Level |
|-----------|---------------|---------------|-------|-------------|
| **VM-1 SMO** | mTLS + JWT | RBAC | 6443 (K8s API) | cluster-admin |
| **VM-2 Edge1** | mTLS + JWT | RBAC | 6443, 31080, 31443, 31280 | site-admin |
| **VM-1 LLM** | API Key + IP Whitelist | Rate Limiting | 8888 | intent-processor |
| **VM-4 Edge2** | mTLS + JWT | RBAC | 6443, 31080, 31443, 31280 | site-admin |
| **E2 Interface** | mTLS | Certificate-based | 36421 | e2-operator |
| **A1 Interface** | OAuth2 | RBAC | 9001 | policy-manager |
| **O1 Interface** | SSH Keys + NETCONF ACM | Rule-based | 830, 22 | config-manager |
| **O2 Interface** | OAuth2 + mTLS | Resource-based | 443 | resource-admin |

**RBAC Configuration Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: smo-orchestrator
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps", "extensions"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["*"]
- apiGroups: ["porch.kpt.dev"]
  resources: ["packagerevisions"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: edge-site-admin
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list"]
```

---

## 2. Network Security

### 2.1 Complete Port Mapping

| VM | Service | Port | Protocol | Purpose | Security |
|----|---------|------|----------|---------|----------|
| **VM-1** | Kubernetes API | 6443 | TCP/TLS | Cluster management | mTLS + RBAC |
| **VM-1** | Gitea SSH | 22 | TCP/SSH | Git operations | SSH keys |
| **VM-1** | Gitea HTTP | 3000 | TCP/HTTP | Web interface | Basic auth |
| **VM-2** | Kubernetes API | 6443 | TCP/TLS | Edge1 cluster | mTLS + RBAC |
| **VM-2** | NodePort HTTP | 31080 | TCP/HTTP | Edge services | Network policies |
| **VM-2** | NodePort HTTPS | 31443 | TCP/HTTPS | Edge services (secure) | TLS + certificates |
| **VM-2** | O2IMS API | 31280 | TCP/HTTP | O-Cloud interface | OAuth2 + rate limiting |
| **VM-1** | LLM Adapter | 8888 | TCP/HTTP | Intent processing | IP whitelist + API keys |
| **VM-4** | Kubernetes API | 6443 | TCP/TLS | Edge2 cluster | mTLS + RBAC |
| **VM-4** | NodePort HTTP | 31080 | TCP/HTTP | Edge services | Network policies |
| **VM-4** | NodePort HTTPS | 31443 | TCP/HTTPS | Edge services (secure) | TLS + certificates |
| **VM-4** | O2IMS API | 31280 | TCP/HTTP | O-Cloud interface | OAuth2 + rate limiting |
| **O-RAN** | E2 Interface | 36421 | TCP/SCTP | RAN control | mTLS + certificates |
| **O-RAN** | A1 Interface | 9001 | TCP/HTTP | Policy management | OAuth2 + JWT |
| **O-RAN** | O1 Interface | 830 | TCP | NETCONF management | SSH + ACM |

### 2.2 Firewall Rules and Network Policies

**VM-1 SMO Firewall Rules:**
```bash
#!/bin/bash
# VM-1 SMO firewall configuration
iptables -F
iptables -X

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH access (restrict to admin networks)
iptables -A INPUT -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT

# Kubernetes API (VM-2, VM-4)
iptables -A INPUT -p tcp --dport 6443 -s 172.16.4.45 -j ACCEPT
iptables -A INPUT -p tcp --dport 6443 -s <VM4_IP> -j ACCEPT

# Gitea access
iptables -A INPUT -p tcp --dport 3000 -s 172.16.4.0/24 -j ACCEPT

# Allow outbound to edge clusters
iptables -A OUTPUT -p tcp --dport 6443 -d 172.16.4.45 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 6443 -d <VM4_IP> -j ACCEPT
iptables -A OUTPUT -p tcp --dport 31080 -d 172.16.4.45 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 31080 -d <VM4_IP> -j ACCEPT
iptables -A OUTPUT -p tcp --dport 31280 -d 172.16.4.45 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 31280 -d <VM4_IP> -j ACCEPT

# Allow outbound to LLM adapter
iptables -A OUTPUT -p tcp --dport 8888 -d <VM1_IP> -j ACCEPT

# Drop all other inbound traffic
iptables -A INPUT -j DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Save configuration
iptables-save > /etc/iptables/rules.v4
```

**Kubernetes Network Policies:**
```yaml
# Default deny-all policy for O-RAN namespaces
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: oran
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow O-RAN interface traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oran-interfaces
  namespace: oran
spec:
  podSelector:
    matchLabels:
      app: oran-component
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: nonrtric
    - namespaceSelector:
        matchLabels:
          name: oran
    ports:
    - protocol: TCP
      port: 36421  # E2
    - protocol: TCP
      port: 9001   # A1
    - protocol: TCP
      port: 830    # O1 NETCONF
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: nonrtric
    - namespaceSelector:
        matchLabels:
          name: oran
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8080
  - to: []  # Allow DNS
    ports:
    - protocol: UDP
      port: 53
---
# SMO to edge clusters communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: smo-edge-communication
  namespace: nephio-system
spec:
  podSelector:
    matchLabels:
      app: config-sync
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # Git over HTTPS
    - protocol: TCP
      port: 22   # Git over SSH
    - protocol: TCP
      port: 6443 # Kubernetes API
```

### 2.3 TLS/SSL Certificate Management

**Certificate Authority Setup:**
```bash
#!/bin/bash
# Create root CA for multi-site deployment
mkdir -p /etc/ssl/oran-ca
cd /etc/ssl/oran-ca

# Generate CA private key
openssl genrsa -aes256 -out ca-key.pem 4096

# Generate CA certificate
openssl req -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem \
  -subj "/C=US/ST=CA/L=San Francisco/O=O-RAN Alliance/OU=Security/CN=O-RAN Root CA"

# Generate server certificates for each VM
for vm in vm1-smo vm2-edge1 vm4-edge2; do
  # Generate private key
  openssl genrsa -out ${vm}-key.pem 4096

  # Generate certificate signing request
  openssl req -subj "/CN=${vm}.oran.local" -sha256 -new -key ${vm}-key.pem -out ${vm}.csr

  # Create extensions file
  cat > ${vm}-extfile.cnf <<EOF
subjectAltName = DNS:${vm}.oran.local,DNS:${vm},IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

  # Generate signed certificate
  openssl x509 -req -days 365 -sha256 -in ${vm}.csr -CA ca.pem -CAkey ca-key.pem \
    -out ${vm}-cert.pem -extfile ${vm}-extfile.cnf -CAcreateserial

  # Clean up
  rm ${vm}.csr ${vm}-extfile.cnf
done

# Set proper permissions
chmod 400 ca-key.pem *-key.pem
chmod 444 ca.pem *-cert.pem
```

**Kubernetes TLS Secrets:**
```bash
#!/bin/bash
# Create TLS secrets in each cluster

# VM-1 SMO
kubectl create secret tls smo-tls-cert \
  --cert=/etc/ssl/oran-ca/vm1-smo-cert.pem \
  --key=/etc/ssl/oran-ca/vm1-smo-key.pem \
  -n nephio-system

# VM-2 Edge1
kubectl --kubeconfig=edge1-kubeconfig create secret tls edge1-tls-cert \
  --cert=/etc/ssl/oran-ca/vm2-edge1-cert.pem \
  --key=/etc/ssl/oran-ca/vm2-edge1-key.pem \
  -n oran

# VM-4 Edge2
kubectl --kubeconfig=edge2-kubeconfig create secret tls edge2-tls-cert \
  --cert=/etc/ssl/oran-ca/vm4-edge2-cert.pem \
  --key=/etc/ssl/oran-ca/vm4-edge2-key.pem \
  -n oran

# Create CA secret for verification
kubectl create secret generic ca-certificates \
  --from-file=ca.crt=/etc/ssl/oran-ca/ca.pem \
  -n nephio-system
```

**Certificate Rotation Script:**
```bash
#!/bin/bash
# /usr/local/bin/rotate-oran-certs.sh
# Automated certificate rotation for O-RAN deployment

CERT_DIR="/etc/ssl/oran-ca"
RENEWAL_DAYS=30
LOG_FILE="/var/log/cert-rotation.log"

check_cert_expiry() {
  local cert_file="$1"
  local days_left=$(openssl x509 -in "$cert_file" -noout -checkend $((RENEWAL_DAYS * 24 * 3600)) && echo "valid" || echo "expires_soon")
  echo "$days_left"
}

rotate_certificates() {
  echo "$(date): Starting certificate rotation" >> "$LOG_FILE"

  for vm_cert in ${CERT_DIR}/vm*-cert.pem; do
    vm_name=$(basename "$vm_cert" -cert.pem)

    if [[ $(check_cert_expiry "$vm_cert") == "expires_soon" ]]; then
      echo "$(date): Rotating certificate for $vm_name" >> "$LOG_FILE"

      # Generate new certificate (reuse existing CSR process)
      # ... certificate generation logic ...

      # Update Kubernetes secrets
      case "$vm_name" in
        "vm1-smo")
          kubectl create secret tls smo-tls-cert --cert="$vm_cert" --key="${vm_cert/-cert/-key}" -n nephio-system --dry-run=client -o yaml | kubectl apply -f -
          ;;
        "vm2-edge1")
          kubectl --kubeconfig=edge1-kubeconfig create secret tls edge1-tls-cert --cert="$vm_cert" --key="${vm_cert/-cert/-key}" -n oran --dry-run=client -o yaml | kubectl apply -f -
          ;;
        "vm4-edge2")
          kubectl --kubeconfig=edge2-kubeconfig create secret tls edge2-tls-cert --cert="$vm_cert" --key="${vm_cert/-cert/-key}" -n oran --dry-run=client -o yaml | kubectl apply -f -
          ;;
      esac

      echo "$(date): Certificate rotation completed for $vm_name" >> "$LOG_FILE"
    fi
  done
}

# Add to crontab: 0 2 * * 0 /usr/local/bin/rotate-oran-certs.sh
rotate_certificates
```

---

## 3. GitOps Security

### 3.1 Repository Access Controls

**Gitea Repository Security Configuration:**
```bash
#!/bin/bash
# Configure secure Git operations

# Create dedicated Git user
useradd -m -s /bin/bash gitops-svc
usermod -aG docker gitops-svc

# Generate SSH key for GitOps service account
sudo -u gitops-svc ssh-keygen -t ed25519 -f /home/gitops-svc/.ssh/id_ed25519 -N ""

# Set up Git configuration
sudo -u gitops-svc git config --global user.name "GitOps Service Account"
sudo -u gitops-svc git config --global user.email "gitops@oran.local"
sudo -u gitops-svc git config --global init.defaultBranch main
sudo -u gitops-svc git config --global pull.rebase true

# Configure SSH for Gitea
cat > /home/gitops-svc/.ssh/config <<EOF
Host gitea.oran.local
    HostName 172.16.4.44
    Port 22
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking yes
EOF

chown -R gitops-svc:gitops-svc /home/gitops-svc/.ssh
chmod 700 /home/gitops-svc/.ssh
chmod 600 /home/gitops-svc/.ssh/*
```

**Git Repository Hooks for Security:**
```bash
#!/bin/bash
# pre-receive hook for security validation
# Place in: /var/lib/gitea/repositories/gitops/nephio-intent-to-o2-demo.git/hooks/

while read oldrev newrev refname; do
  # Check for secrets in commits
  if git diff --name-only "$oldrev".."$newrev" | xargs git show "$newrev" | grep -E "(password|secret|key|token)" > /dev/null; then
    echo "Error: Potential secrets detected in commit. Please remove sensitive data."
    exit 1
  fi

  # Validate YAML/JSON files
  for file in $(git diff --name-only "$oldrev".."$newrev" | grep -E '\.(yaml|yml|json)$'); do
    if ! git show "$newrev":"$file" | python -c "import yaml, sys; yaml.safe_load(sys.stdin)" 2>/dev/null; then
      echo "Error: Invalid YAML/JSON syntax in $file"
      exit 1
    fi
  done

  # Check for large files
  for file in $(git diff --name-only "$oldrev".."$newrev"); do
    size=$(git show "$newrev":"$file" | wc -c)
    if [ "$size" -gt 1048576 ]; then  # 1MB limit
      echo "Error: File $file exceeds size limit (1MB)"
      exit 1
    fi
  done
done

exit 0
```

### 3.2 Secret Management Practices

**Kubernetes External Secrets Operator Configuration:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: nephio-system
spec:
  provider:
    vault:
      server: "https://vault.oran.local"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "nephio-gitops"
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gitea-credentials
  namespace: nephio-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: gitea-auth-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: gitea
      property: username
  - secretKey: password
    remoteRef:
      key: gitea
      property: password
  - secretKey: token
    remoteRef:
      key: gitea
      property: access_token
```

**Secret Scanning with git-secrets:**
```bash
#!/bin/bash
# Install and configure git-secrets

# Install git-secrets
git clone https://github.com/awslabs/git-secrets.git
cd git-secrets
make install

# Configure for O-RAN repositories
cd /home/gitops-svc/nephio-intent-to-o2-demo
git secrets --install
git secrets --register-aws
git secrets --add 'password\s*[:=]\s*["\047][^"\047]+["\047]'
git secrets --add 'secret\s*[:=]\s*["\047][^"\047]+["\047]'
git secrets --add 'key\s*[:=]\s*["\047][^"\047]+["\047]'
git secrets --add 'token\s*[:=]\s*["\047][^"\047]+["\047]'
git secrets --add 'apikey\s*[:=]\s*["\047][^"\047]+["\047]'
git secrets --add 'api_key\s*[:=]\s*["\047][^"\047]+["\047]'

# Add to pre-commit hook
git secrets --install-hooks
```

### 3.3 RBAC Configurations

**Config Sync RBAC for Multi-Site:**
```yaml
# Service account for Config Sync
apiVersion: v1
kind: ServiceAccount
metadata:
  name: config-sync-sa
  namespace: nephio-system
---
# ClusterRole for SMO operations
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: smo-config-sync-role
rules:
- apiGroups: [""]
  resources: ["namespaces", "configmaps", "secrets", "services"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies", "ingresses"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["security.istio.io"]
  resources: ["peerauthentications", "authorizationpolicies"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["porch.kpt.dev"]
  resources: ["packagerevisions", "packagerevisionresources", "repositories"]
  verbs: ["get", "list", "create", "update", "patch", "delete", "approve"]
---
# ClusterRoleBinding for SMO
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: smo-config-sync-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: smo-config-sync-role
subjects:
- kind: ServiceAccount
  name: config-sync-sa
  namespace: nephio-system
---
# Role for edge sites (limited permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: edge-config-sync-role
  namespace: oran
rules:
- apiGroups: [""]
  resources: ["configmaps", "services", "pods"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list"]  # Read-only for security policies
```

### 3.4 Minimum Privilege Principles

**Pod Security Standards:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: oran
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/enforce-version: v1.28
---
apiVersion: v1
kind: Namespace
metadata:
  name: nonrtric
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/enforce-version: v1.28
---
apiVersion: v1
kind: Namespace
metadata:
  name: nephio-system
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/enforce-version: v1.28
```

**Security Context Enforcement:**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-security-context
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: check-security-context
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaces:
          - oran
          - nonrtric
          - nephio-system
    validate:
      message: "Security context is required"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: ">= 1000"
            fsGroup: ">= 1000"
            seccompProfile:
              type: RuntimeDefault
          containers:
          - name: "*"
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop:
                - ALL
```

---

## 4. Compliance & Auditing

### 4.1 O-RAN WG11 Security Requirements

**WG11 Interface Security Implementation:**

```bash
#!/bin/bash
# O-RAN WG11 Compliance Check Script
# Based on O-RAN.WG11.Security-Requirements.v04.00

check_e2_interface_security() {
  echo "=== E2 Interface Security (WG11 Req 4.2.1) ==="

  # Check mTLS configuration
  kubectl get secrets -n oran | grep -E "e2-tls|e2-cert" || {
    echo "ERROR: E2 interface TLS certificates not found"
    return 1
  }

  # Verify E2 node connections use encryption
  kubectl get e2nodeconnections.e2.o-ran.org -A -o json 2>/dev/null | \
    jq '.items[].spec.security' | grep -q "encryption.*true" || {
    echo "WARNING: E2 interface encryption not fully configured"
  }

  # Check for proper authentication
  kubectl get configmap -n oran e2-security-config -o yaml 2>/dev/null | \
    grep -q "authentication.*enabled" && echo "✓ E2 authentication enabled" || \
    echo "✗ E2 authentication not configured"
}

check_a1_interface_security() {
  echo "=== A1 Interface Security (WG11 Req 4.2.2) ==="

  # Check OAuth2 configuration
  kubectl get secrets -n nonrtric | grep -E "a1-oauth|a1-jwt" || {
    echo "ERROR: A1 interface OAuth2 secrets not found"
    return 1
  }

  # Verify policy authentication
  kubectl exec -n nonrtric deployment/policymanagementservice -- \
    curl -s http://localhost:8081/a1-policy/v2/configuration 2>/dev/null | \
    jq '.security.authenticationEnabled' | grep -q true && \
    echo "✓ A1 authentication enabled" || \
    echo "✗ A1 authentication disabled"
}

check_o1_interface_security() {
  echo "=== O1 Interface Security (WG11 Req 4.2.3) ==="

  # Check NETCONF ACM configuration
  kubectl get configmap -n oran netconf-acm-config -o yaml 2>/dev/null | \
    grep -q "enable-nacm.*true" && \
    echo "✓ NETCONF ACM enabled" || \
    echo "✗ NETCONF ACM not configured"

  # Check SSH key management
  kubectl get secrets -n oran | grep -E "ssh-key|netconf-auth" && \
    echo "✓ O1 SSH keys managed" || \
    echo "✗ O1 SSH authentication not configured"
}

check_o2_interface_security() {
  echo "=== O2 Interface Security (WG11 Req 4.2.4) ==="

  # Check OAuth2 + mTLS for O-Cloud
  kubectl get secrets -n ocloud-system | grep -E "o2-oauth|o2-mtls" && \
    echo "✓ O2 authentication configured" || \
    echo "✗ O2 authentication missing"

  # Verify resource pool security
  kubectl get resourcepools.ocloud.nephio.org -A -o json 2>/dev/null | \
    jq '.items[].spec.security' | grep -q "enabled.*true" && \
    echo "✓ O2 resource security enabled" || \
    echo "✗ O2 resource security not configured"
}

# Run all WG11 compliance checks
main() {
  echo "=== O-RAN WG11 Security Compliance Report ==="
  echo "Date: $(date)"
  echo "Cluster: $(kubectl config current-context)"
  echo ""

  check_e2_interface_security
  echo ""
  check_a1_interface_security
  echo ""
  check_o1_interface_security
  echo ""
  check_o2_interface_security
  echo ""

  echo "=== WG11 Compliance Summary ==="
  # Additional security checks per WG11 requirements
  kubectl get networkpolicies -A --no-headers | wc -l | \
    awk '{if($1>0) print "✓ Network segmentation implemented ("$1" policies)"}'

  kubectl get pods -A -o json | \
    jq '[.items[].spec.containers[].securityContext | select(.runAsNonRoot == true)] | length' | \
    awk '{if($1>0) print "✓ Non-root containers: " $1}'
}

main "$@"
```

### 4.2 FIPS 140-3 Compliance Notes

**FIPS Mode Configuration for Go 1.24.6:**
```bash
#!/bin/bash
# Enable FIPS 140-3 mode for O-RAN components

enable_fips_mode() {
  local namespace="$1"
  echo "Enabling FIPS mode for namespace: $namespace"

  # Check Go version compatibility
  GO_VER=$(kubectl get deployment -n "$namespace" -o json | \
    jq -r '.items[0].spec.template.spec.containers[0].image' | \
    xargs docker inspect 2>/dev/null | \
    jq -r '.[0].Config.Env[] | select(startswith("GO_VERSION="))' | \
    cut -d'=' -f2 | cut -d'.' -f2)

  # Set appropriate FIPS mode based on Go version
  if [[ ${GO_VER:-24} -ge 25 ]]; then
    FIPS_MODE="only"  # Go 1.25+ supports strict FIPS-only mode
  else
    FIPS_MODE="on"    # Go 1.24 supports FIPS mode
  fi

  # Apply FIPS configuration to all deployments
  kubectl get deployments -n "$namespace" -o name | while read -r deploy; do
    echo "Configuring FIPS for $deploy"

    # Set FIPS environment variables
    kubectl set env "$deploy" -n "$namespace" GODEBUG=fips140="$FIPS_MODE"
    kubectl set env "$deploy" -n "$namespace" OPENSSL_FIPS=1
    kubectl set env "$deploy" -n "$namespace" FIPS_MODE_ENABLED=true

    # Update deployment annotations
    kubectl annotate "$deploy" -n "$namespace" \
      security.oran.org/fips140-compliance="$FIPS_MODE" --overwrite
  done
}

verify_fips_compliance() {
  echo "=== FIPS 140-3 Compliance Verification ==="

  for ns in oran nonrtric nephio-system ocloud-system; do
    echo "Checking namespace: $ns"

    kubectl get pods -n "$ns" -o json | \
      jq -r '.items[] | "\(.metadata.name): \(.spec.containers[0].env[] | select(.name=="GODEBUG") | .value)"' | \
      while IFS=': ' read -r pod_name fips_setting; do
        if [[ "$fips_setting" =~ fips140=(on|only) ]]; then
          echo "  ✓ $pod_name: FIPS enabled ($fips_setting)"
        else
          echo "  ✗ $pod_name: FIPS not enabled"
        fi
      done
  done

  # Check cryptographic algorithm compliance
  echo ""
  echo "=== Cryptographic Algorithm Verification ==="
  kubectl get secrets -A -o json | \
    jq -r '.items[] | select(.type=="kubernetes.io/tls") | .metadata.name' | \
    while read -r secret_name; do
      kubectl get secret "$secret_name" -o jsonpath='{.data.tls\.crt}' | \
        base64 -d | openssl x509 -noout -text | \
        grep -E "(Signature Algorithm|Public Key Algorithm)" | \
        head -2 | tr '\n' ' ' | sed "s/^/  $secret_name: /"
      echo ""
    done
}

# Apply FIPS mode to all O-RAN components
for namespace in oran nonrtric nephio-system ocloud-system; do
  enable_fips_mode "$namespace"
done

verify_fips_compliance
```

### 4.3 Audit Logging Configuration

**Kubernetes Audit Policy:**
```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log security-related events at Metadata level
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: "rbac.authorization.k8s.io"
    resources: ["*"]
# Log O-RAN specific resources
- level: Request
  resources:
  - group: "e2.o-ran.org"
    resources: ["*"]
  - group: "a1.nonrtric.org"
    resources: ["*"]
  - group: "ocloud.nephio.org"
    resources: ["*"]
  - group: "porch.kpt.dev"
    resources: ["*"]
# Log administrative actions
- level: RequestResponse
  users: ["system:admin", "admin"]
# Log Config Sync operations
- level: Request
  users: ["system:serviceaccount:nephio-system:config-sync-sa"]
  resources:
  - group: ""
    resources: ["*"]
  - group: "apps"
    resources: ["*"]
# Default log level for everything else
- level: Metadata
```

**Audit Log Analysis Script:**
```bash
#!/bin/bash
# /usr/local/bin/analyze-audit-logs.sh
# Analyze Kubernetes audit logs for security events

AUDIT_LOG="/var/log/audit/audit.log"
SECURITY_LOG="/var/log/security/oran-security.log"
DATE_FILTER=${1:-$(date -d "1 day ago" +%Y-%m-%d)}

analyze_security_events() {
  echo "=== Security Events Analysis for $DATE_FILTER ===" >> "$SECURITY_LOG"

  # Failed authentication attempts
  echo "Failed Authentication Attempts:" >> "$SECURITY_LOG"
  jq -r 'select(.verb == "get" and .code >= 400) | "\(.timestamp) \(.user.username) \(.objectRef.resource) \(.code)"' \
    < "$AUDIT_LOG" | grep "$DATE_FILTER" >> "$SECURITY_LOG"

  # Privilege escalation attempts
  echo -e "\nPrivilege Escalation Attempts:" >> "$SECURITY_LOG"
  jq -r 'select(.verb == "create" and .objectRef.resource == "rolebindings" or .objectRef.resource == "clusterrolebindings") |
         "\(.timestamp) \(.user.username) \(.objectRef.name) \(.objectRef.namespace // "cluster-wide")"' \
    < "$AUDIT_LOG" | grep "$DATE_FILTER" >> "$SECURITY_LOG"

  # Secret access
  echo -e "\nSecret Access Events:" >> "$SECURITY_LOG"
  jq -r 'select(.objectRef.resource == "secrets") |
         "\(.timestamp) \(.verb) \(.user.username) \(.objectRef.name) \(.objectRef.namespace)"' \
    < "$AUDIT_LOG" | grep "$DATE_FILTER" >> "$SECURITY_LOG"

  # Network policy modifications
  echo -e "\nNetwork Policy Changes:" >> "$SECURITY_LOG"
  jq -r 'select(.objectRef.resource == "networkpolicies" and (.verb == "create" or .verb == "update" or .verb == "delete")) |
         "\(.timestamp) \(.verb) \(.user.username) \(.objectRef.name) \(.objectRef.namespace)"' \
    < "$AUDIT_LOG" | grep "$DATE_FILTER" >> "$SECURITY_LOG"

  echo -e "\n=== End of Analysis ===\n" >> "$SECURITY_LOG"
}

# Generate security alerts
generate_alerts() {
  # Check for suspicious patterns
  local suspicious_count=$(jq -r 'select(.code >= 400)' < "$AUDIT_LOG" | wc -l)

  if [ "$suspicious_count" -gt 100 ]; then
    echo "ALERT: High number of failed requests detected: $suspicious_count" | \
      mail -s "O-RAN Security Alert" admin@oran.local
  fi

  # Check for after-hours administrative activity
  local after_hours=$(jq -r 'select(.user.username == "admin" and (.timestamp | strftime("%H") | tonumber) > 18 or
                             (.timestamp | strftime("%H") | tonumber) < 6)' < "$AUDIT_LOG" | wc -l)

  if [ "$after_hours" -gt 0 ]; then
    echo "ALERT: After-hours administrative activity detected: $after_hours events" | \
      mail -s "O-RAN After-Hours Activity" admin@oran.local
  fi
}

# Run analysis
analyze_security_events
generate_alerts

# Rotate logs if needed
if [ -f "$SECURITY_LOG" ] && [ $(wc -c < "$SECURITY_LOG") -gt 104857600 ]; then  # 100MB
  mv "$SECURITY_LOG" "${SECURITY_LOG}.$(date +%Y%m%d)"
  gzip "${SECURITY_LOG}.$(date +%Y%m%d)"
fi
```

### 4.4 Security Event Monitoring

**Falco Rules for O-RAN:**
```yaml
# /etc/falco/falco_rules_oran.yaml
- rule: O-RAN Suspicious Network Activity
  desc: Detect suspicious network connections to O-RAN interfaces
  condition: >
    (fd.sport in (36421, 9001, 830) or fd.dport in (36421, 9001, 830)) and
    not proc.name in (oran_du, oran_cu, policy_management, netconfd)
  output: >
    Suspicious O-RAN network activity (user=%user.name command=%proc.cmdline
    connection=%fd.name proto=%fd.l4proto)
  priority: WARNING
  tags: [network, oran]

- rule: Unauthorized Secret Access
  desc: Detect unauthorized access to O-RAN secrets
  condition: >
    open_read and fd.name contains "/var/run/secrets/kubernetes.io" and
    k8s.ns.name in (oran, nonrtric, nephio-system) and
    not k8s.sa.name in (config-sync-sa, oran-operator, policy-manager)
  output: >
    Unauthorized secret access (user=%user.name command=%proc.cmdline
    file=%fd.name namespace=%k8s.ns.name)
  priority: ERROR
  tags: [secrets, oran]

- rule: O-RAN Configuration Change
  desc: Detect configuration changes to O-RAN components
  condition: >
    open_write and fd.name contains "/etc/oran" and
    not proc.name in (kubectl, config-sync, oran-operator)
  output: >
    O-RAN configuration file modified (user=%user.name command=%proc.cmdline
    file=%fd.name)
  priority: NOTICE
  tags: [configuration, oran]

- rule: Privilege Escalation in O-RAN Namespaces
  desc: Detect potential privilege escalation attempts
  condition: >
    spawned_process and proc.name in (sudo, su, setuid) and
    k8s.ns.name in (oran, nonrtric, nephio-system)
  output: >
    Privilege escalation attempt in O-RAN namespace (user=%user.name
    command=%proc.cmdline namespace=%k8s.ns.name)
  priority: CRITICAL
  tags: [privilege_escalation, oran]
```

**Security Metrics Collection:**
```bash
#!/bin/bash
# /usr/local/bin/collect-security-metrics.sh
# Collect and export security metrics for O-RAN deployment

METRICS_FILE="/var/lib/prometheus/node_exporter/oran_security.prom"

collect_metrics() {
  cat > "$METRICS_FILE" <<EOF
# HELP oran_security_events_total Total number of security events
# TYPE oran_security_events_total counter
oran_security_events_total{type="authentication_failure"} $(journalctl --since "1 hour ago" | grep -c "authentication failure")
oran_security_events_total{type="privilege_escalation"} $(journalctl --since "1 hour ago" | grep -c "privilege escalation")
oran_security_events_total{type="unauthorized_access"} $(journalctl --since "1 hour ago" | grep -c "unauthorized access")

# HELP oran_certificate_expiry_days Days until certificate expiry
# TYPE oran_certificate_expiry_days gauge
EOF

  # Check certificate expiry for all TLS secrets
  kubectl get secrets -A -o json | \
    jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.namespace) \(.metadata.name)"' | \
    while read -r namespace secret_name; do
      expiry_days=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.tls\.crt}' | \
        base64 -d | openssl x509 -noout -checkend 0 -enddate 2>/dev/null | \
        grep -o '[0-9]* days' | awk '{print $1}' || echo "0")

      echo "oran_certificate_expiry_days{namespace=\"$namespace\",secret=\"$secret_name\"} $expiry_days" >> "$METRICS_FILE"
    done

  # Network policy coverage
  total_pods=$(kubectl get pods -A --no-headers | wc -l)
  pods_with_policies=$(kubectl get networkpolicies -A -o json | \
    jq '[.items[].spec.podSelector | keys] | length')

  coverage_percent=$(echo "scale=2; $pods_with_policies * 100 / $total_pods" | bc -l)

  cat >> "$METRICS_FILE" <<EOF

# HELP oran_network_policy_coverage_percent Percentage of pods covered by network policies
# TYPE oran_network_policy_coverage_percent gauge
oran_network_policy_coverage_percent $coverage_percent

# HELP oran_fips_compliance_status FIPS 140-3 compliance status
# TYPE oran_fips_compliance_status gauge
EOF

  # FIPS compliance status
  for ns in oran nonrtric nephio-system ocloud-system; do
    fips_pods=$(kubectl get pods -n "$ns" -o json | \
      jq '[.items[] | select(.spec.containers[].env[]?.name == "GODEBUG" and
          (.spec.containers[].env[] | select(.name == "GODEBUG") | .value | test("fips140=(on|only)")))] | length')

    total_pods_ns=$(kubectl get pods -n "$ns" --no-headers | wc -l)

    if [ "$total_pods_ns" -gt 0 ]; then
      compliance_ratio=$(echo "scale=2; $fips_pods / $total_pods_ns" | bc -l)
      echo "oran_fips_compliance_status{namespace=\"$ns\"} $compliance_ratio" >> "$METRICS_FILE"
    fi
  done
}

# Run metrics collection
collect_metrics

# Set proper permissions for Prometheus node_exporter
chown prometheus:prometheus "$METRICS_FILE"
chmod 644 "$METRICS_FILE"
```

---

## 5. Incident Response

### 5.1 Security Breach Procedures

**Immediate Response Checklist:**
```bash
#!/bin/bash
# /usr/local/bin/security-incident-response.sh
# Immediate response to security incidents

INCIDENT_LOG="/var/log/security/incident-$(date +%Y%m%d-%H%M%S).log"
SEVERITY=${1:-"MEDIUM"}  # LOW, MEDIUM, HIGH, CRITICAL

log_incident() {
  echo "$(date -Iseconds) [$SEVERITY] $1" | tee -a "$INCIDENT_LOG"
}

immediate_containment() {
  log_incident "Starting immediate containment procedures"

  case "$SEVERITY" in
    "CRITICAL")
      log_incident "CRITICAL incident - implementing emergency containment"

      # Isolate affected nodes
      kubectl cordon $(kubectl get nodes --no-headers | awk '{print $1}')

      # Enable emergency network policies
      kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-lockdown
  namespace: oran
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

      # Disable external access
      iptables -A INPUT -j DROP
      iptables -A FORWARD -j DROP

      log_incident "Emergency containment activated"
      ;;

    "HIGH")
      log_incident "HIGH severity incident - implementing selective containment"

      # Disable compromised service accounts
      kubectl get serviceaccounts -A | grep -E "(suspected|compromised)" | \
        while read ns sa rest; do
          kubectl patch serviceaccount "$sa" -n "$ns" -p '{"secrets": []}'
          log_incident "Disabled service account: $ns/$sa"
        done

      # Restrict network access
      kubectl apply -f /etc/kubernetes/security/restrictive-network-policies.yaml
      ;;

    "MEDIUM")
      log_incident "MEDIUM severity incident - implementing monitoring enhancement"

      # Increase audit logging verbosity
      kubectl patch configmap audit-policy -n kube-system --type merge -p \
        '{"data":{"audit-policy.yaml":"apiVersion: audit.k8s.io/v1\nkind: Policy\nrules:\n- level: RequestResponse"}}'

      # Enable enhanced monitoring
      kubectl set env daemonset/falco -n falco-system FALCO_LOG_LEVEL=debug
      ;;
  esac
}

forensic_collection() {
  log_incident "Starting forensic data collection"

  FORENSIC_DIR="/var/forensics/incident-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$FORENSIC_DIR"

  # Collect system state
  kubectl cluster-info dump > "$FORENSIC_DIR/cluster-dump.yaml"
  kubectl get events -A --sort-by='.lastTimestamp' > "$FORENSIC_DIR/events.log"
  kubectl get pods -A -o wide > "$FORENSIC_DIR/pods-state.log"

  # Collect audit logs
  cp /var/log/audit/audit.log "$FORENSIC_DIR/"

  # Collect network state
  iptables -L -n > "$FORENSIC_DIR/iptables-rules.txt"
  ss -tuln > "$FORENSIC_DIR/network-connections.txt"

  # Collect process information
  ps auxf > "$FORENSIC_DIR/processes.txt"

  # Create forensic archive
  tar -czf "$FORENSIC_DIR.tar.gz" "$FORENSIC_DIR"
  chmod 600 "$FORENSIC_DIR.tar.gz"

  log_incident "Forensic data collected: $FORENSIC_DIR.tar.gz"
}

notification_procedures() {
  log_incident "Initiating notification procedures"

  # Prepare incident summary
  cat > /tmp/incident-summary.txt <<EOF
SECURITY INCIDENT ALERT

Incident ID: $(basename "$INCIDENT_LOG" .log)
Severity: $SEVERITY
Time: $(date)
Cluster: $(kubectl config current-context)

Immediate Actions Taken:
- Containment procedures activated
- Forensic data collection initiated
- Monitoring enhanced

Next Steps:
1. Review forensic data
2. Assess impact scope
3. Plan remediation actions
4. Update security controls

Contact: Security Team <security@oran.local>
EOF

  # Send alerts
  case "$SEVERITY" in
    "CRITICAL"|"HIGH")
      mail -s "URGENT: O-RAN Security Incident - $SEVERITY" \
        -a "$FORENSIC_DIR.tar.gz" \
        security-team@oran.local < /tmp/incident-summary.txt

      # Send SMS/Slack notifications (if configured)
      curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"SECURITY INCIDENT: '"$SEVERITY"' severity in O-RAN cluster"}' \
        "$SLACK_WEBHOOK_URL" 2>/dev/null || true
      ;;
    *)
      mail -s "O-RAN Security Incident - $SEVERITY" \
        security-team@oran.local < /tmp/incident-summary.txt
      ;;
  esac

  log_incident "Notifications sent"
}

# Execute incident response
main() {
  log_incident "Security incident response initiated - Severity: $SEVERITY"

  immediate_containment
  forensic_collection
  notification_procedures

  log_incident "Initial incident response completed"
  log_incident "Incident log: $INCIDENT_LOG"

  echo "Incident response completed. Review log: $INCIDENT_LOG"
}

main "$@"
```

### 5.2 Recovery Procedures

**System Recovery Playbook:**
```bash
#!/bin/bash
# /usr/local/bin/security-recovery.sh
# Security incident recovery procedures

RECOVERY_LOG="/var/log/security/recovery-$(date +%Y%m%d-%H%M%S).log"

log_recovery() {
  echo "$(date -Iseconds) [RECOVERY] $1" | tee -a "$RECOVERY_LOG"
}

validate_security_posture() {
  log_recovery "Validating current security posture"

  # Check for active threats
  log_recovery "Scanning for active threats..."

  # Run security scans
  trivy image --severity HIGH,CRITICAL $(kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u) > /tmp/vuln-scan.txt 2>/dev/null

  critical_vulns=$(grep -c "CRITICAL" /tmp/vuln-scan.txt)
  high_vulns=$(grep -c "HIGH" /tmp/vuln-scan.txt)

  log_recovery "Found $critical_vulns critical and $high_vulns high vulnerabilities"

  # Check network policies
  policies_count=$(kubectl get networkpolicies -A --no-headers | wc -l)
  log_recovery "Active network policies: $policies_count"

  # Check RBAC
  cluster_admin_bindings=$(kubectl get clusterrolebindings -o json | \
    jq '[.items[] | select(.roleRef.name=="cluster-admin")] | length')
  log_recovery "Cluster-admin bindings: $cluster_admin_bindings"

  if [ "$cluster_admin_bindings" -gt 3 ]; then
    log_recovery "WARNING: Excessive cluster-admin bindings detected"
  fi
}

remediate_vulnerabilities() {
  log_recovery "Starting vulnerability remediation"

  # Update container images to patched versions
  log_recovery "Updating container images..."

  # Get deployment images and check for updates
  kubectl get deployments -A -o json | \
    jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name) \(.spec.template.spec.containers[0].image)"' | \
    while read -r namespace deployment image; do
      # Check if image has a newer version available
      latest_tag=$(curl -s "https://registry.hub.docker.com/v2/repositories/${image%:*}/tags/?page_size=1" | \
        jq -r '.results[0].name' 2>/dev/null || echo "latest")

      current_tag=${image##*:}

      if [ "$current_tag" != "$latest_tag" ] && [ "$latest_tag" != "null" ]; then
        log_recovery "Updating $deployment in $namespace from $current_tag to $latest_tag"

        kubectl set image deployment "$deployment" -n "$namespace" \
          "${deployment}=${image%:*}:${latest_tag}"

        # Wait for rollout to complete
        kubectl rollout status deployment "$deployment" -n "$namespace" --timeout=300s
      fi
    done
}

restore_security_controls() {
  log_recovery "Restoring security controls"

  # Remove emergency restrictions if they exist
  kubectl delete networkpolicy emergency-lockdown -n oran 2>/dev/null || true

  # Re-apply standard security policies
  kubectl apply -f /etc/kubernetes/security/standard-network-policies.yaml
  kubectl apply -f /etc/kubernetes/security/pod-security-policies.yaml
  kubectl apply -f /etc/kubernetes/security/rbac-policies.yaml

  # Restore normal iptables rules
  iptables-restore < /etc/iptables/rules.v4.backup

  # Re-enable nodes
  kubectl get nodes -o name | xargs -I {} kubectl uncordon {}

  log_recovery "Standard security controls restored"
}

rotate_credentials() {
  log_recovery "Starting credential rotation"

  # Rotate service account tokens
  kubectl get serviceaccounts -A -o json | \
    jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
    while read -r namespace sa; do
      # Skip system service accounts
      if [[ "$sa" =~ ^(default|system:).*$ ]]; then
        continue
      fi

      log_recovery "Rotating token for $namespace/$sa"

      # Delete existing secrets to force token regeneration
      kubectl get secret -n "$namespace" | grep "$sa-token" | awk '{print $1}' | \
        xargs -I {} kubectl delete secret {} -n "$namespace" 2>/dev/null || true
    done

  # Rotate TLS certificates
  log_recovery "Rotating TLS certificates"

  kubectl get secrets -A -o json | \
    jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.namespace) \(.metadata.name)"' | \
    while read -r namespace secret; do
      log_recovery "Rotating certificate for $namespace/$secret"

      # Backup existing certificate
      kubectl get secret "$secret" -n "$namespace" -o yaml > \
        "/var/backups/certs/${namespace}-${secret}-$(date +%Y%m%d).yaml"

      # Generate new certificate (reuse the CA setup from earlier)
      /usr/local/bin/generate-oran-cert.sh "$namespace" "$secret"

      # Apply new certificate
      kubectl create secret tls "$secret" \
        --cert="/tmp/${secret}-cert.pem" \
        --key="/tmp/${secret}-key.pem" \
        -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -

      rm -f "/tmp/${secret}-cert.pem" "/tmp/${secret}-key.pem"
    done
}

verify_recovery() {
  log_recovery "Verifying recovery status"

  # Run security compliance check
  /usr/local/bin/security-compliance-check.sh > /tmp/compliance-report.txt

  compliance_score=$(grep "Compliance Score" /tmp/compliance-report.txt | awk '{print $3}')
  log_recovery "Post-recovery compliance score: $compliance_score"

  # Check system health
  unhealthy_pods=$(kubectl get pods -A | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l)
  log_recovery "Unhealthy pods: $unhealthy_pods"

  # Check service availability
  log_recovery "Checking service availability..."

  services_status=""

  # Test O-RAN interfaces
  if curl -s --connect-timeout 5 http://172.16.4.45:31280/o2ims/v1/resourceTypes >/dev/null; then
    services_status="$services_status O2IMS:OK"
  else
    services_status="$services_status O2IMS:FAIL"
  fi

  if timeout 5 nc -z 172.16.4.45 36421; then
    services_status="$services_status E2:OK"
  else
    services_status="$services_status E2:FAIL"
  fi

  log_recovery "Service status: $services_status"

  # Generate recovery report
  cat > /tmp/recovery-report.txt <<EOF
SECURITY RECOVERY REPORT

Recovery ID: $(basename "$RECOVERY_LOG" .log)
Date: $(date)
Cluster: $(kubectl config current-context)

Recovery Actions Completed:
✓ Security posture validation
✓ Vulnerability remediation
✓ Security controls restoration
✓ Credential rotation
✓ System verification

Post-Recovery Status:
- Compliance Score: $compliance_score
- Unhealthy Pods: $unhealthy_pods
- Service Status: $services_status

Recommendations:
1. Monitor system for 24 hours
2. Review security logs for anomalies
3. Update security documentation
4. Schedule security assessment

Recovery Log: $RECOVERY_LOG
EOF

  mail -s "O-RAN Security Recovery Completed" \
    security-team@oran.local < /tmp/recovery-report.txt

  log_recovery "Recovery verification completed"
}

# Execute recovery procedures
main() {
  log_recovery "Starting security recovery procedures"

  validate_security_posture
  remediate_vulnerabilities
  restore_security_controls
  rotate_credentials
  verify_recovery

  log_recovery "Security recovery procedures completed"

  echo "Recovery completed. Review log: $RECOVERY_LOG"
}

main "$@"
```

### 5.3 Forensics Guidelines

**Digital Forensics Procedures:**
```bash
#!/bin/bash
# /usr/local/bin/forensic-investigation.sh
# Digital forensics for O-RAN security incidents

CASE_ID=${1:-"CASE-$(date +%Y%m%d-%H%M%S)"}
FORENSIC_ROOT="/var/forensics/$CASE_ID"
EVIDENCE_LOG="$FORENSIC_ROOT/evidence.log"

setup_forensic_environment() {
  mkdir -p "$FORENSIC_ROOT"/{system,network,application,timeline}
  touch "$EVIDENCE_LOG"
  chmod 600 "$EVIDENCE_LOG"

  echo "$(date -Iseconds) Forensic investigation started - Case ID: $CASE_ID" >> "$EVIDENCE_LOG"
}

collect_system_evidence() {
  echo "$(date -Iseconds) Collecting system evidence" >> "$EVIDENCE_LOG"

  # System state
  kubectl cluster-info dump --all-namespaces --output-directory="$FORENSIC_ROOT/system/cluster-dump"

  # Resource states
  kubectl get all -A -o yaml > "$FORENSIC_ROOT/system/all-resources.yaml"
  kubectl describe nodes > "$FORENSIC_ROOT/system/node-descriptions.txt"
  kubectl top nodes > "$FORENSIC_ROOT/system/node-metrics.txt" 2>/dev/null || true
  kubectl top pods -A > "$FORENSIC_ROOT/system/pod-metrics.txt" 2>/dev/null || true

  # Events and logs
  kubectl get events -A --sort-by='.lastTimestamp' -o wide > "$FORENSIC_ROOT/system/events.log"

  # RBAC information
  kubectl get clusterrolebindings -o yaml > "$FORENSIC_ROOT/system/clusterrolebindings.yaml"
  kubectl get rolebindings -A -o yaml > "$FORENSIC_ROOT/system/rolebindings.yaml"

  # Secrets (metadata only)
  kubectl get secrets -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,TYPE:.type,AGE:.metadata.creationTimestamp > "$FORENSIC_ROOT/system/secrets-metadata.txt"

  echo "$(date -Iseconds) System evidence collected" >> "$EVIDENCE_LOG"
}

collect_network_evidence() {
  echo "$(date -Iseconds) Collecting network evidence" >> "$EVIDENCE_LOG"

  # Network policies
  kubectl get networkpolicies -A -o yaml > "$FORENSIC_ROOT/network/networkpolicies.yaml"

  # Service mesh configuration (if Istio is present)
  if kubectl get namespace istio-system >/dev/null 2>&1; then
    kubectl get destinationrules,virtualservices,gateways,serviceentries -A -o yaml > "$FORENSIC_ROOT/network/istio-config.yaml"
    kubectl get peerauthentications,authorizationpolicies -A -o yaml > "$FORENSIC_ROOT/network/istio-security.yaml"
  fi

  # Network connections from each node
  kubectl get nodes -o name | while read -r node; do
    node_name=${node#node/}
    kubectl debug "$node" -it --image=nicolaka/netshoot -- sh -c "
      ss -tuln > /tmp/connections.txt 2>/dev/null
      iptables -L -n > /tmp/iptables.txt 2>/dev/null
      cat /tmp/connections.txt /tmp/iptables.txt
    " > "$FORENSIC_ROOT/network/${node_name}-network.txt" 2>/dev/null || true
  done

  # DNS resolution
  kubectl run forensic-dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default > "$FORENSIC_ROOT/network/dns-test.txt" 2>/dev/null || true

  echo "$(date -Iseconds) Network evidence collected" >> "$EVIDENCE_LOG"
}

collect_application_evidence() {
  echo "$(date -Iseconds) Collecting application evidence" >> "$EVIDENCE_LOG"

  # O-RAN specific resources
  for crd in e2nodeconnections.e2.o-ran.org policies.a1.nonrtric.org resourcepools.ocloud.nephio.org; do
    kubectl get "$crd" -A -o yaml > "$FORENSIC_ROOT/application/${crd}.yaml" 2>/dev/null || true
  done

  # Application logs
  for ns in oran nonrtric nephio-system ocloud-system; do
    kubectl logs --all-containers=true -n "$ns" --previous=false --since=24h > "$FORENSIC_ROOT/application/${ns}-logs.txt" 2>/dev/null || true
  done

  # Configuration files
  kubectl get configmaps -A -o yaml > "$FORENSIC_ROOT/application/configmaps.yaml"

  # Container images in use
  kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' > "$FORENSIC_ROOT/application/container-images.txt"

  echo "$(date -Iseconds) Application evidence collected" >> "$EVIDENCE_LOG"
}

create_timeline() {
  echo "$(date -Iseconds) Creating timeline analysis" >> "$EVIDENCE_LOG"

  # Parse events for timeline
  kubectl get events -A --sort-by='.firstTimestamp' -o json | \
    jq -r '.items[] | "\(.firstTimestamp) \(.type) \(.namespace)/\(.involvedObject.name) \(.reason) \(.message)"' > "$FORENSIC_ROOT/timeline/events-timeline.txt"

  # Parse audit logs for timeline (if available)
  if [ -f /var/log/audit/audit.log ]; then
    jq -r '"\(.timestamp) \(.verb) \(.user.username) \(.objectRef.namespace // "cluster")/\(.objectRef.name) \(.responseStatus.code // "unknown")"' < /var/log/audit/audit.log | \
      sort > "$FORENSIC_ROOT/timeline/audit-timeline.txt"
  fi

  # Combine timelines
  (
    [ -f "$FORENSIC_ROOT/timeline/events-timeline.txt" ] && sed 's/^/EVENT /' "$FORENSIC_ROOT/timeline/events-timeline.txt"
    [ -f "$FORENSIC_ROOT/timeline/audit-timeline.txt" ] && sed 's/^/AUDIT /' "$FORENSIC_ROOT/timeline/audit-timeline.txt"
  ) | sort > "$FORENSIC_ROOT/timeline/combined-timeline.txt"

  echo "$(date -Iseconds) Timeline analysis created" >> "$EVIDENCE_LOG"
}

analyze_security_indicators() {
  echo "$(date -Iseconds) Analyzing security indicators" >> "$EVIDENCE_LOG"

  # Look for suspicious patterns
  cat > "$FORENSIC_ROOT/analysis-report.txt" <<EOF
FORENSIC ANALYSIS REPORT
Case ID: $CASE_ID
Generated: $(date)

SECURITY INDICATORS:

1. Failed Authentication Attempts:
EOF

  if [ -f /var/log/audit/audit.log ]; then
    grep "code\":40[13]" /var/log/audit/audit.log | wc -l >> "$FORENSIC_ROOT/analysis-report.txt"
  else
    echo "   No audit log available" >> "$FORENSIC_ROOT/analysis-report.txt"
  fi

  cat >> "$FORENSIC_ROOT/analysis-report.txt" <<EOF

2. Privilege Escalation Attempts:
$(grep -i "rolebinding\|clusterrolebinding" "$FORENSIC_ROOT/timeline/combined-timeline.txt" 2>/dev/null | wc -l)

3. Network Policy Violations:
$(grep -i "networkpolicy" "$FORENSIC_ROOT/timeline/events-timeline.txt" 2>/dev/null | grep -i "failed\|denied" | wc -l)

4. Unusual Container Activity:
$(kubectl get pods -A | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)" | wc -l) pods in error state

5. Secret Access Patterns:
EOF

  if [ -f "$FORENSIC_ROOT/timeline/audit-timeline.txt" ]; then
    grep "secrets" "$FORENSIC_ROOT/timeline/audit-timeline.txt" | wc -l >> "$FORENSIC_ROOT/analysis-report.txt"
  else
    echo "   No audit data available" >> "$FORENSIC_ROOT/analysis-report.txt"
  fi

  cat >> "$FORENSIC_ROOT/analysis-report.txt" <<EOF

RECOMMENDATIONS:
1. Review all cluster-admin role bindings
2. Audit container images for vulnerabilities
3. Verify network policy configurations
4. Check for unauthorized secret access
5. Review service account permissions

Evidence Location: $FORENSIC_ROOT
Evidence Log: $EVIDENCE_LOG
EOF

  echo "$(date -Iseconds) Security analysis completed" >> "$EVIDENCE_LOG"
}

package_evidence() {
  echo "$(date -Iseconds) Packaging evidence" >> "$EVIDENCE_LOG"

  # Create chain of custody document
  cat > "$FORENSIC_ROOT/chain-of-custody.txt" <<EOF
CHAIN OF CUSTODY

Case ID: $CASE_ID
Evidence Collected: $(date)
Collected By: $(whoami)@$(hostname)
System: $(kubectl config current-context)

Evidence Hash:
$(find "$FORENSIC_ROOT" -type f -exec md5sum {} \; | sort)

Collection Method: Automated forensic script
Storage Location: $FORENSIC_ROOT

Custody Log:
$(date -Iseconds) - Evidence collected by $(whoami)
$(date -Iseconds) - Evidence packaged for analysis
EOF

  # Create encrypted archive
  tar -czf "/tmp/${CASE_ID}-evidence.tar.gz" -C "$(dirname "$FORENSIC_ROOT")" "$(basename "$FORENSIC_ROOT")"

  # Encrypt with GPG if available
  if command -v gpg >/dev/null 2>&1; then
    gpg --cipher-algo AES256 --compress-algo 1 --s2k-cipher-algo AES256 \
        --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65011712 \
        --symmetric --output "/tmp/${CASE_ID}-evidence.tar.gz.gpg" \
        "/tmp/${CASE_ID}-evidence.tar.gz"

    rm "/tmp/${CASE_ID}-evidence.tar.gz"
    echo "$(date -Iseconds) Evidence encrypted: /tmp/${CASE_ID}-evidence.tar.gz.gpg" >> "$EVIDENCE_LOG"
  else
    echo "$(date -Iseconds) Evidence packaged: /tmp/${CASE_ID}-evidence.tar.gz" >> "$EVIDENCE_LOG"
  fi

  # Set secure permissions
  chmod 600 "/tmp/${CASE_ID}-evidence.tar.gz"* 2>/dev/null || true
}

# Main forensic investigation
main() {
  echo "Starting forensic investigation for case: $CASE_ID"

  setup_forensic_environment
  collect_system_evidence
  collect_network_evidence
  collect_application_evidence
  create_timeline
  analyze_security_indicators
  package_evidence

  echo "Forensic investigation completed"
  echo "Case ID: $CASE_ID"
  echo "Evidence location: $FORENSIC_ROOT"
  echo "Analysis report: $FORENSIC_ROOT/analysis-report.txt"

  # Send notification
  mail -s "Forensic Investigation Completed - $CASE_ID" \
    -a "$FORENSIC_ROOT/analysis-report.txt" \
    security-team@oran.local <<EOF
Forensic investigation completed for case $CASE_ID.

Evidence has been collected and analyzed.
Please review the analysis report for findings and recommendations.

Case directory: $FORENSIC_ROOT
EOF
}

main "$@"
```

---

## Security Command Reference

### Quick Security Commands

```bash
# Security status check
/usr/local/bin/security-compliance-check.sh

# Enable FIPS mode
kubectl get deployments -A -o name | while read d; do
  kubectl set env $d GODEBUG=fips140=on OPENSSL_FIPS=1
done

# Network policy audit
kubectl get networkpolicies -A

# Secret rotation
kubectl get secrets -A -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.namespace) \(.metadata.name)"'

# Container vulnerability scan
trivy image --severity HIGH,CRITICAL $(kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u)

# Audit log analysis
jq -r 'select(.code >= 400) | "\(.timestamp) \(.user.username) \(.verb) \(.objectRef.resource)"' < /var/log/audit/audit.log

# Certificate expiry check
kubectl get secrets -A -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | "\(.metadata.namespace) \(.metadata.name)"' | while read ns secret; do
  kubectl get secret $secret -n $ns -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
done
```

### Security Validation Scripts

All security validation and compliance scripts are located in:
- `/usr/local/bin/security-compliance-check.sh` - Main compliance checker
- `/usr/local/bin/security-incident-response.sh` - Incident response
- `/usr/local/bin/security-recovery.sh` - Recovery procedures
- `/usr/local/bin/forensic-investigation.sh` - Forensic collection
- `/usr/local/bin/rotate-oran-certs.sh` - Certificate rotation
- `/usr/local/bin/analyze-audit-logs.sh` - Audit analysis

### Contact Information

**Security Team Contacts:**
- Primary: security-team@oran.local
- Emergency: +1-555-SECURITY (24/7)
- Slack: #oran-security-alerts

**Escalation Matrix:**
1. **Level 1**: Operations Team (0-15 minutes)
2. **Level 2**: Security Team (15-30 minutes)
3. **Level 3**: Engineering Management (30-60 minutes)
4. **Level 4**: Executive Team (1+ hours)

## 6. Supply Chain Security

### 6.1 SBOM Generation and Management

**Software Bill of Materials (SBOM) Generation:**
```bash
# Generate SBOM for custom images
make sbom

# For specific image
syft <image:tag> -o json > reports/$(date +%Y%m%d_%H%M%S)/sbom/image.sbom.json
syft <image:tag> -o spdx > reports/$(date +%Y%m%d_%H%M%S)/sbom/image.sbom.spdx
```

**SBOM Storage Structure:**
```
reports/
└── <timestamp>/
    └── sbom/
        ├── image1.sbom.json      # JSON format SBOM
        ├── image1.sbom.spdx      # SPDX format SBOM
        ├── image2.sbom.json
        └── image2.sbom.spdx
```

### 6.2 Image and SBOM Signing

**Signing Process:**
```bash
# Sign all custom images and their SBOMs
make sign

# Manual signing with cosign
export COSIGN_EXPERIMENTAL=1  # For keyless signing

# Sign container image
cosign sign --yes <image:tag>

# Sign SBOM artifact
cosign sign-blob --yes reports/<timestamp>/sbom/image.sbom.json \
  > reports/<timestamp>/signatures/image.sbom.sig
```

**Key Management (Optional - for production):**
```bash
# Generate signing key pair
cosign generate-key-pair

# Sign with private key
cosign sign --key cosign.key <image:tag>

# Store keys securely
kubectl create secret generic cosign-keys \
  --from-file=cosign.key \
  --from-file=cosign.pub \
  -n security-system
```

### 6.3 Signature Verification

**Verification Steps:**
```bash
# Verify all signatures
make verify

# Manual verification
export COSIGN_EXPERIMENTAL=1

# Verify image signature (keyless)
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <image:tag>

# Verify image signature (with public key)
cosign verify --key cosign.pub <image:tag>

# Verify SBOM signature
cosign verify-blob \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  --signature reports/<timestamp>/signatures/image.sbom.sig \
  reports/<timestamp>/sbom/image.sbom.json
```

**Automated Verification in CI/CD:**
```yaml
# .github/workflows/verify-supply-chain.yml
- name: Verify Image Signatures
  run: |
    export COSIGN_EXPERIMENTAL=1
    for image in $(cat artifacts/custom-images.txt); do
      cosign verify \
        --certificate-identity-regexp '.*' \
        --certificate-oidc-issuer-regexp '.*' \
        "$image" || exit 1
    done

- name: Verify SBOM Signatures
  run: |
    make verify || exit 1
```

### 6.4 Supply Chain Security Policy

**Policy Enforcement:**
```yaml
# supply-chain-policy.yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: supply-chain-policy
spec:
  images:
  - glob: "ghcr.io/nephio-project/*"
    authorities:
    - keyless:
        identities:
        - issuer: https://token.actions.githubusercontent.com
          subject: "https://github.com/nephio-project/*"
  - glob: "*/oran-*"
    authorities:
    - key:
        data: |
          -----BEGIN PUBLIC KEY-----
          <PRODUCTION_PUBLIC_KEY>
          -----END PUBLIC KEY-----
```

**Verification Checklist:**
- [ ] All custom images have corresponding SBOMs
- [ ] SBOMs are generated in both JSON and SPDX formats
- [ ] All images are signed with cosign
- [ ] All SBOMs are signed as blob artifacts
- [ ] Signatures can be verified with public key or keyless
- [ ] CI/CD pipeline includes signature verification
- [ ] Supply chain policy is enforced in clusters
- [ ] Verification logs are retained for audit

### 6.5 Vulnerability Scanning Integration

**SBOM-based Vulnerability Scanning:**
```bash
# Scan for vulnerabilities using grype
grype sbom:reports/<timestamp>/sbom/image.sbom.json

# Generate vulnerability report
grype sbom:reports/<timestamp>/sbom/image.sbom.json \
  -o json > reports/<timestamp>/vulnerabilities/image.vuln.json

# Check against specific databases
grype sbom:reports/<timestamp>/sbom/image.sbom.json \
  --only-fixed \
  --fail-on high
```

**Continuous Monitoring:**
```bash
#!/bin/bash
# /usr/local/bin/monitor-supply-chain.sh

SBOM_DIR="reports/latest/sbom"
VULN_DIR="reports/latest/vulnerabilities"

for sbom in "$SBOM_DIR"/*.sbom.json; do
  image_name=$(basename "$sbom" .sbom.json)

  # Verify signature
  if ! cosign verify-blob \
    --signature "$SBOM_DIR/../signatures/${image_name}.sbom.sig" \
    "$sbom" 2>/dev/null; then
    echo "⚠️ Invalid signature for $image_name"
    continue
  fi

  # Scan for vulnerabilities
  grype sbom:"$sbom" \
    --fail-on critical \
    -o json > "$VULN_DIR/${image_name}.vuln.json"

  # Alert on critical findings
  if [ $? -ne 0 ]; then
    send_security_alert "Critical vulnerability in $image_name"
  fi
done
```

---

## Common Security Failures and 5-Minute Fixes

### Security Incident Response Playbook

#### 1. Unauthorized Access Attempt (Port 6443/8888)
**Symptoms**: Failed authentication logs, suspicious IPs in audit logs
```bash
# Quick Fix (< 5 min)
# Block suspicious IP immediately
iptables -I INPUT -s <SUSPICIOUS_IP> -j DROP
# Review authentication logs
kubectl logs -n kube-system kube-apiserver-* | grep "Unauthorized"
# Rotate service account tokens if compromised
kubectl delete secret -A -l kubernetes.io/service-account-token
```

#### 2. Certificate Expiry (Ports 6443/31443)
**Symptoms**: TLS handshake failures, "certificate expired" errors
```bash
# Quick Fix (< 5 min)
# Check certificate expiry
kubeadm certs check-expiration
# Renew certificates
kubeadm certs renew all
# Restart API server
systemctl restart kubelet
```

#### 3. O2IMS Authentication Failure (Port 31280)
**Symptoms**: 401/403 errors on O2IMS API calls
```bash
# Quick Fix (< 5 min)
# Regenerate O2IMS tokens
kubectl delete secret o2ims-auth -n o2ims-system
kubectl create secret generic o2ims-auth --from-literal=token=$(openssl rand -hex 32) -n o2ims-system
kubectl rollout restart deployment o2ims-controller -n o2ims-system
```

#### 4. Firewall Rule Corruption (Ports 31080/31443/31280)
**Symptoms**: Services suddenly unreachable, iptables rules missing
```bash
# Quick Fix (< 5 min)
# Restore default security rules
iptables-restore < /etc/iptables/rules.v4.backup
# Verify critical ports are open
for port in 6443 31080 31443 31280 8888; do
  nc -zv 172.16.4.45 $port
done
```

#### 5. RBAC Policy Violation
**Symptoms**: Permission denied errors, service account issues
```bash
# Quick Fix (< 5 min)
# Review RBAC bindings
kubectl get rolebindings,clusterrolebindings -A | grep -i admin
# Apply emergency RBAC fix
kubectl apply -f security/emergency-rbac.yaml
# Audit recent RBAC changes
kubectl get events -A | grep -i rbac
```

### Common Security Failure Patterns

| Incident Type | Port | Detection Method | MTTR | Automation |
|---------------|------|------------------|------|------------|
| Brute Force | 6443 | Fail2ban alerts | 2 min | Auto-block |
| Cert Expiry | 6443/31443 | X.509 monitoring | 3 min | Auto-renew |
| Token Leak | 31280 | Audit logs | 4 min | Auto-rotate |
| DDoS Attack | 31080/8888 | Rate limit alerts | 2 min | Auto-scale |
| Privilege Escalation | All | RBAC audit | 5 min | Alert only |

### Security Preventive Measures

1. **Automated Security Scanning**: Every 4 hours on all exposed ports
2. **Certificate Rotation**: Auto-renew 30 days before expiry
3. **Token Rotation**: Weekly rotation of all service tokens
4. **Audit Log Analysis**: Real-time anomaly detection
5. **Network Segmentation**: Strict firewall rules per port
6. **Rate Limiting**: Automatic rate limits on ports 8888, 31080, 31280

### Emergency Security Contacts

- **Security Team Lead**: security-lead@company.com
- **On-Call Security**: PagerDuty #security-critical
- **Incident Response**: #security-incidents (Slack)
- **24/7 SOC**: +1-555-SEC-RITY

---

*Last Updated: 2025-09-13*
*Document Version: 1.2*
*Classification: Internal Use Only*