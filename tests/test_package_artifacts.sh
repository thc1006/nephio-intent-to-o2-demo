#!/bin/bash
#
# test_package_artifacts.sh - Integration test for package_artifacts.sh
# Tests supply chain trust artifact packaging functionality
#

set -euo pipefail

# Test configuration
TEST_DIR="$(dirname "$0")"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
SCRIPT_DIR="$PROJECT_ROOT/scripts"
PACKAGE_SCRIPT="$SCRIPT_DIR/package_artifacts.sh"
TEST_TIMESTAMP="test-$(date +%s)"
REPORTS_DIR="./reports"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
log_test() {
    echo "[TEST] $1"
}

log_pass() {
    echo "  ✓ PASS: $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo "  ✗ FAIL: $1"
    ((TESTS_FAILED++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"

    log_test "$test_name"
    ((TESTS_RUN++))

    if eval "$test_command"; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Test 1: Script exists and is executable
test_script_exists() {
    [[ -x "$PACKAGE_SCRIPT" ]]
}

# Test 2: Help option works
test_help_option() {
    "$PACKAGE_SCRIPT" --help >/dev/null 2>&1
}

# Test 3: Dry run completes without errors
test_dry_run() {
    "$PACKAGE_SCRIPT" --dry-run --timestamp="$TEST_TIMESTAMP" >/dev/null 2>&1
}

# Test 4: Full packaging creates expected structure
test_full_packaging() {
    "$PACKAGE_SCRIPT" --timestamp="$TEST_TIMESTAMP" --no-attestation >/dev/null 2>&1 && \
    [[ -d "$REPORTS_DIR/$TEST_TIMESTAMP" ]] && \
    [[ -f "$REPORTS_DIR/$TEST_TIMESTAMP/manifest.json" ]] && \
    [[ -f "$REPORTS_DIR/$TEST_TIMESTAMP/checksums.txt" ]] && \
    [[ -d "$REPORTS_DIR/$TEST_TIMESTAMP/artifacts" ]]
}

# Test 5: Manifest contains expected fields
test_manifest_content() {
    local manifest="$REPORTS_DIR/$TEST_TIMESTAMP/manifest.json"
    [[ -f "$manifest" ]] && \
    jq -e '.package_info.timestamp' "$manifest" >/dev/null && \
    jq -e '.artifacts.total_count' "$manifest" >/dev/null && \
    jq -e '.compliance.o_ran_wg11' "$manifest" >/dev/null && \
    jq -e '.security.checksums_verified' "$manifest" >/dev/null
}

# Test 6: Checksums file is valid
test_checksums_validity() {
    local checksums_file="$REPORTS_DIR/$TEST_TIMESTAMP/checksums.txt"
    local artifacts_dir="$REPORTS_DIR/$TEST_TIMESTAMP/artifacts"

    [[ -f "$checksums_file" ]] && \
    (cd "$artifacts_dir" && sha256sum -c "../checksums.txt" >/dev/null 2>&1)
}

# Test 7: Package archive is created
test_package_creation() {
    [[ -f "$REPORTS_DIR/${TEST_TIMESTAMP}.tar.gz" ]] && \
    [[ -f "$REPORTS_DIR/${TEST_TIMESTAMP}.tar.gz.sha256" ]]
}

# Test 8: Latest symlink is updated
test_latest_symlink() {
    [[ -L "$REPORTS_DIR/latest" ]] && \
    [[ "$(readlink "$REPORTS_DIR/latest")" == "$TEST_TIMESTAMP" ]]
}

# Test 9: JSON logging works
test_json_logging() {
    local output=$("$PACKAGE_SCRIPT" --dry-run --json-logs --timestamp="json-test-$(date +%s)" 2>&1)
    echo "$output" | head -1 | jq -e '.timestamp and .level and .message' >/dev/null
}

# Test 10: Error handling for missing dependencies
test_dependency_check() {
    # This test simulates missing jq by using a fake PATH
    PATH="/nonexistent:$PATH" "$PACKAGE_SCRIPT" --dry-run --timestamp="dep-test-$(date +%s)" 2>/dev/null && return 1 || return 0
}

# Test 11: Cosign attestation generation (if available)
test_cosign_attestation() {
    if command -v cosign >/dev/null 2>&1; then
        local test_ts="cosign-test-$(date +%s)"
        "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1 && \
        [[ -f "$REPORTS_DIR/$test_ts/attestations/attest.json" ]]
    else
        # Skip test if cosign not available
        return 0
    fi
}

# Test 12: SBOM generation (if syft available)
test_sbom_generation() {
    if command -v syft >/dev/null 2>&1; then
        local test_ts="sbom-test-$(date +%s)"
        "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1 && \
        [[ -f "$REPORTS_DIR/$test_ts/sbom/sbom.json" ]]
    else
        # Skip test if syft not available
        return 0
    fi
}

# Test 13: Security scan results
test_security_scan() {
    local test_ts="security-test-$(date +%s)"
    "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1 && \
    [[ -f "$REPORTS_DIR/$test_ts/metadata/security_scan.json" ]] && \
    jq -e '.findings_count >= 0' "$REPORTS_DIR/$test_ts/metadata/security_scan.json" >/dev/null
}

# Test 14: Artifact collection with missing files
test_missing_artifacts_handling() {
    # Test that script handles missing artifacts gracefully
    local test_ts="missing-test-$(date +%s)"
    "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1 && \
    [[ -f "$REPORTS_DIR/$test_ts/artifacts/intent.json" ]] && \
    [[ -f "$REPORTS_DIR/$test_ts/artifacts/postcheck.json" ]] && \
    [[ -f "$REPORTS_DIR/$test_ts/artifacts/o2ims.json" ]]
}

# Test 15: Idempotent execution
test_idempotent_execution() {
    local test_ts="idem-test-$(date +%s)"
    "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1
    local first_checksum=$(sha256sum "$REPORTS_DIR/${test_ts}.tar.gz" | cut -d' ' -f1)

    # Run again with same timestamp (should be idempotent)
    "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1
    local second_checksum=$(sha256sum "$REPORTS_DIR/${test_ts}.tar.gz" | cut -d' ' -f1)

    [[ "$first_checksum" == "$second_checksum" ]]
}

# Test 16: Package verification
test_package_verification() {
    local test_ts="verify-test-$(date +%s)"
    "$PACKAGE_SCRIPT" --timestamp="$test_ts" >/dev/null 2>&1 && \
    sha256sum -c "$REPORTS_DIR/${test_ts}.tar.gz.sha256" >/dev/null 2>&1
}

# Test 17: Configuration options
test_configuration_options() {
    local test_ts="config-test-$(date +%s)"
    "$PACKAGE_SCRIPT" --timestamp="$test_ts" --no-sbom --no-security-scan >/dev/null 2>&1 && \
    [[ -f "$REPORTS_DIR/$test_ts/manifest.json" ]] && \
    [[ $(jq -r '.security.sbom_generated' "$REPORTS_DIR/$test_ts/manifest.json") == "false" ]]
}

# Main test execution
main() {
    log_test "Starting package_artifacts.sh integration tests"
    echo

    run_test "Script exists and is executable" "test_script_exists"
    run_test "Help option works" "test_help_option"
    run_test "Dry run completes without errors" "test_dry_run"
    run_test "Full packaging creates expected structure" "test_full_packaging"
    run_test "Manifest contains expected fields" "test_manifest_content"
    run_test "Checksums file is valid" "test_checksums_validity"
    run_test "Package archive is created" "test_package_creation"
    run_test "Latest symlink is updated" "test_latest_symlink"
    run_test "JSON logging works" "test_json_logging"
    run_test "Dependency check works" "test_dependency_check"
    run_test "Cosign attestation generation (if available)" "test_cosign_attestation"
    run_test "SBOM generation (if syft available)" "test_sbom_generation"
    run_test "Security scan results" "test_security_scan"
    run_test "Missing artifacts handling" "test_missing_artifacts_handling"
    run_test "Idempotent execution" "test_idempotent_execution"
    run_test "Package verification" "test_package_verification"
    run_test "Configuration options" "test_configuration_options"

    echo
    echo "=== Test Summary ==="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"

    # Cleanup all test artifacts
    for test_dir in "$REPORTS_DIR"/test-* "$REPORTS_DIR"/cosign-test-* "$REPORTS_DIR"/sbom-test-* \
                   "$REPORTS_DIR"/security-test-* "$REPORTS_DIR"/missing-test-* "$REPORTS_DIR"/idem-test-* \
                   "$REPORTS_DIR"/verify-test-* "$REPORTS_DIR"/config-test-* "$REPORTS_DIR"/json-test-* \
                   "$REPORTS_DIR"/dep-test-*; do
        if [[ -d "$test_dir" ]]; then
            rm -rf "$test_dir"
        fi
    done

    # Cleanup package files
    for pkg_file in "$REPORTS_DIR"/*.tar.gz; do
        if [[ -f "$pkg_file" && "$pkg_file" =~ test- ]]; then
            rm -f "$pkg_file"
            rm -f "${pkg_file}.sha256"
        fi
    done

    if [[ -d "$REPORTS_DIR/$TEST_TIMESTAMP" ]]; then
        rm -rf "$REPORTS_DIR/$TEST_TIMESTAMP"
        rm -f "$REPORTS_DIR/${TEST_TIMESTAMP}.tar.gz"
        rm -f "$REPORTS_DIR/${TEST_TIMESTAMP}.tar.gz.sha256"
    fi

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✓ All tests passed!"
        exit 0
    else
        echo "✗ $TESTS_FAILED test(s) failed"
        exit 1
    fi
}

# Run tests
main "$@"