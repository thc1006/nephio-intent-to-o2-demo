# kpt-functions/expectation-to-krm 決策建議報告

**日期**: 2025-09-28
**決策點**: 完成實作 vs 歸檔
**建議**: ✅ **完成實作 (GREEN Phase)**

---

## 📊 技術分析

### 當前狀況

| 項目 | tools/intent-compiler | kpt-functions/expectation-to-krm |
|------|----------------------|----------------------------------|
| **語言** | Python (43 lines) | Go (1,208 lines) |
| **輸入格式** | TMF921 Intent JSON | 3GPP TS 28.312 Expectation JSON |
| **輸出** | 基礎 Deployment YAML | 完整 KRM 資源套件 (Deployment/PVC/HPA/ServiceMonitor) |
| **狀態** | ✅ 100% 完成 | ⚠️ 30% 完成 (TDD RED Phase) |
| **使用場景** | **生產環境** (14 script 引用) | 開發/測試環境 (5 script 引用) |
| **標準支持** | TMF Forum TMF921 | 3GPP TS 28.312 + O-RAN O2 IMS |
| **功能重疊** | ❌ **無重疊** - 處理不同標準 | ❌ **無重疊** - 不同輸入輸出 |

### 關鍵發現

1. **功能不重複**:
   - `tools/intent-compiler`: TMF921 → 簡單 K8s Deployment
   - `kpt-functions`: 3GPP 28.312 → 完整 O-RAN KRM 資源

2. **標準互補**:
   - TMF921: 電信管理論壇 (TM Forum) 意圖管理 API
   - 3GPP TS 28.312: 3GPP Intent-driven management 標準
   - **兩者都是專案宣稱支持的標準**

3. **完成度**:
   - 架構完整: ✅ (structs, types, test suite 都已定義)
   - 核心邏輯: ❌ (processResourceList 函數未實作)
   - 測試覆蓋: ✅ (完整 golden file testing)

---

## 🎯 建議: 完成實作

### 為什麼選擇「完成」而非「歸檔」?

#### ✅ 支持完成的理由:

1. **標準合規性需求**
   - 專案宣稱符合 3GPP TS 28.312 標準
   - 目前只有 TMF921 實作，缺少 3GPP 支持
   - IEEE 論文提到 3GPP 標準支持 (需要實際實現)

2. **功能完整性**
   - 3GPP 28.312 是更全面的標準 (包含 Expectation 模型)
   - 產生完整 O-RAN 部署資源 (PVC, HPA, ServiceMonitor)
   - `tools/intent-compiler` 太簡化 (只產生 Deployment)

3. **開發成本低**
   - 架構已完成 (30% → 100%)
   - 測試套件完整 (TDD RED phase 已通過)
   - **估計: 2-3 天開發即可完成**

4. **長期價值**
   - 與 O-RAN O2 IMS 深度整合
   - 支持 edge/central 雙場景部署
   - 未來擴展基礎 (HPA, auto-scaling)

5. **專案定位**
   - 學術研究專案 (IEEE ICC 2026 提交)
   - 需要完整標準覆蓋來支撐論文主張
   - 區別於簡化原型實作

#### ❌ 不建議歸檔的原因:

1. 專案文檔多處提到 3GPP TS 28.312 支持
2. IEEE 論文聲稱符合此標準
3. 與 O-RAN O2 IMS 標準直接對應
4. 只需 2-3 天即可完成 (投資報酬率高)

---

## 📋 執行計畫 (GREEN Phase)

### Phase 1: 實作核心邏輯 (1.5 天)

```bash
# 1. 實作 processResourceList 函數
cd kpt-functions/expectation-to-krm

# 目標: main.go 中實作以下邏輯
# - 解析 ConfigMap 中的 expectation.json
# - 根據 expectation 類型產生對應 KRM 資源:
#   - Deployment (CPU/Memory requests/limits from expectation)
#   - PVC (storage requirements from expectation)
#   - ServiceMonitor (observability targets from expectation)
#   - HPA (central scenario auto-scaling)
# - 設置 namespace (edge: o-ran-edge, central: o-ran-central)
# - 添加 expectation metadata annotations
```

**具體步驟:**

```go
// Step 1: 解析 ConfigMap 輸入
func processResourceList(rl *framework.ResourceList) error {
    // 1.1 找到帶有 expectation.28312.3gpp.org/input: "true" annotation 的 ConfigMap
    // 1.2 解析 data.expectation.json 欄位
    // 1.3 Unmarshal 成 Expectation28312 struct

    // Step 2: 判斷部署場景
    scenario := determineDeploymentScenario(expectation)
    namespace := "o-ran-edge" // or "o-ran-central"

    // Step 3: 產生 Kubernetes 資源
    resources := []yaml.RNode{}

    // 3.1 產生 Deployment
    deployment := generateDeployment(expectation, namespace)
    resources = append(resources, deployment)

    // 3.2 產生 PVC (如果需要 storage)
    if requiresStorage(expectation) {
        pvc := generatePVC(expectation, namespace)
        resources = append(resources, pvc)
    }

    // 3.3 產生 ServiceMonitor
    serviceMonitor := generateServiceMonitor(expectation, namespace)
    resources = append(resources, serviceMonitor)

    // 3.4 產生 HPA (central scenario)
    if scenario == "central" {
        hpa := generateHPA(expectation, namespace)
        resources = append(resources, hpa)
    }

    // Step 4: 添加到 ResourceList
    for _, r := range resources {
        rl.Items = append(rl.Items, r)
    }

    return nil
}
```

### Phase 2: 測試驗證 (0.5 天)

```bash
# 1. 運行測試 (應該從 RED 轉為 GREEN)
make test

# 預期結果:
# ✅ TestExpectationToKRMConversion PASS
# ✅ TestKptFunctionInterface PASS
# ✅ Golden file comparison PASS

# 2. 驗證生成的 YAML 符合 golden files
diff testdata/golden/edge/deployment.yaml <(實際輸出)

# 3. 作為 kpt function 測試
make kpt-test
```

### Phase 3: 整合與文檔 (1 天)

```bash
# 1. 整合到主要 pipeline
# 更新 scripts/demo_llm.sh 添加 3GPP path:
if [[ "$INPUT_FORMAT" == "3gpp" ]]; then
    kpt fn eval rendered/krm --image gcr.io/nephio/expectation-to-krm:latest
fi

# 2. 更新文檔
# - README.md: 添加 3GPP TS 28.312 usage examples
# - CLAUDE.md: 記錄 3GPP 支持
# - docs/architecture/: 更新架構圖顯示 3GPP path

# 3. 添加 E2E 測試
pytest tests/test_3gpp_expectation_pipeline.py -v
```

---

## ⏱️ 時間估算

| 階段 | 任務 | 時間 |
|------|------|------|
| Phase 1 | 實作核心邏輯 | 1.5 天 |
| Phase 2 | 測試驗證 | 0.5 天 |
| Phase 3 | 整合與文檔 | 1 天 |
| **總計** | | **3 天** |

---

## 🚀 立即開始的命令

```bash
# 1. 進入工作目錄
cd kpt-functions/expectation-to-krm

# 2. 確認測試環境 (應該在 RED phase)
make test-red

# 3. 開始實作 (編輯 main.go)
vim main.go

# 找到 processResourceList 函數，實作核心邏輯
# 參考上面的步驟 1-4

# 4. 持續測試直到 GREEN
make test

# 5. 提交完成
git add .
git commit -m "feat(kpt-functions): Complete expectation-to-krm GREEN phase

- Implement processResourceList core logic
- Parse 3GPP TS 28.312 expectation JSON
- Generate full O-RAN KRM resources (Deployment/PVC/HPA/ServiceMonitor)
- Support edge and central deployment scenarios
- All golden file tests passing (RED → GREEN)

Closes: #TBD
Standards: 3GPP TS 28.312, O-RAN O2 IMS"
```

---

## 📊 投資報酬率分析

| 指標 | 價值 |
|------|------|
| **開發成本** | 3 天 (已完成 30%) |
| **新增功能** | 3GPP TS 28.312 標準支持 |
| **代碼行數** | ~300 行新增邏輯 (70% 已存在) |
| **測試覆蓋** | 已有完整測試 (0 額外成本) |
| **文檔成本** | 1 天 (更新現有文檔) |
| **維護成本** | 低 (TDD 保護) |
| **學術價值** | 高 (支撐 IEEE 論文主張) |
| **標準合規** | 完整 3GPP + O-RAN 覆蓋 |

**ROI**: 極高 (3 天投入換取完整標準支持 + 學術價值)

---

## 🎯 決策建議

### 推薦選項: ✅ **執行 GREEN Phase 完成實作**

**理由總結:**
1. 只需 3 天即可完成
2. 支撐專案的 3GPP TS 28.312 標準宣稱
3. 增強 IEEE 論文技術深度
4. 與現有系統無重複 (互補而非競爭)
5. 長期維護成本低 (TDD 保護)

### 替代選項: ⚠️ **歸檔** (不推薦)

僅當滿足以下條件時考慮:
- 專案放棄 3GPP TS 28.312 標準支持
- IEEE 論文不需要此標準作為支撐
- 未來 6 個月內無資源完成實作

---

## 📝 執行後檢查清單

完成 GREEN Phase 後，執行以下驗證:

- [ ] `make test` 全部通過 (從 RED 變 GREEN)
- [ ] Golden file 比對 100% 匹配
- [ ] 作為 kpt function 可正常運行
- [ ] 整合到 `demo_llm.sh` 3GPP path
- [ ] 文檔更新完成 (README, CLAUDE.md, architecture)
- [ ] E2E 測試通過
- [ ] Git commit 並 push
- [ ] 更新專案完成度報告 (30% → 100%)

---

**報告產生時間**: 2025-09-28
**決策狀態**: 等待確認執行
**預計完成日期**: 2025-10-01 (若立即開始)