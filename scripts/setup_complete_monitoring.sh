#!/bin/bash

# setup_complete_monitoring.sh - Complete monitoring system setup for Nephio Intent-to-O2 Demo
# This script deploys Prometheus, Grafana, AlertManager and sets up monitoring automation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONITORING_DIR="$PROJECT_ROOT/k8s/monitoring"
CONFIG_DIR="$PROJECT_ROOT/configs"
LOG_FILE="/tmp/complete_monitoring_setup_$(date +%Y%m%d_%H%M%S).log"

# Network configuration
EDGE1_IP="172.16.4.45"
EDGE2_IP="172.16.4.176"
VM1_IP="172.16.0.78"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
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

info() {
    echo -e "${PURPLE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to print header
print_header() {
    echo ""
    echo "=============================================================="
    echo "    NEPHIO INTENT-TO-O2 MONITORING SYSTEM SETUP"
    echo "=============================================================="
    echo ""
    echo "This script will deploy a comprehensive monitoring solution:"
    echo "  • Prometheus for metrics collection"
    echo "  • Grafana for visualization and dashboards"
    echo "  • AlertManager for alerting"
    echo "  • Automated monitoring scripts"
    echo "  • Health checks and status monitoring"
    echo ""
    echo "Target Sites:"
    echo "  • Edge-1: $EDGE1_IP (VM-2)"
    echo "  • Edge-2: $EDGE2_IP (VM-4)"
    echo "  • VM-1:   $VM1_IP (SMO/GitOps Orchestrator)"
    echo ""
    echo "=============================================================="
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check Python for metrics collector
    if ! command -v python3 &> /dev/null; then
        error "python3 not found. Please install Python 3."
        exit 1
    fi

    # Check if we can access Kubernetes cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot access Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    # Install Python dependencies if needed
    if ! python3 -c "import prometheus_client, requests, yaml" 2>/dev/null; then
        log "Installing Python dependencies..."
        pip3 install prometheus_client requests pyyaml || {
            error "Failed to install Python dependencies"
            exit 1
        }
    fi

    success "Prerequisites check passed"
}

# Function to test connectivity to edge sites
test_edge_connectivity() {
    log "Testing connectivity to edge sites..."

    local connectivity_ok=true

    # Test Edge-1
    info "Testing Edge-1 ($EDGE1_IP)..."
    if timeout 5 ping -c 1 "$EDGE1_IP" &>/dev/null; then
        success "  Ping to Edge-1: OK"

        if timeout 5 nc -z "$EDGE1_IP" 30090 2>/dev/null; then
            success "  Edge-1 SLO service (30090): OK"
        else
            warning "  Edge-1 SLO service (30090): NOT REACHABLE"
            connectivity_ok=false
        fi

        if timeout 5 nc -z "$EDGE1_IP" 31280 2>/dev/null; then
            success "  Edge-1 O2IMS service (31280): OK"
        else
            warning "  Edge-1 O2IMS service (31280): NOT REACHABLE"
            connectivity_ok=false
        fi
    else
        warning "  Ping to Edge-1: FAILED"
        connectivity_ok=false
    fi

    # Test Edge-2
    info "Testing Edge-2 ($EDGE2_IP)..."
    if timeout 5 ping -c 1 "$EDGE2_IP" &>/dev/null; then
        success "  Ping to Edge-2: OK"

        if timeout 5 nc -z "$EDGE2_IP" 30090 2>/dev/null; then
            success "  Edge-2 SLO service (30090): OK"
        else
            warning "  Edge-2 SLO service (30090): NOT REACHABLE"
            connectivity_ok=false
        fi

        if timeout 5 nc -z "$EDGE2_IP" 31280 2>/dev/null; then
            success "  Edge-2 O2IMS service (31280): OK"
        else
            warning "  Edge-2 O2IMS service (31280): NOT REACHABLE"
            connectivity_ok=false
        fi
    else
        warning "  Ping to Edge-2: FAILED"
        connectivity_ok=false
    fi

    if $connectivity_ok; then
        success "Edge connectivity test completed - all services reachable"
    else
        warning "Some edge services are not reachable - monitoring will show them as down"
    fi
}

# Function to deploy monitoring namespace
deploy_namespace() {
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

    log "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring

    # Verify Prometheus is accessible
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if timeout 5 curl -s "http://localhost:31090/-/healthy" &>/dev/null; then
            success "Prometheus is running and accessible"
            break
        fi
        log "Waiting for Prometheus to be accessible (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        error "Prometheus failed to become accessible"
        return 1
    fi

    success "Prometheus deployed successfully"
}

# Function to deploy Grafana
deploy_grafana() {
    log "Deploying Grafana..."

    kubectl apply -f "$MONITORING_DIR/grafana-deployment.yaml"

    log "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring

    # Verify Grafana is accessible
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if timeout 5 curl -s "http://localhost:31300/api/health" &>/dev/null; then
            success "Grafana is running and accessible"
            break
        fi
        log "Waiting for Grafana to be accessible (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        error "Grafana failed to become accessible"
        return 1
    fi

    success "Grafana deployed successfully"
}

# Function to deploy AlertManager
deploy_alertmanager() {
    log "Deploying AlertManager..."

    kubectl apply -f "$MONITORING_DIR/alertmanager-deployment.yaml"

    log "Waiting for AlertManager to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/alertmanager -n monitoring

    success "AlertManager deployed successfully"
}

# Function to start metrics collector
start_metrics_collector() {
    log "Starting metrics collector service..."

    # Create systemd service file for metrics collector
    cat > "/tmp/nephio-metrics-collector.service" << EOF
[Unit]
Description=Nephio Monitoring Metrics Collector
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/python3 $SCRIPT_DIR/monitoring_metrics_collector.py --config $CONFIG_DIR/monitoring-config.yaml --port 8000
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=nephio-metrics

[Install]
WantedBy=multi-user.target
EOF

    # Install and start the service
    sudo cp /tmp/nephio-metrics-collector.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable nephio-metrics-collector
    sudo systemctl start nephio-metrics-collector

    # Wait a moment and check if it's running
    sleep 5
    if sudo systemctl is-active --quiet nephio-metrics-collector; then
        success "Metrics collector service started successfully"
    else
        error "Failed to start metrics collector service"
        sudo systemctl status nephio-metrics-collector
    fi
}

# Function to create monitoring dashboard shortcuts
create_shortcuts() {
    log "Creating monitoring dashboard shortcuts..."

    cat > "$PROJECT_ROOT/monitoring-links.txt" << EOF
=============================================================
           NEPHIO MONITORING SYSTEM ACCESS
=============================================================

Prometheus:
  URL: http://$VM1_IP:31090
  Description: Metrics collection and querying
  Targets: http://$VM1_IP:31090/targets

Grafana:
  URL: http://$VM1_IP:31300
  Username: admin
  Password: nephio123!
  Description: Visualization dashboards

AlertManager:
  URL: http://$VM1_IP:31093
  Description: Alert management and routing

Metrics Collector:
  URL: http://$VM1_IP:8000/metrics
  Description: Custom metrics endpoint

=============================================================
                    QUICK COMMANDS
=============================================================

Check monitoring status:
  $SCRIPT_DIR/deploy_monitoring.sh --status

Run health check:
  $SCRIPT_DIR/deploy_monitoring.sh --health

View logs:
  sudo journalctl -u nephio-metrics-collector -f

Restart metrics collector:
  sudo systemctl restart nephio-metrics-collector

=============================================================
EOF

    success "Monitoring shortcuts created at $PROJECT_ROOT/monitoring-links.txt"
}

# Function to run comprehensive verification
verify_deployment() {
    log "Running comprehensive deployment verification..."

    echo ""
    echo "=== Kubernetes Pods ==="
    kubectl get pods -n monitoring -o wide

    echo ""
    echo "=== Kubernetes Services ==="
    kubectl get svc -n monitoring

    echo ""
    echo "=== Service Endpoints ==="

    # Test Prometheus
    if timeout 5 curl -s "http://$VM1_IP:31090/-/healthy" &>/dev/null; then
        success "✅ Prometheus (http://$VM1_IP:31090) - Healthy"
    else
        error "❌ Prometheus (http://$VM1_IP:31090) - Not accessible"
    fi

    # Test Grafana
    if timeout 5 curl -s "http://$VM1_IP:31300/api/health" &>/dev/null; then
        success "✅ Grafana (http://$VM1_IP:31300) - Healthy"
    else
        error "❌ Grafana (http://$VM1_IP:31300) - Not accessible"
    fi

    # Test AlertManager
    if timeout 5 curl -s "http://$VM1_IP:31093/-/healthy" &>/dev/null; then
        success "✅ AlertManager (http://$VM1_IP:31093) - Healthy"
    else
        error "❌ AlertManager (http://$VM1_IP:31093) - Not accessible"
    fi

    # Test Metrics Collector
    if timeout 5 curl -s "http://$VM1_IP:8000/metrics" &>/dev/null; then
        success "✅ Metrics Collector (http://$VM1_IP:8000) - Healthy"
    else
        error "❌ Metrics Collector (http://$VM1_IP:8000) - Not accessible"
    fi

    echo ""
    echo "=== Edge Site Monitoring ==="

    # Test edge sites
    for site in "edge1:$EDGE1_IP" "edge2:$EDGE2_IP"; do
        site_name=$(echo "$site" | cut -d: -f1)
        site_ip=$(echo "$site" | cut -d: -f2)

        if timeout 3 curl -s "http://$site_ip:30090/health" &>/dev/null; then
            success "✅ $site_name SLO service ($site_ip:30090) - Reachable"
        else
            warning "⚠️  $site_name SLO service ($site_ip:30090) - Not reachable"
        fi

        if timeout 3 nc -z "$site_ip" 31280 2>/dev/null; then
            success "✅ $site_name O2IMS service ($site_ip:31280) - Reachable"
        else
            warning "⚠️  $site_name O2IMS service ($site_ip:31280) - Not reachable"
        fi
    done

    success "Deployment verification completed"
}

# Function to display final summary
display_summary() {
    echo ""
    echo "=============================================================="
    echo "           MONITORING SYSTEM DEPLOYMENT COMPLETE"
    echo "=============================================================="
    echo ""
    echo "Access URLs:"
    echo "  🔍 Prometheus: http://$VM1_IP:31090"
    echo "  📊 Grafana:    http://$VM1_IP:31300 (admin/nephio123!)"
    echo "  🚨 Alerts:     http://$VM1_IP:31093"
    echo "  📈 Metrics:    http://$VM1_IP:8000/metrics"
    echo ""
    echo "Monitored Sites:"
    echo "  🏢 Edge-1: $EDGE1_IP (SLO: 30090, O2IMS: 31280)"
    echo "  🏢 Edge-2: $EDGE2_IP (SLO: 30090, O2IMS: 31280)"
    echo ""
    echo "Management Commands:"
    echo "  Status:  $SCRIPT_DIR/deploy_monitoring.sh --status"
    echo "  Health:  $SCRIPT_DIR/deploy_monitoring.sh --health"
    echo "  Logs:    sudo journalctl -u nephio-metrics-collector -f"
    echo ""
    echo "Configuration:"
    echo "  Config:  $CONFIG_DIR/monitoring-config.yaml"
    echo "  Links:   $PROJECT_ROOT/monitoring-links.txt"
    echo ""
    echo "=============================================================="
    echo ""
    echo "🎉 Monitoring system is ready for use!"
    echo ""
}

# Main execution function
main() {
    print_header

    log "Starting complete monitoring system setup..."
    log "Log file: $LOG_FILE"

    check_prerequisites
    test_edge_connectivity
    deploy_namespace
    deploy_prometheus
    deploy_grafana
    deploy_alertmanager
    start_metrics_collector
    create_shortcuts
    verify_deployment

    success "Complete monitoring system setup finished successfully!"
    display_summary

    log "Setup completed. Log file saved to: $LOG_FILE"
}

# Handle script arguments
case "${1:-}" in
    "--status")
        "$SCRIPT_DIR/deploy_monitoring.sh" --status
        ;;
    "--health")
        "$SCRIPT_DIR/deploy_monitoring.sh" --health
        ;;
    "--verify")
        verify_deployment
        ;;
    "--help")
        echo "Usage: $0 [--status|--health|--verify|--help]"
        echo ""
        echo "Options:"
        echo "  (no args)  Complete monitoring system setup"
        echo "  --status   Check monitoring system status"
        echo "  --health   Run health check"
        echo "  --verify   Run deployment verification"
        echo "  --help     Show this help"
        ;;
    *)
        main "$@"
        ;;
esac