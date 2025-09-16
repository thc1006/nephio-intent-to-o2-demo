#!/usr/bin/env python3
"""
實時驗證 Claude CLI 是否被呼叫
"""
import os
import sys
import time
import requests
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

# 確保 Claude CLI 啟用
os.environ['CLAUDE_CLI'] = '1'

from adapters.llm_client import get_llm_client, CACHE

def test_live_claude_call():
    """測試實時 Claude CLI 呼叫"""
    print("=" * 60)
    print("實時驗證 Claude CLI 呼叫")
    print("=" * 60)

    # 清空快取確保新呼叫
    CACHE.clear()
    print("✅ 快取已清空")

    # 獲取 client
    client = get_llm_client()
    print(f"📊 模式: {client.get_model_info()}")
    print(f"📊 Claude 可用: {client.claude_available}")

    # 唯一的測試輸入（避免快取）
    test_input = f"Deploy 5G service at edge1 with {int(time.time()) % 1000}mbps at {time.strftime('%H:%M:%S')}"
    print(f"\n📝 測試輸入: {test_input}")
    print("-" * 60)

    # 記錄開始時間
    start_time = time.time()
    print(f"⏱️  開始時間: {time.strftime('%H:%M:%S.%f')[:-3]}")

    # 追蹤 Claude 呼叫
    original_method = client._parse_with_claude
    claude_called = False

    def tracked_parse_claude(text):
        nonlocal claude_called
        claude_called = True
        print(f"🔔 Claude CLI 被呼叫！時間: {time.strftime('%H:%M:%S.%f')[:-3]}")
        return original_method(text)

    client._parse_with_claude = tracked_parse_claude

    try:
        # 執行解析
        result = client.parse_text(test_input)
        elapsed = time.time() - start_time

        print(f"⏱️  結束時間: {time.strftime('%H:%M:%S.%f')[:-3]}")
        print(f"⏱️  總耗時: {elapsed:.2f} 秒")
        print("-" * 60)

        if claude_called:
            print("✅ Claude CLI 確實被呼叫")
            if elapsed > 2:
                print(f"✅ 執行時間 {elapsed:.2f}秒 符合 Claude CLI 特徵（5-6秒）")
            else:
                print(f"⚠️  執行時間 {elapsed:.2f}秒 較快，可能使用了優化")
        else:
            print("❌ Claude CLI 未被呼叫（使用了降級機制）")

        print(f"\n📤 解析結果:")
        print(f"   服務類型: {result.get('service')}")
        print(f"   目標站點: {result.get('targetSite')}")
        print(f"   QoS: {result.get('qos')}")

    finally:
        # 恢復原始方法
        client._parse_with_claude = original_method

    print("\n" + "=" * 60)

    # API 測試
    print("\n測試 API 端點...")
    api_start = time.time()
    response = requests.post(
        "http://localhost:8888/generate_intent",
        json={"natural_language": test_input + " NEW"},
        timeout=30
    )
    api_elapsed = time.time() - api_start

    print(f"API 回應時間: {api_elapsed:.2f} 秒")
    if api_elapsed > 2:
        print("✅ API 使用 Claude CLI（回應時間 > 2秒）")
    else:
        print("⚠️  API 可能使用快取或規則式")

    return claude_called

if __name__ == "__main__":
    success = test_live_claude_call()
    exit(0 if success else 1)