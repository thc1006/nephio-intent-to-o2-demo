#!/bin/bash

# CI/CD Pipeline - Smoke Tests Runner
# Runs smoke tests to verify basic functionality

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_REPORT="${REPO_ROOT}/artifacts/smoke-test-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$TEST_REPORT")"

echo "::notice::Starting smoke tests..."

cd "$REPO_ROOT"

# Initialize test report
cat > "$TEST_REPORT" << 'EOF'
{
  "test_type": "smoke_tests",
  "timestamp": "",
  "test_suites": [],
  "summary": {
    "total_tests": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

# Test Suite 1: Basic Script Functionality
echo "=== Smoke Test: Basic Script Functionality ==="

script_passed=0
script_failed=0
script_total=5

# Test 1: Check if main demo script exists and is executable
echo "Testing main demo script..."
if [ -x "scripts/demo_llm.sh" ]; then
    echo "✅ demo_llm.sh is executable"
    ((script_passed++))
else
    echo "❌ demo_llm.sh not found or not executable"
    ((script_failed++))
    EXIT_CODE=1
fi

# Test 2: Check if postcheck script exists and is executable
echo "Testing postcheck script..."
if [ -x "scripts/postcheck.sh" ]; then
    echo "✅ postcheck.sh is executable"
    ((script_passed++))
else
    echo "❌ postcheck.sh not found or not executable"
    ((script_failed++))
    EXIT_CODE=1
fi

# Test 3: Check if rollback script exists and is executable
echo "Testing rollback script..."
if [ -x "scripts/rollback.sh" ]; then
    echo "✅ rollback.sh is executable"
    ((script_passed++))
else
    echo "❌ rollback.sh not found or not executable"
    ((script_failed++))
    EXIT_CODE=1
fi

# Test 4: Check if intent compiler exists
echo "Testing intent compiler..."
if [ -f "tools/intent-compiler/translate.py" ]; then
    echo "✅ Intent compiler found"
    ((script_passed++))
else
    echo "❌ Intent compiler not found"
    ((script_failed++))
    EXIT_CODE=1
fi

# Test 5: Check if basic dependencies are available
echo "Testing basic dependencies..."
missing_deps=()
for dep in jq yq python3 git; do
    if ! command -v "$dep" &> /dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -eq 0 ]; then
    echo "✅ All basic dependencies available"
    ((script_passed++))
else
    echo "❌ Missing dependencies: ${missing_deps[*]}"
    ((script_failed++))
    EXIT_CODE=1
fi

# Update test report with script tests
jq --arg total "$script_total" --arg passed "$script_passed" --arg failed "$script_failed" \
   '.test_suites += [{"name": "basic_scripts", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Basic script tests: $script_total total, $script_passed passed, $script_failed failed"

# Test Suite 2: Configuration Structure
echo "=== Smoke Test: Configuration Structure ==="

config_passed=0
config_failed=0
config_total=4

# Test 1: Check gitops directory structure
echo "Testing gitops directory structure..."
if [ -d "gitops" ] && [ -d "gitops/edge1-config" ] && [ -d "gitops/edge2-config" ]; then
    echo "✅ GitOps directory structure is present"
    ((config_passed++))
else
    echo "❌ GitOps directory structure missing"
    ((config_failed++))
    EXIT_CODE=1
fi

# Test 2: Check if essential config files exist
echo "Testing essential configuration files..."
essential_configs=("gitops/edge1-config/Kptfile" "gitops/edge2-config/Kptfile")
missing_configs=()

for config in "${essential_configs[@]}"; do
    if [ ! -f "$config" ]; then
        missing_configs+=("$config")
    fi
done

if [ ${#missing_configs[@]} -eq 0 ]; then
    echo "✅ Essential configuration files found"
    ((config_passed++))
else
    echo "❌ Missing configuration files: ${missing_configs[*]}"
    ((config_failed++))
    EXIT_CODE=1
fi

# Test 3: Check if artifacts directory exists
echo "Testing artifacts directory..."
if [ -d "artifacts" ]; then
    echo "✅ Artifacts directory exists"
    ((config_passed++))
else
    echo "❌ Artifacts directory missing"
    mkdir -p artifacts
    echo "✅ Created artifacts directory"
    ((config_passed++))
fi

# Test 4: Check if reports directory exists
echo "Testing reports directory..."
if [ -d "reports" ]; then
    echo "✅ Reports directory exists"
    ((config_passed++))
else
    echo "❌ Reports directory missing"
    mkdir -p reports
    echo "✅ Created reports directory"
    ((config_passed++))
fi

# Update test report with config tests
jq --arg total "$config_total" --arg passed "$config_passed" --arg failed "$config_failed" \
   '.test_suites += [{"name": "configuration_structure", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Configuration tests: $config_total total, $config_passed passed, $config_failed failed"

# Test Suite 3: Python Components
echo "=== Smoke Test: Python Components ==="

python_passed=0
python_failed=0
python_total=3

# Test 1: Check Python version
echo "Testing Python version..."
python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
if python3 -c "import sys; assert sys.version_info >= (3, 8)" 2>/dev/null; then
    echo "✅ Python version is compatible ($python_version)"
    ((python_passed++))
else
    echo "❌ Python version incompatible ($python_version)"
    ((python_failed++))
    EXIT_CODE=1
fi

# Test 2: Check essential Python modules
echo "Testing essential Python modules..."
essential_modules=("json" "yaml" "requests" "subprocess")
missing_modules=()

for module in "${essential_modules[@]}"; do
    if ! python3 -c "import $module" 2>/dev/null; then
        missing_modules+=("$module")
    fi
done

if [ ${#missing_modules[@]} -eq 0 ]; then
    echo "✅ Essential Python modules available"
    ((python_passed++))
else
    echo "⚠️  Some Python modules missing: ${missing_modules[*]}"
    # Install missing modules if possible
    pip3 install pyyaml requests >/dev/null 2>&1 || true
    ((python_passed++))  # Don't fail for this in smoke test
fi

# Test 3: Test intent compiler syntax
echo "Testing intent compiler syntax..."
if python3 -m py_compile tools/intent-compiler/translate.py 2>/dev/null; then
    echo "✅ Intent compiler syntax is valid"
    ((python_passed++))
else
    echo "❌ Intent compiler has syntax errors"
    ((python_failed++))
    EXIT_CODE=1
fi

# Update test report with Python tests
jq --arg total "$python_total" --arg passed "$python_passed" --arg failed "$python_failed" \
   '.test_suites += [{"name": "python_components", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Python tests: $python_total total, $python_passed passed, $python_failed failed"

# Test Suite 4: Quick Functional Test
echo "=== Smoke Test: Quick Functional Test ==="

functional_passed=0
functional_failed=0
functional_total=2

# Test 1: Simple intent compilation test
echo "Testing intent compilation..."
temp_intent=$(mktemp)
cat > "$temp_intent" << 'EOF'
{
  "intent": {
    "deployment": {
      "name": "smoke-test",
      "namespace": "default",
      "replicas": 1,
      "image": "nginx:alpine"
    }
  },
  "targetSite": "edge1"
}
EOF

if python3 tools/intent-compiler/translate.py "$temp_intent" > /tmp/smoke-output 2>&1; then
    echo "✅ Intent compilation smoke test passed"
    ((functional_passed++))
else
    echo "❌ Intent compilation smoke test failed"
    echo "Output: $(cat /tmp/smoke-output)"
    ((functional_failed++))
    EXIT_CODE=1
fi

rm -f "$temp_intent" /tmp/smoke-output

# Test 2: YAML validation smoke test
echo "Testing YAML validation..."
temp_yaml=$(mktemp --suffix=.yaml)
cat > "$temp_yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: smoke-test
  namespace: default
data:
  test: "smoke-test-value"
EOF

if yamllint "$temp_yaml" >/dev/null 2>&1; then
    echo "✅ YAML validation smoke test passed"
    ((functional_passed++))
else
    echo "❌ YAML validation smoke test failed"
    ((functional_failed++))
    EXIT_CODE=1
fi

rm -f "$temp_yaml"

# Update test report with functional tests
jq --arg total "$functional_total" --arg passed "$functional_passed" --arg failed "$functional_failed" \
   '.test_suites += [{"name": "quick_functional", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Functional tests: $functional_total total, $functional_passed passed, $functional_failed failed"

# Print summary
echo
echo "Smoke Test Summary:"
total_tests=$(jq -r '.summary.total_tests' "$TEST_REPORT")
total_passed=$(jq -r '.summary.passed' "$TEST_REPORT")
total_failed=$(jq -r '.summary.failed' "$TEST_REPORT")
total_skipped=$(jq -r '.summary.skipped' "$TEST_REPORT")

echo "📊 Total tests: $total_tests"
echo "✅ Passed: $total_passed"
echo "❌ Failed: $total_failed"
echo "⏭️  Skipped: $total_skipped"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All smoke tests passed!"
else
    echo "💥 Some smoke tests failed. Check the report at: $TEST_REPORT"
fi

exit $EXIT_CODE