#!/bin/bash
# 快速演示腳本 - 在 VM-3 上執行

echo "===================================="
echo "Nephio Intent-to-O2 快速演示"
echo "===================================="
echo ""

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 顯示服務狀態
echo -e "${BLUE}1. 檢查 LLM Adapter 服務狀態${NC}"
echo "-----------------------------------"
systemctl is-active llm-adapter && echo -e "${GREEN}✓ 服務運行中${NC}" || echo -e "${YELLOW}✗ 服務未運行${NC}"
echo ""

# 2. 顯示 Web UI 訪問地址
echo -e "${BLUE}2. Web UI 訪問地址${NC}"
echo "-----------------------------------"
echo "本機訪問: http://127.0.0.1:8888/"
echo "遠端訪問: http://172.16.2.10:8888/"
echo ""

# 3. 測試健康檢查
echo -e "${BLUE}3. 健康檢查測試${NC}"
echo "-----------------------------------"
curl -s http://localhost:8888/health | jq .
echo ""

# 4. 演示 eMBB 服務解析
echo -e "${BLUE}4. 演示：eMBB 高頻寬服務${NC}"
echo "-----------------------------------"
echo "輸入: 'Deploy eMBB slice in edge1 with 500Mbps downlink'"
curl -s -X POST http://localhost:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Deploy eMBB slice in edge1 with 500Mbps downlink"}' | jq .
echo ""

# 5. 演示 URLLC 服務解析
echo -e "${BLUE}5. 演示：URLLC 低延遲服務${NC}"
echo "-----------------------------------"
echo "輸入: 'Create URLLC service with 1ms latency for autonomous vehicles'"
curl -s -X POST http://localhost:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Create URLLC service with 1ms latency for autonomous vehicles"}' | jq .
echo ""

# 6. 演示 mMTC 服務解析
echo -e "${BLUE}6. 演示：mMTC IoT 服務${NC}"
echo "-----------------------------------"
echo "輸入: 'Setup IoT network for 100000 smart sensors in zone3'"
curl -s -X POST http://localhost:8888/api/v1/intent/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "Setup IoT network for 100000 smart sensors in zone3"}' | jq .
echo ""

# 7. 顯示使用說明
echo -e "${BLUE}7. 如何使用${NC}"
echo "-----------------------------------"
echo "A. Web UI 方式："
echo "   1. 開啟瀏覽器訪問 http://127.0.0.1:8888/"
echo "   2. 在文字框輸入自然語言請求"
echo "   3. 點擊 'Parse Intent (API v1)' 按鈕"
echo "   4. 查看 JSON 格式的解析結果"
echo ""
echo "B. API 方式："
echo "   curl -X POST http://172.16.2.10:8888/api/v1/intent/parse \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"text\": \"您的自然語言請求\"}'"
echo ""

echo -e "${GREEN}演示完成！${NC}"
echo "詳細教學請參考: E2E_DEMO_GUIDE.md"
echo "===================================="