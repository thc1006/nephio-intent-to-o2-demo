#!/usr/bin/env bash
# 完整系統設定腳本 - 啟動所有必要服務
# 適用於 VM-1 (SMO/GitOps Orchestrator)

set -euo pipefail

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 網路配置（根據 AUTHORITATIVE_NETWORK_CONFIG.md）
export VM1_IP="172.16.0.78"
export VM2_IP="172.16.4.45"    # Edge1
export VM3_IP="172.16.2.10"  # LLM Adapter
export VM4_IP="172.16.0.89"    # Edge2
export GITEA_URL="http://${VM1_IP}:8888"
export LLM_ADAPTER_URL="http://${VM3_IP}:8888"

echo -e "${BLUE}=== 完整系統設定開始 ===${NC}"
echo -e "VM-1 IP: $VM1_IP"
echo -e "VM-2 (Edge1) IP: $VM2_IP"
echo -e "VM-3 (LLM) IP: $VM3_IP"
echo -e "VM-4 (Edge2) IP: $VM4_IP"

# 步驟 1: 驗證基礎環境
echo -e "\n${YELLOW}[1/8] 驗證基礎環境${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Kubernetes 叢集運行中${NC}"
    kubectl get nodes
else
    echo -e "${RED}✗ Kubernetes 叢集未運行${NC}"
    exit 1
fi

# 步驟 2: 檢查 Gitea
echo -e "\n${YELLOW}[2/8] 檢查 Gitea 服務${NC}"
if curl -s http://localhost:8888 | grep -q "Gitea"; then
    echo -e "${GREEN}✓ Gitea 運行中${NC}"
else
    echo -e "${YELLOW}! 啟動 Gitea...${NC}"
    ./start-gitea.sh || true
    sleep 10
fi

# 步驟 3: 安裝 Config Sync (如果需要)
echo -e "\n${YELLOW}[3/8] 安裝 Config Sync${NC}"
if kubectl get ns config-management-system &>/dev/null; then
    echo -e "${GREEN}✓ Config Sync 已安裝${NC}"
else
    echo -e "${YELLOW}! 安裝 Config Sync...${NC}"
    kubectl apply -f https://github.com/GoogleContainerTools/kpt-config-sync/releases/download/v1.17.0/config-sync-manifest.yaml

    echo "等待 Config Sync 準備好..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/config-management-operator -n config-management-system || true
fi

# 步驟 4: 部署 O2IMS CRDs
echo -e "\n${YELLOW}[4/8] 部署 O2IMS CRDs${NC}"
if kubectl get crd provisioningrequests.o2ims.provisioning.oran.org &>/dev/null; then
    echo -e "${GREEN}✓ O2IMS CRDs 已部署${NC}"
else
    echo -e "${YELLOW}! 部署 O2IMS CRDs...${NC}"
    if [ -d "o2ims-sdk/config/crd/bases" ]; then
        kubectl apply -f o2ims-sdk/config/crd/bases/ || true
    else
        echo -e "${YELLOW}警告: O2IMS CRD 目錄不存在${NC}"
    fi
fi

# 步驟 5: 設定 GitOps 儲存庫
echo -e "\n${YELLOW}[5/8] 設定 GitOps 儲存庫${NC}"
# 檢查儲存庫是否存在
if curl -s -u admin:admin123 ${GITEA_URL}/api/v1/repos/admin/edge1-config | grep -q "id"; then
    echo -e "${GREEN}✓ edge1-config 儲存庫已存在${NC}"
else
    echo -e "${YELLOW}! 創建 edge1-config 儲存庫...${NC}"
    curl -u admin:admin123 -X POST ${GITEA_URL}/api/v1/user/repos \
        -H "Content-Type: application/json" \
        -d '{"name":"edge1-config","private":false,"auto_init":true}' || true
fi

if curl -s -u admin:admin123 ${GITEA_URL}/api/v1/repos/admin/edge2-config | grep -q "id"; then
    echo -e "${GREEN}✓ edge2-config 儲存庫已存在${NC}"
else
    echo -e "${YELLOW}! 創建 edge2-config 儲存庫...${NC}"
    curl -u admin:admin123 -X POST ${GITEA_URL}/api/v1/user/repos \
        -H "Content-Type: application/json" \
        -d '{"name":"edge2-config","private":false,"auto_init":true}' || true
fi

# 步驟 6: 測試 LLM Adapter 連線
echo -e "\n${YELLOW}[6/8] 測試 LLM Adapter 連線${NC}"
if curl -s --connect-timeout 5 ${LLM_ADAPTER_URL}/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ LLM Adapter 連線成功${NC}"
    curl -s ${LLM_ADAPTER_URL}/health | jq '.' || true
else
    echo -e "${YELLOW}警告: 無法連接到 LLM Adapter (${LLM_ADAPTER_URL})${NC}"
    echo -e "請確認 VM-3 服務運行中"
fi

# 步驟 7: 測試 Edge 站點連線
echo -e "\n${YELLOW}[7/8] 測試 Edge 站點連線${NC}"

# 測試 Edge1
echo -e "\n測試 Edge1 (VM-2: $VM2_IP):"
if ping -c 1 -W 2 $VM2_IP &>/dev/null; then
    echo -e "${GREEN}✓ Edge1 ICMP 連通${NC}"
else
    echo -e "${YELLOW}! Edge1 ICMP 不通${NC}"
fi

if nc -vz -w 3 $VM2_IP 6443 &>/dev/null; then
    echo -e "${GREEN}✓ Edge1 Kubernetes API 可達${NC}"
else
    echo -e "${YELLOW}! Edge1 Kubernetes API 不可達${NC}"
fi

# 測試 Edge2
echo -e "\n測試 Edge2 (VM-4: $VM4_IP):"
if ping -c 1 -W 2 $VM4_IP &>/dev/null; then
    echo -e "${GREEN}✓ Edge2 ICMP 連通${NC}"
else
    echo -e "${YELLOW}! Edge2 ICMP 不通${NC}"
fi

if nc -vz -w 3 $VM4_IP 6443 &>/dev/null; then
    echo -e "${GREEN}✓ Edge2 Kubernetes API 可達${NC}"
else
    echo -e "${YELLOW}! Edge2 Kubernetes API 不可達${NC}"
fi

# 步驟 8: 系統狀態總結
echo -e "\n${YELLOW}[8/8] 系統狀態總結${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "核心服務狀態:"
echo -e "  Kubernetes: $(kubectl version --short 2>/dev/null | head -1 || echo 'Unknown')"
echo -e "  Gitea: ${GITEA_URL}"
echo -e "  LLM Adapter: ${LLM_ADAPTER_URL}"
echo -e ""
echo -e "GitOps 元件:"
kubectl get pods -n config-management-system 2>/dev/null || echo "  Config Sync 未安裝"
echo -e ""
echo -e "O2IMS 元件:"
kubectl get crd | grep o2ims || echo "  O2IMS CRDs 未安裝"
echo -e "${BLUE}================================${NC}"

# 環境變數設定提示
echo -e "\n${GREEN}系統設定完成！${NC}"
echo -e "\n請設定以下環境變數後執行演示："
echo -e "${YELLOW}export VM2_IP=${VM2_IP}${NC}"
echo -e "${YELLOW}export VM3_IP=${VM3_IP}${NC}"
echo -e "${YELLOW}export VM4_IP=${VM4_IP}${NC}"
echo -e "${YELLOW}export LLM_ADAPTER_URL=${LLM_ADAPTER_URL}${NC}"
echo -e ""
echo -e "然後執行："
echo -e "${GREEN}./scripts/demo_llm.sh --target edge1 --mode automated${NC}"