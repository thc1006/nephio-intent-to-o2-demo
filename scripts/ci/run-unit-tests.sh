#!/bin/bash

# CI/CD Pipeline - Unit Tests Runner
# Runs unit tests for the project components

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_REPORT="${REPO_ROOT}/artifacts/unit-test-report.json"
COVERAGE_REPORT="${REPO_ROOT}/artifacts/coverage-report.xml"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$TEST_REPORT")"

echo "::notice::Starting unit tests..."

cd "$REPO_ROOT"

# Initialize test report
cat > "$TEST_REPORT" << 'EOF'
{
  "test_type": "unit_tests",
  "timestamp": "",
  "test_suites": [],
  "summary": {
    "total_tests": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0,
    "coverage_percentage": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

# Run Python unit tests
echo "=== Running Python Unit Tests ==="

if [ -f "requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip install -r requirements.txt
fi

# Install test dependencies
pip install pytest pytest-cov pytest-xvs pytest-json-report

# Run pytest with coverage
if pytest_output=$(pytest \
    --cov=. \
    --cov-report=xml:$COVERAGE_REPORT \
    --cov-report=term-missing \
    --json-report \
    --json-report-file=pytest-report.json \
    tests/ \
    -v 2>&1); then

    echo "✅ Python unit tests passed"

    # Parse pytest results
    if [ -f "pytest-report.json" ]; then
        python3 << 'EOF'
import json
import sys

# Load pytest report
with open('pytest-report.json', 'r') as f:
    pytest_data = json.load(f)

# Load main test report
with open('artifacts/unit-test-report.json', 'r') as f:
    main_report = json.load(f)

# Update main report with pytest data
main_report['test_suites'].append({
    "name": "python_unit_tests",
    "tests": pytest_data['summary']['total'],
    "passed": pytest_data['summary']['passed'],
    "failed": pytest_data['summary']['failed'],
    "skipped": pytest_data['summary']['skipped'],
    "duration": pytest_data['duration']
})

# Update summary
main_report['summary']['total_tests'] += pytest_data['summary']['total']
main_report['summary']['passed'] += pytest_data['summary']['passed']
main_report['summary']['failed'] += pytest_data['summary']['failed']
main_report['summary']['skipped'] += pytest_data['summary']['skipped']

# Save updated report
with open('artifacts/unit-test-report.json', 'w') as f:
    json.dump(main_report, f, indent=2)
EOF
    fi
else
    echo "❌ Python unit tests failed"
    echo "$pytest_output"
    EXIT_CODE=1
fi

# Run shell script tests (if any)
echo "=== Running Shell Script Tests ==="

if [ -d "tests/shell" ]; then
    shell_tests_passed=0
    shell_tests_failed=0
    shell_tests_total=0

    for test_script in tests/shell/test_*.sh; do
        if [ -f "$test_script" ]; then
            ((shell_tests_total++))
            echo "Running $test_script..."

            if bash "$test_script"; then
                echo "✅ $test_script passed"
                ((shell_tests_passed++))
            else
                echo "❌ $test_script failed"
                ((shell_tests_failed++))
                EXIT_CODE=1
            fi
        fi
    done

    # Update test report with shell tests
    jq --arg total "$shell_tests_total" --arg passed "$shell_tests_passed" --arg failed "$shell_tests_failed" \
       '.test_suites += [{"name": "shell_tests", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
        .summary.total_tests += ($total | tonumber) |
        .summary.passed += ($passed | tonumber) |
        .summary.failed += ($failed | tonumber)' \
       "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

    echo "Shell tests: $shell_tests_total total, $shell_tests_passed passed, $shell_tests_failed failed"
fi

# Run KPT function tests
echo "=== Running KPT Function Tests ==="

if [ -d "kpt-functions" ]; then
    kpt_tests_passed=0
    kpt_tests_failed=0
    kpt_tests_total=0

    # Test each KPT function
    for func_dir in kpt-functions/*/; do
        if [ -d "$func_dir" ] && [ -f "$func_dir/Dockerfile" ]; then
            func_name=$(basename "$func_dir")
            ((kpt_tests_total++))

            echo "Testing KPT function: $func_name"

            # Test function build
            if docker build -t "test-$func_name" "$func_dir" >/dev/null 2>&1; then
                echo "✅ $func_name build succeeded"

                # Test function execution (if test data exists)
                if [ -f "$func_dir/test-input.yaml" ]; then
                    if docker run --rm -i "test-$func_name" < "$func_dir/test-input.yaml" >/dev/null 2>&1; then
                        echo "✅ $func_name execution test passed"
                        ((kpt_tests_passed++))
                    else
                        echo "❌ $func_name execution test failed"
                        ((kpt_tests_failed++))
                        EXIT_CODE=1
                    fi
                else
                    echo "⚠️  $func_name - no test input found, skipping execution test"
                    ((kpt_tests_passed++))
                fi

                # Cleanup test image
                docker rmi "test-$func_name" >/dev/null 2>&1 || true
            else
                echo "❌ $func_name build failed"
                ((kpt_tests_failed++))
                EXIT_CODE=1
            fi
        fi
    done

    # Update test report with KPT function tests
    jq --arg total "$kpt_tests_total" --arg passed "$kpt_tests_passed" --arg failed "$kpt_tests_failed" \
       '.test_suites += [{"name": "kpt_functions", "tests": ($total | tonumber), "passed": ($passed | tonumber), "failed": ($failed | tonumber), "skipped": 0}] |
        .summary.total_tests += ($total | tonumber) |
        .summary.passed += ($passed | tonumber) |
        .summary.failed += ($failed | tonumber)' \
       "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

    echo "KPT function tests: $kpt_tests_total total, $kpt_tests_passed passed, $kpt_tests_failed failed"
fi

# Extract coverage percentage if available
if [ -f "$COVERAGE_REPORT" ]; then
    coverage_pct=$(python3 << 'EOF'
import xml.etree.ElementTree as ET
import sys

try:
    tree = ET.parse('artifacts/coverage-report.xml')
    root = tree.getroot()
    coverage = root.get('line-rate', '0')
    print(f"{float(coverage) * 100:.1f}")
except Exception as e:
    print("0")
EOF
)

    # Update coverage in report
    jq --arg cov "$coverage_pct" '.summary.coverage_percentage = ($cov | tonumber)' \
       "$TEST_REPORT" > "${TEST_REPORT}.tmp" && mv "${TEST_REPORT}.tmp" "$TEST_REPORT"

    echo "Code coverage: $coverage_pct%"
fi

# Print summary
echo
echo "Unit Test Summary:"
total_tests=$(jq -r '.summary.total_tests' "$TEST_REPORT")
total_passed=$(jq -r '.summary.passed' "$TEST_REPORT")
total_failed=$(jq -r '.summary.failed' "$TEST_REPORT")
total_skipped=$(jq -r '.summary.skipped' "$TEST_REPORT")

echo "📊 Total tests: $total_tests"
echo "✅ Passed: $total_passed"
echo "❌ Failed: $total_failed"
echo "⏭️  Skipped: $total_skipped"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All unit tests passed!"
else
    echo "💥 Some unit tests failed. Check the report at: $TEST_REPORT"
fi

# Cleanup
rm -f pytest-report.json

exit $EXIT_CODE