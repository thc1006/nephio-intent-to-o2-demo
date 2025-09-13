#!/bin/bash
# validate-config.sh - 本地配置驗證腳本
#
# 此腳本在本地執行與 CI/CD 相同的配置驗證
# 可在提交前確保配置正確性

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 本地配置驗證開始..."
echo "專案根目錄: $PROJECT_ROOT"
echo ""

# 檢查依賴工具
check_dependencies() {
    echo "📋 檢查依賴工具..."
    local missing_deps=()

    for dep in python3 shellcheck bc jq yq; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ 缺少工具: ${missing_deps[*]}"
        echo "安裝指令: sudo apt-get install python3 shellcheck bc jq"
        echo "yq 安裝: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
        exit 1
    fi

    echo "✅ 所有依賴工具都已安裝"
}

# 驗證 YAML 語法
validate_yaml_syntax() {
    echo ""
    echo "📋 驗證 YAML 語法..."

    local yaml_files=()
    while IFS= read -r -d '' file; do
        yaml_files+=("$file")
    done < <(find "$PROJECT_ROOT/config" -name "*.yaml" -o -name "*.yml" -print0 2>/dev/null)

    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        echo "⚠️ 未找到 YAML 配置文件"
        return 0
    fi

    for file in "${yaml_files[@]}"; do
        echo "檢查: ${file#$PROJECT_ROOT/}"
        if python3 -c "
import yaml
import sys
try:
    with open('$file', 'r') as f:
        yaml.safe_load(f)
    print('  ✅ YAML 格式正確')
except yaml.YAMLError as e:
    print(f'  ❌ YAML 格式錯誤: {e}')
    sys.exit(1)
except Exception as e:
    print(f'  ❌ 讀取錯誤: {e}')
    sys.exit(1)
"; then
            continue
        else
            echo "❌ YAML 驗證失敗: $file"
            exit 1
        fi
    done

    echo "✅ 所有 YAML 文件格式正確"
}

# 驗證配置架構
validate_config_schema() {
    echo ""
    echo "📋 驗證配置架構..."

    cd "$PROJECT_ROOT"
    if python3 examples/config_reader.py > /dev/null; then
        echo "✅ 配置架構驗證通過"
    else
        echo "❌ 配置架構驗證失敗"
        exit 1
    fi
}

# 驗證腳本語法
validate_script_syntax() {
    echo ""
    echo "📋 驗證 Shell 腳本語法..."

    local script_files=()
    while IFS= read -r -d '' file; do
        script_files+=("$file")
    done < <(find "$PROJECT_ROOT/scripts" -name "*.sh" -print0 2>/dev/null)

    for script in "${script_files[@]}"; do
        echo "檢查: ${script#$PROJECT_ROOT/}"
        if shellcheck "$script"; then
            echo "  ✅ Shell 語法正確"
        else
            echo "  ❌ Shell 語法錯誤"
            exit 1
        fi
    done

    echo "✅ 所有腳本語法正確"
}

# 測試配置載入
test_config_loading() {
    echo ""
    echo "📋 測試配置載入..."

    cd "$PROJECT_ROOT/scripts"
    if source load_config.sh; then
        echo "✅ 配置載入成功"

        # 檢查關鍵變量
        if [[ -n "${SITES[@]:-}" ]]; then
            echo "  ✅ SITES 配置已載入 (${#SITES[@]} 個站點)"
        else
            echo "  ❌ SITES 配置未載入"
            exit 1
        fi

        if [[ -n "${O2IMS_SITES[@]:-}" ]]; then
            echo "  ✅ O2IMS_SITES 配置已載入"
        else
            echo "  ❌ O2IMS_SITES 配置未載入"
            exit 1
        fi

        echo "  ✅ 閾值配置: 延遲=${LATENCY_P95_THRESHOLD_MS}ms, 成功率=${SUCCESS_RATE_THRESHOLD}"
    else
        echo "❌ 配置載入失敗"
        exit 1
    fi
}

# 測試整合功能
test_integration() {
    echo ""
    echo "📋 測試整合功能..."

    cd "$PROJECT_ROOT"

    # 測試 Python 配置讀取器
    echo "測試 Python 配置讀取器..."
    if python3 -c "
from examples.config_reader import EdgeSiteConfig
config = EdgeSiteConfig()
sites = config.get_all_slo_endpoints()
print(f'載入了 {len(sites)} 個站點: {list(sites.keys())}')
thresholds = config.get_slo_thresholds()
print(f'載入了 {len(thresholds)} 個閾值配置')
"; then
        echo "  ✅ Python 配置讀取器正常"
    else
        echo "  ❌ Python 配置讀取器失敗"
        exit 1
    fi

    # 測試 bash 配置生成
    echo "測試 bash 配置生成..."
    if python3 -c "
from examples.config_reader import EdgeSiteConfig
config = EdgeSiteConfig()
bash_config = config.get_postcheck_config()
print('生成的 bash 配置:')
print(bash_config)
" > /dev/null; then
        echo "  ✅ Bash 配置生成正常"
    else
        echo "  ❌ Bash 配置生成失敗"
        exit 1
    fi
}

# 生成驗證報告
generate_report() {
    echo ""
    echo "📊 生成驗證報告..."

    local report_file="$PROJECT_ROOT/validation-report.txt"
    cat > "$report_file" << EOF
配置驗證報告
=============

執行時間: $(date)
執行目錄: $PROJECT_ROOT

驗證結果:
✅ YAML 語法驗證
✅ 配置架構驗證
✅ Shell 腳本語法驗證
✅ 配置載入測試
✅ 整合功能測試

配置文件:
- config/edge-sites-config.yaml (權威配置)
- scripts/load_config.sh (載入器)
- scripts/postcheck_v2.sh (配置驅動版本)
- examples/config_reader.py (Python 讀取器)

狀態: 所有驗證通過 ✅
EOF

    echo "✅ 驗證報告已生成: $report_file"
}

# 主執行函數
main() {
    check_dependencies
    validate_yaml_syntax
    validate_config_schema
    validate_script_syntax
    test_config_loading
    test_integration
    generate_report

    echo ""
    echo "🎉 所有配置驗證通過！"
    echo "✅ 可以安全提交配置變更"
}

# 處理錯誤
trap 'echo "❌ 驗證過程中發生錯誤"; exit 1' ERR

# 執行主函數
main "$@"