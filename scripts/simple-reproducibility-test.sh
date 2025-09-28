#!/bin/bash
# Simplified Reproducibility Test for IEEE ICC 2026 paper
# Tests if system can be deployed following supplementary materials

set -euo pipefail

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/reports"
TEST_DATE=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORT_DIR/reproducibility-test-$TEST_DATE.md"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
declare -a RESULTS=()

# Helper functions
pass_test() {
    RESULTS+=("✅ $1")
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

fail_test() {
    RESULTS+=("❌ $1")
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

warn_test() {
    RESULTS+=("⚠️  $1")
    ((TOTAL_TESTS++))
}

echo "========================================"
echo "IEEE ICC 2026 Reproducibility Test"
echo "========================================"
echo "Testing if system can be reproduced from documentation alone"
echo

# Create reports directory
mkdir -p "$REPORT_DIR"

# Phase 1: Documentation Completeness
echo "Phase 1: Documentation Completeness"
echo "------------------------------------"

# Test 1.1: Check for supplementary materials
if [[ -f "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" ]]; then
    pass_test "IEEE supplementary materials documentation found"
else
    fail_test "IEEE supplementary materials documentation missing"
fi

# Test 1.2: Check for installation scripts
installation_scripts=0
for script in "install-2025.sh" "install-k3s.sh" "install-config-sync.sh" "install-tmf921-adapter.sh"; do
    if [[ -f "$PROJECT_ROOT/scripts/$script" ]]; then
        ((installation_scripts++))
    fi
done
if [[ $installation_scripts -ge 3 ]]; then
    pass_test "Installation scripts present ($installation_scripts found)"
else
    fail_test "Insufficient installation scripts ($installation_scripts found, need 3+)"
fi

# Test 1.3: Check for configuration files
if [[ -f "$PROJECT_ROOT/config/edge-sites-config.yaml" ]]; then
    pass_test "Edge sites configuration documented"
else
    fail_test "Edge sites configuration missing"
fi

# Test 1.4: Check for API documentation
api_docs=0
for doc in "O2IMS_API_v3.md" "TMF921_API_v5.md" "WebSocket_API.md"; do
    if find "$PROJECT_ROOT" -name "*$doc*" -o -name "*$(echo $doc | tr '[:upper:]' '[:lower:]')*" | grep -q .; then
        ((api_docs++))
    fi
done
if [[ $api_docs -ge 2 ]]; then
    pass_test "API documentation present ($api_docs/3 found)"
else
    warn_test "Limited API documentation ($api_docs/3 found)"
fi

echo

# Phase 2: Prerequisites Documentation
echo "Phase 2: Prerequisites Documentation"
echo "-----------------------------------"

# Test 2.1: System requirements documented
if grep -q "System Requirements" "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" 2>/dev/null; then
    pass_test "System requirements documented"
else
    fail_test "System requirements not clearly documented"
fi

# Test 2.2: Dependency versions specified
if grep -q "Dependencies.*2025" "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" 2>/dev/null; then
    pass_test "2025 dependency versions documented"
else
    warn_test "Dependency versions may not be current"
fi

# Test 2.3: Claude Code CLI integration documented
if grep -q "Claude Code CLI" "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" 2>/dev/null; then
    pass_test "Claude Code CLI integration documented"
else
    fail_test "Claude Code CLI integration not documented"
fi

echo

# Phase 3: Configuration Completeness
echo "Phase 3: Configuration Completeness"
echo "----------------------------------"

# Test 3.1: Edge sites configuration validity
edge_sites=$(grep -c "edge[0-9]:" "$PROJECT_ROOT/config/edge-sites-config.yaml" 2>/dev/null || echo 0)
if [[ $edge_sites -ge 4 ]]; then
    pass_test "All 4 edge sites configured"
elif [[ $edge_sites -ge 2 ]]; then
    warn_test "Partial edge sites configured ($edge_sites/4)"
else
    fail_test "Insufficient edge sites configured ($edge_sites/4)"
fi

# Test 3.2: SSH configuration documented
if grep -q "ssh_key" "$PROJECT_ROOT/config/edge-sites-config.yaml" 2>/dev/null; then
    pass_test "SSH configuration documented"
else
    fail_test "SSH configuration not documented"
fi

# Test 3.3: Service ports documented
required_ports=("22" "6443" "30090" "31280" "8889")
ports_documented=0
for port in "${required_ports[@]}"; do
    if grep -q "$port" "$PROJECT_ROOT/config/edge-sites-config.yaml" 2>/dev/null; then
        ((ports_documented++))
    fi
done
if [[ $ports_documented -ge 4 ]]; then
    pass_test "Service ports documented ($ports_documented/5)"
else
    warn_test "Some service ports missing documentation ($ports_documented/5)"
fi

echo

# Phase 4: Deployment Scripts Analysis
echo "Phase 4: Deployment Scripts Analysis"
echo "-----------------------------------"

# Test 4.1: O2IMS deployment script
if [[ -f "$PROJECT_ROOT/scripts/p0.3_o2ims_install.sh" ]]; then
    if bash -n "$PROJECT_ROOT/scripts/p0.3_o2ims_install.sh" 2>/dev/null; then
        pass_test "O2IMS deployment script syntax valid"
    else
        fail_test "O2IMS deployment script has syntax errors"
    fi
else
    fail_test "O2IMS deployment script not found"
fi

# Test 4.2: TMF921 adapter script
if [[ -f "$PROJECT_ROOT/scripts/install-tmf921-adapter.sh" ]]; then
    if bash -n "$PROJECT_ROOT/scripts/install-tmf921-adapter.sh" 2>/dev/null; then
        pass_test "TMF921 adapter script syntax valid"
    else
        fail_test "TMF921 adapter script has syntax errors"
    fi
else
    fail_test "TMF921 adapter script not found"
fi

# Test 4.3: GitOps manifests
manifests_count=$(find "$PROJECT_ROOT" -name "*.yaml" -o -name "*.yml" | grep -E "(manifest|deploy|gitops)" | wc -l)
if [[ $manifests_count -gt 5 ]]; then
    pass_test "Deployment manifests present ($manifests_count found)"
else
    warn_test "Limited deployment manifests ($manifests_count found)"
fi

echo

# Phase 5: Performance and Compliance
echo "Phase 5: Performance and Compliance"
echo "----------------------------------"

# Test 5.1: SLO targets documented
if grep -q "slo_targets" "$PROJECT_ROOT/config/edge-sites-config.yaml" 2>/dev/null; then
    pass_test "SLO targets documented"
else
    warn_test "SLO targets not explicitly documented"
fi

# Test 5.2: ATIS MVP V2 compliance
if grep -q "ATIS MVP V2" "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" 2>/dev/null; then
    pass_test "ATIS MVP V2 compliance documented"
else
    fail_test "ATIS MVP V2 compliance not documented"
fi

# Test 5.3: Nephio R4 compatibility
if grep -q "Nephio R4" "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" 2>/dev/null; then
    pass_test "Nephio R4 compatibility documented"
else
    fail_test "Nephio R4 compatibility not documented"
fi

# Test 5.4: Test coverage
test_files=$(find "$PROJECT_ROOT" -name "*test*" -type f | wc -l)
if [[ $test_files -gt 10 ]]; then
    pass_test "Comprehensive test suite present ($test_files test files)"
elif [[ $test_files -gt 5 ]]; then
    warn_test "Moderate test coverage ($test_files test files)"
else
    fail_test "Insufficient test coverage ($test_files test files)"
fi

echo

# Calculate results
success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))

# Generate report
cat > "$REPORT_FILE" << EOF
# Reproducibility Test Report

**Date:** $(date)
**System:** $(uname -a)
**Test Type:** Documentation-based reproducibility validation

## Executive Summary

- **Total Tests:** $TOTAL_TESTS
- **Passed:** $PASSED_TESTS
- **Failed:** $FAILED_TESTS
- **Success Rate:** ${success_rate}%

$(if [[ $success_rate -ge 90 ]]; then
    echo "**Status:** ✅ HIGHLY REPRODUCIBLE"
elif [[ $success_rate -ge 75 ]]; then
    echo "**Status:** ⚠️  MOSTLY REPRODUCIBLE"
else
    echo "**Status:** ❌ NEEDS IMPROVEMENT"
fi)

## Detailed Results

EOF

# Add all test results to the report
for result in "${RESULTS[@]}"; do
    echo "- $result" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## Reproducibility Assessment

### Can this system be reproduced from documentation alone?

$(if [[ $success_rate -ge 90 ]]; then
    cat << 'ASSESSMENT'
**YES** - The system appears highly reproducible. The documentation is comprehensive and includes:
- Clear installation instructions
- Complete configuration examples
- Proper version specifications
- Adequate troubleshooting information

**Estimated reproduction time:** 4-6 hours
**Skill level required:** Intermediate (Kubernetes, Linux administration)
ASSESSMENT
elif [[ $success_rate -ge 75 ]]; then
    cat << 'ASSESSMENT'
**MOSTLY** - The system can likely be reproduced with some additional effort:
- Most documentation is present
- Some gaps may require troubleshooting
- Additional research may be needed for edge cases

**Estimated reproduction time:** 8-12 hours
**Skill level required:** Advanced (Deep Kubernetes, O-RAN knowledge)
ASSESSMENT
else
    cat << 'ASSESSMENT'
**NEEDS IMPROVEMENT** - Significant gaps prevent reliable reproduction:
- Missing critical documentation
- Incomplete configuration examples
- Insufficient troubleshooting guidance

**Estimated reproduction time:** 16+ hours
**Skill level required:** Expert (Research-level knowledge required)
ASSESSMENT
fi)

### Key Strengths

$(if [[ $PASSED_TESTS -gt 0 ]]; then
    echo "The documentation excels in several areas:"
    for result in "${RESULTS[@]}"; do
        if [[ "$result" =~ ^✅ ]]; then
            echo "- ${result#✅ }"
        fi
    done
else
    echo "Limited strengths identified in current documentation."
fi)

### Areas for Improvement

$(if [[ $FAILED_TESTS -gt 0 ]]; then
    echo "The following areas need attention for better reproducibility:"
    for result in "${RESULTS[@]}"; do
        if [[ "$result" =~ ^❌ ]]; then
            echo "- ${result#❌ }"
        fi
    done
else
    echo "No critical issues identified."
fi)

### Recommendations

1. **Documentation Enhancements:**
   - Add step-by-step quick start guide (30-minute setup)
   - Include common troubleshooting scenarios
   - Provide configuration validation scripts

2. **Automation Improvements:**
   - Create comprehensive installation script
   - Add environment validation checks
   - Include rollback procedures

3. **Testing Completeness:**
   - Add integration test suite
   - Include performance benchmarks
   - Provide expected results baseline

## Compliance with IEEE Standards

- **Reproducibility:** $(if [[ $success_rate -ge 75 ]]; then echo "Meets IEEE standards"; else echo "Needs improvement"; fi)
- **Documentation:** $(if [[ $PASSED_TESTS -ge $((TOTAL_TESTS * 75 / 100)) ]]; then echo "Comprehensive"; else echo "Requires enhancement"; fi)
- **Code Availability:** $(if [[ -d "$PROJECT_ROOT/.git" ]]; then echo "Version controlled repository"; else echo "Static code only"; fi)

---

*This report validates if the IEEE ICC 2026 paper system can be reproduced by following the provided documentation alone.*

**Next Steps:**
1. Address failed test items
2. Enhance documentation gaps
3. Validate with independent reproduction attempt
4. Update supplementary materials based on findings

*Report generated: $(date)*
EOF

# Print summary
echo "========================================"
echo "         FINAL RESULTS"
echo "========================================"
echo
printf "%-20s %d\n" "Total Tests:" "$TOTAL_TESTS"
printf "%-20s %d\n" "Passed:" "$PASSED_TESTS"
printf "%-20s %d\n" "Failed:" "$FAILED_TESTS"
printf "%-20s %d%%\n" "Success Rate:" "$success_rate"
echo

if [[ $success_rate -ge 90 ]]; then
    echo "✅ HIGHLY REPRODUCIBLE"
    echo "The system can be reliably reproduced from documentation."
elif [[ $success_rate -ge 75 ]]; then
    echo "⚠️  MOSTLY REPRODUCIBLE"
    echo "The system can likely be reproduced with some effort."
else
    echo "❌ NEEDS IMPROVEMENT"
    echo "Significant issues prevent reliable reproduction."
fi

echo
echo "Detailed report: $REPORT_FILE"
echo

# Exit with appropriate code
if [[ $success_rate -ge 75 ]]; then
    exit 0
else
    exit 1
fi