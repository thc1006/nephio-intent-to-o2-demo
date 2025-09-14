#!/bin/bash
echo "🚀 啟動Gitea GitOps服務..."

# 檢查是否已有容器
if docker ps -a | grep gitea > /dev/null; then
    echo "移除舊的Gitea容器..."
    docker stop gitea 2>/dev/null
    docker rm gitea 2>/dev/null
fi

# 啟動Gitea
docker run -d \
  --name gitea \
  -p 8888:3000 \
  -p 2222:22 \
  -v /var/lib/gitea:/data \
  -v /etc/timezone:/etc/timezone:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --restart always \
  gitea/gitea:latest

echo "等待Gitea啟動..."
sleep 10

# 檢查狀態
if curl -s http://localhost:8888 > /dev/null; then
    echo "✅ Gitea成功啟動在 http://172.16.0.78:8888"
    echo "預設登入: admin1 / admin123"
else
    echo "❌ Gitea啟動失敗，請檢查日誌"
    docker logs gitea
fi
