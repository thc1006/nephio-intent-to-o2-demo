# VM-2 Edge1 Integration Information

## VM-2 提供給 VM-1 的資訊

### 1. Edge1 Cluster 端點
- **Cluster Name**: edge1
- **Kubernetes API Server**: https://172.16.4.45:6443
- **VM-2 IP Address**: 172.16.4.45
- **Network Interface**: ens3 (172.16.0.0/16)

### 2. Config Sync 狀態
- **Namespace**: config-management-system
- **Deployment**: root-reconciler
- **Current Git URL**: http://147.251.115.143:8888/admin1/edge1-config.git (無法連線)
- **Sync Interval**: 30 seconds

### 3. 現有資源狀態
- **Namespaces**: edge1, edge-observability, o2ims-system
- **Running Services**: 
  - Test applications in edge1 namespace
  - O2IMS controller
  - Kube-state-metrics

## VM-1 需要提供的資訊

### 1. Gitea Repository 存取
```yaml
gitea:
  url: "http://<ACTUAL_VM1_IP>:8888"  # 需要實際可訪問的 URL
  repository: "admin1/edge1-config.git"
  branch: "main"
  credentials:
    username: "admin"
    token: "<ACTUAL_TOKEN>"  # 需要實際的 access token
```

### 2. 網路配置確認
- 確認 VM-1 Gitea 服務是否在以下任一地址運行：
  - 172.16.0.78:8888 (內網)
  - 147.251.115.143:8888 (外網)
- 防火牆是否允許從 172.16.4.45 訪問

### 3. 更新 Git-Sync 配置命令
一旦獲得正確資訊，執行以下命令更新配置：

```bash
# 更新 secret
kubectl delete secret gitea-token -n config-management-system
kubectl create secret generic gitea-token \
  -n config-management-system \
  --from-literal=username=admin \
  --from-literal=token=<ACTUAL_TOKEN>

# 更新 deployment
kubectl set env deployment/root-reconciler \
  -n config-management-system \
  GITSYNC_REPO=http://<ACTUAL_VM1_IP>:8888/admin1/edge1-config.git

# 重啟 pod
kubectl rollout restart deployment/root-reconciler -n config-management-system
```

## 測試連通性
```bash
# 從 VM-2 測試 VM-1 Gitea
curl -v http://<VM1_IP>:8888
git ls-remote http://<VM1_IP>:8888/admin1/edge1-config.git

# 檢查 sync 狀態
kubectl logs -n config-management-system -l app=root-reconciler -c git-sync
```

## 聯絡資訊
- VM-2 Status: Ready for GitOps integration
- Cluster Health: Operational
- Waiting for: VM-1 Gitea connection details