# O-Cloud Provisioning Samples

This directory contains sample Custom Resources (CRs) for O-Cloud provisioning using the FoCoM operator and O2 IMS APIs.

## Resources

### 1. OCloud (`ocloud.yaml`)
Defines an edge O-Cloud managed by FoCoM:
- Specifies cluster location and endpoints
- References kubeconfig secret for authentication
- Includes capacity and compliance metadata

### 2. TemplateInfo (`template-info.yaml`)
Defines a deployment template for 5G RAN workloads:
- Parameterized configuration for DU/CU deployment
- Resource requirements and constraints
- Service mesh and observability settings

### 3. ProvisioningRequest (`provisioning-request.yaml`)
Triggers actual workload deployment:
- References template and target cluster
- Specifies parameter overrides
- Includes SLA requirements and lifecycle hooks

## Usage

### Option 1: Using the P0.4A Script
```bash
# Run the end-to-end provisioning script
./scripts/p0.4A_ocloud_provision.sh
```

### Option 2: Manual Deployment with Kustomize
```bash
# Apply all resources using kustomize
kubectl apply -k samples/ocloud/

# Or render first to review
kustomize build samples/ocloud/ | kubectl apply -f -
```

### Option 3: Individual Resource Application
```bash
# Create namespace
kubectl create namespace o2ims

# Create edge cluster kubeconfig secret
kubectl create secret generic edge-cluster-kubeconfig \
  --from-file=kubeconfig=/tmp/kubeconfig-edge.yaml \
  --namespace=o2ims

# Apply resources in order
kubectl apply -f samples/ocloud/ocloud.yaml
kubectl apply -f samples/ocloud/template-info.yaml
kubectl apply -f samples/ocloud/provisioning-request.yaml
```

## Verification

Check provisioning status:
```bash
# View all O2IMS resources
kubectl get ocloud,templateinfo,provisioningrequest -n o2ims

# Watch provisioning progress
kubectl get provisioningrequest edge-5g-deployment -n o2ims -w

# Check cluster status
kubectl describe cluster edge-ocloud -n o2ims
```

## Customization

### Environment Variables
- `O2IMS_NAMESPACE`: Target namespace (default: o2ims)
- `VM2_IP`: Edge cluster IP address (default: 172.16.4.45)
- `SMO_KUBECONFIG`: Path to SMO cluster kubeconfig
- `EDGE_KUBECONFIG`: Path to edge cluster kubeconfig

### Kustomization Overlays
Create environment-specific overlays:
```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../samples/ocloud

patches:
  - target:
      kind: ProvisioningRequest
      name: edge-5g-deployment
    patch: |-
      - op: replace
        path: /spec/parameters/du_replicas
        value: 1
```

## Architecture

```
┌─────────────────────┐
│    SMO Cluster      │
│  ┌───────────────┐  │
│  │ FoCoM Operator│  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Provisioning  │  │
│  │   Request     │  │
│  └───────┬───────┘  │
└──────────┼──────────┘
           │
      ┌────▼────┐
      │ Secret  │
      │(kubeconfig)
      └────┬────┘
           │
┌──────────▼──────────┐
│    Edge Cluster     │
│  ┌───────────────┐  │
│  │  5G RAN DU/CU │  │
│  │   Workloads   │  │
│  └───────────────┘  │
└─────────────────────┘
```

## Troubleshooting

### Common Issues

1. **ProvisioningRequest stuck in Pending**
   - Check FoCoM operator logs
   - Verify edge cluster kubeconfig secret exists
   - Ensure template references are correct

2. **Authentication failures**
   - Verify edge cluster is reachable
   - Check kubeconfig validity
   - Ensure proper RBAC permissions

3. **Resource capacity issues**
   - Check edge cluster available resources
   - Review resource requests in template
   - Consider scaling down replicas

### Debug Commands
```bash
# FoCoM operator logs
kubectl logs -n focom-system -l app.kubernetes.io/name=focom-operator

# O2IMS events
kubectl get events -n o2ims --sort-by='.lastTimestamp'

# Provisioning request details
kubectl describe provisioningrequest edge-5g-deployment -n o2ims
```

## References
- [Nephio R5 Documentation](https://nephio.org/docs)
- [O-RAN O2 IMS Specification](https://www.o-ran.org/specifications)
- [FoCoM Operator Guide](https://github.com/nephio-project/focom)