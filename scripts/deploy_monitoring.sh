#!/bin/bash

# deploy_monitoring.sh - Deploy Prometheus and Grafana monitoring system on VM-1
# This script deploys comprehensive monitoring for Edge-1, Edge-2, and central services

set -euo pipefail

# Configuration
MONITORING_DIR="/home/ubuntu/nephio-intent-to-o2-demo/k8s/monitoring"
LOG_FILE="/tmp/monitoring_deployment_$(date +%Y%m%d_%H%M%S).log"
EDGE1_IP="172.16.4.45"
EDGE2_IP="172.16.4.176"
VM1_IP="172.16.0.78"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if kubectl is available and cluster is accessible
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    success "Prerequisites check passed"
}

# Function to test edge site connectivity
test_edge_connectivity() {
    log "Testing connectivity to edge sites..."

    # Test Edge-1
    if timeout 5 nc -z "$EDGE1_IP" 30090 2>/dev/null; then
        success "Edge-1 ($EDGE1_IP:30090) SLO service is reachable"
    else
        warning "Edge-1 ($EDGE1_IP:30090) SLO service is not reachable"
    fi

    if timeout 5 nc -z "$EDGE1_IP" 31280 2>/dev/null; then
        success "Edge-1 ($EDGE1_IP:31280) O2IMS service is reachable"
    else
        warning "Edge-1 ($EDGE1_IP:31280) O2IMS service is not reachable"
    fi

    # Test Edge-2
    if timeout 5 nc -z "$EDGE2_IP" 30090 2>/dev/null; then
        success "Edge-2 ($EDGE2_IP:30090) SLO service is reachable"
    else
        warning "Edge-2 ($EDGE2_IP:30090) SLO service is not reachable"
    fi

    if timeout 5 nc -z "$EDGE2_IP" 31280 2>/dev/null; then
        success "Edge-2 ($EDGE2_IP:31280) O2IMS service is reachable"
    else
        warning "Edge-2 ($EDGE2_IP:31280) O2IMS service is not reachable"
    fi
}

# Function to create monitoring namespace
create_namespace() {
    log "Creating monitoring namespace..."

    if kubectl get namespace monitoring &> /dev/null; then
        warning "Monitoring namespace already exists"
    else
        kubectl create namespace monitoring
        success "Monitoring namespace created"
    fi
}

# Function to deploy Prometheus
deploy_prometheus() {
    log "Deploying Prometheus..."

    kubectl apply -f "$MONITORING_DIR/prometheus-deployment.yaml"

    # Wait for Prometheus to be ready
    log "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring

    success "Prometheus deployed successfully"
}

# Function to deploy Grafana
deploy_grafana() {
    log "Deploying Grafana..."

    kubectl apply -f "$MONITORING_DIR/grafana-deployment.yaml"

    # Wait for Grafana to be ready
    log "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

    success "Grafana deployed successfully"
}

# Function to verify services are running
verify_deployment() {
    log "Verifying monitoring deployment..."

    # Check Prometheus
    if kubectl get pod -n monitoring -l app=prometheus | grep -q Running; then
        success "Prometheus is running"
    else
        error "Prometheus is not running properly"
        kubectl get pods -n monitoring -l app=prometheus
    fi

    # Check Grafana
    if kubectl get pod -n monitoring -l app=grafana | grep -q Running; then
        success "Grafana is running"
    else
        error "Grafana is not running properly"
        kubectl get pods -n monitoring -l app=grafana
    fi

    # Check services
    log "Checking services..."
    kubectl get svc -n monitoring
}

# Function to display access information
display_access_info() {
    log "Monitoring system access information:"

    echo ""
    echo "=================================================================="
    echo "            MONITORING SYSTEM ACCESS INFORMATION"
    echo "=================================================================="
    echo ""
    echo "Prometheus:"
    echo "  URL: http://$VM1_IP:31090"
    echo "  Internal: http://prometheus.monitoring.svc.cluster.local:9090"
    echo ""
    echo "Grafana:"
    echo "  URL: http://$VM1_IP:31300"
    echo "  Username: admin"
    echo "  Password: nephio123!"
    echo "  Internal: http://grafana.monitoring.svc.cluster.local:3000"
    echo ""
    echo "Monitoring Targets:"
    echo "  Edge-1 SLO:   $EDGE1_IP:30090"
    echo "  Edge-1 O2IMS: $EDGE1_IP:31280"
    echo "  Edge-2 SLO:   $EDGE2_IP:30090"
    echo "  Edge-2 O2IMS: $EDGE2_IP:31280"
    echo "  GitOps:       $VM1_IP:8888"
    echo ""
    echo "=================================================================="
}

# Function to create monitoring status script
create_monitoring_status_script() {
    log "Creating monitoring status script..."

    cat > "/home/ubuntu/nephio-intent-to-o2-demo/scripts/monitoring_status.sh" << 'EOF'
#!/bin/bash

# monitoring_status.sh - Check monitoring system status

set -euo pipefail

EDGE1_IP="172.16.4.45"
EDGE2_IP="172.16.4.176"
VM1_IP="172.16.0.78"

echo "=========================================="
echo "      MONITORING SYSTEM STATUS"
echo "=========================================="
echo ""

# Check Kubernetes pods
echo "Kubernetes Monitoring Pods:"
kubectl get pods -n monitoring -o wide 2>/dev/null || echo "  Error: Cannot access Kubernetes cluster"
echo ""

# Check services
echo "Kubernetes Monitoring Services:"
kubectl get svc -n monitoring 2>/dev/null || echo "  Error: Cannot access Kubernetes cluster"
echo ""

# Test external endpoints
echo "External Service Connectivity:"

# Prometheus
if timeout 3 curl -s "http://$VM1_IP:31090/-/healthy" > /dev/null 2>&1; then
    echo "  ✅ Prometheus (VM-1:31090): UP"
else
    echo "  ❌ Prometheus (VM-1:31090): DOWN"
fi

# Grafana
if timeout 3 curl -s "http://$VM1_IP:31300/api/health" > /dev/null 2>&1; then
    echo "  ✅ Grafana (VM-1:31300): UP"
else
    echo "  ❌ Grafana (VM-1:31300): DOWN"
fi

# Edge-1 SLO
if timeout 3 curl -s "http://$EDGE1_IP:30090/health" > /dev/null 2>&1; then
    echo "  ✅ Edge-1 SLO ($EDGE1_IP:30090): UP"
else
    echo "  ❌ Edge-1 SLO ($EDGE1_IP:30090): DOWN"
fi

# Edge-1 O2IMS
if timeout 3 nc -z "$EDGE1_IP" 31280 2>/dev/null; then
    echo "  ✅ Edge-1 O2IMS ($EDGE1_IP:31280): UP"
else
    echo "  ❌ Edge-1 O2IMS ($EDGE1_IP:31280): DOWN"
fi

# Edge-2 SLO
if timeout 3 curl -s "http://$EDGE2_IP:30090/health" > /dev/null 2>&1; then
    echo "  ✅ Edge-2 SLO ($EDGE2_IP:30090): UP"
else
    echo "  ❌ Edge-2 SLO ($EDGE2_IP:30090): DOWN"
fi

# Edge-2 O2IMS
if timeout 3 nc -z "$EDGE2_IP" 31280 2>/dev/null; then
    echo "  ✅ Edge-2 O2IMS ($EDGE2_IP:31280): UP"
else
    echo "  ❌ Edge-2 O2IMS ($EDGE2_IP:31280): DOWN"
fi

echo ""
echo "Quick Links:"
echo "  Prometheus: http://$VM1_IP:31090"
echo "  Grafana:    http://$VM1_IP:31300 (admin/nephio123!)"
echo ""
EOF

    chmod +x "/home/ubuntu/nephio-intent-to-o2-demo/scripts/monitoring_status.sh"
    success "Monitoring status script created at scripts/monitoring_status.sh"
}

# Function to setup automated monitoring checks
setup_automated_monitoring() {
    log "Setting up automated monitoring checks..."

    cat > "/home/ubuntu/nephio-intent-to-o2-demo/scripts/monitoring_healthcheck.sh" << 'EOF'
#!/bin/bash

# monitoring_healthcheck.sh - Automated health check for monitoring system
# Run this script periodically via cron

set -euo pipefail

LOGFILE="/var/log/monitoring_healthcheck.log"
EDGE1_IP="172.16.4.45"
EDGE2_IP="172.16.4.176"
VM1_IP="172.16.0.78"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# Check Prometheus
if ! timeout 5 curl -s "http://$VM1_IP:31090/-/healthy" > /dev/null 2>&1; then
    log "ALERT: Prometheus is down"
    # Add notification logic here (email, Slack, etc.)
else
    log "OK: Prometheus is healthy"
fi

# Check Grafana
if ! timeout 5 curl -s "http://$VM1_IP:31300/api/health" > /dev/null 2>&1; then
    log "ALERT: Grafana is down"
    # Add notification logic here
else
    log "OK: Grafana is healthy"
fi

# Check Edge sites
for site in "Edge-1:$EDGE1_IP" "Edge-2:$EDGE2_IP"; do
    site_name=$(echo "$site" | cut -d: -f1)
    site_ip=$(echo "$site" | cut -d: -f2)

    if ! timeout 5 curl -s "http://$site_ip:30090/health" > /dev/null 2>&1; then
        log "ALERT: $site_name SLO service is down"
    else
        log "OK: $site_name SLO service is healthy"
    fi
done

# Rotate log file if it gets too large
if [ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -gt 10485760 ]; then
    mv "$LOGFILE" "$LOGFILE.old"
    touch "$LOGFILE"
fi
EOF

    chmod +x "/home/ubuntu/nephio-intent-to-o2-demo/scripts/monitoring_healthcheck.sh"
    success "Automated monitoring health check script created"
}

# Main execution
main() {
    log "Starting monitoring system deployment..."
    log "Log file: $LOG_FILE"

    check_prerequisites
    test_edge_connectivity
    create_namespace
    deploy_prometheus
    deploy_grafana
    verify_deployment
    create_monitoring_status_script
    setup_automated_monitoring

    success "Monitoring system deployment completed successfully!"
    display_access_info

    log "Deployment log saved to: $LOG_FILE"
}

# Handle script arguments
case "${1:-}" in
    "--status")
        /home/ubuntu/nephio-intent-to-o2-demo/scripts/monitoring_status.sh
        ;;
    "--health")
        /home/ubuntu/nephio-intent-to-o2-demo/scripts/monitoring_healthcheck.sh
        ;;
    "--help")
        echo "Usage: $0 [--status|--health|--help]"
        echo ""
        echo "Options:"
        echo "  (no args)  Deploy monitoring system"
        echo "  --status   Check monitoring system status"
        echo "  --health   Run health check"
        echo "  --help     Show this help"
        ;;
    *)
        main "$@"
        ;;
esac