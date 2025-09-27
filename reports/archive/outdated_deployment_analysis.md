# Outdated Installation/Deployment Files Analysis

**Date**: September 13, 2025
**Analyst**: Claude Code
**Repository**: nephio-intent-to-o2-demo

## Executive Summary

After deep analysis of the project repository, several installation and deployment files need updates to use current versions. Most components are moderately outdated (6-24 months) rather than severely obsolete.

## 🔴 Critical Updates Required

### 1. Guardrails Security Components
**Status**: MODERATE OUTDATED - Update Recommended

| Component | Current Version | Latest Version | Age | Risk Level |
|-----------|----------------|----------------|-----|------------|
| cert-manager | v1.15.0 | **v1.18.2** | ~8-10 months | Medium |
| Kyverno | v1.12.0 | **v1.15.1** | ~10-12 months | Medium |
| Sigstore Policy Controller | v0.10.0 | **v0.10.2** | ~2-4 months | Low |

**Files to Update**:
- `guardrails/cert-manager/install.sh`
- `guardrails/kyverno/install.sh`
- `guardrails/sigstore/install.sh`

### 2. VM-2 Tool Versions
**Status**: SIGNIFICANTLY OUTDATED - Update Required

**File**: `vm-2/scripts/install-tools.sh`

| Tool | Current Version | Latest Available | Age | Risk Level |
|------|----------------|------------------|-----|------------|
| kubectl | v1.31.3 | **v1.32.x** | ~2-4 months | Low |
| kind | v0.20.0 | **v0.24.0+** | ~8-12 months | Medium |
| kpt | v1.0.0-beta.54 | **v1.0.0+** | ~12+ months | High |

### 3. Bootstrap Configuration
**Status**: PARTIALLY OUTDATED - Review Required

**File**: `scripts/p0.1_bootstrap.sh`

| Component | Current Version | Issue | Risk Level |
|-----------|----------------|-------|------------|
| Kubernetes | v1.29.0 | Still supported but v1.32.x available | Low |
| Gitea | 1.21 | Latest is 1.22.x | Low |
| MetalLB | v0.13.12 | Latest is v0.14.x | Low |

## 🟡 Moderate Updates Recommended

### 4. O2IMS Installation Script
**Status**: WELL-MAINTAINED - Minor Updates

**File**: `scripts/p0.3_o2ims_install.sh`
- **Status**: ✅ Recently updated and well-structured
- **Action**: Monitor for upstream Nephio O2IMS changes
- **Risk**: Low

### 5. GitOps Configuration Scripts
**Status**: FUNCTIONAL - Cosmetic Updates

**Files**:
- `scripts/setup_gitea_*.sh` (Multiple files)
- `scripts/setup_gitops_automation.sh`

**Issues**:
- Environment-specific hardcoding
- No version management
- **Action**: Add version variables and environment detection

## 🟢 Current and Well-Maintained

### 6. KPT Functions and Packages
**Status**: ✅ CURRENT

**Files**:
- `kpt-functions/expectation-to-krm/` - Well-structured
- `packages/intent-to-krm/` - Active development
- GitOps manifests in `gitops/edge1-config/` and `gitops/edge2-config/`

### 7. Testing and Validation
**Status**: ✅ CURRENT

**Files**:
- `guardrails/test-all.sh` - Functional
- Test files in `tests/golden/` - Up-to-date

## 🗑️ Files to Consider for Removal

### Obsolete/Duplicate Files

1. **Multiple Gitea Setup Scripts** - Consolidation needed:
   ```
   scripts/setup_gitea_env.sh          # Helper script - keep
   scripts/setup_gitea_access.sh       # Functional - keep
   scripts/setup_gitea_repo.sh         # Basic - consider merging
   scripts/setup_gitea_for_vm2.sh      # VM-specific - keep
   scripts/gitea_*.sh (7+ files)       # Many duplicates - review
   ```

2. **Legacy Test Files** - Review needed:
   ```
   scripts/test_p0.4A.sh               # May be obsolete
   scripts/gitea_tunnel_alternatives.sh # Alternative approaches
   ```

## 📋 Recommended Action Plan

### Phase 1: Security Updates (HIGH PRIORITY)
1. **Update Security Components**:
   ```bash
   # Update guardrails versions
   sed -i 's/v1.15.0/v1.18.2/' guardrails/cert-manager/install.sh
   sed -i 's/v1.12.0/v1.15.1/' guardrails/kyverno/install.sh
   sed -i 's/v0.10.0/v0.10.2/' guardrails/sigstore/install.sh
   ```

2. **Update VM-2 Tools**:
   ```bash
   # Update tool versions in vm-2/scripts/install-tools.sh
   kubectl: v1.31.3 → v1.32.0+
   kind: v0.20.0 → v0.24.0+
   kpt: v1.0.0-beta.54 → v1.0.0+
   ```

### Phase 2: Infrastructure Updates (MEDIUM PRIORITY)
1. **Bootstrap Script Updates**:
   - Update Kubernetes to v1.32.x
   - Update MetalLB to v0.14.x
   - Update Gitea to 1.22.x

### Phase 3: Cleanup and Consolidation (LOW PRIORITY)
1. **Script Consolidation**:
   - Merge duplicate Gitea setup scripts
   - Remove obsolete test scripts
   - Add version management variables

2. **Documentation Updates**:
   - Update installation guides
   - Add version compatibility matrix
   - Document upgrade procedures

## Testing Strategy

For each update:
1. **Test in isolation** - Update one component at a time
2. **Verify compatibility** - Check with current Kubernetes versions
3. **Integration testing** - Run full bootstrap sequence
4. **Rollback preparation** - Document rollback procedures

## Risk Assessment

| Update Type | Risk Level | Impact | Effort |
|-------------|------------|--------|--------|
| Security tools (guardrails) | **Medium** | High | Low |
| VM-2 tools | **Medium** | Medium | Low |
| Bootstrap infrastructure | **Low** | Medium | Medium |
| Script consolidation | **Low** | Low | High |

## Conclusion

The repository is generally well-maintained with most components being moderately outdated rather than critically obsolete. Priority should be given to updating security components (cert-manager, Kyverno) and development tools (kubectl, kind, kpt) to maintain security posture and compatibility.

**Next Steps**:
1. Execute Phase 1 security updates immediately
2. Schedule Phase 2 infrastructure updates for next maintenance window
3. Plan Phase 3 cleanup for next development cycle

---
**Report Generated**: 2025-09-13 by Claude Code
**Files Analyzed**: 50+ installation/deployment files
**Components Reviewed**: 15+ major components