# 🔐 權威網路配置文檔 - 正確的連線方式
**最後更新**: 2025-09-14
**版本**: v2.0.0 FINAL
**狀態**: ✅ 經過完整測試驗證

## ⚠️ 重要聲明
**這是唯一正確的網路配置文檔。所有其他文檔如有衝突，以此文檔為準。**

---

## 📊 網路拓撲總覽

```
                     ┌──────────────────────────┐
                     │   VM-1 (SMO/GitOps)      │
                     │   內部: 172.16.0.78      │
                     │   外部: 147.251.115.143  │
                     │   角色: 管理與編排       │
                     └──────────┬───────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
         ┌──────────▼──────────┐  ┌────────▼──────────┐
         │   VM-2 (Edge1)      │  │   VM-4 (Edge2)    │
         │   IP: 172.16.4.45   │  │   IP: 172.16.0.89 │
         │   角色: 邊緣站點1    │  │   角色: 邊緣站點2  │
         └─────────────────────┘  └───────────────────┘
```

---

## ✅ VM-1 到 Edge 站點連線狀態（2025-09-14 驗證）

### 🎯 VM-1 → Edge1 (VM-2) 連線
| 服務 | 端口 | 協議 | 狀態 | 用途 |
|------|------|------|------|------|
| ICMP | - | ICMP | ✅ 成功 | 基本連通性測試 |
| SSH | 22 | TCP | ✅ 成功 | 管理訪問 |
| Kubernetes API | 6443 | TCP | ✅ 成功 | K8s 叢集管理 |
| SLO Service | 30090 | TCP | ✅ 成功 | SLO 監控服務 |
| O2IMS API | 31280 | TCP | ✅ 成功 | O-RAN O2 介面 |

### 🎯 VM-1 → Edge2 (VM-4) 連線
| 服務 | 端口 | 協議 | 狀態 | 用途 |
|------|------|------|------|------|
| ICMP | - | ICMP | ✅ 成功（需 OpenStack 設置） | 基本連通性測試 |
| SSH | 22 | TCP | ❌ 超時（需額外設置） | 管理訪問 |
| Kubernetes API | 6443 | TCP | ✅ 成功 | K8s 叢集管理 |
| SLO Service | 30090 | TCP | ✅ 成功 | SLO 監控服務 |
| O2IMS API | 31280 | TCP | ✅ 成功（如已部署） | O-RAN O2 介面 |

---

## 🔧 OpenStack Security Group 正確設置

### 必須的規則（已驗證成功）

#### 1. ICMP 規則（允許 ping）
```
Direction: Ingress
Protocol: ICMP
Remote: CIDR
CIDR: 172.16.0.78/32
```

#### 2. Kubernetes API 規則
```
Direction: Ingress
Protocol: TCP
Port: 6443
Remote: CIDR
CIDR: 172.16.0.0/16
```

#### 3. NodePort 服務範圍
```
Direction: Ingress
Protocol: TCP
Port Range: 30000-32767
Remote: CIDR
CIDR: 172.16.0.0/16
```

#### 4. SSH 規則（可選）
```
Direction: Ingress
Protocol: TCP
Port: 22
Remote: CIDR
CIDR: 172.16.0.78/32
```

---

## 🚀 GitOps 同步配置

### Gitea 服務狀態
```bash
# VM-1 上的 Gitea 服務
服務地址: http://172.16.0.78:8888
外部地址: http://147.251.115.143:8888
狀態: ✅ 運行中
容器: gitea/gitea:latest
端口映射: 8888:3000, 2222:22
```

### Edge1 GitOps 配置
```yaml
# 位置: vm-2/edge1-rootsync.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/admin1/edge1-config  # 正確：使用內部 IP
    branch: main
    auth: token
    secretRef:
      name: gitea-token
```

### Edge2 GitOps 配置
```yaml
# 位置: 待創建
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge2-rootsync
  namespace: config-management-system
spec:
  git:
    repo: http://172.16.0.78:8888/admin1/edge2-config  # 使用 VM-1 內部 IP
    branch: main
    directory: /edge2  # Edge2 監聽子目錄
    auth: token
    secretRef:
      name: git-creds
```

---

## ⚠️ 常見錯誤配置（請避免）

### ❌ 錯誤 1：使用外部 IP 進行內部通訊
```yaml
# 錯誤
repo: http://147.251.115.143:8888/admin1/edge1-config

# 正確
repo: http://172.16.0.78:8888/admin1/edge1-config
```

### ❌ 錯誤 2：使用 SSH 隧道連接同網段機器
```bash
# 錯誤：VM-4 在同網段不需要 SSH 隧道
ssh -L 6443:localhost:6443 ubuntu@172.16.0.89

# 正確：直接連接
kubectl --server=https://172.16.0.89:6443
```

### ❌ 錯誤 3：使用過時的端口
```bash
# 錯誤：使用 30000 而非 8888
http://172.16.0.78:30000/admin1/edge1-config

# 正確：Gitea 運行在 8888
http://172.16.0.78:8888/admin1/edge1-config
```

---

## 📝 快速驗證命令

### 從 VM-1 驗證所有連線
```bash
# 測試 Edge1
echo "=== Testing Edge1 (VM-2) ==="
ping -c 2 172.16.4.45
nc -vz -w 3 172.16.4.45 6443
curl -s http://172.16.4.45:30090/health

# 測試 Edge2
echo "=== Testing Edge2 (VM-4) ==="
ping -c 2 172.16.0.89
nc -vz -w 3 172.16.0.89 6443
curl -s http://172.16.0.89:30090/health

# 測試 Gitea
echo "=== Testing Gitea ==="
curl -s http://localhost:8888 | grep -q "Gitea" && echo "Gitea: OK"
```

### 驗證 GitOps 同步
```bash
# 在 Edge1 (VM-2) 上
kubectl -n config-management-system get rootsync
kubectl -n config-management-system logs -l app=root-reconciler --tail=10

# 在 Edge2 (VM-4) 上
kubectl -n config-management-system get rootsync
kubectl -n config-management-system logs -l app=root-reconciler --tail=10
```

---

## 🔄 同步能力總結

### ✅ VM-1 可以成功同步到兩個 Edge 站點

1. **Edge1 (VM-2)**:
   - GitOps 同步: ✅ 運作中
   - 監控數據收集: ✅ 正常
   - 管理訪問: ✅ 完整

2. **Edge2 (VM-4)**:
   - GitOps 同步: ⚠️ 需要 Edge2 能訪問 VM-1:8888
   - 監控數據收集: ✅ 正常（VM-1 可以主動拉取）
   - 管理訪問: ⚠️ 部分（K8s API 可用，SSH 不可用）

---

## 📋 待解決問題

1. **Edge2 → VM-1 Gitea 連線**
   - 問題：Edge2 無法訪問 147.251.115.143:8888
   - 解決方案：配置網路路由或使用內部 IP

2. **VM-1 → Edge2 SSH**
   - 問題：SSH 端口 22 超時
   - 解決方案：檢查 VM-4 SSH 服務狀態

---

## 🚨 緊急修復程序

如果連線失敗，請按順序執行：

1. **檢查 Gitea 服務**
   ```bash
   docker ps | grep gitea
   # 如未運行，執行：
   ./start-gitea.sh
   ```

2. **檢查 OpenStack Security Groups**
   - 確認 ICMP 規則已添加
   - 確認 TCP 6443, 30000-32767 規則存在

3. **驗證網路路由**
   ```bash
   ip route | grep 172.16
   ```

4. **重啟 Config Sync**
   ```bash
   kubectl -n config-management-system rollout restart deployment reconciler-manager
   ```

---

## 📞 支援資訊

- **文檔維護者**: Nephio Intent-to-O2 Team
- **最後驗證**: 2025-09-14
- **下次審查**: 2025-10-14

---

**⚠️ 重要提醒：此文檔是網路配置的唯一真實來源。請定期參考此文檔，避免使用過時資訊。**