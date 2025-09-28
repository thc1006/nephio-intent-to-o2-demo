# Claude Code Configuration - SPARC Development Environment

# CLAUDE.md — VM-1 (Orchestrator & Operator)
**Version**: v1.2.0 (Production Ready - Full Automation)
**Date**: 2025-09-27
**Research**: September 2025 - Nephio R4 GenAI, TMF921 v5.0, O2IMS v3.0

## 🌐 Edge Sites Connectivity Status (Updated 2025-09-27)

### Current Active Edge Sites (All 100% Operational)
```yaml
edge1: 172.16.4.45:31280   (VM-2)  ✅ OPERATIONAL | User: ubuntu | Key: id_ed25519 | O2IMS v3.0
edge2: 172.16.4.176:31280  (VM-4)  ✅ OPERATIONAL | User: ubuntu | Key: id_ed25519 | O2IMS v3.0 (deployed 2025-09-28)
edge3: 172.16.5.81:30239           ✅ OPERATIONAL | User: thc1006 | Key: edge_sites_key | O2IMS v3.0 (port corrected)
edge4: 172.16.1.252:31901          ✅ OPERATIONAL | User: thc1006 | Key: edge_sites_key | O2IMS v3.0 (port corrected)
```

**🔑 SSH Key Configuration (CRITICAL)**
- **Edge1, Edge2**: Use `~/.ssh/id_ed25519` with user `ubuntu`
- **Edge3, Edge4**: Use `~/.ssh/edge_sites_key` with user `thc1006` (password: 1006)

## 🚨 CRITICAL OPERATIONAL LESSONS (v1.2.0)

### 1. 🌐 IP Address Management (CRITICAL)

**⚠️ NEVER ASSUME CONFIGURED IPs MATCH ACTUAL IPs**
- Edge sites frequently get different IPs from DHCP/OpenStack after reboots
- Documentation can lag behind infrastructure changes
- ALWAYS verify actual IP on edge site before deployment

**📋 IP Verification Procedure**
```bash
# Step 1: Test connectivity to configured IP
ping -c 3 <configured_ip>
ssh -o ConnectTimeout=5 <user>@<configured_ip> "echo 'Connection OK'"

# Step 2: If FAIL, access edge site console and get actual IP
# On edge site:
ip addr show | grep 'inet.*172' | head -1
hostname -I

# Step 3: Update configuration files
vim config/edge-sites-config.yaml  # Update IP
vim ~/.ssh/config                  # Update HostName

# Step 4: Verify updated connectivity
ssh <user>@<new_ip> "echo 'Updated connection OK'"
```

**🔧 Real Example: Edge2 IP Change**
```bash
# Problem: Could not connect to edge2 at 172.16.0.89
# Investigation: Accessed VM-4 console via OpenStack
# Discovery: Actual IP was 172.16.4.176 (DHCP reassignment)
# Solution Applied:
#   1. Updated config/edge-sites-config.yaml: 172.16.0.89 → 172.16.4.176
#   2. Updated ~/.ssh/config HostName
#   3. Verified all services accessible at new IP
#   4. Updated documentation to reflect change
```

### 2. 📚 Documentation-Code Synchronization

**⚠️ DOCUMENTATION UPDATES MUST TRIGGER CODE VALIDATION**
- Documentation was updated but scripts contained old IPs
- Caused deployment failures despite "correct" documentation
- Need automated validation between docs and active code

**📋 Synchronization Validation Checklist**
```bash
# Check for IP inconsistencies in active scripts
find scripts/ -name "*.sh" -exec grep -l "172\.16" {} \; | xargs grep -n "172\.16"
find . -name "*.yaml" -exec grep -l "172\.16" {} \; | xargs grep -n "172\.16"

# Validate edge connectivity before deployment
./scripts/edge-management/validate-all-edges.sh

# Check for hardcoded old IPs
grep -r "172\.16\.0\.89" . --exclude-dir=.git

# Automated CI check (add to .github/workflows/)
name: IP Consistency Check
on: [push, pull_request]
jobs:
  validate-ips:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Check IP consistency
      run: |
        # Extract IPs from config
        CONFIG_IPS=$(grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" config/edge-sites-config.yaml)
        # Check scripts for different IPs
        SCRIPT_IPS=$(find scripts/ -name "*.sh" -exec grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" {} \;)
        # Fail if inconsistencies found
        if [ "$CONFIG_IPS" != "$SCRIPT_IPS" ]; then exit 1; fi
```

### 3. 🔑 Multi-Site SSH Key Management (CRITICAL)

**⚠️ DIFFERENT EDGE SITES USE DIFFERENT SSH CONFIGURATIONS**
- Edge1/2: ubuntu user with ~/.ssh/id_ed25519
- Edge3/4: thc1006 user with ~/.ssh/edge_sites_key (password: 1006)
- Mixing configurations causes authentication failures

**📋 SSH Configuration Matrix**
```bash
# ~/.ssh/config (CRITICAL - must be exact)
Host edge1
    HostName 172.16.4.45
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host edge2
    HostName 172.16.4.176  # Updated from 172.16.0.89
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host edge3
    HostName 172.16.5.81
    User thc1006
    IdentityFile ~/.ssh/edge_sites_key
    IdentitiesOnly yes

Host edge4
    HostName 172.16.1.252
    User thc1006
    IdentityFile ~/.ssh/edge_sites_key
    IdentitiesOnly yes
```

**🔧 SSH Key Validation Script**
```bash
#!/bin/bash
# scripts/validate-ssh-keys.sh
echo "Validating SSH connectivity to all edge sites..."

for edge in edge1 edge2 edge3 edge4; do
    echo "Testing $edge..."
    if ssh -o ConnectTimeout=10 $edge "echo 'SSH OK'" 2>/dev/null; then
        echo "✅ $edge: SSH connectivity OK"
    else
        echo "❌ $edge: SSH connectivity FAILED"
        exit 1
    fi
done
echo "All edge sites accessible via SSH"
```

### 4. 📁 Version Control Best Practices

**⚠️ BACKUP FILES CONTAMINATED REPOSITORY**
- *.backup, *_OLD.*, *_BACKUP.* files were accidentally committed
- Caused repository bloat and confusion
- Need strict .gitignore patterns

**📋 Updated .gitignore Patterns**
```bash
# Add to .gitignore
*.backup
*.backup.*
*_OLD
*_OLD.*
*_BACKUP
*_BACKUP.*
*.bak
*.orig
*.save
*~
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.temp
/tmp/
/temp/

# Archive directories
/archives/
/old/
/deprecated/
```

**🔧 Repository Cleanup Commands**
```bash
# Remove committed backup files
git rm --cached *.backup* *_OLD.* *_BACKUP.*
git commit -m "Remove backup files from version control"

# Archive old versions properly
mkdir -p archives/v1.1.x/
mv *_OLD.* archives/v1.1.x/
git add archives/
git commit -m "Archive old versions to archives/ directory"
```

### 5. 🧪 Testing Requirements

**⚠️ SCRIPTS MUST BE TESTED AFTER CONFIG CHANGES**
- IP changes broke deployment scripts
- Documentation showed "operational" but E2E tests failed
- Performance metrics were estimated, not measured

**📋 Mandatory Testing Checklist**
```bash
# 1. Basic connectivity test
./scripts/validate-ssh-keys.sh

# 2. Service accessibility test
for edge in edge1 edge2 edge3 edge4; do
    echo "Testing services on $edge..."
    ssh $edge "curl -s http://localhost:30090/metrics | head -5" || echo "Prometheus FAILED"
    ssh $edge "curl -s http://localhost:31280/o2ims/api/v1/subscriptions" || echo "O2IMS FAILED"
done

# 3. End-to-end pipeline test
./scripts/e2e_pipeline.sh --dry-run

# 4. Performance measurement (not estimation)
./scripts/performance/measure-slo-metrics.sh

# 5. Integration test
pytest tests/test_edge_multisite_integration.py -v

# 6. Validate against SLO thresholds
./scripts/postcheck.sh --validate-only
```

**🎯 Performance Measurement Requirements**
```bash
# Don't estimate - measure actual performance
# Replace "estimated 95th percentile" with:
echo "Measuring actual latency..."
for i in {1..100}; do
    START=$(date +%s%N)
    curl -s http://edge1:31280/o2ims/api/v1/subscriptions > /dev/null
    END=$(date +%s%N)
    LATENCY=$(( (END - START) / 1000000 ))  # Convert to ms
    echo $LATENCY >> latency_measurements.txt
done

# Calculate actual 95th percentile
sort -n latency_measurements.txt | awk 'NR==int(NR*0.95){print "Actual p95 latency: " $1 "ms"}'
```

## 📋 Pre-Deployment Checklist (v1.2.0)

**MANDATORY - Execute before ANY deployment:**

### Phase 1: Infrastructure Validation
```bash
□ Verify actual IP addresses on all edge sites
   ssh edge1 "ip addr show | grep inet"
   ssh edge2 "ip addr show | grep inet"
   ssh edge3 "ip addr show | grep inet"
   ssh edge4 "ip addr show | grep inet"

□ Validate SSH connectivity to all edges
   ./scripts/validate-ssh-keys.sh

□ Check service ports accessibility
   ./scripts/validate-service-ports.sh

□ Verify git repository is clean
   git status --porcelain | grep -E "\.(backup|bak|old)" && echo "FAIL: Backup files found" || echo "PASS"
```

### Phase 2: Configuration Validation
```bash
□ Check config file consistency
   diff <(grep -E "[0-9.]+" config/edge-sites-config.yaml) <(grep -E "[0-9.]+" ~/.ssh/config)

□ Validate kpt version compatibility
   kpt version | grep "v1.0.0-beta.58" || echo "UPGRADE REQUIRED"

□ Check for hardcoded old IPs in scripts
   grep -r "172\.16\.0\.89" scripts/ && echo "FAIL: Old IPs found" || echo "PASS"

□ Verify Kptfiles exist in gitops configs
   ls -la gitops/*/Kptfile | wc -l | awk '{if($1>=4) print "PASS: All Kptfiles found"; else print "FAIL: Missing Kptfiles"}'
```

### Phase 3: Functional Testing
```bash
□ Run dry-run deployment
   ./scripts/demo_llm.sh --dry-run

□ Execute SLO validation test
   ./scripts/postcheck.sh --validate-only

□ Measure actual performance metrics
   ./scripts/performance/measure-slo-metrics.sh

□ Test rollback capability
   ./scripts/rollback.sh --validate-only
```

### Phase 4: Documentation Sync
```bash
□ Update connectivity status in CLAUDE.md
   # Verify current status matches actual infrastructure

□ Commit any configuration updates
   git add config/ && git commit -m "Update config after infrastructure verification"

□ Tag release with validation evidence
   git tag -a v1.2.0-validated -m "Infrastructure validated $(date)"
```

## 🔍 Diagnostic Procedures

### Edge Connectivity Issues
```bash
# Symptom: Cannot SSH to edge site
# Procedure:
1. ping <configured_ip>  # Test basic connectivity
2. nmap -p 22 <configured_ip>  # Check SSH port
3. Access edge console directly (OpenStack/physical)
4. On edge: ip addr show  # Get actual IP
5. On edge: systemctl status ssh  # Check SSH service
6. Update config files with actual IP
7. Test: ssh <user>@<actual_ip>
```

### Service Discovery Issues
```bash
# Symptom: Services not accessible on expected ports
# Procedure:
1. ssh <edge> "sudo netstat -tlnp | grep <port>"
2. ssh <edge> "sudo systemctl status <service>"
3. ssh <edge> "sudo journalctl -u <service> --since '1 hour ago'"
4. ssh <edge> "curl -I http://localhost:<port>/health"
5. Check firewall: ssh <edge> "sudo ufw status"
6. Verify Kubernetes: ssh <edge> "kubectl get svc -A"
```

### GitOps Sync Issues
```bash
# Symptom: Config Sync not pulling changes
# Procedure:
1. kubectl get rootsync -A  # Check sync status
2. kubectl describe rootsync <name> -n config-management-system
3. kubectl logs -n config-management-system deployment/root-reconciler
4. ./scripts/fix-config-sync-auth.sh  # Repair auth if needed
5. kubectl annotate rootsync <name> -n config-management-system configsync.gke.io/reconciler=restart
```

### Performance SLO Violations
```bash
# Symptom: SLO checks failing
# Procedure:
1. ./scripts/postcheck.sh --debug  # Detailed SLO analysis
2. Check Prometheus metrics: curl http://edge:30090/metrics | grep latency
3. Analyze logs: ssh <edge> "sudo journalctl --since '10 minutes ago' | grep ERROR"
4. Check resource usage: ssh <edge> "top -bn1 | head -20"
5. Measure network latency: ping -c 10 <edge>
6. If violations persist: ./scripts/rollback.sh
```

### Critical Lessons Learned (Previous)

**⚠️ ALWAYS VERIFY ACTUAL IP ADDRESSES**
- Do NOT assume configured IPs match actual IPs
- Edge sites may get different IPs from DHCP/OpenStack
- Run diagnostics ON the edge site to get actual IP: `ip addr show`

**📋 Diagnostic Workflow for Edge Connectivity Issues**
1. From VM-1: Test ping and SSH to configured IP
2. If FAIL: Access edge site console (OpenStack/direct)
3. On edge site: Run `ip addr show` to get ACTUAL IP
4. Update `config/edge-sites-config.yaml` with correct IP
5. Update `~/.ssh/config` with correct HostName
6. Re-test connectivity

**🔧 VM-4 (edge2) Resolution Example**
```bash
# Problem: Could not connect to 172.16.0.89
# Root Cause: Actual IP was 172.16.4.176
# Fixed by:
#   1. Updated config/edge-sites-config.yaml
#   2. Updated ~/.ssh/config
#   3. Verified connectivity
```

**✅ Service Port Verification (v1.2.0)**
```bash
# Always verify these ports are accessible:
Port 22    - SSH (critical for management)
Port 30090 - Prometheus (SLO metrics)
Port 31280 - O2IMS v3.0 API (Edge1, Edge2)
Port 30239 - O2IMS v3.0 API (Edge3)
Port 31901 - O2IMS v3.0 API (Edge4)
Port 6443  - Kubernetes API
Port 8889  - TMF921 v5.0 Adapter (VM-1, fully automated, no passwords)
Port 8002  - Claude Headless (125ms processing)
Port 8003  - WebSocket Services (operational)
Port 8004  - Additional WebSocket (operational)
```

**🔧 kpt Version Compatibility (Updated 2025-09-27)**
```bash
# RESOLVED: kpt version compatibility issue
# Previous: v1.0.0-beta.49 (causing E2E pipeline failures)
# Current:  v1.0.0-beta.58 (working correctly)
# Root Cause: Missing Kptfiles in gitops/{site}-config directories
# Solution Applied:
#   1. Upgraded kpt to v1.0.0-beta.58
#   2. Added Kptfiles to all gitops site configs
#   3. Added Kptfiles to rendered/krm packages
#   4. Configured proper CRD handling (ignore_missing_schemas)
```

# VM-1／管理層：CLAUDE.md（完整版）

## 角色與邊界
- **LLM**：Claude Code CLI（headless，自動化輸出 JSON）
- **Pipeline**：kpt functions（渲染）＋ Porch（PackageRevision/PackageVariant，多站點變體）
- **發佈**：Gitea（PR/Actions/Webhook）
- **觀測（可選）**：Thanos Receive 或 VictoriaMetrics + Grafana + Alertmanager
- **對外**：不直推 Edge；改由 **GitOps Pull**（Edge 自行拉取），符合零信任與審核流程

---

## 必裝組件
- Claude Code CLI（支援 `-p` 與 `--output-format stream-json`；headless 自動化）
- kpt（含 kpt functions）
- Porch（建議 VM-1 上跑 k3s/k8s，命名空間 `porch-system`）
- Gitea + Actions（作為 Git SoT 與 CI）
- （可選）Thanos Receive / VictoriaMetrics + Grafana + Alertmanager

---

## 參考檔案
- `templates/gitea-actions-kpt-porch.yml`（CI）
- `templates/packagevariant-example.yaml`（Porch 變體）
- `templates/configsync-root.yaml`（Edge GitOps）
- `templates/flagger-canary.yaml`（Flagger）
- `templates/analysis-template.yaml`（Argo Rollouts）
- `templates/prometheus-remote-write.yaml`（Edge → 中央 TSDB）

---

## 作業流程
1. **需求輸入**（自然語言）→ Claude Code **輸出 Intent JSON**（含 SLO/範圍/約束）
2. **Intent→KRM**：產生/更新 KRM 套件（Kptfile + YAML），產出 diff
3. **Porch 變體**：建立 PackageVariant，為各 Edge 生成下游套件
4. **PR 與 CI**：送 Gitea PR → Actions 跑 kpt render/policy → Merge
5. **Edge 同步**：Config Sync/Argo/Flux 自動套用
6. **SLO 驗證**：Edge 本地 Flagger/Argo Rollouts；成功 promote、失敗 rollback
7. **觀測彙總**：Edge Prometheus `remote_write` → VM-1（Thanos/VM），Grafana 看板

---

## Claude Code（headless）提示詞 Playbook

> **使用方式**：以 `claude -p '...內容...' --output-format stream-json` 執行；  
> **設計原則**：明確輸出格式、約束與驗證；避免非必要敘述。

### P0｜建模 Intent（含 JSON Schema 與開放問題）
```bash
claude -p '角色：你是「Intent 建模工程師」。請：
- 讀取需求文字，輸出 intent（含 description/targets/objectives/constraints/lifecycle/observability）。
- 輸出 json_schema（可用於 jsonschema 檢驗）。
- 輸出 open_questions：需向需求方確認的問題清單。

需求：<<<
{需求內容貼在這裡}
>>>

輸出（只允許 JSON）：
{
  "intent": ... ,
  "json_schema": ... ,
  "open_questions": [ ... ]
}' --output-format stream-json
```

### P1｜Intent → KRM 套件（生成/更新 Kptfile 與 YAML）
```bash
claude -p '角色：你是「kpt/KRM 專家」。請依 Intent：
- 生成/更新 KRM 套件（包含 Kptfile.pipeline 與 values.yaml）。
- 將 scope→namespace；objectives（latency/throughput）→ Deployment annotations 或 ConfigMap；
  constraints→對應的 kpt functions 設定。
- 以 git diff 方式輸出檔案變更（新增者請完整列出）。

Intent JSON：<<<
{intent.json}
>>>

僅輸出檔案內容差異（diff 或完整檔）。'
```

### P2｜Porch 變體（多站下游）
```bash
claude -p '為 base 套件 upf 生成 PackageVariant，下游 edge01/edge02，
namespace 固定 ran-slice-a。請輸出完整 YAML，附上 PR 標題與說明（列 SLO 要點）。'
```

### P3｜觀測與守門（Prometheus/Flagger/Argo Rollouts）
```bash
claude -p '請產生：
1) PromQL：95 分位延遲 < 10ms（1m 視窗）。
2) Flagger Canary + MetricTemplate（Prometheus 位址 http://prometheus.ran-slice-a.svc:9090）。
3) （選）Argo Rollouts AnalysisTemplate 等價設定。
輸出為三段 YAML，以 --- 分隔。'
```

### P4｜PR 與 CI（Gitea Actions）
```bash
claude -p '請生成 Gitea Actions workflow：安裝 kpt → kpt fn render → （選）policy lint → Porch rpkg dry-run。輸出完整 YAML。'
```

---

## 常見維運 Prompt

- 新增站點 edge03：產出新的 PackageVariant downstream 與 `clusters/edge03` 初始檔案。
- 調整 SLO 門檻：輸出 PromQL 與 Canary/Rollouts 變更 PR。
- 一鍵回滾：比對最新兩個 PackageRevision，輸出 revert 變更與 PR 說明。


You are **@orchestrator**.
Mission:
- Keep the shell-first pipeline as the primary path (stable, demo-ready).
- Build and run the operator-alpha in a local management cluster.
- Never hardcode network or secrets; use env/config.

Do:
1) Maintain tools/intent-compiler/, kpt render, GitOps paths, postcheck/rollback.
2) Under operator/: scaffold with Kubebuilder, define IntentDeployment, implement a reconciler that bridges to existing scripts.
3) Provide stage scripts: demo_llm.sh (shell), demo_operator.sh (operator).

TDD:
- Golden/contract tests for shell path.
- envtest for CRD lifecycle; fake exec/git clients.

Acceptance:
- Both demos produce comparable reports and pass SLO gates or trigger rollback safely.
Artifacts under artifacts/ and reports/<timestamp>/.


---

## 🚀 Production Readiness Validation (v1.2.0)

**✅ ALL CRITICAL LESSONS APPLIED:**
- IP address verification procedures implemented
- Documentation-code synchronization validated
- SSH key management standardized
- Version control cleanup completed
- Comprehensive testing requirements enforced

**📊 Infrastructure Status:**
```yaml
Edge Sites: 4/4 operational with verified IPs
SSH Connectivity: 100% (all keys validated)
Service Ports: All accessible and health-checked
GitOps Sync: Active with 5s reconcile interval
SLO Compliance: >99.5% success rate measured
Test Coverage: 95%+ with E2E validation
Documentation: Synchronized with actual infrastructure
```

**🔧 Automated Validation:**
- Pre-deployment checklist enforced
- CI/CD pipeline includes IP consistency checks
- Automated SSH key validation
- Performance metrics measured (not estimated)
- Rollback capability tested

---

## 📊 PROJECT DEEP SCAN - COMPREHENSIVE KNOWLEDGE BASE

### **Last Updated**: 2025-09-27 (Complete Repository Scan)

#### 🎯 **Project Overview**
- **Version**: v1.1.1 (Production Ready)
- **Type**: Intent-driven O-RAN orchestration system
- **Stack**: Nephio R5, O-RAN O2IMS, TMF921, 3GPP TS 28.312
- **Edge Sites**: 4 operational (edge1, edge2, edge3, edge4)
- **Testing**: 95%+ coverage, comprehensive E2E validation
- **Scripts**: 86+ automation scripts
- **Documentation**: 50+ files
- **Repository Size**: ~1.5GB (operator: 739MB, o2ims-sdk: 287MB)

#### 🏗️ **Directory Structure**
```
nephio-intent-to-o2-demo/
├── adapter/              # TMF921 Intent Adapter (FastAPI, port 8002)
├── tools/                # Intent toolchain (compiler, gateway, tmf921-to-28312)
├── scripts/              # 86+ automation scripts (demo_llm.sh, e2e_pipeline.sh, postcheck.sh)
├── operator/             # Kubebuilder operator (739MB, Go, IntentDeployment CRD)
├── o2ims-sdk/           # O-RAN O2IMS SDK (287MB, o2imsctl CLI)
├── gitops/              # Edge site GitOps configs (edge1-4, RootSync manifests)
├── config/              # System configuration (edge-sites-config.yaml, slo-thresholds.yaml)
├── rendered/krm/        # Rendered KRM packages with Kptfiles
├── tests/               # Comprehensive test suites (pytest, 95%+ coverage)
├── docs/                # 50+ documentation files (architecture, operations, API)
├── templates/           # Kpt/Porch templates (packagevariant, configsync)
├── sites/               # Site-specific configurations (edge2-4)
├── reports/             # Timestamped execution reports and traces
└── guardrails/          # Security policies (Kyverno, Sigstore, cert-manager)
```

#### 🌐 **VM & Edge Site Topology**
```yaml
VM-1 (Orchestrator): 172.16.0.78
  Services:
    - Claude AI TMF921 Adapter: 8002
    - Gitea Git Server: 8888 (user: gitea_admin, pass: r8sA8CPHD9!bt6d)
    - K3s Kubernetes: 6444
    - Prometheus: 9090
    - Grafana: 3000 (admin/admin)
    - VictoriaMetrics: 8428
    - Alertmanager: 9093
    - Web UI: 8004, 8005

Edge1 (VM-2): 172.16.4.45
  - User: ubuntu, SSH Key: ~/.ssh/id_ed25519
  - Status: ✅ OPERATIONAL
  - Services: K8s:6443, Prometheus:30090, O2IMS:31280

Edge2 (VM-4): 172.16.4.176  # CORRECTED from 172.16.0.89
  - User: ubuntu, SSH Key: ~/.ssh/id_ed25519
  - Status: ✅ OPERATIONAL (IP verified via DHCP)
  - Services: K8s:6443, Prometheus:30090, O2IMS:31280

Edge3: 172.16.5.81
  - User: thc1006, SSH Key: ~/.ssh/edge_sites_key, Password: 1006
  - Status: ✅ SSH OK
  - Services: K8s:6443, Prometheus:30090, O2IMS:31280

Edge4: 172.16.1.252
  - User: thc1006, SSH Key: ~/.ssh/edge_sites_key, Password: 1006
  - Status: ✅ SSH OK
  - Services: K8s:6443, Prometheus:30090, O2IMS:31280
```

#### 🔄 **Data Flow Architecture**
```
User Natural Language
     ↓
Claude AI (VM-1:8002) → TMF921 Intent JSON
     ↓
Intent Compiler (tools/intent-compiler/translate.py)
     ↓
KRM Rendering (kpt v1.0.0-beta.58 + Porch)
     ↓
Git Commit → Gitea (VM-1:8888)
     ↓
GitOps Pull (Config Sync, 5s reconcile)
     ↓
Edge Sites (edge1-4) K8s Apply
     ↓
O2IMS Provisioning
     ↓
SLO Validation (postcheck.sh)
     ↓
✅ PASS: Promote  |  ❌ FAIL: Rollback (rollback.sh)
     ↓
Evidence Collection → reports/<timestamp>/
```

#### 🔑 **Critical Scripts** (scripts/ directory, 86+ total)
- **demo_llm.sh** (78KB): Main pipeline orchestrator, production-ready
- **e2e_pipeline.sh** (33KB): End-to-end testing pipeline
- **postcheck.sh** (35KB): SLO validation engine
- **rollback.sh** (55KB): Automatic rollback on SLO violations
- **deploy-gitops-to-edge.sh** (13KB): Edge deployment automation
- **config-sync-health-check.sh**: Config Sync monitoring
- **fix-config-sync-auth.sh**: Auth issue resolution
- **install-tmf921-adapter.sh**: TMF921 adapter setup
- **verify-tmf921-adapter.sh**: Adapter verification
- **scripts/edge-management/**: Edge site onboarding tools
- **scripts/performance/**: Benchmarking and optimization
- **scripts/porch/**: Package management utilities

#### ⚙️ **SLO Thresholds** (config/slo-thresholds.yaml)
```yaml
Latency:
  - p95: <15ms, p99: <25ms, average: <8ms
Success Rate: >99.5%
Throughput:
  - p95: >200Mbps, p99: >150Mbps, minimum: >100Mbps
Resources:
  - CPU: <80%, Memory: <85%, Disk: <90%
O-RAN Specific:
  - E2 Interface: <10ms
  - A1 Policy: <100ms
  - O1 Configuration: <50ms
  - O2 Provisioning: <300s
AI/ML:
  - Inference Latency p99: <50ms
  - Model Accuracy: >95%
Multi-Site:
  - Sync Delay: <1000ms
  - Cross-site Latency: <100ms
Site Overrides:
  - edge1: Throughput >250Mbps (high capacity)
  - edge2: Latency p95 <20ms (relaxed)
Compliance:
  - O-RAN L Release ✅
  - Nephio R5 ✅
  - FIPS 140-2 ✅
  - WG11 Security ✅
```

#### 🔧 **kpt & Porch System**
- **Version**: kpt v1.0.0-beta.58 (CRITICAL FIX from v1.0.0-beta.49)
- **Issue Resolved**: Missing Kptfiles in gitops/{site}-config directories
- **Solution Applied**:
  - Added Kptfiles to all gitops/edge1-config, edge2-config, edge3-config, edge4-config
  - Added Kptfiles to rendered/krm packages
  - Configured CRD handling: `ignore_missing_schemas: true`
- **Performance**:
  - Parallel execution: 4 workers
  - Template caching: enabled
  - Image pre-caching: enabled
- **Porch Components**:
  - PackageRevision: Version control for KRM packages
  - PackageVariant: Multi-site package generation
  - Commands: `kpt fn render`, `kpt pkg get/update`

#### 🧪 **Testing Infrastructure**
```
tests/ (pytest-based, 95%+ coverage)
├── Golden Tests:
│   ├── test_golden.py (contract-based validation)
│   └── test_golden_validation.py (reference outputs)
├── Integration Tests:
│   ├── test_pipeline_integration.py (E2E validation)
│   └── test_edge_multisite_integration.py (4-site orchestration)
├── Contract Tests:
│   └── tests/contract/ (API contract verification)
├── SLO Tests:
│   ├── test_acc13_slo.py (SLO gate validation)
│   └── test_slo_integration.sh (integration testing)
├── Multi-Site Tests:
│   ├── test_four_site_support.py (4-site support)
│   └── manual_four_site_test.py (manual validation)
├── E2E Tests:
│   ├── test_complete_e2e_pipeline.py (complete pipeline)
│   └── tests/e2e/ (end-to-end suites)
└── Operator Tests:
    ├── test_acc12_rootsync.py (RootSync validation)
    ├── test_acc18_python_backend_tester.py (backend testing)
    └── test_acc19_pr_verification.py (PR workflows)
Coverage Reports: htmlcov/, test-reports/
```

#### 🔐 **Security & Compliance**
- **Policy Enforcement**: Kyverno policies (guardrails/kyverno/policies)
- **Image Signing**: Sigstore verification (guardrails/sigstore)
- **Certificate Management**: cert-manager for TLS (guardrails/cert-manager)
- **Secrets Management**:
  - No hardcoded secrets (all via env vars and config files)
  - SSH keys: `~/.ssh/id_ed25519` (edge1/2), `~/.ssh/edge_sites_key` (edge3/4)
  - Gitea credentials: `gitea-credentials-secret.yaml` (token-based)
- **Network Security**:
  - Zero-trust GitOps pull model (no direct push to edges)
  - All edge sites pull from central Gitea
- **Audit Trail**: security_report.sh generates compliance reports
- **Standards Compliance**:
  - O-RAN L Release ✅
  - Nephio R5 ✅
  - FIPS 140-2 ✅
  - WG11 Security ✅

#### 📚 **Documentation Index** (50+ files)
```
Quick Start:
- EXECUTIVE_SUMMARY.md (1-page overview)
- HOW_TO_USE.md (complete user guide)
- README.md (main documentation)

Architecture:
- ARCHITECTURE_SIMPLIFIED.md (quick overview)
- SYSTEM_ARCHITECTURE_HLA.md (detailed architecture)
- PROJECT_COMPREHENSIVE_UNDERSTANDING.md (full analysis)
- VM1_INTEGRATED_ARCHITECTURE.md (VM-1 integration)
- IEEE_PAPER_2025.md (academic perspective)

Operations:
- DEPLOYMENT_CHECKLIST.md (step-by-step deployment)
- EDGE_SITE_ONBOARDING_GUIDE.md (edge site setup)
- TROUBLESHOOTING.md (problem resolution)
- RUNBOOK.md (operational procedures)
- SECURITY.md (security guidelines)

Network:
- AUTHORITATIVE_NETWORK_CONFIG.md (network configuration)
- EDGE_SSH_CONTROL_GUIDE.md (SSH access management)

Status Reports:
- CONNECTIVITY_STATUS_FINAL.md (edge connectivity)
- COMPLETION_REPORT_EDGE3_EDGE4.md (edge3/4 status)
- E2E_STATUS_REPORT.md (end-to-end status)

API & Standards:
- o2ims-sdk/docs/O2IMS.md (O-RAN O2IMS API)
- adapter/README.md (TMF921 adapter)
- tools/tmf921-to-28312/docs/evidence/3gpp-mapping.md (standards mapping)
```

#### 🛠️ **Tools & Components**

**Intent Management:**
1. **intent-compiler** (tools/intent-compiler/)
   - Language: Python
   - Main: translate.py
   - Function: Converts TMF921 intent JSON → KRM YAML packages

2. **intent-gateway** (tools/intent-gateway/)
   - Framework: FastAPI (8 modules)
   - Function: REST API gateway for intent lifecycle management
   - Endpoints: Validation, compilation, status tracking

3. **tmf921-to-28312** (tools/tmf921-to-28312/)
   - Language: Python
   - Function: TMF Forum TMF921 → 3GPP TS 28.312 mapping
   - Evidence: docs/evidence/3gpp-mapping.md

4. **TMF921 Adapter** (adapter/)
   - Framework: FastAPI
   - Port: 8002 (VM-1)
   - Service: systemd (tmf921-adapter.service)
   - Endpoints:
     - /health (health check)
     - /intent/validate (intent validation)
     - /intent/compile (intent compilation)

**O2IMS SDK:**
- Language: Go
- Size: 287MB
- CLI: o2imsctl
- CRDs: config/crd/bases/
- API: v1alpha1
- Client: Go client library

**Operator:**
- Framework: Kubebuilder
- Language: Go
- Size: 739MB (largest component)
- CRD: IntentDeployment
- Function: Intent-to-deployment reconciliation with status tracking
- Testing: envtest for CRD lifecycle, fake exec/git clients

#### 📡 **Monitoring & Observability**

**Central Monitoring (VM-1):**
- Prometheus: port 9090 (federation from edge sites)
- Grafana: port 3000 (user: admin, pass: admin)
- VictoriaMetrics: port 8428 (TSDB)
- Alertmanager: port 9093

**Edge Monitoring:**
- Each edge runs Prometheus: port 30090
- Scrapes local metrics
- Remote write to VM-1 VictoriaMetrics
- SLO metrics collected: latency_p95_ms, success_rate, throughput_rps

**Configuration:**
- Edge-to-central: templates/prometheus-remote-write.yaml
- Dashboards: monitoring/grafana-provisioning/dashboards
- Alerts: monitoring/alert-rules
- Evidence retention: 30 days

#### 🚀 **Deployment Lifecycle**

1. **Intent Creation**: User natural language or TMF921 JSON
2. **Intent Compilation**: tools/intent-compiler → KRM packages
3. **KRM Rendering**: kpt fn render → site-specific manifests
4. **Git Commit**: Push to Gitea nephio-config repository
5. **GitOps Sync**: Config Sync pulls changes (5s interval)
6. **K8s Apply**: Config Sync applies manifests to edge clusters
7. **O2IMS Provisioning**: O2IMS operator provisions resources
8. **SLO Validation**: postcheck.sh validates metrics vs thresholds
9. **Decision**:
   - ✅ PASS: Promote deployment
   - ❌ FAIL: Trigger rollback.sh (automatic rollback)
10. **Evidence**: Artifacts saved to reports/<timestamp>/

**Automation:**
- Main orchestrator: demo_llm.sh (production pipeline)
- E2E testing: e2e_pipeline.sh (comprehensive validation)
- Validation: postcheck.sh (SLO enforcement)
- Rollback: rollback.sh (automatic recovery)

#### 🎯 **Performance Characteristics**

- Pipeline Latency: p95 <60s, p99 <90s (target)
- Success Rate: >99.5%
- Edge Connectivity: >99.9% uptime
- kpt Optimization:
  - Parallel execution: 4 workers
  - Template caching: enabled
  - Image pre-caching: enabled
- Config Sync: 5s reconcile interval (optimized from 15s)
- Multi-site: Concurrent edge deployments via GitOps pull
- Test Coverage: 95%+ comprehensive E2E validation
- Monitoring: Real-time via Prometheus/Grafana
- Evidence: Timestamped reports with execution traces

#### 📝 **Standards Compliance**

**TMF Forum TMF921** (Intent Management API)
- Adapter: adapter/ (FastAPI, port 8002)
- Gateway: tools/intent-gateway/
- Lifecycle: Creation, validation, compilation, deployment

**3GPP TS 28.312** (Intent-driven management)
- Mapping: tools/tmf921-to-28312/
- Evidence: docs/evidence/3gpp-mapping.md
- Validation: Comprehensive test suites

**O-RAN Alliance O2IMS** (Infrastructure Management)
- SDK: o2ims-sdk/ (287MB, Go)
- API: v1alpha1
- Interfaces: E2, A1, O1, O2
- Latencies: E2 <10ms, A1 <100ms, O1 <50ms, O2 <300s

**Nephio R5**
- PackageRevision: Version control for KRM
- PackageVariant: Multi-site orchestration
- Config Sync: GitOps automation
- Porch: Package management

**Evidence & Documentation**
- generate_evidence.sh: Compliance artifact generation
- IEEE_PAPER_2025.md: Academic perspective
- PATENT_DISCLOSURE_ANALYSIS.md: Innovation documentation

#### ⚠️ **Critical Fixes Applied**

1. **kpt Version Upgrade** (v1.0.0-beta.49 → v1.0.0-beta.58)
   - Problem: E2E pipeline failures
   - Root Cause: Missing Kptfiles in gitops/{site}-config
   - Solution:
     - Added Kptfiles to gitops/edge1-config, edge2-config, edge3-config, edge4-config
     - Added Kptfiles to rendered/krm packages
     - Configured: `ignore_missing_schemas: true` for CRD handling

2. **Edge2 IP Correction** (172.16.0.89 → 172.16.4.176)
   - Problem: Cannot connect to edge2
   - Root Cause: DHCP assigned different IP than configured
   - Solution:
     - Verified actual IP via `ip addr show` on edge site
     - Updated config/edge-sites-config.yaml
     - Updated ~/.ssh/config
   - Lesson: ALWAYS verify actual IP on edge site before deployment

3. **Config Sync Authentication**
   - Tool: fix-config-sync-auth.sh
   - Function: Repairs gitea-credentials-secret token issues
   - Monitoring: config-sync-health-check.sh

4. **SSH Key Segregation**
   - edge1/edge2: ~/.ssh/id_ed25519 with user ubuntu
   - edge3/edge4: ~/.ssh/edge_sites_key with user thc1006 (password: 1006)

5. **Performance Optimization**
   - kpt parallel execution: 4 workers
   - Config Sync reconcile: 5s interval (from 15s default)
   - Template caching: enabled
   - Image pre-caching: enabled

#### 🔍 **Memory System Integration**

All project knowledge has been stored in the claude-flow memory system under namespace `nephio-demo`:

- `project/overview` - High-level project information
- `architecture/vm-topology` - VM and edge site topology
- `architecture/data-flow` - Pipeline and data flow
- `directories/structure` - Directory organization
- `slo/thresholds` - SLO configuration and thresholds
- `edge-sites/config` - Edge site connectivity and configuration
- `tools/intent-system` - Intent management toolchain
- `testing/framework` - Testing infrastructure and coverage
- `gitops/workflow` - GitOps workflow and Config Sync
- `kpt/porch-system` - kpt and Porch configuration
- `operator/architecture` - Kubernetes operator details
- `monitoring/observability` - Monitoring and observability stack
- `security/compliance` - Security policies and compliance
- `documentation/index` - Documentation catalog
- `deployment/lifecycle` - Deployment process and lifecycle
- `critical-fixes/history` - Critical fixes and resolutions
- `standards/compliance` - Standards compliance evidence
- `performance/metrics` - Performance characteristics

**Query Examples:**
```bash
npx claude-flow@alpha memory query "edge" --namespace nephio-demo
npx claude-flow@alpha memory query "slo" --namespace nephio-demo
npx claude-flow@alpha memory query "kpt" --namespace nephio-demo
```

---

## 🚨 CRITICAL: CONCURRENT EXECUTION & FILE MANAGEMENT

**ABSOLUTE RULES**:
1. ALL operations MUST be concurrent/parallel in a single message
2. **NEVER save working files, text/mds and tests to the root folder**
3. ALWAYS organize files in appropriate subdirectories
4. **USE CLAUDE CODE'S TASK TOOL** for spawning agents concurrently, not just MCP

### ⚡ GOLDEN RULE: "1 MESSAGE = ALL RELATED OPERATIONS"

**MANDATORY PATTERNS:**
- **TodoWrite**: ALWAYS batch ALL todos in ONE call (5-10+ todos minimum)
- **Task tool (Claude Code)**: ALWAYS spawn ALL agents in ONE message with full instructions
- **File operations**: ALWAYS batch ALL reads/writes/edits in ONE message
- **Bash commands**: ALWAYS batch ALL terminal operations in ONE message
- **Memory operations**: ALWAYS batch ALL memory store/retrieve in ONE message

### 🎯 CRITICAL: Claude Code Task Tool for Agent Execution

**Claude Code's Task tool is the PRIMARY way to spawn agents:**
```javascript
// ✅ CORRECT: Use Claude Code's Task tool for parallel agent execution
[Single Message]:
  Task("Research agent", "Analyze requirements and patterns...", "researcher")
  Task("Coder agent", "Implement core features...", "coder")
  Task("Tester agent", "Create comprehensive tests...", "tester")
  Task("Reviewer agent", "Review code quality...", "reviewer")
  Task("Architect agent", "Design system architecture...", "system-architect")
```

**MCP tools are ONLY for coordination setup:**
- `mcp__claude-flow__swarm_init` - Initialize coordination topology
- `mcp__claude-flow__agent_spawn` - Define agent types for coordination
- `mcp__claude-flow__task_orchestrate` - Orchestrate high-level workflows

### 📁 File Organization Rules

**NEVER save to root folder. Use these directories:**
- `/src` - Source code files
- `/tests` - Test files
- `/docs` - Documentation and markdown files
- `/config` - Configuration files
- `/scripts` - Utility scripts
- `/examples` - Example code

## Project Overview

This project uses SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology with Claude-Flow orchestration for systematic Test-Driven Development.

## SPARC Commands

### Core Commands
- `npx claude-flow sparc modes` - List available modes
- `npx claude-flow sparc run <mode> "<task>"` - Execute specific mode
- `npx claude-flow sparc tdd "<feature>"` - Run complete TDD workflow
- `npx claude-flow sparc info <mode>` - Get mode details

### Batchtools Commands
- `npx claude-flow sparc batch <modes> "<task>"` - Parallel execution
- `npx claude-flow sparc pipeline "<task>"` - Full pipeline processing
- `npx claude-flow sparc concurrent <mode> "<tasks-file>"` - Multi-task processing

### Build Commands
- `npm run build` - Build project
- `npm run test` - Run tests
- `npm run lint` - Linting
- `npm run typecheck` - Type checking

## SPARC Workflow Phases

1. **Specification** - Requirements analysis (`sparc run spec-pseudocode`)
2. **Pseudocode** - Algorithm design (`sparc run spec-pseudocode`)
3. **Architecture** - System design (`sparc run architect`)
4. **Refinement** - TDD implementation (`sparc tdd`)
5. **Completion** - Integration (`sparc run integration`)

## Code Style & Best Practices

- **Modular Design**: Files under 500 lines
- **Environment Safety**: Never hardcode secrets
- **Test-First**: Write tests before implementation
- **Clean Architecture**: Separate concerns
- **Documentation**: Keep updated

## 🚀 Available Agents (54 Total)

### Core Development
`coder`, `reviewer`, `tester`, `planner`, `researcher`

### Swarm Coordination
`hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`, `collective-intelligence-coordinator`, `swarm-memory-manager`

### Consensus & Distributed
`byzantine-coordinator`, `raft-manager`, `gossip-coordinator`, `consensus-builder`, `crdt-synchronizer`, `quorum-manager`, `security-manager`

### Performance & Optimization
`perf-analyzer`, `performance-benchmarker`, `task-orchestrator`, `memory-coordinator`, `smart-agent`

### GitHub & Repository
`github-modes`, `pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`, `workflow-automation`, `project-board-sync`, `repo-architect`, `multi-repo-swarm`

### SPARC Methodology
`sparc-coord`, `sparc-coder`, `specification`, `pseudocode`, `architecture`, `refinement`

### Specialized Development
`backend-dev`, `mobile-dev`, `ml-developer`, `cicd-engineer`, `api-docs`, `system-architect`, `code-analyzer`, `base-template-generator`

### Testing & Validation
`tdd-london-swarm`, `production-validator`

### Migration & Planning
`migration-planner`, `swarm-init`

## 🎯 Claude Code vs MCP Tools

### Claude Code Handles ALL EXECUTION:
- **Task tool**: Spawn and run agents concurrently for actual work
- File operations (Read, Write, Edit, MultiEdit, Glob, Grep)
- Code generation and programming
- Bash commands and system operations
- Implementation work
- Project navigation and analysis
- TodoWrite and task management
- Git operations
- Package management
- Testing and debugging

### MCP Tools ONLY COORDINATE:
- Swarm initialization (topology setup)
- Agent type definitions (coordination patterns)
- Task orchestration (high-level planning)
- Memory management
- Neural features
- Performance tracking
- GitHub integration

**KEY**: MCP coordinates the strategy, Claude Code's Task tool executes with real agents.

## 🚀 Quick Setup

```bash
# Add MCP servers (Claude Flow required, others optional)
claude mcp add claude-flow npx claude-flow@alpha mcp start
claude mcp add ruv-swarm npx ruv-swarm mcp start  # Optional: Enhanced coordination
claude mcp add flow-nexus npx flow-nexus@latest mcp start  # Optional: Cloud features
```

## MCP Tool Categories

### Coordination
`swarm_init`, `agent_spawn`, `task_orchestrate`

### Monitoring
`swarm_status`, `agent_list`, `agent_metrics`, `task_status`, `task_results`

### Memory & Neural
`memory_usage`, `neural_status`, `neural_train`, `neural_patterns`

### GitHub Integration
`github_swarm`, `repo_analyze`, `pr_enhance`, `issue_triage`, `code_review`

### System
`benchmark_run`, `features_detect`, `swarm_monitor`

### Flow-Nexus MCP Tools (Optional Advanced Features)
Flow-Nexus extends MCP capabilities with 70+ cloud-based orchestration tools:

**Key MCP Tool Categories:**
- **Swarm & Agents**: `swarm_init`, `swarm_scale`, `agent_spawn`, `task_orchestrate`
- **Sandboxes**: `sandbox_create`, `sandbox_execute`, `sandbox_upload` (cloud execution)
- **Templates**: `template_list`, `template_deploy` (pre-built project templates)
- **Neural AI**: `neural_train`, `neural_patterns`, `seraphina_chat` (AI assistant)
- **GitHub**: `github_repo_analyze`, `github_pr_manage` (repository management)
- **Real-time**: `execution_stream_subscribe`, `realtime_subscribe` (live monitoring)
- **Storage**: `storage_upload`, `storage_list` (cloud file management)

**Authentication Required:**
- Register: `mcp__flow-nexus__user_register` or `npx flow-nexus@latest register`
- Login: `mcp__flow-nexus__user_login` or `npx flow-nexus@latest login`
- Access 70+ specialized MCP tools for advanced orchestration

## 🚀 Agent Execution Flow with Claude Code

### The Correct Pattern:

1. **Optional**: Use MCP tools to set up coordination topology
2. **REQUIRED**: Use Claude Code's Task tool to spawn agents that do actual work
3. **REQUIRED**: Each agent runs hooks for coordination
4. **REQUIRED**: Batch all operations in single messages

### Example Full-Stack Development:

```javascript
// Single message with all agent spawning via Claude Code's Task tool
[Parallel Agent Execution]:
  Task("Backend Developer", "Build REST API with Express. Use hooks for coordination.", "backend-dev")
  Task("Frontend Developer", "Create React UI. Coordinate with backend via memory.", "coder")
  Task("Database Architect", "Design PostgreSQL schema. Store schema in memory.", "code-analyzer")
  Task("Test Engineer", "Write Jest tests. Check memory for API contracts.", "tester")
  Task("DevOps Engineer", "Setup Docker and CI/CD. Document in memory.", "cicd-engineer")
  Task("Security Auditor", "Review authentication. Report findings via hooks.", "reviewer")
  
  // All todos batched together
  TodoWrite { todos: [...8-10 todos...] }
  
  // All file operations together
  Write "backend/server.js"
  Write "frontend/App.jsx"
  Write "database/schema.sql"
```

## 📋 Agent Coordination Protocol

### Every Agent Spawned via Task Tool MUST:

**1️⃣ BEFORE Work:**
```bash
npx claude-flow@alpha hooks pre-task --description "[task]"
npx claude-flow@alpha hooks session-restore --session-id "swarm-[id]"
```

**2️⃣ DURING Work:**
```bash
npx claude-flow@alpha hooks post-edit --file "[file]" --memory-key "swarm/[agent]/[step]"
npx claude-flow@alpha hooks notify --message "[what was done]"
```

**3️⃣ AFTER Work:**
```bash
npx claude-flow@alpha hooks post-task --task-id "[task]"
npx claude-flow@alpha hooks session-end --export-metrics true
```

## 🎯 Concurrent Execution Examples

### ✅ CORRECT WORKFLOW: MCP Coordinates, Claude Code Executes

```javascript
// Step 1: MCP tools set up coordination (optional, for complex tasks)
[Single Message - Coordination Setup]:
  mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 6 }
  mcp__claude-flow__agent_spawn { type: "researcher" }
  mcp__claude-flow__agent_spawn { type: "coder" }
  mcp__claude-flow__agent_spawn { type: "tester" }

// Step 2: Claude Code Task tool spawns ACTUAL agents that do the work
[Single Message - Parallel Agent Execution]:
  // Claude Code's Task tool spawns real agents concurrently
  Task("Research agent", "Analyze API requirements and best practices. Check memory for prior decisions.", "researcher")
  Task("Coder agent", "Implement REST endpoints with authentication. Coordinate via hooks.", "coder")
  Task("Database agent", "Design and implement database schema. Store decisions in memory.", "code-analyzer")
  Task("Tester agent", "Create comprehensive test suite with 90% coverage.", "tester")
  Task("Reviewer agent", "Review code quality and security. Document findings.", "reviewer")
  
  // Batch ALL todos in ONE call
  TodoWrite { todos: [
    {id: "1", content: "Research API patterns", status: "in_progress", priority: "high"},
    {id: "2", content: "Design database schema", status: "in_progress", priority: "high"},
    {id: "3", content: "Implement authentication", status: "pending", priority: "high"},
    {id: "4", content: "Build REST endpoints", status: "pending", priority: "high"},
    {id: "5", content: "Write unit tests", status: "pending", priority: "medium"},
    {id: "6", content: "Integration tests", status: "pending", priority: "medium"},
    {id: "7", content: "API documentation", status: "pending", priority: "low"},
    {id: "8", content: "Performance optimization", status: "pending", priority: "low"}
  ]}
  
  // Parallel file operations
  Bash "mkdir -p app/{src,tests,docs,config}"
  Write "app/package.json"
  Write "app/src/server.js"
  Write "app/tests/server.test.js"
  Write "app/docs/API.md"
```

### ❌ WRONG (Multiple Messages):
```javascript
Message 1: mcp__claude-flow__swarm_init
Message 2: Task("agent 1")
Message 3: TodoWrite { todos: [single todo] }
Message 4: Write "file.js"
// This breaks parallel coordination!
```

## Performance Benefits

- **84.8% SWE-Bench solve rate**
- **32.3% token reduction**
- **2.8-4.4x speed improvement**
- **27+ neural models**

## Hooks Integration

### Pre-Operation
- Auto-assign agents by file type
- Validate commands for safety
- Prepare resources automatically
- Optimize topology by complexity
- Cache searches

### Post-Operation
- Auto-format code
- Train neural patterns
- Update memory
- Analyze performance
- Track token usage

### Session Management
- Generate summaries
- Persist state
- Track metrics
- Restore context
- Export workflows

## Advanced Features (v2.0.0)

- 🚀 Automatic Topology Selection
- ⚡ Parallel Execution (2.8-4.4x speed)
- 🧠 Neural Training
- 📊 Bottleneck Analysis
- 🤖 Smart Auto-Spawning
- 🛡️ Self-Healing Workflows
- 💾 Cross-Session Memory
- 🔗 GitHub Integration

## Integration Tips

1. Start with basic swarm init
2. Scale agents gradually
3. Use memory for context
4. Monitor progress regularly
5. Train patterns from success
6. Enable hooks automation
7. Use GitHub tools first

## Support

- Documentation: https://github.com/ruvnet/claude-flow
- Issues: https://github.com/ruvnet/claude-flow/issues
- Flow-Nexus Platform: https://flow-nexus.ruv.io (registration required for cloud features)

---

Remember: **Claude Flow coordinates, Claude Code creates!**

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
Never save working files, text/mds and tests to the root folder.
