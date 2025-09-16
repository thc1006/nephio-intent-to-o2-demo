# Git Subtree Synchronization Guide

## Overview

This directory (`/operator`) is a git subtree of the independent operator repository.

- **Main Repository**: https://github.com/thc1006/nephio-intent-to-o2-demo
- **Operator Repository**: https://github.com/thc1006/nephio-intent-operator
- **Subtree Path**: `/operator`

## Prerequisites

Ensure the operator remote is configured:
```bash
# Add the operator remote (only needed once)
git remote add operator https://github.com/thc1006/nephio-intent-operator.git
```

## Synchronization Commands

### 📥 Pull Changes FROM Operator Repository

Pull latest changes from the independent operator repository into the main repository:

```bash
git subtree pull --prefix=operator operator main --squash
```

**When to use:**
- After changes are made directly to the operator repository
- When updating to a new operator version
- To sync external contributions

**Example workflow:**
```bash
# 1. Ensure you're on the correct branch
git checkout main

# 2. Pull latest changes from operator repo
git subtree pull --prefix=operator operator main --squash

# 3. Resolve any conflicts if necessary
# 4. Commit the merge
git push origin main
```

### 📤 Push Changes TO Operator Repository

Push changes from the main repository's operator directory to the independent operator repository:

```bash
git subtree push --prefix=operator operator main
```

**When to use:**
- After making changes in the `/operator` directory
- To publish operator updates
- To contribute changes back to the standalone repository

**Example workflow:**
```bash
# 1. Make changes in operator/ directory
cd operator/
# ... make your changes ...

# 2. Commit changes to main repository
git add .
git commit -m "feat(operator): add new reconciliation logic"
git push origin main

# 3. Push operator changes to standalone repo
git subtree push --prefix=operator operator main
```

## Advanced Operations

### 🔄 Force Push (Use with Caution!)

If the operator repository has diverged significantly:

```bash
# Force push - THIS WILL OVERWRITE the operator repo!
git push operator `git subtree split --prefix=operator main`:main --force
```

### 📊 View Subtree History

See only commits affecting the operator subtree:

```bash
git log --oneline -- operator/
```

### 🏷️ Tag an Operator Release

```bash
# Tag in main repo
git tag -a operator-v0.1.0 -m "Operator release v0.1.0"
git push origin operator-v0.1.0

# Extract and push to operator repo
git subtree push --prefix=operator operator main
cd /tmp
git clone https://github.com/thc1006/nephio-intent-operator.git
cd nephio-intent-operator
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

## Troubleshooting

### Merge Conflicts

If you encounter conflicts during `subtree pull`:

```bash
# 1. The conflict markers will be in your working tree
# 2. Resolve conflicts manually
# 3. Stage the resolved files
git add operator/
# 4. Continue with the commit
git commit
```

### Out of Sync

If the repositories are out of sync:

```bash
# Check the split point
git log --oneline --graph --decorate -- operator/

# Re-sync from a specific commit
git subtree pull --prefix=operator operator main --squash --strategy=ours
```

### Authentication Issues

For private repositories or push access:

```bash
# Use SSH URL instead
git remote set-url operator git@github.com:thc1006/nephio-intent-operator.git

# Or use token authentication
git remote set-url operator https://<token>@github.com/thc1006/nephio-intent-operator.git
```

## Best Practices

1. **Always pull before push** to avoid conflicts
2. **Use `--squash`** to keep history clean
3. **Tag releases** in both repositories
4. **Document breaking changes** in commit messages
5. **Run tests** before synchronizing

## Quick Reference

| Action | Command |
|--------|---------|
| Pull from operator repo | `git subtree pull --prefix=operator operator main --squash` |
| Push to operator repo | `git subtree push --prefix=operator operator main` |
| Add remote | `git remote add operator https://github.com/thc1006/nephio-intent-operator.git` |
| Check remote | `git remote -v` |
| View subtree commits | `git log --oneline -- operator/` |

## Version Management

- **Main Repository**: Uses tags like `v1.1.x` for the overall demo
- **Operator Repository**: Uses tags like `v0.1.0-alpha` for operator releases
- **Subtree Sync Points**: Tagged as `operator-sync-YYYYMMDD`

---

*Last Updated: 2025-09-16*
*Maintainer: @thc1006*