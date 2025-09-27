# OpenStack Security Group Configuration Guide

**Version**: 1.2.0
**Last Updated**: 2025-09-27
**Status**: Production Ready - 4 Edge Sites Operational
**Purpose**: Configure network security for 4-site Kubernetes edge deployment

---

## What This Guide Does

This guide helps you set up network security rules in OpenStack for the 4-site Nephio Intent-to-O2 deployment so your edge clusters can communicate properly. Think of Security Groups as firewalls that control which network traffic is allowed.

**4-Site Deployment Architecture (v1.2.0):**
- **VM-1 (SMO)**: 172.16.0.78 - Orchestrator with TMF921 Adapter (8889), Gitea (8888), WebSockets (8002-8004)
- **Edge1 (VM-2)**: 172.16.4.45 - O2IMS (31280), Prometheus (30090), K8s API (6443)
- **Edge2 (VM-4)**: 172.16.4.176 - O2IMS (31281), Prometheus (30090), K8s API (6443)
- **Edge3**: 172.16.5.81 - O2IMS (32080), Prometheus (30090), K8s API (6443)
- **Edge4**: 172.16.1.252 - O2IMS (32080), Prometheus (30090), K8s API (6443)

---

## Key Concepts

### Security Groups = Network Firewalls
- Control what traffic can enter (ingress) or leave (egress) your VMs
- Work like a whitelist - only allow what you specify
- Apply to VM network interfaces

### Why We Need These Rules
Each service in our system uses specific network ports. We must open these ports for the system to work.

---

## Required Ports and Their Purpose

### 1. ICMP (Ping) - Network Testing
**Purpose**: Test if machines can reach each other
```
Protocol: ICMP
Direction: Ingress
Why: Allows ping tests to check network connectivity
Example: ping edge-cluster
```

### 2. SSH (Port 22) - Remote Management
**Purpose**: Secure remote access to manage VMs
```
Protocol: TCP
Port: 22
Direction: Ingress
Why: Allows administrators to connect and manage the system
Example: ssh admin@edge-cluster
```

### 3. Kubernetes API (Port 6443) - Cluster Control
**Purpose**: Main API for Kubernetes cluster management
```
Protocol: TCP
Port: 6443
Direction: Ingress
Why: Required for kubectl commands and cluster operations
Example: kubectl get nodes
```

### 4. NodePort Services - 4-Site Specific Ports
**Purpose**: Access applications running in Kubernetes across all 4 edge sites
```
Protocol: TCP
Direction: Ingress
Why: Kubernetes exposes services on these high ports

4-Site Port Mapping (v1.2.0):
  - 30090: Prometheus metrics (all sites)
  - 31280: Edge1 O2IMS API
  - 31281: Edge2 O2IMS API (different port to avoid conflict)
  - 32080: Edge3/Edge4 O2IMS API
  - 30000-32767: General NodePort range
```

### 5. TMF921 Adapter (Port 8889) - Intent Processing
**Purpose**: TMF921 adapter for automated intent processing
```
Protocol: TCP
Port: 8889
Direction: Ingress
Why: Processes natural language intents into KRM manifests
Example: curl http://172.16.0.78:8889/health
```

### 6. Gitea (Port 8888) - GitOps Repository
**Purpose**: Git repository for configuration management
```
Protocol: TCP
Port: 8888
Direction: Ingress
Why: Stores and serves configuration files for GitOps
Example: git clone http://172.16.0.78:8888/nephio/deployments
```

### 7. WebSocket Services (Ports 8002-8004) - Real-time Communication
**Purpose**: Real-time monitoring and control services
```
Protocol: TCP
Ports: 8002 (Claude Headless), 8003 (Realtime Monitor), 8004 (TMux Bridge)
Direction: Ingress
Why: Enables real-time monitoring and remote terminal access
Example: WebSocket connections for live monitoring
```

---

## How to Configure

### Using OpenStack Web Interface (Horizon)

#### Step 1: Find Your Security Group
1. Log into OpenStack Dashboard
2. Go to: **Project → Network → Security Groups**
3. Find the security group used by your VM
4. Click **Manage Rules**

#### Step 2: Add Rules
For each service you need, click **Add Rule** and fill in:

**Example - Allow Ping:**
```
Rule: All ICMP
Direction: Ingress
Remote: CIDR
CIDR: 10.0.0.0/24  (your management network)
```

**Example - Allow SSH:**
```
Rule: SSH
Direction: Ingress
Remote: CIDR
CIDR: 10.0.0.0/24  (your management network)
```

**Example - Allow Kubernetes API:**
```
Rule: Custom TCP Rule
Direction: Ingress
Port: 6443
Remote: CIDR
CIDR: 172.16.0.0/16  (4-site network range)
```

### Using Command Line (OpenStack CLI)

```bash
# 4-Site Security Group Configuration

# Allow ICMP from all sites
openstack security group rule create \
  --protocol icmp \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

# Allow SSH from VM-1 (orchestrator)
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --ingress \
  --remote-ip 172.16.0.78/32 \
  <SECURITY_GROUP_NAME>

# Allow Kubernetes API from all sites
openstack security group rule create \
  --protocol tcp \
  --dst-port 6443 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

# Allow specific NodePorts for 4-site deployment
# Prometheus on all sites
openstack security group rule create \
  --protocol tcp \
  --dst-port 30090 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

# O2IMS ports (site-specific)
openstack security group rule create \
  --protocol tcp \
  --dst-port 31280:31281 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

openstack security group rule create \
  --protocol tcp \
  --dst-port 32080 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

# TMF921 Adapter on VM-1
openstack security group rule create \
  --protocol tcp \
  --dst-port 8889 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

# Gitea on VM-1
openstack security group rule create \
  --protocol tcp \
  --dst-port 8888 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>

# WebSocket services on VM-1
openstack security group rule create \
  --protocol tcp \
  --dst-port 8002:8004 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  <SECURITY_GROUP_NAME>
```

---

## 4-Site Network Architecture (v1.2.0)

```
Nephio Intent-to-O2 Network (172.16.0.0/16)
    │
    ├── VM-1 SMO/Orchestrator (172.16.0.78)
    │   ├── TMF921 Adapter: 8889
    │   ├── Gitea Repository: 8888
    │   ├── Claude Headless: 8002
    │   ├── Realtime Monitor: 8003
    │   └── TMux Bridge: 8004
    │
    ├── Edge1 (VM-2): 172.16.4.45
    │   ├── Kubernetes API: 6443
    │   ├── O2IMS API: 31280
    │   └── Prometheus: 30090
    │
    ├── Edge2 (VM-4): 172.16.4.176
    │   ├── Kubernetes API: 6443
    │   ├── O2IMS API: 31281 (different port)
    │   └── Prometheus: 30090
    │
    ├── Edge3: 172.16.5.81
    │   ├── Kubernetes API: 6443
    │   ├── O2IMS API: 32080
    │   └── Prometheus: 30090
    │
    └── Edge4: 172.16.1.252
        ├── Kubernetes API: 6443
        ├── O2IMS API: 32080
        └── Prometheus: 30090
```

---

## Security Best Practices

### 1. Use Specific Source IPs
Instead of allowing traffic from anywhere (0.0.0.0/0), specify exact source networks:
- ✅ Good: Allow SSH from 10.0.0.10/32 (specific admin machine)
- ❌ Bad: Allow SSH from 0.0.0.0/0 (entire internet)

### 2. Minimize Open Ports
Only open ports you actually use:
- ✅ Open port 30090 if you have SLO monitoring
- ❌ Don't open entire 30000-32767 range if you only use 2-3 ports

### 3. Document Your Rules
Add descriptions to explain why each rule exists:
```
Description: "Allow K8s API from management network for kubectl access"
```

---

## Troubleshooting

### Connection Refused
**Problem**: Service port appears closed
**Check**:
1. Is the service actually running? `kubectl get svc`
2. Is it listening on the right interface? `netstat -tlnp`
3. Is the Security Group rule applied to the VM?

### Timeout Issues
**Problem**: Connection attempts hang
**Check**:
1. Security Group rules (most common issue)
2. Network routing between VMs
3. Service binding (0.0.0.0 vs localhost)

### Testing Connectivity
```bash
# Test basic network
ping <target-ip>

# Test specific port
nc -vz <target-ip> <port>

# Test service response
curl http://<target-ip>:<port>/health
```

---

## Common Configurations

### Development Environment
- Open all ports between development VMs
- Allow SSH from developer workstations
- Less restrictive for easier testing

### Production Environment
- Only allow specific required ports
- Restrict source IPs to known systems
- Enable logging for security audit

### GitOps Setup
Essential ports for GitOps workflow:
- 8888: Gitea repository
- 6443: Kubernetes API
- 22: SSH for troubleshooting

---

## Quick Reference

| Service | Port | Protocol | Purpose | Site |
| SSH | 22 | TCP | Remote management | All sites |
| Kubernetes API | 6443 | TCP | Cluster control | Edge1-4 |
| TMF921 Adapter | 8889 | TCP | Intent processing | VM-1 only |
| Gitea | 8888 | TCP | Git repository | VM-1 only |
| Prometheus | 30090 | TCP | Metrics collection | All edge sites |
| Edge1 O2IMS | 31280 | TCP | O-RAN interface | Edge1 only |
| Edge2 O2IMS | 31281 | TCP | O-RAN interface | Edge2 only |
| Edge3/4 O2IMS | 32080 | TCP | O-RAN interface | Edge3/4 only |
| Claude Headless | 8002 | TCP | WebSocket service | VM-1 only |
| Realtime Monitor | 8003 | TCP | WebSocket service | VM-1 only |
| TMux Bridge | 8004 | TCP | WebSocket service | VM-1 only |
| Ping | - | ICMP | Network testing | All sites |

---

## Next Steps

1. Identify which services you need
2. Create Security Group rules for those services
3. Test connectivity using the troubleshooting commands
4. Document your configuration for team reference

Remember: Start with restrictive rules and open ports as needed. It's easier to add access than to secure an overly open system later.