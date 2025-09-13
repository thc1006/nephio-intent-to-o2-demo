#!/bin/bash
#
# Test multi-site routing functionality
# Tests demo_llm.sh and render_krm.sh for correct site targeting
#

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source scripts to test
DEMO_LLM_SCRIPT="$PROJECT_ROOT/scripts/demo_llm.sh"
RENDER_KRM_SCRIPT="$PROJECT_ROOT/scripts/render_krm.sh"

# Test configuration
TEST_ARTIFACTS_DIR="/tmp/test-multisite-$$"
TEST_GITOPS_DIR="$TEST_ARTIFACTS_DIR/gitops"

# Mock intent files
MOCK_INTENT_EDGE1='
{
  "intentExpectationId": "test-edge1-001",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "edge1",
  "intent": {
    "serviceName": "test-service-edge1",
    "serviceType": "eMBB",
    "networkSlice": {
      "sliceId": "slice-edge1-001"
    },
    "qos": {
      "downlinkThroughput": "1Gbps",
      "uplinkThroughput": "100Mbps",
      "latency": "20ms"
    }
  }
}'

MOCK_INTENT_EDGE2='
{
  "intentExpectationId": "test-edge2-001",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "edge2",
  "intent": {
    "serviceName": "test-service-edge2",
    "serviceType": "URLLC",
    "networkSlice": {
      "sliceId": "slice-edge2-001"
    },
    "qos": {
      "downlinkThroughput": "500Mbps",
      "uplinkThroughput": "250Mbps",
      "latency": "1ms"
    }
  }
}'

MOCK_INTENT_BOTH='
{
  "intentExpectationId": "test-both-001",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "both",
  "intent": {
    "serviceName": "test-service-both",
    "serviceType": "mMTC",
    "networkSlice": {
      "sliceId": "slice-both-001"
    },
    "qos": {
      "downlinkThroughput": "100Mbps",
      "uplinkThroughput": "50Mbps",
      "latency": "100ms"
    }
  }
}'

# Setup function
oneTimeSetUp() {
    # Create test directories
    mkdir -p "$TEST_ARTIFACTS_DIR"
    mkdir -p "$TEST_GITOPS_DIR"

    # Create mock intent files
    echo "$MOCK_INTENT_EDGE1" > "$TEST_ARTIFACTS_DIR/intent-edge1.json"
    echo "$MOCK_INTENT_EDGE2" > "$TEST_ARTIFACTS_DIR/intent-edge2.json"
    echo "$MOCK_INTENT_BOTH" > "$TEST_ARTIFACTS_DIR/intent-both.json"

    # Export test environment variables
    export GITOPS_BASE_DIR="$TEST_GITOPS_DIR"
    export DRY_RUN="true"
    export ARTIFACTS_DIR="$TEST_ARTIFACTS_DIR"
}

# Teardown function
oneTimeTearDown() {
    # Clean up test artifacts
    rm -rf "$TEST_ARTIFACTS_DIR"

    # Unset test environment variables
    unset GITOPS_BASE_DIR
    unset DRY_RUN
    unset ARTIFACTS_DIR
}

# Test: GitOps directory structure creation
test_gitops_directory_structure() {
    # Verify gitops directories were created by demo_llm.sh
    local expected_dirs=(
        "$PROJECT_ROOT/gitops/edge1-config"
        "$PROJECT_ROOT/gitops/edge1-config/services"
        "$PROJECT_ROOT/gitops/edge1-config/network-functions"
        "$PROJECT_ROOT/gitops/edge1-config/monitoring"
        "$PROJECT_ROOT/gitops/edge1-config/baseline"
        "$PROJECT_ROOT/gitops/edge2-config"
        "$PROJECT_ROOT/gitops/edge2-config/services"
        "$PROJECT_ROOT/gitops/edge2-config/network-functions"
        "$PROJECT_ROOT/gitops/edge2-config/monitoring"
        "$PROJECT_ROOT/gitops/edge2-config/baseline"
    )

    for dir in "${expected_dirs[@]}"; do
        assertTrue "Directory should exist: $dir" "[ -d '$dir' ]"
    done
}

# Test: Baseline files exist
test_baseline_files_exist() {
    local baseline_files=(
        "$PROJECT_ROOT/gitops/edge1-config/baseline/namespace.yaml"
        "$PROJECT_ROOT/gitops/edge1-config/baseline/sample-service.yaml"
        "$PROJECT_ROOT/gitops/edge2-config/baseline/namespace.yaml"
        "$PROJECT_ROOT/gitops/edge2-config/baseline/sample-service.yaml"
    )

    for file in "${baseline_files[@]}"; do
        assertTrue "Baseline file should exist: $file" "[ -f '$file' ]"
    done
}

# Test: render_krm.sh routes to edge1 correctly
test_render_krm_edge1_routing() {
    # Run render_krm.sh for edge1
    local output
    output=$("$RENDER_KRM_SCRIPT" \
        --intent "$TEST_ARTIFACTS_DIR/intent-edge1.json" \
        --output-dir "$TEST_GITOPS_DIR" \
        --dry-run 2>&1)

    # Check that edge1-config is mentioned in output
    echo "$output" | grep -q "edge1-config"
    assertEquals "render_krm.sh should route to edge1-config" 0 $?

    # Check that edge2-config is NOT mentioned
    echo "$output" | grep -q "edge2-config"
    assertNotEquals "render_krm.sh should not route to edge2-config for edge1 target" 0 $?
}

# Test: render_krm.sh routes to edge2 correctly
test_render_krm_edge2_routing() {
    # Run render_krm.sh for edge2
    local output
    output=$("$RENDER_KRM_SCRIPT" \
        --intent "$TEST_ARTIFACTS_DIR/intent-edge2.json" \
        --output-dir "$TEST_GITOPS_DIR" \
        --dry-run 2>&1)

    # Check that edge2-config is mentioned in output
    echo "$output" | grep -q "edge2-config"
    assertEquals "render_krm.sh should route to edge2-config" 0 $?

    # Check that only edge2 is targeted (not edge1)
    echo "$output" | grep -q "Rendering for site: edge2"
    assertEquals "Should be rendering for edge2" 0 $?
}

# Test: render_krm.sh routes to both sites correctly
test_render_krm_both_routing() {
    # Run render_krm.sh for both
    local output
    output=$("$RENDER_KRM_SCRIPT" \
        --intent "$TEST_ARTIFACTS_DIR/intent-both.json" \
        --output-dir "$TEST_GITOPS_DIR" \
        --dry-run 2>&1)

    # Check that both edge1-config and edge2-config are mentioned
    echo "$output" | grep -q "edge1-config"
    assertEquals "render_krm.sh should route to edge1-config for 'both'" 0 $?

    echo "$output" | grep -q "edge2-config"
    assertEquals "render_krm.sh should route to edge2-config for 'both'" 0 $?

    echo "$output" | grep -q "Rendering for both edge1 and edge2"
    assertEquals "Should explicitly state rendering for both sites" 0 $?
}

# Test: demo_llm.sh validates target parameter
test_demo_llm_target_validation() {
    # Test valid targets
    for target in edge1 edge2 both; do
        "$DEMO_LLM_SCRIPT" --target "$target" --dry-run 2>&1 | grep -q "Valid target site: $target"
        assertEquals "Should accept valid target: $target" 0 $?
    done

    # Test invalid target
    local output
    output=$("$DEMO_LLM_SCRIPT" --target "invalid" --dry-run 2>&1 || true)
    echo "$output" | grep -q "Invalid target site"
    assertEquals "Should reject invalid target" 0 $?
}

# Test: Intent file with targetSite field
test_intent_targetsite_field() {
    # Create test intent files and verify targetSite is preserved
    for site in edge1 edge2 both; do
        local test_file="$TEST_ARTIFACTS_DIR/intent-$site.json"
        local target_site
        target_site=$(jq -r '.targetSite' "$test_file")
        assertEquals "Intent should have targetSite=$site" "$site" "$target_site"
    done
}

# Test: KRM output contains correct site labels
test_krm_site_labels() {
    # Create actual KRM files (not dry-run) for testing
    "$RENDER_KRM_SCRIPT" \
        --intent "$TEST_ARTIFACTS_DIR/intent-edge1.json" \
        --output-dir "$TEST_GITOPS_DIR" \
        --force 2>/dev/null

    # Find generated YAML files
    local krm_files
    krm_files=$(find "$TEST_GITOPS_DIR/edge1-config" -name "*.yaml" -type f 2>/dev/null | head -1)

    if [[ -n "$krm_files" ]]; then
        # Check for target-site label
        grep -q "target-site: edge1" "$krm_files"
        assertEquals "KRM should have target-site: edge1 label" 0 $?
    fi
}

# Test: Multi-site deployment simulation
test_multisite_deployment_simulation() {
    # Test that demo_llm.sh properly handles multi-site deployment
    export VM4_IP="172.16.5.45"  # Mock edge2 IP

    # Run with both target
    local output
    output=$("$DEMO_LLM_SCRIPT" --target both --dry-run 2>&1)

    # Should mention both edge1 and edge2 deployment
    echo "$output" | grep -q "edge1"
    assertEquals "Should deploy to edge1" 0 $?

    echo "$output" | grep -q "edge2"
    assertEquals "Should deploy to edge2" 0 $?

    unset VM4_IP
}

# Test: Rollback target routing
test_rollback_routing() {
    # Test rollback with specific targets
    for target in edge1 edge2 both; do
        local output
        output=$("$DEMO_LLM_SCRIPT" --rollback --target "$target" --dry-run 2>&1 || true)
        echo "$output" | grep -q "rollback for target: $target"
        assertEquals "Rollback should target: $target" 0 $?
    done
}

# Test: GitOps path resolution
test_gitops_path_resolution() {
    # Test that paths are correctly resolved
    local edge1_path="$TEST_GITOPS_DIR/edge1-config"
    local edge2_path="$TEST_GITOPS_DIR/edge2-config"

    # Create directories
    mkdir -p "$edge1_path/services"
    mkdir -p "$edge2_path/services"

    # Run render_krm and check output paths
    "$RENDER_KRM_SCRIPT" \
        --intent "$TEST_ARTIFACTS_DIR/intent-edge1.json" \
        --output-dir "$TEST_GITOPS_DIR" \
        --force 2>&1 | grep -q "$edge1_path"
    assertEquals "Should use edge1 path" 0 $?
}

# Test: Concurrent multi-site rendering
test_concurrent_multisite_rendering() {
    # Test that both sites can be rendered concurrently
    "$RENDER_KRM_SCRIPT" \
        --intent "$TEST_ARTIFACTS_DIR/intent-both.json" \
        --output-dir "$TEST_GITOPS_DIR" \
        --force 2>/dev/null

    # Check both directories have files
    local edge1_files edge2_files
    edge1_files=$(find "$TEST_GITOPS_DIR/edge1-config/services" -name "*.yaml" 2>/dev/null | wc -l)
    edge2_files=$(find "$TEST_GITOPS_DIR/edge2-config/services" -name "*.yaml" 2>/dev/null | wc -l)

    assertTrue "Edge1 should have rendered files" "[ $edge1_files -gt 0 ]"
    assertTrue "Edge2 should have rendered files" "[ $edge2_files -gt 0 ]"
}

# Test: Site-specific service types
test_site_specific_service_types() {
    # Edge1 should have eMBB service
    local edge1_intent edge1_service_type
    edge1_intent="$TEST_ARTIFACTS_DIR/intent-edge1.json"
    edge1_service_type=$(jq -r '.intent.serviceType' "$edge1_intent")
    assertEquals "Edge1 should have eMBB service" "eMBB" "$edge1_service_type"

    # Edge2 should have URLLC service
    local edge2_intent edge2_service_type
    edge2_intent="$TEST_ARTIFACTS_DIR/intent-edge2.json"
    edge2_service_type=$(jq -r '.intent.serviceType' "$edge2_intent")
    assertEquals "Edge2 should have URLLC service" "URLLC" "$edge2_service_type"

    # Both should have mMTC service
    local both_intent both_service_type
    both_intent="$TEST_ARTIFACTS_DIR/intent-both.json"
    both_service_type=$(jq -r '.intent.serviceType' "$both_intent")
    assertEquals "Both sites should have mMTC service" "mMTC" "$both_service_type"
}

# Test: RootSync configuration files
test_rootsync_configuration() {
    # Check RootSync files exist
    assertTrue "Edge1 RootSync should exist" \
        "[ -f '$PROJECT_ROOT/gitops/edge1-config/rootsync.yaml' ]"
    assertTrue "Edge2 RootSync should exist" \
        "[ -f '$PROJECT_ROOT/gitops/edge2-config/rootsync.yaml' ]"

    # Check edge1 RootSync has correct IP
    grep -q "172.16.4.45" "$PROJECT_ROOT/gitops/edge1-config/rootsync.yaml"
    assertEquals "Edge1 RootSync should have correct IP" 0 $?

    # Check edge2 RootSync has TBD placeholder
    grep -q "TBD" "$PROJECT_ROOT/gitops/edge2-config/rootsync.yaml"
    assertEquals "Edge2 RootSync should have TBD placeholder" 0 $?
}

# Load shunit2
if [[ -f /tmp/shunit2 ]]; then
    . /tmp/shunit2
elif [[ -f ./shunit2 ]]; then
    . ./shunit2
else
    echo "shunit2 not found. Please install it."
    exit 1
fi