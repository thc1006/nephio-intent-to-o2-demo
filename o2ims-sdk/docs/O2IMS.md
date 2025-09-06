# O2 IMS SDK Documentation

## Overview

The O2 IMS (Infrastructure Management Services) SDK provides a Kubernetes-native implementation for managing O-RAN infrastructure resources following the O-RAN Alliance O2 specifications. This SDK integrates with Nephio to enable intent-driven provisioning of O-RAN network functions.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Intent        │    │   TMF921 Intent  │    │   3GPP TS       │
│   Gateway       │───▶│   (TIO/CTK       │───▶│   28.312        │
│                 │    │   validated)     │    │   Intent        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │   kpt/Porch      │    │   KRM packages  │
│   Resources     │◀───│   Functions      │◀───│   (Config-as-   │
│                 │    │                  │    │    Code)        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   O2 IMS        │    │   Provisioning   │    │   Infrastructure│
│   Controller    │───▶│   Request        │───▶│   Resources     │
│                 │    │   (CRD)          │    │   (O-RAN NFs)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Key Components

### 1. ProvisioningRequest Custom Resource Definition (CRD)

The `ProvisioningRequest` CRD is the primary resource managed by the O2 IMS SDK. It represents a request to provision O-RAN infrastructure resources.

#### API Group and Version
- **API Group**: `o2ims.provisioning.oran.org`
- **Version**: `v1alpha1`
- **Kind**: `ProvisioningRequest`
- **Short Name**: `pr`

#### Resource Structure

```yaml
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: example-pr
  namespace: default
spec:
  targetCluster: string              # Required
  resourceRequirements:              # Required
    cpu: string                      # e.g., "2000m"
    memory: string                   # e.g., "4Gi" 
    storage: string                  # e.g., "10Gi"
  networkConfig:                     # Optional
    vlan: int32                      # VLAN ID (1-4094)
    subnet: string                   # CIDR notation
    gateway: string                  # Gateway IP
  description: string                # Optional
status:
  observedGeneration: int64
  phase: string                      # Pending|Processing|Ready|Failed
  conditions:
    - type: string                   # Condition type
      status: string                 # True|False|Unknown
      lastTransitionTime: string     # RFC3339 timestamp
      reason: string                 # Brief reason
      message: string                # Human readable message
  provisionedResources:
    key: value                       # Map of provisioned resources
```

### 2. Status Lifecycle

ProvisioningRequests follow a well-defined lifecycle:

1. **Pending** - Request has been created and is queued for processing
2. **Processing** - Resources are being provisioned
3. **Ready** - All resources have been successfully provisioned
4. **Failed** - Provisioning encountered an error

### 3. Client SDK

The SDK provides both real and fake client implementations:

- **Real Client**: Uses controller-runtime client for actual Kubernetes API calls
- **Fake Client**: In-memory implementation for testing with simulated status progression

## Nephio Integration

### Integration with Nephio R5

This SDK is designed to work with [Nephio R5](https://nephio.org/) and follows Nephio patterns:

1. **Package Management**: Integrates with kpt and Porch for configuration management
2. **Intent-Driven**: Supports conversion from high-level intents to resource specifications  
3. **GitOps**: Enables SLO-gated GitOps workflows
4. **Multi-cluster**: Supports deployment across multiple edge clusters

### Nephio O2IMS Operator

The SDK works with the [Nephio O2IMS Operator](https://github.com/nephio-project/nephio/tree/main/controllers/o2ims) which:

- Reconciles `ProvisioningRequest` resources
- Manages O-RAN network function lifecycles
- Provides status reporting back to management systems
- Integrates with Nephio's package orchestration

## O-RAN Specifications

This implementation follows O-RAN Alliance specifications:

### O-RAN O2 Interface Specifications

- **O-RAN.WG6.O2IMS-ARCH-v01.00**: O2 IMS Architecture
- **O-RAN.WG6.O2IMS-API-v01.00**: O2 IMS API Specifications  
- **O-RAN.WG6.O2DMS-API-v01.00**: O2 DMS (Deployment Management Service)

### Supported O-RAN Network Functions

The ProvisioningRequest can provision various O-RAN network functions:

- **CU-CP**: Central Unit Control Plane
- **CU-UP**: Central Unit User Plane  
- **DU**: Distributed Unit
- **RU**: Radio Unit (via O1 interface)
- **RIC**: RAN Intelligent Controller
- **SMO**: Service Management and Orchestration

## Usage Examples

### Creating a ProvisioningRequest

```bash
# Create from YAML file
o2imsctl pr create --from examples/pr.yaml

# Create from stdin
cat examples/pr.yaml | o2imsctl pr create --from -

# Use fake mode for testing
o2imsctl pr create --from examples/pr.yaml --fake
```

### Monitoring Status

```bash
# Get specific ProvisioningRequest
o2imsctl pr get example-pr

# List all ProvisioningRequests  
o2imsctl pr list

# Wait for Ready condition
o2imsctl pr wait example-pr --timeout 10m

# Wait for specific condition
o2imsctl pr wait example-pr --condition Processing --timeout 5m
```

### Status Monitoring Output

```yaml
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: example-pr
  namespace: default
spec:
  targetCluster: "edge-cluster-us-west1-a"
  resourceRequirements:
    cpu: "8000m"
    memory: "16Gi"
    storage: "50Gi"
status:
  observedGeneration: 1
  phase: "Ready"
  conditions:
    - type: "Ready"
      status: "True"
      lastTransitionTime: "2025-01-06T10:30:00Z"
      reason: "ProvisioningComplete"
      message: "All resources provisioned successfully"
  provisionedResources:
    deployment: "example-pr-deployment"
    service: "example-pr-service"
    configmap: "example-pr-config"
```

## Development

### Building the SDK

```bash
# Install dependencies
make deps

# Generate code and manifests
make generate

# Run tests
make test

# Build CLI
make build

# Run fake mode demo
make demo-fake
```

### Testing with Fake Client

The fake client provides realistic behavior for development and testing:

```go
// Create fake client
scheme := runtime.NewScheme()
o2imsv1alpha1.AddToScheme(scheme)

fakeClient := client.NewFakeO2IMSClient(client.FakeClientOptions{
    Scheme: scheme,
    InitialObjects: []client.Object{},
})

// Use like real client
prInterface := fakeClient.ProvisioningRequests("default")
pr, err := prInterface.Create(ctx, &provisioningRequest, metav1.CreateOptions{})
```

### Running Tests

```bash
# Run all tests with envtest
make test

# Run with coverage
make test-coverage

# Verify RED phase (tests should initially fail)
make verify-red-phase
```

## Configuration Examples

### Basic O-RAN CU Deployment

```yaml
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: oran-cu-basic
  labels:
    oran.org/deployment-type: "5g-ran"
    nephio.org/package-name: "o-ran-cu"
spec:
  targetCluster: "edge-cluster-001"
  resourceRequirements:
    cpu: "4000m"
    memory: "8Gi"  
    storage: "20Gi"
  networkConfig:
    vlan: 100
    subnet: "192.168.100.0/24"
    gateway: "192.168.100.1"
```

### Multi-Cluster Edge Deployment

```yaml
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: edge-ran-cluster
  annotations:
    nephio.org/region: "us-west1"
    nephio.org/zone: "us-west1-a"
spec:
  targetCluster: "nephio-edge-us-west1-a"
  resourceRequirements:
    cpu: "16000m"   # 16 cores for high-performance RAN
    memory: "32Gi"  # 32GB for user plane processing
    storage: "100Gi"
  description: |
    High-performance edge RAN deployment supporting:
    - 5000+ simultaneous users
    - Ultra-low latency services (URLLC)
    - Network slicing for different service types
```

## Troubleshooting

### Common Issues

1. **ProvisioningRequest Stuck in Pending**
   ```bash
   # Check controller logs
   kubectl logs -n o2ims-system o2ims-controller-manager
   
   # Check resource constraints
   o2imsctl pr get <name> -o yaml
   ```

2. **Resource Allocation Failures**
   ```bash
   # Verify cluster has sufficient resources
   kubectl top nodes
   kubectl describe nodes
   
   # Check for resource quotas
   kubectl get resourcequota -A
   ```

3. **Network Configuration Issues**
   ```bash
   # Validate VLAN configuration
   o2imsctl pr get <name> -o json | jq '.spec.networkConfig'
   
   # Check network policies
   kubectl get networkpolicies -A
   ```

### Debug Mode

Enable verbose logging:
```bash
o2imsctl pr get example-pr --verbose
o2imsctl pr list --verbose --fake
```

## Integration with CI/CD

### GitHub Actions Integration

```yaml
name: O2 IMS Provisioning
on:
  workflow_dispatch:
    inputs:
      target_cluster:
        description: 'Target cluster for deployment'
        required: true

jobs:
  provision:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup o2imsctl  
        run: |
          make build
          sudo cp bin/o2imsctl /usr/local/bin/
          
      - name: Deploy O-RAN Functions
        run: |
          o2imsctl pr create --from deployments/oran-cu.yaml
          o2imsctl pr wait oran-cu --timeout 15m
```

### Validation Hooks

```bash
# Pre-commit validation
make validate-examples

# Schema validation  
o2imsctl validate --file examples/pr.yaml --schema

# Resource policy checks
o2imsctl pr create --from examples/pr.yaml --dry-run
```

## Security Considerations

### RBAC Configuration

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: o2ims-provisioner
rules:
- apiGroups: ["o2ims.provisioning.oran.org"]
  resources: ["provisioningrequests"]
  verbs: ["create", "get", "list", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["configmaps", "services"]
  verbs: ["create", "get", "list", "update", "patch"]
```

### Network Security

- Use NetworkPolicies to restrict traffic between O-RAN functions
- Implement proper VLAN segmentation for different interfaces (F1, E1, N2, N3)
- Enable encryption for inter-function communication

### Resource Limits

```yaml
spec:
  resourceRequirements:
    cpu: "2000m"
    memory: "4Gi"
    # Enforce limits to prevent resource exhaustion
  securityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
```

## References

### O-RAN Alliance Specifications
- [O-RAN Architecture Description](https://oranalliance.atlassian.net/wiki/spaces/OAD)
- [O-RAN O2 General Aspects and Principles](https://oranalliance.atlassian.net/wiki/spaces/ORAN)

### Nephio Documentation  
- [Nephio Architecture](https://nephio.org/docs/architecture/)
- [Nephio Package Orchestration](https://nephio.org/docs/packages/)
- [Nephio R5 Release Notes](https://github.com/nephio-project/nephio/releases)

### Kubernetes Documentation
- [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Controller Runtime](https://controller-runtime.sigs.k8s.io/)
- [Kubebuilder](https://kubebuilder.io/)

### Standards
- **3GPP TS 28.312**: Intent driven management services for mobile networks
- **TMF921**: Intent Management API
- **ITU-T Y.3172**: Architectural framework for machine learning in future networks including IMT-2020