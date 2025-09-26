#!/bin/bash
# 快速測試監控狀態

echo "==================================="
echo "    服務連線狀態測試"
echo "==================================="
echo

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 測試函數
test_service() {
    local name="$1"
    local url="$2"
    local code=$(curl -s --max-time 2 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    if [[ "$code" == "200" ]] || [[ "$code" == "201" ]] || [[ "$code" == "301" ]] || [[ "$code" == "302" ]]; then
        echo -e "$name: ${GREEN}✅ Online${NC} (HTTP $code)"
    else
        echo -e "$name: ${RED}❌ Offline${NC} (HTTP $code)"
    fi
}

# 測試所有服務
test_service "LLM Adapter (VM-1 Integrated)" "http://localhost:8002/health"
test_service "O2IMS Edge1 (VM-2)" "http://172.16.4.45:31280"
test_service "O2IMS Edge2 (VM-4)" "http://172.16.4.176:31280"
test_service "Gitea Repository" "http://localhost:8888"

echo
echo "==================================="
echo "現在可以運行視覺化監控："
echo "./scripts/visual_monitor.sh"
echo "==================================="