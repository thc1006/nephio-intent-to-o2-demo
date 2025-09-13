# VM-2 Edge1 O-Cloud Cluster

This directory contains scripts, configurations, and documentation for VM-2, which hosts the edge1 Kubernetes cluster.

## Overview
- **Role**: Edge1 O-Cloud cluster managed by SMO (VM-1) through GitOps
- **Cluster**: Kind cluster named "edge1"
- **Config Sync**: v1.17.0 pulling configs from VM-1's Gitea repository

## Directory Structure
- `scripts/`: Operational scripts for edge1 cluster management
- `host-notes/`: Documentation and deployment notes
- `diagnostics/`: Health check and diagnostic tools

## Key Components
- Edge1 Kind cluster configuration
- GitOps RootSync configurations
- O2IMS operator manifests
- Health monitoring exporters

## GitOps Integration
The edge1 cluster uses Config Sync to pull configurations from VM-1's Gitea repository.
This ensures consistent deployment of network functions across the edge site.
