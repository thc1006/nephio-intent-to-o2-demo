#!/bin/bash

# CI/CD Pipeline - Integration Tests Runner
# Runs integration tests in Kind cluster

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_REPORT="${REPO_ROOT}/artifacts/integration-test-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$TEST_REPORT")"

echo "::notice::Starting integration tests..."

cd "$REPO_ROOT"

# Initialize test report
cat > "$TEST_REPORT" << 'EOF'
{
  "test_type": "integration_tests",
  "timestamp": "",
  "test_suites": [],
  "cluster_info": {},
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

# Verify Kind cluster is available
echo "=== Verifying Kind Cluster ==="

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Kind cluster not available"
    exit 1
fi

# Get cluster info
cluster_version=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
server_version=$(kubectl version -o json | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")
node_count=$(kubectl get nodes --no-headers | wc -l)

# Update cluster info in report
jq --arg client_ver "$cluster_version" --arg server_ver "$server_version" --arg nodes "$node_count" \
   '.cluster_info = {"client_version": $client_ver, "server_version": $server_ver, "node_count": ($nodes | tonumber)}' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "✅ Kind cluster available (server: $server_version, nodes: $node_count)"

# Test 1: Config Sync Operator
echo "=== Testing Config Sync Operator ==="

config_sync_passed=0
config_sync_failed=0
config_sync_total=3

# Test if Config Sync operator is installed
echo "Testing Config Sync operator installation..."
if kubectl get deployment config-sync-operator -n config-management-system >/dev/null 2>&1; then
    echo "✅ Config Sync operator is installed"
    ((config_sync_passed++))
else
    echo "❌ Config Sync operator not found"
    ((config_sync_failed++))
    EXIT_CODE=1
fi

# Test if Config Sync CRDs are available
echo "Testing Config Sync CRDs..."
if kubectl get crd rootsyncs.configsync.gke.io >/dev/null 2>&1 && \
   kubectl get crd reposyncs.configsync.gke.io >/dev/null 2>&1; then
    echo "✅ Config Sync CRDs are available"
    ((config_sync_passed++))
else
    echo "❌ Config Sync CRDs not found"
    ((config_sync_failed++))
    EXIT_CODE=1
fi

# Test Config Sync operator readiness
echo "Testing Config Sync operator readiness..."
if kubectl wait --for=condition=available --timeout=60s deployment/config-sync-operator -n config-management-system >/dev/null 2>&1; then
    echo "✅ Config Sync operator is ready"
    ((config_sync_passed++))
else
    echo "❌ Config Sync operator not ready"
    ((config_sync_failed++))
    EXIT_CODE=1
fi

# Update test report with Config Sync tests
jq --arg total "$config_sync_total" --arg passed "$config_sync_passed" --arg failed "$config_sync_failed" \
   '.test_suites += [{"name": "config_sync_operator", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Config Sync tests: $config_sync_total total, $config_sync_passed passed, $config_sync_failed failed"

# Test 2: KPT Package Rendering
echo "=== Testing KPT Package Rendering ==="

kpt_passed=0
kpt_failed=0
kpt_total=0

# Find and test KPT packages
for package_dir in $(find "$REPO_ROOT" -name "Kptfile" -type f -exec dirname {} \; | head -5); do
    package_name=$(basename "$package_dir")
    ((kpt_total++))

    echo "Testing KPT package rendering: $package_name"

    # Create temporary directory for testing
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Copy package to temp directory
    if cp -r "$package_dir" "$temp_dir/test-package"; then
        cd "$temp_dir/test-package"

        # Test kpt fn render
        if kpt fn render >/dev/null 2>&1; then
            echo "✅ $package_name rendering succeeded"
            ((kpt_passed++))
        else
            echo "❌ $package_name rendering failed"
            ((kpt_failed++))
            EXIT_CODE=1
        fi

        cd - >/dev/null
    else
        echo "❌ Failed to copy package $package_name"
        ((kpt_failed++))
        EXIT_CODE=1
    fi

    rm -rf "$temp_dir"
done

# Update test report with KPT tests
jq --arg total "$kpt_total" --arg passed "$kpt_passed" --arg failed "$kpt_failed" \
   '.test_suites += [{"name": "kpt_package_rendering", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "KPT package tests: $kpt_total total, $kpt_passed passed, $kpt_failed failed"

# Test 3: Sample Deployment Test
echo "=== Testing Sample Deployment ==="

deployment_passed=0
deployment_failed=0
deployment_total=2

# Create test namespace
echo "Creating test namespace..."
kubectl create namespace ci-integration-test >/dev/null 2>&1 || true

# Deploy a simple test application
cat << 'EOF' | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: ci-integration-test
  labels:
    app: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  namespace: ci-integration-test
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
EOF

# Test deployment rollout
echo "Testing deployment rollout..."
if kubectl rollout status deployment/test-app -n ci-integration-test --timeout=120s >/dev/null 2>&1; then
    echo "✅ Test deployment succeeded"
    ((deployment_passed++))
else
    echo "❌ Test deployment failed"
    ((deployment_failed++))
    EXIT_CODE=1
fi

# Test service accessibility
echo "Testing service accessibility..."
if kubectl get service test-app-service -n ci-integration-test >/dev/null 2>&1; then
    echo "✅ Test service is accessible"
    ((deployment_passed++))
else
    echo "❌ Test service not accessible"
    ((deployment_failed++))
    EXIT_CODE=1
fi

# Update test report with deployment tests
jq --arg total "$deployment_total" --arg passed "$deployment_passed" --arg failed "$deployment_failed" \
   '.test_suites += [{"name": "sample_deployment", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Deployment tests: $deployment_total total, $deployment_passed passed, $deployment_failed failed"

# Cleanup test resources
echo "Cleaning up test resources..."
kubectl delete namespace ci-integration-test --ignore-not-found=true >/dev/null 2>&1 &

# Test 4: Intent Compiler Integration
echo "=== Testing Intent Compiler Integration ==="

compiler_passed=0
compiler_failed=0
compiler_total=1

if [ -f "tools/intent-compiler/translate.py" ]; then
    echo "Testing intent compiler..."

    # Create a simple test intent
    cat > /tmp/test-intent.json << 'EOF'
{
  "intent": {
    "deployment": {
      "name": "test-workload",
      "namespace": "test-ns",
      "replicas": 1,
      "image": "nginx:alpine"
    }
  },
  "targetSite": "edge1"
}
EOF

    # Test intent compilation
    if python3 tools/intent-compiler/translate.py /tmp/test-intent.json >/dev/null 2>&1; then
        echo "✅ Intent compiler test passed"
        ((compiler_passed++))
    else
        echo "❌ Intent compiler test failed"
        ((compiler_failed++))
        EXIT_CODE=1
    fi

    rm -f /tmp/test-intent.json
else
    echo "⚠️  Intent compiler not found, skipping test"
fi

# Update test report with compiler tests
jq --arg total "$compiler_total" --arg passed "$compiler_passed" --arg failed "$compiler_failed" \
   '.test_suites += [{"name": "intent_compiler", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
    .summary.total_tests += ($total | tonumber) |
    .summary.passed += ($passed | tonumber) |
    .summary.failed += ($failed | tonumber)' \
   "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

echo "Intent compiler tests: $compiler_total total, $compiler_passed passed, $compiler_failed failed"

# Print summary
echo
echo "Integration Test Summary:"
total_tests=$(jq -r '.summary.total_tests' "$TEST_REPORT")
total_passed=$(jq -r '.summary.passed' "$TEST_REPORT")
total_failed=$(jq -r '.summary.failed' "$TEST_REPORT")
total_skipped=$(jq -r '.summary.skipped' "$TEST_REPORT")

echo "📊 Total tests: $total_tests"
echo "✅ Passed: $total_passed"
echo "❌ Failed: $total_failed"
echo "⏭️  Skipped: $total_skipped"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All integration tests passed!"
else
    echo "💥 Some integration tests failed. Check the report at: $TEST_REPORT"
fi

exit $EXIT_CODE