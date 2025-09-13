#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Gitea Access Alternatives${NC}"
echo -e "${BLUE}=========================================${NC}"

echo -e "\n${YELLOW}SSH Tunnel 失敗的替代方案：${NC}"

echo -e "\n${GREEN}方案 1: 使用 socat 轉發（在 VM 上）${NC}"
echo "----------------------------------------"
# Check if socat is installed
if ! command -v socat &> /dev/null; then
    echo "安裝 socat..."
    echo "sudo apt-get update && sudo apt-get install -y socat"
else
    echo "# 在 VM 上執行（會佔用終端）："
    echo "socat TCP-LISTEN:8080,fork,reuseaddr TCP:172.18.0.2:30924"
    echo ""
    echo "# 或背景執行："
    echo "nohup socat TCP-LISTEN:8080,fork,reuseaddr TCP:172.18.0.2:30924 > /tmp/socat.log 2>&1 &"
    echo ""
    echo "# 然後從你的筆電 SSH tunnel 到 VM 的 8080："
    echo "ssh -L 8080:localhost:8080 ubuntu@172.16.0.78"
fi

echo -e "\n${GREEN}方案 2: 使用 kubectl port-forward（在 VM 上）${NC}"
echo "----------------------------------------"
echo "# 在 VM 上執行："
echo "kubectl port-forward -n gitea-system svc/gitea-service 8080:3000 --address=0.0.0.0 &"
echo ""
echo "# 如果 0.0.0.0 不行，試試："
echo "kubectl port-forward -n gitea-system svc/gitea-service 8080:3000 --address=172.16.0.78 &"
echo ""
echo "# 然後直接從筆電訪問："
echo "http://172.16.0.78:8080"

echo -e "\n${GREEN}方案 3: 使用 nginx 反向代理（在 VM 上）${NC}"
echo "----------------------------------------"
cat << 'EOF'
# 安裝 nginx
sudo apt-get update && sudo apt-get install -y nginx

# 建立 nginx 設定
sudo tee /etc/nginx/sites-available/gitea-proxy << 'NGINX'
server {
    listen 8080;
    listen [::]:8080;
    server_name _;
    
    location / {
        proxy_pass http://172.18.0.2:30924;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

# 啟用設定
sudo ln -sf /etc/nginx/sites-available/gitea-proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 從筆電訪問
http://172.16.0.78:8080
EOF

echo -e "\n${GREEN}方案 4: 使用 SSH 動態轉發 (SOCKS proxy)${NC}"
echo "----------------------------------------"
echo "# 在筆電執行："
echo "ssh -D 9999 ubuntu@172.16.0.78"
echo ""
echo "# 設定瀏覽器使用 SOCKS proxy："
echo "SOCKS Host: localhost"
echo "Port: 9999"
echo ""
echo "# 然後直接訪問內部 IP："
echo "http://172.18.0.2:30924"

echo -e "\n${GREEN}方案 5: 直接在 VM 上用 CLI 建立使用者和 Token${NC}"
echo "----------------------------------------"
echo "# 先檢查 Gitea 資料庫"
kubectl exec -n gitea-system $(kubectl get pods -n gitea-system -l app=gitea -o jsonpath='{.items[0].metadata.name}') -- \
    su git -c "gitea admin user list" 2>/dev/null || echo "需要用 git 使用者執行"

echo ""
echo "# 建立新管理員（如果需要）："
cat << 'EOF'
POD=$(kubectl get pods -n gitea-system -l app=gitea -o jsonpath='{.items[0].metadata.name}')

# 建立管理員使用者
kubectl exec -n gitea-system $POD -- su git -c "gitea admin user create \
    --username admin \
    --password 'Admin123!' \
    --email admin@example.com \
    --admin"

# 產生 access token
kubectl exec -n gitea-system $POD -- su git -c "gitea admin user generate-access-token \
    --username admin \
    --token-name edge-gitops \
    --scopes write:repository,write:user"
EOF

echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE}快速測試當前可用方法${NC}"
echo -e "${BLUE}=========================================${NC}"

# Test kubectl port-forward
echo -e "\n測試 kubectl port-forward..."
timeout 2 kubectl port-forward -n gitea-system svc/gitea-service 8081:3000 > /tmp/pf-test.log 2>&1 &
PF_PID=$!
sleep 1

if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null | grep -q "200"; then
    echo -e "${GREEN}✓ kubectl port-forward 可用！${NC}"
    echo "使用: kubectl port-forward -n gitea-system svc/gitea-service 8080:3000"
    kill $PF_PID 2>/dev/null || true
else
    echo -e "${RED}✗ kubectl port-forward 失敗${NC}"
fi

# Test direct access from VM
echo -e "\n測試從 VM 直接存取..."
if curl -s -o /dev/null -w "%{http_code}" http://172.18.0.2:30924 2>/dev/null | grep -q "200"; then
    echo -e "${GREEN}✓ 可從 VM 內部存取 Gitea${NC}"
    echo "Gitea URL: http://172.18.0.2:30924"
fi