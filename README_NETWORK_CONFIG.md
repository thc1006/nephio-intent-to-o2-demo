# 📚 網路配置文檔指南

## ⚠️ 重要提醒
**請只參考以下權威文檔，其他文檔可能包含過時資訊**

---

## ✅ 權威文檔（請使用這些）

### 1. 🔐 主要配置文檔
- **`AUTHORITATIVE_NETWORK_CONFIG.md`** - 唯一正確的網路配置來源
  - 包含所有正確的 IP 地址、端口、連線方式
  - 最後更新：2025-09-14
  - 定期驗證和更新

### 2. 🧪 測試工具
- **`test-connectivity.sh`** - 權威連線測試腳本
  - 基於 AUTHORITATIVE_NETWORK_CONFIG.md
  - 測試所有關鍵連線點

### 3. 🚀 設置腳本
- **`setup-gitops-repos.sh`** - GitOps repository 初始化
- **`start-gitea.sh`** - Gitea 服務啟動腳本

### 4. 📊 OpenStack 配置
- **`docs/openstack-icmp-fix.md`** - ICMP 配置指南
- **`docs/openstack-gui-icmp-setup.md`** - GUI 設置步驟

---

## ❌ 已歸檔/過時文檔（請勿使用）

以下文檔已移至 `archived/outdated-docs/`：
- ~~NETWORK_BEHAVIOR_ANALYSIS.md~~ - 包含錯誤的端口資訊
- ~~VM1_NETWORK_BEHAVIOR_UPDATE.md~~ - 過時的網路行為分析
- ~~BIDIRECTIONAL_CONNECTIVITY_ANALYSIS.md~~ - 錯誤的連線假設
- ~~test-ssh-tunnels.sh~~ - 使用錯誤的外部 IP
- ~~fix_openstack_connectivity.sh~~ - 過時的修復方法

---

## 🔄 快速參考

### 正確的連線資訊
```yaml
VM-1 (SMO):
  內部 IP: 172.16.0.78
  外部 IP: 147.251.115.143
  Gitea: port 8888 (不是 30000!)

Edge1 (VM-2):
  IP: 172.16.4.45
  連線: 直接，不需要 SSH 隧道

Edge2 (VM-4):
  IP: 172.16.0.89
  連線: 直接，同網段，不需要 SSH 隧道
```

### 測試連線
```bash
# 使用權威測試腳本
./test-connectivity.sh
```

### 檢查 GitOps
```bash
# 檢查 Gitea
docker ps | grep gitea
curl http://localhost:8888

# 檢查 repositories
curl http://172.16.0.78:8888/admin1/edge1-config
curl http://172.16.0.78:8888/admin1/edge2-config
```

---

## 📝 維護說明

1. **只更新 AUTHORITATIVE_NETWORK_CONFIG.md**
2. **測試腳本基於權威文檔**
3. **定期驗證連線（每週）**
4. **發現錯誤立即更新**

---

**最後審查：2025-09-14**
**下次審查：2025-09-21**