#!/bin/bash

# monitoring_summary.sh - Display comprehensive monitoring system summary

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=============================================================="
echo "        NEPHIO INTENT-TO-O2 MONITORING SYSTEM SUMMARY"
echo "=============================================================="
echo -e "${NC}"

echo -e "${GREEN}📊 DEPLOYED COMPONENTS:${NC}"
echo "  ✅ Prometheus - Metrics collection and storage"
echo "  ✅ Grafana - Visualization dashboards"
echo "  ✅ AlertManager - Alert management and routing"
echo "  ✅ Custom Metrics Collector - Edge site monitoring"
echo "  ✅ Automated health checks and status monitoring"
echo ""

echo -e "${GREEN}🌐 ACCESS URLS:${NC}"
echo "  🔍 Prometheus:   http://172.16.0.78:31090"
echo "  📊 Grafana:      http://172.16.0.78:31300"
echo "     Username:     admin"
echo "     Password:     nephio123!"
echo "  🚨 AlertManager: http://172.16.0.78:31093"
echo "  📈 Metrics API:  http://172.16.0.78:8000/metrics"
echo ""

echo -e "${GREEN}🏢 MONITORED SITES:${NC}"
echo "  Edge-1 (VM-2): 172.16.4.45"
echo "    • SLO Service:  Port 30090"
echo "    • O2IMS Service: Port 31280"
echo "    • K8s API:      Port 6443"
echo ""
echo "  Edge-2 (VM-4): 172.16.4.176"
echo "    • SLO Service:  Port 30090"
echo "    • O2IMS Service: Port 31280"
echo "    • K8s API:      Port 6443"
echo ""
echo "  VM-1 (GitOps): 172.16.0.78"
echo "    • Gitea:        Port 8888"
echo "    • Monitoring:   Ports 31090-31093"
echo ""

echo -e "${GREEN}📋 QUICK COMMANDS:${NC}"
echo "  Status Check:     ./scripts/deploy_monitoring.sh --status"
echo "  Health Check:     ./scripts/deploy_monitoring.sh --health"
echo "  Full Verification: ./scripts/setup_complete_monitoring.sh --verify"
echo "  View Logs:        sudo journalctl -u nephio-metrics-collector -f"
echo "  Restart Collector: sudo systemctl restart nephio-metrics-collector"
echo ""

echo -e "${GREEN}📁 KEY FILES:${NC}"
echo "  Configuration:    configs/monitoring-config.yaml"
echo "  Prometheus:       k8s/monitoring/prometheus-deployment.yaml"
echo "  Grafana:          k8s/monitoring/grafana-deployment.yaml"
echo "  AlertManager:     k8s/monitoring/alertmanager-deployment.yaml"
echo "  Setup Script:     scripts/setup_complete_monitoring.sh"
echo "  Metrics Collector: scripts/monitoring_metrics_collector.py"
echo "  Documentation:    k8s/monitoring/README.md"
echo ""

echo -e "${GREEN}🎯 MONITORING CAPABILITIES:${NC}"
echo "  ✅ Multi-site service availability monitoring"
echo "  ✅ O2IMS service health and metrics"
echo "  ✅ SLO performance tracking"
echo "  ✅ GitOps synchronization status"
echo "  ✅ Infrastructure resource monitoring"
echo "  ✅ Real-time alerting and notifications"
echo "  ✅ Historical data analysis and trending"
echo "  ✅ Custom business metrics collection"
echo ""

echo -e "${GREEN}🔄 AUTOMATED FEATURES:${NC}"
echo "  ✅ Continuous metrics collection (30s intervals)"
echo "  ✅ Automated health checks and status reporting"
echo "  ✅ Self-monitoring and system health validation"
echo "  ✅ Log rotation and maintenance"
echo "  ✅ Alert escalation and notification routing"
echo ""

echo -e "${YELLOW}⚠️  IMPORTANT NOTES:${NC}"
echo "  • Ensure edge sites (172.16.4.45, 172.16.4.176) are accessible"
echo "  • Default Grafana password should be changed in production"
echo "  • Monitor storage usage for Prometheus data retention"
echo "  • Review and adjust alert thresholds based on usage patterns"
echo ""

echo -e "${PURPLE}🚀 NEXT STEPS:${NC}"
echo "  1. Access Grafana at http://172.16.0.78:31300"
echo "  2. Review pre-configured dashboards"
echo "  3. Set up additional notification channels in AlertManager"
echo "  4. Customize alert rules based on your SLO requirements"
echo "  5. Configure automated backup procedures"
echo ""

echo -e "${BLUE}"
echo "=============================================================="
echo "  Monitoring system is ready for production use!"
echo "=============================================================="
echo -e "${NC}"