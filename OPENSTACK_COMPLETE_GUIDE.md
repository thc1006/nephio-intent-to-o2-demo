# 📚 OpenStack 完整配置指南
**最後更新**: 2025-09-14
**狀態**: ✅ 整合版本

---

## 🔧 Security Group 配置

### GUI 配置步驟
1. 登入 OpenStack Horizon Dashboard
2. Project → Network → Security Groups
3. 找到目標 VM 的 Security Group → Manage Rules

### 必要規則設置

#### ICMP (Ping)
```
Rule: All ICMP
Direction: Ingress
Remote: CIDR
CIDR: 172.16.0.78/32  # VM-1 IP
```

#### SSH
```
Rule: SSH
Direction: Ingress
Port: 22
Remote: CIDR
CIDR: 172.16.0.78/32
```

#### Kubernetes API
```
Rule: Custom TCP Rule
Direction: Ingress
Port: 6443
Remote: CIDR
CIDR: 172.16.0.0/16  # 內部網段
```

#### NodePort 範圍
```
Rule: Custom TCP Rule
Direction: Ingress
Port Range: 30000-32767
Remote: CIDR
CIDR: 172.16.0.0/16
```

---

## 🖥️ CLI 配置命令

### 使用 OpenStack CLI
```bash
# ICMP
openstack security group rule create \
  --protocol icmp \
  --remote-ip 172.16.0.78/32 \
  --ingress \
  <SECURITY_GROUP_NAME>

# SSH
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 172.16.0.78/32 \
  --ingress \
  <SECURITY_GROUP_NAME>

# Kubernetes API
openstack security group rule create \
  --protocol tcp \
  --dst-port 6443 \
  --remote-ip 172.16.0.0/16 \
  --ingress \
  <SECURITY_GROUP_NAME>

# NodePort Range
openstack security group rule create \
  --protocol tcp \
  --dst-port 30000:32767 \
  --remote-ip 172.16.0.0/16 \
  --ingress \
  <SECURITY_GROUP_NAME>
```

---

## 🚨 故障排除

### 連線問題診斷
1. 檢查 Security Group 規則是否正確套用
2. 驗證服務是否在目標端口運行
3. 確認網路路由正確

### 常見問題
- **ICMP 不通**: 檢查 OpenStack Security Groups
- **SSH 超時**: 確認 SSH 服務運行且防火牆開放
- **API 無法訪問**: 驗證服務綁定的 IP 地址

---

## 📝 重要提醒
- 使用內部 IP (172.16.0.78) 而非外部 IP
- 生產環境使用最小權限原則
- 定期審查安全規則