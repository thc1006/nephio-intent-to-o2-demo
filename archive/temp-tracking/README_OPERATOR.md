# Operator Integration Notice

## Git Subtree Configuration

The `/operator` directory in this repository is a **git subtree** synchronized with the independent operator repository at https://github.com/thc1006/nephio-intent-operator.

### Important Notes

- **DO NOT** modify files in `/operator` directly unless you intend to sync changes back to the operator repository
- The operator has its own versioning (`v0.1.0-alpha`) independent from the main demo versioning (`v1.1.x`)
- The operator can be developed and deployed independently

### Synchronization

To sync changes between repositories, see [`/operator/SYNC.md`](./operator/SYNC.md).

### Quick Commands

```bash
# Pull latest operator changes
git subtree pull --prefix=operator operator main --squash

# Push operator changes
git subtree push --prefix=operator operator main
```

### Repository Links

- **Main Demo Repository**: https://github.com/thc1006/nephio-intent-to-o2-demo
- **Operator Repository**: https://github.com/thc1006/nephio-intent-operator

---

*For operator-specific documentation, see [`/operator/README.md`](./operator/README.md)*