#!/bin/bash
set -euo pipefail

# Source environment
source scripts/env.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Gitea CLI 操作工具${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${YELLOW}由於 SSH tunnel 被禁用，這裡提供純 CLI 操作方式${NC}"
echo ""

function show_menu() {
    echo "選擇操作："
    echo "1) 列出所有 repositories"
    echo "2) 建立新 repository"
    echo "3) 查看 repository 詳情"
    echo "4) 建立新使用者"
    echo "5) 列出所有使用者"
    echo "6) 克隆 repository (使用 token)"
    echo "7) 查看 edge1-config 內容"
    echo "8) 推送更新到 edge1-config"
    echo "9) 退出"
    echo ""
    read -p "請選擇 [1-9]: " choice
}

function list_repos() {
    echo -e "\n${BLUE}Repositories:${NC}"
    curl -s -H "Authorization: token $GITEA_TOKEN" \
        "${GITEA_URL}/api/v1/user/repos" | jq -r '.[] | "\(.name) - \(.clone_url)"'
}

function create_repo() {
    read -p "Repository 名稱: " repo_name
    read -p "描述: " repo_desc
    read -p "私有 (true/false) [true]: " is_private
    is_private=${is_private:-true}
    
    response=$(curl -s -X POST \
        -H "Authorization: token $GITEA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$repo_name\",\"description\":\"$repo_desc\",\"private\":$is_private}" \
        "${GITEA_URL}/api/v1/user/repos")
    
    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Repository '$repo_name' 建立成功${NC}"
        echo "Clone URL: $(echo "$response" | jq -r '.clone_url')"
    else
        echo -e "${RED}建立失敗${NC}"
        echo "$response" | jq
    fi
}

function view_repo() {
    read -p "Repository 名稱 [edge1-config]: " repo_name
    repo_name=${repo_name:-edge1-config}
    
    echo -e "\n${BLUE}Repository 詳情:${NC}"
    curl -s -H "Authorization: token $GITEA_TOKEN" \
        "${GITEA_URL}/api/v1/repos/gitops-admin/$repo_name" | jq
}

function create_user() {
    read -p "使用者名稱: " username
    read -p "Email: " email
    read -s -p "密碼: " password
    echo ""
    
    # 需要管理員權限，使用 kubectl exec
    POD=$(kubectl get pods -n gitea-system -l app=gitea -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n gitea-system $POD -- su git -c "gitea admin user create \
        --username $username \
        --password '$password' \
        --email $email" && \
    echo -e "${GREEN}✓ 使用者 '$username' 建立成功${NC}" || \
    echo -e "${RED}建立失敗${NC}"
}

function list_users() {
    echo -e "\n${BLUE}使用者列表:${NC}"
    POD=$(kubectl get pods -n gitea-system -l app=gitea -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -n gitea-system $POD -- su git -c "gitea admin user list"
}

function clone_repo() {
    read -p "Repository 名稱 [edge1-config]: " repo_name
    repo_name=${repo_name:-edge1-config}
    read -p "Clone 到目錄 [/tmp/$repo_name]: " clone_dir
    clone_dir=${clone_dir:-/tmp/$repo_name}
    
    if [ -d "$clone_dir" ]; then
        echo -e "${YELLOW}目錄已存在，刪除中...${NC}"
        rm -rf "$clone_dir"
    fi
    
    clone_url="http://gitops-admin:${GITEA_TOKEN}@${GITEA_URL#http://}/gitops-admin/${repo_name}.git"
    echo -e "${BLUE}Cloning from: $clone_url${NC}"
    git clone "$clone_url" "$clone_dir" && \
    echo -e "${GREEN}✓ Clone 成功到 $clone_dir${NC}" || \
    echo -e "${RED}Clone 失敗${NC}"
}

function view_edge_config() {
    echo -e "\n${BLUE}edge1-config repository 內容:${NC}"
    if [ ! -d "/home/ubuntu/repos/edge1-config" ]; then
        echo -e "${YELLOW}本地 repository 不存在，從遠端克隆...${NC}"
        cd /home/ubuntu/repos
        git clone "http://gitops-admin:${GITEA_TOKEN}@${GITEA_URL#http://}/gitops-admin/edge1-config.git"
    fi
    
    cd /home/ubuntu/repos/edge1-config
    echo -e "\n${GREEN}目錄結構:${NC}"
    tree -L 3 2>/dev/null || ls -la
    
    echo -e "\n${GREEN}最近的 commits:${NC}"
    git log --oneline -5
    
    echo -e "\n${GREEN}當前分支:${NC}"
    git branch -a
}

function push_update() {
    cd /home/ubuntu/repos/edge1-config
    
    echo -e "\n${BLUE}當前狀態:${NC}"
    git status
    
    read -p "要新增一個範例設定嗎？(y/n): " add_example
    if [[ "$add_example" =~ ^[Yy]$ ]]; then
        # 建立範例應用設定
        cat > apps/example-app.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  namespace: edge
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF
        
        git add apps/example-app.yaml
        git commit -m "Add example application deployment"
        git push && echo -e "${GREEN}✓ 推送成功${NC}" || echo -e "${RED}推送失敗${NC}"
    fi
}

# Main loop
while true; do
    show_menu
    
    case $choice in
        1) list_repos ;;
        2) create_repo ;;
        3) view_repo ;;
        4) create_user ;;
        5) list_users ;;
        6) clone_repo ;;
        7) view_edge_config ;;
        8) push_update ;;
        9) echo "Bye!"; exit 0 ;;
        *) echo -e "${RED}無效選擇${NC}" ;;
    esac
    
    echo ""
    read -p "按 Enter 繼續..."
done