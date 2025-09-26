# IntentDeployment CRD Design

## Overview

The `IntentDeployment` Custom Resource Definition (CRD) orchestrates the complete lifecycle of intent-based deployments in the Nephio ecosystem, from natural language or JSON intents to deployed Kubernetes resources with SLO validation and automatic rollback capabilities.

## API Version

- **Group**: `tna.tna.ai`
- **Version**: `v1alpha1`
- **Kind**: `IntentDeployment`

## Spec Fields

### Core Fields

#### `intent` (string, required)
The original intent specification, either as natural language or structured JSON.

Example:
```yaml
intent: |
  {
    "service": "edge-analytics",
    "replicas": 3,
    "resources": {
      "cpu": "500m",
      "memory": "1Gi"
    }
  }
```

### Configuration Sections

#### `compileConfig` (optional)
Controls how intents are compiled into Kubernetes resources.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `engine` | string | `kpt` | Compilation engine (`kpt`, `kustomize`, `helm`) |
| `renderTimeout` | string | `5m` | Maximum time for rendering operations |

#### `deliveryConfig` (optional)
Manages resource delivery to target sites.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `targetSite` | string | `both` | Deployment target (`edge1`, `edge2`, `both`) |
| `gitOpsRepo` | string | - | GitOps repository URL |
| `syncWaitTimeout` | string | `10m` | Maximum wait for sync completion |

#### `gatesConfig` (optional)
Defines validation gates and SLO thresholds.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Enable/disable validation gates |
| `sloThresholds` | map[string]string | - | Key-value pairs of metric thresholds |
| `postCheckScript` | string | - | Path to custom validation script |

#### `rollbackConfig` (optional)
Controls automatic rollback behavior.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `autoRollback` | bool | `true` | Enable automatic rollback on failure |
| `maxRetries` | int | `3` | Maximum rollback attempts |
| `retainFailedArtifacts` | bool | `true` | Keep debug information for failed deployments |

## Status Fields

### Primary Status

#### `phase` (string)
Current lifecycle phase of the deployment.

Valid values:
- `Pending`: Initial state, awaiting processing
- `Compiling`: Converting intent to KRM manifests
- `Rendering`: Processing through kpt/kustomize pipelines
- `Delivering`: Pushing to GitOps and syncing
- `Validating`: Running SLO checks and gates
- `Succeeded`: Deployment complete and validated
- `Failed`: Deployment or validation failed
- `RollingBack`: Reverting to previous state

#### `observedGeneration` (int64)
The generation of the IntentDeployment that was last processed.

#### `lastUpdateTime` (Time)
Timestamp of the last status update.

### Detailed Status Sections

#### `compiledManifests` (string)
The generated Kubernetes manifests in YAML format.

#### `deliveryStatus` (object)
Tracks GitOps delivery progress.

| Field | Type | Description |
|-------|------|-------------|
| `gitCommit` | string | SHA of the deployment commit |
| `syncState` | string | GitOps sync status (`Pending`, `Syncing`, `Synced`, `Failed`) |
| `sites` | map[string]SiteStatus | Per-site deployment status |

#### `validationResults` (array)
List of validation check outcomes.

Each result contains:
- `name`: Check identifier
- `passed`: Boolean result
- `message`: Human-readable description
- `metrics`: Numerical results map

#### `rollbackStatus` (object)
Current rollback operation state.

| Field | Type | Description |
|-------|------|-------------|
| `active` | bool | Whether rollback is in progress |
| `reason` | string | Why rollback was triggered |
| `previousCommit` | string | Target commit for restoration |
| `attempts` | int | Number of attempts made |

#### `conditions` (array)
Standard Kubernetes conditions for observability.

## Example CR

```yaml
apiVersion: tna.tna.ai/v1alpha1
kind: IntentDeployment
metadata:
  name: edge-analytics-deployment
  namespace: nephio-system
spec:
  intent: |
    Deploy analytics service to edge sites with
    3 replicas and auto-scaling enabled

  compileConfig:
    engine: kpt
    renderTimeout: 5m

  deliveryConfig:
    targetSite: both
    gitOpsRepo: https://github.com/org/gitops-repo
    syncWaitTimeout: 10m

  gatesConfig:
    enabled: true
    sloThresholds:
      error_rate: "0.01"
      latency_p99: "200ms"
      availability: "99.9"

  rollbackConfig:
    autoRollback: true
    maxRetries: 3
    retainFailedArtifacts: true

status:
  phase: Validating
  observedGeneration: 2
  lastUpdateTime: "2025-09-16T10:30:00Z"

  compiledManifests: |
    apiVersion: apps/v1
    kind: Deployment
    ...

  deliveryStatus:
    gitCommit: "abc123def"
    syncState: Synced
    sites:
      edge1:
        state: Deployed
        message: "Successfully deployed"
        lastSyncTime: "2025-09-16T10:28:00Z"
      edge2:
        state: Deployed
        message: "Successfully deployed"
        lastSyncTime: "2025-09-16T10:29:00Z"

  validationResults:
  - name: error_rate_check
    passed: true
    message: "Error rate 0.005 below threshold 0.01"
    metrics:
      current: "0.005"
      threshold: "0.01"

  conditions:
  - type: Available
    status: "True"
    reason: ValidationPassed
    message: "All SLO checks passed"
    lastTransitionTime: "2025-09-16T10:30:00Z"
```

## Controller Behavior

### Reconciliation Loop

1. **Phase: Pending**
   - Validate spec fields
   - Initialize status
   - Transition to Compiling

2. **Phase: Compiling**
   - Parse intent (NL or JSON)
   - Generate KRM manifests
   - Store in `compiledManifests`
   - Transition to Rendering

3. **Phase: Rendering**
   - Apply kpt/kustomize transformations
   - Validate generated resources
   - Transition to Delivering

4. **Phase: Delivering**
   - Commit to GitOps repository
   - Monitor sync status
   - Update per-site status
   - Transition to Validating

5. **Phase: Validating**
   - Execute SLO checks
   - Run custom validation scripts
   - Collect metrics
   - Transition to Succeeded or Failed

6. **Phase: Failed**
   - If `autoRollback` enabled, transition to RollingBack
   - Otherwise, remain in Failed state

7. **Phase: RollingBack**
   - Revert GitOps commits
   - Re-sync previous state
   - Update rollback status
   - Transition to Failed (if max retries exceeded) or Succeeded

### Environment Variables

The controller respects these environment variables:

- `GITOPS_REPO_URL`: Default GitOps repository
- `RENDER_TIMEOUT`: Default render timeout
- `SYNC_WAIT_TIMEOUT`: Default sync wait timeout
- `SLO_CHECK_INTERVAL`: Validation check frequency
- `ROLLBACK_ENABLED`: Global rollback toggle

## Validation

### OpenAPI Schema Validation

- `intent`: Required, non-empty string
- `targetSite`: Enum validation (edge1|edge2|both)
- `engine`: Enum validation (kpt|kustomize|helm)
- Timeout fields: Duration string format

### Webhook Validation

Additional validation via admission webhooks:
- Intent syntax validation (JSON parsing)
- GitOps repository accessibility
- SLO threshold format validation
- Resource name conflicts

## Metrics

The controller exposes these Prometheus metrics:

- `intentdeployment_phase_duration_seconds`: Time spent in each phase
- `intentdeployment_validation_results`: SLO check outcomes
- `intentdeployment_rollback_total`: Rollback operation count
- `intentdeployment_sync_duration_seconds`: GitOps sync time

## Security Considerations

- No credentials stored in CR
- GitOps authentication via ServiceAccount
- Validation script execution in sandboxed environment
- Audit logging for all phase transitions

## Future Enhancements

- Support for multi-cluster deployments
- Integration with external intent engines
- Advanced rollback strategies (canary, blue-green)
- Machine learning-based intent interpretation
- Real-time SLO monitoring dashboard integration