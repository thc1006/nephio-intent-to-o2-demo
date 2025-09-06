# Setup Guide

## Hardware Requirements

Minimum:
- 8 vCPU
- 32 GB RAM  
- 200 GB SSD
- Ubuntu 22.04 LTS

## Two-VM Topology

VM1 (Control):
- kind cluster with Nephio R5
- O2 IMS simulator
- Intent gateway

VM2 (Worker):
- kpt/Porch
- GitOps controllers
- Monitoring stack

## Quick Start

```bash
# VM1: Launch kind cluster
./scripts/kind-up.sh

# Install Nephio R5
kubectl apply -f https://github.com/nephio-project/nephio/releases/download/v5.0.0/nephio-r5-components.yaml

# Deploy O2 IMS simulator
kubectl apply -f guardrails/o2ims/simulator.yaml
```

## References

- [Nephio R5 Release](https://github.com/nephio-project/nephio/releases/tag/v5.0.0)
- [O-RAN O2 IMS Spec](https://www.o-ran.org/specifications)
- [kpt Function SDK](https://kpt.dev/book/05-developing-functions/)
- [Sigstore Policy Controller](https://docs.sigstore.dev/policy-controller/overview/)