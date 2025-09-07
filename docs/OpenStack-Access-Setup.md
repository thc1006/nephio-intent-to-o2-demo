# OpenStack 網路存取設定指南

## 方案 1: Floating IP (推薦)

如果你的 VM 在 OpenStack 上，可以分配 Floating IP 來公開服務：

### 步驟：

1. **分配 Floating IP**
```bash
# 在 OpenStack CLI 或 Horizon Dashboard
openstack floating ip create <external-network>
# 例如: openstack floating ip create public
```

2. **關聯到 VM**
```bash
openstack server add floating ip <vm-name> <floating-ip>
# 例如: openstack server add floating ip vm-1nephio 140.113.xxx.xxx
```

3. **開啟 Security Group 規則**
```bash
# 開放 port 8888 for Gitea
openstack security group rule create <security-group> \
  --protocol tcp \
  --dst-port 8888 \
  --ingress

# 或在 Horizon Dashboard:
# Network → Security Groups → 選擇你的 SG → Add Rule
# Rule: Custom TCP Rule
# Direction: Ingress  
# Port: 8888
```

4. **存取服務**
```
http://<floating-ip>:8888
```

## 方案 2: Load Balancer as a Service (LBaaS)

如果 OpenStack 有 Octavia/LBaaS：

```bash
# 建立 Load Balancer
openstack loadbalancer create --name gitea-lb --vip-subnet-id <subnet-id>

# 建立 Listener
openstack loadbalancer listener create --name gitea-listener \
  --protocol HTTP \
  --protocol-port 80 \
  gitea-lb

# 建立 Pool
openstack loadbalancer pool create --name gitea-pool \
  --lb-algorithm ROUND_ROBIN \
  --listener gitea-listener \
  --protocol HTTP

# 加入 Member (你的 VM)
openstack loadbalancer member create --subnet-id <subnet-id> \
  --address 172.16.0.78 \
  --protocol-port 8888 \
  gitea-pool
```

## 方案 3: 使用現有的 Ingress/Gateway

如果你的 OpenStack 環境已有 Ingress Controller 或 API Gateway：

1. **檢查是否有 Ingress**
```bash
kubectl get ingress -A
kubectl get ingressclass
```

2. **建立 Ingress for Gitea**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitea-ingress
  namespace: gitea-system
spec:
  rules:
  - host: gitea.your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitea-service
            port:
              number: 3000
```

## 方案 4: VPN Access

如果 OpenStack 提供 VPN 服務：

1. **設定 VPNaaS**
```bash
# 建立 VPN Service
openstack vpn service create --name vm-vpn \
  --router <router-name> \
  --subnet <subnet-id>

# 建立 IKE Policy
openstack vpn ike policy create --name ike-policy

# 建立 IPSec Policy  
openstack vpn ipsec policy create --name ipsec-policy

# 建立 VPN Connection
openstack vpn ipsec site connection create \
  --name vpn-connection \
  --vpnservice vm-vpn \
  --ikepolicy ike-policy \
  --ipsecpolicy ipsec-policy \
  --peer-address <your-public-ip> \
  --peer-id <your-public-ip> \
  --psk <pre-shared-key>
```

2. **連線後可直接存取內部 IP**
```
http://172.18.0.2:30924
```

## 方案 5: SSH Bastion/Jump Host

如果有 Bastion Host：

```bash
# 透過 Bastion 建立 tunnel
ssh -J bastion@bastion-host \
    -L 8888:localhost:8888 \
    ubuntu@172.16.0.78
```

## 快速檢查你的 OpenStack 環境

執行以下命令了解可用選項：

```bash
# 檢查 Floating IP
openstack floating ip list

# 檢查 Security Groups
openstack security group list
openstack security group show <your-sg>

# 檢查網路
openstack network list
openstack subnet list

# 檢查 Router
openstack router list
```

## 立即可用的解決方案

如果你有 OpenStack 管理權限，最快的方式：

1. **在 OpenStack Dashboard (Horizon)**:
   - Project → Network → Security Groups
   - 找到你 VM 的 Security Group
   - Add Rule → Custom TCP → Port 8888 → Add

2. **重啟 port-forward 監聽所有介面**:
```bash
# 在 VM 上執行
pkill -f port-forward
kubectl port-forward -n gitea-system \
  svc/gitea-service 8888:3000 \
  --address=0.0.0.0 &
```

3. **從外部存取**:
```
http://172.16.0.78:8888
```

注意：這需要 172.16.0.78 是可路由的，或你有相應的網路設定。