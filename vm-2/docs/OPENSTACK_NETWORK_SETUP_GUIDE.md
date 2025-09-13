# OpenStack 網路設置指南：解決 VM 間連通性問題

**適用環境**: OpenStack 雲端平台
**問題**: ping 失敗但 HTTP 服務可用
**目標**: 實現 VM-1 與 VM-4 完全連通性

---

## 🔍 當前環境分析

### VM-4 (Edge2) 網路狀態
```bash
# 內網 IP: 172.16.0.89 (ens3 介面)
# 外網 IP: 147.251.115.193 (透過 OpenStack 浮動 IP)
# 狀態: HTTP 服務正常，ICMP 被阻擋
```

### OpenStack 元數據確認
- ✅ OpenStack 元數據服務可用 (169.254.169.254)
- ✅ VM 名稱: "VM-4（edge2）"
- ✅ 項目 ID: ebf3aa9e2319468bbd7b9ad04b76907a

---

## 🛠️ OpenStack 設置方案

### 方案 A：安全群組配置 (推薦)

#### 1. 檢查當前安全群組
```bash
# 在有 OpenStack CLI 的管理節點執行
openstack security group list

# 查看 VM-4 的安全群組
openstack server show "VM-4（edge2）" -f value -c security_groups
```

#### 2. 創建或更新安全群組規則
```bash
# 創建專用安全群組
openstack security group create edge2-cluster-sg \
  --description "Security group for VM-4 Edge2 cluster"

# 添加 ICMP 規則 (解決 ping 問題)
openstack security group rule create \
  --protocol icmp \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 添加 HTTP 服務端口
openstack security group rule create \
  --protocol tcp \
  --dst-port 30090 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 添加 O2IMS 端口
openstack security group rule create \
  --protocol tcp \
  --dst-port 31280 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 添加 Kubernetes API 端口
openstack security group rule create \
  --protocol tcp \
  --dst-port 6443 \
  --ingress \
  --remote-ip 172.16.0.0/16 \
  edge2-cluster-sg

# 應用安全群組到 VM-4
openstack server add security group "VM-4（edge2）" edge2-cluster-sg
```

#### 3. 驗證安全群組設置
```bash
# 檢查安全群組規則
openstack security group show edge2-cluster-sg

# 驗證 VM 的安全群組
openstack server show "VM-4（edge2）" -c security_groups
```

### 方案 B：浮動 IP 配置

#### 1. 檢查浮動 IP 狀態
```bash
# 查看浮動 IP
openstack floating ip list

# 檢查 VM-4 的浮動 IP 詳情
openstack floating ip show 147.251.115.193
```

#### 2. 確認浮動 IP 綁定
```bash
# 如果浮動 IP 未正確綁定
openstack server add floating ip "VM-4（edge2）" 147.251.115.193

# 驗證綁定狀態
openstack server show "VM-4（edge2）" -c addresses
```

### 方案 C：網路拓撲檢查

#### 1. 檢查網路和子網
```bash
# 查看網路列表
openstack network list

# 檢查子網配置
openstack subnet list

# 查看路由器配置
openstack router list
openstack router show <router-id>
```

#### 2. 驗證網路連通性
```bash
# 檢查網路命名空間 (在 OpenStack 控制節點)
sudo ip netns list

# 在網路命名空間中測試連通性
sudo ip netns exec <netns> ping 172.16.0.89
```

---

## 🔧 在 VM-4 上的配置調整

### 1. 系統防火牆配置
```bash
# 當前 ufw 規則 (已配置)
sudo ufw status numbered

# 如需要添加 ICMP 支持
sudo ufw allow from 172.16.0.0/16 to any app OpenSSH
sudo ufw allow from 172.16.0.0/16 to any port 22 proto tcp
sudo ufw insert 1 allow from 172.16.0.0/16 to any proto icmp

# 重新載入防火牆
sudo ufw reload
```

### 2. 網路介面優化
```bash
# 檢查網路介面配置
sudo netplan get

# 如需要修改網路配置，編輯 netplan
sudo vim /etc/netplan/50-cloud-init.yaml

# 應用配置 (小心！可能中斷連接)
# sudo netplan apply
```

### 3. 內核網路參數調整
```bash
# 啟用 ICMP 響應 (如果被禁用)
echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all
echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# 永久設置
echo "net.ipv4.icmp_echo_ignore_all = 0" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts = 0" | sudo tee -a /etc/sysctl.conf

# 應用設置
sudo sysctl -p
```

---

## 🧪 測試和驗證

### 1. 從 VM-4 自測
```bash
# 測試本地服務
curl -s http://localhost:30090/health
curl -s http://172.16.0.89:30090/health

# 測試網路連接
ping -c 3 172.16.0.1  # 網關
ping -c 3 172.16.0.78  # VM-1
```

### 2. 從 VM-1 測試
```bash
# 基本連通性
ping -c 3 172.16.0.89

# 服務端點測試
curl -s http://172.16.0.89:30090/health
curl -s http://172.16.0.89:30090/metrics/api/v1/slo

# 端口掃描
nmap -p 30090,31280,6443 172.16.0.89
```

### 3. 從外部測試 (如果需要)
```bash
# 使用浮動 IP 測試
ping -c 3 147.251.115.193
curl -s http://147.251.115.193:30090/health
```

---

## 🏗️ OpenStack 架構優化建議

### 網路架構圖
```
OpenStack 環境
├── 租戶網路 (172.16.0.0/16)
│   ├── VM-1 (SMO): 172.16.0.78
│   └── VM-4 (Edge2): 172.16.0.89
├── 浮動 IP 池
│   └── VM-4 浮動 IP: 147.251.115.193
└── 安全群組
    ├── default (基礎規則)
    └── edge2-cluster-sg (自定義規則)
```

### 最佳實踐配置
```bash
# 創建完整的安全群組配置
openstack security group create nephio-cluster-sg \
  --description "Nephio multi-site cluster security group"

# 允許集群內部全通信
openstack security group rule create \
  --protocol tcp \
  --dst-port 1:65535 \
  --ingress \
  --remote-group nephio-cluster-sg \
  nephio-cluster-sg

openstack security group rule create \
  --protocol udp \
  --dst-port 1:65535 \
  --ingress \
  --remote-group nephio-cluster-sg \
  nephio-cluster-sg

openstack security group rule create \
  --protocol icmp \
  --ingress \
  --remote-group nephio-cluster-sg \
  nephio-cluster-sg

# 應用到所有相關 VM
openstack server add security group "VM-1（SMO）" nephio-cluster-sg
openstack server add security group "VM-4（edge2）" nephio-cluster-sg
```

---

## 🚨 故障排除步驟

### 1. 連通性問題診斷
```bash
# 逐步測試連通性
traceroute 172.16.0.89         # 路由追蹤
mtr -c 10 172.16.0.89          # 網路質量測試
nc -zv 172.16.0.89 30090       # 端口測試
```

### 2. OpenStack 組件檢查
```bash
# 檢查 neutron 代理狀態
openstack network agent list

# 檢查安全群組應用狀態
openstack security group rule list edge2-cluster-sg

# 檢查浮動 IP 路由
openstack floating ip show 147.251.115.193 -c floating_network_id
```

### 3. 系統層面診斷
```bash
# 檢查 iptables 規則
sudo iptables -L -n | grep -E "(30090|31280|ICMP)"

# 檢查路由表
ip route show table all

# 檢查網路命名空間
sudo ip netns exec $(sudo ip netns list | grep -o '^[^ ]*') ping 172.16.0.89
```

---

## 📋 執行檢查清單

### OpenStack 管理員操作
- [ ] 檢查並配置安全群組規則
- [ ] 驗證浮動 IP 綁定狀態
- [ ] 確認網路拓撲和路由配置
- [ ] 測試網路命名空間連通性

### VM-4 系統管理員操作
- [ ] 確認防火牆規則允許 ICMP
- [ ] 檢查內核網路參數
- [ ] 驗證服務端口監聽狀態
- [ ] 測試本地和遠端連通性

### VM-1 整合測試
- [ ] 執行 ping 連通性測試
- [ ] 驗證 HTTP 服務可達性
- [ ] 更新 postcheck.sh 配置
- [ ] 執行多站點驗收測試

---

## 🎯 預期結果

完成上述設置後，應該能夠實現：

✅ **完全連通性**：
- VM-1 能夠 ping 通 VM-4
- HTTP 服務完全可達
- 多站點監控正常運行

✅ **安全性**：
- 僅允許必要的流量
- 維持雲端安全最佳實踐
- 支援未來擴展需求

---

**注意**: 在生產環境中，建議先在測試環境驗證所有網路變更，避免影響現有服務。