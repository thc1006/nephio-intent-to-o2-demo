#!/bin/bash
# 權威連線測試腳本 - 基於 AUTHORITATIVE_NETWORK_CONFIG.md
# 最後更新: 2025-09-14

echo "=== 🔐 權威網路連線測試 ==="
echo "基於 AUTHORITATIVE_NETWORK_CONFIG.md"
echo ""

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 測試函數
test_connection() {
    local name=$1
    local host=$2
    local port=$3
    local protocol=${4:-tcp}

    if [ "$protocol" = "icmp" ]; then
        if ping -c 1 -W 2 $host > /dev/null 2>&1; then
            echo -e "${GREEN}✅${NC} $name: ICMP ping 成功"
            return 0
        else
            echo -e "${RED}❌${NC} $name: ICMP ping 失敗"
            return 1
        fi
    else
        if nc -vz -w 3 $host $port > /dev/null 2>&1; then
            echo -e "${GREEN}✅${NC} $name: 端口 $port 可達"
            return 0
        else
            echo -e "${RED}❌${NC} $name: 端口 $port 不可達"
            return 1
        fi
    fi
}

# 測試 HTTP 服務
test_http_service() {
    local name=$1
    local url=$2

    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$url" | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✅${NC} $name: HTTP 服務正常"
        return 0
    else
        echo -e "${YELLOW}⚠️${NC} $name: HTTP 服務無回應或錯誤"
        return 1
    fi
}

echo "📊 VM-1 → Edge1 (VM-2: 172.16.4.45) 連線測試"
echo "========================================="
test_connection "ICMP" "172.16.4.45" "" "icmp"
test_connection "SSH" "172.16.4.45" "22"
test_connection "Kubernetes API" "172.16.4.45" "6443"
test_connection "SLO Service" "172.16.4.45" "30090"
test_connection "O2IMS API" "172.16.4.45" "31280"
test_http_service "SLO Health" "http://172.16.4.45:30090/health"
echo ""

echo "📊 VM-1 → Edge2 (VM-4: 172.16.0.89) 連線測試"
echo "========================================="
test_connection "ICMP" "172.16.0.89" "" "icmp"
test_connection "SSH" "172.16.0.89" "22"
test_connection "Kubernetes API" "172.16.0.89" "6443"
test_connection "SLO Service" "172.16.0.89" "30090"
test_connection "O2IMS API" "172.16.0.89" "31280"
test_http_service "SLO Health" "http://172.16.0.89:30090/health"
echo ""

echo "🚀 Gitea GitOps 服務測試"
echo "========================="
test_connection "Gitea Internal" "localhost" "8888"
test_http_service "Gitea Web" "http://localhost:8888"
echo ""

echo "📝 測試摘要"
echo "==========="
echo "• Edge1: 使用內部 IP 172.16.4.45"
echo "• Edge2: 使用內部 IP 172.16.0.89"
echo "• Gitea: 運行在 VM-1:8888"
echo ""
echo "💡 提示："
echo "• 如果 ICMP 失敗，檢查 OpenStack Security Groups"
echo "• 如果端口不可達，檢查服務是否運行"
echo "• 詳細配置請參考 AUTHORITATIVE_NETWORK_CONFIG.md"