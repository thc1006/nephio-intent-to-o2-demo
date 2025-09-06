# Project Mission & Guardrails

Mission:
Build a verifiable intent pipeline for Telco cloud & O-RAN:
LLM → TMF921 Intent (TIO/CTK-validated) → 3GPP TS 28.312 Intent/Expectation → KRM packages via kpt/Porch → O-RAN O2 IMS (ProvisioningRequest) → (optional) O2 Measurement Job Query → IntentReport & SLO-gated GitOps; with default-on security (Sigstore/Kyverno/cert-manager).

Key Standards & Sources:
- Nephio R5 release & O-RAN integration guides (O2 IMS / ProvisioningRequest). 
- O-RAN blog: First O2 IMS Performance API: Measurement Job Query.
- kpt function SDK (Go) for 28.312→KRM.
- Sigstore policy-controller, Kyverno verifyImages, cert-manager install guides.
(Keep links in docs/REFERENCES.md)
[Nephio R5 docs, O-RAN O2 IMS, kpt fn ref, Sigstore/Kyverno/cert-manager references]

Working Agreements (enforce in every task):
1) TDD: write failing tests first (RED), implement minimal code (GREEN), refactor safely.
2) Small, atomic commits and PRs. Each module ships with Makefile, README, dev scripts.
3) Deterministic CLIs with explicit exit codes; all artifacts under ./artifacts when relevant.
4) Security on by default: signed images only in prod, schemas for external inputs, rate limits, secretless configs.

Repository Layout (do not move without a dedicated PR):
  tools/{intent-gateway, tmf921-to-28312}/
  kpt-functions/expectation-to-krm/
  o2ims-sdk/
  slo-gated-gitops/{job-query-adapter, gate}/
  guardrails/{sigstore, kyverno, cert-manager, schemas}/
  packages/intent-to-krm/
  samples/{tmf921, 28312, krm}/
  scripts/
  docs/
  .github/workflows/

Coding Style:
- Python 3.11 (ruff+black+pytest), Go 1.22 (gofmt+golangci-lint+testing), YAML (kubeconform+yamllint).
- Prefer pure functions; explicit mapping tables for model transforms (TMF921→28.312).
- Avoid hidden side effects; log JSON for machine parsing.

Security Rules:
- No `sudo npm -g`; no plaintext secrets; use GitHub Secrets and local `.env.example`.
- Enforce image signatures in non-dev namespaces; provide signed demo images.
- Validate all external payloads (A1/E2/O2) against JSON Schema before applying.

Slash Commands Examples (you can type these in Claude Code):
- `/plan` Summarize task into 3–5 tiny subtasks with tests-first.
- `/test-first` Generate RED tests for <module>.
- `/impl` Implement minimal code to satisfy tests.
- `/refactor` Clean up code without behavior change.
- `/commit` Propose concise, conventional commit messages.
- `/review security` Review changes for supply-chain and input-validation risks.

Acceptance Examples:
- `intent-gateway validate --file samples/tmf921/valid_intent_01.json --tio-mode fake` exits 0.
- `tmf921-to-28312 convert ...` emits valid 28.312 JSON and a delta report.
- `kpt fn render packages/intent-to-krm/` yields kubeconform-valid KRM.
- `o2imsctl pr create --from examples/pr.yaml` transitions to Ready (fake client in tests).
- `gate --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200"` returns 0 when KPIs met.

Non-Goals:
- No proprietary cloud lock-in; no long LLM fine-tuning; no production secrets.