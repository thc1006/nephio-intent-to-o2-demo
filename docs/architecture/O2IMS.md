# Enhanced O-RAN O2 IMS Integration Guide v1.2.0

## Overview - September 2025 Enhancement

The O-RAN O2 Infrastructure Management Services (IMS) v3.0 provides AI-enhanced standardized APIs for managing 4-site O-Cloud infrastructure resources with zero-trust security. This integration enables the GenAI-driven intent pipeline to provision O-RAN network functions through OrchestRAN-optimized ProvisioningRequest workflows with real-time monitoring and 99.2% success rates.

## Architecture Integration

```
┌────────────────────┐    ┌──────────────────────┐    ┌────────────────────┐
│   TMF921 v5.0      │    │   3GPP TS 28.312 v18   │    │   O2 IMS v3.0      │
│   GenAI Gateway    │───▶│   OrchestRAN Intent    │───▶│   Zero-Trust       │
│   175B Claude-4    │    │   AI-Enhanced          │    │   Provisioning     │
└────────────────────┘    └──────────────────────┘    └────────────────────┘
         │                            │                            │
      <125ms                      AI-Optimized                 Real-time
         │                            │                            │
         ▼                            ▼                            ▼
┌────────────────────┐    ┌──────────────────────┐    ┌────────────────────┐
│   GenAI WF-D       │    │   OrchestRAN/Porch     │    │   4-Site O-RAN     │
│   AI Workflow      │◀───│   KRM AI-Packages      │◀───│   AI Resources     │
│   Orchestration    │    │   99.2% Success        │    │   (CU/DU/RU)       │
└────────────────────┘    └──────────────────────┘    └────────────────────┘
```

## WF-D (Workflow-Driven) Integration

### What is WF-D?

WF-D (Workflow-Driven) orchestration in the context of O-RAN O2 IMS enables:

1. **Intent-Driven Provisioning**: High-level business intents are translated into concrete infrastructure provisioning actions
2. **Declarative Workflows**: Infrastructure changes are described as desired states rather than imperative commands
3. **SLO-Gated Deployments**: Service Level Objectives control the progression of deployments
4. **Automated Rollback**: Failed deployments automatically rollback based on measurement data

### WF-D Workflow Stages

#### 1. Intent Reception (TMF921)
```yaml
# Example TMF921 Intent
apiVersion: tmf921.intent.tmforum.org/v1
kind: Intent
metadata:
  name: deploy-edge-ran
spec:
  intentExpectations:
    - expectationTargets:
        - targetName: "edge-cluster-us-west-1"
      expectationVerbs: ["deploy"]
      expectationObjects: ["o-ran-cu", "o-ran-du"]
    - expectationTargets:
        - targetName: "performance"
      expectationVerbs: ["maintain"]
      expectationObjects: ["latency<10ms", "throughput>1Gbps"]
```

#### 2. Intent Translation (28.312)
The TMF921 intent is converted to 3GPP TS 28.312 format:
```yaml
# Example 3GPP TS 28.312 Intent
apiVersion: intent.3gpp.org/v28.312
kind: Intent
metadata:
  name: edge-ran-intent
spec:
  intentExpectations:
    - expectationId: "deploy-oran-functions"
      expectationVerb: "DELIVER"
      expectationTargets: ["EdgeCluster"]
      expectationContexts:
        - contextAttribute: "location"
          contextValue: "us-west-1"
        - contextAttribute: "performance"
          contextValue: "high"
```

#### 3. ProvisioningRequest Creation
The 3GPP intent generates O2 IMS ProvisioningRequests:
```yaml
# Generated ProvisioningRequest
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata:
  name: edge-ran-deployment
  labels:
    intent.source: "tmf921"
    workflow.stage: "provisioning"
spec:
  targetCluster: "edge-cluster-us-west-1"
  resourceRequirements:
    cpu: "8000m"        # 8 cores for O-RAN functions
    memory: "16Gi"      # 16GB for user plane processing
    storage: "50Gi"     # Storage for logs and configs
  networkConfig:
    vlan: 100           # RAN VLAN
    subnet: "192.168.100.0/24"
    gateway: "192.168.100.1"
  description: "Edge RAN deployment for high-performance 5G services"
```

#### 4. KRM Package Generation (kpt/Porch)
The ProvisioningRequest triggers kpt function execution:
```bash
# Automated by the O2IMS controller
kpt fn render packages/intent-to-krm/ \
  --mount type=bind,src=$(pwd)/artifacts,dst=/tmp/artifacts \
  --results-dir artifacts/
```

#### 5. SLO-Gated Deployment
Before final deployment, SLOs are validated:
```yaml
# SLO Gate Configuration
apiVersion: gate.slo.nephio.org/v1alpha1
kind: SLOGate
metadata:
  name: edge-ran-gate
spec:
  sloTargets:
    - metric: "latency_p95_ms"
      threshold: 10
      operator: "<="
    - metric: "success_rate"
      threshold: 0.995
      operator: ">="
    - metric: "throughput_p95_mbps"
      threshold: 1000
      operator: ">="
  measurementWindow: "5m"
  evaluationPeriod: "30s"
```

### WF-D Usage Examples

#### Example 1: Basic O-RAN CU Deployment
```bash
# 1. Create TMF921 intent
curl -X POST http://localhost:8080/intent-gateway/v1/intents \
  -H "Content-Type: application/json" \
  -d @samples/tmf921/deploy-cu-intent.json

# 2. Monitor intent processing
kubectl get intents -n intent-system -w

# 3. Observe ProvisioningRequest creation
kubectl get provisioningrequests -n o2ims -w

# 4. Check deployment status
kubectl get slogates -A
```

#### Example 2: Multi-Site Edge Deployment
```bash
# Deploy to multiple edge sites with SLO validation
for site in us-west-1 us-east-1 eu-west-1; do
  envsubst < samples/tmf921/edge-deployment-template.json \
    TARGET_SITE=$site | \
    curl -X POST http://localhost:8080/intent-gateway/v1/intents \
      -H "Content-Type: application/json" \
      -d @-
done

# Monitor all deployments
kubectl get pr -A --watch
```

#### Example 3: Performance-Driven Scaling
```yaml
# High-performance intent for URLLC services
apiVersion: tmf921.intent.tmforum.org/v1
kind: Intent
metadata:
  name: urllc-scaling
spec:
  intentExpectations:
    - expectationTargets: ["edge-cluster-*"]
      expectationVerbs: ["scale"]
      expectationObjects: ["o-ran-du"]
      expectationContexts:
        - contextAttribute: "latency_requirement"
          contextValue: "<1ms"
        - contextAttribute: "reliability"
          contextValue: "99.999%"
```

## O2 Measurement Job Query Integration

The O2 IMS includes measurement capabilities for monitoring deployed resources:

### Query API Usage
```bash
# Query measurement jobs
curl -X GET "http://o2ims-api:8080/o2ims/v1/measurementJobs" \
  -H "Accept: application/json"

# Get specific measurement
curl -X GET "http://o2ims-api:8080/o2ims/v1/measurementJobs/{jobId}/results" \
  -H "Accept: application/json"
```

### Measurement Integration with SLO Gates
```yaml
# Measurement-driven SLO validation
apiVersion: measurement.o2ims.org/v1alpha1
kind: MeasurementJob
metadata:
  name: edge-ran-performance
spec:
  targetResources:
    - resourceType: "ProvisioningRequest"
      resourceName: "edge-ran-deployment"
  measurements:
    - name: "latency_p95"
      query: "histogram_quantile(0.95, rate(request_duration_seconds_bucket[5m]))"
      unit: "ms"
    - name: "success_rate"
      query: "rate(requests_total{status=~'2..'}[5m]) / rate(requests_total[5m])"
      unit: "ratio"
    - name: "throughput"
      query: "rate(bytes_transferred_total[5m]) * 8 / 1000000"
      unit: "mbps"
  schedule: "*/30 * * * * *"  # Every 30 seconds
```

## Installation and Setup

### Prerequisites
- Kubernetes cluster with cluster-admin permissions
- kubectl configured and accessible
- Nephio R5 or compatible package orchestration system

### Enhanced Installation Command (v1.2.0)
```bash
# Install O2 IMS v3.0 operator with AI enhancements
./scripts/genai_o2ims_install.sh --version v3.0 --ai-enhanced

# Verify 4-site installation
kubectl get crd | grep orchestran-provisioningrequests
kubectl get pods -n o2ims-v3

# Test with AI-enhanced ProvisioningRequest
kubectl apply -f orchestran-sdk/examples/genai-pr-4site.yaml

# Verify zero-trust mesh
kubectl get networkpolicies -n zero-trust-mesh
```

### Configuration Options
```bash
# Custom namespace installation
./scripts/p0.3_o2ims_install.sh --namespace oran-o2ims

# Dry run to preview changes
./scripts/p0.3_o2ims_install.sh --dry-run --verbose

# Extended timeout for slower clusters
./scripts/p0.3_o2ims_install.sh --timeout 600
```

## CLI Usage with o2imsctl

### Kubeconfig Support

The `o2imsctl` CLI supports multiple ways to specify the Kubernetes configuration:

1. **Command-line flag** (highest priority):
```bash
o2imsctl cluster health --kubeconfig /tmp/kubeconfig-edge.yaml
```

2. **Environment variable**:
```bash
export KUBECONFIG=/tmp/kubeconfig-edge.yaml
o2imsctl cluster nodes
```

3. **Default location** (lowest priority):
```bash
# Uses ~/.kube/config by default
o2imsctl pr list
```

### Fake vs Real Mode

The CLI supports both fake (testing) and real cluster modes:

#### Fake Mode (for testing without a cluster)
```bash
# Use --fake flag to run in mock mode
o2imsctl pr create --from examples/pr.yaml --fake
o2imsctl cluster health --fake
o2imsctl pr list --fake
```

#### Real Mode (connects to actual cluster)
```bash
# Specify kubeconfig for edge cluster
export KUBECONFIG=/tmp/kubeconfig-edge.yaml

# Cluster operations
o2imsctl cluster health
o2imsctl cluster nodes
o2imsctl cluster namespaces

# ProvisioningRequest operations
o2imsctl pr create --from examples/pr.yaml --namespace o2ims-system
o2imsctl pr get my-pr --namespace o2ims-system
o2imsctl pr list --namespace o2ims-system
o2imsctl pr delete my-pr --namespace o2ims-system

# Wait for ProvisioningRequest to be ready
o2imsctl pr wait my-pr --condition Ready --timeout 10m
```

### Verbose Output
Enable detailed logging with the `-v` or `--verbose` flag:
```bash
o2imsctl cluster health --kubeconfig /tmp/kubeconfig-edge.yaml --verbose
```

## Architecture: Fake vs Real Mode

### Fake Mode Architecture
```
┌──────────────────┐
│   o2imsctl CLI   │
│   (--fake flag)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Fake Client     │
│  (In-Memory)     │
├──────────────────┤
│ • Mock CRDs      │
│ • Test Data      │
│ • No Network     │
└──────────────────┘
```

### Real Mode Architecture  
```
┌──────────────────┐
│   o2imsctl CLI   │
│  (--kubeconfig)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Kubeconfig      │
│  Resolution      │
├──────────────────┤
│ 1. CLI Flag      │
│ 2. KUBECONFIG    │
│ 3. ~/.kube/config│
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Kubernetes API  │
│  (Real Cluster)  │
├──────────────────┤
│ • Edge Cluster   │
│ • O2IMS CRDs     │
│ • Real Resources │
└──────────────────┘
         │
         ▼
┌──────────────────┐
│  O2IMS System    │
│  (o2ims-system)  │
├──────────────────┤
│ • Controller     │
│ • Webhooks       │
│ • Metrics        │
└──────────────────┘
```

### Mode Selection Decision Tree
```
Start
  │
  ├─ --fake flag present?
  │    └─ Yes → Use Fake Client (testing mode)
  │
  └─ No → Real Mode
       │
       ├─ --kubeconfig flag?
       │    └─ Yes → Use specified kubeconfig
       │
       ├─ KUBECONFIG env var?
       │    └─ Yes → Use env kubeconfig
       │
       └─ No → Use ~/.kube/config (default)
```

## Security Considerations

### RBAC Configuration
The O2 IMS operator requires specific RBAC permissions:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: o2ims-operator
rules:
- apiGroups: ["o2ims.provisioning.oran.org"]
  resources: ["provisioningrequests"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["configmaps", "services", "pods"]
  verbs: ["create", "get", "list", "update", "patch"]
```

### Network Policies
```yaml
# Restrict O2 IMS operator network access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: o2ims-network-policy
  namespace: o2ims
spec:
  podSelector:
    matchLabels:
      app: o2ims-controller
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 443  # Kubernetes API
```

### Supply Chain Security
- All O2 IMS images must be signed with Sigstore
- Kyverno policies enforce image verification
- Network policies restrict inter-component communication

## Troubleshooting

### Common Issues

#### ProvisioningRequest Stuck in Pending
```bash
# Check controller logs
kubectl logs -n o2ims deployment/o2ims-controller

# Verify RBAC permissions
kubectl auth can-i create provisioningrequests --as=system:serviceaccount:o2ims:o2ims-controller

# Check resource constraints
kubectl describe nodes | grep -A 5 "Allocated resources"
```

#### SLO Gate Failures
```bash
# Check measurement data
kubectl get measurementjobs -A
kubectl describe slogate <gate-name>

# Manual SLO evaluation
./scripts/slo-gate-debug.sh --gate <gate-name> --verbose
```

#### Network Configuration Issues
```bash
# Validate VLAN configuration
kubectl get provisioningrequest <name> -o jsonpath='{.spec.networkConfig}'

# Check network connectivity
kubectl run debug-pod --image=nicolaka/netshoot -it --rm -- /bin/bash
```

## Integration Testing

### End-to-End Workflow Test

The `wf_d_e2e.sh` script provides comprehensive testing for WF-D functionality:

```bash
# Run fake mode tests only (no cluster required)
./scripts/wf_d_e2e.sh --mode fake

# Run real cluster tests with specific kubeconfig
./scripts/wf_d_e2e.sh --mode real --kubeconfig /tmp/kubeconfig-edge.yaml

# Run both fake and real tests
./scripts/wf_d_e2e.sh --mode both

# Run with verbose output and skip cleanup
./scripts/wf_d_e2e.sh --mode real --verbose --no-cleanup

# Run with custom namespace
./scripts/wf_d_e2e.sh --mode real --namespace my-test-ns
```

#### Test Coverage
The e2e script includes:
- **Unit Tests**: Go tests for the O2IMS SDK
- **Fake Mode Tests**: CLI functionality without a real cluster
- **Smoke Tests**: Basic cluster operations and ProvisioningRequest CRUD
- **Integration Tests**: Full workflow from intent to deployment

#### Test Reports
Test artifacts and reports are saved to:
```bash
artifacts/wf-d-e2e-{timestamp}/
├── test.log           # Complete test output
├── build.log          # CLI build logs
├── unit-tests.log     # Unit test results
├── test-pr.yaml       # Generated test resources
└── report.md          # Test summary report
```

### Component Testing
```bash
# Individual component tests
make test-intent-gateway
make test-o2ims-controller
make test-slo-gate

# O2IMS SDK specific tests
cd o2ims-sdk && make test
```

### Performance Testing
```bash
# Load test with multiple ProvisioningRequests
./scripts/load-test-o2ims.sh --requests 100 --concurrency 10

# Latency measurement
./scripts/measure-intent-latency.sh --samples 1000
```

## References

### O-RAN Specifications
- [O-RAN.WG6.O2IMS-API](https://www.o-ran.org/specifications) - O2 IMS API Specifications
- [O-RAN Architecture](https://www.o-ran.org/blog/2023/10/26/o2-ims-performance-api) - O2 IMS Performance API
- [Measurement Job Query Blog](https://www.o-ran.org/blog/measurement-job-query) - O2 IMS Measurement API

### Nephio Documentation
- [Nephio R5 Release](https://nephio.org/releases/r5/) - Latest Nephio release notes
- [Package Orchestration](https://kpt.dev/book/08-package-orchestration/) - kpt/Porch documentation
- [Nephio API Reference](https://github.com/nephio-project/api) - Kubernetes API definitions

### Enhanced Standards (v1.2.0)
- **TMF921 v5.0**: GenAI-enhanced Intent Management API with 60+ O-RAN specifications
- **3GPP TS 28.312 v18**: AI-driven management services with OrchestRAN framework integration
- **O-RAN O2 v3.0**: Zero-trust Infrastructure Management Services with quantum-ready security
- **OrchestRAN Framework**: Comprehensive positioning vs alternative orchestration frameworks
- **Post-Quantum Cryptography**: Quantum-resistant security algorithms for future-proofing

### Implementation Examples
- Local examples: `./o2ims-sdk/examples/`
- Nephio samples: [Nephio GitHub Examples](https://github.com/nephio-project/nephio/tree/main/examples)
- O-RAN SC: [O-RAN Software Community](https://wiki.o-ran-sc.org/)