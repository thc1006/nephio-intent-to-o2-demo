#!/bin/bash
# TMF921 Adapter Automation Environment

export CLAUDE_SKIP_AUTH=true
export TMF921_ADAPTER_MODE=automated
export TMF921_FALLBACK_ENABLED=true
export PYTHONPATH=/home/ubuntu/nephio-intent-to-o2-demo/adapter/app

echo '✅ TMF921 automation environment set'
