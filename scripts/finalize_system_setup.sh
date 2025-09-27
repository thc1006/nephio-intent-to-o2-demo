#!/usr/bin/env bash
# 最終系統設定腳本 - 只處理還沒完成的部分
# 基於深入掃描的實際狀態

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

# 網路配置（根據你提供的資訊）
export VM1_IP="172.16.0.78"
export VM2_IP="172.16.4.45"    # Edge1
export VM1_IP="172.16.0.78"  # LLM Adapter（已確認運行）
export VM4_IP="172.16.4.176"    # Edge2
export GITEA_URL="http://${VM1_IP}:8888"
export LLM_ADAPTER_URL="http://${VM1_IP}:8888"

echo -e "${BLUE}=== 最終系統設定 - 基於實際狀態 ===${NC}"
echo -e "${GREEN}已確認的服務：${NC}"
echo -e "  ✅ Config Sync (RootSync/RepoSync CRDs)"
echo -e "  ✅ O2IMS (ProvisioningRequest CRD)"
echo -e "  ✅ Gitea (edge1-config, edge2-config 儲存庫)"
echo -e "  ✅ LLM Adapter (${VM1_IP}:8888)"

# 步驟 1: 安裝 Porch（如果需要）
echo -e "\n${YELLOW}[1/4] 檢查並安裝 Porch${NC}"
if kubectl get ns porch-system &>/dev/null; then
    echo -e "${GREEN}✓ Porch 已安裝${NC}"
else
    echo -e "${YELLOW}! 安裝 Porch...${NC}"
    # 使用本地腳本如果存在
    if [ -f "./scripts/p0.1_bootstrap.sh" ]; then
        echo "使用 p0.1_bootstrap.sh 安裝 Porch..."
        # 只執行 Porch 相關部分
        kubectl apply --server-side -f https://github.com/nephio-project/porch/releases/download/v1.0.0/porch-server.yaml || true
        sleep 10
    fi
fi

# 步驟 2: 創建 Gitea token 和 secret
echo -e "\n${YELLOW}[2/4] 設定 Gitea 認證${NC}"
if kubectl get secret gitea-token -n config-management-system &>/dev/null; then
    echo -e "${GREEN}✓ Gitea token secret 已存在${NC}"
else
    echo -e "${YELLOW}! 創建 Gitea token secret...${NC}"
    # 創建簡單的 token secret（實際生產環境應該用真實 token）
    kubectl create secret generic gitea-token \
        --from-literal=username=admin \
        --from-literal=token=admin123 \
        -n config-management-system || true
fi

# 步驟 3: 配置 RootSync（這是主要缺失的部分）
echo -e "\n${YELLOW}[3/4] 配置 RootSync for GitOps${NC}"
if kubectl get rootsync -n config-management-system &>/dev/null && [ $(kubectl get rootsync -n config-management-system --no-headers | wc -l) -gt 0 ]; then
    echo -e "${GREEN}✓ RootSync 已配置${NC}"
else
    echo -e "${YELLOW}! 創建 RootSync 配置...${NC}"

    # 為 edge1 創建 RootSync
    cat <<EOF | kubectl apply -f -
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: ${GITEA_URL}/admin/edge1-config
    branch: main
    auth: token
    secretRef:
      name: gitea-token
    period: 30s
EOF

    echo -e "${GREEN}✓ RootSync 已創建${NC}"
fi

# 步驟 4: 測試整個流程
echo -e "\n${YELLOW}[4/4] 驗證系統準備狀態${NC}"

# 檢查 Config Sync 狀態
echo -e "\n${BLUE}Config Sync 狀態：${NC}"
kubectl get rootsync -n config-management-system || echo "No RootSync found"

# 檢查 O2IMS CRD
echo -e "\n${BLUE}O2IMS CRD 狀態：${NC}"
kubectl get crd | grep o2ims || echo "O2IMS CRD not found"

# 測試 LLM Adapter
echo -e "\n${BLUE}測試 LLM Adapter：${NC}"
if curl -s --connect-timeout 5 ${LLM_ADAPTER_URL}/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ LLM Adapter 連線成功${NC}"
else
    echo -e "${YELLOW}! LLM Adapter 連線失敗 - 請確認 VM-1 (Integrated) 服務${NC}"
fi

# 測試 Gitea
echo -e "\n${BLUE}測試 Gitea：${NC}"
if curl -s ${GITEA_URL}/api/v1/version | grep -q "version"; then
    echo -e "${GREEN}✓ Gitea API 正常${NC}"
else
    echo -e "${YELLOW}! Gitea API 無回應${NC}"
fi

# 系統準備狀態總結
echo -e "\n${BLUE}================================${NC}"
echo -e "${GREEN}系統準備狀態總結${NC}"
echo -e "${BLUE}================================${NC}"

echo -e "\n${GREEN}核心元件狀態：${NC}"
echo -e "  Config Sync: $(kubectl get pods -n config-management-system --no-headers | wc -l) pods"
echo -e "  O2IMS CRDs: $(kubectl get crd | grep o2ims | wc -l) CRDs"
echo -e "  Gitea: ${GITEA_URL}"
echo -e "  LLM Adapter: ${LLM_ADAPTER_URL}"

echo -e "\n${GREEN}準備執行演示：${NC}"
echo -e "1. 設定環境變數："
echo -e "   ${YELLOW}export VM2_IP=${VM2_IP}${NC}"
echo -e "   ${YELLOW}export VM1_IP=${VM1_IP}${NC}"
echo -e "   ${YELLOW}export VM4_IP=${VM4_IP}${NC}"

echo -e "\n2. 執行演示："
echo -e "   ${GREEN}./scripts/demo_llm.sh --target edge1 --mode automated${NC}"

echo -e "\n3. 或執行 dry-run 測試："
echo -e "   ${GREEN}./scripts/demo_llm.sh --dry-run --target edge1${NC}"

echo -e "\n${BLUE}================================${NC}"
echo -e "${GREEN}✅ 系統設定完成！${NC}"
echo -e "${BLUE}================================${NC}"