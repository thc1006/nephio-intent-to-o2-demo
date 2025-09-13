#!/bin/bash
# load_config.sh - Configuration loader for edge sites
#
# 此腳本從權威配置文件載入站點配置
# 替代硬編碼配置，確保一致性和可維護性

set -euo pipefail

# 配置文件路徑
CONFIG_FILE="${CONFIG_FILE:-config/edge-sites-config.yaml}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FULL_CONFIG_PATH="$PROJECT_ROOT/$CONFIG_FILE"

# 檢查配置文件是否存在
if [[ ! -f "$FULL_CONFIG_PATH" ]]; then
    echo "❌ 配置文件不存在: $FULL_CONFIG_PATH" >&2
    echo "請確保權威配置文件已正確放置" >&2
    exit 1
fi

# 檢查依賴工具
check_dependencies() {
    local missing_deps=()

    for dep in python3 yq; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ 缺少必要工具: ${missing_deps[*]}" >&2
        echo "請安裝: sudo apt-get install python3 yq" >&2
        exit 1
    fi
}

# 載入站點配置
load_site_config() {
    echo "📋 從權威配置文件載入站點配置..."
    echo "配置文件: $FULL_CONFIG_PATH"

    # 使用 Python 生成 bash 配置
    python3 -c "
import sys
import yaml
import os

config_path = '$FULL_CONFIG_PATH'
try:
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)

    # 生成 SITES 配置
    sites = config.get('sites', {})
    print('# 從權威配置文件自動生成')
    print('declare -A SITES=(')
    for site_name, site_config in sites.items():
        slo_url = site_config['endpoints']['slo_metrics']['url']
        # 移除協議前綴
        endpoint = slo_url.replace('http://', '').replace('https://', '')
        print(f'    [{site_name}]=\"{endpoint}\"')
    print(')')
    print('')

    # 生成 O2IMS_SITES 配置
    print('declare -A O2IMS_SITES=(')
    for site_name, site_config in sites.items():
        o2ims_url = site_config['endpoints']['o2ims_api']['url']
        o2ims_path = site_config['endpoints']['o2ims_api']['path']
        full_url = f'{o2ims_url}{o2ims_path}'
        print(f'    [{site_name}]=\"{full_url}\"')
    print(')')
    print('')

    # 生成閾值配置
    thresholds = config.get('global', {}).get('slo_thresholds', {})
    print(f'LATENCY_P95_THRESHOLD_MS={thresholds.get(\"latency_p95_ms\", 15)}')
    print(f'SUCCESS_RATE_THRESHOLD={thresholds.get(\"success_rate_min\", 0.995)}')
    print(f'THROUGHPUT_P95_THRESHOLD_MBPS={thresholds.get(\"throughput_p95_mbps\", 200)}')
    print('')

    # 生成超時配置
    timeouts = config.get('global', {}).get('timeouts', {})
    print(f'METRICS_TIMEOUT_SECONDS={timeouts.get(\"connection_timeout_seconds\", 30)}')

except Exception as e:
    print(f'echo \"❌ 配置載入失敗: {e}\" >&2', file=sys.stderr)
    print('exit 1', file=sys.stderr)
    sys.exit(1)
"
}

# 驗證配置
validate_config() {
    echo "🔍 驗證配置完整性..."

    # 檢查必要的配置項是否存在
    if [[ -z "${SITES[@]:-}" ]]; then
        echo "❌ SITES 配置未正確載入" >&2
        return 1
    fi

    if [[ -z "${O2IMS_SITES[@]:-}" ]]; then
        echo "❌ O2IMS_SITES 配置未正確載入" >&2
        return 1
    fi

    echo "✅ 配置驗證通過"
    echo "✅ 載入了 ${#SITES[@]} 個站點: ${!SITES[*]}"
}

# 顯示載入的配置
show_config() {
    echo ""
    echo "📊 已載入的配置:"
    echo "站點配置:"
    for site in "${!SITES[@]}"; do
        echo "  $site: ${SITES[$site]}"
    done

    echo "O2IMS 配置:"
    for site in "${!O2IMS_SITES[@]}"; do
        echo "  $site: ${O2IMS_SITES[$site]}"
    done

    echo "閾值配置:"
    echo "  延遲 P95: ${LATENCY_P95_THRESHOLD_MS}ms"
    echo "  成功率: ${SUCCESS_RATE_THRESHOLD}"
    echo "  吞吐量: ${THROUGHPUT_P95_THRESHOLD_MBPS}Mbps"
}

# 主執行函數
main() {
    check_dependencies

    # 載入配置並執行在當前 shell 中
    eval "$(load_site_config)"

    # 驗證配置
    validate_config

    # 如果是直接執行腳本，顯示配置
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        show_config
    fi
}

# 如果直接執行此腳本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi