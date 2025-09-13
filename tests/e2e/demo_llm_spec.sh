#!/bin/bash
#
# E2E Test Specification for Multi-Site LLM Demo Pipeline
#
# Tests the complete pipeline:
# 1. Intent parsing with targetSite routing
# 2. KRM rendering to correct GitOps directories
# 3. Validation of rendered artifacts
#

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
TESTS_GOLDEN_DIR="$PROJECT_ROOT/tests/golden"
GITOPS_DIR="$PROJECT_ROOT/gitops"
TEMP_DIR="$(mktemp -d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TEST_PASSED=0
TEST_FAILED=0
TEST_TOTAL=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*" >&2
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*" >&2
    ((TEST_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*" >&2
    ((TEST_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TEST_TOTAL++))
    log_test "Running: $test_name"
    
    if $test_function; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

# Setup test environment
setup_test_env() {
    log_test "Setting up test environment..."
    
    # Ensure GitOps directories exist
    mkdir -p "$GITOPS_DIR/edge1-config/services"
    mkdir -p "$GITOPS_DIR/edge2-config/services"
    
    # Clean up any existing test artifacts
    rm -f "$GITOPS_DIR/edge1-config/services/test-*"
    rm -f "$GITOPS_DIR/edge2-config/services/test-*"
    
    log_test "Test environment ready"
}

# Cleanup test environment
cleanup_test_env() {
    log_test "Cleaning up test environment..."
    
    # Remove test artifacts
    rm -f "$GITOPS_DIR/edge1-config/services/test-*"
    rm -f "$GITOPS_DIR/edge2-config/services/test-*"
    rm -rf "$TEMP_DIR"
    
    log_test "Test cleanup complete"
}

# Test 1: Validate intent parsing with targetSite field
test_intent_parsing_with_target_site() {
    local test_intent="$TESTS_GOLDEN_DIR/intent_edge1_embb.json"
    
    if [[ ! -f "$test_intent" ]]; then
        log_fail "Test intent file not found: $test_intent"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.targetSite' "$test_intent" >/dev/null 2>&1; then
        log_fail "Intent missing targetSite field"
        return 1
    fi
    
    local target_site
    target_site=$(jq -r '.targetSite' "$test_intent")
    
    if [[ "$target_site" != "edge1" ]]; then
        log_fail "Expected targetSite 'edge1', got '$target_site'"
        return 1
    fi
    
    return 0
}

# Test 2: KRM rendering script exists and is executable
test_render_krm_script_exists() {
    local render_script="$SCRIPTS_DIR/render_krm.sh"
    
    if [[ ! -f "$render_script" ]]; then
        log_fail "Render KRM script not found: $render_script"
        return 1
    fi
    
    if [[ ! -x "$render_script" ]]; then
        log_fail "Render KRM script not executable: $render_script"
        return 1
    fi
    
    return 0
}

# Test 3: Intent from LLM script exists and is executable
test_intent_from_llm_script_exists() {
    local intent_script="$SCRIPTS_DIR/intent_from_llm.sh"
    
    if [[ ! -f "$intent_script" ]]; then
        log_fail "Intent from LLM script not found: $intent_script"
        return 1
    fi
    
    if [[ ! -x "$intent_script" ]]; then
        log_fail "Intent from LLM script not executable: $intent_script"
        return 1
    fi
    
    return 0
}

# Test 4: Demo LLM script has target argument support
test_demo_llm_target_support() {
    local demo_script="$SCRIPTS_DIR/demo_llm.sh"
    
    if [[ ! -f "$demo_script" ]]; then
        log_fail "Demo LLM script not found: $demo_script"
        return 1
    fi
    
    # Check if script has --target option
    if ! grep -q "\-\-target" "$demo_script"; then
        log_fail "Demo LLM script missing --target option support"
        return 1
    fi
    
    return 0
}

# Test 5: Dry-run KRM rendering for edge1
test_krm_rendering_edge1_dry_run() {
    local test_intent="$TESTS_GOLDEN_DIR/intent_edge1_embb.json"
    local render_script="$SCRIPTS_DIR/render_krm.sh"
    
    if [[ ! -f "$test_intent" ]] || [[ ! -x "$render_script" ]]; then
        log_fail "Prerequisites not met for KRM rendering test"
        return 1
    fi
    
    # Run in dry-run mode
    if "$render_script" --intent "$test_intent" --target edge1 --dry-run --verbose; then
        return 0
    else
        log_fail "KRM rendering dry-run failed for edge1"
        return 1
    fi
}

# Test 6: Dry-run KRM rendering for edge2
test_krm_rendering_edge2_dry_run() {
    local test_intent="$TESTS_GOLDEN_DIR/intent_edge2_urllc.json"
    local render_script="$SCRIPTS_DIR/render_krm.sh"
    
    if [[ ! -f "$test_intent" ]] || [[ ! -x "$render_script" ]]; then
        log_fail "Prerequisites not met for KRM rendering test"
        return 1
    fi
    
    # Run in dry-run mode
    if "$render_script" --intent "$test_intent" --target edge2 --dry-run --verbose; then
        return 0
    else
        log_fail "KRM rendering dry-run failed for edge2"
        return 1
    fi
}

# Test 7: Dry-run KRM rendering for both sites
test_krm_rendering_both_dry_run() {
    local test_intent="$TESTS_GOLDEN_DIR/intent_both_mmtc.json"
    local render_script="$SCRIPTS_DIR/render_krm.sh"
    
    if [[ ! -f "$test_intent" ]] || [[ ! -x "$render_script" ]]; then
        log_fail "Prerequisites not met for KRM rendering test"
        return 1
    fi
    
    # Run in dry-run mode
    if "$render_script" --intent "$test_intent" --target both --dry-run --verbose; then
        return 0
    else
        log_fail "KRM rendering dry-run failed for both sites"
        return 1
    fi
}

# Test 8: Validate GitOps directory structure
test_gitops_directory_structure() {
    local edge1_dir="$GITOPS_DIR/edge1-config"
    local edge2_dir="$GITOPS_DIR/edge2-config"
    
    # Check edge1 structure
    for subdir in services network-functions monitoring; do
        if [[ ! -d "$edge1_dir/$subdir" ]]; then
            log_fail "Missing edge1 subdirectory: $subdir"
            return 1
        fi
    done
    
    # Check edge2 structure
    for subdir in services network-functions monitoring; do
        if [[ ! -d "$edge2_dir/$subdir" ]]; then
            log_fail "Missing edge2 subdirectory: $subdir"
            return 1
        fi
    done
    
    # Check kustomization files
    if [[ ! -f "$edge1_dir/kustomization.yaml" ]]; then
        log_fail "Missing edge1 kustomization.yaml"
        return 1
    fi
    
    if [[ ! -f "$edge2_dir/kustomization.yaml" ]]; then
        log_fail "Missing edge2 kustomization.yaml"
        return 1
    fi
    
    return 0
}

# Test 9: Validate golden test files have correct structure
test_golden_files_structure() {
    local golden_files=(
        "$TESTS_GOLDEN_DIR/intent_edge1_embb.json"
        "$TESTS_GOLDEN_DIR/intent_edge2_urllc.json"
        "$TESTS_GOLDEN_DIR/intent_both_mmtc.json"
    )
    
    for file in "${golden_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_fail "Golden file not found: $file"
            return 1
        fi
        
        # Validate JSON structure
        if ! jq -e '.intentExpectationId and .targetSite' "$file" >/dev/null 2>&1; then
            log_fail "Golden file missing required fields: $file"
            return 1
        fi
    done
    
    return 0
}

# Test 10: Demo script help output includes multi-site options
test_demo_script_help() {
    local demo_script="$SCRIPTS_DIR/demo_llm.sh"
    
    if [[ ! -x "$demo_script" ]]; then
        log_fail "Demo script not executable: $demo_script"
        return 1
    fi
    
    # Check help output mentions target sites
    local help_output
    help_output=$("$demo_script" --help 2>&1 || true)
    
    if [[ ! "$help_output" =~ edge1.*edge2.*both ]]; then
        log_fail "Demo script help doesn't mention multi-site targets"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo
    log_test "Starting Multi-Site LLM Demo Pipeline E2E Tests"
    echo
    
    # Setup
    setup_test_env
    
    # Run tests
    run_test "Intent parsing with targetSite field" test_intent_parsing_with_target_site
    run_test "Render KRM script exists and executable" test_render_krm_script_exists
    run_test "Intent from LLM script exists and executable" test_intent_from_llm_script_exists
    run_test "Demo LLM script has target argument support" test_demo_llm_target_support
    run_test "KRM rendering edge1 dry-run" test_krm_rendering_edge1_dry_run
    run_test "KRM rendering edge2 dry-run" test_krm_rendering_edge2_dry_run
    run_test "KRM rendering both sites dry-run" test_krm_rendering_both_dry_run
    run_test "GitOps directory structure" test_gitops_directory_structure
    run_test "Golden test files structure" test_golden_files_structure
    run_test "Demo script help includes multi-site options" test_demo_script_help
    
    # Cleanup
    cleanup_test_env
    
    # Results
    echo
    log_test "Test Results Summary:"
    log_test "  Total: $TEST_TOTAL"
    log_test "  Passed: $TEST_PASSED"
    log_test "  Failed: $TEST_FAILED"
    echo
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        log_pass "All tests passed! Multi-site routing pipeline is ready."
        exit 0
    else
        log_fail "$TEST_FAILED tests failed. Please fix issues before proceeding."
        exit 1
    fi
}

# Execute main function
main "$@"