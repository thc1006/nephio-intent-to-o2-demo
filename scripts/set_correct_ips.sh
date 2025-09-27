#!/usr/bin/env bash
# 設定正確的 IP 地址（基於實際網路配置）

# VM-1 (Integrated) LLM Adapter - 使用內部 IP（已確認可連線）
export VM1_IP=172.16.0.78
export LLM_ADAPTER_URL=http://172.16.0.78:8888

# VM-2 Edge1 - 保持不變
export VM2_IP=172.16.4.45

# VM-4 Edge2 - 如果有的話
export VM4_IP=172.16.4.176

echo "環境變數已設定："
echo "  VM1_IP (LLM Adapter): $VM1_IP ✅"
echo "  VM2_IP (Edge1): $VM2_IP"
echo "  VM4_IP (Edge2): $VM4_IP"
echo "  LLM_ADAPTER_URL: $LLM_ADAPTER_URL ✅"
echo ""
echo "現在可以執行："
echo "  ./scripts/demo_llm.sh --target edge1 --mode automated"