#!/bin/bash
# 快速啟動視覺化監控系統

echo "🚀 啟動 Intent-to-O2 視覺化監控系統"
echo "================================="
echo

# 選項菜單
echo "選擇監控模式："
echo "1) 📊 即時儀表板 (自動刷新)"
echo "2) 🎮 互動式監控 (手動控制)"
echo "3) 📝 流程追蹤器 (日誌追蹤)"
echo "4) 🌐 Web UI (瀏覽器介面)"
echo "5) 🔍 完整監控 (全部開啟)"
echo
read -p "請選擇 [1-5]: " choice

case $choice in
    1)
        echo "啟動自動刷新儀表板..."
        ./scripts/visual_monitor.sh
        ;;
    2)
        echo "啟動互動式監控 (手動刷新)..."
        ./scripts/visual_monitor_interactive.sh
        ;;
    3)
        echo "啟動流程追蹤器..."
        chmod +x ./scripts/trace_flow.sh
        ./scripts/trace_flow.sh
        ;;
    4)
        echo "開啟 Web UI..."
        echo "請在瀏覽器訪問: http://localhost:8002"
        echo
        echo "在 Web UI 中你可以："
        echo "- 輸入自然語言指令"
        echo "- 即時查看 Pipeline 狀態"
        echo "- 監控部署進度"
        ;;
    5)
        echo "啟動完整監控系統..."
        # 開啟多個終端
        gnome-terminal --tab --title="Dashboard" -- bash -c "./scripts/visual_monitor.sh; bash" 2>/dev/null || \
        xterm -T "Dashboard" -e "./scripts/visual_monitor.sh" &
        
        gnome-terminal --tab --title="Flow Tracer" -- bash -c "./scripts/trace_flow.sh; bash" 2>/dev/null || \
        xterm -T "Flow Tracer" -e "./scripts/trace_flow.sh" &
        
        echo "✅ 監控系統已啟動"
        echo "Web UI: http://${VM1_IP:-Configure_VM1_IP}:8888"
        ;;
    *)
        echo "無效選項"
        exit 1
        ;;
esac