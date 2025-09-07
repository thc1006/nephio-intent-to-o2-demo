#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Gitea Remote Access Setup${NC}"
echo -e "${BLUE}=========================================${NC}"

echo -e "\n${YELLOW}選擇存取方式:${NC}"
echo "1) SSH Tunnel (從你的筆電建立 tunnel)"
echo "2) kubectl port-forward (在 VM 上執行)"
echo "3) 純 CLI 操作 (不需要瀏覽器)"
echo ""
read -p "請選擇 [1-3]: " CHOICE

case $CHOICE in
    1)
        echo -e "\n${GREEN}=== SSH Tunnel 方法 ===${NC}"
        echo -e "${YELLOW}在你的本地筆電終端執行以下命令:${NC}"
        echo ""
        
        # Get current SSH connection info
        SSH_CLIENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
        VM_IP=$(hostname -I | awk '{print $1}')
        
        echo "# 建立 SSH tunnel (在你的筆電執行)"
        echo "ssh -L 8080:172.18.0.2:30924 ubuntu@${VM_IP}"
        echo ""
        echo "# 或者如果你已經知道 VM 的 IP:"
        echo "ssh -L 8080:172.18.0.2:30924 ubuntu@172.16.0.78"
        echo ""
        echo -e "${BLUE}然後在你的筆電瀏覽器訪問:${NC}"
        echo "http://localhost:8080"
        echo ""
        echo -e "${YELLOW}預設登入帳密:${NC}"
        echo "Username: gitea_admin"
        echo "Password: r8sA8CPHD9!bt6d"
        ;;
        
    2)
        echo -e "\n${GREEN}=== kubectl port-forward 方法 ===${NC}"
        echo -e "${YELLOW}在 VM 上執行:${NC}"
        echo ""
        
        # Kill existing port-forward if any
        pkill -f "port-forward.*gitea-service" 2>/dev/null || true
        
        echo "# 背景執行 port-forward"
        echo "nohup kubectl port-forward -n gitea-system svc/gitea-service 8080:3000 --address=0.0.0.0 > /tmp/gitea-pf.log 2>&1 &"
        echo ""
        echo "# 實際執行:"
        nohup kubectl port-forward -n gitea-system svc/gitea-service 8080:3000 --address=0.0.0.0 > /tmp/gitea-pf.log 2>&1 &
        PF_PID=$!
        sleep 2
        
        if ps -p $PF_PID > /dev/null; then
            echo -e "${GREEN}✓ Port-forward 已啟動 (PID: $PF_PID)${NC}"
            echo ""
            echo -e "${BLUE}現在建立 SSH tunnel (在你的筆電執行):${NC}"
            echo "ssh -L 8080:localhost:8080 ubuntu@$(hostname -I | awk '{print $1}')"
            echo ""
            echo -e "${BLUE}然後訪問:${NC}"
            echo "http://localhost:8080"
        else
            echo -e "${RED}Port-forward 啟動失敗${NC}"
            cat /tmp/gitea-pf.log
        fi
        ;;
        
    3)
        echo -e "\n${GREEN}=== 純 CLI 方法 (自動建立 Token) ===${NC}"
        echo -e "${YELLOW}直接在 VM 上用 CLI 建立 token...${NC}"
        echo ""
        
        # Source environment
        source scripts/env.sh 2>/dev/null || true
        
        GITEA_URL="${GITEA_URL:-http://172.18.0.2:30924}"
        GITEA_USER="gitea_admin"
        GITEA_PASS="r8sA8CPHD9!bt6d"
        
        echo "使用預設管理員帳號建立 token..."
        
        # Create token using curl with basic auth
        TOKEN_NAME="edge-gitops-$(date +%s)"
        
        echo "正在建立 token: $TOKEN_NAME"
        
        RESPONSE=$(curl -s -X POST \
            -u "${GITEA_USER}:${GITEA_PASS}" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${TOKEN_NAME}\"}" \
            "${GITEA_URL}/api/v1/users/${GITEA_USER}/tokens" 2>/dev/null)
        
        TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')
        
        if [ -n "$TOKEN" ]; then
            echo -e "${GREEN}✓ Token 建立成功！${NC}"
            echo ""
            echo -e "${YELLOW}Token:${NC}"
            echo "$TOKEN"
            echo ""
            
            # Save to env.sh
            echo "export GITEA_TOKEN=\"$TOKEN\"" >> scripts/env.sh
            echo -e "${GREEN}Token 已儲存到 scripts/env.sh${NC}"
            echo ""
            echo -e "${BLUE}現在執行:${NC}"
            echo "source scripts/env.sh"
            echo "bash scripts/edge_repo_bootstrap.sh"
        else
            echo -e "${RED}Token 建立失敗${NC}"
            echo "Response: $RESPONSE"
            echo ""
            echo -e "${YELLOW}可能需要先初始化 Gitea 或檢查服務狀態${NC}"
        fi
        ;;
        
    *)
        echo -e "${RED}無效選擇${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}其他有用的命令:${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "# 檢查 Gitea 服務狀態"
echo "kubectl get pods -n gitea-system"
echo ""
echo "# 查看 port-forward 狀態"
echo "ps aux | grep port-forward"
echo ""
echo "# 停止 port-forward"
echo "pkill -f 'port-forward.*gitea-service'"
echo ""
echo "# 測試 token"
echo "bash scripts/test_gitea_auth.sh"