#!/usr/bin/env python3
"""
Edge Sites Configuration Reader
===============================

示範如何讀取和使用 edge-sites-config.yaml 權威配置文件

用途:
- 為所有 Python 腳本提供統一的配置讀取方式
- 避免硬編碼，提升維護性
- 確保配置一致性

作者: DevOps Team
日期: 2025-09-13
"""

import yaml
import requests
from typing import Dict, Any, Optional
from pathlib import Path

class EdgeSiteConfig:
    """Edge 站點配置管理類"""

    def __init__(self, config_path: str = "config/edge-sites-config.yaml"):
        """
        初始化配置讀取器

        Args:
            config_path: 配置文件路徑，相對於專案根目錄
        """
        self.config_path = Path(config_path)
        self.config = self._load_config()

    def _load_config(self) -> Dict[str, Any]:
        """載入 YAML 配置文件"""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as file:
                return yaml.safe_load(file)
        except FileNotFoundError:
            raise FileNotFoundError(f"配置文件未找到: {self.config_path}")
        except yaml.YAMLError as e:
            raise ValueError(f"YAML 格式錯誤: {e}")

    def get_site_config(self, site_name: str) -> Dict[str, Any]:
        """
        獲取指定站點的完整配置

        Args:
            site_name: 站點名稱 ('edge1' 或 'edge2')

        Returns:
            站點配置字典
        """
        sites = self.config.get('sites', {})
        if site_name not in sites:
            raise ValueError(f"站點 '{site_name}' 不存在於配置中")
        return sites[site_name]

    def get_slo_endpoint(self, site_name: str) -> str:
        """
        獲取指定站點的 SLO 監控端點 URL

        Args:
            site_name: 站點名稱

        Returns:
            SLO 端點 URL
        """
        site_config = self.get_site_config(site_name)
        return site_config['endpoints']['slo_metrics']['url']

    def get_health_check_url(self, site_name: str) -> str:
        """
        獲取指定站點的健康檢查端點

        Args:
            site_name: 站點名稱

        Returns:
            健康檢查 URL
        """
        site_config = self.get_site_config(site_name)
        return site_config['endpoints']['slo_metrics']['health_check']

    def get_all_slo_endpoints(self) -> Dict[str, str]:
        """
        獲取所有站點的 SLO 端點

        Returns:
            {站點名稱: SLO_URL} 的字典
        """
        endpoints = {}
        for site_name in self.config.get('sites', {}):
            endpoints[site_name] = self.get_slo_endpoint(site_name)
        return endpoints

    def get_slo_thresholds(self) -> Dict[str, float]:
        """
        獲取 SLO 閾值配置

        Returns:
            SLO 閾值字典
        """
        return self.config.get('global', {}).get('slo_thresholds', {})

    def test_connectivity(self, site_name: str) -> bool:
        """
        測試指定站點的連通性

        Args:
            site_name: 站點名稱

        Returns:
            True 如果連接成功，False 否則
        """
        try:
            health_url = self.get_health_check_url(site_name)
            timeout = self.config.get('global', {}).get('timeouts', {}).get('health_check_timeout_seconds', 10)

            response = requests.get(health_url, timeout=timeout)
            return response.status_code == 200
        except Exception as e:
            print(f"連接 {site_name} 失敗: {e}")
            return False

    def get_postcheck_config(self) -> str:
        """
        為 postcheck.sh 生成 bash 配置

        Returns:
            bash 配置字串
        """
        sites = self.get_all_slo_endpoints()
        config_lines = ["declare -A SITES=("]
        for site_name, url in sites.items():
            # 移除 http:// 前綴以符合 postcheck.sh 格式
            endpoint = url.replace('http://', '').replace('https://', '')
            config_lines.append(f'    [{site_name}]="{endpoint}"')
        config_lines.append(")")
        return '\n'.join(config_lines)


def main():
    """示範配置讀取器的使用"""
    print("=== Edge Sites 配置讀取器示範 ===\n")

    # 初始化配置讀取器
    try:
        config = EdgeSiteConfig()
        print("✅ 配置文件載入成功")
    except Exception as e:
        print(f"❌ 配置載入失敗: {e}")
        return

    # 示範 1: 獲取 edge1 的連線資訊
    print("\n📋 示範 1: 獲取 Edge1 連線資訊")
    try:
        edge1_slo = config.get_slo_endpoint('edge1')
        edge1_health = config.get_health_check_url('edge1')

        print(f"Edge1 SLO 端點: {edge1_slo}")
        print(f"Edge1 健康檢查: {edge1_health}")
    except Exception as e:
        print(f"獲取 Edge1 配置失敗: {e}")

    # 示範 2: 獲取所有站點端點
    print("\n📋 示範 2: 所有站點 SLO 端點")
    all_endpoints = config.get_all_slo_endpoints()
    for site, endpoint in all_endpoints.items():
        print(f"{site}: {endpoint}")

    # 示範 3: 獲取 SLO 閾值
    print("\n📋 示範 3: SLO 閾值配置")
    thresholds = config.get_slo_thresholds()
    for metric, threshold in thresholds.items():
        print(f"{metric}: {threshold}")

    # 示範 4: 測試連通性
    print("\n📋 示範 4: 連通性測試")
    for site_name in ['edge1', 'edge2']:
        status = "✅ 正常" if config.test_connectivity(site_name) else "❌ 失敗"
        print(f"{site_name}: {status}")

    # 示範 5: 生成 postcheck.sh 配置
    print("\n📋 示範 5: 生成 Bash 配置")
    bash_config = config.get_postcheck_config()
    print("生成的 postcheck.sh 配置:")
    print(bash_config)


if __name__ == "__main__":
    main()