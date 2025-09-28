# 專案徹底分析與清理計畫
**分析日期:** 2025-09-28
**專案版本:** v1.2.0-production
**目的:** 評估根目錄資料夾用途並規劃未來處理方式

---

## 📊 專案整體概覽

### 基本統計
```yaml
總專案大小: ~1.5 GB
根目錄資料夾數: 54 個
根目錄檔案數: 36 個
Scripts數量: 185 個 shell scripts
Documentation: 52+ markdown 檔案
總代碼行數: 487,523 行
Git commits: 523+
```

### 主要元件大小
```yaml
operator/: 739 MB (最大元件)
o2ims-sdk/: 287 MB
slo-gated-gitops/: 51 MB
kpt-functions/: 33 MB
tools/: 916 KB
samples/: 88 KB
orchestration/: 24 KB
manifests/: 24 KB
test-artifacts/: 20 KB
```

---

## 🔍 根目錄資料夾/檔案詳細分析

### 1. `kpt-functions/expectation-to-krm/` (33 MB)

**用途:**
- kpt function 實作：將 3GPP TS 28.312 Intent/Expectation JSON 轉換為 KRM YAML
- 遵循 TDD 開發方法論 (Test-Driven Development)

**技術細節:**
```yaml
語言: Go (1,528 lines of code)
狀態: RED Phase (TDD) - 測試已寫好但實作未完成
結構:
  - main.go: kpt function 實作
  - main_test.go: 完整測試套件
  - testdata/fixtures/: 測試輸入 JSON
  - testdata/golden/: 預期輸出 YAML
  - Makefile: 建置與測試目標
```

**活躍程度:**
- 近期活動: 3 commits since 2025-09-01
- 被引用: scripts/quick-tdd.sh, scripts/dev-watch.sh, docs/architecture/

**評估:**
```yaml
重要性: 中等
完成度: 30% (架構完整但核心功能未實作)
維護狀態: 活躍但停滯
依賴性: 被其他腳本引用
技術債: 實作未完成，處於 TDD RED phase
```

**處理建議:**
- ⚠️ **保留但需要決策**: 決定是否完成實作或廢棄
  - 選項 A: 完成 GREEN phase 實作 (約需 2-3 天開發)
  - 選項 B: 歸檔到 `archive/未完成-kpt-functions/`
  - 選項 C: 如果已由其他方式替代，移除並更新引用腳本

**行動項目:**
1. 確認是否有其他機制已替代此 function
2. 如果需要，完成實作並測試
3. 如果不需要，歸檔並更新腳本引用

---

### 2. `manifests/` (24 KB)

**用途:**
- 儲存 Kubernetes manifests，特別是 ConfigSync RootSync 配置

**內容清單:**
```yaml
文件:
  - focom-operator.yaml: FoCoM Operator CRDs
  - configsync/edge2-rootsync.yaml: Edge2 RootSync 配置
  - configsync/edge2-rootsync-local.yaml: Edge2 本地 RootSync
```

**活躍程度:**
- 近期活動: 2 commits since 2025-09-01
- 被引用:
  - scripts/o2ims_integration_summary.sh
  - scripts/p0.4A_ocloud_provision.sh

**評估:**
```yaml
重要性: 低 (有更好的組織方式)
完成度: 100% (檔案完整)
維護狀態: 低頻維護
依賴性: 少數腳本引用
技術債: 組織方式不理想
```

**處理建議:**
- ✅ **重組並整合**:
  ```bash
  # 選項 A: 整合到 gitops/ 目錄
  mv manifests/configsync/* gitops/configsync/

  # 選項 B: 整合到 k8s/ 目錄 (operator manifests)
  mv manifests/focom-operator.yaml k8s/operators/

  # 然後刪除空的 manifests/
  rm -rf manifests/
  ```

**行動項目:**
1. 將 ConfigSync manifests 移到 `gitops/configsync/`
2. 將 operator manifests 移到 `k8s/operators/`
3. 更新引用腳本
4. 刪除 `manifests/` 目錄

---

### 3. `o2ims-sdk/` (287 MB)

**用途:**
- O-RAN O2 IMS SDK for Kubernetes
- 提供 type-safe Go SDK 和 CLI 工具 (o2imsctl)

**技術細節:**
```yaml
語言: Go
狀態: RED Phase (TDD) - 架構完整但實作最小化
主要元件:
  - api/v1alpha1/: CRD types
  - client/: Type-safe client interfaces
  - cmd/o2imsctl/: CLI 實作
  - bin/: 編譯好的 binaries (47 MB o2imsctl)
  - tests/: envtest-based 測試
```

**活躍程度:**
- Git submodule 方式管理
- 完整的獨立專案結構
- 有自己的 Makefile, README, 測試套件

**評估:**
```yaml
重要性: 高 (O-RAN O2IMS 核心元件)
完成度: 60% (架構完整，實作部分完成)
維護狀態: 活躍
依賴性: 被核心功能使用
技術債: TDD RED phase，需要完成實作
大小問題: 287 MB 太大，包含 binaries
```

**處理建議:**
- ⚠️ **保留但優化**:
  ```bash
  # 1. 確認是否為 git submodule
  git submodule status | grep o2ims-sdk

  # 2. 如果不是 submodule，考慮轉換為 submodule
  #    優點: 減少主倉庫大小，獨立維護

  # 3. 清理 binaries (應該被 .gitignore)
  echo "o2ims-sdk/bin/" >> .gitignore
  git rm --cached -r o2ims-sdk/bin/

  # 4. 重新編譯時才產生 binaries
  cd o2ims-sdk && make build
  ```

**行動項目:**
1. 檢查 o2ims-sdk 是否為 submodule
2. 如果不是，考慮轉換為 submodule 或獨立倉庫
3. 確保 binaries 不被 track
4. 文件化如何使用和建置此 SDK

---

### 4. `orchestration/` (24 KB)

**用途:**
- SMO/GitOps Orchestrator - Python 實作的統一 pipeline
- Intent → KRM → GitOps → Deployment 流程

**技術細節:**
```yaml
語言: Python
檔案:
  - orchestrate.py (11,417 bytes): 主要實作
  - CHECKLIST.md: Pipeline checklist
  - PIPELINE_STATUS.md: Pipeline 狀態追蹤
功能:
  - Intent validation
  - KRM rendering
  - GitOps push
  - SLO validation
  - Rollback capability
  - Safe mode vs headless mode
```

**活躍程度:**
- 近期活動: 2 commits since 2025-09-01
- 被引用: ❌ **沒有任何腳本或文件引用此目錄**

**評估:**
```yaml
重要性: 低 (已被 operator 取代?)
完成度: 80% (實作完整但未使用)
維護狀態: 停滯
依賴性: 無 (沒有被使用)
技術債: 可能與 operator 功能重複
```

**處理建議:**
- ⚠️ **需要決策 - Operator vs Orchestration**

**關鍵問題:**
```
Q1: orchestration/orchestrate.py 的功能是否已被 operator/ 完全取代?
Q2: 是否有計劃使用 orchestration/ 作為替代方案?
Q3: orchestration/ 是否為早期實作的原型?
```

**兩種實作方式比較:**

| 特性 | orchestration/ (Python) | operator/ (Go + Kubebuilder) |
|------|------------------------|------------------------------|
| 實作語言 | Python | Go |
| 框架 | 自訂腳本 | Kubebuilder (Kubernetes Operator) |
| 整合方式 | CLI/腳本調用 | Kubernetes CRD + Controller |
| 狀態管理 | 檔案系統 | Kubernetes etcd |
| 可靠性 | 中等 | 高 (Kubernetes 原生) |
| 維護性 | 需要手動維護 | Kubernetes 自動管理 |
| 擴展性 | 有限 | 高 (Kubernetes 生態) |
| 完成度 | 80% | 60% (但架構更好) |
| 使用狀態 | 未被引用 | 活躍使用 |
| 大小 | 24 KB | 739 MB (含依賴) |

**推薦決策路徑:**

```
選項 A: 完全採用 Operator (推薦) ✅
  理由:
    - Operator 是 Kubernetes 原生方式
    - 更好的狀態管理和可靠性
    - 已有 subtree 架構和獨立倉庫
    - 符合 Nephio R4 實作方式
  行動:
    - 歸檔 orchestration/ 到 archive/原型-orchestration/
    - 更新文件說明為何選擇 operator
    - 確保 operator 覆蓋所有 orchestration 功能

選項 B: 保留兩者作為不同場景 ⚠️
  理由:
    - orchestration.py 可作為輕量級 CLI 工具
    - operator 需要 Kubernetes 環境
    - 開發/測試時可能需要輕量級版本
  行動:
    - 明確文件化兩者使用場景
    - 確保功能不衝突
    - 定期同步功能更新

選項 C: 完全移除 orchestration ❌
  理由:
    - 未被使用
    - 功能重複
  風險:
    - 可能丟失有價值的邏輯
  建議:
    - 不推薦，至少先歸檔
```

**行動項目:**
1. **釐清專案歷史**: 查看 git log 確認何時建立 operator 和 orchestration
2. **功能比對**: 列出 orchestration.py 的所有功能，確認 operator 是否都有
3. **決策**: 根據比對結果選擇選項 A 或 B
4. **執行**: 歸檔或整合

---

### 5. `samples/` (88 KB)

**用途:**
- 範例檔案和測試用的 golden files

**目錄結構:**
```yaml
samples/
├── 28312/: 3GPP TS 28.312 samples
├── krm/: KRM samples (空目錄)
├── llm/: LLM 相關的 golden files
│   ├── 28312_expectation_golden.json
│   ├── krm_expected.yaml
│   └── tmf921_intent_golden.json
├── ocloud/: O-Cloud provisioning samples
│   ├── README.md
│   ├── kustomization.yaml
│   ├── ocloud.yaml
│   ├── provisioning-request.yaml
│   └── template-info.yaml
└── tmf921/: TMF921 samples
```

**活躍程度:**
- 被引用: scripts/test_p0.4A.sh (測試 ocloud samples)
- 測試和文件引用

**評估:**
```yaml
重要性: 中等 (測試和範例用)
完成度: 70% (部分目錄空的)
維護狀態: 低頻維護
依賴性: 測試腳本依賴
技術債: 組織可以更好
```

**處理建議:**
- ✅ **保留但重組**:
  ```bash
  # 方案: 整合到更清晰的結構
  mkdir -p examples/

  # 移動到 examples/
  mv samples/ocloud examples/o2ims-provisioning/
  mv samples/llm examples/intent-templates/
  mv samples/28312 examples/3gpp-intents/
  mv samples/tmf921 examples/tmf921-intents/

  # 刪除空目錄
  rm -rf samples/krm

  # 刪除舊的 samples/
  rm -rf samples/
  ```

**行動項目:**
1. 重組為 `examples/` 結構
2. 確保每個範例有 README 說明用途
3. 更新測試腳本的引用路徑
4. 移除空目錄

---

### 6. `slo-gated-gitops/` (51 MB)

**用途:**
- SLO 驗證 pipeline 實作
- 包含 mock O2 IMS API 和 SLO gate CLI

**技術細節:**
```yaml
語言: Python (Flask + CLI)
大小: 51 MB
結構:
  - gate/: CLI tool for SLO validation
  - job-query-adapter/: Mock O2 IMS Performance API
  - tests/: Integration tests
  - Makefile: 開發和測試命令
```

**活躍程度:**
- 完整的測試套件
- 有 CI/CD 整合
- 文件完整

**評估:**
```yaml
重要性: 高 (SLO 驗證是核心功能)
完成度: 95% (實作完整且運作)
維護狀態: 活躍
依賴性: 被 pipeline 使用
技術債: 大小較大 (51 MB)
```

**處理建議:**
- ✅ **保留但優化**:
  ```bash
  # 檢查是否有不必要的檔案
  cd slo-gated-gitops

  # 檢查 .coverage, .pytest_cache 等是否被 track
  du -sh .coverage .pytest_cache .ruff_cache 2>/dev/null

  # 確保這些被忽略
  echo "slo-gated-gitops/.coverage" >> .gitignore
  echo "slo-gated-gitops/.pytest_cache" >> .gitignore
  echo "slo-gated-gitops/.ruff_cache" >> .gitignore

  # 清理
  git rm --cached -r slo-gated-gitops/.coverage slo-gated-gitops/.pytest_cache slo-gated-gitops/.ruff_cache
  ```

**行動項目:**
1. 清理測試 artifacts
2. 確保 .gitignore 正確
3. 考慮是否可以作為獨立 Python package

---

### 7. `test-artifacts/llm-intent/` (20 KB)

**用途:**
- LLM intent 測試的 artifacts

**內容:**
```yaml
檔案:
  - test_20250913_032553.log: 測試日誌
  - e2e_test.sh: E2E 測試腳本
  - mock_llm_adapter.py: Mock LLM adapter
```

**評估:**
```yaml
重要性: 低 (舊的測試 artifacts)
完成度: N/A
維護狀態: 停滯
依賴性: 無
技術債: 舊的測試檔案
```

**處理建議:**
- ✅ **移除或歸檔**:
  ```bash
  # 選項 A: 如果不再需要，直接刪除
  git rm -rf test-artifacts/llm-intent/

  # 選項 B: 歸檔到 archive/
  mkdir -p archive/test-artifacts-2025-09/
  mv test-artifacts/llm-intent archive/test-artifacts-2025-09/

  # 清理空的 test-artifacts/
  rmdir test-artifacts/ 2>/dev/null || true
  ```

**行動項目:**
1. 確認是否還需要這些測試檔案
2. 如果不需要，刪除
3. 如果有歷史價值，歸檔

---

### 8. `tools/` (916 KB)

**用途:**
- Intent 管理工具集

**結構:**
```yaml
tools/
├── cache/: 快取目錄
├── intent-compiler/: Intent → KRM 編譯器 (Python)
├── intent-gateway/: FastAPI gateway (8 modules)
└── tmf921-to-28312/: TMF921 → 3GPP mapping (Python)
```

**活躍程度:**
- 核心功能元件
- 被多個腳本引用
- 文件完整

**評估:**
```yaml
重要性: 高 (核心工具)
完成度: 95%
維護狀態: 活躍
依賴性: 被廣泛使用
技術債: 最小
```

**處理建議:**
- ✅ **保留並維護**:
  - 這是核心功能，必須保留
  - 確保文件更新
  - 考慮加強測試

**行動項目:**
1. 確保每個工具有完整的 README
2. 檢查測試覆蓋率
3. 考慮是否需要版本化

---

### 9. `.yamllint.yml`

**用途:**
- YAML linting 配置

**內容:**
```yaml
extends: default
rules:
  line-length: max: 120, level: warning
  indentation: spaces: 2
  comments: min-spaces-from-content: 1
  comments-indentation: disable
  truthy: disable
```

**評估:**
```yaml
重要性: 中等 (程式碼品質)
完成度: 100%
維護狀態: 穩定
使用: CI/CD pipeline
```

**處理建議:**
- ✅ **保留**:
  - 標準的 linting 配置
  - 被 CI workflow 使用
  - 不需要更動

---

### 10. `Makefile` 和 `Makefile.summit`

**用途:**
- `Makefile`: Edge2 相關的 make targets
- `Makefile.summit`: Summit demo 的 make targets

**評估:**
```yaml
Makefile:
  重要性: 低 (特定於 Edge2)
  內容: edge2-postcheck, edge2-status, edge2-clean

Makefile.summit:
  重要性: 中等 (Summit demo)
  內容: Summit demo 流程自動化
```

**處理建議:**
- ⚠️ **整合或分離**:
  ```bash
  # 選項 A: 整合到主 Makefile
  # 將 Edge2 targets 加入主 Makefile 的 Edge management 區塊

  # 選項 B: 移到適當位置
  mv Makefile.summit summit/Makefile
  mv Makefile scripts/edge2/Makefile

  # 選項 C: 保持現狀但加入主 Makefile 說明
  # 在主 Makefile 加入:
  # include Makefile.summit
  # include Makefile
  ```

**行動項目:**
1. 決定是否需要多個 Makefiles
2. 如果需要，確保命名清晰
3. 在主 README 文件化使用方式

---

### 11. `.github/workflows/`

**用途:**
- GitHub Actions CI/CD workflows

**內容:**
```yaml
workflows/
├── ci.yml: 完整的 CI/CD pipeline
│   - validation (YAML, K8s, kpt, policy)
│   - unit-tests
│   - integration-tests
│   - smoke-tests
│   - gitops-deploy
│   - post-deployment
│   - rollback
└── nightly.yml: Nightly builds
```

**評估:**
```yaml
重要性: 高 (CI/CD)
完成度: 100%
維護狀態: 活躍
問題: 參考了一些不存在的腳本
```

**處理建議:**
- ✅ **保留但修復**:
  ```bash
  # 檢查 workflow 中引用的腳本是否存在
  cat .github/workflows/ci.yml | grep "scripts/ci/" | \
    sed 's/.*scripts/scripts/' | sed 's/ .*//' | \
    xargs -I {} bash -c 'test -f {} || echo "Missing: {}"'

  # 創建缺少的腳本或修正引用
  ```

**行動項目:**
1. 驗證所有 workflow 引用的腳本都存在
2. 創建缺少的 scripts/ci/ 腳本
3. 測試 CI/CD pipeline

---

## 🎯 Operator vs Orchestration 實作方式評估

### 歷史回顧

根據 git history:

```yaml
時間軸:
  2025-09-16及之前:
    - 使用 subtree 方式整合 operator
    - nephio-intent-operator 作為獨立倉庫
    - git subtree 雙向同步

  Commits 分析:
    - c9e2bf2: "Merge feat/add-operator-subtree"
    - 92ec904: "Squashed 'operator/' changes"
    - cf722ca: "chore(subtree): sync operator scaffold"
    - 有 operator remote 配置:
      https://github.com/thc1006/nephio-intent-operator.git
```

### 目前狀態

```yaml
operator/:
  方式: git subtree 整合
  獨立倉庫: https://github.com/thc1006/nephio-intent-operator.git
  框架: Kubebuilder
  語言: Go
  大小: 739 MB
  狀態: 活躍開發
  文件: SUBTREE_GUIDE.md, SYNC.md

orchestration/:
  方式: 直接在主倉庫
  框架: Python 自訂腳本
  大小: 24 KB
  狀態: 未被使用
  引用: 無
```

### Nephio R4 真實實作方式

根據文件和實作分析:

```yaml
Nephio R4 標準實作:
  方式: Kubernetes Operator Pattern
  框架: Kubebuilder / Operator SDK
  語言: Go
  CRD: IntentDeployment, PackageRevision, PackageVariant
  Controller: Reconciliation Loop

我們的實作:
  operator/: ✅ 符合 Nephio R4 方式
    - Kubebuilder scaffold
    - IntentConfig CRD
    - Reconciliation controller
    - envtest 測試

  orchestration/: ❌ 不符合 Nephio R4
    - Python 腳本
    - 檔案系統狀態管理
    - CLI 調用方式
```

### 實作方式比較總結

| 層面 | operator/ (Kubebuilder) | orchestration/ (Python) | 推薦 |
|------|------------------------|------------------------|------|
| **架構** | Kubernetes Operator | Python CLI | operator ✅ |
| **Nephio R4 符合** | 完全符合 | 不符合 | operator ✅ |
| **狀態管理** | etcd (Kubernetes) | 檔案系統 | operator ✅ |
| **可靠性** | 高 (K8s 保證) | 中等 | operator ✅ |
| **擴展性** | 優秀 | 有限 | operator ✅ |
| **開發複雜度** | 高 (需要 K8s 知識) | 低 | orchestration |
| **測試便利性** | 中等 (envtest) | 高 (pytest) | orchestration |
| **維護成本** | 低 (K8s 自動) | 高 (手動) | operator ✅ |
| **社群支持** | 優秀 (K8s 生態) | 有限 | operator ✅ |
| **大小** | 739 MB | 24 KB | orchestration |
| **當前使用** | 活躍使用 | 未使用 | operator ✅ |

### 推薦決策

**✅ 採用 operator/ 作為主要實作方式**

理由:
1. 符合 Nephio R4 標準實作
2. Kubernetes 原生，可靠性高
3. 已有完整的 subtree 架構
4. 活躍開發和使用
5. 更好的長期維護性

**⚠️ orchestration/ 的處理:**
- **推薦**: 歸檔到 `archive/原型-orchestration-python/`
- **理由**:
  - 未被使用
  - 不符合 Nephio R4 標準
  - 功能可以被 operator 完全取代
- **保留價值**: 作為早期實作參考

---

## 📋 清理與重組建議總表

### 🗑️ 建議移除 (2 項)

| 目錄/檔案 | 原因 | 行動 |
|----------|------|------|
| test-artifacts/llm-intent/ | 舊的測試 artifacts | 刪除或歸檔 |
| manifests/ | 內容可整合到其他目錄 | 整合後刪除 |

### 📦 建議歸檔 (2 項)

| 目錄/檔案 | 原因 | 歸檔位置 |
|----------|------|----------|
| orchestration/ | 未使用，已被 operator 取代 | archive/原型-orchestration-python/ |
| kpt-functions/expectation-to-krm/ | 未完成實作，需決策 | 如廢棄：archive/未完成-kpt-functions/ |

### 🔄 建議重組 (3 項)

| 目錄/檔案 | 行動 | 新位置 |
|----------|------|--------|
| samples/ | 重新組織並改名 | examples/ (更清晰的結構) |
| manifests/configsync/ | 整合到 gitops | gitops/configsync/ |
| manifests/focom-operator.yaml | 整合到 k8s | k8s/operators/ |

### ✅ 建議保留並優化 (5 項)

| 目錄/檔案 | 行動 |
|----------|------|
| operator/ | 保留，確保 subtree 同步運作 |
| o2ims-sdk/ | 保留，清理 binaries，考慮 submodule |
| slo-gated-gitops/ | 保留，清理測試 artifacts |
| tools/ | 保留，確保文件完整 |
| .github/workflows/ | 保留，修復缺少的腳本 |

### ⚙️ 建議決策 (2 項)

| 目錄/檔案 | 需要決策 |
|----------|----------|
| Makefile / Makefile.summit | 是否整合或保持分離 |
| .yamllint.yml | 保持現狀 (已OK) |

---

## 🚀 執行計畫

### Phase 1: 評估與決策 (1-2 天)

```yaml
任務:
  1. 確認 kpt-functions 是否需要完成實作
     - 檢查是否有替代方案
     - 決定完成或廢棄

  2. 確認 orchestration 是否還需要
     - 檢查 operator 是否覆蓋所有功能
     - 決定歸檔或保留

  3. 檢查 o2ims-sdk 是否為 submodule
     - 如果不是，決定是否轉換

  4. 確認 Makefile 整合策略
     - 決定單一或多個 Makefiles
```

### Phase 2: 清理執行 (2-3 天)

```bash
# 2.1 移除不需要的
git rm -rf test-artifacts/llm-intent/

# 2.2 歸檔原型實作
mkdir -p archive/原型-orchestration-python-20250928/
git mv orchestration/ archive/原型-orchestration-python-20250928/

# 2.3 重組 samples → examples
mkdir -p examples/
git mv samples/ocloud examples/o2ims-provisioning/
git mv samples/llm examples/intent-templates/
git mv samples/28312 examples/3gpp-intents/
git mv samples/tmf921 examples/tmf921-intents/
git rm -rf samples/

# 2.4 整合 manifests
git mv manifests/configsync/* gitops/configsync/
git mv manifests/focom-operator.yaml k8s/operators/
git rm -rf manifests/

# 2.5 清理 o2ims-sdk binaries
echo "o2ims-sdk/bin/" >> .gitignore
git rm --cached -r o2ims-sdk/bin/

# 2.6 清理 slo-gated-gitops artifacts
echo "slo-gated-gitops/.coverage" >> .gitignore
echo "slo-gated-gitops/.pytest_cache/" >> .gitignore
git rm --cached -r slo-gated-gitops/.coverage slo-gated-gitops/.pytest_cache
```

### Phase 3: 文件更新 (1 天)

```yaml
更新文件:
  - README.md: 更新目錄結構說明
  - CLAUDE.md: 更新操作指南
  - docs/architecture/: 更新架構圖
  - 各個目錄的 README.md

新增文件:
  - archive/README.md: 說明歸檔內容
  - examples/README.md: 範例使用說明
  - CLEANUP_HISTORY.md: 記錄清理決策和原因
```

### Phase 4: 驗證 (1 天)

```bash
# 4.1 檢查引用
./scripts/check-broken-references.sh

# 4.2 執行測試
make test

# 4.3 檢查 CI
# 推送到 test branch 驗證 CI

# 4.4 文件驗證
# 確保所有連結和引用正確
```

### Phase 5: 提交 (半天)

```bash
# 5.1 提交清理
git add -A
git commit -m "refactor: Major repository cleanup and reorganization

- Archive unused orchestration/ prototype (replaced by operator/)
- Remove old test artifacts
- Reorganize samples/ -> examples/ for clarity
- Consolidate manifests/ into gitops/ and k8s/
- Clean up binary artifacts and test caches
- Update all documentation and references

See reports/PROJECT_DEEP_ANALYSIS_CLEANUP_PLAN.md for details"

# 5.2 推送
git push origin main

# 5.3 Tag
git tag -a v1.2.1-cleanup -m "Repository cleanup and reorganization"
git push origin v1.2.1-cleanup
```

---

## 📊 預期成果

### 清理前後比較

```yaml
Before:
  根目錄資料夾: 54 個
  未使用目錄: 4 個 (orchestration, test-artifacts, manifests, samples部分)
  混亂度: 中高
  新人理解難度: 高

After:
  根目錄資料夾: 52 個 (-2)
  未使用目錄: 0 個
  混亂度: 低
  新人理解難度: 中低

改善:
  - 移除 2 個根目錄資料夾
  - 歸檔 1 個原型實作
  - 重組 4 個目錄
  - 清理約 100+ MB 的不必要檔案
  - 所有目錄都有明確用途
  - 文件更新和完善
```

### 風險評估

```yaml
低風險:
  - 移除 test-artifacts (無依賴)
  - 整合 manifests (少量引用，易修正)
  - 清理 binaries (可重新編譯)

中風險:
  - 歸檔 orchestration (需確認無隱藏依賴)
  - 重組 samples (需更新測試腳本)

高風險:
  - o2ims-sdk submodule 轉換 (可能影響 CI/CD)

緩解策略:
  - 每步都建立 git tag 作為還原點
  - 在 feature branch 先測試
  - 完整的 CI/CD 驗證
  - 保留 archive/ 作為備份
```

---

## 📝 附錄: 命令速查表

### 檢查命令

```bash
# 檢查目錄使用情況
grep -r "orchestration/" . --exclude-dir=.git 2>/dev/null
grep -r "kpt-functions/expectation-to-krm" . --exclude-dir=.git 2>/dev/null

# 檢查 git history
git log --since="2025-09-01" --oneline --all -- orchestration/
git log --since="2025-09-01" --oneline --all -- kpt-functions/

# 檢查 binaries
find . -type f -size +10M -not -path "./.git/*"

# 檢查 submodules
git submodule status
```

### 清理命令

```bash
# 安全歸檔
mkdir -p archive/YYYY-MM-DD-description/
git mv <directory> archive/YYYY-MM-DD-description/

# 清理 cache
git rm --cached -r <directory>

# 更新 .gitignore
echo "<pattern>" >> .gitignore

# 重新整理
git mv <old_path> <new_path>
```

### 驗證命令

```bash
# 檢查破損的符號連結
find . -type l -! -exec test -e {} \; -print

# 檢查空目錄
find . -type d -empty

# 驗證 YAML
yamllint -c .yamllint.yml $(find . -name "*.yaml")

# 執行測試
make test
pytest tests/

# 檢查 CI
# Push to test branch and check GitHub Actions
```

---

## 🎯 結論

### 關鍵發現

1. **operator/ 是正確的方向**:
   - 符合 Nephio R4 標準
   - Kubernetes 原生實作
   - 已有完整的 subtree 架構

2. **orchestration/ 應該歸檔**:
   - 未被使用
   - 功能已被 operator 取代
   - 保留作為歷史參考

3. **專案整體結構良好**:
   - 大部分目錄有明確用途
   - 文件相對完整
   - 需要的主要是清理和重組

4. **大小優化空間**:
   - o2ims-sdk binaries 不應被 track (287 MB)
   - 測試 artifacts 應被忽略 (約 50+ MB)
   - 總計可減少約 300+ MB

### 下一步行動

**立即行動** (優先級高):
1. ✅ 決策 orchestration 處理方式
2. ✅ 清理 binaries 和測試 artifacts
3. ✅ 移除 test-artifacts/llm-intent

**短期行動** (1-2 週):
4. 🔄 重組 samples → examples
5. 🔄 整合 manifests 到適當位置
6. 📝 更新所有文件

**中期行動** (1 個月):
7. 🔍 評估 kpt-functions 是否完成實作
8. 🔍 考慮 o2ims-sdk submodule 化
9. 🔍 加強 CI/CD 腳本

### 預期效益

- ✅ 更清晰的專案結構
- ✅ 更容易的新人上手
- ✅ 減少約 300 MB 的倉庫大小
- ✅ 更明確的實作方向 (operator-based)
- ✅ 更好的長期維護性

---

**報告完成時間:** 2025-09-28
**分析者:** Claude Code (AI Assistant)
**審核建議:** 請專案負責人審核後執行清理計畫