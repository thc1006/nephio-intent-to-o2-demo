# Edge2 GitOps Configuration

This directory contains the GitOps configurations for Edge2 (VM-4).

## Deployment Status

- **O2IMS Service**: Configured (nginx placeholder)
  - NodePort: 31280
  - Namespace: o2ims-system

## Sync Configuration

To sync this with Edge2 cluster:

1. Ensure VM-4 has access to VM-1 Gitea (172.16.0.78:8888)
2. Apply the RootSync configuration
3. Monitor sync status

## Services

- O2IMS API: http://172.16.0.89:31280/o2ims
- Health Check: http://172.16.0.89:31280/health