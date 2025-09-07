# OpenStack Security Group 設定指南

## Ingress vs Egress 說明

- **Ingress (入站)**: 從外部進入 VM 的流量 ← 這是你需要的
- **Egress (出站)**: 從 VM 出去的流量

## 設定 Ingress 規則允許存取 Gitea

### 方法 1: OpenStack CLI

```bash
# 查看你的 security group
openstack security group list

# 假設你的 security group 叫 "default" 或 "vm-1nephio-sg"
# 新增 Ingress 規則允許 port 8888
openstack security group rule create <security-group-name> \
  --protocol tcp \
  --dst-port 8888:8888 \
  --remote-ip 0.0.0.0/0 \
  --ingress

# 或只允許你的 IP (更安全)
openstack security group rule create <security-group-name> \
  --protocol tcp \
  --dst-port 8888:8888 \
  --remote-ip <your-public-ip>/32 \
  --ingress
```

### 方法 2: OpenStack Dashboard (Horizon)

1. 登入 OpenStack Dashboard
2. 進入 **Project → Network → Security Groups**
3. 找到你 VM 使用的 Security Group (通常是 default 或 VM 名稱相關)
4. 點擊 **Manage Rules**
5. 點擊 **Add Rule**
6. 設定：
   - **Rule**: Custom TCP Rule
   - **Direction**: Ingress (入站)
   - **Open Port**: Port
   - **Port**: 8888
   - **Remote**: CIDR
   - **CIDR**: 0.0.0.0/0 (允許所有) 或 你的IP/32 (只允許你)
7. 點擊 **Add**

### 方法 3: 使用現有的 HTTP/HTTPS 規則

如果已有 HTTP (80) 或 HTTPS (443) 規則，可以改用這些 port：

```bash
# 在 VM 上，改用 port 80
sudo kubectl port-forward -n gitea-system svc/gitea-service 80:3000 --address=0.0.0.0

# 或使用 nginx 反向代理
sudo apt-get install -y nginx
sudo tee /etc/nginx/sites-available/gitea << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://172.18.0.2:30924;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/gitea /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

## 完整設定步驟

### Step 1: 確認 VM 的 Security Group

```bash
# 在 OpenStack CLI
openstack server show vm-1nephio -f value -c security_groups

# 或查看所有 security groups
openstack security group list
```

### Step 2: 新增 Ingress Rule

```bash
# 假設 security group 是 "default"
openstack security group rule create default \
  --protocol tcp \
  --dst-port 8888 \
  --ingress \
  --description "Gitea Web UI"
```

### Step 3: 在 VM 上啟動 port-forward

```bash
# 確保監聽所有介面 (0.0.0.0)
pkill -f port-forward 2>/dev/null || true
kubectl port-forward -n gitea-system svc/gitea-service 8888:3000 --address=0.0.0.0 > /tmp/pf.log 2>&1 &
```

### Step 4: 測試存取

```bash
# 從 VM 內部測試
curl http://localhost:8888

# 從外部測試 (你的筆電)
curl http://172.16.0.78:8888
# 或瀏覽器訪問
http://172.16.0.78:8888
```

## 安全建議

1. **限制 IP 範圍**：不要用 0.0.0.0/0，改用你的特定 IP
   ```bash
   # 查詢你的公網 IP
   curl ifconfig.me
   
   # 只允許你的 IP
   --remote-ip <your-ip>/32
   ```

2. **使用 VPN**：如果有企業 VPN，連上 VPN 後可能就能直接存取內網

3. **定期檢查規則**：
   ```bash
   openstack security group rule list <security-group>
   ```

## 疑難排解

如果還是無法連線：

1. **檢查 port-forward 狀態**
   ```bash
   ps aux | grep port-forward
   netstat -tlnp | grep 8888
   ```

2. **檢查防火牆**
   ```bash
   sudo iptables -L -n | grep 8888
   sudo ufw status
   ```

3. **檢查路由**
   ```bash
   ip route
   traceroute 172.16.0.78
   ```

4. **確認 OpenStack 網路**
   - VM 是否有正確的網路介面
   - Subnet 是否可路由
   - 是否需要 Floating IP