#!/bin/bash
set -euo pipefail

# test_slo_integration.sh - Test script for enhanced postcheck.sh and rollback.sh integration
# Tests the complete SLO-gated pipeline with evidence collection and rollback

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
EXECUTION_ID="$(date +%Y%m%d_%H%M%S)_$$"

# Test configuration
TEST_MODE="${TEST_MODE:-comprehensive}"  # basic|comprehensive|rollback-only
DRY_RUN="${DRY_RUN:-true}"
SIMULATE_FAILURE="${SIMULATE_FAILURE:-false}"
TARGET_SITE="${TARGET_SITE:-edge1}"

# Directory configuration
TEST_REPORTS_DIR="./reports/test-${EXECUTION_ID}"
EVIDENCE_DIR="$TEST_REPORTS_DIR/evidence"
ARTIFACTS_DIR="./artifacts/test-${EXECUTION_ID}"

# Logging
log() {
    local level="$1"
    local message="$2"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")] [$level] [test] $message"
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# Initialize test environment
initialize_test_environment() {
    log_info "Initializing test environment: $EXECUTION_ID"

    # Create test directories
    mkdir -p "$TEST_REPORTS_DIR" "$EVIDENCE_DIR" "$ARTIFACTS_DIR"

    # Set environment variables for consistent testing
    export VM2_IP="${VM2_IP:-172.16.4.45}"
    export VM4_IP="${VM4_IP:-172.16.4.176}"
    export REPORT_DIR="$TEST_REPORTS_DIR"
    export ROLLBACK_DIR="$TEST_REPORTS_DIR/rollback"
    export COLLECT_EVIDENCE="true"
    export CREATE_SNAPSHOTS="true"
    export ENABLE_RCA="true"
    export LOG_LEVEL="INFO"

    # Create test manifest
    cat > "$TEST_REPORTS_DIR/test-manifest.json" <<EOF
{
  "test": {
    "execution_id": "$EXECUTION_ID",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "mode": "$TEST_MODE",
    "dry_run": $([[ "$DRY_RUN" == "true" ]] && echo "true" || echo "false"),
    "target_site": "$TARGET_SITE",
    "simulate_failure": $([[ "$SIMULATE_FAILURE" == "true" ]] && echo "true" || echo "false")
  },
  "scripts": {
    "postcheck": "./scripts/postcheck.sh",
    "rollback": "./scripts/rollback.sh",
    "demo_llm": "./scripts/demo_llm.sh"
  }
}
EOF

    log_info "Test environment initialized"
}

# Test postcheck.sh functionality
test_postcheck_functionality() {
    log_info "Testing postcheck.sh functionality"

    local postcheck_exit_code=0
    local postcheck_output=""

    # Test basic postcheck execution
    log_info "Running postcheck with target site: $TARGET_SITE"

    if [[ "$SIMULATE_FAILURE" == "true" ]]; then
        # Set thresholds that will cause failure for testing
        export LATENCY_P95_THRESHOLD_MS="1"
        export SUCCESS_RATE_THRESHOLD="0.999"
        export THROUGHPUT_P95_THRESHOLD_MBPS="1000"
        log_info "Simulating SLO failure with strict thresholds"
    fi

    # Execute postcheck
    if postcheck_output=$(TARGET_SITE="$TARGET_SITE" ./scripts/postcheck.sh 2>&1); then
        postcheck_exit_code=0
        log_info "✅ Postcheck completed successfully"
    else
        postcheck_exit_code=$?
        log_warn "⚠️ Postcheck failed with exit code: $postcheck_exit_code"

        if [[ $postcheck_exit_code -eq 3 ]]; then
            log_info "SLO violation detected (expected for simulation)"
        fi
    fi

    # Save postcheck output
    echo "$postcheck_output" > "$EVIDENCE_DIR/postcheck-output.log"
    echo "Exit Code: $postcheck_exit_code" >> "$EVIDENCE_DIR/postcheck-output.log"

    # Check for expected outputs
    local postcheck_report_found=false
    local evidence_collected=false

    if ls "$TEST_REPORTS_DIR"/postcheck_report.json &>/dev/null; then
        postcheck_report_found=true
        log_info "✅ Postcheck report generated"

        # Validate report structure
        if jq -e '.metadata.execution_id' "$TEST_REPORTS_DIR"/postcheck_report.json &>/dev/null; then
            log_info "✅ Report structure is valid"
        else
            log_error "❌ Invalid report structure"
        fi
    else
        log_error "❌ Postcheck report not found"
    fi

    if ls "$TEST_REPORTS_DIR"/evidence/ &>/dev/null; then
        evidence_collected=true
        log_info "✅ Evidence collection completed"
        ls -la "$TEST_REPORTS_DIR"/evidence/ > "$EVIDENCE_DIR/evidence-inventory.txt" 2>/dev/null || true
    else
        log_warn "⚠️ No evidence directory found"
    fi

    # Create postcheck test results
    cat > "$EVIDENCE_DIR/postcheck-test-results.json" <<EOF
{
  "postcheck_test": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "exit_code": $postcheck_exit_code,
    "report_generated": $postcheck_report_found,
    "evidence_collected": $evidence_collected,
    "target_site": "$TARGET_SITE",
    "simulated_failure": $([[ "$SIMULATE_FAILURE" == "true" ]] && echo "true" || echo "false")
  }
}
EOF

    return $postcheck_exit_code
}

# Test rollback.sh functionality
test_rollback_functionality() {
    log_info "Testing rollback.sh functionality"

    local rollback_exit_code=0
    local rollback_output=""
    local rollback_reason="test-rollback"

    # Test rollback execution
    log_info "Running rollback with reason: $rollback_reason"

    # Set rollback environment
    export ROLLBACK_STRATEGY="revert"
    export TARGET_SITE="$TARGET_SITE"
    export DRY_RUN="$DRY_RUN"

    # Execute rollback
    if rollback_output=$(./scripts/rollback.sh "$rollback_reason" 2>&1); then
        rollback_exit_code=0
        log_info "✅ Rollback completed successfully"
    else
        rollback_exit_code=$?
        log_error "❌ Rollback failed with exit code: $rollback_exit_code"
    fi

    # Save rollback output
    echo "$rollback_output" > "$EVIDENCE_DIR/rollback-output.log"
    echo "Exit Code: $rollback_exit_code" >> "$EVIDENCE_DIR/rollback-output.log"

    # Check for expected outputs
    local rollback_report_found=false
    local snapshots_created=false
    local rca_performed=false

    if ls "$TEST_REPORTS_DIR"/rollback/rollback_report.json &>/dev/null; then
        rollback_report_found=true
        log_info "✅ Rollback report generated"

        # Validate report structure
        if jq -e '.metadata.execution_id' "$TEST_REPORTS_DIR"/rollback/rollback_report.json &>/dev/null; then
            log_info "✅ Rollback report structure is valid"
        else
            log_error "❌ Invalid rollback report structure"
        fi
    else
        log_warn "⚠️ Rollback report not found"
    fi

    if ls "$TEST_REPORTS_DIR"/rollback/snapshots/ &>/dev/null; then
        snapshots_created=true
        log_info "✅ Rollback snapshots created"
        ls -la "$TEST_REPORTS_DIR"/rollback/snapshots/ > "$EVIDENCE_DIR/snapshots-inventory.txt" 2>/dev/null || true
    else
        log_warn "⚠️ No snapshots directory found"
    fi

    if ls "$TEST_REPORTS_DIR"/rollback/root-cause-analysis/ &>/dev/null; then
        rca_performed=true
        log_info "✅ Root cause analysis performed"
        ls -la "$TEST_REPORTS_DIR"/rollback/root-cause-analysis/ > "$EVIDENCE_DIR/rca-inventory.txt" 2>/dev/null || true
    else
        log_warn "⚠️ No RCA directory found"
    fi

    # Create rollback test results
    cat > "$EVIDENCE_DIR/rollback-test-results.json" <<EOF
{
  "rollback_test": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "exit_code": $rollback_exit_code,
    "report_generated": $rollback_report_found,
    "snapshots_created": $snapshots_created,
    "rca_performed": $rca_performed,
    "strategy": "$ROLLBACK_STRATEGY",
    "reason": "$rollback_reason",
    "dry_run": $([[ "$DRY_RUN" == "true" ]] && echo "true" || echo "false")
  }
}
EOF

    return $rollback_exit_code
}

# Test integration with demo_llm.sh
test_demo_llm_integration() {
    log_info "Testing integration with demo_llm.sh"

    # Check if demo_llm.sh exists and can call postcheck/rollback
    if [[ ! -f "./scripts/demo_llm.sh" ]]; then
        log_warn "⚠️ demo_llm.sh not found, skipping integration test"
        return 0
    fi

    # Test the integration points
    local integration_points=()

    # Check if demo_llm.sh references postcheck.sh
    if grep -q "postcheck" "./scripts/demo_llm.sh"; then
        integration_points+=("postcheck_referenced")
        log_info "✅ demo_llm.sh references postcheck.sh"
    else
        log_warn "⚠️ demo_llm.sh does not reference postcheck.sh"
    fi

    # Check if demo_llm.sh references rollback.sh
    if grep -q "rollback" "./scripts/demo_llm.sh"; then
        integration_points+=("rollback_referenced")
        log_info "✅ demo_llm.sh references rollback.sh"
    else
        log_warn "⚠️ demo_llm.sh does not reference rollback.sh"
    fi

    # Check for SLO gate pattern
    if grep -qi -E "(slo|gate)" "./scripts/demo_llm.sh"; then
        integration_points+=("slo_gate_pattern")
        log_info "✅ SLO gate pattern found in demo_llm.sh"
    else
        log_warn "⚠️ No SLO gate pattern found in demo_llm.sh"
    fi

    # Create integration test results
    cat > "$EVIDENCE_DIR/integration-test-results.json" <<EOF
{
  "integration_test": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "demo_llm_exists": true,
    "integration_points": $(printf '%s\n' "${integration_points[@]}" | jq -R . | jq -s .),
    "integration_count": ${#integration_points[@]}
  }
}
EOF

    log_info "Integration test completed with ${#integration_points[@]} integration points"
}

# Test configuration validation
test_configuration_validation() {
    log_info "Testing configuration validation"

    local config_tests=()

    # Test SLO configuration loading
    if [[ -f "./config/slo-thresholds.yaml" ]]; then
        config_tests+=("slo_config_exists")
        log_info "✅ SLO configuration file exists"

        if command -v yq &>/dev/null; then
            if yq eval '.slo_config.thresholds.latency.p95_ms' "./config/slo-thresholds.yaml" &>/dev/null; then
                config_tests+=("slo_config_valid")
                log_info "✅ SLO configuration is valid YAML"
            else
                log_warn "⚠️ SLO configuration has invalid structure"
            fi
        else
            log_warn "⚠️ yq not available for YAML validation"
        fi
    else
        log_warn "⚠️ SLO configuration file not found"
    fi

    # Test rollback configuration loading
    if [[ -f "./config/rollback.conf" ]]; then
        config_tests+=("rollback_config_exists")
        log_info "✅ Rollback configuration file exists"

        # Test loading the config
        if source "./config/rollback.conf" 2>/dev/null; then
            config_tests+=("rollback_config_loadable")
            log_info "✅ Rollback configuration is loadable"
        else
            log_warn "⚠️ Rollback configuration has syntax errors"
        fi
    else
        log_warn "⚠️ Rollback configuration file not found"
    fi

    # Create configuration test results
    cat > "$EVIDENCE_DIR/configuration-test-results.json" <<EOF
{
  "configuration_test": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "config_tests": $(printf '%s\n' "${config_tests[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]'),
    "tests_passed": ${#config_tests[@]}
  }
}
EOF

    log_info "Configuration validation completed with ${#config_tests[@]} tests passed"
}

# Generate comprehensive test report
generate_test_report() {
    log_info "Generating comprehensive test report"

    local end_time=$(date +%s)
    local start_time_file="$TEST_REPORTS_DIR/.start_time"
    local start_time=$end_time

    if [[ -f "$start_time_file" ]]; then
        start_time=$(cat "$start_time_file")
    fi

    local duration=$((end_time - start_time))

    # Collect all test results
    local test_results=()

    if [[ -f "$EVIDENCE_DIR/postcheck-test-results.json" ]]; then
        test_results+=("$(cat "$EVIDENCE_DIR/postcheck-test-results.json")")
    fi

    if [[ -f "$EVIDENCE_DIR/rollback-test-results.json" ]]; then
        test_results+=("$(cat "$EVIDENCE_DIR/rollback-test-results.json")")
    fi

    if [[ -f "$EVIDENCE_DIR/integration-test-results.json" ]]; then
        test_results+=("$(cat "$EVIDENCE_DIR/integration-test-results.json")")
    fi

    if [[ -f "$EVIDENCE_DIR/configuration-test-results.json" ]]; then
        test_results+=("$(cat "$EVIDENCE_DIR/configuration-test-results.json")")
    fi

    # Generate master test report
    local test_report=$(jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
        --arg execution_id "$EXECUTION_ID" \
        --arg test_mode "$TEST_MODE" \
        --arg duration "$duration" \
        --argjson test_results "$(printf '%s\n' "${test_results[@]}" | jq -s . 2>/dev/null || echo '[]')" \
        '{
            test_execution: {
                timestamp: $timestamp,
                execution_id: $execution_id,
                test_mode: $test_mode,
                duration_seconds: ($duration | tonumber),
                script_version: "'"$SCRIPT_VERSION"'"
            },
            environment: {
                target_site: "'"$TARGET_SITE"'",
                dry_run: "'"$DRY_RUN"'",
                simulate_failure: "'"$SIMULATE_FAILURE"'"
            },
            results: $test_results,
            evidence: {
                test_reports_dir: "'"$TEST_REPORTS_DIR"'",
                evidence_dir: "'"$EVIDENCE_DIR"'",
                artifacts_dir: "'"$ARTIFACTS_DIR"'"
            }
        }')

    # Save test report
    echo "$test_report" | jq . > "$TEST_REPORTS_DIR/integration-test-report.json"

    # Generate checksums
    if command -v sha256sum &> /dev/null; then
        find "$TEST_REPORTS_DIR" -type f -name "*.json" -exec sha256sum {} \; > "$TEST_REPORTS_DIR/checksums.sha256"
    fi

    # Create summary
    cat > "$TEST_REPORTS_DIR/test-summary.txt" <<EOF
=== SLO Integration Test Summary ===

Execution ID: $EXECUTION_ID
Test Mode: $TEST_MODE
Duration: ${duration}s
Target Site: $TARGET_SITE
Dry Run: $DRY_RUN
Simulate Failure: $SIMULATE_FAILURE

Test Results:
$(echo "$test_report" | jq -r '.results[] | keys[]' 2>/dev/null | sort | uniq -c | awk '{print "- " $2 ": " $1 " test(s)"}' || echo "- No test results available")

Report Location: $TEST_REPORTS_DIR/integration-test-report.json
Evidence Location: $EVIDENCE_DIR

Test completed at: $(date)
EOF

    log_info "✅ Test report generated: $TEST_REPORTS_DIR/integration-test-report.json"
    log_info "📊 Summary: $TEST_REPORTS_DIR/test-summary.txt"
}

# Main test execution
main() {
    local start_time=$(date +%s)

    log_info "🧪 Starting SLO integration tests"
    log_info "📋 Execution ID: $EXECUTION_ID"
    log_info "🔧 Test mode: $TEST_MODE"
    log_info "🎯 Target site: $TARGET_SITE"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🧪 DRY-RUN MODE enabled"
    fi

    if [[ "$SIMULATE_FAILURE" == "true" ]]; then
        log_info "⚠️ FAILURE SIMULATION enabled"
    fi

    # Initialize test environment
    initialize_test_environment

    # Store start time after directory creation
    echo "$start_time" > "$TEST_REPORTS_DIR/.start_time"

    case "$TEST_MODE" in
        "basic")
            test_configuration_validation
            ;;
        "comprehensive")
            test_configuration_validation
            test_postcheck_functionality
            test_rollback_functionality
            test_demo_llm_integration
            ;;
        "rollback-only")
            test_rollback_functionality
            ;;
        *)
            log_error "Unknown test mode: $TEST_MODE"
            exit 1
            ;;
    esac

    # Generate final report
    generate_test_report

    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))

    log_info "🎉 Integration tests completed successfully!"
    log_info "⏱️  Total execution time: ${total_time}s"
    log_info "📊 Report: $TEST_REPORTS_DIR/integration-test-report.json"

    # Show summary
    echo ""
    cat "$TEST_REPORTS_DIR/test-summary.txt"
}

# Parse command line arguments
show_help() {
    cat <<EOF
SLO Integration Test Script v$SCRIPT_VERSION

Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -h, --help              Show this help message
  --mode MODE            Test mode: basic|comprehensive|rollback-only (default: comprehensive)
  --target-site SITE     Target site: edge1|edge2|both (default: edge1)
  --dry-run              Enable dry-run mode (default: true)
  --simulate-failure     Simulate SLO failure (default: false)

Environment Variables:
  TEST_MODE              Test mode override
  TARGET_SITE           Target site override
  DRY_RUN               Enable dry-run mode
  SIMULATE_FAILURE      Simulate failure conditions
  VM2_IP                Edge1 site IP
  VM4_IP                Edge2 site IP

Examples:
  $SCRIPT_NAME                                   # Comprehensive test
  $SCRIPT_NAME --mode basic                      # Basic configuration test
  $SCRIPT_NAME --simulate-failure               # Test with simulated failure
  TARGET_SITE=both $SCRIPT_NAME                 # Test both sites

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --mode)
            TEST_MODE="$2"
            shift 2
            ;;
        --target-site)
            TARGET_SITE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --simulate-failure)
            SIMULATE_FAILURE="true"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute main function
main