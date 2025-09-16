#!/usr/bin/env python3
"""
Trace Claude CLI calls with detailed logging
"""

import os
import sys
import json
import time
import subprocess
from pathlib import Path
from datetime import datetime

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent))

# Enable Claude CLI and verbose logging
os.environ['CLAUDE_CLI'] = '1'

import logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

from adapters.llm_client import get_llm_client, CACHE

def monkey_patch_subprocess():
    """Monkey patch subprocess to trace all Claude CLI calls"""
    original_run = subprocess.run

    def traced_run(cmd, *args, **kwargs):
        if isinstance(cmd, list) and 'claude' in cmd[0]:
            print(f"\n🔍 CLAUDE CLI CALL DETECTED at {datetime.now().strftime('%H:%M:%S.%f')[:-3]}")
            print(f"   Command: {' '.join(cmd[:2])}...")
            if len(cmd) > 2:
                prompt = cmd[2] if len(cmd) > 2 else ""
                print(f"   Prompt preview: {prompt[:100]}...")
            print(f"   Timeout: {kwargs.get('timeout', 'default')}s")

            start = time.time()
            result = original_run(cmd, *args, **kwargs)
            elapsed = time.time() - start

            print(f"   Return code: {result.returncode}")
            print(f"   Execution time: {elapsed:.2f}s")
            if result.stdout:
                print(f"   Output preview: {result.stdout[:100]}...")

            return result
        else:
            return original_run(cmd, *args, **kwargs)

    subprocess.run = traced_run
    print("✅ Subprocess monitoring enabled - all Claude CLI calls will be traced\n")

def test_with_tracing():
    """Test NL parsing with full tracing"""
    print("=" * 80)
    print("TESTING NATURAL LANGUAGE TO TMF921 CONVERSION WITH CLAUDE CLI")
    print("=" * 80)

    # Clear cache to ensure fresh calls
    CACHE.clear()

    client = get_llm_client()
    print(f"\n📊 Client Configuration:")
    print(f"   Mode: {client.get_model_info()}")
    print(f"   Claude Available: {client.claude_available}")
    print(f"   Timeout: {client.timeout}s")
    print(f"   Max Retries: {client.max_retries}")

    # Test cases
    test_cases = [
        {
            "id": "Test-1",
            "input": "Deploy eMBB slice in edge1 with 200Mbps DL, 30ms latency",
            "description": "Standard eMBB deployment"
        },
        {
            "id": "Test-2",
            "input": "Need ultra-reliable service at edge2 for autonomous vehicles",
            "description": "URLLC service detection"
        },
        {
            "id": "Test-3",
            "input": "Setup IoT sensors across both edge sites",
            "description": "mMTC with multi-site deployment"
        }
    ]

    results = []

    for test in test_cases:
        print(f"\n" + "=" * 80)
        print(f"🧪 {test['id']}: {test['description']}")
        print(f"   Input: \"{test['input']}\"")
        print("-" * 80)

        start_time = time.time()

        try:
            # Parse the text - this should trigger Claude CLI
            result = client.parse_text(test['input'])
            elapsed = time.time() - start_time

            print(f"\n✅ Parsing completed in {elapsed:.2f}s")
            print(f"📤 Result:")
            print(json.dumps(result, indent=2))

            results.append({
                "test_id": test['id'],
                "success": True,
                "time": elapsed,
                "result": result
            })

        except Exception as e:
            print(f"\n❌ Error: {e}")
            results.append({
                "test_id": test['id'],
                "success": False,
                "error": str(e)
            })

    # Summary
    print("\n" + "=" * 80)
    print("📊 EXECUTION SUMMARY")
    print("=" * 80)

    successful = sum(1 for r in results if r.get('success', False))
    print(f"Tests completed: {len(results)}")
    print(f"Successful: {successful}/{len(results)}")

    if client.fallback_count > 0:
        print(f"⚠️  Fallback used: {client.fallback_count} times")
    else:
        print(f"✅ No fallbacks - all processed through Claude CLI")

    print(f"LLM Success count: {client.llm_success_count}")

    # Save trace log
    artifacts_dir = Path('/home/ubuntu/nephio-intent-to-o2-demo/artifacts/adapter')
    trace_file = artifacts_dir / f"claude_trace_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

    with open(trace_file, 'w') as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "mode": client.get_model_info(),
            "results": results,
            "stats": {
                "llm_success": client.llm_success_count,
                "fallback_count": client.fallback_count
            }
        }, f, indent=2)

    print(f"\n💾 Trace saved to: {trace_file}")
    print("=" * 80)

def main():
    # Enable subprocess tracing
    monkey_patch_subprocess()

    # Run tests with tracing
    test_with_tracing()

    return 0

if __name__ == "__main__":
    exit(main())