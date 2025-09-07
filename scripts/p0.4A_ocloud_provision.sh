#!/bin/bash
# P0.4A O-Cloud Provisioning Script
# Part of the verifiable intent pipeline for Telco cloud & O-RAN
# Provisions O-Cloud using FoCoM operator with ProvisioningRequest CRs

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="1.0.0"
SCRIPT_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Configuration
SMO_CLUSTER_NAME="${SMO_CLUSTER_NAME:-focom-smo}"
SMO_KUBECONFIG="${SMO_KUBECONFIG:-/tmp/focom-kubeconfig}"
EDGE_KUBECONFIG="${EDGE_KUBECONFIG:-/tmp/kubeconfig-edge.yaml}"
O2IMS_NAMESPACE="${O2IMS_NAMESPACE:-o2ims}"
FOCOM_NAMESPACE="${FOCOM_NAMESPACE:-focom-system}"
VM2_IP="${VM2_IP:-172.16.4.45}"
TIMEOUT="${TIMEOUT:-600}"  # 10 minutes default timeout
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
CLEANUP_ON_FAILURE="${CLEANUP_ON_FAILURE:-true}"

# KPT catalog configuration
KPT_CATALOG_URL="${KPT_CATALOG_URL:-https://github.com/nephio-project/catalog.git}"
KPT_CATALOG_REF="${KPT_CATALOG_REF:-v2.0.0}"
FOCOM_PACKAGE_PATH="${FOCOM_PACKAGE_PATH:-workloads/focom/focom-operator}"

# Exit codes (following project deterministic CLI standards)
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=1
EXIT_KIND_CLUSTER_FAILED=2
EXIT_FOCOM_DEPLOY_FAILED=3
EXIT_SECRET_CREATION_FAILED=4
EXIT_CR_APPLY_FAILED=5
EXIT_PROVISIONING_FAILED=6
EXIT_TIMEOUT=7
EXIT_CLEANUP_FAILED=8

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Temporary files for cleanup
TEMP_FILES=()
trap cleanup EXIT

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
    printf "${BLUE}[INFO]${NC} %s\n" "$1" >&2
}

log_success() {
    log_json "SUCCESS" "$1"
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1" >&2
}

log_warning() {
    log_json "WARNING" "$1"
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1" >&2
}

log_error() {
    log_json "ERROR" "$1"
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_step() {
    local step_num="$1"
    local step_desc="$2"
    log_json "STEP" "Step $step_num: $step_desc"
    printf "\n${MAGENTA}═══ Step $step_num: $step_desc ═══${NC}\n" >&2
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code: $exit_code"
        
        if [[ "$CLEANUP_ON_FAILURE" == "true" ]]; then
            log_info "Performing cleanup due to failure..."
            
            # Clean up temporary files
            for temp_file in "${TEMP_FILES[@]}"; do
                if [[ -f "$temp_file" ]]; then
                    rm -f "$temp_file" || true
                fi
            done
            
            # Optionally delete the KinD cluster on failure
            if [[ "${DELETE_CLUSTER_ON_FAILURE:-false}" == "true" ]]; then
                log_info "Deleting KinD cluster ${SMO_CLUSTER_NAME}..."
                kind delete cluster --name "${SMO_CLUSTER_NAME}" 2>/dev/null || true
            fi
        fi
    else
        log_success "Script completed successfully"
    fi
    
    local end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    log_json "COMPLETE" "Script execution completed. Start: $SCRIPT_START_TIME, End: $end_time"
}

# Function to check prerequisites
check_prerequisites() {
    log_step 1 "Checking prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    for tool in kubectl kind kpt jq yq; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        exit $EXIT_INVALID_ARGS
    fi
    
    # Check if edge kubeconfig exists
    if [[ ! -f "$EDGE_KUBECONFIG" ]]; then
        log_error "Edge kubeconfig not found at: $EDGE_KUBECONFIG"
        log_info "Please ensure the edge cluster kubeconfig is available"
        exit $EXIT_INVALID_ARGS
    fi
    
    # Verify edge cluster connectivity
    if ! kubectl --kubeconfig="$EDGE_KUBECONFIG" cluster-info &>/dev/null; then
        log_error "Cannot connect to edge cluster using kubeconfig: $EDGE_KUBECONFIG"
        exit $EXIT_INVALID_ARGS
    fi
    
    log_success "All prerequisites satisfied"
}

# Function to create KinD cluster
create_kind_cluster() {
    log_step 2 "Creating KinD cluster: ${SMO_CLUSTER_NAME}"
    
    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${SMO_CLUSTER_NAME}$"; then
        log_info "KinD cluster ${SMO_CLUSTER_NAME} already exists"
        
        # Export kubeconfig
        kind export kubeconfig --name="${SMO_CLUSTER_NAME}" --kubeconfig="${SMO_KUBECONFIG}"
        
        # Verify cluster is healthy
        if kubectl --kubeconfig="${SMO_KUBECONFIG}" cluster-info &>/dev/null; then
            log_success "Using existing KinD cluster ${SMO_CLUSTER_NAME}"
            return 0
        else
            log_warning "Existing cluster is not healthy, recreating..."
            kind delete cluster --name="${SMO_CLUSTER_NAME}"
        fi
    fi
    
    # Create KinD cluster configuration
    local kind_config="/tmp/kind-config-${SMO_CLUSTER_NAME}.yaml"
    TEMP_FILES+=("$kind_config")
    
    cat > "$kind_config" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${SMO_CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "nephio.org/cluster-name=${SMO_CLUSTER_NAME}"
  extraPortMappings:
  - containerPort: 30080
    hostPort: 31080
    protocol: TCP
  - containerPort: 30443
    hostPort: 31443
    protocol: TCP
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
EOF
    
    log_info "Creating KinD cluster with configuration..."
    if ! kind create cluster --config="$kind_config" --kubeconfig="${SMO_KUBECONFIG}" --wait=60s; then
        log_error "Failed to create KinD cluster"
        exit $EXIT_KIND_CLUSTER_FAILED
    fi
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if kubectl --kubeconfig="${SMO_KUBECONFIG}" get nodes &>/dev/null; then
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    if [[ $retries -eq 0 ]]; then
        log_error "Cluster did not become ready in time"
        exit $EXIT_KIND_CLUSTER_FAILED
    fi
    
    # Install required CRDs for the cluster
    log_info "Installing base CRDs..."
    kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f https://github.com/nephio-project/nephio/raw/main/config/crd/bases/config.nephio.org_networks.yaml || true
    kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f https://github.com/nephio-project/nephio/raw/main/config/crd/bases/workload.nephio.org_clusters.yaml || true
    
    log_success "KinD cluster ${SMO_CLUSTER_NAME} created successfully"
}

# Function to deploy FoCoM operator
deploy_focom_operator() {
    log_step 3 "Deploying FoCoM operator via kpt"
    
    # Create namespace
    log_info "Creating namespace ${FOCOM_NAMESPACE}..."
    kubectl --kubeconfig="${SMO_KUBECONFIG}" create namespace "${FOCOM_NAMESPACE}" --dry-run=client -o yaml | \
        kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f -
    
    # Apply the FoCoM operator manifests
    log_info "Applying FoCoM operator manifests..."
    local focom_manifest="${SCRIPT_DIR}/../manifests/focom-operator.yaml"
    
    if [[ ! -f "$focom_manifest" ]]; then
        log_error "FoCoM operator manifest not found at: $focom_manifest"
        exit $EXIT_FOCOM_DEPLOY_FAILED
    fi
    
    if ! kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f "$focom_manifest"; then
        log_error "Failed to apply FoCoM operator manifests"
        exit $EXIT_FOCOM_DEPLOY_FAILED
    fi
    
    # Wait for operator to be ready
    log_info "Waiting for FoCoM operator to be ready..."
    local retries=60
    while [[ $retries -gt 0 ]]; do
        local ready_pods=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get pods -n "${FOCOM_NAMESPACE}" \
            -l app=focom-controller \
            -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null | wc -w)
        
        if [[ $ready_pods -gt 0 ]]; then
            log_success "FoCoM operator is running"
            break
        fi
        
        sleep 5
        retries=$((retries - 1))
        
        if [[ $((retries % 10)) -eq 0 ]]; then
            log_info "Still waiting for FoCoM operator... ($retries retries left)"
        fi
    done
    
    if [[ $retries -eq 0 ]]; then
        log_error "FoCoM operator did not become ready in time"
        kubectl --kubeconfig="${SMO_KUBECONFIG}" get pods -n "${FOCOM_NAMESPACE}" -o wide
        exit $EXIT_FOCOM_DEPLOY_FAILED
    fi
    
    # Clean up temporary package directory
    rm -rf "$temp_pkg_dir"
    
    log_success "FoCoM operator deployed successfully"
}

# Function to create edge cluster secret
create_edge_cluster_secret() {
    log_step 4 "Creating edge cluster kubeconfig secret"
    
    log_info "Creating secret with edge cluster kubeconfig..."
    
    # Create the secret
    if ! kubectl --kubeconfig="${SMO_KUBECONFIG}" create secret generic edge-cluster-kubeconfig \
        --from-file=kubeconfig="${EDGE_KUBECONFIG}" \
        --namespace="${O2IMS_NAMESPACE}" \
        --dry-run=client -o yaml | \
        kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f -; then
        log_error "Failed to create edge cluster kubeconfig secret"
        exit $EXIT_SECRET_CREATION_FAILED
    fi
    
    log_success "Edge cluster kubeconfig secret created"
}

# Function to apply O-Cloud CRs
apply_ocloud_crs() {
    log_step 5 "Applying O-Cloud Custom Resources"
    
    # Create namespace for O2IMS resources
    log_info "Creating namespace ${O2IMS_NAMESPACE}..."
    kubectl --kubeconfig="${SMO_KUBECONFIG}" create namespace "${O2IMS_NAMESPACE}" --dry-run=client -o yaml | \
        kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f -
    
    # Create OCloud CR
    local ocloud_manifest="/tmp/ocloud-cr.yaml"
    TEMP_FILES+=("$ocloud_manifest")
    
    cat > "$ocloud_manifest" <<EOF
apiVersion: focom.nephio.org/v1alpha1
kind: OCloud
metadata:
  name: edge-ocloud
  namespace: ${O2IMS_NAMESPACE}
spec:
  endpoint: "https://${VM2_IP}:6443"
  secretRef:
    name: edge-cluster-kubeconfig
    namespace: ${O2IMS_NAMESPACE}
EOF
    
    log_info "Applying OCloud CR..."
    if ! kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f "$ocloud_manifest"; then
        log_error "Failed to apply OCloud CR"
        exit $EXIT_CR_APPLY_FAILED
    fi
    
    # Create TemplateInfo CR
    local template_manifest="/tmp/template-info-cr.yaml"
    TEMP_FILES+=("$template_manifest")
    
    cat > "$template_manifest" <<EOF
apiVersion: focom.nephio.org/v1alpha1
kind: TemplateInfo
metadata:
  name: edge-5g-template
  namespace: ${O2IMS_NAMESPACE}
spec:
  template: "5g-ran-du"
  parameters:
    namespace: "ran-workloads"
    replicas: 3
    cpu_request: "500m"
    memory_request: "1Gi"
    environment: "edge"
EOF
    
    log_info "Applying TemplateInfo CR..."
    if ! kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f "$template_manifest"; then
        log_error "Failed to apply TemplateInfo CR"
        exit $EXIT_CR_APPLY_FAILED
    fi
    
    # Create FocomProvisioningRequest CR
    local pr_manifest="/tmp/focom-pr-cr.yaml"
    TEMP_FILES+=("$pr_manifest")
    
    cat > "$pr_manifest" <<EOF
apiVersion: focom.nephio.org/v1alpha1
kind: FocomProvisioningRequest
metadata:
  name: edge-5g-deployment
  namespace: ${O2IMS_NAMESPACE}
spec:
  ocloudRef:
    name: edge-ocloud
  templateRef:
    name: edge-5g-template
  parameters:
    namespace: "ran-workloads"
    replicas: 3
    cpu_request: "1"
    memory_request: "2Gi"
EOF
    
    log_info "Applying FocomProvisioningRequest CR..."
    if ! kubectl --kubeconfig="${SMO_KUBECONFIG}" apply -f "$pr_manifest"; then
        log_error "Failed to apply FocomProvisioningRequest CR"
        exit $EXIT_CR_APPLY_FAILED
    fi
    
    log_success "All O-Cloud CRs applied successfully"
}

# Function to display status table
display_status_table() {
    local show_header="$1"
    
    if [[ "$show_header" == "true" ]]; then
        printf "\n${CYAN}═══ Resource Status ═══${NC}\n"
        printf "%-30s %-15s %-20s %-40s\n" "RESOURCE" "TYPE" "STATUS" "MESSAGE"
        printf "%-30s %-15s %-20s %-40s\n" "────────" "────" "──────" "───────"
    fi
    
    # Get ProvisioningRequest status
    local pr_status=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get provisioningrequest edge-5g-deployment \
        -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null | \
        jq -r '.status.state // "Unknown"')
    local pr_message=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get provisioningrequest edge-5g-deployment \
        -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null | \
        jq -r '.status.message // "-"' | cut -c1-40)
    
    printf "%-30s %-15s %-20s %-40s\n" \
        "edge-5g-deployment" \
        "ProvisioningReq" \
        "$pr_status" \
        "$pr_message"
    
    # Get PackageVariant status (if exists)
    local pv_count=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get packagevariants \
        -n "${O2IMS_NAMESPACE}" 2>/dev/null | grep -c edge || echo "0")
    
    if [[ "$pv_count" -gt "0" ]]; then
        kubectl --kubeconfig="${SMO_KUBECONFIG}" get packagevariants \
            -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null | \
            jq -r '.items[] | select(.metadata.name | contains("edge")) | 
                "\(.metadata.name | .[0:30]) PackageVariant \(.status.phase // "Unknown") \(.status.message // "-" | .[0:40])"' | \
            while read -r line; do
                printf "%-30s %-15s %-20s %-40s\n" $line
            done
    fi
    
    # Get Cluster status
    local cluster_status=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get cluster edge-ocloud \
        -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null | \
        jq -r '.status.phase // "Unknown"')
    local cluster_ready=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get cluster edge-ocloud \
        -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null | \
        jq -r '.status.conditions[]? | select(.type=="Ready") | .status // "Unknown"')
    
    printf "%-30s %-15s %-20s %-40s\n" \
        "edge-ocloud" \
        "Cluster" \
        "$cluster_status" \
        "Ready=$cluster_ready"
    
    printf "\n"
}

# Function to wait for provisioning
wait_for_provisioning() {
    log_step 6 "Waiting for O-Cloud provisioning to complete"
    
    local start_time=$(date +%s)
    local timeout_time=$((start_time + TIMEOUT))
    local last_status=""
    local check_interval=5
    local display_counter=0
    
    log_info "Monitoring provisioning status (timeout: ${TIMEOUT}s)..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # Check if timeout exceeded
        if [[ $current_time -gt $timeout_time ]]; then
            log_error "Provisioning timeout exceeded (${TIMEOUT}s)"
            display_status_table true
            exit $EXIT_TIMEOUT
        fi
        
        # Get current cluster status
        local cluster_status=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get cluster edge-ocloud \
            -n "${O2IMS_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        
        # Check if status changed
        if [[ "$cluster_status" != "$last_status" ]]; then
            log_info "Cluster status changed: $last_status -> $cluster_status"
            last_status="$cluster_status"
        fi
        
        # Display status table every 15 seconds
        if [[ $((display_counter % 3)) -eq 0 ]]; then
            display_status_table true
        fi
        display_counter=$((display_counter + 1))
        
        # Check if provisioning is complete
        if [[ "$cluster_status" == "Provisioned" ]] || [[ "$cluster_status" == "Ready" ]]; then
            log_success "O-Cloud provisioning completed successfully!"
            display_status_table true
            break
        fi
        
        # Check for failure states
        if [[ "$cluster_status" == "Failed" ]] || [[ "$cluster_status" == "Error" ]]; then
            log_error "O-Cloud provisioning failed with status: $cluster_status"
            display_status_table true
            
            # Get error details
            kubectl --kubeconfig="${SMO_KUBECONFIG}" describe cluster edge-ocloud \
                -n "${O2IMS_NAMESPACE}" | tail -20
            
            exit $EXIT_PROVISIONING_FAILED
        fi
        
        # Progress indicator
        printf "."
        
        sleep $check_interval
    done
    
    local total_time=$((current_time - start_time))
    log_success "Provisioning completed in ${total_time} seconds"
}

# Function to generate documentation
generate_documentation() {
    log_step 7 "Generating O-Cloud documentation"
    
    local doc_file="docs/OCloud.md"
    local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Create docs directory if it doesn't exist
    mkdir -p "$(dirname "$doc_file")"
    
    # Get cluster details
    local cluster_info=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get cluster edge-ocloud \
        -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null)
    
    local pr_info=$(kubectl --kubeconfig="${SMO_KUBECONFIG}" get provisioningrequest edge-5g-deployment \
        -n "${O2IMS_NAMESPACE}" -o json 2>/dev/null)
    
    cat > "$doc_file" <<EOF
# O-Cloud Provisioning Summary

## Deployment Information
- **Date**: ${timestamp}
- **Script Version**: ${SCRIPT_VERSION}
- **SMO Cluster**: ${SMO_CLUSTER_NAME}
- **Edge IP**: ${VM2_IP}

## O-Cloud Details

### Cluster Information
- **Name**: edge-ocloud
- **Namespace**: ${O2IMS_NAMESPACE}
- **Status**: $(echo "$cluster_info" | jq -r '.status.phase // "Unknown"')
- **Location**: Edge Site 1

### Provisioning Request
- **Name**: edge-5g-deployment
- **Template**: edge-5g-template
- **Workload Type**: 5G RAN DU
- **Status**: $(echo "$pr_info" | jq -r '.status.state // "Unknown"')

## Access Information

### SMO Cluster Access
\`\`\`bash
export KUBECONFIG=${SMO_KUBECONFIG}
kubectl get clusters -n ${O2IMS_NAMESPACE}
\`\`\`

### Edge Cluster Access
\`\`\`bash
export KUBECONFIG=${EDGE_KUBECONFIG}
kubectl get nodes
\`\`\`

## Verification Commands

### Check O-Cloud Status
\`\`\`bash
kubectl --kubeconfig=${SMO_KUBECONFIG} get ocloud,cluster,provisioningrequest -n ${O2IMS_NAMESPACE}
\`\`\`

### View FoCoM Operator Logs
\`\`\`bash
kubectl --kubeconfig=${SMO_KUBECONFIG} logs -n ${FOCOM_NAMESPACE} -l app.kubernetes.io/name=focom-operator --tail=50
\`\`\`

### Check Workload Deployment
\`\`\`bash
kubectl --kubeconfig=${EDGE_KUBECONFIG} get pods -n ran-workloads
\`\`\`

## Resource Details

### Applied Resources
1. **OCloud CR**: Defines the edge O-Cloud with kubeconfig reference
2. **TemplateInfo CR**: Specifies the 5G RAN deployment template
3. **ProvisioningRequest CR**: Triggers the actual workload deployment

### Key Components
- **FoCoM Operator**: Manages the provisioning lifecycle
- **Edge Cluster Secret**: Contains kubeconfig for edge cluster access
- **PackageVariants**: Generated during provisioning process

## Troubleshooting

### Common Issues
1. **Provisioning Stuck**: Check FoCoM operator logs for errors
2. **Authentication Failed**: Verify edge cluster kubeconfig is valid
3. **Resource Not Found**: Ensure all CRDs are properly installed

### Debug Commands
\`\`\`bash
# Check FoCoM operator status
kubectl --kubeconfig=${SMO_KUBECONFIG} get pods -n ${FOCOM_NAMESPACE}

# View provisioning events
kubectl --kubeconfig=${SMO_KUBECONFIG} get events -n ${O2IMS_NAMESPACE} --sort-by='.lastTimestamp'

# Describe provisioning request
kubectl --kubeconfig=${SMO_KUBECONFIG} describe provisioningrequest edge-5g-deployment -n ${O2IMS_NAMESPACE}
\`\`\`

## Next Steps
1. Monitor workload deployment on edge cluster
2. Configure service mesh for inter-service communication
3. Set up observability stack for monitoring
4. Implement SLO-based GitOps workflows

---
*Generated by ${SCRIPT_NAME} v${SCRIPT_VERSION} on ${timestamp}*
EOF
    
    log_success "Documentation generated at: $doc_file"
}

# Function to display usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Provisions O-Cloud using FoCoM operator with ProvisioningRequest CRs.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Perform dry run (don't apply changes)
    -t, --timeout SECONDS   Set provisioning timeout (default: 600)
    -c, --cleanup           Clean up on failure (default: true)
    --smo-cluster NAME      SMO cluster name (default: focom-smo)
    --edge-ip IP            Edge cluster IP (default: 172.16.4.45)
    --skip-kind             Skip KinD cluster creation
    --skip-focom            Skip FoCoM operator deployment

ENVIRONMENT VARIABLES:
    SMO_CLUSTER_NAME        SMO cluster name
    SMO_KUBECONFIG         Path to SMO kubeconfig
    EDGE_KUBECONFIG        Path to edge kubeconfig
    O2IMS_NAMESPACE        O2IMS namespace
    FOCOM_NAMESPACE        FoCoM operator namespace
    VM2_IP                 Edge cluster IP address
    TIMEOUT                Provisioning timeout in seconds
    CLEANUP_ON_FAILURE     Clean up resources on failure

EXAMPLES:
    # Basic provisioning
    $SCRIPT_NAME

    # Verbose mode with custom timeout
    $SCRIPT_NAME --verbose --timeout 900

    # Dry run to validate setup
    $SCRIPT_NAME --dry-run

    # Skip KinD cluster creation (use existing)
    $SCRIPT_NAME --skip-kind

EXIT CODES:
    0  - Success
    1  - Invalid arguments
    2  - KinD cluster creation failed
    3  - FoCoM deployment failed
    4  - Secret creation failed
    5  - CR application failed
    6  - Provisioning failed
    7  - Timeout exceeded
    8  - Cleanup failed

EOF
}

# Parse command line arguments
SKIP_KIND=false
SKIP_FOCOM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -c|--cleanup)
            CLEANUP_ON_FAILURE=true
            shift
            ;;
        --smo-cluster)
            SMO_CLUSTER_NAME="$2"
            shift 2
            ;;
        --edge-ip)
            VM2_IP="$2"
            shift 2
            ;;
        --skip-kind)
            SKIP_KIND=true
            shift
            ;;
        --skip-focom)
            SKIP_FOCOM=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit $EXIT_INVALID_ARGS
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting P0.4A O-Cloud Provisioning"
    log_info "Configuration:"
    log_info "  SMO Cluster: ${SMO_CLUSTER_NAME}"
    log_info "  Edge IP: ${VM2_IP}"
    log_info "  Timeout: ${TIMEOUT}s"
    log_info "  Dry Run: ${DRY_RUN}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN MODE - No changes will be applied"
    fi
    
    # Execute steps
    check_prerequisites
    
    if [[ "$SKIP_KIND" != "true" ]]; then
        create_kind_cluster
    else
        log_info "Skipping KinD cluster creation (--skip-kind flag)"
    fi
    
    if [[ "$SKIP_FOCOM" != "true" ]]; then
        deploy_focom_operator
    else
        log_info "Skipping FoCoM operator deployment (--skip-focom flag)"
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        create_edge_cluster_secret
        apply_ocloud_crs
        wait_for_provisioning
        generate_documentation
    else
        log_info "Skipping actual deployment due to dry-run mode"
    fi
    
    log_success "P0.4A O-Cloud provisioning completed successfully!"
    
    # Display final status
    display_status_table true
    
    # Print access instructions
    printf "\n${GREEN}═══ Access Instructions ═══${NC}\n"
    printf "SMO Cluster: export KUBECONFIG=${SMO_KUBECONFIG}\n"
    printf "Edge Cluster: export KUBECONFIG=${EDGE_KUBECONFIG}\n"
    printf "Documentation: cat docs/OCloud.md\n\n"
    
    exit $EXIT_SUCCESS
}

# Run main function
main