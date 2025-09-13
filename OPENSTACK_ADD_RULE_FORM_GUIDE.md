# OpenStack Add Rule 欄位填寫指南

**目標**: 為 VM-4 Edge2 添加安全群組規則
**需求**: 解決 ping 失敗問題，確保 VM-1 能正常訪問

---

## 📋 Web UI 表單欄位對應

### 規則 1: 允許 ICMP (解決 ping 問題)
```
Rule:            ICMP
Direction:       Ingress
Ether Type:      IPv4
IP Protocol:     ICMP
Port Range:      (留空)
Remote:          CIDR
CIDR:           172.16.0.0/16
Description:     Allow ICMP ping from internal network
```

### 規則 2: 允許 SLO 端口 (30090)
```
Rule:            Custom TCP Rule
Direction:       Ingress
Ether Type:      IPv4
IP Protocol:     TCP
Port Range:      30090
Remote:          CIDR
CIDR:           172.16.0.0/16
Description:     Allow SLO metrics endpoint
```

### 規則 3: 允許 O2IMS 端口 (31280)
```
Rule:            Custom TCP Rule
Direction:       Ingress
Ether Type:      IPv4
IP Protocol:     TCP
Port Range:      31280
Remote:          CIDR
CIDR:           172.16.0.0/16
Description:     Allow O2IMS API endpoint
```

### 規則 4: 允許 Kubernetes API (6443)
```
Rule:            Custom TCP Rule
Direction:       Ingress
Ether Type:      IPv4
IP Protocol:     TCP
Port Range:      6443
Remote:          CIDR
CIDR:           172.16.0.0/16
Description:     Allow Kubernetes API server
```

---

## 🎯 CLI 命令對應 (完整格式)

### 查找你的安全群組
```bash
# 1. 先查找 VM-4 使用的安全群組
openstack server show "VM-4（edge2）" -f value -c security_groups
# 或者
openstack security group list
```

### 添加規則命令
```bash
# 假設安全群組名稱為 "default"，請替換為實際名稱
SECURITY_GROUP="default"

# 規則 1: ICMP
openstack security group rule create \
  --protocol icmp \
  --ingress \
  --ethertype IPv4 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow ICMP ping from internal network" \
  $SECURITY_GROUP

# 規則 2: SLO 端口
openstack security group rule create \
  --protocol tcp \
  --ingress \
  --ethertype IPv4 \
  --dst-port 30090 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow SLO metrics endpoint" \
  $SECURITY_GROUP

# 規則 3: O2IMS 端口
openstack security group rule create \
  --protocol tcp \
  --ingress \
  --ethertype IPv4 \
  --dst-port 31280 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow O2IMS API endpoint" \
  $SECURITY_GROUP

# 規則 4: Kubernetes API
openstack security group rule create \
  --protocol tcp \
  --ingress \
  --ethertype IPv4 \
  --dst-port 6443 \
  --remote-ip 172.16.0.0/16 \
  --description "Allow Kubernetes API server" \
  $SECURITY_GROUP
```

---

## 📱 Horizon Web UI 操作步驟

### 步驟 1: 進入安全群組管理
1. 登入 OpenStack Horizon Dashboard
2. 點選左側選單 **"Network"** → **"Security Groups"**
3. 找到 VM-4 使用的安全群組 (通常是 "default")
4. 點選該安全群組的 **"Manage Rules"** 按鈕

### 步驟 2: 添加 ICMP 規則
1. 點選 **"Add Rule"** 按鈕
2. 在表單中填寫：
   ```
   Rule: ICMP
   Direction: Ingress
   Ether Type: IPv4
   IP Protocol: ICMP
   Port Range: (保持空白)
   Remote: CIDR
   CIDR: 172.16.0.0/16
   Description: Allow ICMP ping from internal network
   ```
3. 點選 **"Add"** 按鈕

### 步驟 3: 添加 TCP 端口規則 (重複 3 次)
對於每個端口 (30090, 31280, 6443)，重複以下步驟：

1. 點選 **"Add Rule"** 按鈕
2. 填寫表單：
   ```
   Rule: Custom TCP Rule
   Direction: Ingress
   Ether Type: IPv4
   IP Protocol: TCP
   Port Range: <端口號> (如 30090)
   Remote: CIDR
   CIDR: 172.16.0.0/16
   Description: <相對應的描述>
   ```
3. 點選 **"Add"** 按鈕

---

## 🔍 欄位說明詳解

### Rule (規則類型)
| 選項 | 用途 | 何時選擇 |
|------|------|----------|
| `ICMP` | ping 命令 | 需要 ping 連通性 |
| `SSH` | SSH 連線 (22 端口) | 需要 SSH 管理 |
| `HTTP` | HTTP 服務 (80 端口) | 網頁服務 |
| `HTTPS` | HTTPS 服務 (443 端口) | 安全網頁服務 |
| `Custom TCP Rule` | 自定義 TCP 端口 | **我們的情況** (30090, 31280, 6443) |
| `Custom UDP Rule` | 自定義 UDP 端口 | DNS 等 UDP 服務 |

### Direction (流量方向)
| 選項 | 說明 | 我們的選擇 |
|------|------|----------|
| `Ingress` | 允許進入 VM 的流量 | **選這個** (VM-1 → VM-4) |
| `Egress` | 允許 VM 對外的流量 | 不需要 |

### Ether Type (網路層協議)
| 選項 | 說明 | 我們的選擇 |
|------|------|----------|
| `IPv4` | IPv4 網路 | **選這個** |
| `IPv6` | IPv6 網路 | 不需要 |

### IP Protocol (傳輸層協議)
| 選項 | 說明 | 使用場景 |
|------|------|----------|
| `ICMP` | 網路控制訊息協議 | ping 命令 |
| `TCP` | 傳輸控制協議 | **HTTP 服務** |
| `UDP` | 用戶資料協議 | DNS, DHCP |

### Port Range (端口範圍)
| 格式 | 說明 | 範例 |
|------|------|------|
| `80` | 單一端口 | HTTP |
| `8000-8999` | 端口範圍 | 應用服務範圍 |
| (空白) | 所有端口 | ICMP 規則 |

### Remote (來源限制)
| 選項 | 說明 | 使用場景 |
|------|------|----------|
| `CIDR` | IP 地址範圍 | **我們選這個** |
| `Security Group` | 另一個安全群組 | 群組間通信 |

### CIDR (IP 地址範圍)
| 格式 | 說明 | 安全性 |
|------|------|-------|
| `172.16.0.0/16` | 內網範圍 | **推薦** (安全) |
| `172.16.0.78/32` | 只允許 VM-1 | 最安全 |
| `0.0.0.0/0` | 允許所有 IP | 不安全 |

---

## 📋 快速檢查清單

完成規則添加後，請檢查：

### 在 OpenStack 管理介面
- [ ] 安全群組顯示 4 條新規則
- [ ] ICMP 規則：protocol=icmp, source=172.16.0.0/16
- [ ] TCP 規則：port 30090, source=172.16.0.0/16
- [ ] TCP 規則：port 31280, source=172.16.0.0/16
- [ ] TCP 規則：port 6443, source=172.16.0.0/16

### 功能測試
- [ ] 從 VM-1 能 ping 通 VM-4：`ping 172.16.0.89`
- [ ] SLO 端點可訪問：`curl http://172.16.0.89:30090/health`
- [ ] 返回 "OK" 響應

---

## 🚨 常見問題

### Q: 找不到 VM-4 使用的安全群組？
**A**: 執行命令查看
```bash
openstack server show "VM-4（edge2）" -f value -c security_groups
```

### Q: 規則添加後仍然無法 ping？
**A**: 檢查順序
1. 確認安全群組規則已生效 (重新整理頁面)
2. 在 VM-4 上執行：`./scripts/fix_openstack_connectivity.sh`
3. 等待 30 秒讓規則生效

### Q: CIDR 應該填什麼？
**A**: 根據需求選擇
- `172.16.0.0/16` - 允許整個內網 (推薦)
- `172.16.0.78/32` - 只允許 VM-1
- `0.0.0.0/0` - 允許所有 IP (不建議)

---

## 🎯 完成後驗證

```bash
# 在 VM-1 上執行這些命令驗證
ping -c 3 172.16.0.89                              # 應該成功
curl http://172.16.0.89:30090/health               # 應該返回 "OK"
curl http://172.16.0.89:30090/metrics/api/v1/slo | jq .site  # 應該返回 "edge2"

# 執行多站點測試
cd /path/to/nephio-intent-to-o2-demo
./scripts/postcheck.sh                             # 應該包含 edge1 和 edge2 數據
```

**🎉 完成這些規則添加後，你的多站點 Nephio 環境就完全就緒了！**