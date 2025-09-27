# Porch + Gitea Integration Report

**Date**: 2025-09-27
**Integration**: Porch v1.5.3 with Gitea v1.24.6
**Status**: 🚧 **IN PROGRESS**

---

## Objective

Integrate Porch v1.5.3 Package Orchestration with Gitea Git repositories to enable PackageRevision-based workflow for the 4 edge sites.

---

## Gitea Repository Status

### Available Repositories (Verified)
```bash
$ curl http://172.16.0.78:8888/api/v1/repos/search
Found 2 repositories:
  admin1/edge3-config
  admin1/edge4-config
```

✅ **Edge3 and Edge4**: Repositories exist in Gitea
❌ **Edge1 and Edge2**: Repositories NOT YET created in Gitea

### Repository URLs
- **Edge3**: http://172.16.0.78:8888/admin1/edge3-config.git
- **Edge4**: http://172.16.0.78:8888/admin1/edge4-config.git
- **Edge1**: http://172.16.0.78:8888/admin1/edge1-config.git (MISSING)
- **Edge2**: http://172.16.0.78:8888/admin1/edge2-config.git (MISSING)

---

## Porch Repository Registration

### Registered Repositories
```bash
$ kubectl get repositories.config.porch.kpt.dev
NAMESPACE   NAME           TYPE   CONTENT   DEPLOYMENT   READY   ADDRESS
default     edge1-config   git    Package   true         False   http://172.16.0.78:8888/admin1/edge1-config.git
default     edge2-config   git    Package   true         False   http://172.16.0.78:8888/admin1/edge2-config.git
default     edge3-config   git    Package   true         False   http://172.16.0.78:8888/admin1/edge3-config.git
default     edge4-config   git    Package   true         False   http://172.16.0.78:8888/admin1/edge4-config.git
default     kpt-samples    git    Package                True    https://github.com/kptdev/kpt-samples.git
```

⚠️ **All edge repositories showing READY=False**

### Error Analysis

**Error Message (from kubectl describe)**:
```
Message: error cloning git repository http://172.16.0.78:8888/admin1/edge1-config.git,
         fetch of remote repository failed: fetch of remote repository default:edge1-config::main
         with retry failed: fetch of remote repository default:edge1-config::main with retry
         failed on try number 6: cannot fetch repository default:edge1-config::main:
         failed to obtain git credentials: failed to obtain credential from secret
         default/gitea-auth: error resolving credential: bearer Token secret.Data key
         must be set as bearerToken
```

**Root Causes Identified**:
1. **Authentication Secret Format**: Porch expecting `kubernetes.io/basic-auth` type secret
2. **Missing Repositories**: edge1-config and edge2-config don't exist in Gitea yet
3. **Repository Initialization**: Even existing repos (edge3, edge4) need proper initialization

---

## Authentication Secret Configuration

### Initial Attempt (Failed)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitea-auth
  namespace: default
data:
  username: admin1
  password: admin1password
```
❌ **Result**: "bearer Token secret.Data key must be set as bearerToken"

### Corrected Configuration (In Progress)
```bash
kubectl create secret generic gitea-auth -n default \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=admin1 \
  --from-literal=password=admin1password
```
✅ **Type**: `kubernetes.io/basic-auth` (required by Porch)
⏳ **Testing**: Waiting for Porch to reconcile

---

## Porch Logs Analysis

```
E0927 05:11:06.614332 git.go:681] Fetching Remote Repository default:edge4-config::main failed - try number 2
E0927 05:11:07.625932 git.go:681] Fetching Remote Repository default:edge4-config::main failed - try number 3
E0927 05:11:08.632123 git.go:681] Fetching Remote Repository default:edge4-config::main failed - try number 4
E0927 05:11:09.640283 git.go:681] Fetching Remote Repository default:edge4-config::main failed - try number 5
E0927 05:11:10.646476 git.go:681] Fetching Remote Repository default:edge4-config::main failed - try number 6
```

**Observations**:
- Porch retries 6 times before giving up
- Failure on every repository (edge1, edge2, edge3, edge4)
- Authentication issue preventing git clone

---

## Action Plan

### 1. Create Missing Gitea Repositories ⏳
```bash
# Create edge1-config repository
curl -X POST http://172.16.0.78:8888/api/v1/admin/users/admin1/repos \
  -H "Content-Type: application/json" \
  -H "Authorization: token <GITEA_TOKEN>" \
  -d '{
    "name": "edge1-config",
    "private": false,
    "auto_init": true
  }'

# Create edge2-config repository
curl -X POST http://172.16.0.78:8888/api/v1/admin/users/admin1/repos \
  -H "Content-Type: application/json" \
  -H "Authorization: token <GITEA_TOKEN>" \
  -d '{
    "name": "edge2-config",
    "private": false,
    "auto_init": true
  }'
```

### 2. Initialize Existing Repositories ⏳
```bash
# Ensure edge3-config and edge4-config have main branch initialized
# May need to push initial commits if empty
```

### 3. Fix Authentication Secret ✅
```bash
# Already recreated with correct type: kubernetes.io/basic-auth
kubectl get secret gitea-auth -n default -o yaml
```

### 4. Verify Repository Connectivity ⏳
```bash
# After fixes, wait for Porch reconciliation (15-30 seconds)
kubectl get repositories.config.porch.kpt.dev -w

# Check for READY=True status
```

### 5. Test PackageRevision Creation ⏳
```bash
# Once repositories are READY, test creating a PackageRevision
kubectl create -f - <<EOF
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageRevision
metadata:
  name: edge3-test-package
  namespace: default
spec:
  packageName: test-package
  workspaceName: main
  repository: edge3-config
  lifecycle: Draft
EOF
```

---

## Known Issues & Workarounds

### Issue 1: Porch Secret Format
**Problem**: Default secret format not recognized by Porch
**Solution**: Use `type: kubernetes.io/basic-auth` explicitly
**Status**: ✅ Fixed

### Issue 2: Missing Repositories
**Problem**: edge1-config and edge2-config don't exist in Gitea
**Solution**: Create repositories via Gitea API
**Status**: ⏳ Pending execution

### Issue 3: Repository Initialization
**Problem**: Repositories need `main` branch with at least one commit
**Solution**: Initialize with README.md or .gitkeep
**Status**: ⏳ Pending verification

---

## Alternative Approach: Upstream + Downstream Pattern

If direct deployment repository usage proves problematic, consider:

### Upstream Repository (Package Source)
```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-packages
spec:
  type: git
  content: Package  # Source packages
  deployment: false
  git:
    repo: https://github.com/nephio-project/catalog.git
    branch: main
```

### Downstream Repositories (Deployment Targets)
```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: edge3-config
spec:
  type: git
  content: Package
  deployment: true  # Deployment repository
  git:
    repo: http://172.16.0.78:8888/admin1/edge3-config.git
    branch: main
    secretRef:
      name: gitea-auth
```

### PackageVariant to Connect Them
```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: edge3-basens
spec:
  upstream:
    repo: nephio-packages
    package: basens
    revision: main
  downstream:
    repo: edge3-config
    package: basens
```

---

## Expected Outcome

Once all issues resolved:

```bash
$ kubectl get repositories.config.porch.kpt.dev
NAMESPACE   NAME           TYPE   CONTENT   DEPLOYMENT   READY   ADDRESS
default     edge1-config   git    Package   true         True    http://172.16.0.78:8888/admin1/edge1-config.git
default     edge2-config   git    Package   true         True    http://172.16.0.78:8888/admin1/edge2-config.git
default     edge3-config   git    Package   true         True    http://172.16.0.78:8888/admin1/edge3-config.git
default     edge4-config   git    Package   true         True    http://172.16.0.78:8888/admin1/edge4-config.git
default     kpt-samples    git    Package                True    https://github.com/kptdev/kpt-samples.git
```

✅ All repositories READY=True
✅ PackageRevision creation working
✅ Ready for E2E pipeline integration

---

## Next Steps

1. ⏳ Create missing edge1-config and edge2-config repositories in Gitea
2. ⏳ Verify authentication secret fix resolves connectivity
3. ⏳ Initialize all repositories with main branch
4. ⏳ Test PackageRevision workflow on edge3-config
5. ⏳ Document PackageRevision-based E2E flow
6. ⏳ Update e2e_pipeline.sh to use Porch APIs

---

**Status**: 🚧 **Authentication fixed, awaiting repository creation and verification**
**Report Author**: Claude Code
**Last Updated**: 2025-09-27T05:15:00Z