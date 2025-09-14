# OpenStack Security Group 設置指南

## 必要的 Security Group 規則

### 1. VM-1 到 VM-3 LLM Adapter 通訊

```bash
# 創建 Security Group
openstack security group create llm-adapter-sg --description "LLM Adapter Service Access"

# 規則 1: 允許 VM-1 訪問 VM-3 的 8888 端口
openstack security group rule create llm-adapter-sg \
  --protocol tcp \
  --dst-port 8888 \
  --remote-ip 172.16.0.78/32 \
  --ingress

# 規則 2: 允許健康檢查 (ICMP)
openstack security group rule create llm-adapter-sg \
  --protocol icmp \
  --remote-ip 172.16.0.0/16 \
  --ingress

# 規則 3: 允許 SSH 管理（可選）
openstack security group rule create llm-adapter-sg \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 172.16.0.78/32 \
  --ingress
```

### 2. VM-1 GitOps Orchestrator 規則

```bash
# 創建 GitOps Orchestrator Security Group
openstack security group create gitops-orchestrator-sg

# 規則 1: Gitea Web UI
openstack security group rule create gitops-orchestrator-sg \
  --protocol tcp \
  --dst-port 8888 \
  --remote-ip 0.0.0.0/0 \
  --ingress

# 規則 2: Gitea SSH
openstack security group rule create gitops-orchestrator-sg \
  --protocol tcp \
  --dst-port 2222 \
  --remote-ip 172.16.0.0/16 \
  --ingress

# 規則 3: Kubernetes API (如果需要外部訪問)
openstack security group rule create gitops-orchestrator-sg \
  --protocol tcp \
  --dst-port 6443 \
  --remote-ip 172.16.0.0/16 \
  --ingress
```

### 3. Edge 站點通訊規則

```bash
# Edge 站點 Security Group
openstack security group create edge-sites-sg

# 規則 1: Kubernetes API
openstack security group rule create edge-sites-sg \
  --protocol tcp \
  --dst-port 6443 \
  --remote-ip 172.16.0.0/16 \
  --ingress

# 規則 2: NodePort 服務範圍
openstack security group rule create edge-sites-sg \
  --protocol tcp \
  --dst-port 30000:32767 \
  --remote-ip 172.16.0.0/16 \
  --ingress

# 規則 3: O2IMS API
openstack security group rule create edge-sites-sg \
  --protocol tcp \
  --dst-port 31280 \
  --remote-ip 172.16.0.0/16 \
  --ingress

# 規則 4: SLO Service
openstack security group rule create edge-sites-sg \
  --protocol tcp \
  --dst-port 30090 \
  --remote-ip 172.16.0.0/16 \
  --ingress
```

### 4. 跨網段通訊（VM-3 特殊情況）

如果 VM-3 在不同網段 (192.168.0.0/24)：

```bash
# 選項 1: 使用 Any-Any 規則（較不安全但簡單）
openstack security group rule create llm-adapter-sg \
  --protocol tcp \
  --dst-port 8888 \
  --remote-ip 0.0.0.0/0 \
  --ingress

# 選項 2: 明確允許兩個網段
openstack security group rule create llm-adapter-sg \
  --protocol tcp \
  --dst-port 8888 \
  --remote-group gitops-orchestrator-sg \
  --ingress
```

## 應用 Security Groups 到 VM

```bash
# 應用到 VM-1
openstack server add security group VM-1 gitops-orchestrator-sg

# 應用到 VM-3
openstack server add security group VM-3 llm-adapter-sg

# 應用到 VM-2 和 VM-4
openstack server add security group VM-2 edge-sites-sg
openstack server add security group VM-4 edge-sites-sg
```

## 驗證連線

### 從 VM-1 測試所有連線

```bash
# 測試 VM-3 LLM Adapter
ping -c 2 172.16.2.10
curl -v http://172.16.2.10:8888/health

# 測試 VM-2 Edge1
ping -c 2 172.16.4.45
nc -vz 172.16.4.45 6443
curl http://172.16.4.45:30090/health

# 測試 VM-4 Edge2
ping -c 2 172.16.0.89
nc -vz 172.16.0.89 6443
```

## 故障排除

### 1. 無法 ping 通

檢查 ICMP 規則：
```bash
openstack security group rule list llm-adapter-sg | grep icmp
```

### 2. TCP 連線被拒絕

檢查特定端口規則：
```bash
openstack security group rule list llm-adapter-sg | grep 8888
```

### 3. 跨網段不通

檢查路由：
```bash
# 在 VM-1 上
ip route
traceroute 172.16.2.10

# 檢查 Neutron 路由器
openstack router show demo-router
```

### 4. 查看當前 Security Groups

```bash
# 查看 VM 的 Security Groups
openstack server show VM-1 -c security_groups
openstack server show VM-3 -c security_groups

# 查看規則詳情
openstack security group show llm-adapter-sg
```

## 最小必要設置

如果時間緊迫，至少要設置：

```bash
# 1. VM-3 允許 8888 端口
openstack security group rule create default \
  --protocol tcp \
  --dst-port 8888 \
  --remote-ip 172.16.0.78/32

# 2. 允許 ICMP (ping)
openstack security group rule create default \
  --protocol icmp \
  --remote-ip 172.16.0.0/16
```

---
最後更新：2025-09-14
注意：請根據實際網路拓撲調整 IP 範圍