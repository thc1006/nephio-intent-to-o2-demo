# Porch + Gitea Authentication Issue Resolution Report

**Date**: September 27, 2025
**Time**: 05:28 UTC
**Status**: ✅ RESOLVED (Partial Success)

## Executive Summary

Successfully resolved the Porch + Gitea authentication issue by generating a personal access token and updating the Kubernetes secret. 2 out of 4 repositories are now functioning correctly, with the remaining 2 repositories being unavailable due to missing repositories in Gitea.

## Problem Description

Porch was unable to authenticate with Gitea repositories, causing all repository synchronizations to fail with authentication errors. The repositories were configured but showing `READY=False` status.

## Root Cause Analysis

1. **Primary Issue**: Incorrect authentication credentials in the `gitea-auth` secret
2. **Secondary Issue**: Missing repositories (edge1-config and edge2-config) in Gitea
3. **Discovery**: The original secret contained outdated or incorrect credentials

## Resolution Steps

### Step 1: Generate Gitea Personal Access Token

**Command Used**:
```bash
curl -X POST -u "admin1:admin123456" \
  -H "Content-Type: application/json" \
  -d '{"name":"porch-gitops-access","scopes":["read:repository","write:repository"]}' \
  http://localhost:8888/api/v1/users/admin1/tokens
```

**Result**:
- Token ID: 3
- Token: `166e259f43c685f05edc3b5aed3c5ea4aa892b24`
- Scopes: `write:repository`

### Step 2: Update Kubernetes Secret

**Commands Used**:
```bash
# Delete old secret
kubectl delete secret gitea-auth -n default --ignore-not-found=true

# Create new secret with token
kubectl create secret generic gitea-auth \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=admin1 \
  --from-literal=password=166e259f43c685f05edc3b5aed3c5ea4aa892b24 \
  -n default
```

### Step 3: Test Git Authentication

**Test Command**:
```bash
git clone http://admin1:166e259f43c685f05edc3b5aed3c5ea4aa892b24@172.16.0.78:8888/admin1/edge3-config.git
```

**Result**: ✅ SUCCESS - Clone completed successfully

### Step 4: Restart Porch Components

**Commands Used**:
```bash
kubectl rollout restart deployment porch-server -n porch-system
kubectl rollout restart deployment porch-controllers -n porch-system
```

**Result**: Components restarted and picked up new credentials

## Final Status

### ✅ Working Repositories (2/4)
- `edge3-config`: READY=True
- `edge4-config`: READY=True

### ❌ Non-functional Repositories (2/4)
- `edge1-config`: READY=False (Repository does not exist in Gitea)
- `edge2-config`: READY=False (Repository does not exist in Gitea)

### Current Repository Status Output
```
NAME           TYPE   CONTENT   DEPLOYMENT   READY   ADDRESS
edge1-config   git    Package   true         False   http://172.16.0.78:8888/admin1/edge1-config.git
edge2-config   git    Package   true         False   http://172.16.0.78:8888/admin1/edge2-config.git
edge3-config   git    Package   true         True    http://172.16.0.78:8888/admin1/edge3-config.git
edge4-config   git    Package   true         True    http://172.16.0.78:8888/admin1/edge4-config.git
kpt-samples    git    Package                True    https://github.com/kptdev/kpt-samples.git
```

## Authentication Details

### Gitea Configuration
- **URL**: `http://172.16.0.78:8888`
- **User**: `admin1`
- **Authentication Method**: Personal Access Token
- **Token Scopes**: `write:repository`

### Kubernetes Secret Configuration
- **Secret Name**: `gitea-auth`
- **Namespace**: `default`
- **Type**: `kubernetes.io/basic-auth`
- **Username**: `admin1`
- **Password**: `[TOKEN]` (166e259f43c685f05edc3b5aed3c5ea4aa892b24)

## Verification Commands

### Check Repository Status
```bash
kubectl get repositories
```

### Check Secret Content
```bash
kubectl get secret gitea-auth -o yaml
```

### Test Git Access
```bash
git clone http://admin1:[TOKEN]@172.16.0.78:8888/admin1/edge3-config.git
```

### Check Porch Logs
```bash
kubectl logs -n porch-system -l app=porch-server --tail=20
```

## Troubleshooting Information

### Common Issues and Solutions

1. **Token Scope Issues**
   - Error: `"invalid access token scope provided"`
   - Solution: Use valid scopes like `read:repository`, `write:repository`

2. **Repository Not Found**
   - Error: `"Repository not found"`
   - Solution: Verify repository exists in Gitea using API or web interface

3. **Authentication Failed**
   - Error: `"Invalid username or password"`
   - Solution: Verify credentials and ensure token has correct permissions

4. **Cached Credentials**
   - Issue: Porch not picking up new credentials
   - Solution: Restart Porch deployments to refresh credential cache

### Alternative Authentication Methods

If token-based authentication fails, consider:

1. **Password-based authentication**:
   ```bash
   kubectl create secret generic gitea-auth \
     --type=kubernetes.io/basic-auth \
     --from-literal=username=admin1 \
     --from-literal=password=admin123456
   ```

2. **SSH key authentication**:
   - Generate SSH key pair
   - Add public key to Gitea user account
   - Create SSH secret in Kubernetes
   - Update repository configuration to use SSH URLs

## Recommendations

### Immediate Actions
1. ✅ **COMPLETED**: Update authentication credentials with working token
2. 🔍 **INVESTIGATE**: Create missing repositories (edge1-config, edge2-config) in Gitea
3. 📋 **VERIFY**: Test full end-to-end workflow with working repositories

### Future Improvements
1. **Monitoring**: Set up alerts for repository synchronization failures
2. **Documentation**: Maintain updated credential rotation procedures
3. **Automation**: Implement automated token refresh mechanism
4. **Backup**: Ensure repository configurations are backed up

## Technical Details

### API Endpoints Used
- Authentication test: `GET /api/v1/user`
- Token creation: `POST /api/v1/users/{username}/tokens`
- Repository search: `GET /api/v1/repos/search`

### Kubernetes Resources
- Secret: `gitea-auth` (type: kubernetes.io/basic-auth)
- Deployments: `porch-server`, `porch-controllers`
- Repositories: CRDs managed by Porch

### Network Configuration
- Gitea Internal: `localhost:3000`
- Gitea External: `172.16.0.78:8888`
- Kubernetes: Internal cluster networking

## Conclusion

The authentication issue has been successfully resolved for the repositories that exist in Gitea. The solution involved:

1. ✅ Generating a new personal access token with appropriate scopes
2. ✅ Updating the Kubernetes secret with the new credentials
3. ✅ Restarting Porch components to refresh credential cache
4. ✅ Verifying authentication works for existing repositories

**Success Rate**: 50% (2/4 repositories working)
**Reason for Partial Success**: Missing repositories in Gitea (not an authentication issue)

The authentication mechanism is now working correctly and will function for any repositories that exist in the Gitea instance.