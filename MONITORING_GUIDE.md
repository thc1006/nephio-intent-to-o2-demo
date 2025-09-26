# 🎯 Intent-to-O2 視覺化監控指南

## ✅ 服務狀態確認

所有服務已正常運行：
- **LLM Adapter (VM-1)**: ✅ Online at 172.16.0.78:8888
- **O2IMS Edge1 (VM-2)**: ✅ Online at 172.16.4.45:31280
- **O2IMS Edge2 (VM-4)**: ✅ Online at 172.16.4.176:31280
- **Gitea Repository**: ✅ Online at localhost:8888

## 🚀 快速啟動監控

### 1. 即時監控儀表板
```bash
./scripts/visual_monitor.sh
```
顯示內容：
- 即時 Pipeline 流程圖
- 服務健康狀態（綠燈/紅燈）
- 當前部署活動
- SLO 指標
- 最近活動日誌

### 2. 啟動所有監控工具
```bash
./START_VISUALIZATION.sh
```
選項：
- **1** - 視覺化儀表板
- **2** - 詳細流程追蹤
- **3** - Web UI 介面
- **4** - 全部同時開啟

## 📊 視覺化流程說明

### Pipeline 流程圖
```
[User]
   ↓
[Web UI] → [LLM Adapter] ● Online
   ↓
[Intent Parser]
   ↓
[KRM Renderer] (Phase: Active)
   ↓
[GitOps]
  ├→ [Edge1] ✓ Synced
  └→ [Edge2] ✓ Synced
```

### 狀態指示器
- 🟢 **綠色圓點**: 服務正常
- 🔴 **紅色圓點**: 服務離線
- 🟡 **黃色圓點**: 同步中
- ✅ **綠色勾號**: 部署成功
- ⟳ **旋轉符號**: 處理中

## 🌐 Web UI 使用

### 訪問地址
- **LLM Adapter Web UI**: http://172.16.0.78:8888
- **Gitea Repository**: http://localhost:8888

### Web UI 功能
1. **輸入自然語言指令**
   - 例如: "Deploy eMBB service on edge1 with 100Mbps"

2. **即時查看處理狀態**
   - Natural Language → Intent → KRM → GitOps → O2IMS → SLO Gate

3. **監控部署進度**
   - 每個階段的狀態更新
   - 錯誤訊息即時顯示

## 📝 測試範例

### 1. 部署 eMBB 服務
```bash
# 透過腳本
./scripts/intent_from_llm.sh "Deploy eMBB slice in edge1 with 200Mbps DL"

# 或透過 Web UI
訪問 http://172.16.0.78:8888
輸入: "Deploy eMBB slice in edge1 with 200Mbps DL"
```

### 2. 監控部署狀態
```bash
# 查看即時日誌
tail -f artifacts/demo-llm/deployment.log

# 查看 GitOps 同步
kubectl get rootsync -n config-management-system

# 查看部署狀態
kubectl get deployments -A | grep intent
```

## 🔧 故障排除

### 如果服務顯示離線
```bash
# 重新啟動服務
./scripts/start_services.sh

# 檢查網路連接
ping -c 2 172.16.0.78   # VM-1
ping -c 2 172.16.4.45   # VM-2
ping -c 2 172.16.4.176  # VM-4
```

### 查看服務日誌
```bash
# LLM Adapter 日誌
ssh ubuntu@172.16.0.78 "tail -f ~/nephio-intent-to-o2-demo/llm-adapter/service.log"

# Gitea 日誌
docker logs gitea

# O2IMS 日誌
kubectl logs -n o2ims-system deployment/o2ims-controller
```

## 📈 效能指標

監控儀表板顯示的關鍵指標：
- **Intent Processing Time**: < 5s
- **Deployment Success Rate**: > 95%
- **SLO Achievement**: > 99%
- **System Availability**: 99.9%

## 💡 使用提示

1. **監控儀表板每 2 秒自動更新**
2. **按 Ctrl+C 退出監控**
3. **所有服務狀態會即時反映**
4. **錯誤會以紅色高亮顯示**
5. **成功訊息顯示為綠色**

---

現在你可以完整視覺化看到整個 Intent-to-O2 流程的運行狀況！