# 根目錄清理計劃

**分析時間**: 2025-09-26
**當前檔案數**: 33 個檔案（不含目錄）
**總 Markdown 行數**: 8,732 行

---

## 📊 檔案分類分析

### 1. 核心文檔 (保留，需整理到 docs/)
- ✅ **README.md** (67 行) - 專案主README，保留在根目錄
- ✅ **CHANGELOG.md** (81 行) - 版本記錄，保留在根目錄
- ✅ **LICENSE** (11KB) - 授權文件，保留在根目錄

### 2. 新生成文檔 (保留)
- ✅ **PROJECT_COMPREHENSIVE_UNDERSTANDING.md** (2150 行) - 剛生成的完整理解
- ✅ **HOW_TO_USE.md** (682 行) - 剛生成的使用指南
- ✅ **ARCHITECTURE_SIMPLIFIED.md** (95 行) - 簡化架構

### 3. 架構文檔 (整併與移動)
- 🔄 **SYSTEM_ARCHITECTURE_HLA.md** (693 行) → 移至 docs/architecture/
- 🔄 **VM1_INTEGRATED_ARCHITECTURE.md** (843 行) → 移至 docs/architecture/
- 🔄 **THREE_VM_INTEGRATION_PLAN.md** (469 行) → 移至 docs/architecture/
- ⚠️ **ULTIMATE_DEVELOPMENT_PLAN.md** (1485 行) → 過時，移至 docs/archive/

### 4. 操作指南 (整併重複內容)
- ❌ **ACCESS_GUIDE.md** (108 行) - 與 COMPLETE_ACCESS_GUIDE.md 重複
- 🔄 **COMPLETE_ACCESS_GUIDE.md** (200 行) → 整併進 HOW_TO_USE.md
- 🔄 **MONITORING_GUIDE.md** (141 行) → 整併進 HOW_TO_USE.md
- ✅ **TROUBLESHOOTING.md** (201 行) → 移至 docs/operations/

### 5. 部署與測試記錄 (過時，歸檔)
- ⚠️ **SERVICES_DEPLOYMENT_RECORD.md** (182 行) - 2025-09-25 記錄，已過時
- ⚠️ **TEST_REPORT.md** (140 行) - 測試報告，已過時
- ⚠️ **FINAL_DEEP_ANALYSIS.md** (248 行) - 分析報告，已過時
- ⚠️ **GAP_CLOSURE_SUMMARY.md** (153 行) - 完成報告，已過時

### 6. Summit Demo 文檔 (移至 docs/summit-demo/)
- 🔄 **SUMMIT_DEMO_GUIDE.md** (312 行)
- 🔄 **SUMMIT_DEMO_RUNBOOK.md** (316 行)

### 7. 配置文件 (保留)
- ✅ **.gitignore** (1710 bytes)
- ✅ **.yamllint.yml** (193 bytes)
- ✅ **Makefile** (1696 bytes)
- ✅ **Makefile.summit** (6988 bytes)
- ✅ **CLAUDE.md** (129 行) - Claude 指引，但應在 .gitignore 中

### 8. 腳本與測試檔案 (移至對應目錄)
- 🔄 **MONITOR_STATUS.sh** → scripts/
- 🔄 **START_VISUALIZATION.sh** → scripts/
- 🔄 **TEST_MONITOR.sh** → scripts/
- 🔄 **test-cr-sample1.yaml** → tests/fixtures/
- 🔄 **test-cr-sample2.yaml** → tests/fixtures/
- 🔄 **test-cr-sample3.yaml** → tests/fixtures/

### 9. 網路配置 (移至 docs/)
- 🔄 **AUTHORITATIVE_NETWORK_CONFIG.md** (37 行) → docs/network/

### 10. 測試產出 (應被 .gitignore)
- ❌ **.coverage** (53KB) - pytest 覆蓋率報告，應刪除

---

## 🎯 清理策略

### A. 立即刪除 (重複/過時)
```
❌ ACCESS_GUIDE.md (被 COMPLETE_ACCESS_GUIDE.md 取代)
❌ .coverage (測試產出)
```

### B. 移至 docs/archive/ (歷史記錄)
```
⚠️ SERVICES_DEPLOYMENT_RECORD.md
⚠️ TEST_REPORT.md
⚠️ FINAL_DEEP_ANALYSIS.md
⚠️ GAP_CLOSURE_SUMMARY.md
⚠️ ULTIMATE_DEVELOPMENT_PLAN.md
```

### C. 移至 docs/architecture/
```
🔄 SYSTEM_ARCHITECTURE_HLA.md
🔄 VM1_INTEGRATED_ARCHITECTURE.md
🔄 THREE_VM_INTEGRATION_PLAN.md
```

### D. 移至 docs/operations/
```
🔄 TROUBLESHOOTING.md
```

### E. 移至 docs/summit-demo/
```
🔄 SUMMIT_DEMO_GUIDE.md (已存在，檢查重複)
🔄 SUMMIT_DEMO_RUNBOOK.md (已存在，檢查重複)
```

### F. 移至 docs/network/
```
🔄 AUTHORITATIVE_NETWORK_CONFIG.md
```

### G. 移至 scripts/
```
🔄 MONITOR_STATUS.sh
🔄 START_VISUALIZATION.sh
🔄 TEST_MONITOR.sh
```

### H. 移至 tests/fixtures/
```
🔄 test-cr-sample*.yaml
```

### I. 整併進 HOW_TO_USE.md
```
🔄 COMPLETE_ACCESS_GUIDE.md (整併內容後刪除)
🔄 MONITORING_GUIDE.md (整併內容後刪除)
```

---

## 📋 最終根目錄結構

### 保留檔案 (8個)
```
nephio-intent-to-o2-demo/
├── .gitignore
├── .yamllint.yml
├── ARCHITECTURE_SIMPLIFIED.md       ← 簡化架構總覽
├── CHANGELOG.md                     ← 版本記錄
├── HOW_TO_USE.md                    ← 使用指南 (新)
├── LICENSE
├── Makefile
├── Makefile.summit
├── PROJECT_COMPREHENSIVE_UNDERSTANDING.md  ← 完整理解 (新)
└── README.md                        ← 專案入口
```

### 移除的混亂 (25個檔案)
- 刪除: 2 個
- 歸檔: 5 個
- 移至子目錄: 18 個

---

## ✅ 清理後的優勢

1. **根目錄清爽**: 從 33 個減少到 10 個檔案
2. **結構清晰**: 所有文檔分類存放
3. **避免重複**: 整併重複內容
4. **保留歷史**: 過時文檔歸檔而非刪除
5. **易於維護**: 新手一眼看懂專案結構

---

## ⚠️ 注意事項

1. **檢查內部連結**: 移動檔案後需更新 markdown 內部連結
2. **更新 README.md**: 需反映新的檔案結構
3. **保留 CLAUDE.md**: 雖然在 .gitignore 中，但需保留給 Claude
4. **測試腳本**: 移動腳本後需測試路徑是否正確
5. **Git 歷史**: 使用 `git mv` 保留檔案歷史

---

## 🔄 執行順序

1. 建立目標目錄
2. 使用 `git mv` 移動檔案
3. 刪除過時檔案
4. 整併重複內容
5. 更新 README.md
6. 更新內部連結
7. 提交變更
8. 驗證系統運作

---

**準備執行清理！**