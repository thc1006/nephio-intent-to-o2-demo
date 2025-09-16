# Dual Repository Synchronization Manual

## Repository Structure

### Main Repository: nephio-intent-to-o2-demo
- **Version**: v1.1.x
- **Branch**: main
- **Purpose**: Complete intent-to-O2IMS system
- **CI**: Shell scripts, Python tools, E2E tests
- **Operator**: Subtree mirror at `operator/`

### Operator Repository: nephio-intent-operator
- **Version**: v0.1.x-alpha
- **Branch**: main
- **Purpose**: Kubernetes operator for IntentDeployment
- **CI**: Go build/test, golangci-lint, coverage
- **Type**: Independent Go module

## Synchronization Commands

### Pull Operator Changes to Main Repo
```bash
# From main repo root
git subtree pull --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main --squash
```

### Push Main Repo Changes to Operator
```bash
# From main repo root
git subtree push --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main
```

### Split History for New Subtree
```bash
# Only if recreating subtree
git subtree split --prefix=operator -b operator-branch
git push https://github.com/thc1006/nephio-intent-operator.git \
  operator-branch:main
```

## Version Mapping

| Main Repo | Operator Repo | Status | Notes |
|-----------|---------------|---------|-------|
| v1.1.0 | - | Released | Pre-operator |
| v1.1.1 | - | Released | Production ready |
| v1.1.2-rc1 | v0.1.0-alpha | Summit RC | Initial operator |
| v1.1.2-rc2 | v0.1.1-alpha | Summit RC | Phase transitions fixed |
| v1.1.2 | v0.1.2-alpha | Summit | Dual-mode support |
| v1.2.0 | v0.2.0-beta | Future | Standalone mode |

## CI Configuration

### Main Repository CI
```yaml
# .github/workflows/main-ci.yml
- Shell scripts testing
- Python tool validation
- E2E integration tests
- Summit packaging
- NO Go compilation
```

### Operator Repository CI
```yaml
# .github/workflows/go-ci.yml
- Go build and test
- golangci-lint
- Coverage reporting
- Docker image build
- Kubebuilder E2E tests
```

## Development Workflow

### 1. Operator Development
```bash
# Clone operator repo
git clone https://github.com/thc1006/nephio-intent-operator
cd nephio-intent-operator

# Make changes
vim api/v1alpha1/intentdeployment_types.go
make generate manifests

# Test locally
make test
make run

# Commit and push
git add .
git commit -m "feat: Add new feature"
git push origin main
```

### 2. Sync to Main Repo
```bash
# From main repo
cd ~/nephio-intent-to-o2-demo
git subtree pull --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main --squash

# Test integration
make -f Makefile.summit summit-operator

# Commit
git add .
git commit -m "chore: Sync operator v0.1.x changes"
git push origin main
```

### 3. Backport Main Changes
```bash
# If changes made in main repo operator/
cd ~/nephio-intent-to-o2-demo
git add operator/
git commit -m "fix: Update operator logic"

# Push to operator repo
git subtree push --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main
```

## Release Process

### Operator Release
```bash
# In operator repo
git tag v0.1.2-alpha
git push origin v0.1.2-alpha

# Build and push image
make docker-build docker-push IMG=ghcr.io/thc1006/intent-operator:v0.1.2-alpha
```

### Main Repo Release
```bash
# In main repo
# First sync operator
git subtree pull --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  v0.1.2-alpha --squash

# Tag main repo
git tag v1.1.2-rc2
git push origin v1.1.2-rc2
```

## Troubleshooting

### Subtree Conflicts
```bash
# Abort and retry with strategy
git subtree pull --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main --squash -X theirs
```

### Missing Subtree History
```bash
# Re-add subtree
git subtree add --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main --squash
```

### CI Failures
- **Main repo**: Check shell scripts and Python tools
- **Operator repo**: Check Go modules and kubebuilder version
- **Both**: Ensure GitHub Actions secrets are configured

## Best Practices

1. **Always test locally** before syncing
2. **Use semantic versioning** for both repos
3. **Document breaking changes** in both repos
4. **Keep CI green** in both repositories
5. **Tag releases** in sync between repos
6. **Use squash** for cleaner history
7. **Review subtree changes** before committing

## Emergency Procedures

### Rollback Operator in Main Repo
```bash
git revert HEAD  # If just synced
git subtree pull --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  <previous-tag> --squash
```

### Force Sync from Operator
```bash
# Nuclear option - replaces operator/ completely
rm -rf operator/
git subtree add --prefix=operator \
  https://github.com/thc1006/nephio-intent-operator.git \
  main --squash
```

## Contact

- Main Repo: https://github.com/thc1006/nephio-intent-to-o2-demo
- Operator Repo: https://github.com/thc1006/nephio-intent-operator
- Issues: File in respective repository
- Summit Support: See POCKET_QA.md