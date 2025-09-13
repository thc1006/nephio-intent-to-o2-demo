#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Remote Gitea Access Guide${NC}"
echo -e "${BLUE}=========================================${NC}"

echo -e "\n${YELLOW}你的網路狀況：${NC}"
echo "筆電 IP: $(echo $SSH_CLIENT | awk '{print $1}')"
echo "VM 私網 IP: 172.16.0.78"
echo "Gitea 在 Kubernetes: 172.18.0.2:30924"
echo ""

echo -e "${RED}重要：${NC}"
echo "你無法直接從筆電存取 172.16.0.78:8888"
echo "因為 172.16.x.x 是私有網段，無法跨網路存取"
echo ""

echo -e "${GREEN}=== 解決方案：SSH Tunnel ===${NC}"
echo ""
echo -e "${BLUE}步驟 1: 先在 VM 確認 port-forward 運行中${NC}"
echo "檢查狀態："
ps aux | grep "port-forward.*8888" | grep -v grep && echo -e "${GREEN}✓ Port-forward 正在運行${NC}" || {
    echo -e "${YELLOW}Port-forward 未運行，正在啟動...${NC}"
    kubectl port-forward -n gitea-system svc/gitea-service 8888:3000 --address=127.0.0.1 > /tmp/pf.log 2>&1 &
    sleep 2
    echo -e "${GREEN}✓ Port-forward 已啟動${NC}"
}

echo ""
echo -e "${BLUE}步驟 2: 在你的筆電開新終端，執行以下命令${NC}"
echo "（請將 [VM_HOST] 替換成你平常 SSH 連線用的主機名或 IP）"
echo ""
echo -e "${YELLOW}ssh -L 8888:localhost:8888 ubuntu@[VM_HOST]${NC}"
echo ""
echo "範例："
echo "  ssh -L 8888:localhost:8888 ubuntu@your-vm.example.com"
echo "  或"
echo "  ssh -L 8888:localhost:8888 ubuntu@140.113.xxx.xxx"
echo ""

echo -e "${BLUE}步驟 3: 在筆電瀏覽器訪問${NC}"
echo -e "${GREEN}http://localhost:8888${NC}"
echo ""

echo -e "${BLUE}登入資訊：${NC}"
echo "使用者名稱: gitops-admin"
echo "密碼: GitOps123!"
echo ""

echo "========================================="
echo -e "${YELLOW}其他選項：${NC}"
echo "========================================="
echo ""
echo "1. 如果 8888 埠被佔用，可改用其他埠："
echo "   VM 上: kubectl port-forward -n gitea-system svc/gitea-service 9999:3000 --address=127.0.0.1 &"
echo "   筆電: ssh -L 9999:localhost:9999 ubuntu@[VM_HOST]"
echo ""
echo "2. 使用 SOCKS proxy (可存取所有 VM 內部服務)："
echo "   筆電: ssh -D 1080 ubuntu@[VM_HOST]"
echo "   設定瀏覽器 SOCKS proxy: localhost:1080"
echo "   直接訪問: http://172.18.0.2:30924"
echo ""
echo "3. 使用 VS Code Remote SSH："
echo "   安裝 Remote-SSH 擴充功能"
echo "   連線到 VM 後，使用內建的 Port Forward 功能"