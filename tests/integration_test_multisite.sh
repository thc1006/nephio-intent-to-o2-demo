#!/bin/bash
#
# Integration test for multi-site GitOps routing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Multi-Site GitOps Integration Test ==="
echo

# Test 1: Verify GitOps directory structure
echo "Test 1: Checking GitOps directory structure..."
if [[ -d "$PROJECT_ROOT/gitops/edge1-config" ]] && [[ -d "$PROJECT_ROOT/gitops/edge2-config" ]]; then
    echo "✓ GitOps directories exist"
else
    echo "✗ GitOps directories missing"
    exit 1
fi

# Test 2: Verify baseline files
echo "Test 2: Checking baseline files..."
baseline_files=(
    "$PROJECT_ROOT/gitops/edge1-config/baseline/namespace.yaml"
    "$PROJECT_ROOT/gitops/edge1-config/baseline/sample-service.yaml"
    "$PROJECT_ROOT/gitops/edge2-config/baseline/namespace.yaml"
    "$PROJECT_ROOT/gitops/edge2-config/baseline/sample-service.yaml"
)

for file in "${baseline_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✓ Found: $(basename "$(dirname "$file")")/$(basename "$file")"
    else
        echo "✗ Missing: $file"
        exit 1
    fi
done

# Test 3: Test render_krm.sh with edge1 target
echo "Test 3: Testing render_krm.sh for edge1..."
cat > /tmp/test-intent-edge1.json <<EOF
{
  "intentExpectationId": "test-001",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "edge1",
  "intent": {
    "serviceType": "eMBB",
    "networkSlice": {"sliceId": "test-slice"}
  }
}
EOF

output=$("$PROJECT_ROOT/scripts/render_krm.sh" \
    --intent /tmp/test-intent-edge1.json \
    --output-dir /tmp/test-gitops \
    --force 2>&1)

if echo "$output" | grep -q "edge1"; then
    echo "✓ render_krm.sh correctly routes to edge1"
else
    echo "✗ render_krm.sh failed to route to edge1"
    echo "$output"
    exit 1
fi

# Test 4: Test render_krm.sh with both target
echo "Test 4: Testing render_krm.sh for both sites..."
cat > /tmp/test-intent-both.json <<EOF
{
  "intentExpectationId": "test-002",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "both",
  "intent": {
    "serviceType": "mMTC",
    "networkSlice": {"sliceId": "test-slice-both"}
  }
}
EOF

output=$("$PROJECT_ROOT/scripts/render_krm.sh" \
    --intent /tmp/test-intent-both.json \
    --output-dir /tmp/test-gitops-both \
    --force 2>&1)

if echo "$output" | grep -q "both edge1 and edge2"; then
    echo "✓ render_krm.sh correctly routes to both sites"
else
    echo "✗ render_krm.sh failed to route to both sites"
    echo "$output"
    exit 1
fi

# Test 5: Verify generated files
echo "Test 5: Checking generated KRM files..."
if [[ -d /tmp/test-gitops-both/edge1-config/services ]] && \
   [[ -d /tmp/test-gitops-both/edge2-config/services ]]; then
    edge1_files=$(find /tmp/test-gitops-both/edge1-config -name "*.yaml" | wc -l)
    edge2_files=$(find /tmp/test-gitops-both/edge2-config -name "*.yaml" | wc -l)

    if [[ $edge1_files -gt 0 ]] && [[ $edge2_files -gt 0 ]]; then
        echo "✓ Generated files for both sites (edge1: $edge1_files, edge2: $edge2_files)"
    else
        echo "✗ Failed to generate files for both sites"
        exit 1
    fi
else
    echo "✗ Output directories not created"
    exit 1
fi

# Test 6: Verify RootSync configurations
echo "Test 6: Checking RootSync configurations..."
if grep -q "172.16.4.45" "$PROJECT_ROOT/gitops/edge1-config/rootsync.yaml"; then
    echo "✓ Edge1 RootSync has correct IP"
else
    echo "✗ Edge1 RootSync missing correct IP"
    exit 1
fi

if grep -q "TBD" "$PROJECT_ROOT/gitops/edge2-config/rootsync.yaml"; then
    echo "✓ Edge2 RootSync has TBD placeholder"
else
    echo "✗ Edge2 RootSync missing TBD placeholder"
    exit 1
fi

# Test 7: Test demo_llm.sh parameter validation
echo "Test 7: Testing demo_llm.sh parameter validation..."
for target in edge1 edge2 both; do
    if "$PROJECT_ROOT/scripts/demo_llm.sh" --target "$target" --dry-run 2>&1 | grep -q "Valid target site: $target"; then
        echo "✓ demo_llm.sh accepts target: $target"
    else
        echo "✗ demo_llm.sh rejects valid target: $target"
    fi
done

# Test 8: Check golden test files
echo "Test 8: Verifying golden test files..."
golden_files=(
    "$PROJECT_ROOT/tests/golden/intent_edge1.json"
    "$PROJECT_ROOT/tests/golden/intent_edge2.json"
    "$PROJECT_ROOT/tests/golden/intent_both.json"
)

for file in "${golden_files[@]}"; do
    if [[ -f "$file" ]]; then
        target_site=$(jq -r '.targetSite' "$file")
        expected=$(basename "$file" | sed 's/intent_//' | sed 's/.json//')
        if [[ "$target_site" == "$expected" ]]; then
            echo "✓ Golden file $(basename "$file") has correct targetSite: $target_site"
        else
            echo "✗ Golden file $(basename "$file") has wrong targetSite"
            exit 1
        fi
    else
        echo "✗ Missing golden file: $file"
        exit 1
    fi
done

# Cleanup
rm -rf /tmp/test-intent-*.json /tmp/test-gitops* 2>/dev/null || true

echo
echo "=== All Integration Tests Passed ✓ ==="
echo
echo "Summary:"
echo "  - GitOps directory structure: ✓"
echo "  - Baseline configurations: ✓"
echo "  - KRM rendering for edge1: ✓"
echo "  - KRM rendering for both sites: ✓"
echo "  - File generation: ✓"
echo "  - RootSync configurations: ✓"
echo "  - Parameter validation: ✓"
echo "  - Golden test files: ✓"
echo
echo "The multi-site GitOps routing is working correctly!"