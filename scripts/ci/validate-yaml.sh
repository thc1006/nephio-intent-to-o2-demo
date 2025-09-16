#!/bin/bash

# CI/CD Pipeline - YAML Validation Script
# Validates YAML syntax across the repository

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATION_REPORT="${REPO_ROOT}/artifacts/yaml-validation-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$VALIDATION_REPORT")"

# Initialize report
cat > "$VALIDATION_REPORT" << 'EOF'
{
  "validation_type": "yaml_syntax",
  "timestamp": "",
  "files_checked": [],
  "errors": [],
  "warnings": [],
  "summary": {
    "total_files": 0,
    "passed": 0,
    "failed": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo "::notice::Starting YAML validation across repository..."

# Create yamllint config
cat > "${REPO_ROOT}/.yamllint.yml" << 'EOF'
extends: default
rules:
  line-length:
    max: 120
    level: warning
  indentation:
    spaces: 2
  comments:
    min-spaces-from-content: 1
  comments-indentation: disable
  truthy: disable
EOF

# Find all YAML files
mapfile -t yaml_files < <(find "$REPO_ROOT" -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/artifacts/*" \
  ! -path "*/reports/*" \
  ! -path "*/.pytest_cache/*" \
  ! -path "*/htmlcov/*")

total_files=${#yaml_files[@]}
echo "Found $total_files YAML files to validate"

# Update total files count
jq --arg count "$total_files" '.summary.total_files = ($count | tonumber)' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

passed=0
failed=0

for file in "${yaml_files[@]}"; do
    rel_path="${file#$REPO_ROOT/}"
    echo "Validating: $rel_path"

    # Add file to checked list
    jq --arg file "$rel_path" '.files_checked += [$file]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

    # Validate with yamllint
    if yamllint_output=$(yamllint -f parsable "$file" 2>&1); then
        echo "✅ $rel_path - PASSED"
        ((passed++))
    else
        echo "❌ $rel_path - FAILED"
        echo "$yamllint_output"
        ((failed++))
        EXIT_CODE=1

        # Add error to report
        error_msg=$(echo "$yamllint_output" | jq -Rs .)
        jq --arg file "$rel_path" --argjson error "$error_msg" '.errors += [{"file": $file, "error": $error}]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi
done

# Update summary
jq --arg passed "$passed" --arg failed "$failed" \
   '.summary.passed = ($passed | tonumber) | .summary.failed = ($failed | tonumber)' \
   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo
echo "YAML Validation Summary:"
echo "📊 Total files: $total_files"
echo "✅ Passed: $passed"
echo "❌ Failed: $failed"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All YAML files are valid!"
else
    echo "💥 YAML validation failed. Check the report at: $VALIDATION_REPORT"
fi

# Clean up
rm -f "${REPO_ROOT}/.yamllint.yml"

exit $EXIT_CODE