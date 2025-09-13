#!/usr/bin/env bash
# KRM Rendering Pipeline with Intent Compiler Integration
# Integrates TMF921 intent translation with kpt fn render pipeline

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INTENT_COMPILER="${PROJECT_ROOT}/tools/intent-compiler/translate.py"
OUTPUT_BASE="${PROJECT_ROOT}/rendered/krm"
PACKAGE_BASE="${PROJECT_ROOT}/packages"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function: Print colored message
log() {
    local level=$1
    shift
    case $level in
        INFO)  echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $*" >&2 ;;
    esac
}

# Function: Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <intent-file>

Render KRM resources from TMF921 intent using kpt fn pipeline.

Options:
    -o, --output DIR     Output directory (default: rendered/krm)
    -p, --package DIR    Package directory for kpt functions (default: packages)
    -d, --dry-run        Print commands without executing
    -v, --validate       Run kubeconform validation after rendering
    -k, --kpt-pipeline   Apply kpt fn render pipeline after translation
    -h, --help           Show this help message

Examples:
    $0 tests/intent_edge1.json
    $0 -v -k tests/intent_both.json
    $0 --dry-run -o /tmp/krm tests/intent_edge2.json

EOF
    exit 0
}

# Function: Check prerequisites
check_prerequisites() {
    local missing=()

    # Check Python
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi

    # Check translator script
    if [[ ! -f "$INTENT_COMPILER" ]]; then
        log ERROR "Intent compiler not found: $INTENT_COMPILER"
        exit 1
    fi

    # Check kpt if pipeline requested
    if [[ "$USE_KPT_PIPELINE" == "true" ]] && ! command -v kpt &> /dev/null; then
        missing+=("kpt")
    fi

    # Check kubeconform if validation requested
    if [[ "$VALIDATE" == "true" ]] && ! command -v kubeconform &> /dev/null; then
        missing+=("kubeconform")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log ERROR "Missing prerequisites: ${missing[*]}"
        log INFO "Install with:"
        for tool in "${missing[@]}"; do
            case $tool in
                kpt)
                    echo "  curl -L https://github.com/kptdev/kpt/releases/download/v1.0.0-beta.49/kpt_linux_amd64 -o /tmp/kpt"
                    echo "  chmod +x /tmp/kpt && sudo mv /tmp/kpt /usr/local/bin/"
                    ;;
                kubeconform)
                    echo "  curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz"
                    echo "  sudo mv kubeconform /usr/local/bin/"
                    ;;
            esac
        done
        exit 1
    fi
}

# Parse arguments
OUTPUT_DIR="$OUTPUT_BASE"
PACKAGE_DIR="$PACKAGE_BASE"
DRY_RUN="false"
VALIDATE="false"
USE_KPT_PIPELINE="false"
INTENT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--package)
            PACKAGE_DIR="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -v|--validate)
            VALIDATE="true"
            shift
            ;;
        -k|--kpt-pipeline)
            USE_KPT_PIPELINE="true"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            log ERROR "Unknown option: $1"
            usage
            ;;
        *)
            INTENT_FILE="$1"
            shift
            ;;
    esac
done

# Validate input
if [[ -z "$INTENT_FILE" ]]; then
    log ERROR "Intent file is required"
    usage
fi

if [[ ! -f "$INTENT_FILE" ]]; then
    log ERROR "Intent file not found: $INTENT_FILE"
    exit 1
fi

# Function: Translate intent to KRM
translate_intent() {
    local intent_file=$1
    local output_dir=$2

    log INFO "Translating intent: $intent_file"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "python3 $INTENT_COMPILER $intent_file -o $output_dir"
    else
        python3 "$INTENT_COMPILER" "$intent_file" -o "$output_dir"
    fi

    if [[ $? -eq 0 ]]; then
        log INFO "Translation complete: $output_dir"
    else
        log ERROR "Translation failed"
        exit 1
    fi
}

# Function: Apply kpt fn render pipeline
apply_kpt_pipeline() {
    local krm_dir=$1

    log INFO "Applying kpt fn render pipeline"

    # Find all site directories
    for site_dir in "$krm_dir"/*; do
        if [[ ! -d "$site_dir" ]]; then
            continue
        fi

        local site=$(basename "$site_dir")
        log INFO "Processing site: $site"

        # Create temporary package structure
        local temp_pkg=$(mktemp -d)
        cp -r "$site_dir"/* "$temp_pkg/"

        # Create Kptfile if not exists
        if [[ ! -f "$temp_pkg/Kptfile" ]]; then
            cat > "$temp_pkg/Kptfile" << EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: intent-$site
  annotations:
    config.kubernetes.io/local-config: "true"
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/set-namespace:v0.4.1
      configMap:
        namespace: $site
    - image: gcr.io/kpt-fn/set-labels:v0.2.0
      configMap:
        site: $site
        managed-by: intent-compiler
  validators:
    - image: gcr.io/kpt-fn/kubeval:v0.3.0
EOF
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "kpt fn render $temp_pkg"
        else
            # Run kpt fn render
            if kpt fn render "$temp_pkg" > /dev/null 2>&1; then
                log INFO "kpt fn render successful for $site"
                # Copy rendered resources back
                cp -r "$temp_pkg"/* "$site_dir/"
            else
                log WARN "kpt fn render failed for $site (may need additional functions)"
            fi
        fi

        # Cleanup
        rm -rf "$temp_pkg"
    done
}

# Function: Validate KRM resources
validate_resources() {
    local krm_dir=$1
    local validation_failed=0

    log INFO "Validating KRM resources with kubeconform"

    # Find all YAML files
    while IFS= read -r -d '' yaml_file; do
        # Skip kustomization files
        if [[ $(basename "$yaml_file") == "kustomization.yaml" ]] || \
           [[ $(basename "$yaml_file") == "Kptfile" ]]; then
            continue
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "kubeconform -skip-kinds NetworkSlice,ProvisioningRequest $yaml_file"
        else
            if kubeconform -skip-kinds NetworkSlice,ProvisioningRequest "$yaml_file" > /dev/null 2>&1; then
                log INFO "✓ Valid: $(basename "$yaml_file")"
            else
                log ERROR "✗ Invalid: $yaml_file"
                validation_failed=1
            fi
        fi
    done < <(find "$krm_dir" -name "*.yaml" -type f -print0)

    if [[ $validation_failed -eq 1 ]]; then
        log ERROR "Validation failed for some resources"
        return 1
    else
        log INFO "All resources validated successfully"
        return 0
    fi
}

# Function: Generate summary
generate_summary() {
    local krm_dir=$1

    log INFO "Generation Summary:"
    echo "----------------------------------------"

    for site_dir in "$krm_dir"/*; do
        if [[ ! -d "$site_dir" ]]; then
            continue
        fi

        local site=$(basename "$site_dir")
        local resource_count=$(find "$site_dir" -name "*.yaml" -type f | wc -l)

        echo "Site: $site"
        echo "  Resources: $resource_count files"
        echo "  Path: $site_dir"

        # List resource types
        echo "  Types:"
        for yaml_file in "$site_dir"/*.yaml; do
            if [[ -f "$yaml_file" ]]; then
                local kind=$(grep "^kind:" "$yaml_file" | head -1 | awk '{print $2}')
                local name=$(basename "$yaml_file")
                echo "    - $kind ($name)"
            fi
        done
        echo
    done

    echo "----------------------------------------"
}

# Main execution
main() {
    log INFO "Starting KRM rendering pipeline"
    log INFO "Intent file: $INTENT_FILE"
    log INFO "Output directory: $OUTPUT_DIR"

    # Check prerequisites
    check_prerequisites

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Step 1: Translate intent to KRM
    translate_intent "$INTENT_FILE" "$OUTPUT_DIR"

    # Step 2: Apply kpt pipeline if requested
    if [[ "$USE_KPT_PIPELINE" == "true" ]]; then
        apply_kpt_pipeline "$OUTPUT_DIR"
    fi

    # Step 3: Validate if requested
    if [[ "$VALIDATE" == "true" ]]; then
        validate_resources "$OUTPUT_DIR"
    fi

    # Step 4: Generate summary
    generate_summary "$OUTPUT_DIR"

    log INFO "KRM rendering pipeline complete"
}

# Run main function
main