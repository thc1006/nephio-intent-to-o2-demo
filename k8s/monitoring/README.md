# Nephio Intent-to-O2 Monitoring System

This directory contains a comprehensive monitoring solution for the Nephio Intent-to-O2 demonstration environment, providing centralized monitoring for multi-site Edge deployments and GitOps orchestration.

## Architecture Overview

```
                     ┌──────────────────────────┐
                     │   VM-1 (SMO/GitOps)      │
                     │   - Prometheus            │
                     │   - Grafana               │
                     │   - AlertManager          │
                     │   - Metrics Collector     │
                     └──────────┬───────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
         ┌──────────▼──────────┐  ┌────────▼──────────┐
         │   Edge-1 (VM-2)     │  │   Edge-2 (VM-4)  │
         │   - SLO Service     │  │   - SLO Service   │
         │   - O2IMS Service   │  │   - O2IMS Service │
         │   - K8s Metrics     │  │   - K8s Metrics   │
         └─────────────────────┘  └───────────────────┘
```

## Components

### 1. Prometheus
- **Purpose**: Metrics collection and storage
- **Port**: 31090
- **Features**:
  - Multi-site metrics collection
  - Edge-1 and Edge-2 monitoring
  - O2IMS service monitoring
  - SLO metrics collection
  - GitOps sync status monitoring

### 2. Grafana
- **Purpose**: Visualization and dashboards
- **Port**: 31300
- **Credentials**: admin / nephio123!
- **Features**:
  - Multi-site overview dashboard
  - O2IMS monitoring dashboard
  - SLO performance dashboard
  - GitOps status dashboard

### 3. AlertManager
- **Purpose**: Alert management and routing
- **Port**: 31093
- **Features**:
  - Critical alerts for service outages
  - Performance threshold alerts
  - Multi-channel notification support

### 4. Custom Metrics Collector
- **Purpose**: Collect custom metrics from edge sites
- **Port**: 8000
- **Features**:
  - Edge site connectivity monitoring
  - Service availability checks
  - GitOps synchronization status
  - Custom business metrics

## Monitored Services

### Edge Sites
- **Edge-1 (172.16.4.45)**:
  - SLO Service: Port 30090
  - O2IMS Service: Port 31280
  - Kubernetes API: Port 6443

- **Edge-2 (172.16.4.176)**:
  - SLO Service: Port 30090
  - O2IMS Service: Port 31280
  - Kubernetes API: Port 6443

### Central Services (VM-1)
- **GitOps (Gitea)**: Port 8888
- **Prometheus**: Port 31090
- **Grafana**: Port 31300
- **AlertManager**: Port 31093

## Quick Start

### 1. Complete Setup (Recommended)
```bash
# Deploy everything in one command
./scripts/setup_complete_monitoring.sh
```

### 2. Individual Components
```bash
# Deploy just Prometheus and Grafana
./scripts/deploy_monitoring.sh

# Deploy AlertManager separately
kubectl apply -f k8s/monitoring/alertmanager-deployment.yaml

# Start metrics collector
python3 scripts/monitoring_metrics_collector.py
```

### 3. Status Checks
```bash
# Check overall status
./scripts/deploy_monitoring.sh --status

# Run health check
./scripts/deploy_monitoring.sh --health

# Verify deployment
./scripts/setup_complete_monitoring.sh --verify
```

## Configuration

### Main Configuration File
- **Location**: `configs/monitoring-config.yaml`
- **Purpose**: Central configuration for all monitoring components
- **Key Settings**:
  - Edge site IP addresses and ports
  - GitOps repository settings
  - Alert thresholds
  - Collection intervals

### Prometheus Configuration
- **Location**: `k8s/monitoring/prometheus-deployment.yaml`
- **Scrape Targets**:
  - Edge-1 SLO: `172.16.4.45:30090`
  - Edge-1 O2IMS: `172.16.4.45:31280`
  - Edge-2 SLO: `172.16.4.176:30090`
  - Edge-2 O2IMS: `172.16.4.176:31280`
  - Local services and GitOps

### Grafana Dashboards
- **Multi-Site Overview**: Service availability across all sites
- **O2IMS Monitoring**: O-RAN O2 interface metrics
- **SLO Dashboard**: Service Level Objective tracking
- **GitOps Status**: Synchronization and deployment status

## Access Information

### Web Interfaces
```
Prometheus:   http://172.16.0.78:31090
Grafana:      http://172.16.0.78:31300 (admin/nephio123!)
AlertManager: http://172.16.0.78:31093
Metrics API:  http://172.16.0.78:8000/metrics
```

### Command Line Tools
```bash
# View Prometheus targets
curl http://172.16.0.78:31090/api/v1/targets

# Check Grafana health
curl http://172.16.0.78:31300/api/health

# Query custom metrics
curl http://172.16.0.78:8000/metrics
```

## Alert Rules

### Critical Alerts
- **EdgeSiteUnreachable**: Edge site connectivity lost
- **O2IMSServiceDown**: O2IMS service unavailable
- **SLOServiceDown**: SLO monitoring service down

### Warning Alerts
- **HighLatencyDetected**: 95th percentile latency > 1s
- **HighErrorRate**: Error rate > 5%
- **GitOpsSyncFailure**: GitOps synchronization issues

### Performance Alerts
- **HighMemoryUsage**: Memory usage > 85%
- **HighCPUUsage**: CPU usage > 85%

## Troubleshooting

### Common Issues

#### 1. Services Not Accessible
```bash
# Check Kubernetes pods
kubectl get pods -n monitoring

# Check service endpoints
kubectl get svc -n monitoring

# Check NodePort availability
netstat -tlnp | grep :3109
```

#### 2. Edge Sites Not Reachable
```bash
# Test connectivity
ping 172.16.4.45
ping 172.16.4.176

# Test specific ports
nc -z 172.16.4.45 30090
nc -z 172.16.4.176 31280
```

#### 3. Metrics Not Appearing
```bash
# Check metrics collector logs
sudo journalctl -u nephio-metrics-collector -f

# Verify Prometheus targets
curl http://172.16.0.78:31090/api/v1/targets
```

### Log Locations
- **Prometheus**: `kubectl logs -n monitoring deployment/prometheus`
- **Grafana**: `kubectl logs -n monitoring deployment/grafana`
- **Metrics Collector**: `sudo journalctl -u nephio-metrics-collector`
- **Setup Logs**: `/tmp/complete_monitoring_setup_*.log`

## Maintenance

### Regular Tasks
1. **Monitor Storage**: Check Prometheus storage usage
2. **Update Dashboards**: Keep Grafana dashboards current
3. **Review Alerts**: Tune alert thresholds based on usage
4. **Log Rotation**: Manage log file sizes

### Backup Procedures
```bash
# Backup Prometheus data
kubectl exec -n monitoring deployment/prometheus -- tar -czf /tmp/prometheus-backup.tar.gz /prometheus/

# Backup Grafana dashboards
kubectl get configmap -n monitoring grafana-multi-site-dashboard -o yaml > grafana-backup.yaml
```

### Updates
```bash
# Update monitoring configuration
kubectl apply -f k8s/monitoring/

# Restart metrics collector
sudo systemctl restart nephio-metrics-collector

# Rolling update Prometheus
kubectl rollout restart deployment/prometheus -n monitoring
```

## Integration with GitOps

The monitoring system integrates with the GitOps workflow:

1. **Sync Status Monitoring**: Tracks RootSync health across edge sites
2. **Deployment Metrics**: Monitors successful/failed deployments
3. **Configuration Drift**: Detects when edge sites drift from desired state
4. **Performance Impact**: Measures GitOps operation impact on edge performance

## Security Considerations

1. **Access Control**: Grafana uses basic authentication
2. **Network Security**: Services exposed only on necessary ports
3. **Data Protection**: Metrics contain no sensitive information
4. **Audit Trail**: All access logged for compliance

## Performance Tuning

### Prometheus Optimizations
- **Retention**: 30 days (configurable)
- **Scrape Interval**: 30 seconds
- **Storage**: Optimized for time-series data

### Grafana Optimizations
- **Refresh Rate**: 30 seconds default
- **Query Optimization**: Efficient PromQL queries
- **Dashboard Caching**: Reduced load on Prometheus

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review logs in `/tmp/` and systemd journals
3. Verify network connectivity to edge sites
4. Ensure Kubernetes cluster is healthy

## Files Structure

```
k8s/monitoring/
├── README.md                          # This file
├── prometheus-deployment.yaml         # Prometheus configuration
├── grafana-deployment.yaml           # Grafana configuration
├── alertmanager-deployment.yaml      # AlertManager configuration
└── charts/                           # Helm chart templates
    ├── prometheus/
    │   └── values.yaml
    └── grafana/
        └── values.yaml

scripts/
├── deploy_monitoring.sh              # Basic deployment script
├── setup_complete_monitoring.sh      # Complete setup script
├── monitoring_metrics_collector.py   # Custom metrics collector
├── monitoring_status.sh             # Status check script
└── monitoring_healthcheck.sh        # Automated health check

configs/
└── monitoring-config.yaml           # Main configuration file
```