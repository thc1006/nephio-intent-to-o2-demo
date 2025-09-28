# SMO/GitOps Orchestration Checklist

## Pipeline Execution Workflow

### 1. PLAN Phase
- [ ] Validate Intent JSON schema
- [ ] Check GitOps repository connectivity
- [ ] Verify kpt function availability
- [ ] Create git snapshot for rollback

### 2. TESTS Phase
- [ ] Run Intent JSON validation tests
- [ ] Execute KRM contract tests
- [ ] Validate golden test mappings
- [ ] Check render determinism

### 3. RENDER Phase
- [ ] Execute kpt fn render
- [ ] Generate KRM packages
- [ ] Validate output structure
- [ ] Calculate checksums

### 4. PUBLISH Phase
- [ ] Commit to edge1 repository
- [ ] Commit to edge2 repository
- [ ] Push to GitOps branches
- [ ] Trigger Config Sync

### 5. VERIFY Phase
- [ ] Check RootSync status
- [ ] Monitor deployment rollout
- [ ] Validate resource creation
- [ ] Collect deployment metrics

### 6. GATE Phase
- [ ] Execute SLO checks
- [ ] Validate acceptance criteria
- [ ] Check error budgets
- [ ] Generate gate report

### 7. ROLLBACK Phase (if needed)
- [ ] Detect gate failures
- [ ] Execute rollback plan
- [ ] Restore previous state
- [ ] Document failure reasons

### 8. REPORT Phase
- [ ] Generate execution summary
- [ ] Archive artifacts to reports/<timestamp>/
- [ ] Store manifests and checksums
- [ ] Create audit trail

## Execution Modes

### Safe Mode (Default)
- Interactive approval at each phase
- Full validation before proceeding
- Manual gate confirmation

### Headless Mode (Restricted)
- Only for well-scoped tasks
- Automatic rollback on failure
- Requires clean git snapshot
- Must be reversible

## Artifacts Structure
```
reports/
└── <timestamp>/
    ├── intent.json          # Input intent
    ├── rendered/            # KRM output
    ├── manifests.yaml       # Applied manifests
    ├── checksums.sha256     # Integrity checks
    ├── slo_report.json      # Gate results
    └── execution.log        # Full audit log
```