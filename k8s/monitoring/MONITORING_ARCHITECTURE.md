# Monitoring Architecture

## Overview
Multi-site monitoring stack deployed on VM-1 (SMO) to monitor Edge-1 (VM-2) and Edge-2 (VM-4) sites.

## Components

### Prometheus (VM-1)
- **Port**: 31090 (NodePort)
- **Retention**: 30 days / 50GB
- **Scrape Targets**:
  - Edge-1 K8s API: `172.16.4.45:6443`
  - Edge-2 K8s API: `172.16.4.176:6443`
  - Edge-1 SLO Service: `172.16.4.45:30090`
  - Edge-2 SLO Service: `172.16.4.176:30090`
  - Edge-1 O2IMS: `172.16.4.45:31280`
  - Edge-2 O2IMS: `172.16.4.176:31280`
  - GitOps Status: `localhost:8888` (Gitea)
  - VM-1 Node Exporter: `localhost:9100`

### Grafana (VM-1)
- **Port**: 31300 (NodePort)
- **Admin**: admin/nephio123!
- **Datasources**:
  - Prometheus-Central: `http://prometheus:9090` (default)
  - Edge1-Metrics: Direct SLO endpoint
  - Edge2-Metrics: Direct SLO endpoint
- **Dashboards**:
  - Multi-Site Overview
  - O2IMS Service Status
  - SLO Monitoring
  - GitOps Sync Status

### AlertManager (VM-1)
- **Port**: 31093 (NodePort)
- **Routes**:
  - Critical alerts → webhook
  - Infrastructure alerts → webhook
  - O2IMS alerts → webhook
- **Webhook Target**: `localhost:5001` (not deployed)

## Data Flow

```
Edge-1 (172.16.4.45)          Edge-2 (172.16.4.176)
├── K8s API :6443              ├── K8s API :6443
├── SLO Service :30090         ├── SLO Service :30090
└── O2IMS :31280               └── O2IMS :31280
         ↓                              ↓
         └──────────┬───────────────────┘
                    ↓
            Prometheus (VM-1)
            localhost:31090
                    ↓
         ┌──────────┴───────────┐
         ↓                      ↓
    Grafana                AlertManager
    :31300                 :31093
```

## Alert Rules

### Critical Alerts
- **EdgeSiteDown**: Site unreachable for >2min
- **O2IMSServiceDown**: O2IMS down for >1min
- **SLOServiceDown**: SLO monitoring down for >1min

### Warning Alerts
- **HighErrorRateMultiSite**: Error rate >5% for >2min
- **GitOpsSyncFailure**: Sync failures detected

## Access URLs
- Prometheus: `http://172.16.0.78:31090`
- Grafana: `http://172.16.0.78:31300`
- AlertManager: `http://172.16.0.78:31093`

## Known Issues
1. Grafana datasource configuration inconsistency (port 30090 vs 30091)
2. AlertManager webhook receiver not deployed (localhost:5001)
3. Edge site Prometheus instances may not be exposed on expected ports

## Security Notes
- Basic auth configured for edge K8s API access
- Anonymous viewer access enabled in Grafana
- TLS verification disabled for edge K8s API scraping