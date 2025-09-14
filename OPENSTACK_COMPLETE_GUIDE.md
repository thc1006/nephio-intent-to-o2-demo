# OpenStack Security Group Configuration Guide

**Last Updated**: 2025-09-14
**Purpose**: Configure network security for Kubernetes edge clusters

---

## What This Guide Does

This guide helps you set up network security rules in OpenStack so your edge clusters can communicate properly. Think of Security Groups as firewalls that control which network traffic is allowed.

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

### 4. NodePort Services (Ports 30000-32767) - Application Access
**Purpose**: Access applications running in Kubernetes
```
Protocol: TCP
Port Range: 30000-32767
Direction: Ingress
Why: Kubernetes exposes services on these high ports
Common ports:
  - 30090: SLO monitoring service
  - 31280: O2IMS API service
  - 30000-32767: Other services
```

### 5. Gitea (Port 8888) - GitOps Repository
**Purpose**: Git repository for configuration management
```
Protocol: TCP
Port: 8888
Direction: Ingress
Why: Stores and serves configuration files for GitOps
Example: git clone http://gitea-server:8888/config-repo
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
CIDR: 10.0.0.0/16  (your cluster network)
```

### Using Command Line (OpenStack CLI)

```bash
# Allow ICMP from management network
openstack security group rule create \
  --protocol icmp \
  --ingress \
  --remote-ip 10.0.0.0/24 \
  <SECURITY_GROUP_NAME>

# Allow SSH from specific admin machine
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --ingress \
  --remote-ip 10.0.0.10/32 \
  <SECURITY_GROUP_NAME>

# Allow Kubernetes API from cluster network
openstack security group rule create \
  --protocol tcp \
  --dst-port 6443 \
  --ingress \
  --remote-ip 10.0.0.0/16 \
  <SECURITY_GROUP_NAME>

# Allow NodePort range
openstack security group rule create \
  --protocol tcp \
  --dst-port 30000:32767 \
  --ingress \
  --remote-ip 10.0.0.0/16 \
  <SECURITY_GROUP_NAME>
```

---

## Network Architecture Example

```
Management Network (10.0.0.0/24)
    │
    ├── Admin Workstation (10.0.0.10)
    │   └── Needs: SSH, K8s API access
    │
    ├── GitOps Server (10.0.0.20)
    │   └── Provides: Gitea on port 8888
    │
    └── Edge Clusters (10.0.1.0/24)
        ├── Edge-1 (10.0.1.10)
        │   └── Needs: All ports listed above
        └── Edge-2 (10.0.1.20)
            └── Needs: All ports listed above
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

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| SSH | 22 | TCP | Remote management |
| Kubernetes API | 6443 | TCP | Cluster control |
| SLO Monitor | 30090 | TCP | Performance metrics |
| O2IMS API | 31280 | TCP | O-RAN interface |
| Gitea | 8888 | TCP | Git repository |
| NodePorts | 30000-32767 | TCP | General services |
| Ping | - | ICMP | Network testing |

---

## Next Steps

1. Identify which services you need
2. Create Security Group rules for those services
3. Test connectivity using the troubleshooting commands
4. Document your configuration for team reference

Remember: Start with restrictive rules and open ports as needed. It's easier to add access than to secure an overly open system later.