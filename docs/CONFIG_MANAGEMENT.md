# Edge Sites 配置管理指南

## 📋 概述

本指南說明如何使用和維護 `config/edge-sites-config.yaml` 權威配置文件。

## 🎯 配置文件架構

### 檔案位置
```
config/edge-sites-config.yaml    # 權威配置文件
examples/config_reader.py        # Python 配置讀取器
docs/CONFIG_MANAGEMENT.md        # 本使用指南
```

### 配置結構
```yaml
global:           # 全域設定 (閾值、超時等)
sites:            # 站點配置
  edge1:          # Edge1 (VM-2) 配置
  edge2:          # Edge2 (VM-4) 配置
cross_site:       # 跨站點配置
deployment_templates: # 部署模板
troubleshooting:  # 故障排除指南
```

## 🚀 使用方式

### 1. Python 腳本中使用

```python
from examples.config_reader import EdgeSiteConfig

# 初始化配置讀取器
config = EdgeSiteConfig()

# 獲取 Edge1 的 SLO 端點
edge1_url = config.get_slo_endpoint('edge1')

# 測試連通性
is_healthy = config.test_connectivity('edge1')

# 獲取所有站點端點
all_endpoints = config.get_all_slo_endpoints()
```

### 2. Bash 腳本中使用

```bash
# 使用 yq 工具讀取配置 (需要安裝 yq)
EDGE1_URL=$(yq '.sites.edge1.endpoints.slo_metrics.url' config/edge-sites-config.yaml)
EDGE2_URL=$(yq '.sites.edge2.endpoints.slo_metrics.url' config/edge-sites-config.yaml)

# 或使用 Python 一行程式生成 bash 配置
python3 -c "
from examples.config_reader import EdgeSiteConfig
config = EdgeSiteConfig()
print(config.get_postcheck_config())
" > /tmp/generated_config.sh

source /tmp/generated_config.sh
```

### 3. 現有腳本遷移

**舊方式 (硬編碼)**:
```bash
declare -A SITES=(
    [edge1]="172.16.4.45:30090/metrics/api/v1/slo"
    [edge2]="172.16.0.89:30090/metrics/api/v1/slo"
)
```

**新方式 (配置驅動)**:
```bash
# 從配置文件自動生成
source <(python3 -c "from examples.config_reader import EdgeSiteConfig; print(EdgeSiteConfig().get_postcheck_config())")
```

## 🔧 維護流程

### 新增站點

1. 在 `config/edge-sites-config.yaml` 的 `sites` 區塊新增站點:

```yaml
sites:
  edge3:  # 新站點
    name: "Edge3 (VM-5)"
    network:
      internal_ip: "172.16.0.90"
      external_ip: "147.251.115.194"
    endpoints:
      slo_metrics:
        url: "http://172.16.0.90:30090/metrics/api/v1/slo"
        # ... 其他配置
```

2. 測試配置:
```bash
python3 examples/config_reader.py
```

3. 更新相關腳本 (如果使用配置讀取器，無需修改代碼)

### 修改端點

1. 直接編輯 `config/edge-sites-config.yaml`
2. 更新 `changelog` 區塊記錄變更
3. 執行驗證測試

### 故障排除

配置文件包含 `troubleshooting` 區塊，記錄常見問題和解決方案。

## 📊 配置驗證

### 自動驗證
```bash
# YAML 格式驗證
python3 -c "import yaml; yaml.safe_load(open('config/edge-sites-config.yaml'))"

# 端點連通性測試
python3 examples/config_reader.py
```

### 手動驗證
```bash
# 測試 Edge1 連通性
curl -s http://$(yq '.sites.edge1.endpoints.slo_metrics.health_check' config/edge-sites-config.yaml | tr -d '"')

# 測試 Edge2 連通性
curl -s http://$(yq '.sites.edge2.endpoints.slo_metrics.health_check' config/edge-sites-config.yaml | tr -d '"')
```

## 📚 最佳實踐

### 1. 單一來源原則
- ✅ 所有端點配置都從此文件讀取
- ❌ 避免在腳本中硬編碼 IP 和端口

### 2. 版本控制
- ✅ 配置變更必須通過 Git 提交
- ✅ 重大變更需要 code review
- ✅ 更新 `changelog` 記錄變更

### 3. 測試優先
- ✅ 配置變更前先執行驗證腳本
- ✅ 確保所有端點可訪問
- ✅ 測試配置讀取器正常工作

### 4. 文檔同步
- ✅ 配置變更時同步更新相關文檔
- ✅ 保持故障排除指南的時效性

## 🎯 遷移檢查清單

將現有硬編碼配置遷移到配置文件系統:

- [ ] 識別所有硬編碼的 IP 和端口
- [ ] 使用配置讀取器替代硬編碼
- [ ] 測試所有相關腳本
- [ ] 更新部署文檔
- [ ] 訓練團隊成員使用新的配置系統

---

**透過統一的配置管理，我們確保了系統的可維護性和一致性。所有團隊成員都應該熟悉這套配置系統。**