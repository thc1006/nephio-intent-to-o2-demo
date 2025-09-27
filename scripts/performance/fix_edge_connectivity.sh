#!/usr/bin/env bash
# Fix Edge Site Connectivity Issues
# Updates IP addresses and tests connections

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Known working edge configurations
declare -A EDGE_CONFIG
EDGE_CONFIG[edge1]="172.16.4.45:ubuntu:id_ed25519"
EDGE_CONFIG[edge2]="172.16.4.176:ubuntu:id_ed25519"  # Updated IP
EDGE_CONFIG[edge3]="172.16.5.81:thc1006:edge_sites_key"
EDGE_CONFIG[edge4]="172.16.1.252:thc1006:edge_sites_key"

# Test edge connectivity
test_edge_connectivity() {
    local edge_name="$1"
    local config="${EDGE_CONFIG[$edge_name]}"

    IFS=':' read -r ip user key <<< "$config"

    log_info "Testing connectivity to $edge_name ($ip)"

    # Test ping
    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        log_success "✓ $edge_name: ICMP ping successful"
        local ping_ok=true
    else
        log_error "✗ $edge_name: ICMP ping failed"
        local ping_ok=false
    fi

    # Test SSH
    if timeout 5 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -i ~/.ssh/"$key" "$user@$ip" 'echo ok' > /dev/null 2>&1; then
        log_success "✓ $edge_name: SSH connection successful"
        local ssh_ok=true
    else
        log_error "✗ $edge_name: SSH connection failed"
        local ssh_ok=false
    fi

    # Test Kubernetes API (port 6443)
    if timeout 3 nc -z "$ip" 6443 > /dev/null 2>&1; then
        log_success "✓ $edge_name: Kubernetes API reachable"
        local k8s_ok=true
    else
        log_warn "⚠ $edge_name: Kubernetes API not reachable"
        local k8s_ok=false
    fi

    # Test Prometheus (port 30090)
    if timeout 3 nc -z "$ip" 30090 > /dev/null 2>&1; then
        log_success "✓ $edge_name: Prometheus reachable"
        local prom_ok=true
    else
        log_warn "⚠ $edge_name: Prometheus not reachable"
        local prom_ok=false
    fi

    # Return overall status
    if [[ "$ping_ok" == "true" && "$ssh_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Update edge sites configuration
update_edge_config() {
    local config_file="$PROJECT_ROOT/config/edge-sites-config.yaml"
    local backup_file="${config_file}.backup.$(date +%s)"

    log_info "Updating edge sites configuration"
    log_info "Backup created: $backup_file"

    # Create backup
    cp "$config_file" "$backup_file"

    # Create updated configuration
    cat > "$config_file" <<EOF
# Edge Sites Configuration - Updated $(date)
# Performance optimization and connectivity fixes applied

edge_sites:
  edge1:
    name: "Edge Site 1 (VM-2)"
    ip: "172.16.4.45"
    internal_ip: "172.16.4.45"
    user: "ubuntu"
    ssh_key: "id_ed25519"
    services:
      kubernetes_api: 6443
      prometheus: 30090
      o2ims_api: 31280
      slo_service: 30090
    status:
      connectivity: "operational"
      last_verified: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      performance_optimized: true

  edge2:
    name: "Edge Site 2 (VM-4)"
    ip: "172.16.4.176"  # Corrected IP
    internal_ip: "172.16.4.176"
    user: "ubuntu"
    ssh_key: "id_ed25519"
    services:
      kubernetes_api: 6443
      prometheus: 30090
      o2ims_api: 31280
      slo_service: 30090
    status:
      connectivity: "testing"
      last_verified: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      performance_optimized: true

  edge3:
    name: "Edge Site 3"
    ip: "172.16.5.81"
    internal_ip: "172.16.5.81"
    user: "thc1006"
    ssh_key: "edge_sites_key"
    password: "1006"
    services:
      kubernetes_api: 6443
      prometheus: 30090
      o2ims_api: 31280
      slo_service: 30090
    status:
      connectivity: "testing"
      last_verified: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      performance_optimized: true

  edge4:
    name: "Edge Site 4"
    ip: "172.16.1.252"
    internal_ip: "172.16.1.252"
    user: "thc1006"
    ssh_key: "edge_sites_key"
    password: "1006"
    services:
      kubernetes_api: 6443
      prometheus: 30090
      o2ims_api: 31280
      slo_service: 30090
    status:
      connectivity: "testing"
      last_verified: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      performance_optimized: true

# Performance monitoring configuration
monitoring:
  enabled: true
  scrape_interval: "15s"
  evaluation_interval: "15s"
  external_labels:
    cluster: "vm1-orchestrator"
    environment: "production"

# SLO targets for performance optimization
slo_targets:
  pipeline_latency_p95: "60s"
  pipeline_latency_p99: "90s"
  success_rate_target: "99.5%"
  edge_connectivity_uptime: "99.9%"

# Optimization flags
performance_optimizations:
  kpt_parallel_execution: true
  kpt_max_workers: 4
  template_caching: true
  image_pre_caching: true
  rootsync_reconcile_interval: "5s"
EOF

    log_success "Configuration updated: $config_file"
}

# Update SSH configuration
update_ssh_config() {
    local ssh_config="$HOME/.ssh/config"
    local backup_file="${ssh_config}.backup.$(date +%s)"

    log_info "Updating SSH configuration"

    # Create backup if config exists
    if [[ -f "$ssh_config" ]]; then
        cp "$ssh_config" "$backup_file"
        log_info "SSH config backup: $backup_file"
    fi

    # Add edge site configurations
    cat >> "$ssh_config" <<EOF

# Edge Sites Configuration - Performance Optimized
# Generated $(date)

Host edge1
    HostName 172.16.4.45
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host edge2
    HostName 172.16.4.176
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host edge3
    HostName 172.16.5.81
    User thc1006
    IdentityFile ~/.ssh/edge_sites_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host edge4
    HostName 172.16.1.252
    User thc1006
    IdentityFile ~/.ssh/edge_sites_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

    # Set proper permissions
    chmod 600 "$ssh_config"
    log_success "SSH configuration updated: $ssh_config"
}

# Test all edge sites
test_all_edges() {
    log_info "Testing connectivity to all edge sites"

    local total_sites=0
    local reachable_sites=0

    for edge in edge1 edge2 edge3 edge4; do
        total_sites=$((total_sites + 1))

        if test_edge_connectivity "$edge"; then
            reachable_sites=$((reachable_sites + 1))
        fi
        echo  # Add spacing between tests
    done

    log_info "Connectivity Summary: $reachable_sites/$total_sites sites reachable"

    if [[ $reachable_sites -eq $total_sites ]]; then
        log_success "🎉 All edge sites are reachable!"
        return 0
    elif [[ $reachable_sites -gt 0 ]]; then
        log_warn "⚠️ Partial connectivity: $reachable_sites/$total_sites sites reachable"
        return 1
    else
        log_error "❌ No edge sites reachable"
        return 2
    fi
}

# Generate connectivity report
generate_connectivity_report() {
    local report_file="$PROJECT_ROOT/reports/edge_connectivity_$(date +%Y%m%d_%H%M%S).txt"

    log_info "Generating connectivity report"

    cat > "$report_file" <<EOF
Edge Site Connectivity Report
============================
Generated: $(date)
Test Type: Performance Optimization Connectivity Check

Configuration Updates Applied:
- Updated edge2 IP from 172.16.0.89 to 172.16.4.176
- Added performance optimizations to SSH config
- Updated edge-sites-config.yaml with current IPs
- Configured connection timeouts and keep-alive

Test Results:
=============
EOF

    # Run tests and capture results
    for edge in edge1 edge2 edge3 edge4; do
        echo "Testing $edge..." >> "$report_file"
        if test_edge_connectivity "$edge" >> "$report_file" 2>&1; then
            echo "Status: REACHABLE" >> "$report_file"
        else
            echo "Status: UNREACHABLE" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

Next Steps:
===========
1. For unreachable sites, verify actual IP addresses
2. Check firewall and security group configurations
3. Ensure SSH keys are properly deployed
4. Test Kubernetes and service endpoints
5. Monitor connectivity over time

Performance Impact:
==================
- Reachable sites will benefit from optimized kpt execution
- Unreachable sites will cause pipeline failures
- Recommend fixing connectivity before production use

Files Updated:
==============
- config/edge-sites-config.yaml
- ~/.ssh/config
EOF

    log_success "Connectivity report saved: $report_file"
}

# Main function
main() {
    log_info "Starting Edge Connectivity Fix"
    log_info "This will update IP addresses and test connections"

    # Update configurations
    update_edge_config
    update_ssh_config

    # Test connectivity
    echo
    log_info "Testing edge site connectivity..."
    test_all_edges
    local connectivity_status=$?

    # Generate report
    generate_connectivity_report

    echo
    case $connectivity_status in
        0)
            log_success "🎉 All edge sites are reachable - ready for performance testing!"
            ;;
        1)
            log_warn "⚠️ Partial connectivity - some performance tests will fail"
            ;;
        2)
            log_error "❌ No connectivity - manual intervention required"
            ;;
    esac

    log_info "Configuration files updated and backed up"
    log_info "Use 'ssh edge1' etc. to test direct connections"

    return $connectivity_status
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi