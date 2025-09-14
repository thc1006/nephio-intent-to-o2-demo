#!/bin/bash
# Workflow Validation Script
# Validates GitHub Actions workflows for syntax, completeness, and integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

echo "🔍 Validating GitHub Actions workflows..."
echo "Repository: $REPO_ROOT"
echo "Workflows directory: $WORKFLOWS_DIR"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_WORKFLOWS=0
PASSED_WORKFLOWS=0
FAILED_WORKFLOWS=0

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}✅ PASS${NC}: $message"
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL${NC}: $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  WARN${NC}: $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO${NC}: $message"
            ;;
    esac
}

# Function to validate YAML syntax
validate_yaml_syntax() {
    local workflow_file=$1
    local workflow_name=$(basename "$workflow_file" .yml)

    print_status "INFO" "Validating YAML syntax for $workflow_name"

    # Check if python3 and pyyaml are available
    if ! command -v python3 &> /dev/null; then
        print_status "WARN" "Python3 not available, skipping YAML validation"
        return 0
    fi

    # Validate YAML syntax
    python3 -c "
import yaml
import sys
try:
    with open('$workflow_file', 'r') as f:
        yaml.safe_load(f)
    print('  YAML syntax is valid')
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'  YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'  Error reading file: {e}')
    sys.exit(1)
" && return 0 || return 1
}

# Function to validate workflow structure
validate_workflow_structure() {
    local workflow_file=$1
    local workflow_name=$(basename "$workflow_file" .yml)

    print_status "INFO" "Validating workflow structure for $workflow_name"

    # Check required sections
    local required_sections=("name" "on" "jobs")
    local missing_sections=()

    for section in "${required_sections[@]}"; do
        if ! grep -q "^$section:" "$workflow_file"; then
            missing_sections+=("$section")
        fi
    done

    if [[ ${#missing_sections[@]} -gt 0 ]]; then
        print_status "FAIL" "Missing required sections: ${missing_sections[*]}"
        return 1
    fi

    # Check for environment variables
    if grep -q "^env:" "$workflow_file"; then
        print_status "PASS" "Environment variables defined"
    fi

    # Check for caching
    if grep -q "actions/cache@" "$workflow_file"; then
        print_status "PASS" "Caching strategy implemented"
    fi

    # Check for artifact handling
    if grep -q "actions/upload-artifact@" "$workflow_file"; then
        print_status "PASS" "Artifact upload configured"
    fi

    return 0
}

# Function to validate workflow integration
validate_workflow_integration() {
    local workflow_file=$1
    local workflow_name=$(basename "$workflow_file" .yml)

    print_status "INFO" "Validating workflow integration for $workflow_name"

    case $workflow_name in
        "ci")
            # CI should trigger other workflows
            if grep -q "github-script@" "$workflow_file" && grep -q "createWorkflowDispatch" "$workflow_file"; then
                print_status "PASS" "CI workflow integration configured"
            else
                print_status "WARN" "CI workflow may be missing integration triggers"
            fi
            ;;
        "security-scan")
            # Security scan should have multiple scan types
            if grep -q "dependency-check" "$workflow_file" && grep -q "sast-scan" "$workflow_file"; then
                print_status "PASS" "Security scan has multiple scan types"
            else
                print_status "FAIL" "Security scan missing required scan types"
                return 1
            fi
            ;;
        "multi-site-validation")
            # Multi-site should have matrix strategy
            if grep -q "strategy:" "$workflow_file" && grep -q "matrix:" "$workflow_file"; then
                print_status "PASS" "Multi-site validation has matrix strategy"
            else
                print_status "FAIL" "Multi-site validation missing matrix strategy"
                return 1
            fi
            ;;
        "summit-package")
            # Summit package should create releases
            if grep -q "softprops/action-gh-release" "$workflow_file"; then
                print_status "PASS" "Summit package can create releases"
            else
                print_status "WARN" "Summit package may not create GitHub releases"
            fi
            ;;
    esac

    return 0
}

# Function to validate workflow dependencies
validate_workflow_dependencies() {
    local workflow_file=$1
    local workflow_name=$(basename "$workflow_file" .yml)

    print_status "INFO" "Validating dependencies for $workflow_name"

    # Check for version consistency
    local go_version=$(grep "GO_VERSION:" "$workflow_file" | head -1 | cut -d"'" -f2 || echo "")
    local python_version=$(grep "PYTHON_VERSION:" "$workflow_file" | head -1 | cut -d"'" -f2 || echo "")
    local kpt_version=$(grep "KPT_VERSION:" "$workflow_file" | head -1 | cut -d"'" -f2 || echo "")

    if [[ -n "$go_version" && "$go_version" != "1.22" ]]; then
        print_status "WARN" "Go version $go_version may be inconsistent"
    fi

    if [[ -n "$python_version" && "$python_version" != "3.11" ]]; then
        print_status "WARN" "Python version $python_version may be inconsistent"
    fi

    # Check for action versions
    local outdated_actions=()

    if grep -q "actions/checkout@v3" "$workflow_file"; then
        outdated_actions+=("checkout@v3")
    fi

    if grep -q "actions/setup-python@v3" "$workflow_file"; then
        outdated_actions+=("setup-python@v3")
    fi

    if [[ ${#outdated_actions[@]} -gt 0 ]]; then
        print_status "WARN" "Potentially outdated actions: ${outdated_actions[*]}"
    fi

    return 0
}

# Function to check workflow permissions
validate_workflow_permissions() {
    local workflow_file=$1
    local workflow_name=$(basename "$workflow_file" .yml)

    print_status "INFO" "Validating permissions for $workflow_name"

    # Check for explicit permissions
    if grep -q "^permissions:" "$workflow_file"; then
        print_status "PASS" "Explicit permissions defined"
    else
        print_status "WARN" "No explicit permissions defined (using defaults)"
    fi

    # Check for write operations that might need permissions
    if grep -q "softprops/action-gh-release\|github/codeql-action" "$workflow_file"; then
        if ! grep -q "contents: write\|security-events: write" "$workflow_file"; then
            print_status "WARN" "Workflow may need additional permissions for write operations"
        fi
    fi

    return 0
}

# Main validation loop
echo "=== Starting Workflow Validation ==="
echo ""

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    print_status "FAIL" "Workflows directory not found: $WORKFLOWS_DIR"
    exit 1
fi

# Find all workflow files
mapfile -t workflow_files < <(find "$WORKFLOWS_DIR" -name "*.yml" -o -name "*.yaml")

if [[ ${#workflow_files[@]} -eq 0 ]]; then
    print_status "FAIL" "No workflow files found in $WORKFLOWS_DIR"
    exit 1
fi

print_status "INFO" "Found ${#workflow_files[@]} workflow files"
echo ""

# Validate each workflow
for workflow_file in "${workflow_files[@]}"; do
    TOTAL_WORKFLOWS=$((TOTAL_WORKFLOWS + 1))
    workflow_name=$(basename "$workflow_file" .yml)

    echo "--- Validating $workflow_name ---"

    # Track validation status
    validation_failed=false

    # YAML syntax validation
    if ! validate_yaml_syntax "$workflow_file"; then
        validation_failed=true
    fi

    # Structure validation
    if ! validate_workflow_structure "$workflow_file"; then
        validation_failed=true
    fi

    # Integration validation
    if ! validate_workflow_integration "$workflow_file"; then
        validation_failed=true
    fi

    # Dependencies validation
    validate_workflow_dependencies "$workflow_file"

    # Permissions validation
    validate_workflow_permissions "$workflow_file"

    # Overall status
    if [[ "$validation_failed" == "true" ]]; then
        print_status "FAIL" "Workflow $workflow_name has validation issues"
        FAILED_WORKFLOWS=$((FAILED_WORKFLOWS + 1))
    else
        print_status "PASS" "Workflow $workflow_name validation complete"
        PASSED_WORKFLOWS=$((PASSED_WORKFLOWS + 1))
    fi

    echo ""
done

# Validate workflow integration matrix
echo "=== Workflow Integration Matrix ==="
echo ""

# Check if CI workflow can trigger other workflows
if [[ -f "$WORKFLOWS_DIR/ci.yml" ]]; then
    if grep -q "security-scan.yml\|multi-site-validation.yml\|summit-package.yml" "$WORKFLOWS_DIR/ci.yml"; then
        print_status "PASS" "CI workflow has integration triggers"
    else
        print_status "WARN" "CI workflow may be missing integration triggers"
    fi
fi

# Check for workflow dependencies
declare -A workflow_deps
workflow_deps["ci.yml"]="security-scan.yml,multi-site-validation.yml,summit-package.yml"
workflow_deps["security-scan.yml"]=""
workflow_deps["multi-site-validation.yml"]=""
workflow_deps["summit-package.yml"]="ci.yml"
workflow_deps["nightly.yml"]=""
workflow_deps["golden-tests.yml"]=""

for workflow in "${!workflow_deps[@]}"; do
    if [[ -f "$WORKFLOWS_DIR/$workflow" ]]; then
        deps="${workflow_deps[$workflow]}"
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep in "${dep_array[@]}"; do
                if [[ -f "$WORKFLOWS_DIR/$dep" ]]; then
                    print_status "PASS" "$workflow depends on $dep (available)"
                else
                    print_status "FAIL" "$workflow depends on $dep (missing)"
                fi
            done
        fi
    fi
done

# Check for required scripts
echo ""
echo "=== Script Dependencies ==="
echo ""

required_scripts=(
    "scripts/demo_llm.sh"
    "scripts/postcheck.sh"
    "scripts/rollback.sh"
    "scripts/package_artifacts.sh"
)

for script in "${required_scripts[@]}"; do
    if [[ -f "$REPO_ROOT/$script" ]]; then
        print_status "PASS" "Required script exists: $script"
        # Check if script is executable
        if [[ -x "$REPO_ROOT/$script" ]]; then
            print_status "PASS" "Script is executable: $script"
        else
            print_status "WARN" "Script is not executable: $script"
        fi
    else
        print_status "WARN" "Required script missing: $script"
    fi
done

# Final summary
echo ""
echo "=== Validation Summary ==="
echo ""
print_status "INFO" "Total workflows: $TOTAL_WORKFLOWS"
print_status "INFO" "Passed: $PASSED_WORKFLOWS"
print_status "INFO" "Failed: $FAILED_WORKFLOWS"

if [[ $FAILED_WORKFLOWS -eq 0 ]]; then
    print_status "PASS" "All workflows passed validation! 🎉"
    echo ""
    echo "Next steps:"
    echo "1. Test workflows with: gh workflow list"
    echo "2. Run a workflow with: gh workflow run ci.yml"
    echo "3. Monitor workflow status with: gh run list"
    exit 0
else
    print_status "FAIL" "Some workflows have validation issues that need attention"
    echo ""
    echo "Recommended actions:"
    echo "1. Fix validation errors shown above"
    echo "2. Re-run this validation script"
    echo "3. Test workflows in a branch before merging"
    exit 1
fi