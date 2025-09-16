# O-2B｜控制器（Bridge 版）：以 Go 呼叫「主倉」腳本（可嵌入/可獨立）

**目的（變更點）**

* 因為 Operator 在子倉，**不可假設**與 shell 腳本一定在同一倉庫路徑。
* 設計 **雙模式**：

  * **embedded 模式**（被 subtree 進主倉，路徑 `operator/`）：用相對於主倉根的腳本路徑（由環境變數提供，如 `SHELL_PIPELINE_ROOT=..`）。
  * **standalone 模式**（獨立部署）：腳本以 **ConfigMap volume** 或 **外部服務 API** 提供（建議先 volume 方案）。

**建議環境變數**

* `PIPELINE_MODE` = `embedded|standalone`
* `SHELL_PIPELINE_ROOT`（embedded 下：`/work/nephio-intent-to-o2-demo` 或自動探測）
* `ARTIFACTS_ROOT`（例如 `/var/run/operator-artifacts`）
* `GIT_REMOTE_URL`、`GIT_BRANCH`（若需要自動 commit/push）
* 超時與 backoff：`EXEC_TIMEOUT_SEC`、`REQUEUE_BACKOFF_SEC`

**Claude 提示詞（@controller-implementer）**

```
You are @controller-implementer.
Repo: github.com/thc1006/nephio-intent-operator
Goal: Implement a reconciler for IntentDeployment that BRIDGES to the existing shell pipeline in two modes:
 - embedded: invoked when the repo is vendored into thc1006/nephio-intent-to-o2-demo/operator via subtree.
 - standalone: scripts are mounted via ConfigMap/volume or remote endpoints.
Flow:
 1) Serialize spec.intent to a temp file under $ARTIFACTS_ROOT/<ns>/<name>/<ts>/.
 2) If embedded: call $SHELL_PIPELINE_ROOT/scripts/render_krm.sh (or tools/intent-compiler).
    Else: call /opt/pipeline/scripts/render_krm.sh (volume mounted) or use HTTP API.
 3) Commit & push manifests using a small git helper (env-based, no secrets in code).
 4) Poll GitOps/O2IMS readiness via kubectl/jsonpath or client-go.
 5) Run postcheck; on FAIL + rollback.enabled → run rollback.sh.
 6) Update Status: phases, lastError, artifactsRef.
Constraints:
 - Idempotent; use workqueue keys; finalizers on deletion.
 - All external calls must timeout and be logged to $ARTIFACTS_ROOT.
TDD:
 - Table-driven tests for phase transitions; fake exec runner and fake git client.
Acceptance:
 - `make test` passes (with fakes).
 - Reconciler handles embedded/standalone via PIPELINE_MODE switch.
Outputs:
 - internal/execrunner/, internal/git/, internal/env/
 - docs/design/bridge-modes.md with env var matrix and path diagrams.
```

---

# O-3B｜CRD 契約測試（envtest E2E）

**命令**

```bash
cd ~/nephio-intent-operator
make test
```

**Claude 提示詞（@contract-tester）**

```
You are @contract-tester.
Goal: envtest-based lifecycle tests for IntentDeployment:
 - Create CRD; apply minimal CR (edge1).
 - Assert phase transitions and status updates using fake runners.
 - Verify artifacts manifest paths and error propagation.
 - Include negative tests: timeouts, script nonzero exit, rollback branches.
Acceptance:
 - Coverage report generated to build/coverage.out (fixed path).
 - README documents how to run tests locally and in CI.
```

---

# O-4B｜容器化與本地部署（kind on VM-1）

**命令（VM-1）**

```bash
# 在子倉建鏡像
cd ~/nephio-intent-operator
make docker-build IMG=<your-registry>/intent-operator:v0.1.0-alpha

# 本地 kind 叢集部署（不干擾 edge1/edge2）
kind create cluster --name mgmt || true
kind load docker-image <your-registry>/intent-operator:v0.1.0-alpha --name mgmt
make deploy IMG=<your-registry>/intent-operator:v0.1.0-alpha
kubectl get pods -n intent-operator-system
```

**Claude 提示詞（@deployer）**

```
You are @deployer.
Goal: Produce Kustomize manifests, deploy operator into local 'mgmt' cluster, and verify health.
Tasks:
 - RBAC for required namespaces/CRDs; leader election on.
 - Config via ConfigMap: PIPELINE_MODE, SHELL_PIPELINE_ROOT, ARTIFACTS_ROOT.
 - Health checks: readiness/liveness probes; log "ready" banner on start.
Acceptance:
 - Pod Ready; leader election ok; logs confirm mode and resolved script paths.
```

---

# O-5B｜與 GitOps / O2IMS / SLO Gate 串接（契約打通）

**重點（變更點）**

* 串接**不改動**既有腳本；僅在 Operator 端提供**環境變數/ConfigMap** 指向腳本與輸出根目錄。
* 提供範例 CR：`examples/intentdeployment-edge1.yaml`、`edge2.yaml`、`both.yaml`。
* 在 **embedded 模式**下，範例假定 subtree 路徑；在 **standalone** 下，假定 volume mount 的 `/opt/pipeline/scripts/…`。

**Claude 提示詞（@integration-engineer）**

```
You are @integration-engineer.
Goal: Wire the operator to the existing shell pipeline with zero changes to scripts.
Tasks:
 - Define a Config interface (ConfigMap/Env) to point to scripts/output roots.
 - Map script exit codes and log markers into CRD .status.* fields.
 - Provide examples for edge1/edge2/both deployments.
Acceptance:
 - Applying examples triggers end-to-end pipeline equivalently to shell flow.
 - Status==Succeeded with artifactsRef set on success; informative errors otherwise.
Outputs:
 - config/samples/tna_v1alpha1_intentdeployment_{edge1,edge2,both}.yaml
 - docs/integration/contracts.md (exit code/log → status mapping)
```

---

# O-6B｜演示與回退保險

**Claude 提示詞（@demo-wrangler）**

```
You are @demo-wrangler.
Goal: Provide stage scripts that demo both modes and rollback.
Tasks:
 - scripts/demo_operator_embedded.sh: assumes subtree inside main repo; sets PIPELINE_MODE=embedded; applies samples; watches status.
 - scripts/demo_operator_standalone.sh: mounts scripts at /opt/pipeline/scripts; sets PIPELINE_MODE=standalone.
 - scripts/fail_inject.sh: induce an SLO breach to showcase rollback.
Acceptance:
 - Two demos run end-to-end; failure path shows rollback and CR status Failed with lastError.
```

---

# O-7B｜文件與 Summit 投影片補強

**Claude 提示詞（@doc-writer）**

```
You are @doc-writer.
Goal: Author operator README, CRD reference, and Summit slide deltas tailored for the “independent repo + subtree” story.
Outline:
 - Why “shell-first → operator-next” with independent repo for reusability.
 - Repo topology: main (shell) vs operator (Go), and how subtree keeps main self-contained.
 - CRD schema, phase machine, safety properties.
 - Bridge modes (embedded/standalone) and env var matrix.
 - Release plan: operator v0.1.x; main continues v1.1.x; how to sync subtree on release.
Acceptance:
 - README and docs provide copy-pastable commands for subtree pull/push.
 - SLIDES.md add-on pages ready for Summit; Q&A updated.
```

---

## CI / 版本 / 同步 重要補充

* **CI 分離**

  * 子倉：`.github/workflows/ci.yml` 跑 `go vet`, `golangci-lint`, `make test`, `kind`（可選）等。
  * 主倉：現有 Shell CI 照舊。`operator/.github/...` 在主倉**不會觸發**，避免重複。
  * 如需主倉做「抽樣驗證 operator」：可在主倉根加一支工作流，`paths: ["operator/**"]` 時只跑 `go list` 或樣本測試（用 `go work use ./operator`）。

* **發版與同步**

  * 子倉打 tag：`v0.1.0-alpha` → 其他專案可 `go get github.com/thc1006/nephio-intent-operator@v0.1.0-alpha`。
  * 主倉同步子倉新版：`git subtree pull --prefix=operator operator main --squash`，在 `operator/README.md` 記錄對應子倉 commit/tag。
  * 若在主倉 `operator/` 修改並要回饋：`git subtree push --prefix=operator operator main` 後，在子倉開 PR 審閱。

* **嵌入/獨立雙模式守則**

  * 嵌入（embedded）：不寫死相對路徑；靠 `SHELL_PIPELINE_ROOT`。主倉 `Makefile` 可幫忙 set 這個變數。
  * 獨立（standalone）：以 Volume/ConfigMap 或 API 替代腳本路徑；避免耦合主倉結構。

---

## 如果你先前已在主倉做過 `operator/` 草稿

要保留歷史抽出去當子倉：

```bash
cd ~/nephio-intent-to-o2-demo
git subtree split --prefix=operator -b split-operator
git push git@github.com:thc1006/nephio-intent-operator.git split-operator:main
```