# Porch Integration Guide for E2E Pipeline

## Overview

This guide documents the integration of Google Porch (Package Orchestration) into the existing Nephio Intent-to-O2 E2E pipeline. The integration provides PackageRevision-based deployment workflow while maintaining backward compatibility with the traditional git-based approach.

## Architecture

### Traditional Pipeline (Phase 19-B)
```
Intent → KRM → Validation → kpt → Git Commit → GitOps → O2IMS → Validation
```

### Porch-Enhanced Pipeline (Phase 19-C)
```
Intent → KRM → Validation → kpt → Porch PackageRevision → PackageVariants → O2IMS → Validation
```

## Key Components

### 1. PackageRevision Workflow
- **Intent Packages**: Created as PackageRevisions in the `intent-packages` repository
- **Multi-site Variants**: Automatically generated via PackageVariants for each target site
- **Lifecycle Management**: Draft → Published → Active states managed by Porch

### 2. Repository Structure
```yaml
# Main package repository
intent-packages/
  ├── intent-e2e-123456-v1/  # PackageRevision for each intent
  │   ├── Kptfile
  │   ├── deployment.yaml
  │   ├── service.yaml
  │   └── ...

# Site-specific deployment repositories
edge1-config/, edge2-config/, edge3-config/, edge4-config/
  ├── intent-e2e-123456-edge1/  # PackageVariant
  │   ├── Kptfile
  │   ├── deployment.yaml (site-customized)
  │   └── ...
```

### 3. Integration Points
- **Stage 5-P**: Replaces traditional git operations with Porch workflow
- **Prerequisites**: Automatic checking and repository creation
- **Multi-site**: PackageVariants handle site-specific customizations

## Usage

### Basic Commands

#### Traditional Mode (Default)
```bash
# Standard pipeline - no changes
./scripts/e2e_pipeline_porch.sh --target edge3

# Equivalent to original pipeline
./scripts/e2e_pipeline.sh --target edge3
```

#### Porch Mode
```bash
# Enable Porch workflow
./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch

# Multi-site with Porch
./scripts/e2e_pipeline_porch.sh --target all --use-porch

# Custom package repository
./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch --porch-repo my-packages
```

#### Environment Variables
```bash
# Enable Porch globally
export USE_PORCH=true
./scripts/e2e_pipeline_porch.sh --target edge3

# Custom configuration
export PORCH_NAMESPACE=custom-porch
export PACKAGE_REPOSITORY=my-packages
./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch
```

### Advanced Options

```bash
# Dry run with Porch
./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch --dry-run

# Skip validation with Porch
./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch --skip-validation

# Disable auto-rollback
./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch --no-rollback
```

## Configuration

### Prerequisites

1. **Porch Installation**: Verify Porch is installed and running
   ```bash
   kubectl get crd repositories.config.porch.kpt.dev
   kubectl get ns porch-system
   ```

2. **Repository Setup**: Ensure package repositories exist
   ```bash
   kubectl get repository.config.porch.kpt.dev -n porch-system
   ```

### Environment Configuration

```bash
# Required
USE_PORCH=true                    # Enable Porch workflow
PORCH_NAMESPACE=porch-system      # Porch system namespace
PACKAGE_REPOSITORY=intent-packages # Main package repository

# Pipeline configuration
TARGET_SITE=edge3                 # Target deployment site
SERVICE_TYPE=enhanced-mobile-broadband # Service type
DRY_RUN=false                     # Execution mode
```

## Workflow Details

### Stage Flow

#### 1. Initialize Pipeline
- Check Porch prerequisites
- Create edge site repositories if needed
- Initialize tracing and reporting

#### 2. Traditional Stages (1-4)
- **Stage 1**: Generate Intent JSON
- **Stage 2**: Translate Intent to KRM
- **Stage 3**: Validate KRM with kpt functions
- **Stage 4**: Run kpt pipeline

#### 3. Porch Workflow (Stage 5-P)

**5-P.1: Create PackageRevision**
```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageRevision
metadata:
  name: intent-e2e-123456-v1
spec:
  packageName: intent-e2e-123456
  revision: v1
  repository: intent-packages
  lifecycle: Draft
```

**5-P.2: Populate Package Content**
- Copy KRM resources from `rendered/krm/`
- Create Kptfile with pipeline configuration
- Update PackageRevision with content

**5-P.3: Create PackageVariants** (Multi-site only)
```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: intent-e2e-123456-edge3
spec:
  upstream:
    repo: intent-packages
    package: intent-e2e-123456
    revision: v1
  downstream:
    repo: edge3-config
    package: intent-e2e-123456-edge3
  packageContext:
    data:
      site: edge3
      intent-id: intent-e2e-123456
```

**5-P.4: Publish PackageRevision**
- Update lifecycle: Draft → Published
- Trigger downstream propagation

#### 4. Monitoring Stages (6-8)
- **Stage 6**: Wait for RootSync reconciliation
- **Stage 7**: Poll O2IMS provisioning status
- **Stage 8**: Perform on-site validation

### Repository Management

#### Automatic Repository Creation
The pipeline automatically creates missing edge site repositories:

```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: edge3-config
  namespace: porch-system
spec:
  description: "Edge site edge3 deployment repository"
  type: git
  content: Package
  deployment: true
  git:
    repo: "file:///tmp/git/edge3-config"
    branch: "main"
    createBranch: true
```

#### Package Structure
Each PackageRevision includes:

```yaml
# Kptfile
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: intent-e2e-123456-edge3
info:
  description: "Intent e2e-123456 deployment for edge3"
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/set-labels:v0.2.0
      configMap:
        intent-id: "intent-e2e-123456"
        site: "edge3"
        service-type: "enhanced-mobile-broadband"
```

## Monitoring and Troubleshooting

### Monitoring Commands

```bash
# Check PackageRevisions
kubectl get packagerevisions.config.porch.kpt.dev -n porch-system

# Check PackageVariants
kubectl get packagevariants.config.porch.kpt.dev -n porch-system

# Check repositories
kubectl get repositories.config.porch.kpt.dev -n porch-system

# Pipeline traces
ls reports/traces/pipeline-*.json
./scripts/stage_trace.sh timeline reports/traces/pipeline-e2e-123456.json
```

### Common Issues

#### 1. Porch Prerequisites Not Met
```bash
[ERROR] Porch CRDs not found. Please install Porch first.
```
**Solution**: Install Porch using the deployment scripts in `scripts/porch/`

#### 2. Package Repository Not Found
```bash
[WARN] Package repository 'intent-packages' not found. Will attempt to create it.
```
**Solution**: The pipeline will attempt to create it automatically, or create manually

#### 3. PackageRevision Creation Failed
```bash
[ERROR] Failed to create PackageRevision
```
**Solution**: Check Porch logs and repository permissions

#### 4. PackageVariant Creation Failed
```bash
[ERROR] Failed to create any PackageVariants
```
**Solution**: Verify downstream repositories exist and are accessible

### Debugging Commands

```bash
# Check Porch controller logs
kubectl logs -n porch-system deployment/porch-controller

# Check package content
kubectl get packagerevision intent-e2e-123456-v1 -n porch-system -o yaml

# Check variant status
kubectl describe packagevariant intent-e2e-123456-edge3 -n porch-system
```

## Migration Guide

### From Traditional to Porch

1. **Test Compatibility**: Verify both modes work
   ```bash
   # Test traditional
   ./scripts/e2e_pipeline_porch.sh --target edge3 --dry-run

   # Test Porch
   ./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch --dry-run
   ```

2. **Gradual Migration**: Start with single sites
   ```bash
   # Migrate edge3 to Porch
   ./scripts/e2e_pipeline_porch.sh --target edge3 --use-porch
   ```

3. **Full Migration**: Enable Porch globally
   ```bash
   export USE_PORCH=true
   # Update deployment scripts and CI/CD
   ```

### Rollback Strategy

If issues occur with Porch workflow:

1. **Immediate Fallback**: Use traditional mode
   ```bash
   ./scripts/e2e_pipeline.sh --target edge3
   ```

2. **Environment Override**: Disable Porch temporarily
   ```bash
   export USE_PORCH=false
   ./scripts/e2e_pipeline_porch.sh --target edge3
   ```

## Best Practices

### 1. Repository Management
- Use descriptive repository names
- Maintain consistent branch strategies
- Regular cleanup of old PackageRevisions

### 2. Package Versioning
- Follow semantic versioning for packages
- Use intent IDs for traceability
- Maintain package history for rollbacks

### 3. Multi-site Deployment
- Test single site before multi-site
- Use PackageVariants for site customization
- Monitor propagation delays

### 4. Monitoring
- Enable pipeline tracing
- Monitor Porch controller health
- Track PackageRevision lifecycle events

## Integration with Existing Tools

### GitOps Compatibility
- Porch packages integrate with Config Sync
- Traditional RootSync still applies packages
- No changes needed for edge site GitOps

### CI/CD Integration
```bash
# Jenkins/GitHub Actions example
if [ "$USE_PORCH" = "true" ]; then
    ./scripts/e2e_pipeline_porch.sh --target ${TARGET_SITE} --use-porch
else
    ./scripts/e2e_pipeline.sh --target ${TARGET_SITE}
fi
```

### Monitoring Integration
- Pipeline metrics include Porch operations
- Stage tracing captures Porch timing
- Reports include PackageRevision status

## Performance Considerations

### Porch vs Traditional
- **PackageRevision Creation**: ~2-5s overhead
- **Multi-site Variants**: Parallel creation
- **Git Operations**: Handled by Porch controller
- **Overall Impact**: <10% pipeline time increase

### Optimization Tips
- Use local git repositories for testing
- Batch PackageVariant creation
- Monitor Porch controller resources
- Cache repository checks

## Future Enhancements

### Planned Features
1. **Automatic Package Cleanup**: Remove old PackageRevisions
2. **Advanced Variants**: Complex site customizations
3. **Package Dependencies**: Hierarchical package structure
4. **Integration Testing**: Automated Porch testing

### Extension Points
- Custom kpt functions in packages
- Advanced PackageVariant configurations
- Integration with external package sources
- Enhanced monitoring and alerting

## Summary

The Porch integration provides a modern, GitOps-native approach to package management while maintaining full backward compatibility. Key benefits include:

- **Modern Package Management**: Leverages Google's Porch for enterprise-grade package lifecycle
- **Multi-site Deployment**: Automated PackageVariants for site-specific customizations
- **Backward Compatibility**: Traditional workflow remains unchanged
- **Enhanced Traceability**: PackageRevisions provide better audit trails
- **Scalable Architecture**: Supports complex multi-site deployments

For production deployment, start with single-site testing, gradually migrate to Porch mode, and maintain traditional pipeline as fallback option.