#!/bin/bash
# KRM Rendering Pipeline with Multi-Site Support

set -euo pipefail

# Default values
TARGET_SITE="${TARGET_SITE:-edge1}"
INTENT_FILE="${1:-}"
OUTPUT_BASE="${OUTPUT_BASE:-./gitops}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[RENDER]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $0 [INTENT_FILE] [OPTIONS]

Render KRM manifests from intent JSON file.

OPTIONS:
    -t, --target SITE   Target site: edge1|edge2|both (default: edge1)
    -o, --output DIR    Output base directory (default: ./gitops)
    -d, --dry-run       Show what would be rendered without creating files
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

ENVIRONMENT:
    TARGET_SITE    Target site (overrides --target)
    DRY_RUN        Set to 'true' for dry run
    VERBOSE        Set to 'true' for verbose output

EXAMPLES:
    $0 intent.json --target edge1
    $0 intent.json --target both --dry-run
    TARGET_SITE=edge2 $0 intent.json
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            TARGET_SITE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_BASE="$2"
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
            ;;
        *)
            if [[ -z "$INTENT_FILE" ]]; then
                INTENT_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Validate intent file
if [[ -z "$INTENT_FILE" ]]; then
    error "Intent file is required"
    usage
fi

if [[ ! -f "$INTENT_FILE" ]]; then
    error "Intent file not found: $INTENT_FILE"
    exit 1
fi

# Validate target site
case "$TARGET_SITE" in
    edge1|edge2|both)
        ;;
    *)
        error "Invalid target site: $TARGET_SITE (must be edge1|edge2|both)"
        exit 1
        ;;
esac

# Extract targetSite from intent if present
extract_target_site() {
    local intent_file="$1"
    if command -v jq &>/dev/null; then
        jq -r '.targetSite // "edge1"' "$intent_file" 2>/dev/null || echo "edge1"
    else
        grep -o '"targetSite"[[:space:]]*:[[:space:]]*"[^"]*"' "$intent_file" | \
            sed 's/.*"targetSite"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "edge1"
    fi
}

# Render KRM for a specific site
render_for_site() {
    local site="$1"
    local intent_file="$2"
    local output_dir="${OUTPUT_BASE}/${site}-config"

    log "Rendering KRM for site: $site"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would render to: $output_dir"
        log "[DRY-RUN] Intent file: $intent_file"
        return 0
    fi

    # Clean previous renders for idempotency
    if [[ -d "$output_dir" ]]; then
        [[ "$VERBOSE" == "true" ]] && log "Cleaning previous render: $output_dir"
        rm -rf "$output_dir"
    fi

    # Create output directory
    mkdir -p "$output_dir"

    # Extract intent details (check both top-level and nested under 'intent')
    local service_type resource_profile
    if command -v jq &>/dev/null; then
        service_type=$(jq -r '.serviceType // .intent.serviceType // "enhanced-mobile-broadband"' "$intent_file")
        resource_profile=$(jq -r '.resourceProfile // .intent.resourceProfile // "standard"' "$intent_file")
    else
        service_type="enhanced-mobile-broadband"
        resource_profile="standard"
    fi

    [[ "$VERBOSE" == "true" ]] && log "Service type: $service_type, Profile: $resource_profile"

    # Generate base namespace
    cat > "$output_dir/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: oran-services
  labels:
    site: $site
    managed-by: nephio
EOF

    # Generate service-specific resources
    case "$service_type" in
        "enhanced-mobile-broadband"|"eMBB")
            render_embb_service "$site" "$output_dir" "$resource_profile"
            ;;
        "ultra-reliable-low-latency"|"URLLC")
            render_urllc_service "$site" "$output_dir" "$resource_profile"
            ;;
        "massive-machine-type"|"mMTC")
            render_mmtc_service "$site" "$output_dir" "$resource_profile"
            ;;
        *)
            warn "Unknown service type: $service_type, using default"
            render_default_service "$site" "$output_dir" "$resource_profile"
            ;;
    esac

    # Generate kustomization.yaml with sorted resources for determinism
    cat > "$output_dir/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: oran-services
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
commonLabels:
  site: $site
  service-type: $service_type
  managed-by: nephio
EOF

    # Ensure all files are created with consistent permissions
    chmod 644 "$output_dir"/*.yaml 2>/dev/null || true

    log "✓ Rendered KRM to $output_dir"
}

# Service rendering functions
render_embb_service() {
    local site="$1"
    local output_dir="$2"
    local profile="$3"

    # Service definition
    cat > "$output_dir/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: embb-service
  namespace: oran-services
spec:
  selector:
    app: embb
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  type: LoadBalancer
EOF

    # Deployment
    local replicas=2
    [[ "$profile" == "high-performance" ]] && replicas=3

    cat > "$output_dir/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: embb-deployment
  namespace: oran-services
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: embb
  template:
    metadata:
      labels:
        app: embb
        site: $site
    spec:
      containers:
      - name: embb
        image: oran/embb:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
EOF
}

render_urllc_service() {
    local site="$1"
    local output_dir="$2"
    local profile="$3"

    cat > "$output_dir/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: urllc-service
  namespace: oran-services
spec:
  selector:
    app: urllc
  ports:
  - port: 8081
    targetPort: 8081
    name: http
  type: LoadBalancer
EOF

    cat > "$output_dir/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: urllc-deployment
  namespace: oran-services
spec:
  replicas: 2
  selector:
    matchLabels:
      app: urllc
  template:
    metadata:
      labels:
        app: urllc
        site: $site
    spec:
      containers:
      - name: urllc
        image: oran/urllc:latest
        ports:
        - containerPort: 8081
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
EOF
}

render_mmtc_service() {
    local site="$1"
    local output_dir="$2"
    local profile="$3"

    cat > "$output_dir/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: mmtc-service
  namespace: oran-services
spec:
  selector:
    app: mmtc
  ports:
  - port: 8082
    targetPort: 8082
    name: http
  type: LoadBalancer
EOF

    cat > "$output_dir/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mmtc-deployment
  namespace: oran-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mmtc
  template:
    metadata:
      labels:
        app: mmtc
        site: $site
    spec:
      containers:
      - name: mmtc
        image: oran/mmtc:latest
        ports:
        - containerPort: 8082
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF
}

render_default_service() {
    local site="$1"
    local output_dir="$2"
    local profile="$3"

    cat > "$output_dir/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: default-service
  namespace: oran-services
spec:
  selector:
    app: default
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

    cat > "$output_dir/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: default-deployment
  namespace: oran-services
spec:
  replicas: 1
  selector:
    matchLabels:
      app: default
  template:
    metadata:
      labels:
        app: default
        site: $site
    spec:
      containers:
      - name: default
        image: oran/default:latest
        ports:
        - containerPort: 8080
EOF
}

# Main execution
main() {
    log "Starting KRM rendering pipeline"
    log "Intent file: $INTENT_FILE"
    log "Target site: $TARGET_SITE"

    # Create output base directory if it doesn't exist
    mkdir -p "$OUTPUT_BASE"

    # Override target if specified in intent
    local intent_target
    intent_target=$(extract_target_site "$INTENT_FILE")
    if [[ "$intent_target" != "edge1" ]] && [[ "$TARGET_SITE" == "edge1" ]]; then
        log "Using targetSite from intent: $intent_target"
        TARGET_SITE="$intent_target"
    fi

    # Render based on target (deterministic order)
    case "$TARGET_SITE" in
        edge1)
            render_for_site "edge1" "$INTENT_FILE"
            ;;
        edge2)
            render_for_site "edge2" "$INTENT_FILE"
            ;;
        both)
            # Always render in same order for determinism
            render_for_site "edge1" "$INTENT_FILE"
            render_for_site "edge2" "$INTENT_FILE"
            ;;
    esac

    # Verify rendering succeeded
    local success=true
    case "$TARGET_SITE" in
        edge1)
            [[ ! -d "${OUTPUT_BASE}/edge1-config" ]] && success=false
            ;;
        edge2)
            [[ ! -d "${OUTPUT_BASE}/edge2-config" ]] && success=false
            ;;
        both)
            [[ ! -d "${OUTPUT_BASE}/edge1-config" ]] && success=false
            [[ ! -d "${OUTPUT_BASE}/edge2-config" ]] && success=false
            ;;
    esac

    if [[ "$success" == "false" ]] && [[ "$DRY_RUN" != "true" ]]; then
        error "Rendering failed - output directories not created"
        exit 1
    fi

    log "KRM rendering completed successfully"
}

# Run main function
main "$@"