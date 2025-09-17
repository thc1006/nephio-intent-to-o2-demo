# Incremental Documentation Update Strategy

## Overview
Documentation updates after each workflow (WF) goes GREEN to maintain accurate, up-to-date project documentation.

## Update Triggers & Actions

### 1. After CI/CD Workflow GREEN

**Trigger**: `.github/workflows/ci.yml` passes
**Updates Required**:

#### ARCHITECTURE.md
```markdown
## CI/CD Integration
- Build status: [![CI](https://github.com/[org]/repo/actions/workflows/ci.yml/badge.svg)]
- Coverage: XX%
- Last successful build: [timestamp]
```

#### OPERATIONS.md
```markdown
## Automated Testing
- Unit tests: XXX passing
- Integration tests: XX passing  
- Coverage threshold: 80%
```

**Update Commands**:
```bash
# After CI passes
./scripts/update-docs.sh --workflow ci --status green
git add docs/*.md
git commit -m "docs: update after CI workflow success"
```

---

### 2. After Security Scan Workflow GREEN

**Trigger**: `.github/workflows/security.yml` passes
**Updates Required**:

#### REFERENCES.md
```markdown
## Security Compliance
- Sigstore validation: ✓ Enabled
- Kyverno policies: XX active
- Last security scan: [timestamp]
- Vulnerabilities: 0 critical, 0 high
```

#### ARCHITECTURE.md
```markdown
## Security Boundaries
- Image signing: cosign v2.x
- Policy enforcement: Kyverno vX.X
- Certificate management: cert-manager vX.X
```

**Update Commands**:
```bash
# Extract security metrics
./scripts/extract-security-metrics.sh > artifacts/security-status.json

# Update docs
./scripts/update-docs.sh --workflow security --metrics artifacts/security-status.json
```

---

### 3. After E2E Test Workflow GREEN

**Trigger**: `.github/workflows/e2e.yml` passes  
**Updates Required**:

#### OPERATIONS.md
```markdown
## E2E Test Scenarios
1. Intent validation: ✓ Passing (Xms)
2. TMF921→28.312: ✓ Passing (Xms)
3. KRM generation: ✓ Passing (Xs)
4. O2 IMS deployment: ✓ Passing (Xs)
5. SLO validation: ✓ Passing (Xs)

Total pipeline time: X minutes
```

#### ARCHITECTURE.md
```markdown
## Performance Benchmarks
- Intent processing: < Xms (actual: Xms)
- End-to-end pipeline: < 5min (actual: Xmin)
- Resource usage: CPU: X%, Memory: XMB
```

**Update Commands**:
```bash
# Parse E2E results
cat artifacts/e2e-results.json | jq '.scenarios[] | {name, status, duration}'

# Update performance section
./scripts/update-docs.sh --workflow e2e --results artifacts/e2e-results.json
```

---

### 4. After Release Workflow GREEN

**Trigger**: `.github/workflows/release.yml` completes
**Updates Required**:

#### All Documentation Files
```markdown
## Version Information
- Current version: vX.Y.Z
- Release date: YYYY-MM-DD
- Container images: gcr.io/nephio/*:vX.Y.Z
```

#### OPERATIONS.md
```markdown
## Deployment Versions
- intent-gateway: vX.Y.Z
- tmf921-to-28312: vX.Y.Z  
- expectation-to-krm: vX.Y.Z
- o2ims-sdk: vX.Y.Z
```

**Update Commands**:
```bash
# Update version references
export VERSION=$(git describe --tags --abbrev=0)
find docs -name "*.md" -exec sed -i "s/v[0-9]\+\.[0-9]\+\.[0-9]\+/${VERSION}/g" {} \;

git add docs/*.md
git commit -m "docs: update to version ${VERSION}"
```

---

## Automation Scripts

### scripts/update-docs.sh
```bash
#!/bin/bash
# Incremental doc updater

WORKFLOW=$1
STATUS=$2
METRICS_FILE=$3

update_architecture() {
  echo "Updating ARCHITECTURE.md for $WORKFLOW..."
  # Implementation
}

update_operations() {
  echo "Updating OPERATIONS.md for $WORKFLOW..."
  # Implementation
}

update_references() {
  echo "Updating REFERENCES.md for $WORKFLOW..."
  # Implementation
}

case $WORKFLOW in
  ci)
    update_architecture
    update_operations
    ;;
  security)
    update_references
    update_architecture
    ;;
  e2e)
    update_operations
    update_architecture
    ;;
  release)
    update_architecture
    update_operations
    update_references
    ;;
esac
```

### GitHub Action Integration
```yaml
# .github/workflows/update-docs.yml
name: Update Documentation
on:
  workflow_run:
    workflows: ["CI", "Security", "E2E", "Release"]
    types: [completed]

jobs:
  update-docs:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Update documentation
        run: |
          ./scripts/update-docs.sh \
            --workflow ${{ github.event.workflow_run.name }} \
            --status success \
            --run-id ${{ github.event.workflow_run.id }}
      
      - name: Commit updates
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/*.md
          git diff --staged --quiet || git commit -m "docs: auto-update after ${{ github.event.workflow_run.name }} success"
          git push
```

---

## Manual Update Checklist

When manually updating after GREEN workflows:

### 1. Check Workflow Status
```bash
gh workflow list
gh run list --workflow=ci.yml --limit 1
```

### 2. Extract Metrics
```bash
# CI metrics
make test 2>&1 | tee artifacts/test-output.log
grep -E "passed|failed" artifacts/test-output.log

# Security scan
cosign verify --key cosign.pub gcr.io/nephio/* 2>&1 | tee artifacts/verify.log

# E2E timing
time make e2e 2>&1 | tee artifacts/e2e-timing.log
```

### 3. Update Specific Sections

#### Quick Updates
```bash
# Update badge URLs
sed -i 's/badge.svg?branch=.*/badge.svg?branch=main/g' docs/*.md

# Update timestamps
sed -i "s/Last updated:.*/Last updated: $(date -I)/g" docs/*.md

# Update test counts
TEST_COUNT=$(find . -name "*_test.go" -o -name "test_*.py" | wc -l)
sed -i "s/Total tests:.*/Total tests: $TEST_COUNT/g" docs/OPERATIONS.md
```

### 4. Validate Updates
```bash
# Check markdown syntax
markdownlint docs/*.md

# Verify links
markdown-link-check docs/*.md

# Preview HTML
pandoc docs/ARCHITECTURE.md -o /tmp/preview.html
open /tmp/preview.html
```

### 5. Commit Pattern
```bash
git add docs/*.md
git commit -m "docs: update after [workflow] success

- Updated metrics from [workflow] run #XXX
- Performance: [summary]
- Security: [summary]
- Coverage: XX%"
```

---

## Documentation Health Metrics

Track documentation quality:

```bash
# Create doc health report
cat > artifacts/doc-health.json << EOF
{
  "last_updated": "$(date -I)",
  "workflows_tracked": ["ci", "security", "e2e", "release"],
  "auto_updates_enabled": true,
  "sections": {
    "architecture": {
      "last_modified": "$(stat -c %y docs/ARCHITECTURE.md)",
      "word_count": $(wc -w < docs/ARCHITECTURE.md)
    },
    "operations": {
      "last_modified": "$(stat -c %y docs/OPERATIONS.md)",
      "word_count": $(wc -w < docs/OPERATIONS.md)
    },
    "references": {
      "last_modified": "$(stat -c %y docs/REFERENCES.md)",
      "word_count": $(wc -w < docs/REFERENCES.md)
    }
  }
}
EOF
```

---

## Best Practices

1. **Update Immediately**: Update docs within 24h of workflow GREEN
2. **Include Metrics**: Always add performance/quality metrics
3. **Version Everything**: Tag docs with component versions
4. **Automate When Possible**: Use GitHub Actions for routine updates
5. **Review Quarterly**: Full doc review every 3 months

## Doc Update Commands Reference

```bash
# Quick update all badges
make update-badges

# Update version references
make update-version VERSION=v1.2.3

# Generate metrics summary
make doc-metrics

# Full documentation rebuild
make docs-rebuild

# Export to PDF with latest updates
make docs-pdf
```