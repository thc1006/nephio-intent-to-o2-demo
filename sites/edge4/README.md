# Edge4 Site Configuration

This directory contains Kubernetes manifests for edge4 site.

Managed by Config Sync from VM-1.

## Components
- O2IMS: Deployed via kubectl
- Prometheus: Deployed with remote_write to VM-1
- Flagger: Deployed for progressive delivery
- Config Sync: GitOps pull from this directory