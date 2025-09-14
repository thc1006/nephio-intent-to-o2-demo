# OpenStack ICMP 配置指南

## 問題診斷
VM-1 (172.16.0.78) 無法 ping 通 VM-4 (172.16.0.89)，但 TCP 連接正常

## 解決方案

### 方法 1: 使用 OpenStack CLI

```bash
# 1. 列出現有安全群組
openstack security group list

# 2. 找到 VM-4 使用的安全群組 (假設為 default 或 edge2-sg)
openstack server show VM-4 -c security_groups

# 3. 添加 ICMP 規則 (允許所有 ICMP)
openstack security group rule create \
  --protocol icmp \
  --ingress \
  <SECURITY_GROUP_NAME>

# 或者只允許特定來源 (VM-1)
openstack security group rule create \
  --protocol icmp \
  --remote-ip 172.16.0.78/32 \
  --ingress \
  <SECURITY_GROUP_NAME>

# 4. 允許 ICMP Echo Request (ping)
openstack security group rule create \
  --protocol icmp \
  --icmp-type 8 \
  --icmp-code 0 \
  --ingress \
  <SECURITY_GROUP_NAME>

# 5. 允許 ICMP Echo Reply
openstack security group rule create \
  --protocol icmp \
  --icmp-type 0 \
  --icmp-code 0 \
  --egress \
  <SECURITY_GROUP_NAME>
```

### 方法 2: 使用 OpenStack Horizon (Web UI)

1. 登入 OpenStack Dashboard
2. 導航至: Project → Network → Security Groups
3. 找到 VM-4 使用的安全群組
4. 點擊 "Manage Rules"
5. 點擊 "Add Rule"
6. 配置:
   - Rule: All ICMP
   - Direction: Ingress
   - Remote: CIDR
   - CIDR: 172.16.0.0/16 (或 172.16.0.78/32 更嚴格)
7. 點擊 "Add"

### 方法 3: 使用 Neutron CLI

```bash
# 1. 列出安全群組
neutron security-group-list

# 2. 添加 ICMP 規則
neutron security-group-rule-create \
  --protocol icmp \
  --direction ingress \
  --remote-ip-prefix 172.16.0.0/16 \
  <SECURITY_GROUP_ID>
```

### 方法 4: 使用 Heat Template (Infrastructure as Code)

```yaml
resources:
  icmp_rule:
    type: OS::Neutron::SecurityGroupRule
    properties:
      security_group: { get_resource: edge2_security_group }
      protocol: icmp
      direction: ingress
      remote_ip_prefix: 172.16.0.0/16
```

## 驗證步驟

```bash
# 1. 檢查規則是否生效
openstack security group rule list <SECURITY_GROUP_NAME> | grep icmp

# 2. 從 VM-1 測試 ping
ping -c 3 172.16.0.89

# 3. 檢查路由表 (如果仍有問題)
openstack router list
openstack router show <ROUTER_NAME>

# 4. 檢查網路拓撲
openstack network list
openstack subnet list
```

## 常見問題排查

### 1. 如果添加規則後仍無法 ping

```bash
# 檢查 VM-4 內部防火牆
ssh ubuntu@172.16.0.89
sudo iptables -L -n | grep ICMP
sudo ufw status

# 如果 ufw 啟用，允許 ICMP
sudo ufw allow from 172.16.0.78 to any proto icmp
```

### 2. 檢查 OpenStack 網路配置

```bash
# 檢查 port security
openstack port list --server VM-4
openstack port show <PORT_ID> | grep port_security_enabled

# 如果 port security 阻擋，可以暫時禁用 (不建議生產環境)
openstack port set --no-security-group --disable-port-security <PORT_ID>
```

### 3. 使用 tcpdump 診斷

```bash
# 在 VM-4 上監聽 ICMP
sudo tcpdump -i any icmp -n

# 在 VM-1 上發送 ping
ping 172.16.0.89
```

## 建議的最小安全群組規則

```bash
# 為 Edge2 cluster 創建專用安全群組
openstack security group create edge2-cluster-sg \
  --description "Security group for Edge2 Kubernetes cluster"

# 基本規則集
# 1. SSH (管理)
openstack security group rule create \
  --protocol tcp --dst-port 22 \
  --remote-ip 172.16.0.78/32 \
  edge2-cluster-sg

# 2. Kubernetes API
openstack security group rule create \
  --protocol tcp --dst-port 6443 \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 3. NodePort 範圍
openstack security group rule create \
  --protocol tcp --dst-port 30000:32767 \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 4. ICMP (診斷)
openstack security group rule create \
  --protocol icmp \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 5. 應用到 VM-4
openstack server add security group VM-4 edge2-cluster-sg
```

## 注意事項

1. **安全考量**: 只開放必要的 ICMP 類型，避免 ICMP 洪水攻擊
2. **監控**: 記錄 ICMP 流量以偵測異常
3. **文檔化**: 記錄所有安全群組變更
4. **最小權限**: 只允許必要的來源 IP

## 快速修復命令 (一行解決)

```bash
# 最快速的解決方案 (允許所有 ICMP)
openstack security group rule create --protocol icmp --ingress default

# 或者使用 Neutron
neutron security-group-rule-create --protocol icmp --direction ingress default
```