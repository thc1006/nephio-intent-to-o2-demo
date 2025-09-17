# Network Topology Documentation

## VM Network Configuration

### VM-3 (LLM Adapter) - This VM
```yaml
External IP: 147.251.115.156
Group Project Network (ens4): 192.168.0.201/24
Internal IPv4 (ens3): 172.16.2.10/16
Service Port: 8888
Service Binding: 0.0.0.0:8888 (all interfaces)
```

### VM-1 (Nephio / Intent Gateway)
```yaml
External IP: 147.251.115.143
Group Project Network: 192.168.0.47/24
Internal IPv4: 172.16.0.78/16
Connection to VM-3: http://192.168.0.201:8888
```

### VM-2
```yaml
External IP: 147.251.115.129
Group Project Network: 192.168.0.174/24
Internal IPv4: 172.16.4.45/16
Connection to VM-3: http://192.168.0.201:8888
```

### VM-4 (Edge2)
```yaml
External IP: 147.251.115.193
External IPv6: 2001:718:801:43b:f816:3eff:fe3e:cb45
Internal IPv4: 172.16.4.176/16
Group Project Network: NOT AVAILABLE
Connection to VM-3: http://172.16.2.10:8888 (must use internal-ipv4)
```

## Network Connectivity Matrix

| From | To | Network | URL/IP |
|------|-----|---------|--------|
| VM-1 | VM-3 | group-project-network | http://192.168.0.201:8888 |
| VM-2 | VM-3 | group-project-network | http://192.168.0.201:8888 |
| VM-4 | VM-3 | internal-ipv4 | http://172.16.2.10:8888 |
| VM-3 | VM-1 | group-project-network | 192.168.0.47 |
| VM-3 | VM-2 | group-project-network | 192.168.0.174 |
| VM-3 | VM-4 | internal-ipv4 | 172.16.4.176 |

## Important Notes

1. **VM-4 Connectivity**: VM-4 (Edge2) does NOT have access to group-project-network. It can only communicate via internal-ipv4 network.

2. **Service Binding**: The LLM Adapter service binds to 0.0.0.0:8888, making it accessible from both network interfaces.

3. **Target Site Mapping**:
   - `edge1` → VM-1 (Nephio)
   - `edge2` → VM-4
   - `both` → VM-1 and VM-4

## Testing Connectivity

### From VM-1 to VM-3
```bash
ping 192.168.0.201
curl http://192.168.0.201:8888/health
```

### From VM-4 to VM-3
```bash
ping 172.16.2.10
curl http://172.16.2.10:8888/health
```

### From VM-3 (local test)
```bash
curl http://localhost:8888/health
curl http://192.168.0.201:8888/health
curl http://172.16.2.10:8888/health
```

## Service Access URLs

- **For VM-1**: `http://192.168.0.201:8888`
- **For VM-2**: `http://192.168.0.201:8888`
- **For VM-4**: `http://172.16.2.10:8888`
- **External SSH**: `ssh ubuntu@147.251.115.156`