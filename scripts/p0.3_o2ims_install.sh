#!/bin/bash
# O-RAN O2 IMS Operator Installation Script
# Part of the verifiable intent pipeline for Telco cloud & O-RAN
# Installs ProvisioningRequest CRD and O2 IMS operator components

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Configuration
O2IMS_NAMESPACE="${O2IMS_NAMESPACE:-o2ims}"
CRD_URL="${CRD_URL:-https://raw.githubusercontent.com/nephio-project/api/refs/heads/main/config/crd/bases/o2ims.provisioning.oran.org_provisioningrequests.yaml}"
LOCAL_CRD_PATH="./o2ims-sdk/config/crd/bases/o2ims.provisioning.oran.org_provisioningrequests.yaml"
TIMEOUT="${TIMEOUT:-300}"  # 5 minutes default timeout
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Exit codes (following project deterministic CLI standards)
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_CRD_INSTALL_FAILED=2
EXIT_NAMESPACE_CREATION_FAILED=3
EXIT_OPERATOR_INSTALL_FAILED=4
EXIT_VERIFICATION_FAILED=5
EXIT_TIMEOUT=6

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions (JSON format for machine parsing)
log_json() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"timestamp":"%s","level":"%s","script":"%s","version":"%s","message":"%s"}\n' \
        "$timestamp" "$level" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$message" >&2
}

log_info() {
    log_json "INFO" "$1"
    if [[ "$VERBOSE" == "true" ]]; then
        printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2
    fi
}

log_warn() {
    log_json "WARN" "$1"
    printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2
}

log_error() {
    log_json "ERROR" "$1"
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_success() {
    log_json "SUCCESS" "$1"
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >&2
}

# Usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Install O-RAN O2 IMS operator on the management cluster and verify CRDs/pods.

OPTIONS:
    -n, --namespace NAMESPACE   O2 IMS namespace (default: o2ims)
    -t, --timeout SECONDS       Timeout for operations (default: 300)
    -d, --dry-run               Show what would be done without executing
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

ENVIRONMENT VARIABLES:
    O2IMS_NAMESPACE    Override default namespace
    CRD_URL            Custom CRD URL (default: official Nephio API)
    TIMEOUT            Operation timeout in seconds
    DRY_RUN            Set to 'true' for dry-run mode
    VERBOSE            Set to 'true' for verbose logging

EXIT CODES:
    0    Success
    1    Invalid arguments
    2    CRD installation failed
    3    Namespace creation failed
    4    Operator installation failed
    5    Verification failed
    6    Timeout exceeded

EXAMPLES:
    # Basic installation
    $SCRIPT_NAME

    # Custom namespace with verbose output
    $SCRIPT_NAME --namespace oran-o2ims --verbose

    # Dry run to preview changes
    $SCRIPT_NAME --dry-run

    # With custom timeout
    $SCRIPT_NAME --timeout 600

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                O2IMS_NAMESPACE="$2"
                shift 2
                ;;
            -t|--timeout)
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    log_error "Timeout must be a positive integer"
                    exit $EXIT_INVALID_ARGS
                fi
                TIMEOUT="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                usage
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit $EXIT_INVALID_ARGS
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites"
    
    # Check kubectl availability
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl is required but not installed"
        exit $EXIT_INVALID_ARGS
    fi
    
    # Check kubectl cluster connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Unable to connect to Kubernetes cluster"
        exit $EXIT_INVALID_ARGS
    fi
    
    # Check cluster-admin permissions for CRD installation
    if ! kubectl auth can-i create customresourcedefinitions --quiet; then
        log_error "Insufficient permissions to create CRDs (cluster-admin required)"
        exit $EXIT_INVALID_ARGS
    fi
    
    log_success "Prerequisites validation completed"
}

# Create namespace if it doesn't exist
create_namespace() {
    log_info "Creating namespace: $O2IMS_NAMESPACE"
    
    if kubectl get namespace "$O2IMS_NAMESPACE" >/dev/null 2>&1; then
        log_info "Namespace $O2IMS_NAMESPACE already exists"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create namespace: $O2IMS_NAMESPACE"
        return 0
    fi
    
    if ! kubectl create namespace "$O2IMS_NAMESPACE"; then
        log_error "Failed to create namespace: $O2IMS_NAMESPACE"
        exit $EXIT_NAMESPACE_CREATION_FAILED
    fi
    
    log_success "Namespace $O2IMS_NAMESPACE created successfully"
}

# Install ProvisioningRequest CRD
install_crd() {
    log_info "Installing ProvisioningRequest CRD"
    
    # Check if CRD already exists
    if kubectl get crd provisioningrequests.o2ims.provisioning.oran.org >/dev/null 2>&1; then
        log_info "ProvisioningRequest CRD already exists, checking version"
        
        # Get current CRD version
        local current_version
        current_version=$(kubectl get crd provisioningrequests.o2ims.provisioning.oran.org -o jsonpath='{.metadata.annotations.controller-gen\.kubebuilder\.io/version}' || echo "unknown")
        log_info "Current CRD version: $current_version"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would install CRD from: $CRD_URL"
        return 0
    fi
    
    # Try local CRD first, then fallback to remote URL
    if [[ -f "$LOCAL_CRD_PATH" ]]; then
        log_info "Using local CRD file: $LOCAL_CRD_PATH"
        if ! kubectl apply -f "$LOCAL_CRD_PATH"; then
            log_error "Failed to apply local CRD"
            exit $EXIT_CRD_INSTALL_FAILED
        fi
    else
        log_info "Using remote CRD from: $CRD_URL"
        if ! kubectl apply -f "$CRD_URL"; then
            log_error "Failed to apply remote CRD"
            exit $EXIT_CRD_INSTALL_FAILED
        fi
    fi
    
    # Wait for CRD to be established
    log_info "Waiting for CRD to be established"
    if ! kubectl wait --for=condition=Established crd/provisioningrequests.o2ims.provisioning.oran.org --timeout="${TIMEOUT}s"; then
        log_error "Timeout waiting for CRD to be established"
        exit $EXIT_TIMEOUT
    fi
    
    log_success "ProvisioningRequest CRD installed and established"
}

# Deploy O2IMS operator components
deploy_operator() {
    log_info "Deploying O2IMS operator components"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would deploy O2IMS operator in namespace: $O2IMS_NAMESPACE"
        return 0
    fi
    
    # Create a minimal operator deployment for demonstration
    # In a real environment, this would deploy the actual Nephio O2IMS operator
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: o2ims-controller
  namespace: $O2IMS_NAMESPACE
  labels:
    app: o2ims-controller
    component: operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: o2ims-controller
  template:
    metadata:
      labels:
        app: o2ims-controller
    spec:
      serviceAccountName: o2ims-controller
      containers:
      - name: controller
        image: nephio/o2ims-controller:latest
        imagePullPolicy: IfNotPresent
        command:
        - /manager
        args:
        - --leader-elect=true
        - --metrics-bind-address=:8080
        - --health-probe-bind-address=:8081
        env:
        - name: WATCH_NAMESPACE
          value: ""
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: OPERATOR_NAME
          value: "o2ims-controller"
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 8081
          name: health
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: o2ims-controller
  namespace: $O2IMS_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: o2ims-controller
rules:
- apiGroups: ["o2ims.provisioning.oran.org"]
  resources: ["provisioningrequests"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: ["o2ims.provisioning.oran.org"]
  resources: ["provisioningrequests/status"]
  verbs: ["get", "patch", "update"]
- apiGroups: [""]
  resources: ["configmaps", "services", "pods"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: o2ims-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: o2ims-controller
subjects:
- kind: ServiceAccount
  name: o2ims-controller
  namespace: $O2IMS_NAMESPACE
---
apiVersion: v1
kind: Service
metadata:
  name: o2ims-controller-metrics
  namespace: $O2IMS_NAMESPACE
  labels:
    app: o2ims-controller
spec:
  selector:
    app: o2ims-controller
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
EOF
    
    log_success "O2IMS operator components deployed"
}

# Wait for operator pods to be ready
wait_for_pods() {
    log_info "Waiting for O2IMS operator pods to be ready"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would wait for pods in namespace: $O2IMS_NAMESPACE"
        return 0
    fi
    
    # Wait for deployment to be ready
    if ! kubectl rollout status deployment/o2ims-controller -n "$O2IMS_NAMESPACE" --timeout="${TIMEOUT}s"; then
        log_error "Timeout waiting for O2IMS operator deployment"
        exit $EXIT_TIMEOUT
    fi
    
    # Wait for pods to be running
    if ! kubectl wait --for=condition=Ready pod -l app=o2ims-controller -n "$O2IMS_NAMESPACE" --timeout="${TIMEOUT}s"; then
        log_error "Timeout waiting for O2IMS operator pods to be ready"
        exit $EXIT_TIMEOUT
    fi
    
    log_success "O2IMS operator pods are ready"
}

# Verify installation
verify_installation() {
    log_info "Verifying O2IMS installation"
    
    local verification_failed=false
    
    # Check CRD existence
    log_info "Checking ProvisioningRequest CRD"
    if ! kubectl get crd provisioningrequests.o2ims.provisioning.oran.org >/dev/null 2>&1; then
        log_error "ProvisioningRequest CRD not found"
        verification_failed=true
    else
        log_success "✓ ProvisioningRequest CRD exists"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would verify pods in namespace: $O2IMS_NAMESPACE"
        log_success "Dry-run verification completed"
        return 0
    fi
    
    # Check pods in o2ims namespace
    log_info "Checking pods in namespace: $O2IMS_NAMESPACE"
    local pod_count
    pod_count=$(kubectl get pods -n "$O2IMS_NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [[ "$pod_count" -eq 0 ]]; then
        log_error "No pods found in namespace: $O2IMS_NAMESPACE"
        verification_failed=true
    else
        log_success "✓ Found $pod_count pod(s) in namespace: $O2IMS_NAMESPACE"
        
        # Check if pods are running
        local running_pods
        running_pods=$(kubectl get pods -n "$O2IMS_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
        
        if [[ "$running_pods" -gt 0 ]]; then
            log_success "✓ $running_pods pod(s) are running"
        else
            log_error "No pods are in Running state"
            verification_failed=true
        fi
    fi
    
    # Display pod details if verbose
    if [[ "$VERBOSE" == "true" ]] && [[ "$pod_count" -gt 0 ]]; then
        log_info "Pod details:"
        kubectl get pods -n "$O2IMS_NAMESPACE" -o wide
    fi
    
    if [[ "$verification_failed" == "true" ]]; then
        log_error "Installation verification failed"
        exit $EXIT_VERIFICATION_FAILED
    fi
    
    log_success "Installation verification completed successfully"
}

# Print next steps and hints
print_next_steps() {
    log_success "O-RAN O2 IMS installation completed successfully!"
    
    cat << EOF

${GREEN}Next Steps:${NC}

1. Verify ProvisioningRequest CRD:
   kubectl get crd | grep provisioningrequests

2. Check O2IMS operator pods:
   kubectl get pods -n $O2IMS_NAMESPACE

3. Create a test ProvisioningRequest:
   kubectl apply -f o2ims-sdk/examples/pr-minimal.yaml

4. Monitor ProvisioningRequest status:
   kubectl get provisioningrequests -A -w

5. View operator logs:
   kubectl logs -n $O2IMS_NAMESPACE deployment/o2ims-controller -f

${BLUE}Useful Commands:${NC}
   # List all ProvisioningRequests
   kubectl get pr -A

   # Describe a specific ProvisioningRequest
   kubectl describe pr <name> -n <namespace>

   # Check O2IMS operator metrics
   kubectl port-forward -n $O2IMS_NAMESPACE service/o2ims-controller-metrics 8080:8080

${YELLOW}Documentation:${NC}
   - Local: ./docs/O2IMS.md
   - O2IMS SDK: ./o2ims-sdk/README.md
   - Examples: ./o2ims-sdk/examples/

${YELLOW}Integration:${NC}
   This O2IMS installation integrates with:
   - TMF921 Intent Gateway (WF-D workflow)
   - 3GPP TS 28.312 Intent transformations
   - kpt/Porch package orchestration
   - Nephio R5 cluster management

EOF
}

# Cleanup function for graceful exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code: $exit_code"
    fi
    
    local script_end_time
    script_end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local duration
    duration=$(($(date -d "$script_end_time" +%s) - $(date -d "$SCRIPT_START_TIME" +%s)))
    
    log_json "SCRIPT_END" "Duration: ${duration}s, Exit Code: $exit_code"
    
    exit $exit_code
}

# Main execution function
main() {
    # Set up signal handlers
    trap cleanup EXIT INT TERM
    
    log_info "Starting O-RAN O2 IMS installation"
    log_json "SCRIPT_START" "Version: $SCRIPT_VERSION, Args: $*"
    
    # Parse arguments and validate
    parse_args "$@"
    validate_prerequisites
    
    # Installation steps
    create_namespace
    install_crd
    deploy_operator
    wait_for_pods
    
    # Verification and completion
    verify_installation
    print_next_steps
    
    log_success "O-RAN O2 IMS installation completed successfully"
    exit $EXIT_SUCCESS
}

# Execute main function with all arguments
main "$@"