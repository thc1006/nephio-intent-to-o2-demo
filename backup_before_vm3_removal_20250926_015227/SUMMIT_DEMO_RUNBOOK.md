# 🚀 Summit Demo Runbook / 峰會演示執行手冊

## 📋 Executive Overview / 執行概述

This runbook provides step-by-step instructions for executing the Nephio Intent-to-O2 demo at the summit. Each stage demonstrates a critical capability of the intent-driven orchestration pipeline.

本執行手冊提供在峰會上執行 Nephio Intent-to-O2 演示的逐步說明。每個階段都展示了意圖驅動編排管道的關鍵能力。

---

## 🎯 Demo Objectives / 演示目標

1. **Demonstrate intent-driven orchestration** / **展示意圖驅動編排**
2. **Show both shell and operator paths** / **展示 shell 和操作器兩種路徑**
3. **Validate SLO-based governance** / **驗證基於 SLO 的治理**
4. **Prove rollback capabilities** / **證明回滾能力**
5. **Provide verifiable evidence** / **提供可驗證的證據**

---

## 📊 Stage A: Shell Pipeline / Shell 管道

### 🎯 **Purpose / 用途**
Demonstrates the shell-based intent compilation pipeline from TMF921 intent to deployed KRM packages.

展示從 TMF921 意圖到部署 KRM 包的基於 shell 的意圖編譯管道。

### ⏰ **When to Use / 使用時機**
- Opening demonstration to show basic flow / 開場演示以展示基本流程
- When explaining the intent transformation process / 解釋意圖轉換過程時
- To highlight deterministic compilation / 突出確定性編譯

### 📝 **Functionality / 功能描述**
- Converts TMF921 JSON intent to 3GPP TS 28.312 format / 將 TMF921 JSON 意圖轉換為 3GPP TS 28.312 格式
- Generates Kubernetes Resource Model (KRM) manifests / 生成 Kubernetes 資源模型（KRM）清單
- Deploys to edge sites via kubectl / 通過 kubectl 部署到邊緣站點
- Creates audit trail and reports / 創建審計追踪和報告

### 💻 **Commands / 指令**
```bash
# Full summit demo with shell pipeline
# 使用 shell 管道的完整峰會演示
make -f Makefile.summit summit

# Alternative: Quick demo
# 替代方案：快速演示
./scripts/demo_quick.sh
```

### 📊 **Expected Output / 預期輸出**
```
✅ Edge-1 Analytics deployed
✅ Edge-2 ML Inference deployed
✅ Federated Learning deployed to both sites
✅ KPI tests passed
✅ Report generated at reports/<timestamp>/
```

---

## 🤖 Stage B: Operator Pipeline / 操作器管道

### 🎯 **Purpose / 用途**
Showcases the Kubernetes operator-based approach using Custom Resource Definitions (CRDs).

展示使用自定義資源定義（CRD）的基於 Kubernetes 操作器的方法。

### ⏰ **When to Use / 使用時機**
- After showing the shell pipeline / 展示 shell 管道後
- When discussing cloud-native patterns / 討論雲原生模式時
- To demonstrate reconciliation loops / 展示協調循環

### 📝 **Functionality / 功能描述**
- Applies IntentDeployment custom resources / 應用 IntentDeployment 自定義資源
- Operator watches and reconciles state / 操作器監視和協調狀態
- Automatic phase transitions / 自動階段轉換
- Built-in retry and error handling / 內建重試和錯誤處理

### 💻 **Commands / 指令**
```bash
# Deploy via operator
# 通過操作器部署
make -f Makefile.summit summit-operator

# Alternative: Direct kubectl
# 替代方案：直接 kubectl
kubectl apply -f operator/config/samples/
kubectl get intentdeployments -w

# Monitor phase transitions
# 監控階段轉換
./scripts/monitor_operator_phases.sh
```

### 📊 **Expected Output / 預期輸出**
```
✅ IntentDeployment CRs created
✅ Phase: Initializing → Provisioning → Configuring → Active
✅ All deployments reach Active state
✅ Operator metrics collected
```

---

## 💥 Stage C: Failure Injection / 故障注入

### 🎯 **Purpose / 用途**
Demonstrates resilience and automatic rollback capabilities when SLOs are violated.

展示當 SLO 被違反時的韌性和自動回滾能力。

### ⏰ **When to Use / 使用時機**
- Middle of demo to show resilience / 演示中段展示韌性
- When discussing production readiness / 討論生產就緒性時
- To highlight SLO-based governance / 突出基於 SLO 的治理

### 📝 **Functionality / 功能描述**
- Injects various fault types / 注入各種故障類型
- Triggers SLO violations / 觸發 SLO 違規
- Automatic detection and rollback / 自動檢測和回滾
- Recovery verification / 恢復驗證

### 💻 **Commands / 指令**
```bash
# Inject high latency fault on edge2
# 在 edge2 上注入高延遲故障
./scripts/inject_fault.sh edge2 high_latency

# Alternative fault types / 替代故障類型
./scripts/inject_fault.sh edge1 error_rate 0.15
./scripts/inject_fault.sh edge2 network_partition
./scripts/inject_fault.sh edge1 cpu_spike

# Trigger rollback manually (if needed)
# 手動觸發回滾（如需要）
./scripts/trigger_rollback.sh edge2 /tmp/rollback-evidence.json

# Check recovery / 檢查恢復
kubectl get pods -o wide
```

### 📊 **Expected Output / 預期輸出**
```
⚠️ Fault injected: high_latency on edge2
❌ SLO violation detected: latency > 15ms
🔄 Rollback initiated
✅ Previous version restored
✅ SLOs restored to normal
```

---

## 📁 Stage D: Evidence Collection / 證據收集

### 🎯 **Purpose / 用途**
Provides verifiable evidence of the demo execution with comprehensive reports and attestation.

提供演示執行的可驗證證據，包括綜合報告和認證。

### ⏰ **When to Use / 使用時機**
- End of demo for summary / 演示結束時總結
- When showing compliance / 展示合規性時
- For audit and documentation / 用於審計和文檔

### 📝 **Functionality / 功能描述**
- Generates manifest.json with metadata / 生成帶有元數據的 manifest.json
- Creates SHA256 checksums / 創建 SHA256 校驗和
- HTML report generation / HTML 報告生成
- Optional Cosign signatures / 可選的 Cosign 簽名

### 💻 **Commands / 指令**
```bash
# View generated reports
# 查看生成的報告
ls -la reports/$(ls -t reports/ | head -1)/

# Open HTML report
# 打開 HTML 報告
open reports/*/index.html

# View manifest
# 查看清單
cat reports/*/manifest.json | jq .

# Check checksums
# 檢查校驗和
cat reports/*/checksums.txt

# Optional: Sign with cosign (if configured)
# 可選：使用 cosign 簽名（如已配置）
make -f Makefile.summit summit-sign
```

### 📊 **Expected Output / 預期輸出**
```
✅ Reports generated at: reports/20250925-HHMMSS/
  ├── index.html (Executive summary)
  ├── manifest.json (Metadata)
  ├── checksums.txt (SHA256 hashes)
  ├── kpi-results.json (Performance metrics)
  └── deployment-record.json (Audit trail)
```

---

## 🎬 Complete Demo Flow / 完整演示流程

### 📋 **Preparation Checklist / 準備清單**
```bash
# 1. Verify connectivity / 驗證連接
ping -c 1 172.16.4.45   # VM2
kubectl get nodes        # Local cluster

# 2. Clean previous runs / 清理之前的運行
rm -rf artifacts/$(date +%Y%m%d)*
rm -rf reports/$(date +%Y%m%d)*

# 3. Set environment / 設置環境
export DEMO_MODE="summit"
source scripts/env.sh
```

### 🚀 **Execution Sequence / 執行順序**
```bash
# Stage A: Shell Pipeline (2 min)
make -f Makefile.summit summit

# Stage B: Operator (2 min)
make -f Makefile.summit summit-operator

# Stage C: Failure Demo (1 min)
./scripts/inject_fault.sh edge2 high_latency
# Wait for rollback / 等待回滾
sleep 10

# Stage D: Evidence (1 min)
ls -la reports/$(ls -t reports/ | head -1)/
cat reports/*/manifest.json | jq .summary
```

### 📊 **Success Criteria / 成功標準**
- ✅ All commands execute without errors / 所有命令無錯誤執行
- ✅ Both shell and operator paths work / Shell 和操作器路徑都工作
- ✅ Rollback triggers on fault / 故障時觸發回滾
- ✅ Reports generated automatically / 自動生成報告
- ✅ Audience can follow the flow / 觀眾能夠跟上流程

---

## 🆘 Troubleshooting / 故障排除

### Common Issues / 常見問題

| Problem / 問題 | Solution / 解決方案 | Command / 命令 |
|---------------|-------------------|----------------|
| Script not found / 腳本未找到 | Use alternative / 使用替代方案 | `./scripts/demo_quick.sh` |
| CRD not found / CRD 未找到 | Apply CRDs first / 先應用 CRD | `kubectl apply -f operator/config/crd/` |
| Timeout / 超時 | Increase timeout / 增加超時 | `export TIMEOUT_STEP=600` |
| No metrics / 無指標 | Use mock data / 使用模擬數據 | `export USE_MOCK=true` |

### 🔄 **Quick Recovery / 快速恢復**
```bash
# Reset everything / 重置一切
kubectl delete intentdeployments --all
kubectl delete deployments -l intent-id
rm -rf artifacts/* reports/*

# Start fresh / 重新開始
./scripts/demo_quick.sh
```

---

## 📝 Key Talking Points / 關鍵談話要點

### English
1. **Intent-driven**: "From business intent to deployed infrastructure"
2. **Dual paths**: "Supporting both imperative and declarative approaches"
3. **SLO governance**: "Automatic rollback on policy violations"
4. **Standards**: "TMF921 and 3GPP TS 28.312 compliant"
5. **Production-ready**: "Complete with monitoring and rollback"

### 中文
1. **意圖驅動**："從業務意圖到部署的基礎設施"
2. **雙路徑**："支持命令式和聲明式方法"
3. **SLO 治理**："違反策略時自動回滾"
4. **標準**："符合 TMF921 和 3GPP TS 28.312"
5. **生產就緒**："配備完整的監控和回滾"

---

## ✅ Final Checks / 最終檢查

Before starting the demo / 開始演示前：

- [ ] All scripts are executable / 所有腳本可執行
- [ ] Golden intents are in place / Golden 意圖就位
- [ ] Network connectivity verified / 網絡連接已驗證
- [ ] Previous artifacts cleaned / 之前的工件已清理
- [ ] Backup plan ready / 備份計劃就緒
- [ ] Timer set for 15 minutes / 計時器設置為 15 分鐘

---

## 🎉 Success Message / 成功訊息

When everything completes successfully / 當一切成功完成時：

**English:**
"We have successfully demonstrated an end-to-end intent-driven orchestration pipeline, from natural language intent to deployed infrastructure, with automatic SLO validation and rollback capabilities."

**中文：**
"我們已成功演示了端到端的意圖驅動編排管道，從自然語言意圖到部署的基礎設施，具有自動 SLO 驗證和回滾能力。"

---

**Good luck with your demo! / 祝您演示順利！** 🚀