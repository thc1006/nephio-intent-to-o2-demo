# SSL/TLS 快速開始指南

🚀 **一鍵部署 SSL/TLS 基礎設施**

## 前置檢查

運行環境驗證：
```bash
./scripts/simple-ssl-validation.sh
```

確保看到：`[SUCCESS] Environment is ready for SSL/TLS deployment!`

## 快速部署

### 1. 完整部署（推薦）

```bash
# 一鍵部署所有 SSL/TLS 組件
./scripts/deploy-ssl-infrastructure.sh
```

這將自動：
- 生成 CA 和所有服務證書
- 配置 Gitea HTTPS (端口 8443)
- 部署 cert-manager 到 K8s 集群
- 創建管理腳本
- 生成部署報告

### 2. 驗證部署

```bash
# 檢查證書狀態
./scripts/ssl-manager.sh status

# 測試 Gitea HTTPS
./scripts/ssl-manager.sh test-gitea

# 測試 K8s TLS
./scripts/ssl-manager.sh test-k8s
```

## 服務端點

部署完成後，以下端點可用：

| 服務 | HTTP | HTTPS |
|------|------|-------|
| **Gitea** | http://172.16.0.78:8888 | https://172.16.0.78:8443 |
| **Edge1 K8s** | - | https://172.16.4.45:6443 |
| **Edge2 K8s** | - | https://172.16.4.176:6443 |

## 常用命令

```bash
# 統一管理工具
./scripts/ssl-manager.sh help

# 證書狀態檢查
./scripts/ssl-manager.sh status

# 證書更新
./scripts/ssl-manager.sh renew

# 測試連接
./scripts/ssl-manager.sh test-gitea
./scripts/ssl-manager.sh test-k8s

# 如需回滾到 HTTP
./scripts/ssl-manager.sh rollback-gitea
```

## 客戶端使用

### Git 操作
```bash
# 使用 CA 證書
git -c http.sslCAInfo=certs/nephio-ca.crt clone https://172.16.0.78:8443/admin1/edge1-config.git

# 或跳過 SSL 驗證（僅用於測試）
git -c http.sslVerify=false clone https://172.16.0.78:8443/admin1/edge1-config.git
```

### Kubectl 操作
```bash
# 使用預配置的 kubeconfig
export KUBECONFIG=configs/ssl/kubeconfig-edge1-tls.yaml
kubectl get nodes

# 或直接指定 CA 證書
kubectl --server=https://172.16.4.45:6443 \
        --certificate-authority=certs/nephio-ca.crt \
        get nodes
```

### Curl 測試
```bash
# 使用 CA 證書
curl --cacert certs/nephio-ca.crt https://172.16.0.78:8443

# 跳過 SSL 驗證（僅用於測試）
curl -k https://172.16.0.78:8443
```

## 故障排除

### 如果部署失敗

1. **檢查前置條件**：
   ```bash
   ./scripts/simple-ssl-validation.sh
   ```

2. **檢查服務狀態**：
   ```bash
   docker ps | grep gitea
   nc -z -w 3 172.16.4.45 6443
   nc -z -w 3 172.16.4.176 6443
   ```

3. **查看詳細日誌**：
   ```bash
   ls reports/ssl-deployment-report-*.md
   docker logs gitea-https
   ```

### 常見問題

1. **證書不被信任**：
   - 使用 `--cacert certs/nephio-ca.crt` 參數
   - 或將 CA 證書添加到系統信任庫

2. **Gitea HTTPS 無響應**：
   ```bash
   # 重新部署 Gitea HTTPS
   ./scripts/setup/deploy-gitea-https.sh
   ```

3. **K8s 集群無法訪問**：
   - 檢查網路連接和防火牆規則
   - 確保 OpenStack Security Groups 正確配置

## 下一步

1. **更新 GitOps 配置**使用 HTTPS：
   ```bash
   # 應用 HTTPS RootSync 配置
   kubectl apply -f configs/ssl/edge1-rootsync-https.yaml
   kubectl apply -f configs/ssl/edge2-rootsync-https.yaml
   ```

2. **設置監控**：
   ```bash
   # 添加到 crontab 進行自動監控
   echo "0 8 * * * $(pwd)/scripts/check-certificate-status.sh" | crontab -
   ```

3. **配置自動更新**：
   ```bash
   # 每月自動更新證書
   echo "0 0 1 * * $(pwd)/scripts/renew-certificates.sh" | crontab -
   ```

## 完整文檔

- **詳細實施指南**: `docs/SSL_TLS_INFRASTRUCTURE.md`
- **實施摘要**: `SSL_TLS_IMPLEMENTATION_SUMMARY.md`
- **網路配置**: `AUTHORITATIVE_NETWORK_CONFIG.md`

---

**需要幫助？** 運行 `./scripts/ssl-manager.sh help` 查看所有可用命令。
