# OpenStack Security Group Rules 詳細欄位說明

**目標**: 為 VM-4 Edge2 配置正確的安全群組規則
**環境**: OpenStack 雲端平台
**需求**: 允許 VM-1 與 VM-4 完全連通

---

## 📋 Security Group Rule 欄位詳解

### 基本語法結構
```bash
openstack security group rule create \
  --protocol <協議類型> \
  --direction <流量方向> \
  --ethertype <網路層協議> \
  --port-range-min <最小端口> \
  --port-range-max <最大端口> \
  --remote-ip <來源IP範圍> \
  --remote-group <來源安全群組> \
  --description "<規則描述>" \
  <目標安全群組名稱或ID>
```

---

## 🔍 每個欄位的詳細說明

### 1. `--protocol` (協議類型)
**必填欄位**，指定網路協議

| 值 | 說明 | 使用場景 |
|---|------|----------|
| `tcp` | TCP 協議 | HTTP, HTTPS, SSH, Kubernetes API |
| `udp` | UDP 協議 | DNS, DHCP, 某些應用服務 |
| `icmp` | ICMP 協議 | Ping, 網路診斷 |
| `ah` | Authentication Header | IPSec |
| `dccp` | Datagram Congestion Control Protocol | 特殊應用 |
| `egp` | Exterior Gateway Protocol | 路由協議 |
| `esp` | Encapsulating Security Payload | IPSec |
| `gre` | Generic Routing Encapsulation | VPN, 隧道 |
| `igmp` | Internet Group Management Protocol | 多播 |
| `ipv6-encap` | IPv6 Encapsulation | IPv6 隧道 |
| `ipv6-frag` | IPv6 Fragment | IPv6 分片 |
| `ipv6-icmp` | ICMPv6 | IPv6 網路診斷 |
| `ipv6-nonxt` | IPv6 No Next Header | IPv6 |
| `ipv6-opts` | IPv6 Options | IPv6 |
| `ipv6-route` | IPv6 Routing | IPv6 路由 |
| `ospf` | Open Shortest Path First | 路由協議 |
| `pgm` | Pragmatic General Multicast | 多播 |
| `rsvp` | Resource Reservation Protocol | QoS |
| `sctp` | Stream Control Transmission Protocol | 特殊應用 |
| `tcp` | Transmission Control Protocol | 標準 TCP |
| `udp` | User Datagram Protocol | 標準 UDP |
| `udplite` | UDP-Lite | 輕量級 UDP |
| `vrrp` | Virtual Router Redundancy Protocol | 高可用 |

### 2. `--direction` (流量方向)
**可選欄位**，預設為 `ingress`

| 值 | 說明 | 使用場景 |
|---|------|----------|
| `ingress` | 入站流量 | 允許外部訪問本 VM 的服務 |
| `egress` | 出站流量 | 允許本 VM 訪問外部服務 |

### 3. `--ethertype` (網路層協議)
**可選欄位**，預設為 `IPv4`

| 值 | 說明 |
|---|------|
| `IPv4` | IPv4 網路 |
| `IPv6` | IPv6 網路 |

### 4. 端口範圍欄位

#### `--port-range-min` 和 `--port-range-max`
**TCP/UDP 協議時使用**

| 使用方式 | 說明 | 範例 |
|---------|------|------|
| `--port-range-min 80 --port-range-max 80` | 單一端口 | HTTP 服務 |
| `--port-range-min 8000 --port-range-max 8999` | 端口範圍 | 應用服務範圍 |
| `--port-range-min 1 --port-range-max 65535` | 全部端口 | 允許所有端口 |

#### `--dst-port` (簡化寫法)
**等同於設置相同的 min 和 max**
```bash
--dst-port 30090  # 等同於 --port-range-min 30090 --port-range-max 30090
```

### 5. 來源限制欄位 (二選一)

#### `--remote-ip` (IP 地址範圍)
指定允許的來源 IP 範圍

| 格式 | 說明 | 使用場景 |
|------|------|----------|
| `0.0.0.0/0` | 所有 IPv4 地址 | 公開服務 |
| `::/0` | 所有 IPv6 地址 | IPv6 公開服務 |
| `172.16.0.0/16` | 內網範圍 | 內部服務 |
| `172.16.0.78/32` | 單一 IP | 特定主機 |
| `10.0.0.0/8` | 私有網路 A 類 | 企業內網 |
| `192.168.0.0/16` | 私有網路 C 類 | 小型網路 |

#### `--remote-group` (安全群組)
指定允許的來源安全群組

| 使用方式 | 說明 |
|---------|------|
| `--remote-group default` | 預設安全群組 |
| `--remote-group web-servers` | 特定安全群組 |
| `--remote-group self` | 同一個安全群組內互相通信 |

### 6. `--description` (規則描述)
**強烈建議填寫**，方便管理
```bash
--description "Allow HTTP traffic from internal network"
--description "Allow ICMP ping from VM-1"
--description "Kubernetes API access"
```

---

## 🎯 針對 VM-4 Edge2 的具體配置範例

### 1. 允許內網 ICMP (解決 ping 問題)
```bash
openstack security group rule create \
  --protocol icmp \
  --direction ingress \
  --ethertype IPv4 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow ICMP ping from internal network" \
  <security-group-name>
```

**欄位解析**:
- `--protocol icmp`: ICMP 協議 (ping)
- `--direction ingress`: 允許進入的流量
- `--ethertype IPv4`: IPv4 網路
- `--remote-ip 172.16.0.0/16`: 來源為內網範圍
- `--description`: 規則說明

### 2. 允許 SLO 服務端口 (30090)
```bash
openstack security group rule create \
  --protocol tcp \
  --direction ingress \
  --ethertype IPv4 \
  --dst-port 30090 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow SLO metrics endpoint from internal network" \
  <security-group-name>
```

**欄位解析**:
- `--protocol tcp`: TCP 協議
- `--dst-port 30090`: 目標端口 30090
- `--remote-ip 172.16.0.0/16`: 限制來源為內網

### 3. 允許 O2IMS 服務端口 (31280)
```bash
openstack security group rule create \
  --protocol tcp \
  --direction ingress \
  --ethertype IPv4 \
  --dst-port 31280 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow O2IMS API endpoint from internal network" \
  <security-group-name>
```

### 4. 允許 Kubernetes API (6443)
```bash
openstack security group rule create \
  --protocol tcp \
  --direction ingress \
  --ethertype IPv4 \
  --dst-port 6443 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow Kubernetes API server access from internal network" \
  <security-group-name>
```

### 5. 允許 SSH 管理 (22)
```bash
openstack security group rule create \
  --protocol tcp \
  --direction ingress \
  --ethertype IPv4 \
  --dst-port 22 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow SSH access from internal network" \
  <security-group-name>
```

### 6. 允許安全群組內互相通信 (推薦)
```bash
openstack security group rule create \
  --protocol tcp \
  --direction ingress \
  --ethertype IPv4 \
  --port-range-min 1 \
  --port-range-max 65535 \
  --remote-group <same-security-group-name> \
  --description "Allow all TCP traffic within security group" \
  <security-group-name>

openstack security group rule create \
  --protocol udp \
  --direction ingress \
  --ethertype IPv4 \
  --port-range-min 1 \
  --port-range-max 65535 \
  --remote-group <same-security-group-name> \
  --description "Allow all UDP traffic within security group" \
  <security-group-name>

openstack security group rule create \
  --protocol icmp \
  --direction ingress \
  --ethertype IPv4 \
  --remote-group <same-security-group-name> \
  --description "Allow ICMP within security group" \
  <security-group-name>
```

---

## 🛠️ 實際執行步驟

### 步驟 1: 查找安全群組名稱
```bash
# 列出所有安全群組
openstack security group list

# 查看 VM-4 當前使用的安全群組
openstack server show "VM-4（edge2）" -f value -c security_groups

# 假設安全群組名稱為 "default"
SECURITY_GROUP="default"
```

### 步驟 2: 執行規則創建 (複製貼上即可)
```bash
# 設置變數
SECURITY_GROUP="default"  # 替換為實際的安全群組名稱
INTERNAL_NETWORK="172.16.0.0/16"

# 創建 ICMP 規則 (解決 ping 問題)
openstack security group rule create \
  --protocol icmp \
  --direction ingress \
  --remote-ip $INTERNAL_NETWORK \
  --description "Allow ICMP ping from internal network" \
  $SECURITY_GROUP

# 創建 SLO 端口規則
openstack security group rule create \
  --protocol tcp \
  --dst-port 30090 \
  --remote-ip $INTERNAL_NETWORK \
  --description "Allow SLO metrics endpoint" \
  $SECURITY_GROUP

# 創建 O2IMS 端口規則
openstack security group rule create \
  --protocol tcp \
  --dst-port 31280 \
  --remote-ip $INTERNAL_NETWORK \
  --description "Allow O2IMS API endpoint" \
  $SECURITY_GROUP

# 創建 Kubernetes API 規則
openstack security group rule create \
  --protocol tcp \
  --dst-port 6443 \
  --remote-ip $INTERNAL_NETWORK \
  --description "Allow Kubernetes API access" \
  $SECURITY_GROUP

echo "安全群組規則創建完成！"
```

### 步驟 3: 驗證規則創建
```bash
# 查看安全群組的所有規則
openstack security group show $SECURITY_GROUP

# 只查看新創建的規則
openstack security group rule list $SECURITY_GROUP | grep -E "(icmp|30090|31280|6443)"
```

---

## 🧪 測試驗證

### 規則創建後立即測試
```bash
# 從 VM-1 (172.16.0.78) 測試到 VM-4 (172.16.0.89)
ping -c 3 172.16.0.89                              # 應該成功
curl -s http://172.16.0.89:30090/health            # 應該返回 "OK"
curl -s http://172.16.0.89:30090/metrics/api/v1/slo | jq .  # 應該返回 JSON 數據
```

---

## 📋 常見錯誤和解決方案

### 錯誤 1: "Security group not found"
```bash
# 檢查安全群組名稱是否正確
openstack security group list | grep -i default

# 使用正確的安全群組 ID 而不是名稱
openstack security group rule create --protocol icmp <security-group-id>
```

### 錯誤 2: "Rule already exists"
```bash
# 查看現有規則避免重複
openstack security group rule list <security-group-name>

# 刪除重複規則後重新創建
openstack security group rule delete <rule-id>
```

### 錯誤 3: "Invalid CIDR"
```bash
# 確保 IP 範圍格式正確
--remote-ip 172.16.0.0/16  # 正確
--remote-ip 172.16.0.0/32  # 單一主機
--remote-ip 172.16.0.89    # 錯誤：缺少 CIDR
```

---

## 🎯 總結

**核心規則配置 (最小必要集)**:
1. **ICMP**: `--protocol icmp --remote-ip 172.16.0.0/16`
2. **SLO 端口**: `--protocol tcp --dst-port 30090 --remote-ip 172.16.0.0/16`
3. **O2IMS 端口**: `--protocol tcp --dst-port 31280 --remote-ip 172.16.0.0/16`
4. **K8s API**: `--protocol tcp --dst-port 6443 --remote-ip 172.16.0.0/16`

完成這些規則配置後，VM-1 就能完全正常地與 VM-4 Edge2 通信了！