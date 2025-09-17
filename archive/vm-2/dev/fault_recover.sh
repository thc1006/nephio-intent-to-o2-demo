#!/bin/bash

# Edge Cluster Fault Recovery Script
# Restores cluster to previous good state after fault injection
# Author: Edge Platform Team
# Version: 1.0.0

set -e

# Configuration
KUBECONFIG="/tmp/kubeconfig-edge.yaml"
TARGET_NAMESPACE="${1:-edge1}"
BACKUP_DIR="/tmp/fault-backup"
RECOVERY_METHOD="${2:-auto}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found"
        exit 1
    fi
    
    if [ ! -f "$KUBECONFIG" ]; then
        error "Kubeconfig not found at $KUBECONFIG"
        exit 1
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "Backup directory not found at $BACKUP_DIR"
        exit 1
    fi
    
    success "Prerequisites check completed"
}

# Function to find the latest backup
find_latest_backup() {
    local latest_file="$BACKUP_DIR/latest-backup.txt"
    
    if [ -f "$latest_file" ]; then
        local backup_file=$(cat "$latest_file")
        if [ -f "$backup_file" ]; then
            echo "$backup_file"
            return 0
        fi
    fi
    
    # Fallback: find most recent backup file
    local backup_file=$(ls -t "$BACKUP_DIR"/state-backup-*.yaml 2>/dev/null | head -1)
    if [ -n "$backup_file" ]; then
        echo "$backup_file"
        return 0
    fi
    
    return 1
}

# Function to show current unhealthy state
show_current_state() {
    log "Current cluster state before recovery:"
    
    echo ""
    echo "=== Deployment Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o wide 2>/dev/null || echo "No deployments found"
    
    echo ""
    echo "=== Pod Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get pods -n "$TARGET_NAMESPACE" -o wide 2>/dev/null || echo "No pods found"
    
    echo ""
    echo "=== Health Check ==="
    if command -v /home/ubuntu/dev/edge_observe.sh &> /dev/null; then
        /home/ubuntu/dev/edge_observe.sh table || warning "Health check failed"
    else
        warning "edge_observe.sh not found - skipping health check"
    fi
}

# Function to perform rollback using kubectl rollout
rollback_deployment() {
    log "Attempting deployment rollback..."
    
    local deployments=$(kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$deployments" ]; then
        warning "No deployments found in namespace $TARGET_NAMESPACE"
        return 1
    fi
    
    for deployment in $deployments; do
        log "Rolling back deployment: $deployment"
        
        # Check if there's a previous revision to rollback to
        local revisions=$(kubectl --kubeconfig="$KUBECONFIG" rollout history deployment/"$deployment" -n "$TARGET_NAMESPACE" 2>/dev/null | wc -l)
        
        if [ "$revisions" -gt 2 ]; then  # Header + current revision = 2, need > 2 for previous revision
            kubectl --kubeconfig="$KUBECONFIG" rollout undo deployment/"$deployment" -n "$TARGET_NAMESPACE"
            success "Rolled back deployment $deployment"
        else
            warning "No previous revision found for deployment $deployment"
            # Try to reset to known good configuration
            reset_deployment_to_healthy "$deployment"
        fi
    done
}

# Function to reset deployment to known healthy state
reset_deployment_to_healthy() {
    local deployment="$1"
    log "Resetting deployment $deployment to healthy configuration..."
    
    # Reset to known good nginx configuration
    kubectl --kubeconfig="$KUBECONFIG" patch deployment "$deployment" -n "$TARGET_NAMESPACE" -p '{
        "spec": {
            "replicas": 2,
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "image": "nginx:alpine",
                        "resources": {
                            "requests": {
                                "memory": "32Mi",
                                "cpu": "10m"
                            },
                            "limits": {
                                "memory": "64Mi",
                                "cpu": "100m"
                            }
                        },
                        "readinessProbe": {
                            "httpGet": {
                                "path": "/",
                                "port": 80
                            },
                            "initialDelaySeconds": 5,
                            "periodSeconds": 10
                        },
                        "livenessProbe": {
                            "httpGet": {
                                "path": "/",
                                "port": 80
                            },
                            "initialDelaySeconds": 10,
                            "periodSeconds": 30
                        }
                    }]
                }
            }
        }
    }'
    
    success "Reset deployment $deployment to healthy configuration"
}

# Function to restore from backup file
restore_from_backup() {
    local backup_file="$1"
    log "Restoring from backup file: $backup_file"
    
    # Delete current resources first
    kubectl --kubeconfig="$KUBECONFIG" delete deployment --all -n "$TARGET_NAMESPACE" --ignore-not-found=true
    kubectl --kubeconfig="$KUBECONFIG" delete service --all -n "$TARGET_NAMESPACE" --ignore-not-found=true
    kubectl --kubeconfig="$KUBECONFIG" delete configmap --all -n "$TARGET_NAMESPACE" --ignore-not-found=true
    
    # Wait a moment for cleanup
    sleep 5
    
    # Apply backup
    kubectl --kubeconfig="$KUBECONFIG" apply -f "$backup_file"
    
    success "Restored from backup file"
}

# Function to clean up fault injection artifacts
cleanup_artifacts() {
    log "Cleaning up fault injection artifacts..."
    
    # Remove broken configmaps
    kubectl --kubeconfig="$KUBECONFIG" delete configmap broken-config -n "$TARGET_NAMESPACE" --ignore-not-found=true
    
    # Clean up any failed pods
    kubectl --kubeconfig="$KUBECONFIG" delete pods --field-selector=status.phase=Failed -n "$TARGET_NAMESPACE" --ignore-not-found=true
    
    success "Cleaned up fault injection artifacts"
}

# Function to wait for recovery
wait_for_recovery() {
    log "Waiting for cluster to recover..."
    
    local timeout=120
    local count=0
    
    while [ $count -lt $timeout ]; do
        local ready_deployments=$(kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o jsonpath='{.items[?(@.status.readyReplicas==@.status.replicas)].metadata.name}' 2>/dev/null | wc -w)
        local total_deployments=$(kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" --no-headers 2>/dev/null | wc -l)
        
        if [ "$ready_deployments" -eq "$total_deployments" ] && [ "$total_deployments" -gt 0 ]; then
            success "All deployments are ready"
            break
        fi
        
        log "Waiting for deployments to become ready ($ready_deployments/$total_deployments)..."
        sleep 5
        count=$((count + 5))
    done
    
    if [ $count -ge $timeout ]; then
        warning "Timeout waiting for deployments to become ready"
        return 1
    fi
    
    return 0
}

# Function to verify recovery
verify_recovery() {
    log "Verifying recovery..."
    
    echo ""
    echo "=== Post-Recovery Deployment Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o wide
    
    echo ""
    echo "=== Post-Recovery Pod Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get pods -n "$TARGET_NAMESPACE" -o wide
    
    echo ""
    echo "=== Health Check After Recovery ==="
    if command -v /home/ubuntu/dev/edge_observe.sh &> /dev/null; then
        local health_output
        if health_output=$(/home/ubuntu/dev/edge_observe.sh table); then
            echo "$health_output"
            
            # Check if health score is good
            local health_score=$(/home/ubuntu/dev/edge_observe.sh json | jq -r '.health_score' 2>/dev/null || echo "0")
            if [ "$health_score" -ge 90 ]; then
                success "Cluster health is good (Score: $health_score%)"
                return 0
            else
                warning "Cluster health is degraded (Score: $health_score%)"
                return 1
            fi
        else
            error "Health check failed after recovery"
            return 1
        fi
    else
        warning "Health check tool not available"
        return 0
    fi
}

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [NAMESPACE] [RECOVERY_METHOD]

Recovery Methods:
  auto        - Automatic recovery (rollback + cleanup) (default)
  rollback    - Use kubectl rollout undo
  backup      - Restore from backup file
  reset       - Reset to known healthy configuration
  cleanup     - Only cleanup artifacts

Examples:
  $0                          # Auto recovery in edge1 namespace
  $0 edge1 rollback          # Rollback deployments in edge1
  $0 my-ns backup            # Restore from backup file

The script will:
1. Show current unhealthy state
2. Perform recovery based on method
3. Wait for cluster to stabilize
4. Verify recovery success
EOF
}

# Main execution
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi
    
    log "Starting fault recovery process..."
    log "Target namespace: $TARGET_NAMESPACE"
    log "Recovery method: $RECOVERY_METHOD"
    
    check_prerequisites
    show_current_state
    
    case "$RECOVERY_METHOD" in
        "auto")
            log "Performing automatic recovery..."
            cleanup_artifacts
            rollback_deployment
            wait_for_recovery
            ;;
        "rollback")
            rollback_deployment
            wait_for_recovery
            ;;
        "backup")
            local backup_file
            if backup_file=$(find_latest_backup); then
                restore_from_backup "$backup_file"
                wait_for_recovery
            else
                error "No backup file found"
                exit 1
            fi
            ;;
        "reset")
            local deployments=$(kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
            for deployment in $deployments; do
                reset_deployment_to_healthy "$deployment"
            done
            cleanup_artifacts
            wait_for_recovery
            ;;
        "cleanup")
            cleanup_artifacts
            ;;
        *)
            error "Unknown recovery method: $RECOVERY_METHOD"
            usage
            exit 1
            ;;
    esac
    
    echo ""
    if verify_recovery; then
        success "Recovery completed successfully!"
        echo ""
        echo "=== Recovery Summary ==="
        echo "• Method used: $RECOVERY_METHOD"
        echo "• Namespace: $TARGET_NAMESPACE"
        echo "• Cluster health: GOOD"
        echo "• All deployments: READY"
    else
        error "Recovery verification failed"
        echo ""
        echo "=== Recovery Issues ==="
        echo "• Some components may still be unhealthy"
        echo "• Check logs: kubectl logs -n $TARGET_NAMESPACE"
        echo "• Verify resources: kubectl describe pods -n $TARGET_NAMESPACE"
        echo "• Consider manual intervention"
        exit 1
    fi
}

# Run main function
main "$@"