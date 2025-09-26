# IEEE ICC 2026 投稿時程規劃
# Intent-Driven O-RAN Network Orchestration Paper

**創建日期：** 2025年9月26日
**投稿截止：** 2026年1月（具體日期待確認）
**總時程：** 14週（2025/09/26 - 2026/01/15）
**當前狀態：** Week 0 - 準備階段完成 ✅

---

## 📊 時程總覽

```
Sept 2025          Oct 2025           Nov 2025           Dec 2025          Jan 2026
   |                 |                  |                  |                 |
   |--- Week 1-2 ----|--- Week 3-4 ----|--- Week 5-8 ----|-- Week 9-10 ---|-- Week 11-12 --|-- Week 13-14 --|
   |  圖表+校對      |   補充材料       |   內部審查       |   外部審閱      |   最終修訂      |   Buffer       | 投稿
   └─────────────────┴─────────────────┴─────────────────┴────────────────┴────────────────┴───────────────┴──────>
```

---

## Week 0：準備階段（2025/09/26 完成）✅

### 已完成項目
- [x] 更新 Related Work section（MAESTRO, MantaRay, Hermes, Tech Mahindra LLM）
- [x] 重寫對比表（Table I）加入 2025 最新系統
- [x] 更新標準引用（3GPP TS 28.312 V18.8.0, TR294A）
- [x] 強化 Abstract 和 Introduction 突出創新性
- [x] 創建 Rebuttal Materials 文件（67頁）
- [x] 確認投稿時程規劃

### 產出文件
- `IEEE_PAPER_2025_ANONYMOUS.md` - 主論文（已更新）
- `REBUTTAL_MATERIALS_ICC2026.md` - 審稿回應材料
- `ICC2026_SUBMISSION_TIMELINE.md` - 本時程文件

---

## Week 1-2：圖表製作 + 最終校對（2025/09/30 - 2025/10/13）

### 目標
完成所有圖表製作並進行第一輪校對

### Week 1（2025/09/30 - 2025/10/06）

#### 任務清單
- [ ] **Figure 1: System Architecture Overview**
  - [ ] 繪製四層架構圖（UI Layer, Intent Layer, Orchestration Layer, Infrastructure Layer）
  - [ ] 使用工具：draw.io / TikZ / PlantUML
  - [ ] 高解析度輸出（300 DPI）
  - [ ] 配色符合 IEEE 規範（黑白友好）

- [ ] **Figure 2: Network Topology Diagram**
  - [ ] 繪製 VM-1/VM-2/VM-4 拓撲
  - [ ] 標註 IP 地址和端口（匿名處理）
  - [ ] 顯示 service endpoints 連接

- [ ] **Figure 3: Data Flow Diagram**
  - [ ] 繪製 intent-to-deployment pipeline（7個階段）
  - [ ] 包含 feedback loops（SLO validation, rollback）
  - [ ] 使用泳道圖或序列圖

- [ ] **Figure 4: Deployment Success Rate Over Time**
  - [ ] 使用實際數據繪製（30天數據）
  - [ ] 包含趨勢線和置信區間
  - [ ] 工具：Python matplotlib / R ggplot2

#### 交付物
- [ ] 4 個高解析度圖表檔案（PNG + SVG/PDF）
- [ ] 圖表原始檔（.drawio / .tex / .py）
- [ ] 圖表說明文字（Caption）草稿

---

### Week 2（2025/10/07 - 2025/10/13）

#### 任務清單
- [ ] **Additional Tables and Figures**
  - [ ] Table II: SLO Thresholds and Validation Results（已有數據，需格式化）
  - [ ] Table III: Intent Processing Latency Analysis（已有數據）
  - [ ] Table IV: GitOps Performance Metrics（已有數據）
  - [ ] Table V: Fault Injection Test Results（已有數據）
  - [ ] Table VI: Comparative Performance Analysis（已有數據）

- [ ] **文法與格式校對**
  - [ ] 使用 Grammarly / LanguageTool 進行語法檢查
  - [ ] 檢查所有縮寫首次出現時是否有全稱（LLM, O-RAN, etc.）
  - [ ] 統一用語（例如：intent-driven vs. intent driven）
  - [ ] 檢查引用格式一致性（IEEE style）
  - [ ] 檢查圖表和表格引用完整性

- [ ] **數字和統計數據一致性檢查**
  - [ ] 驗證 Abstract 中的數字與 Results 章節一致
  - [ ] 檢查所有置信區間（95% CI）計算正確
  - [ ] 驗證 p-values 和 effect sizes 一致

#### 檢查清單
- [ ] 所有圖表已插入論文中
- [ ] 所有表格格式符合 IEEE 規範
- [ ] 文法錯誤 < 5 個
- [ ] 引用格式 100% 正確
- [ ] 數字一致性 100% 驗證

#### 交付物
- [ ] 完整論文草稿 v1.0（含所有圖表）
- [ ] 校對報告（錯誤清單）
- [ ] 圖表索引文件

---

## Week 3-4：補充材料準備（2025/10/14 - 2025/10/27）

### 目標
準備投稿所需的所有補充材料

### Week 3（2025/10/14 - 2025/10/20）

#### 任務清單
- [ ] **Source Code Repository 準備**
  - [ ] 清理 GitHub repository（移除敏感信息）
  - [ ] 撰寫完整 README.md（安裝、部署、測試步驟）
  - [ ] 創建 INSTALL.md（詳細安裝指南）
  - [ ] 創建 QUICKSTART.md（快速開始指南）
  - [ ] 添加 LICENSE 文件（選擇開源協議）
  - [ ] 創建 CONTRIBUTING.md（貢獻指南）

- [ ] **Deployment Automation Scripts**
  - [ ] 整理所有部署腳本到 `scripts/` 目錄
  - [ ] 撰寫腳本說明文檔
  - [ ] 創建 Docker Compose / Kubernetes manifests
  - [ ] 測試一鍵部署流程

- [ ] **Test Datasets**
  - [ ] 準備 1,000 個 intent 測試樣本（匿名化）
  - [ ] 創建 dataset README（格式說明）
  - [ ] 包含不同類型 intent（eMBB, URLLC, mMTC）
  - [ ] 提供 JSON Schema validation 檔案

#### 交付物
- [ ] GitHub repository URL（公開或匿名鏈接）
- [ ] 部署腳本包（.tar.gz）
- [ ] 測試數據集（.zip）
- [ ] 文檔網站（GitHub Pages / Read the Docs）

---

### Week 4（2025/10/21 - 2025/10/27）

#### 任務清單
- [ ] **Performance Measurement Tools**
  - [ ] 整理 Prometheus queries 和 Grafana dashboards
  - [ ] 提供性能測試腳本（load testing, chaos engineering）
  - [ ] 創建測試結果分析 Jupyter notebooks
  - [ ] 包含原始實驗數據（30天完整數據）

- [ ] **Statistical Analysis Materials**
  - [ ] Jupyter Notebook（統計分析代碼）
  - [ ] R scripts（如果有使用 R）
  - [ ] 原始數據 CSV 檔案
  - [ ] 統計檢定結果報告（t-test, ANOVA, etc.）

- [ ] **Standards Compliance Test Reports**
  - [ ] TMF921 compliance test results（JSON/XML）
  - [ ] 3GPP TS 28.312 compliance test results
  - [ ] O-RAN O2IMS compliance test results
  - [ ] Automated test suite（pytest / JUnit）

- [ ] **Video Demonstration**
  - [ ] 錄製系統操作演示（5-10分鐘）
  - [ ] 包含：Intent 輸入 → 部署 → SLO 驗證 → Rollback
  - [ ] 使用 OBS Studio / QuickTime 錄製
  - [ ] 上傳到 YouTube（unlisted）或自託管

#### 交付物
- [ ] Performance tools package（.zip）
- [ ] Statistical analysis notebooks（.ipynb）
- [ ] Compliance test reports（.pdf）
- [ ] Demo video（YouTube link + .mp4）

#### 檢查清單
- [ ] 所有補充材料可獨立運行
- [ ] 文檔完整且易於理解
- [ ] 無敏感信息洩露（IP, passwords, etc.）
- [ ] 測試數據匿名化處理

---

## Week 5-8：內部審查 + 修改（2025/10/28 - 2025/11/24）

### 目標
進行內部團隊審查並根據反饋修改

### Week 5（2025/10/28 - 2025/11/03）

#### 任務清單
- [ ] **內部審查第一輪**
  - [ ] 分發論文給團隊成員（3-5人）
  - [ ] 設定審查截止日期（11/03）
  - [ ] 提供審查模板（Technical, Writing, Novelty, Impact）
  - [ ] 收集審查意見

- [ ] **審查重點**
  - [ ] 技術準確性（架構、算法、實驗）
  - [ ] 創新性論述（是否充分突出）
  - [ ] 寫作清晰度（邏輯、流暢性）
  - [ ] 圖表質量（可讀性、美觀性）
  - [ ] 引用完整性（是否遺漏重要文獻）

#### 交付物
- [ ] 審查意見匯總文檔
- [ ] 修改優先級清單（Critical / Important / Nice-to-have）

---

### Week 6（2025/11/04 - 2025/11/10）

#### 任務清單
- [ ] **Critical Issues 修改**
  - [ ] 修復技術錯誤（如有）
  - [ ] 改進創新性論述（如不足）
  - [ ] 修正實驗設計缺陷（如有）
  - [ ] 更新圖表（如不清晰）

- [ ] **Writing Improvements**
  - [ ] 改善段落結構和邏輯流
  - [ ] 增強 transition sentences
  - [ ] 簡化複雜句子
  - [ ] 強化 key messages

#### 交付物
- [ ] 修改後論文 v1.1
- [ ] 修改說明文檔（change log）

---

### Week 7（2025/11/11 - 2025/11/17）

#### 任務清單
- [ ] **內部審查第二輪**
  - [ ] 分發修改後論文 v1.1
  - [ ] 聚焦於修改部分的驗證
  - [ ] 檢查是否引入新問題

- [ ] **Important Issues 修改**
  - [ ] 改進非關鍵但重要的部分
  - [ ] 優化圖表和表格
  - [ ] 增強相關工作對比
  - [ ] 補充實驗細節

#### 交付物
- [ ] 修改後論文 v1.2
- [ ] 修改追蹤表（issue tracking）

---

### Week 8（2025/11/18 - 2025/11/24）

#### 任務清單
- [ ] **Nice-to-have 修改**
  - [ ] 潤飾語言表達
  - [ ] 優化 Abstract 吸引力
  - [ ] 改進 Introduction hook
  - [ ] 增強 Conclusion impact

- [ ] **最終內部驗收**
  - [ ] 全文通讀（端到端）
  - [ ] 檢查流暢性和一致性
  - [ ] 驗證所有修改已完成
  - [ ] 確認可以送外部審閱

#### 檢查清單
- [ ] 所有 Critical Issues 已解決
- [ ] 所有 Important Issues 已解決
- [ ] 論文邏輯完整且流暢
- [ ] 圖表清晰且專業
- [ ] 團隊達成一致可送外審

#### 交付物
- [ ] 內部審查完成版 v1.3
- [ ] 外審準備清單

---

## Week 9-10：外部專家審閱（2025/11/25 - 2025/12/08）

### 目標
邀請外部專家進行獨立審閱

### Week 9（2025/11/25 - 2025/12/01）

#### 任務清單
- [ ] **外部審閱者邀請**
  - [ ] 識別 3-5 位外部專家
    - [ ] 領域專家（O-RAN / Intent networking）
    - [ ] LLM 應用專家
    - [ ] 統計/實驗方法專家
    - [ ] 英文 native speaker（寫作質量）
  - [ ] 發送邀請郵件（附論文和審查模板）
  - [ ] 設定審查截止日期（12/08）
  - [ ] 提供報酬/致謝說明

- [ ] **審查指南準備**
  - [ ] 提供審查問題清單
  - [ ] 強調需要關注的部分（創新性、嚴謹性）
  - [ ] 提供 rebuttal materials 供參考

#### 交付物
- [ ] 外審邀請記錄
- [ ] 審查指南文檔

---

### Week 10（2025/12/02 - 2025/12/08）

#### 任務清單
- [ ] **追蹤審查進度**
  - [ ] 提醒審閱者截止日期
  - [ ] 回答審閱者問題
  - [ ] 收集審查意見

- [ ] **審查意見初步分析**
  - [ ] 彙整所有外部意見
  - [ ] 分類問題（Technical / Writing / Clarity）
  - [ ] 評估修改工作量
  - [ ] 制定回應策略

#### 審查重點問題
- [ ] 創新性是否充分突出？（vs. MAESTRO, MantaRay, etc.）
- [ ] 實驗設計是否嚴謹？（統計方法、樣本量）
- [ ] 相關工作對比是否公平？
- [ ] 生產環境驗證是否可信？
- [ ] 局限性討論是否充分？
- [ ] 寫作是否清晰易懂？

#### 交付物
- [ ] 外審意見匯總報告
- [ ] 修改計劃（優先級排序）
- [ ] 回應草稿（預演 rebuttal）

---

## Week 11-12：最終修訂（2025/12/09 - 2025/12/22）

### 目標
根據外審意見進行最終修訂

### Week 11（2025/12/09 - 2025/12/15）

#### 任務清單
- [ ] **Major Revisions**
  - [ ] 解決所有 critical comments
  - [ ] 改進技術論述（如有問題）
  - [ ] 增強創新性說明
  - [ ] 補充實驗數據（如需要）
  - [ ] 改進圖表（如不清晰）

- [ ] **Writing Polish**
  - [ ] 根據 native speaker 意見潤飾
  - [ ] 改善 Abstract 和 Introduction
  - [ ] 強化 Related Work 對比
  - [ ] 優化 Discussion 洞察

#### 交付物
- [ ] 修改後論文 v2.0
- [ ] 修改對照表（old vs. new）

---

### Week 12（2025/12/16 - 2025/12/22）

#### 任務清單
- [ ] **Minor Revisions**
  - [ ] 解決所有 minor comments
  - [ ] 最終語法和拼寫檢查
  - [ ] 格式統一性檢查
  - [ ] 引用格式最終確認

- [ ] **轉換為 IEEE 格式**
  - [ ] 下載 IEEE ICC 2026 LaTeX template
  - [ ] 轉換 Markdown → LaTeX
  - [ ] 插入所有圖表（.eps or .pdf）
  - [ ] 調整版面和排版
  - [ ] 檢查頁數限制（IEEE ICC 通常 6-8 頁）

- [ ] **最終驗證**
  - [ ] 使用 IEEE PDF eXpress 檢查 PDF
  - [ ] 驗證 metadata（title, authors, keywords）
  - [ ] 檢查 double-blind 要求（匿名化）
  - [ ] 確認補充材料鏈接有效

#### 檢查清單（最終投稿前）
- [ ] 所有外審意見已處理
- [ ] IEEE LaTeX 格式正確
- [ ] PDF 符合 IEEE 規範
- [ ] 頁數在限制內
- [ ] 圖表清晰（300 DPI）
- [ ] 引用格式正確（IEEE style）
- [ ] Double-blind 匿名化完成
- [ ] 補充材料已上傳並可訪問
- [ ] 所有作者信息準備好（EDAS 系統）

#### 交付物
- [ ] 最終論文 v2.1（LaTeX source + PDF）
- [ ] 補充材料包（完整打包）
- [ ] 投稿清單文檔

---

## Week 13-14：Buffer + 預印本發佈（2025/12/23 - 2026/01/05）

### 目標
緩衝時間處理意外問題並發佈預印本

### Week 13（2025/12/23 - 2025/12/29）

#### 任務清單
- [ ] **最終 Buffer 週**
  - [ ] 處理任何最後一刻的問題
  - [ ] 與共同作者最終確認
  - [ ] 準備 cover letter（如需要）
  - [ ] 測試投稿系統（EDAS）

- [ ] **arXiv 預印本準備**
  - [ ] 創建 arXiv 版本（non-anonymous）
  - [ ] 撰寫 arXiv abstract
  - [ ] 選擇分類（cs.NI, cs.AI）
  - [ ] 準備 arXiv metadata

#### 注意事項
- 聖誕假期（12/25），團隊可能不在線
- 確保關鍵文件有備份

---

### Week 14（2025/12/30 - 2026/01/05）

#### 任務清單
- [ ] **預印本發佈**
  - [ ] 在 arXiv.org 提交預印本
  - [ ] 獲得 arXiv ID（例如：arXiv:2501.xxxxx）
  - [ ] 在論文中引用 arXiv 版本（如允許）
  - [ ] 社交媒體宣傳（Twitter, LinkedIn）

- [ ] **最終準備**
  - [ ] 再次檢查所有投稿材料
  - [ ] 確認投稿截止日期和時區
  - [ ] 準備投稿當天的時間

#### 投稿材料最終檢查清單
- [ ] 論文 PDF（IEEE 格式，double-blind）
- [ ] LaTeX source files（如需要）
- [ ] 補充材料 URL（GitHub, Zenodo）
- [ ] Cover letter（如需要）
- [ ] Author information（EDAS）
- [ ] Conflict of interest statements
- [ ] Copyright form（如需要預填）

#### 交付物
- [ ] arXiv 預印本 URL
- [ ] 投稿確認郵件
- [ ] 投稿 tracking number

---

## 2026年1月：正式投稿（2026/01/06 - 2026/01/15）

### 投稿週（2026/01/06 - 2026/01/12）

#### 任務清單
- [ ] **確認投稿系統開放**
  - [ ] 登入 EDAS / HotCRP 系統
  - [ ] 確認 IEEE ICC 2026 track 開放
  - [ ] 檢查投稿要求（可能有更新）

- [ ] **正式投稿**
  - [ ] 上傳論文 PDF
  - [ ] 上傳 LaTeX source（如需要）
  - [ ] 填寫 metadata（title, abstract, keywords）
  - [ ] 選擇 track（Network Automation and Orchestration）
  - [ ] 提供補充材料 URL
  - [ ] 提交作者信息
  - [ ] 聲明 conflicts of interest
  - [ ] 最終確認並提交

- [ ] **投稿後**
  - [ ] 保存投稿確認郵件
  - [ ] 記錄 paper ID
  - [ ] 通知所有共同作者
  - [ ] 更新個人網站/CV

#### 投稿當天檢查清單
- [ ] 穩定的網絡連接
- [ ] 所有文件已準備好（避免最後一刻上傳問題）
- [ ] 至少在截止日期前 24 小時提交（避免系統擁堵）
- [ ] 確認時區（ICC 截止時間通常是 UTC 或某個特定時區）

---

### 後續追蹤（2026/01/13 - 審稿結果）

#### 任務清單
- [ ] **追蹤投稿狀態**
  - [ ] 定期檢查 EDAS 系統
  - [ ] 確認論文進入審稿流程
  - [ ] 記錄審稿里程碑日期

- [ ] **準備審稿回應**
  - [ ] 複習 rebuttal materials
  - [ ] 準備 revision 計劃
  - [ ] 預留時間進行 major/minor revision

#### 預期時間線（ICC 2026）
- **2026/01**：投稿截止
- **2026/02-03**：審稿進行中
- **2026/04**：審稿結果通知（Accept / Revise / Reject）
- **2026/05**：Camera-ready 截止（如 accepted）
- **2026/06**：IEEE ICC 2026 會議（地點待定）

---

## 📋 總體檢查清單

### 論文內容
- [x] Abstract 完整且吸引人
- [x] Introduction 明確問題和貢獻
- [x] Related Work 全面且最新（2025 系統）
- [x] System Architecture 清晰
- [ ] Implementation Details 充分
- [ ] Experimental Results 嚴謹（統計驗證）
- [ ] Discussion 有洞察
- [ ] Conclusion 有力
- [x] References 完整（IEEE 格式）

### 圖表和表格
- [ ] Figure 1: Architecture Overview
- [ ] Figure 2: Network Topology
- [ ] Figure 3: Data Flow Diagram
- [ ] Figure 4: Performance Over Time
- [ ] Table I: System Comparison
- [ ] Table II: SLO Validation
- [ ] Table III: Latency Analysis
- [ ] Table IV: GitOps Metrics
- [ ] Table V: Fault Injection Results
- [ ] Table VI: Comparative Analysis

### 補充材料
- [ ] GitHub repository（公開）
- [ ] Deployment scripts
- [ ] Test datasets（1,000 intents）
- [ ] Performance measurement tools
- [ ] Statistical analysis notebooks
- [ ] Compliance test reports
- [ ] Demo video

### 格式和規範
- [ ] IEEE ICC LaTeX template
- [ ] Double-blind anonymization
- [ ] Page limit compliance（6-8頁）
- [ ] Figure resolution（300 DPI）
- [ ] Reference format（IEEE style）
- [ ] PDF/A compliance（IEEE PDF eXpress）

### 審查和驗證
- [ ] Internal review (3-5 people)
- [ ] External expert review (3-5 people)
- [ ] Grammar and spell check
- [ ] Technical accuracy verification
- [ ] Statistical validation
- [ ] Reproducibility check

---

## 🚨 風險管理

### 潛在風險
1. **時程延遲**
   - 緩解：每階段預留 buffer，提前完成關鍵任務
   - 應急：可壓縮 Week 13-14（但不建議）

2. **外審者不回覆**
   - 緩解：邀請 5-7 位（預期 3-5 位回覆）
   - 應急：如少於 3 位，快速邀請備選專家

3. **技術問題（圖表、LaTeX）**
   - 緩解：提前測試工具和模板
   - 應急：尋求專業協助（設計師、LaTeX 專家）

4. **Major revisions 需求**
   - 緩解：內部審查嚴格把關
   - 應急：Week 11-12 可加班處理

5. **投稿系統問題**
   - 緩解：提前 48 小時投稿
   - 應急：聯繫會議組織者延期（極少成功）

### 關鍵里程碑
- **2025/10/13**：圖表和校對完成（Go/No-Go decision 1）
- **2025/10/27**：補充材料準備完成（Go/No-Go decision 2）
- **2025/11/24**：內部審查完成（Go/No-Go decision 3）
- **2025/12/08**：外部審查完成（Go/No-Go decision 4）
- **2025/12/22**：最終版本完成（Go/No-Go decision 5）
- **2026/01/12**：投稿完成（Milestone）

---

## 📞 聯絡人和責任分工

### 角色分配（待填寫）
- **項目負責人（PI）**：___________
  - 整體時程管理
  - 最終決策

- **第一作者**：___________
  - 論文撰寫和修改
  - 實驗驗證

- **共同作者 1**：___________
  - 系統實現
  - 補充材料準備

- **共同作者 2**：___________
  - 統計分析
  - 圖表製作

- **審查協調人**：___________
  - 內外部審查組織
  - 意見彙整

---

## 📊 進度追蹤

### 週報格式
每週五更新進度：

```
Week X Progress Report (YYYY/MM/DD)

Completed:
- [x] Task 1
- [x] Task 2

In Progress:
- [ ] Task 3 (50% done, expected completion: MM/DD)

Blocked:
- [ ] Task 4 (reason: xxxx, need help: xxxx)

Next Week Plan:
- [ ] Task 5
- [ ] Task 6

Risks:
- Risk description and mitigation plan
```

### 進度儀表板（建議使用 Trello / Notion / GitHub Projects）
- **To Do**：待開始的任務
- **In Progress**：進行中的任務
- **Review**：待審查的產出
- **Done**：已完成的任務

---

## 📚 參考資源

### IEEE ICC 2026 官方信息
- **官網**：（待更新，2025年底公佈）
- **Call for Papers**：（待發布）
- **投稿系統**：EDAS（https://edas.info）
- **Submission Guidelines**：（待確認）

### 工具和模板
- **LaTeX Template**：IEEE conference template（overleaf.com）
- **Drawing Tools**：draw.io, TikZ, PlantUML
- **Statistical Analysis**：Python (matplotlib, seaborn), R (ggplot2)
- **PDF Check**：IEEE PDF eXpress
- **Grammar Check**：Grammarly, LanguageTool
- **Version Control**：Git（本地 + GitHub backup）

### 相關會議和預印本
- **arXiv.org**：cs.NI, cs.AI categories
- **IEEE Xplore**：搜尋相關已發表論文
- **TechRxiv**：電信領域預印本平台

---

## 📝 備註和更新日誌

### 2025/09/26 - Initial Version
- 創建完整 14 週投稿時程
- 明確每週任務和交付物
- 建立檢查清單和風險管理計劃

### 後續更新（待補充）
- 確認 IEEE ICC 2026 截止日期後更新具體日期
- 根據實際進度調整時程
- 記錄實際完成日期和經驗教訓

---

**最後更新：** 2025年9月26日
**下次審查：** 2025年10月06日（Week 1 結束）
**文件維護者：** [待填寫]

---

*本時程規劃為動態文件，將根據實際進度和新需求持續更新。*