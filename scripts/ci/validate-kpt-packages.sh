#!/bin/bash

# CI/CD Pipeline - KPT Package Validation Script
# Validates KPT packages structure and renders

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATION_REPORT="${REPO_ROOT}/artifacts/kpt-validation-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$VALIDATION_REPORT")"

# Initialize report
cat > "$VALIDATION_REPORT" << 'EOF'
{
  "validation_type": "kpt_packages",
  "timestamp": "",
  "packages_checked": [],
  "errors": [],
  "warnings": [],
  "summary": {
    "total_packages": 0,
    "passed": 0,
    "failed": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo "::notice::Starting KPT package validation..."

# Find all KPT packages (directories with Kptfile)
mapfile -t kpt_packages < <(find "$REPO_ROOT" -name "Kptfile" -type f \
  ! -path "*/.git/*" \
  ! -path "*/artifacts/*" \
  ! -path "*/reports/*" \
  -exec dirname {} \; | sort -u)

total_packages=${#kpt_packages[@]}
echo "Found $total_packages KPT packages to validate"

# Update total packages count
jq --arg count "$total_packages" '.summary.total_packages = ($count | tonumber)' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

passed=0
failed=0

# Function to validate single KPT package
validate_kpt_package() {
    local package_dir="$1"
    local rel_path="${package_dir#$REPO_ROOT/}"
    local package_errors=()
    local temp_dir

    echo "Validating KPT package: $rel_path"

    # Add package to checked list
    jq --arg pkg "$rel_path" '.packages_checked += [$pkg]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

    # Check Kptfile validity
    if ! kptfile_check=$(kpt pkg validate "$package_dir" 2>&1); then
        echo "❌ $rel_path - FAILED Kptfile validation"
        echo "$kptfile_check"
        package_errors+=("Kptfile validation: $kptfile_check")
    else
        echo "✅ $rel_path - Kptfile is valid"
    fi

    # Test package rendering in isolation
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    if ! cp -r "$package_dir" "$temp_dir/test-package" 2>/dev/null; then
        echo "❌ $rel_path - FAILED to copy package for testing"
        package_errors+=("Failed to copy package for testing")
    else
        # Test kpt fn render
        cd "$temp_dir/test-package"
        if ! render_output=$(kpt fn render 2>&1); then
            echo "❌ $rel_path - FAILED kpt fn render"
            echo "$render_output"
            package_errors+=("kpt fn render failed: $render_output")
        else
            echo "✅ $rel_path - Successfully rendered"

            # Check if render produced valid YAML
            if ! find . -name "*.yaml" -o -name "*.yml" -exec yamllint {} \; >/dev/null 2>&1; then
                echo "⚠️  $rel_path - WARNING: Rendered output contains invalid YAML"
                jq --arg pkg "$rel_path" --arg warning "Rendered output contains invalid YAML" '.warnings += [{"package": $pkg, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
        fi
        cd - >/dev/null
    fi

    # Check for required package structure
    if [ ! -f "$package_dir/Kptfile" ]; then
        package_errors+=("Missing Kptfile")
    fi

    # Check for package metadata
    if ! grep -q "metadata:" "$package_dir/Kptfile"; then
        echo "⚠️  $rel_path - WARNING: Kptfile missing metadata section"
        jq --arg pkg "$rel_path" --arg warning "Kptfile missing metadata section" '.warnings += [{"package": $pkg, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Check for functions
    if grep -q "pipeline:" "$package_dir/Kptfile"; then
        echo "✅ $rel_path - Has function pipeline"
    else
        echo "⚠️  $rel_path - WARNING: No function pipeline defined"
        jq --arg pkg "$rel_path" --arg warning "No function pipeline defined" '.warnings += [{"package": $pkg, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Validate package dependencies if they exist
    if grep -q "upstream:" "$package_dir/Kptfile"; then
        echo "📦 $rel_path - Has upstream dependencies"
        # Could add dependency validation here
    fi

    # If there were errors, mark as failed
    if [ ${#package_errors[@]} -gt 0 ]; then
        ((failed++))
        EXIT_CODE=1
        # Add errors to report
        for error in "${package_errors[@]}"; do
            jq --arg pkg "$rel_path" --arg error "$error" '.errors += [{"package": $pkg, "error": $error}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
        done
    else
        ((passed++))
    fi

    # Cleanup temp directory
    rm -rf "$temp_dir"
}

# Validate all KPT packages
for package_dir in "${kpt_packages[@]}"; do
    validate_kpt_package "$package_dir"
done

# Update summary
jq --arg passed "$passed" --arg failed "$failed" \
   '.summary.passed = ($passed | tonumber) | .summary.failed = ($failed | tonumber)' \
   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo
echo "KPT Package Validation Summary:"
echo "📊 Total packages: $total_packages"
echo "✅ Passed: $passed"
echo "❌ Failed: $failed"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All KPT packages are valid!"
else
    echo "💥 KPT package validation failed. Check the report at: $VALIDATION_REPORT"
fi

exit $EXIT_CODE