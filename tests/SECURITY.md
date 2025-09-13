# Security Operations Manual

**Version:** 1.0.0  
**Last Updated:** 2025-09-13
**Security Level:** Demo Environment

## Network Security

### IP Address Whitelist
**Allowed source IPs for demo access:**
- **VM-1 (SMO):** localhost, 127.0.0.1
- **VM-2 (Edge1):** 172.16.4.45
- **VM-3 (LLM):** 172.16.2.10  
- **VM-4 (Edge2):** TBD (update when deployed)
- **Demo operators:** [Add specific operator IPs]

### Port Access Control
| Port | Service | Access Level | Whitelist |
|------|---------|--------------|-----------|
| 6443 | Kubernetes API | Restricted | Admin IPs only |
| 31080 | HTTP NodePort | Demo-public | All demo users |
| 31443 | HTTPS NodePort | Demo-public | All demo users |
| 31280 | O2IMS API | Restricted | SMO + operators |
| 8888 | LLM Adapter | Restricted | VM-1 only |

### Firewall Configuration
```bash
# VM-2 Edge1 (172.16.4.45)
sudo ufw allow from 172.16.4.0/24 to any port 6443    # K8s API
sudo ufw allow from any to any port 31080             # HTTP demo access  
sudo ufw allow from any to any port 31443             # HTTPS demo access
sudo ufw allow from 172.16.2.10 to any port 31280    # O2IMS restricted

# VM-3 LLM (172.16.2.10)  
sudo ufw allow from 172.16.4.45 to any port 8888     # LLM adapter restricted
sudo ufw deny from any to any port 8888               # Deny all others
```

## Access Control & Authentication

### 5-Minute Security Incident Response
**When:** Suspicious activity detected, immediate lockdown needed

1. **Isolate affected systems** (60 seconds)
   ```bash
   # Block suspicious IP
   sudo ufw insert 1 deny from <SUSPICIOUS_IP>
   
   # Emergency service stop  
   ssh vm3 "sudo systemctl stop llm-adapter"  # If LLM compromised
   ```

2. **Assess damage** (120 seconds)
   ```bash
   # Check active connections
   netstat -an | grep ESTABLISHED
   
   # Review recent logs
   tail -50 /var/log/auth.log | grep FAILED
   ```

3. **Secure and document** (120 seconds)  
   ```bash
   # Change critical credentials
   kubectl --context edge1 -n config-management-system get secrets
   
   # Log incident  
   echo "$(date): Security incident - IP blocked: <SUSPICIOUS_IP>" >> security.log
   ```

### Credential Management
**Demo environment credentials (rotate weekly):**

- **Kubernetes contexts:** edge1, edge2
  ```bash
  # Rotate kubeconfig
  kubectl config view --raw > backup-kubeconfig-$(date +%Y%m%d)
  ```

- **LLM Adapter API keys:**
  ```bash  
  # Update API key (coordinate with VM-3)
  ssh vm3 "sudo systemctl edit llm-adapter"  
  ```

- **O2IMS certificates:**
  ```bash
  # Check cert expiry
  curl -k https://172.16.4.45:31443 | openssl x509 -noout -dates
  ```

### GitOps Security

#### Repository Access Control
- **Read access:** Demo operators, viewers
- **Write access:** Platform engineers only  
- **Admin access:** Team leads, security team

#### Commit Signing
```bash
# Enable commit signing
git config --global commit.gpgsign true
git config --global user.signingkey <KEY_ID>

# Verify signatures
git log --show-signature -n 5
```

#### Branch Protection
- **main branch:** Require PR reviews, signed commits
- **develop branch:** Require status checks  
- **feature branches:** No restrictions

## Common Security Failures & Rapid Response

### 1. Unauthorized API Access (Port 6443)
**Symptoms:** Unknown kubectl commands in logs, API rate limiting

**5-minute containment:**
```bash
# Check API server logs
kubectl --context edge1 logs -n kube-system kube-apiserver-* | grep FORBIDDEN

# Block suspicious IPs immediately
sudo ufw insert 1 deny from <SUSPICIOUS_IP>

# Rotate service account tokens  
kubectl --context edge1 delete secret --all -n config-management-system
```

### 2. LLM Adapter Compromise (Port 8888)
**Symptoms:** Unusual intent generation, high traffic to VM-3

**5-minute containment:**
```bash
# Stop LLM adapter immediately
ssh vm3 "sudo systemctl stop llm-adapter"

# Check for malicious payloads
ssh vm3 "tail -100 /var/log/llm-adapter.log | grep -E '(script|exec|eval)'"

# Restart with clean state
ssh vm3 "sudo systemctl start llm-adapter"
```

### 3. O2IMS Data Exposure (Port 31280)  
**Symptoms:** Unauthorized access to O-RAN interfaces

**5-minute containment:**
```bash
# Restrict O2IMS access immediately
kubectl --context edge1 patch service o2ims-api -p '{"spec":{"type":"ClusterIP"}}'

# Check access logs
kubectl --context edge1 logs -n o2ims -l app=o2ims-api | grep -E "(POST|PUT|DELETE)"

# Re-enable with restrictions
kubectl --context edge1 patch service o2ims-api -p '{"spec":{"type":"NodePort"}}'
```

## Network Security Monitoring

### Traffic Analysis
```bash
# Monitor suspicious patterns
sudo netstat -an | grep ":6443\|:31080\|:31280\|:8888" | sort

# Check connection sources  
sudo ss -tuln | grep -E "(6443|31080|31280|8888)"

# Log analysis for intrusion detection
grep -E "(FAILED|INVALID|BREAK)" /var/log/auth.log | tail -20
```

### Rate Limiting Configuration
```yaml
# Nginx rate limiting (if applicable)
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=llm:10m rate=5r/s;

server {
    location /api/ {
        limit_req zone=api burst=20 nodelay;
    }
    location /intent {
        limit_req zone=llm burst=5 nodelay;  
    }
}
```

## Data Protection

### Sensitive Data Handling
**Demo environment contains:**
- Network topology information
- Service configurations  
- Performance metrics
- Intent/expectation data

**Protection measures:**
```bash
# Encrypt sensitive configs at rest
ansible-vault encrypt gitops/edge1-config/secrets.yaml
ansible-vault encrypt gitops/edge2-config/secrets.yaml

# Secure log transmission
rsyslog with TLS to central log server (if configured)
```

### Backup Security
```bash
# Encrypted backups
tar -czf - gitops/ tests/golden/ | gpg -c > backup-$(date +%Y%m%d).tar.gz.gpg

# Secure backup verification
gpg -d backup-$(date +%Y%m%d).tar.gz.gpg | tar -tz | head -10
```

## Compliance & Audit

### Security Checklist (Weekly)
- [ ] **Access logs reviewed**
  ```bash
  grep -E "(FAILED|DENIED)" /var/log/auth.log | wc -l
  ```
- [ ] **Firewall rules validated**
  ```bash  
  sudo ufw status numbered | grep -E "(6443|31080|31280|8888)"
  ```
- [ ] **Certificate expiry checked**
  ```bash
  curl -k https://172.16.4.45:31443 2>/dev/null | openssl x509 -noout -dates
  ```
- [ ] **API access patterns analyzed**
  ```bash
  kubectl --context edge1 get events --sort-by='.lastTimestamp' | tail -20
  ```

### Incident Documentation
**Required for all security events:**

1. **Timeline:** When detected, when contained, when resolved
2. **Impact:** Which services/data affected  
3. **Root cause:** How breach occurred
4. **Remediation:** Steps taken to fix and prevent
5. **Lessons learned:** Process improvements

### Security Contacts
- **Security Team:** Immediate escalation for breaches
- **Platform Team:** Infrastructure security issues
- **Legal/Compliance:** Data exposure incidents  
- **External CERT:** Coordinated vulnerability disclosure

## Risk Assessment

### Demo Environment Risks
| Risk | Likelihood | Impact | Mitigation |
|------|------------|---------|------------|
| API credential exposure | Medium | High | Regular rotation, monitoring |
| Network eavesdropping | Low | Medium | TLS encryption, network segmentation |  
| Service disruption | High | Medium | Rate limiting, DDoS protection |
| Data extraction | Low | High | Access controls, audit logging |

### Acceptable Risk Level
**Demo environment accepts:**
- Higher availability vs security trade-offs
- Simplified authentication for demo purposes  
- Limited encryption for performance  

**Not acceptable:**
- Credential reuse across environments
- Production data in demo systems
- Unmonitored administrative access

---
**Security Officer:** [Contact for security incidents]
**Next Security Review:** Monthly
**Emergency Security Contact:** 24/7 security hotline
