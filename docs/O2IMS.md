# O-RAN O2 IMS Integration Guide

## Overview

The O-RAN O2 Infrastructure Management Services (IMS) provides standardized APIs for managing O-Cloud infrastructure resources. This integration enables the verifiable intent pipeline to provision O-RAN network functions through standardized ProvisioningRequest workflows.

## Architecture Integration

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   TMF921        │    │   3GPP TS        │    │   O2 IMS        │
│   Intent        │───▶│   28.312         │───▶│   Provisioning  │
│   Gateway       │    │   Intent         │    │   Request       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   WF-D          │    │   kpt/Porch      │    │   O-RAN         │
│   Workflow      │◀───│   KRM Packages   │◀───│   Resources     │
│   Orchestration │    │                  │    │   (CU/DU/RU)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
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

### Installation Command
```bash
# Install O2 IMS operator and CRDs
./scripts/p0.3_o2ims_install.sh

# Verify installation
kubectl get crd | grep provisioningrequests
kubectl get pods -n o2ims

# Test with example ProvisioningRequest
kubectl apply -f o2ims-sdk/examples/pr-minimal.yaml
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
```bash
# Complete pipeline test
make test-e2e-wfd

# Individual component tests
make test-intent-gateway
make test-o2ims-controller
make test-slo-gate
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

### Standards
- **TMF921**: Intent Management API - Business intent specification
- **3GPP TS 28.312**: Intent driven management services - Technical intent format
- **O-RAN O2**: Infrastructure Management Services - O-Cloud management APIs

### Implementation Examples
- Local examples: `./o2ims-sdk/examples/`
- Nephio samples: [Nephio GitHub Examples](https://github.com/nephio-project/nephio/tree/main/examples)
- O-RAN SC: [O-RAN Software Community](https://wiki.o-ran-sc.org/)