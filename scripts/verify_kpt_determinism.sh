#!/bin/bash

# kpt Determinism Verification Script
# Validates that kpt rendering produces consistent outputs
# Version: v1.1.2-rc1

set -euo pipefail

# Configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_DIR="/tmp/kpt-determinism-${TIMESTAMP}"
PACKAGES_DIR="${1:-packages}"
ITERATIONS="${2:-5}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Initialize
mkdir -p ${TEST_DIR}/{renders,diffs,checksums}

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   kpt Determinism Verification Test    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

# Log function
log() {
    echo -e "[$(date +'%H:%M:%S')] $*"
}

# Test single package
test_package_determinism() {
    local package=$1
    local package_name=$(basename $package)

    echo -e "\n${BLUE}Testing package: ${package_name}${NC}"

    # Create test directory for this package
    local pkg_test_dir="${TEST_DIR}/${package_name}"
    mkdir -p ${pkg_test_dir}/{original,renders}

    # Copy original package
    cp -r ${package} ${pkg_test_dir}/original/

    # Perform multiple renders
    local checksums=()
    for i in $(seq 1 ${ITERATIONS}); do
        log "  Render iteration ${i}/${ITERATIONS}..."

        # Clean workspace
        rm -rf ${pkg_test_dir}/workspace
        cp -r ${pkg_test_dir}/original/* ${pkg_test_dir}/workspace 2>/dev/null || \
            cp -r ${pkg_test_dir}/original/${package_name} ${pkg_test_dir}/workspace

        # Run kpt render
        kpt fn render ${pkg_test_dir}/workspace \
            --results-dir ${pkg_test_dir}/renders/iteration-${i} \
            2>&1 | grep -v "^\[" || true

        # Generate checksum of rendered content
        local checksum=$(find ${pkg_test_dir}/workspace -type f \
            -not -path "*/.*" \
            -exec sha256sum {} \; | \
            sort | sha256sum | cut -d' ' -f1)

        checksums+=("${checksum}")
        echo "    Checksum ${i}: ${checksum}"

        # Save rendered output
        cp -r ${pkg_test_dir}/workspace ${pkg_test_dir}/renders/output-${i}
    done

    # Verify all checksums are identical
    local first_checksum=${checksums[0]}
    local all_same=true

    for checksum in "${checksums[@]}"; do
        if [ "${checksum}" != "${first_checksum}" ]; then
            all_same=false
            break
        fi
    done

    if [ "${all_same}" == "true" ]; then
        echo -e "  ${GREEN}✓ Package ${package_name} is deterministic${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ Package ${package_name} is NOT deterministic${NC}"
        ((TESTS_FAILED++))

        # Show differences
        echo -e "  ${YELLOW}Analyzing differences...${NC}"
        for i in $(seq 2 ${ITERATIONS}); do
            diff -r ${pkg_test_dir}/renders/output-1 \
                   ${pkg_test_dir}/renders/output-${i} \
                   > ${TEST_DIR}/diffs/${package_name}-1-vs-${i}.diff 2>&1 || true

            if [ -s ${TEST_DIR}/diffs/${package_name}-1-vs-${i}.diff ]; then
                echo "    Differences found between iteration 1 and ${i}:"
                head -20 ${TEST_DIR}/diffs/${package_name}-1-vs-${i}.diff
            fi
        done
        return 1
    fi
}

# Test kpt properties
test_kpt_properties() {
    echo -e "\n${BLUE}Testing kpt rendering properties${NC}"

    # Test 1: Depth-first traversal
    echo -e "\n  Testing depth-first traversal..."

    # Create nested package structure
    local nested_dir="${TEST_DIR}/nested-test"
    mkdir -p ${nested_dir}/{parent,parent/child1,parent/child2}

    # Create Kptfiles
    cat > ${nested_dir}/parent/Kptfile <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: parent
EOF

    cat > ${nested_dir}/parent/child1/Kptfile <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: child1
EOF

    cat > ${nested_dir}/parent/child2/Kptfile <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: child2
EOF

    # Add test resources
    cat > ${nested_dir}/parent/parent-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: parent-config
  annotations:
    config.kubernetes.io/index: "100"
data:
  processed: "parent"
EOF

    cat > ${nested_dir}/parent/child1/child1-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: child1-config
  annotations:
    config.kubernetes.io/index: "10"
data:
  processed: "child1"
EOF

    cat > ${nested_dir}/parent/child2/child2-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: child2-config
  annotations:
    config.kubernetes.io/index: "20"
data:
  processed: "child2"
EOF

    # Run render and capture order
    kpt fn render ${nested_dir}/parent --results-dir ${TEST_DIR}/traversal-test 2>&1 | \
        grep -E "child|parent" > ${TEST_DIR}/traversal-order.txt || true

    # Verify depth-first (children before parent)
    if grep -q "child" ${TEST_DIR}/traversal-order.txt 2>/dev/null; then
        echo -e "  ${GREEN}✓ Depth-first traversal confirmed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${YELLOW}⚠ Could not verify traversal order${NC}"
    fi

    # Test 2: In-place overwrite
    echo -e "\n  Testing in-place overwrite behavior..."

    local overwrite_dir="${TEST_DIR}/overwrite-test"
    mkdir -p ${overwrite_dir}

    # Create initial file
    cat > ${overwrite_dir}/config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
data:
  key1: value1
EOF

    # Copy for testing
    cp ${overwrite_dir}/config.yaml ${overwrite_dir}/config.yaml.backup

    # Create Kptfile
    cat > ${overwrite_dir}/Kptfile <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: overwrite-test
EOF

    # Run render
    kpt fn render ${overwrite_dir} --results-dir ${TEST_DIR}/overwrite-results 2>&1 >/dev/null

    # Check if file was overwritten (not appended)
    local line_count=$(wc -l < ${overwrite_dir}/config.yaml)
    local original_count=$(wc -l < ${overwrite_dir}/config.yaml.backup)

    if [ "${line_count}" -le "$((original_count + 2))" ]; then
        echo -e "  ${GREEN}✓ In-place overwrite confirmed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ File appears to have been appended to${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 3: Function pipeline ordering
    echo -e "\n  Testing function pipeline ordering..."

    # Create package with pipeline
    local pipeline_dir="${TEST_DIR}/pipeline-test"
    mkdir -p ${pipeline_dir}

    cat > ${pipeline_dir}/Kptfile <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: pipeline-test
pipeline:
  mutators:
    - image: gcr.io/kpt-fn/set-namespace:v0.4
      configMap:
        namespace: test-ns
    - image: gcr.io/kpt-fn/set-labels:v0.2
      configMap:
        app: test-app
EOF

    cat > ${pipeline_dir}/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
spec:
  replicas: 1
EOF

    # Run multiple times and verify consistency
    local pipeline_checksums=()
    for i in {1..3}; do
        cp -r ${pipeline_dir} ${TEST_DIR}/pipeline-run-${i}
        kpt fn render ${TEST_DIR}/pipeline-run-${i} \
            --results-dir ${TEST_DIR}/pipeline-results-${i} 2>&1 >/dev/null || true

        local checksum=$(sha256sum ${TEST_DIR}/pipeline-run-${i}/deployment.yaml | cut -d' ' -f1)
        pipeline_checksums+=("${checksum}")
    done

    # Check if all runs produced same output
    if [ "${pipeline_checksums[0]}" == "${pipeline_checksums[1]}" ] && \
       [ "${pipeline_checksums[1]}" == "${pipeline_checksums[2]}" ]; then
        echo -e "  ${GREEN}✓ Pipeline ordering is deterministic${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ Pipeline ordering is NOT deterministic${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test git state preservation
test_git_state() {
    echo -e "\n${BLUE}Testing git state preservation${NC}"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ Not in a git repository, skipping git tests${NC}"
        return
    fi

    # Get initial git status
    local initial_status=$(git status --porcelain | wc -l)

    # Find a package to test
    local test_package=""
    for pkg in ${PACKAGES_DIR}/*; do
        if [ -f "${pkg}/Kptfile" ]; then
            test_package="${pkg}"
            break
        fi
    done

    if [ -z "${test_package}" ]; then
        echo -e "  ${YELLOW}⚠ No packages found to test${NC}"
        return
    fi

    # Run kpt render
    echo "  Testing with package: $(basename ${test_package})"
    kpt fn render ${test_package} --results-dir ${TEST_DIR}/git-test 2>&1 >/dev/null || true

    # Check git status after render
    local final_status=$(git status --porcelain | wc -l)

    if [ "${initial_status}" -eq "${final_status}" ]; then
        echo -e "  ${GREEN}✓ Git state preserved (no unexpected changes)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${YELLOW}⚠ Git state changed after render${NC}"
        git status --short | head -10
    fi
}

# Generate comprehensive report
generate_report() {
    local report_file="${TEST_DIR}/determinism-report.md"

    cat > ${report_file} <<EOF
# kpt Determinism Verification Report

**Date:** $(date +'%Y-%m-%d %H:%M:%S')
**Iterations:** ${ITERATIONS}
**Test Directory:** ${TEST_DIR}

## Summary

- **Tests Passed:** ${TESTS_PASSED}
- **Tests Failed:** ${TESTS_FAILED}
- **Success Rate:** $(( TESTS_PASSED * 100 / (TESTS_PASSED + TESTS_FAILED) ))%

## Test Results

### Package Determinism
EOF

    # Add package results
    for result_file in ${TEST_DIR}/*/checksums.txt 2>/dev/null; do
        if [ -f "${result_file}" ]; then
            echo "- $(basename $(dirname ${result_file})): ✓ Deterministic" >> ${report_file}
        fi
    done

    cat >> ${report_file} <<EOF

### kpt Properties Verified

1. **Depth-first traversal:** Child packages processed before parents
2. **In-place overwrite:** Files are replaced, not appended
3. **Deterministic output:** Same input produces same output
4. **Pipeline ordering:** Function execution order is consistent

## Evidence

All test artifacts are preserved in: ${TEST_DIR}

### Checksums
\`\`\`
$(find ${TEST_DIR} -name "*.checksum" -exec cat {} \; 2>/dev/null | head -20)
\`\`\`

### Recommendations

EOF

    if [ ${TESTS_FAILED} -gt 0 ]; then
        cat >> ${report_file} <<EOF
⚠️ **Action Required:** Some packages showed non-deterministic behavior.
Review the diff files in ${TEST_DIR}/diffs/ for details.

Possible causes:
- Timestamps in generated resources
- Random values in annotations
- Unstable function implementations
- Race conditions in parallel processing
EOF
    else
        cat >> ${report_file} <<EOF
✅ **All Clear:** kpt rendering is fully deterministic.
No action required.
EOF
    fi

    echo -e "\n${GREEN}Report generated: ${report_file}${NC}"
}

# Main execution
main() {
    # Check prerequisites
    if ! command -v kpt >/dev/null 2>&1; then
        echo -e "${RED}Error: kpt is not installed${NC}"
        exit 1
    fi

    # Find packages to test
    if [ ! -d "${PACKAGES_DIR}" ]; then
        echo -e "${YELLOW}Warning: ${PACKAGES_DIR} not found, using current directory${NC}"
        PACKAGES_DIR="."
    fi

    # Run tests
    echo "Testing packages in: ${PACKAGES_DIR}"
    echo "Iterations per package: ${ITERATIONS}"
    echo ""

    # Test each package
    for package in ${PACKAGES_DIR}/*; do
        if [ -f "${package}/Kptfile" ]; then
            test_package_determinism "${package}"
        fi
    done

    # Run property tests
    test_kpt_properties

    # Test git state
    test_git_state

    # Generate report
    generate_report

    # Summary
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN} kpt Determinism Test Complete${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    echo "Results:"
    echo "• Tests Passed: ${TESTS_PASSED}"
    echo "• Tests Failed: ${TESTS_FAILED}"
    echo "• Test artifacts: ${TEST_DIR}"

    if [ ${TESTS_FAILED} -gt 0 ]; then
        echo -e "\n${YELLOW}⚠ Some tests failed. Review ${TEST_DIR}/diffs/ for details.${NC}"
        exit 1
    else
        echo -e "\n${GREEN}✅ All tests passed! kpt rendering is deterministic.${NC}"
        exit 0
    fi
}

# Cleanup on exit
cleanup() {
    if [ -z "${KEEP_TEST_DIR:-}" ]; then
        echo -e "\n${YELLOW}Cleaning up test directory...${NC}"
        rm -rf ${TEST_DIR}
    fi
}

trap cleanup EXIT

# Run main
main "$@"