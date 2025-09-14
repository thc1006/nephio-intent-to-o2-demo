# 🎯 Summit Demo 視覺化流程圖

## 演示架構總覽

```mermaid
graph TB
    subgraph "觀眾輸入"
        USER[("👥 觀眾<br/>自然語言需求")]
    end

    subgraph "VM-3: LLM 服務"
        WEBUI[("🌐 Web UI<br/>http://localhost:8888")]
        LLM[("🧠 Claude AI<br/>172.16.2.10:8888")]
        INTENT[("📋 TMF921 Intent<br/>JSON 格式")]
    end

    subgraph "VM-1: GitOps 編排器"
        COMPILER[("⚙️ Intent 編譯器<br/>Intent → KRM")]
        KPT[("📦 KPT 渲染<br/>產生 YAML")]
        GIT[("🔄 GitOps<br/>Config Sync")]
    end

    subgraph "Edge 站點"
        EDGE1[("📡 Edge1<br/>172.16.4.45")]
        EDGE2[("📡 Edge2<br/>172.16.0.89")]
    end

    subgraph "驗證與監控"
        SLO[("✅ SLO 檢查<br/>服務品質")]
        ROLLBACK[("🔄 自動回復<br/>< 30秒")]
    end

    USER -->|"透過 Web UI"| WEBUI
    WEBUI -->|"自然語言"| LLM
    LLM -->|"< 20ms"| INTENT
    INTENT -->|"自動轉換"| COMPILER
    COMPILER -->|"確定性渲染"| KPT
    KPT -->|"Git Push"| GIT
    GIT -->|"同步部署"| EDGE1
    GIT -->|"同步部署"| EDGE2
    EDGE1 -->|"監控"| SLO
    EDGE2 -->|"監控"| SLO
    SLO -->|"違規"| ROLLBACK
    ROLLBACK -->|"復原"| GIT

    style USER fill:#e1f5fe
    style WEBUI fill:#ffecb3
    style LLM fill:#fff3e0
    style INTENT fill:#f3e5f5
    style COMPILER fill:#e8f5e9
    style KPT fill:#e8f5e9
    style GIT fill:#e8f5e9
    style EDGE1 fill:#fff8e1
    style EDGE2 fill:#fff8e1
    style SLO fill:#e0f2f1
    style ROLLBACK fill:#ffebee
```

---

## 詳細步驟流程

```mermaid
sequenceDiagram
    participant 觀眾
    participant WebUI as VM-3 Web UI
    participant VM3_LLM as VM-3 LLM
    participant VM1_Orchestrator as VM-1 編排器
    participant GitOps
    participant Edge1
    participant Edge2
    participant SLO_Monitor as SLO 監控

    觀眾->>WebUI: 在瀏覽器輸入<br/>"部署 5G 高頻寬服務"
    WebUI->>VM3_LLM: 發送請求
    VM3_LLM->>VM3_LLM: AI 理解與分類
    VM3_LLM-->>WebUI: 顯示 Intent JSON
    WebUI-->>VM1_Orchestrator: TMF921 Intent

    VM1_Orchestrator->>VM1_Orchestrator: Intent → KRM 編譯
    VM1_Orchestrator->>VM1_Orchestrator: KPT 渲染 YAML
    VM1_Orchestrator->>GitOps: Git Commit & Push

    GitOps->>Edge1: 同步配置
    GitOps->>Edge2: 同步配置

    Edge1-->>SLO_Monitor: 回報狀態
    Edge2-->>SLO_Monitor: 回報狀態

    alt SLO 通過
        SLO_Monitor-->>觀眾: ✅ 部署成功
    else SLO 違規
        SLO_Monitor->>GitOps: 觸發回復
        GitOps->>Edge1: 復原配置
        GitOps->>Edge2: 復原配置
        GitOps-->>觀眾: ⚠️ 已自動回復
    end
```

---

## 10 步驟 Pipeline 流程

```mermaid
graph LR
    subgraph "準備階段"
        S1[1.檢查相依性]
        S2[2.設定工作區]
        S3[3.初始化狀態]
    end

    subgraph "Intent 生成"
        S4[4.驗證目標]
        S5[5.檢查 LLM]
        S6[6.生成 Intent]
    end

    subgraph "部署階段"
        S7[7.渲染 KRM]
        S8[8.GitOps 部署]
        S9[9.等待 O2IMS]
    end

    subgraph "驗證階段"
        S10[10.SLO 檢查]
    end

    S1 --> S2 --> S3
    S3 --> S4 --> S5 --> S6
    S6 --> S7 --> S8 --> S9
    S9 --> S10

    style S1 fill:#e3f2fd
    style S2 fill:#e3f2fd
    style S3 fill:#e3f2fd
    style S4 fill:#f3e5f5
    style S5 fill:#f3e5f5
    style S6 fill:#f3e5f5
    style S7 fill:#e8f5e9
    style S8 fill:#e8f5e9
    style S9 fill:#e8f5e9
    style S10 fill:#fff3e0
```

---

## 網路拓撲圖

```
                        ┌──────────────────┐
                        │   外部網路       │
                        │ 147.251.115.143  │
                        └────────┬─────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
        ┌───────────▼───────────┐ ┌──────────▼──────────┐
        │   VM-1 (GitOps)       │ │   VM-3 (LLM)       │
        │   172.16.0.78         │ │   172.16.2.10      │
        │                       │ │                    │
        │  • Kubernetes Master  │ │  • Claude AI API   │
        │  • Config Sync        │ │  • Intent Gen      │
        │  • Intent Compiler    │ │  • Port 8888       │
        └───────────┬───────────┘ └──────────┬──────────┘
                    │                         │
        ┌───────────┴───────────────────────┴───────────┐
        │              內部網路 172.16.x.x               │
        └───────────┬───────────────────────┬───────────┘
                    │                        │
        ┌───────────▼───────────┐ ┌─────────▼───────────┐
        │   VM-2 (Edge1)        │ │   VM-4 (Edge2)      │
        │   172.16.4.45         │ │   172.16.0.89       │
        │                       │ │                     │
        │  • Edge Cluster #1    │ │  • Edge Cluster #2  │
        │  • 5G Network Func    │ │  • 5G Network Func  │
        │  • O-RAN Components   │ │  • O-RAN Components │
        └───────────────────────┘ └─────────────────────┘
```

---

## 服務類型對照表

| 自然語言關鍵字 | 服務類型 | 英文名稱 | 特性 |
|--------------|---------|----------|------|
| 高頻寬、4K影片、串流 | eMBB | Enhanced Mobile Broadband | 100 Mbps, 50ms 延遲 |
| 超低延遲、自動駕駛、工廠 | URLLC | Ultra-Reliable Low Latency | 10 Mbps, 1ms 延遲 |
| IoT、感測器、大量裝置 | mMTC | Massive Machine Type Comm | 1 Mbps, 支援 50000 裝置 |

---

## 演示時間軸

```mermaid
gantt
    title Summit Demo 時間分配
    dateFormat mm:ss
    axisFormat %M:%S

    section 準備
    系統檢查           :00:00, 1m

    section Part 1
    自然語言測試       :01:00, 3m

    section Part 2
    單站點部署         :04:00, 5m

    section Part 3
    多站點部署         :09:00, 5m

    section Part 4
    SLO 驗證          :14:00, 3m

    section Part 5
    報告生成          :17:00, 2m

    section Q&A
    問答時間          :19:00, 1m
```

---

## 演示成功檢查點

✅ **演示前**
- [ ] SSH 可登入
- [ ] LLM 服務正常
- [ ] Kubernetes 運作中
- [ ] GitOps 已設定

✅ **演示中**
- [ ] 自然語言轉 Intent 成功
- [ ] KRM 渲染完成
- [ ] GitOps 同步成功
- [ ] SLO 檢查通過

✅ **演示後**
- [ ] 報告產生完成
- [ ] 所有服務仍正常

---

## 關鍵指令速查

```bash
# 建立 SSH 隧道（用於 Web UI）
ssh -L 8888:172.16.2.10:8888 ubuntu@147.251.115.143

# 開啟 Web UI
open http://localhost:8888/

# 快速健康檢查
curl -s http://172.16.2.10:8888/health | jq '.status'

# 中文 Intent 測試（命令列）
curl -X POST http://172.16.2.10:8888/generate_intent \
  -d '{"natural_language": "部署 5G 服務", "target_site": "edge1"}' | jq

# 執行完整演示
./scripts/demo_llm.sh --dry-run --target both --mode automated

# 檢查 SLO
./scripts/postcheck.sh --target edge1 --json-output | jq '.summary'

# 產生報告
./scripts/package_summit_demo.sh --full-bundle
```

---

**這份視覺化流程圖讓演示更容易理解！** 🚀