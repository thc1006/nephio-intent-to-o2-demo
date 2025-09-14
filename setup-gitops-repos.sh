#!/bin/bash
# 設置 GitOps Repositories
# 基於 AUTHORITATIVE_NETWORK_CONFIG.md

echo "🚀 設置 GitOps Repositories..."

# Gitea API token
TOKEN="1b5ea0b27add59e71980ba3f7612a3bfed1487b7"
GITEA_URL="http://localhost:8888"

# 創建 edge1-config repository
echo "創建 edge1-config repository..."
curl -X POST "$GITEA_URL/api/v1/user/repos" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "edge1-config",
    "description": "GitOps configuration for Edge1 cluster",
    "private": false,
    "auto_init": true
  }' 2>/dev/null | jq -r '.name' || echo "Repository 可能已存在"

# 創建 edge2-config repository
echo "創建 edge2-config repository..."
curl -X POST "$GITEA_URL/api/v1/user/repos" \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "edge2-config",
    "description": "GitOps configuration for Edge2 cluster",
    "private": false,
    "auto_init": true
  }' 2>/dev/null | jq -r '.name' || echo "Repository 可能已存在"

# 初始化 edge1-config
echo "初始化 edge1-config..."
if [ ! -d "/tmp/edge1-config" ]; then
    git clone http://admin1:admin123@localhost:8888/admin1/edge1-config.git /tmp/edge1-config 2>/dev/null || {
        mkdir -p /tmp/edge1-config
        cd /tmp/edge1-config
        git init
        git remote add origin http://admin1:admin123@localhost:8888/admin1/edge1-config.git
    }
fi

cd /tmp/edge1-config
cat > namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: edge1-workloads
  labels:
    site: edge1
    managed-by: gitops
EOF

git add namespace.yaml
git commit -m "Initial edge1 configuration" 2>/dev/null || echo "No changes to commit"
git push origin main 2>/dev/null || git push --set-upstream origin main

# 初始化 edge2-config
echo "初始化 edge2-config..."
if [ ! -d "/tmp/edge2-config" ]; then
    git clone http://admin1:admin123@localhost:8888/admin1/edge2-config.git /tmp/edge2-config 2>/dev/null || {
        mkdir -p /tmp/edge2-config
        cd /tmp/edge2-config
        git init
        git remote add origin http://admin1:admin123@localhost:8888/admin1/edge2-config.git
    }
fi

cd /tmp/edge2-config
mkdir -p edge2
cat > edge2/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: edge2-workloads
  labels:
    site: edge2
    managed-by: gitops
EOF

git add edge2/namespace.yaml
git commit -m "Initial edge2 configuration" 2>/dev/null || echo "No changes to commit"
git push origin main 2>/dev/null || git push --set-upstream origin main

echo ""
echo "✅ GitOps repositories 設置完成"
echo ""
echo "驗證："
echo "  Edge1: http://172.16.0.78:8888/admin1/edge1-config"
echo "  Edge2: http://172.16.0.78:8888/admin1/edge2-config"
echo ""
echo "下一步："
echo "1. 在 Edge1 (VM-2) 應用 RootSync："
echo "   kubectl apply -f vm-2/edge1-rootsync.yaml"
echo ""
echo "2. 在 Edge2 (VM-4) 創建並應用 RootSync"