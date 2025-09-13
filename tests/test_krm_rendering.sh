#!/bin/bash
# Comprehensive KRM Rendering Test Suite
# Tests routing, idempotency, determinism, and YAML validation

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RENDER_SCRIPT="$PROJECT_ROOT/scripts/render_krm.sh"
GOLDEN_DIR="$PROJECT_ROOT/tests/golden"
EXPECTED_DIR="$GOLDEN_DIR/expected"
OUTPUT_BASE="$PROJECT_ROOT/tests/output"
TEMP_DIR="$(mktemp -d)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
    rm -rf "$OUTPUT_BASE"
}
trap cleanup EXIT

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_error() { echo -e "${RED}[FAIL]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running: $test_name"

    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name"
        return 1
    fi
}

# Validate YAML syntax
validate_yaml() {
    local file="$1"
    if ! command -v python3 &>/dev/null; then
        log_warn "Python3 not found, skipping YAML validation"
        return 0
    fi

    python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null
}

# Check if files are identical
files_identical() {
    local file1="$1"
    local file2="$2"
    diff -q "$file1" "$file2" >/dev/null 2>&1
}

# Sort and normalize YAML for comparison
normalize_yaml() {
    local file="$1"
    if command -v python3 &>/dev/null; then
        python3 -c "
import yaml, json, sys
with open('$file') as f:
    data = yaml.safe_load(f)
    print(json.dumps(data, sort_keys=True, indent=2))
" 2>/dev/null || cat "$file"
    else
        cat "$file"
    fi
}

# Compare directories recursively
compare_directories() {
    local dir1="$1"
    local dir2="$2"
    local exclude_pattern="${3:-}"

    # Check same number of files
    local count1=$(find "$dir1" -type f | wc -l)
    local count2=$(find "$dir2" -type f | wc -l)

    if [ "$count1" -ne "$count2" ]; then
        log_error "Different number of files: $dir1 ($count1) vs $dir2 ($count2)"
        return 1
    fi

    # Compare each file
    while IFS= read -r file; do
        local relative_path="${file#$dir1/}"
        local file2="$dir2/$relative_path"

        if [ ! -f "$file2" ]; then
            log_error "Missing file in $dir2: $relative_path"
            return 1
        fi

        # Skip if matches exclude pattern
        if [ -n "$exclude_pattern" ] && echo "$relative_path" | grep -q "$exclude_pattern"; then
            continue
        fi

        # Compare normalized content
        if ! diff -q <(normalize_yaml "$file") <(normalize_yaml "$file2") >/dev/null 2>&1; then
            log_error "Files differ: $relative_path"
            return 1
        fi
    done < <(find "$dir1" -type f)

    return 0
}

# Test: Edge1 routing
test_edge1_routing() {
    local intent_file="$GOLDEN_DIR/intent_edge1.json"
    local output_dir="$OUTPUT_BASE/edge1-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge1 >/dev/null 2>&1

    # Check edge1-config exists and has files
    if [ ! -d "$output_dir/edge1-config" ]; then
        log_error "edge1-config directory not created"
        return 1
    fi

    # Check edge2-config does NOT exist
    if [ -d "$output_dir/edge2-config" ]; then
        log_error "edge2-config should not exist for edge1 target"
        return 1
    fi

    # Validate all YAML files
    for yaml_file in "$output_dir/edge1-config"/*.yaml; do
        if [ -f "$yaml_file" ]; then
            if ! validate_yaml "$yaml_file"; then
                log_error "Invalid YAML: $yaml_file"
                return 1
            fi
        fi
    done

    # Check required files exist
    local required_files=("namespace.yaml" "service.yaml" "deployment.yaml" "kustomization.yaml")
    for file in "${required_files[@]}"; do
        if [ ! -f "$output_dir/edge1-config/$file" ]; then
            log_error "Required file missing: $file"
            return 1
        fi
    done

    return 0
}

# Test: Edge2 routing
test_edge2_routing() {
    local intent_file="$GOLDEN_DIR/intent_edge2.json"
    local output_dir="$OUTPUT_BASE/edge2-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge2 >/dev/null 2>&1

    # Check edge2-config exists and has files
    if [ ! -d "$output_dir/edge2-config" ]; then
        log_error "edge2-config directory not created"
        return 1
    fi

    # Check edge1-config does NOT exist
    if [ -d "$output_dir/edge1-config" ]; then
        log_error "edge1-config should not exist for edge2 target"
        return 1
    fi

    # Validate all YAML files
    for yaml_file in "$output_dir/edge2-config"/*.yaml; do
        if [ -f "$yaml_file" ]; then
            if ! validate_yaml "$yaml_file"; then
                log_error "Invalid YAML: $yaml_file"
                return 1
            fi
        fi
    done

    return 0
}

# Test: Both sites routing
test_both_routing() {
    local intent_file="$GOLDEN_DIR/intent_both.json"
    local output_dir="$OUTPUT_BASE/both-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target both >/dev/null 2>&1

    # Check both directories exist
    if [ ! -d "$output_dir/edge1-config" ]; then
        log_error "edge1-config directory not created"
        return 1
    fi

    if [ ! -d "$output_dir/edge2-config" ]; then
        log_error "edge2-config directory not created"
        return 1
    fi

    # Files should be identical in both directories (except site labels)
    for file in namespace.yaml service.yaml deployment.yaml kustomization.yaml; do
        if [ ! -f "$output_dir/edge1-config/$file" ] || [ ! -f "$output_dir/edge2-config/$file" ]; then
            log_error "Required file missing: $file"
            return 1
        fi

        # Check that site labels are correct
        if grep -q "site: edge1" "$output_dir/edge1-config/$file" 2>/dev/null; then
            if grep -q "site: edge2" "$output_dir/edge1-config/$file" 2>/dev/null; then
                log_error "edge1 config contains edge2 labels"
                return 1
            fi
        fi

        if grep -q "site: edge2" "$output_dir/edge2-config/$file" 2>/dev/null; then
            if grep -q "site: edge1" "$output_dir/edge2-config/$file" 2>/dev/null; then
                log_error "edge2 config contains edge1 labels"
                return 1
            fi
        fi
    done

    return 0
}

# Test: Idempotency
test_idempotency() {
    local intent_file="$GOLDEN_DIR/intent_edge1.json"
    local output_dir="$OUTPUT_BASE/idempotent-test"

    rm -rf "$output_dir"

    # Run twice
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge1 >/dev/null 2>&1
    cp -r "$output_dir/edge1-config" "$TEMP_DIR/run1"

    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge1 >/dev/null 2>&1
    cp -r "$output_dir/edge1-config" "$TEMP_DIR/run2"

    # Compare outputs
    if ! compare_directories "$TEMP_DIR/run1" "$TEMP_DIR/run2"; then
        log_error "Rendering is not idempotent"
        return 1
    fi

    return 0
}

# Test: Deterministic file ordering
test_deterministic_ordering() {
    local intent_file="$GOLDEN_DIR/intent_both.json"
    local output_dir="$OUTPUT_BASE/deterministic-test"

    rm -rf "$output_dir"

    # Run multiple times and check file creation order
    local run_count=3
    for i in $(seq 1 $run_count); do
        rm -rf "$output_dir"
        OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target both >/dev/null 2>&1

        # List files in order
        find "$output_dir" -type f -name "*.yaml" | sort > "$TEMP_DIR/files_$i.txt"
    done

    # Compare file lists
    for i in $(seq 2 $run_count); do
        if ! files_identical "$TEMP_DIR/files_1.txt" "$TEMP_DIR/files_$i.txt"; then
            log_error "File ordering is not deterministic (run 1 vs run $i)"
            return 1
        fi
    done

    return 0
}

# Test: No cross-contamination
test_no_cross_contamination() {
    local output_dir="$OUTPUT_BASE/contamination-test"

    rm -rf "$output_dir"

    # Render edge1
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$GOLDEN_DIR/intent_edge1.json" --target edge1 >/dev/null 2>&1

    # Check no edge2 references in edge1 files
    if grep -r "edge2" "$output_dir/edge1-config" 2>/dev/null | grep -v "^Binary"; then
        log_error "Found edge2 references in edge1 config"
        return 1
    fi

    # Clean and render edge2
    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$GOLDEN_DIR/intent_edge2.json" --target edge2 >/dev/null 2>&1

    # Check no edge1 references in edge2 files
    if grep -r "edge1" "$output_dir/edge2-config" 2>/dev/null | grep -v "^Binary"; then
        log_error "Found edge1 references in edge2 config"
        return 1
    fi

    return 0
}

# Test: Service type rendering (eMBB)
test_embb_rendering() {
    local intent_file="$GOLDEN_DIR/intent_edge1_embb.json"
    local output_dir="$OUTPUT_BASE/embb-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge1 >/dev/null 2>&1

    # Check for eMBB-specific configuration
    if ! grep -q "embb-service" "$output_dir/edge1-config/service.yaml" 2>/dev/null; then
        log_error "eMBB service not properly rendered"
        return 1
    fi

    if ! grep -q "embb-deployment" "$output_dir/edge1-config/deployment.yaml" 2>/dev/null; then
        log_error "eMBB deployment not properly rendered"
        return 1
    fi

    return 0
}

# Test: Service type rendering (URLLC)
test_urllc_rendering() {
    local intent_file="$GOLDEN_DIR/intent_edge2_urllc.json"
    local output_dir="$OUTPUT_BASE/urllc-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge2 >/dev/null 2>&1

    # Check for URLLC-specific configuration
    if ! grep -q "urllc-service" "$output_dir/edge2-config/service.yaml" 2>/dev/null; then
        log_error "URLLC service not properly rendered"
        return 1
    fi

    if ! grep -q "urllc-deployment" "$output_dir/edge2-config/deployment.yaml" 2>/dev/null; then
        log_error "URLLC deployment not properly rendered"
        return 1
    fi

    # Check for higher resource limits (URLLC needs more resources)
    if ! grep -q "memory: \"1Gi\"" "$output_dir/edge2-config/deployment.yaml" 2>/dev/null; then
        log_error "URLLC resource limits not properly set"
        return 1
    fi

    return 0
}

# Test: Service type rendering (mMTC)
test_mmtc_rendering() {
    local intent_file="$GOLDEN_DIR/intent_both_mmtc.json"
    local output_dir="$OUTPUT_BASE/mmtc-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target both >/dev/null 2>&1

    # Check for mMTC-specific configuration in both sites
    for site in edge1 edge2; do
        if ! grep -q "mmtc-service" "$output_dir/$site-config/service.yaml" 2>/dev/null; then
            log_error "mMTC service not properly rendered for $site"
            return 1
        fi

        if ! grep -q "mmtc-deployment" "$output_dir/$site-config/deployment.yaml" 2>/dev/null; then
            log_error "mMTC deployment not properly rendered for $site"
            return 1
        fi

        # Check for lower resource limits (mMTC needs fewer resources)
        if ! grep -q "memory: \"256Mi\"" "$output_dir/$site-config/deployment.yaml" 2>/dev/null; then
            log_error "mMTC resource limits not properly set for $site"
            return 1
        fi
    done

    return 0
}

# Test: Intent targetSite override
test_intent_targetsite_override() {
    local output_dir="$OUTPUT_BASE/override-test"

    # Create intent with targetSite: edge2
    cat > "$TEMP_DIR/intent_override.json" <<EOF
{
  "intentExpectationId": "override-test-001",
  "targetSite": "edge2",
  "serviceType": "enhanced-mobile-broadband",
  "resourceProfile": "standard"
}
EOF

    rm -rf "$output_dir"
    # Run with --target edge1 but intent says edge2
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$TEMP_DIR/intent_override.json" --target edge1 >/dev/null 2>&1

    # Should respect intent's targetSite and create edge2-config
    if [ ! -d "$output_dir/edge2-config" ]; then
        log_error "Intent targetSite not respected"
        return 1
    fi

    return 0
}

# Test: Dry run mode
test_dry_run() {
    local intent_file="$GOLDEN_DIR/intent_edge1.json"
    local output_dir="$OUTPUT_BASE/dry-run-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" DRY_RUN=true "$RENDER_SCRIPT" "$intent_file" --target edge1 >/dev/null 2>&1

    # Should NOT create any files
    if [ -d "$output_dir/edge1-config" ]; then
        log_error "Dry run created files"
        return 1
    fi

    return 0
}

# Test: Error handling - invalid intent file
test_invalid_intent_file() {
    local output_dir="$OUTPUT_BASE/error-test"

    rm -rf "$output_dir"

    # Should fail with non-existent file
    if OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "/non/existent/file.json" --target edge1 2>/dev/null; then
        log_error "Should fail with non-existent intent file"
        return 1
    fi

    return 0
}

# Test: Error handling - invalid target site
test_invalid_target_site() {
    local intent_file="$GOLDEN_DIR/intent_edge1.json"
    local output_dir="$OUTPUT_BASE/invalid-target-test"

    rm -rf "$output_dir"

    # Should fail with invalid target
    if OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target invalid 2>/dev/null; then
        log_error "Should fail with invalid target site"
        return 1
    fi

    return 0
}

# Test: Kustomization validity
test_kustomization_validity() {
    local intent_file="$GOLDEN_DIR/intent_edge1.json"
    local output_dir="$OUTPUT_BASE/kustomize-test"

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$intent_file" --target edge1 >/dev/null 2>&1

    # Check kustomization.yaml references all resources
    local kustomization="$output_dir/edge1-config/kustomization.yaml"

    if ! grep -q "namespace.yaml" "$kustomization" 2>/dev/null; then
        log_error "kustomization.yaml missing namespace.yaml"
        return 1
    fi

    if ! grep -q "service.yaml" "$kustomization" 2>/dev/null; then
        log_error "kustomization.yaml missing service.yaml"
        return 1
    fi

    if ! grep -q "deployment.yaml" "$kustomization" 2>/dev/null; then
        log_error "kustomization.yaml missing deployment.yaml"
        return 1
    fi

    # Test kustomize build if available
    if command -v kustomize &>/dev/null; then
        if ! kustomize build "$output_dir/edge1-config" >/dev/null 2>&1; then
            log_error "kustomize build failed"
            return 1
        fi
    else
        log_warn "kustomize not installed, skipping build test"
    fi

    return 0
}

# Test: Resource profiles
test_resource_profiles() {
    local output_dir="$OUTPUT_BASE/profile-test"

    # Create intent with high-performance profile
    cat > "$TEMP_DIR/intent_highperf.json" <<EOF
{
  "intentExpectationId": "highperf-test-001",
  "targetSite": "edge1",
  "serviceType": "enhanced-mobile-broadband",
  "resourceProfile": "high-performance"
}
EOF

    rm -rf "$output_dir"
    OUTPUT_BASE="$output_dir" "$RENDER_SCRIPT" "$TEMP_DIR/intent_highperf.json" --target edge1 >/dev/null 2>&1

    # Check for increased replicas
    if ! grep -q "replicas: 3" "$output_dir/edge1-config/deployment.yaml" 2>/dev/null; then
        log_error "High-performance profile not applied"
        return 1
    fi

    return 0
}

# Main test execution
main() {
    log_info "Starting KRM Rendering Test Suite"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Output base: $OUTPUT_BASE"

    # Create output directory
    mkdir -p "$OUTPUT_BASE"

    # Run all tests
    run_test "Edge1 routing" test_edge1_routing
    run_test "Edge2 routing" test_edge2_routing
    run_test "Both sites routing" test_both_routing
    run_test "Idempotency" test_idempotency
    run_test "Deterministic ordering" test_deterministic_ordering
    run_test "No cross-contamination" test_no_cross_contamination
    run_test "eMBB service rendering" test_embb_rendering
    run_test "URLLC service rendering" test_urllc_rendering
    run_test "mMTC service rendering" test_mmtc_rendering
    run_test "Intent targetSite override" test_intent_targetsite_override
    run_test "Dry run mode" test_dry_run
    run_test "Invalid intent file handling" test_invalid_intent_file
    run_test "Invalid target site handling" test_invalid_target_site
    run_test "Kustomization validity" test_kustomization_validity
    run_test "Resource profiles" test_resource_profiles

    # Print summary
    echo
    echo "====================================="
    echo "Test Summary"
    echo "====================================="
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "====================================="

    if [ "$TESTS_FAILED" -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi