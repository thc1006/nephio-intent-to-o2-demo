#!/bin/bash
# 啟動所有必要服務

echo "🚀 啟動 Intent-to-O2 服務"
echo "=========================="

# 1. 啟動 LLM Adapter (本地運行當作 VM-1 (Integrated))
echo "1. 啟動 LLM Adapter..."
cd /home/ubuntu/nephio-intent-to-o2-demo/llm-adapter
pkill -f "uvicorn main:app" 2>/dev/null
export CLAUDE_CLI=0
nohup uvicorn main:app --host 0.0.0.0 --port 8000 > service.log 2>&1 &
echo "   LLM Adapter PID: $!"
sleep 2

# 2. 檢查 Gitea (已在 port 8888)
echo "2. Gitea 狀態..."
if docker ps | grep -q gitea; then
    echo "   ✓ Gitea 運行中 (port 8888)"
else
    echo "   啟動 Gitea..."
    docker start gitea 2>/dev/null || docker run -d --name=gitea \
        -p 8888:3000 -p 2222:22 \
        -v gitea:/data \
        --restart always \
        gitea/gitea:latest
fi

# 3. 設置環境變量
echo "3. 設置環境變量..."
cat > /home/ubuntu/nephio-intent-to-o2-demo/scripts/env.sh << 'EOF'
export VM1_IP="172.16.0.78"
export VM2_IP="172.16.4.45"
export VM1_IP="localhost"  # LLM Adapter 在本地
export VM4_IP="172.16.4.176"
export LLM_ADAPTER_URL="http://localhost:8000"
export GITEA_URL="http://localhost:8888"
EOF

source /home/ubuntu/nephio-intent-to-o2-demo/scripts/env.sh

# 4. 驗證服務
echo ""
echo "🔍 驗證服務狀態:"
echo "=================="

# LLM Adapter
if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ LLM Adapter: Online (http://localhost:8000)"
else
    echo "❌ LLM Adapter: Offline"
fi

# Gitea
if curl -s http://localhost:8888 >/dev/null 2>&1; then
    echo "✅ Gitea: Online (http://localhost:8888)"
else
    echo "❌ Gitea: Offline"
fi

# Edge1 O2IMS
if curl -s http://172.16.4.45:31280/o2ims --max-time 2 >/dev/null 2>&1; then
    echo "✅ O2IMS Edge1: Online"
else
    echo "⚠️  O2IMS Edge1: Offline/Unreachable"
fi

# Edge2 O2IMS
if curl -s http://172.16.4.176:31280/o2ims --max-time 2 >/dev/null 2>&1; then
    echo "✅ O2IMS Edge2: Online"
else
    echo "⚠️  O2IMS Edge2: Offline/Unreachable"
fi

echo ""
echo "📋 快速指令:"
echo "- 查看 LLM Adapter 日誌: tail -f llm-adapter/service.log"
echo "- 查看監控面板: ./scripts/visual_monitor.sh"
echo "- 訪問 Web UI: http://localhost:8000"
echo "- 訪問 Gitea: http://localhost:8888"