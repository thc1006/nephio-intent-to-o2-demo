#!/bin/bash

# CI/CD Pipeline - Kubernetes Manifest Validation Script
# Validates K8s manifests using kubeconform and custom checks

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATION_REPORT="${REPO_ROOT}/artifacts/k8s-validation-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$VALIDATION_REPORT")"

# Initialize report
cat > "$VALIDATION_REPORT" << 'EOF'
{
  "validation_type": "k8s_manifests",
  "timestamp": "",
  "files_checked": [],
  "errors": [],
  "warnings": [],
  "summary": {
    "total_files": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo "::notice::Starting Kubernetes manifest validation..."

# Find all Kubernetes manifest files
mapfile -t k8s_files < <(find "$REPO_ROOT" -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/artifacts/*" \
  ! -path "*/reports/*" \
  ! -path "*/.pytest_cache/*" \
  ! -path "*/htmlcov/*" \
  ! -path "*/.github/workflows/*" \
  -exec grep -l "apiVersion:" {} \; 2>/dev/null || true)

total_files=${#k8s_files[@]}
echo "Found $total_files Kubernetes manifest files to validate"

# Update total files count
jq --arg count "$total_files" '.summary.total_files = ($count | tonumber)' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

passed=0
failed=0
skipped=0

# Function to validate single manifest
validate_manifest() {
    local file="$1"
    local rel_path="${file#$REPO_ROOT/}"
    local file_errors=()

    echo "Validating K8s manifest: $rel_path"

    # Add file to checked list
    jq --arg file "$rel_path" '.files_checked += [$file]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

    # Check if file contains Kubernetes resources
    if ! grep -q "apiVersion:" "$file"; then
        echo "⚠️  $rel_path - SKIPPED (no Kubernetes resources)"
        ((skipped++))
        return 0
    fi

    # Validate with kubeconform
    if kubeconform_output=$(kubeconform -summary -verbose "$file" 2>&1); then
        echo "✅ $rel_path - PASSED kubeconform validation"
    else
        echo "❌ $rel_path - FAILED kubeconform validation"
        echo "$kubeconform_output"
        file_errors+=("kubeconform: $kubeconform_output")
    fi

    # Custom validation checks
    # Check for required labels
    if ! grep -q "app:" "$file" && grep -q "kind: Deployment\|kind: Service\|kind: StatefulSet" "$file"; then
        warning_msg="Missing 'app' label in Deployment/Service/StatefulSet"
        echo "⚠️  $rel_path - WARNING: $warning_msg"
        jq --arg file "$rel_path" --arg warning "$warning_msg" '.warnings += [{"file": $file, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Check for resource limits in containers
    if grep -q "kind: Deployment\|kind: StatefulSet\|kind: Job" "$file" && ! grep -q "resources:" "$file"; then
        warning_msg="Missing resource limits/requests in containers"
        echo "⚠️  $rel_path - WARNING: $warning_msg"
        jq --arg file "$rel_path" --arg warning "$warning_msg" '.warnings += [{"file": $file, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Check for security context
    if grep -q "kind: Deployment\|kind: StatefulSet\|kind: Job" "$file" && ! grep -q "securityContext:" "$file"; then
        warning_msg="Missing securityContext in workload"
        echo "⚠️  $rel_path - WARNING: $warning_msg"
        jq --arg file "$rel_path" --arg warning "$warning_msg" '.warnings += [{"file": $file, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Check for hardcoded values that should be configurable
    if grep -E "image:.*:latest|localhost:|127\.0\.0\.1" "$file"; then
        warning_msg="Potential hardcoded values found (latest tag, localhost, etc.)"
        echo "⚠️  $rel_path - WARNING: $warning_msg"
        jq --arg file "$rel_path" --arg warning "$warning_msg" '.warnings += [{"file": $file, "warning": $warning}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # If there were errors, mark as failed
    if [ ${#file_errors[@]} -gt 0 ]; then
        ((failed++))
        EXIT_CODE=1
        # Add errors to report
        for error in "${file_errors[@]}"; do
            jq --arg file "$rel_path" --arg error "$error" '.errors += [{"file": $file, "error": $error}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
        done
    else
        ((passed++))
    fi
}

# Validate all manifest files
for file in "${k8s_files[@]}"; do
    validate_manifest "$file"
done

# Update summary
jq --arg passed "$passed" --arg failed "$failed" --arg skipped "$skipped" \
   '.summary.passed = ($passed | tonumber) | .summary.failed = ($failed | tonumber) | .summary.skipped = ($skipped | tonumber)' \
   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo
echo "Kubernetes Manifest Validation Summary:"
echo "📊 Total files: $total_files"
echo "✅ Passed: $passed"
echo "❌ Failed: $failed"
echo "⏭️  Skipped: $skipped"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All Kubernetes manifests are valid!"
else
    echo "💥 Kubernetes manifest validation failed. Check the report at: $VALIDATION_REPORT"
fi

exit $EXIT_CODE