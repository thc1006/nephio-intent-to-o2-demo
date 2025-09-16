# CI/CD Pipeline Documentation

本項目實施了完整的 CI/CD pipeline，包含配置驗證、自動化測試、GitOps 整合和回滾機制。

## 概述

CI/CD pipeline 由以下組件組成：

- **GitHub Actions Workflows**: 主要的 CI/CD 編排
- **配置驗證腳本**: YAML、Kubernetes manifest 和策略驗證
- **測試框架**: Unit tests、Integration tests 和 Smoke tests
- **GitOps 整合**: 自動部署到 Gitea 倉庫
- **回滾機制**: 智能回滾與安全檢查

## 工作流程結構

### 主要工作流程 (ci.yml)

```yaml
觸發條件:
  - Push to main/develop branches
  - Pull requests to main
  - 修改 gitops/、k8s/、packages/、tools/、scripts/ 目錄

階段:
1. Configuration Validation (配置驗證)
2. Unit Tests (單元測試)
3. Integration Tests (整合測試)
4. Smoke Tests (煙霧測試)
5. GitOps Deploy (GitOps 部署)
6. Post-deployment Validation (部署後驗證)
7. Rollback (失敗時回滾)
```

### 夜間工作流程 (nightly.yml)

```yaml
觸發條件:
  - 定時執行 (每天 UTC 2:00 AM)
  - 手動觸發

功能:
- 系統健康檢查
- 安全掃描
- 依賴更新檢查
- 舊文件清理
- 失敗通知
```

## 驗證腳本

### 1. YAML 語法驗證 (`validate-yaml.sh`)

- 使用 `yamllint` 驗證所有 YAML 文件
- 檢查語法錯誤和格式問題
- 生成詳細的驗證報告

### 2. Kubernetes Manifest 驗證 (`validate-k8s-manifests.sh`)

- 使用 `kubeconform` 驗證 K8s 資源
- 檢查必需標籤和資源限制
- 驗證安全上下文配置

### 3. KPT Package 驗證 (`validate-kpt-packages.sh`)

- 驗證 KPT 包結構
- 測試 `kpt fn render` 功能
- 檢查包依賴關係

### 4. 策略驗證 (`validate-policies.sh`)

- 使用 OPA 策略驗證
- 基本 Kyverno 策略檢查
- 內建安全策略檢查

## 測試框架

### Unit Tests (`run-unit-tests.sh`)

- Python 單元測試 (pytest)
- Shell 腳本測試
- KPT 函數測試
- 代碼覆蓋率報告

### Integration Tests (`run-integration-tests.sh`)

- Kind 集群中的測試
- Config Sync 操作驗證
- KPT 包渲染測試
- Intent 編譯器整合測試

### Smoke Tests (`run-smoke-tests.sh`)

- 基本腳本功能測試
- 配置結構驗證
- Python 組件檢查
- 快速功能測試

## GitOps 整合

### 部署腳本 (`deploy-to-gitops.sh`)

```bash
功能:
- 自動同步到 Gitea 倉庫
- 支援多站點部署 (edge1-config, edge2-config)
- Git 認證與權限驗證
- 部署狀態追蹤

環境變數:
- GITEA_TOKEN: Gitea 訪問令牌
- GITEA_URL: Gitea 伺服器 URL
```

### 部署驗證 (`verify-gitops-deployment.sh`)

```bash
功能:
- 驗證 GitOps 倉庫狀態
- 檢查 Config Sync 同步狀態
- YAML 和 K8s manifest 驗證
- 最近更新檢查
```

## 回滾機制

### 增強回滾 (`enhanced-rollback.sh`)

```bash
功能:
- 智能策略選擇
- 本地倉庫回滾
- GitOps 倉庫回滾
- 回滾後驗證
- 安全檢查與快照

回滾策略:
- test_failure: 回滾到最後已知良好提交
- deployment_failure: GitOps 倉庫 + 本地更改回滾
- validation_failure: 放棄當前更改 + 重置到 main
- automatic_failure: 全面回滾 (本地 + GitOps)
```

## 使用方法

### 1. 設置環境變數

在 GitHub repository secrets 中設置：

```bash
GITEA_TOKEN=<your-gitea-token>
GITEA_URL=http://172.18.0.2:30924/admin1/edge2-config
```

### 2. 本地運行驗證

```bash
# 運行所有驗證
./scripts/ci/validate-yaml.sh
./scripts/ci/validate-k8s-manifests.sh
./scripts/ci/validate-kpt-packages.sh
./scripts/ci/validate-policies.sh

# 運行測試
./scripts/ci/run-unit-tests.sh
./scripts/ci/run-smoke-tests.sh
```

### 3. 手動 GitOps 部署

```bash
export GITEA_TOKEN="your-token"
export GITEA_URL="http://172.18.0.2:30924/admin1/edge2-config"

./scripts/ci/deploy-to-gitops.sh
./scripts/ci/verify-gitops-deployment.sh
```

### 4. 觸發回滾

```bash
# 自動回滾 (基於觸發原因)
./scripts/ci/enhanced-rollback.sh deployment_failure

# 驗證回滾
./scripts/ci/verify-gitops-deployment.sh
```

## 報告和工件

所有 CI/CD 運行都會生成以下報告：

```
artifacts/
├── yaml-validation-report.json
├── k8s-validation-report.json
├── kpt-validation-report.json
├── policy-validation-report.json
├── unit-test-report.json
├── integration-test-report.json
├── smoke-test-report.json
├── gitops-deploy-report.json
├── gitops-verify-report.json
├── rollback-report.json
└── deployment-report.json (綜合報告)
```

## 故障排除

### 常見問題

1. **GitOps 部署失敗**
   - 檢查 GITEA_TOKEN 和 GITEA_URL 環境變數
   - 驗證 Gitea 伺服器可訪問性
   - 確認倉庫權限

2. **驗證失敗**
   - 檢查 YAML 語法錯誤
   - 修復 Kubernetes manifest 問題
   - 解決策略違規

3. **測試失敗**
   - 檢查 Python 依賴
   - 驗證 Kind 集群狀態
   - 修復腳本語法錯誤

### 調試命令

```bash
# 檢查 pipeline 狀態
cat artifacts/deployment-summary.txt

# 查看詳細錯誤
jq '.errors' artifacts/*-report.json

# 檢查 Git 狀態
git status
git log --oneline -5
```

## 最佳實踐

1. **代碼質量**
   - 在提交前運行本地驗證
   - 修復所有 linting 錯誤
   - 維護測試覆蓋率

2. **安全性**
   - 不要提交敏感信息
   - 使用環境變數和 secrets
   - 定期更新依賴

3. **GitOps**
   - 保持配置倉庫清潔
   - 使用描述性提交消息
   - 監控部署狀態

4. **回滾準備**
   - 定期測試回滾腳本
   - 維護已知良好的提交標記
   - 備份重要配置

## 高級配置

### 自定義驗證規則

在 `scripts/ci/validate-policies.sh` 中添加自定義 OPA 或 Kyverno 策略。

### 擴展測試套件

在 `tests/` 目錄中添加新的測試用例，並更新相應的測試腳本。

### 多環境支援

修改 GitOps 腳本以支援額外的目標環境或倉庫。

---

此 CI/CD pipeline 提供了生產級的自動化、驗證和回滾功能，確保配置更改的安全和可靠部署。