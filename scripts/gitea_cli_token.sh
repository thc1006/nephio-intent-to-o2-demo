#!/bin/bash
set -euo pipefail

# Source environment
source scripts/env.sh

echo "=== Gitea CLI Token 建立 ==="
echo "Gitea URL: $GITEA_URL"

# Method 1: Try with basic auth
echo "嘗試方法 1: Basic Auth API..."
TOKEN_NAME="edge-gitops-$(date +%s)"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    -u "gitea_admin:r8sA8CPHD9!bt6d" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${TOKEN_NAME}\",\"scopes\":[\"write:repository\",\"write:user\"]}" \
    "${GITEA_URL}/api/v1/users/gitea_admin/tokens" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    TOKEN=$(echo "$BODY" | jq -r '.sha1')
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        echo "✓ Token 建立成功！"
        echo ""
        echo "Token: $TOKEN"
        echo ""
        echo "# 儲存 token:"
        echo "export GITEA_TOKEN=\"$TOKEN\""
        echo ""
        echo "# 加入 env.sh:"
        echo "echo 'export GITEA_TOKEN=\"$TOKEN\"' >> scripts/env.sh"
        
        # Auto save
        echo "export GITEA_TOKEN=\"$TOKEN\"" >> scripts/env.sh
        echo "✓ Token 已自動儲存到 scripts/env.sh"
        
        exit 0
    fi
fi

echo "API 方法失敗 (HTTP $HTTP_CODE)"
echo "Response: $BODY"

# Method 2: Try to exec into pod
echo ""
echo "嘗試方法 2: 直接在 Gitea pod 內執行..."

POD_NAME=$(kubectl get pods -n gitea-system -l app=gitea -o jsonpath='{.items[0].metadata.name}')

if [ -n "$POD_NAME" ]; then
    echo "找到 Gitea pod: $POD_NAME"
    
    # Create token using gitea CLI inside pod
    TOKEN=$(kubectl exec -n gitea-system $POD_NAME -- \
        gitea admin user generate-access-token \
        --username gitea_admin \
        --token-name "${TOKEN_NAME}" \
        --scopes "write:repository,write:user" \
        2>/dev/null | grep -oP 'Access token was successfully created: \K.*' || true)
    
    if [ -n "$TOKEN" ]; then
        echo "✓ Token 建立成功！"
        echo ""
        echo "Token: $TOKEN"
        echo ""
        echo "export GITEA_TOKEN=\"$TOKEN\"" >> scripts/env.sh
        echo "✓ Token 已儲存到 scripts/env.sh"
        exit 0
    else
        echo "Pod 內建立失敗"
    fi
fi

echo ""
echo "=== 替代方案: SSH Tunnel ==="
echo "如果自動方法都失敗，請使用 SSH tunnel:"
echo ""
echo "1. 在你的筆電開新終端執行:"
echo "   ssh -L 8080:172.18.0.2:30924 ubuntu@172.16.0.78"
echo ""
echo "2. 在筆電瀏覽器訪問:"
echo "   http://localhost:8080"
echo ""
echo "3. 登入 (gitea_admin / r8sA8CPHD9!bt6d)"
echo ""
echo "4. 建立 token 後執行:"
echo "   export GITEA_TOKEN=\"你的token\""