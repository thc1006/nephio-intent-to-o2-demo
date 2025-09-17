#!/bin/bash

# Edge Cluster Fault Injection Script
# Creates controlled failures to test monitoring and rollback mechanisms
# Author: Edge Platform Team
# Version: 1.0.0

set -e

# Configuration
KUBECONFIG="/tmp/kubeconfig-edge.yaml"
TARGET_NAMESPACE="${1:-edge1}"
FAULT_TYPE="${2:-replicas}"
BACKUP_DIR="/tmp/fault-backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

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
    
    # Check if target namespace exists
    if ! kubectl --kubeconfig="$KUBECONFIG" get ns "$TARGET_NAMESPACE" &>/dev/null; then
        warning "Namespace $TARGET_NAMESPACE not found, creating it..."
        kubectl --kubeconfig="$KUBECONFIG" create ns "$TARGET_NAMESPACE"
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    success "Prerequisites check completed"
}

# Function to backup current state
backup_state() {
    log "Backing up current state..."
    
    local backup_file="$BACKUP_DIR/state-backup-$TIMESTAMP.yaml"
    
    # Backup deployments in target namespace
    kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o yaml > "$backup_file" 2>/dev/null || true
    
    # Backup services
    kubectl --kubeconfig="$KUBECONFIG" get services -n "$TARGET_NAMESPACE" -o yaml >> "$backup_file" 2>/dev/null || true
    
    # Backup configmaps
    kubectl --kubeconfig="$KUBECONFIG" get configmaps -n "$TARGET_NAMESPACE" -o yaml >> "$backup_file" 2>/dev/null || true
    
    echo "$backup_file" > "$BACKUP_DIR/latest-backup.txt"
    
    success "State backed up to $backup_file"
}

# Function to create a test deployment if none exists
create_test_deployment() {
    log "Creating test deployment for fault injection..."
    
    cat <<EOF | kubectl --kubeconfig="$KUBECONFIG" apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: $TARGET_NAMESPACE
  labels:
    app: test-app
    fault-injection: "true"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: $TARGET_NAMESPACE
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
EOF

    # Wait for deployment to be ready
    log "Waiting for test deployment to be ready..."
    kubectl --kubeconfig="$KUBECONFIG" wait --for=condition=available --timeout=60s deployment/test-app -n "$TARGET_NAMESPACE"
    
    success "Test deployment created and ready"
}

# Fault injection functions
inject_replica_fault() {
    log "Injecting replica fault (excessive replicas)..."
    
    # Scale to an unreasonably high number of replicas
    kubectl --kubeconfig="$KUBECONFIG" patch deployment test-app -n "$TARGET_NAMESPACE" -p '{"spec":{"replicas":50}}'
    
    success "Replica fault injected - scaled to 50 replicas"
    warning "This will likely cause resource exhaustion and failed pods"
}

inject_readiness_fault() {
    log "Injecting readiness probe fault..."
    
    # Modify readiness probe to point to non-existent path
    kubectl --kubeconfig="$KUBECONFIG" patch deployment test-app -n "$TARGET_NAMESPACE" -p '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "readinessProbe": {
                            "httpGet": {
                                "path": "/nonexistent-health-check",
                                "port": 80
                            },
                            "initialDelaySeconds": 5,
                            "periodSeconds": 10,
                            "failureThreshold": 3
                        }
                    }]
                }
            }
        }
    }'
    
    success "Readiness probe fault injected - probe will fail"
    warning "Pods will not be marked as ready"
}

inject_resource_fault() {
    log "Injecting resource constraint fault..."
    
    # Set impossible resource requests
    kubectl --kubeconfig="$KUBECONFIG" patch deployment test-app -n "$TARGET_NAMESPACE" -p '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "resources": {
                            "requests": {
                                "memory": "10Gi",
                                "cpu": "8"
                            },
                            "limits": {
                                "memory": "10Gi",
                                "cpu": "8"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    success "Resource fault injected - impossible resource requirements"
    warning "Pods will be in Pending state due to insufficient resources"
}

inject_image_fault() {
    log "Injecting image fault (non-existent image)..."
    
    kubectl --kubeconfig="$KUBECONFIG" patch deployment test-app -n "$TARGET_NAMESPACE" -p '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "image": "nonexistent/broken-image:latest"
                    }]
                }
            }
        }
    }'
    
    success "Image fault injected - using non-existent image"
    warning "Pods will fail with ImagePullBackOff"
}

inject_config_fault() {
    log "Injecting configuration fault..."
    
    # Create a configmap with wrong data and mount it
    kubectl --kubeconfig="$KUBECONFIG" create configmap broken-config -n "$TARGET_NAMESPACE" \
        --from-literal=config.json='{"broken": invalid-json}' --dry-run=client -o yaml | \
        kubectl --kubeconfig="$KUBECONFIG" apply -f -
    
    kubectl --kubeconfig="$KUBECONFIG" patch deployment test-app -n "$TARGET_NAMESPACE" -p '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "volumeMounts": [{
                            "name": "config-volume",
                            "mountPath": "/etc/config"
                        }],
                        "env": [{
                            "name": "CONFIG_FILE",
                            "value": "/etc/config/config.json"
                        }]
                    }],
                    "volumes": [{
                        "name": "config-volume",
                        "configMap": {
                            "name": "broken-config"
                        }
                    }]
                }
            }
        }
    }'
    
    success "Configuration fault injected - invalid config mounted"
    warning "Application may fail to parse configuration"
}

# Function to show current status
show_status() {
    log "Current cluster status after fault injection:"
    
    echo ""
    echo "=== Deployment Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get deployments -n "$TARGET_NAMESPACE" -o wide
    
    echo ""
    echo "=== Pod Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get pods -n "$TARGET_NAMESPACE" -o wide
    
    echo ""
    echo "=== Events (last 10) ==="
    kubectl --kubeconfig="$KUBECONFIG" get events -n "$TARGET_NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    
    echo ""
    echo "=== Health Check ==="
    if command -v /home/ubuntu/dev/edge_observe.sh &> /dev/null; then
        /home/ubuntu/dev/edge_observe.sh table
    else
        warning "edge_observe.sh not found - skipping health check"
    fi
}

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [NAMESPACE] [FAULT_TYPE]

Fault Types:
  replicas    - Scale deployment to excessive replicas (default)
  readiness   - Break readiness probe
  resources   - Set impossible resource requirements
  image       - Use non-existent container image
  config      - Inject broken configuration

Examples:
  $0                          # Default: inject replica fault in edge1 namespace
  $0 edge1 readiness          # Inject readiness probe fault
  $0 my-ns resources          # Inject resource constraint fault

The script will:
1. Backup current state to $BACKUP_DIR
2. Create a test deployment if none exists
3. Inject the specified fault
4. Show resulting status
5. Save recovery information

Use fault_recover.sh to restore the previous state.
EOF
}

# Main execution
main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi
    
    log "Starting fault injection process..."
    log "Target namespace: $TARGET_NAMESPACE"
    log "Fault type: $FAULT_TYPE"
    
    check_prerequisites
    backup_state
    
    # Check if test deployment exists, create if not
    if ! kubectl --kubeconfig="$KUBECONFIG" get deployment test-app -n "$TARGET_NAMESPACE" &>/dev/null; then
        create_test_deployment
    else
        log "Using existing test-app deployment"
    fi
    
    # Inject the specified fault
    case "$FAULT_TYPE" in
        "replicas")
            inject_replica_fault
            ;;
        "readiness")
            inject_readiness_fault
            ;;
        "resources")
            inject_resource_fault
            ;;
        "image")
            inject_image_fault
            ;;
        "config")
            inject_config_fault
            ;;
        *)
            error "Unknown fault type: $FAULT_TYPE"
            usage
            exit 1
            ;;
    esac
    
    log "Waiting 30 seconds for fault to manifest..."
    sleep 30
    
    show_status
    
    echo ""
    success "Fault injection completed!"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Monitor the cluster with: watch kubectl get pods -n $TARGET_NAMESPACE"
    echo "2. Check health status with: /home/ubuntu/dev/edge_observe.sh table"
    echo "3. Simulate postcheck failure (should detect degraded health)"
    echo "4. Run rollback with: /home/ubuntu/dev/fault_recover.sh"
    echo ""
    echo "Backup saved to: $(cat "$BACKUP_DIR/latest-backup.txt")"
}

# Run main function
main "$@"