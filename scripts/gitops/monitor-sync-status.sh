#!/bin/bash

# GitOps Sync Status Monitoring Script
# Monitors Config Sync status across edge sites

set -euo pipefail

# Configuration
NAMESPACE="config-management-system"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
MAX_RETRIES="${MAX_RETRIES:-10}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

check_sync_status() {
    local site_name="$1"
    local detailed="${2:-false}"

    info "Checking sync status for $site_name..."

    # Check if RootSync exists
    if ! kubectl get rootsync ${site_name}-sync -n $NAMESPACE &> /dev/null; then
        error "RootSync ${site_name}-sync not found"
        return 1
    fi

    # Get sync status
    local sync_status
    sync_status=$(kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "Unknown")

    local reconciling_status
    reconciling_status=$(kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Reconciling")].status}' 2>/dev/null || echo "Unknown")

    local stalled_status
    stalled_status=$(kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Stalled")].status}' 2>/dev/null || echo "Unknown")

    # Get last sync commit
    local last_sync_commit
    last_sync_commit=$(kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.sync.commit}' 2>/dev/null || echo "Unknown")

    local last_sync_time
    last_sync_time=$(kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.sync.lastUpdate}' 2>/dev/null || echo "Unknown")

    # Get error count
    local error_count
    error_count=$(kubectl get rootsync ${site_name}-sync -n $NAMESPACE -o jsonpath='{.status.sync.errorSummary.totalCount}' 2>/dev/null || echo "0")

    # Display status
    echo ""
    echo "=== $site_name Sync Status ==="
    echo "Synced: $sync_status"
    echo "Reconciling: $reconciling_status"
    echo "Stalled: $stalled_status"
    echo "Last Commit: $last_sync_commit"
    echo "Last Update: $last_sync_time"
    echo "Error Count: $error_count"

    if [ "$detailed" = "true" ]; then
        echo ""
        echo "=== Detailed Status ==="
        kubectl describe rootsync ${site_name}-sync -n $NAMESPACE
        echo ""
        echo "=== Recent Logs ==="
        kubectl logs -n $NAMESPACE -l app=root-reconciler --tail=20 || warn "Could not fetch logs"
    fi

    # Return status
    if [ "$sync_status" = "True" ] && [ "$stalled_status" != "True" ] && [ "$error_count" = "0" ]; then
        log "$site_name sync is healthy"
        return 0
    else
        warn "$site_name sync has issues"
        return 1
    fi
}

check_cluster_resources() {
    local site_name="$1"

    info "Checking deployed resources for $site_name..."

    # Check namespaces
    local namespaces
    namespaces=$(kubectl get namespaces -l site=$site_name --no-headers 2>/dev/null | wc -l || echo "0")
    echo "Namespaces with site=$site_name: $namespaces"

    # Check deployments
    local deployments
    deployments=$(kubectl get deployments -A -l site=$site_name --no-headers 2>/dev/null | wc -l || echo "0")
    echo "Deployments with site=$site_name: $deployments"

    # Check services
    local services
    services=$(kubectl get services -A -l site=$site_name --no-headers 2>/dev/null | wc -l || echo "0")
    echo "Services with site=$site_name: $services"

    # Check ConfigMaps
    local configmaps
    configmaps=$(kubectl get configmaps -A -l site=$site_name --no-headers 2>/dev/null | wc -l || echo "0")
    echo "ConfigMaps with site=$site_name: $configmaps"
}

wait_for_sync() {
    local site_name="$1"
    local timeout="${2:-300}"

    log "Waiting for $site_name sync to complete (timeout: ${timeout}s)..."

    local start_time
    start_time=$(date +%s)

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $timeout ]; then
            error "Timeout waiting for $site_name sync to complete"
            return 1
        fi

        if check_sync_status "$site_name" false &> /dev/null; then
            log "$site_name sync completed successfully"
            return 0
        fi

        info "Waiting for $site_name sync... (${elapsed}s elapsed)"
        sleep $CHECK_INTERVAL
    done
}

monitor_continuous() {
    local sites=("$@")

    log "Starting continuous monitoring for sites: ${sites[*]}"
    log "Check interval: ${CHECK_INTERVAL}s"
    log "Press Ctrl+C to stop"

    while true; do
        echo ""
        echo "========================"
        echo "Sync Status Check - $(date)"
        echo "========================"

        for site in "${sites[@]}"; do
            check_sync_status "$site" false || true
            check_cluster_resources "$site"
            echo "------------------------"
        done

        sleep $CHECK_INTERVAL
    done
}

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] COMMAND [SITES...]

Monitor GitOps sync status for edge sites

Commands:
  status SITE         Check sync status for a specific site
  wait SITE [TIMEOUT] Wait for sync to complete (default timeout: 300s)
  monitor SITES...    Continuously monitor multiple sites
  all                 Check status for all known sites (edge1, edge2)

Options:
  -h, --help          Show this help message
  -d, --detailed      Show detailed status information
  -i, --interval SEC  Check interval for monitoring (default: $CHECK_INTERVAL)
  -n, --namespace NS  Config Sync namespace (default: $NAMESPACE)

Examples:
  $0 status edge1
  $0 status edge1 --detailed
  $0 wait edge1 600
  $0 monitor edge1 edge2
  $0 all
EOF
}

main() {
    local command=""
    local sites=()
    local detailed=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--detailed)
                detailed=true
                shift
                ;;
            -i|--interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            status|wait|monitor|all)
                command="$1"
                shift
                break
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                error "Unknown command: $1"
                ;;
        esac
    done

    # Get remaining arguments as sites
    sites=("$@")

    # Validate command
    if [ -z "$command" ]; then
        error "Command is required. Use -h for help."
    fi

    # Check kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
    fi

    case $command in
        status)
            if [ ${#sites[@]} -ne 1 ]; then
                error "Status command requires exactly one site"
            fi
            check_sync_status "${sites[0]}" "$detailed"
            check_cluster_resources "${sites[0]}"
            ;;
        wait)
            if [ ${#sites[@]} -lt 1 ] || [ ${#sites[@]} -gt 2 ]; then
                error "Wait command requires site and optional timeout"
            fi
            local timeout=300
            if [ ${#sites[@]} -eq 2 ]; then
                timeout="${sites[1]}"
            fi
            wait_for_sync "${sites[0]}" "$timeout"
            ;;
        monitor)
            if [ ${#sites[@]} -eq 0 ]; then
                error "Monitor command requires at least one site"
            fi
            monitor_continuous "${sites[@]}"
            ;;
        all)
            sites=("edge1" "edge2")
            for site in "${sites[@]}"; do
                echo ""
                check_sync_status "$site" "$detailed" || true
                check_cluster_resources "$site"
                echo "========================"
            done
            ;;
        *)
            error "Unknown command: $command"
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi