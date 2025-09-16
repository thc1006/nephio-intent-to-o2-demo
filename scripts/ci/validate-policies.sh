#!/bin/bash

# CI/CD Pipeline - Policy Validation Script
# Validates configurations against OPA/Kyverno policies

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATION_REPORT="${REPO_ROOT}/artifacts/policy-validation-report.json"
POLICIES_DIR="${REPO_ROOT}/guardrails"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$VALIDATION_REPORT")"

# Initialize report
cat > "$VALIDATION_REPORT" << 'EOF'
{
  "validation_type": "policy_validation",
  "timestamp": "",
  "files_checked": [],
  "policies_applied": [],
  "violations": [],
  "warnings": [],
  "summary": {
    "total_files": 0,
    "total_policies": 0,
    "violations_found": 0,
    "passed": 0,
    "failed": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo "::notice::Starting policy validation..."

# Check if OPA is available
if ! command -v opa &> /dev/null; then
    echo "Installing OPA..."
    curl -L -o opa https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64_static
    chmod +x opa
    sudo mv opa /usr/local/bin/
fi

# Find policy files
mapfile -t policy_files < <(find "$POLICIES_DIR" -name "*.rego" -type f 2>/dev/null || true)
mapfile -t kyverno_policies < <(find "$POLICIES_DIR" -name "*policy*.yaml" -type f 2>/dev/null || true)

total_policies=$((${#policy_files[@]} + ${#kyverno_policies[@]}))
echo "Found $total_policies policy files to apply"

# Update total policies count
jq --arg count "$total_policies" '.summary.total_policies = ($count | tonumber)' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

# Find target files to validate
mapfile -t target_files < <(find "$REPO_ROOT" -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/artifacts/*" \
  ! -path "*/reports/*" \
  ! -path "*/.pytest_cache/*" \
  ! -path "*/htmlcov/*" \
  ! -path "*/.github/workflows/*" \
  -exec grep -l "apiVersion:" {} \; 2>/dev/null || true)

total_files=${#target_files[@]}
echo "Found $total_files Kubernetes manifest files to validate against policies"

# Update total files count
jq --arg count "$total_files" '.summary.total_files = ($count | tonumber)' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

passed=0
failed=0
violations_found=0

# Function to validate with OPA policies
validate_with_opa() {
    local file="$1"
    local rel_path="${file#$REPO_ROOT/}"

    echo "Validating $rel_path against OPA policies..."

    # Add file to checked list
    jq --arg file "$rel_path" '.files_checked += [$file]' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

    local file_violations=0

    for policy_file in "${policy_files[@]}"; do
        local policy_rel_path="${policy_file#$REPO_ROOT/}"

        # Add policy to applied list
        jq --arg policy "$policy_rel_path" '.policies_applied += [$policy] | .policies_applied |= unique' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

        # Run OPA evaluation
        if opa_result=$(opa eval -f pretty -d "$policy_file" -i "$file" "data.main.violation" 2>&1); then
            # Check if there are violations
            if echo "$opa_result" | grep -q "true\|violation"; then
                echo "❌ Policy violation found in $rel_path (policy: $policy_rel_path)"
                echo "$opa_result"
                ((file_violations++))
                ((violations_found++))

                # Add violation to report
                jq --arg file "$rel_path" --arg policy "$policy_rel_path" --arg violation "$opa_result" \
                   '.violations += [{"file": $file, "policy": $policy, "violation": $violation}]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
        else
            echo "⚠️  Error evaluating policy $policy_rel_path against $rel_path: $opa_result"
            jq --arg file "$rel_path" --arg policy "$policy_rel_path" --arg warning "Policy evaluation error: $opa_result" \
               '.warnings += [{"file": $file, "policy": $policy, "warning": $warning}]' \
               "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
        fi
    done

    return $file_violations
}

# Function to validate with Kyverno policies (basic check)
validate_with_kyverno() {
    local file="$1"
    local rel_path="${file#$REPO_ROOT/}"

    echo "Checking $rel_path against Kyverno policies..."

    local file_violations=0

    for policy_file in "${kyverno_policies[@]}"; do
        local policy_rel_path="${policy_file#$REPO_ROOT/}"

        # Add policy to applied list
        jq --arg policy "$policy_rel_path" '.policies_applied += [$policy] | .policies_applied |= unique' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

        # Basic Kyverno policy checks (simplified)
        # Check for required labels based on policy
        if grep -q "require.*label" "$policy_file"; then
            required_labels=$(grep -o "require.*label.*" "$policy_file" | head -1)
            if ! grep -q "labels:" "$file"; then
                echo "⚠️  $rel_path - Missing labels (required by $policy_rel_path)"
                jq --arg file "$rel_path" --arg policy "$policy_rel_path" --arg warning "Missing required labels" \
                   '.warnings += [{"file": $file, "policy": $policy, "warning": $warning}]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
        fi

        # Check for security context requirements
        if grep -q "securityContext" "$policy_file"; then
            if grep -q "kind: Deployment\|kind: StatefulSet" "$file" && ! grep -q "securityContext:" "$file"; then
                echo "❌ Security policy violation in $rel_path: Missing securityContext"
                ((file_violations++))
                ((violations_found++))

                jq --arg file "$rel_path" --arg policy "$policy_rel_path" --arg violation "Missing required securityContext" \
                   '.violations += [{"file": $file, "policy": $policy, "violation": $violation}]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
        fi
    done

    return $file_violations
}

# Built-in security policies
apply_builtin_policies() {
    local file="$1"
    local rel_path="${file#$REPO_ROOT/}"

    echo "Applying built-in security policies to $rel_path..."

    local violations=0

    # Check for privileged containers
    if grep -q "privileged: true" "$file"; then
        echo "❌ Security violation: Privileged container detected in $rel_path"
        ((violations++))
        ((violations_found++))

        jq --arg file "$rel_path" --arg policy "builtin-security" --arg violation "Privileged container detected" \
           '.violations += [{"file": $file, "policy": $policy, "violation": $violation}]' \
           "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Check for containers running as root
    if grep -q "runAsUser: 0" "$file"; then
        echo "❌ Security violation: Container running as root in $rel_path"
        ((violations++))
        ((violations_found++))

        jq --arg file "$rel_path" --arg policy "builtin-security" --arg violation "Container running as root" \
           '.violations += [{"file": $file, "policy": $policy, "violation": $violation}]' \
           "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    # Check for hostNetwork usage
    if grep -q "hostNetwork: true" "$file"; then
        echo "⚠️  Security warning: hostNetwork enabled in $rel_path"
        jq --arg file "$rel_path" --arg policy "builtin-security" --arg warning "hostNetwork enabled" \
           '.warnings += [{"file": $file, "policy": $policy, "warning": $warning}]' \
           "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
    fi

    return $violations
}

# Validate all target files
for file in "${target_files[@]}"; do
    rel_path="${file#$REPO_ROOT/}"
    echo "=== Validating $rel_path ==="

    file_violations=0

    # Apply OPA policies
    if [ ${#policy_files[@]} -gt 0 ]; then
        validate_with_opa "$file"
        file_violations=$((file_violations + $?))
    fi

    # Apply Kyverno policies
    if [ ${#kyverno_policies[@]} -gt 0 ]; then
        validate_with_kyverno "$file"
        file_violations=$((file_violations + $?))
    fi

    # Apply built-in policies
    apply_builtin_policies "$file"
    file_violations=$((file_violations + $?))

    # Update counters
    if [ $file_violations -gt 0 ]; then
        ((failed++))
        EXIT_CODE=1
        echo "❌ $rel_path - FAILED ($file_violations violations)"
    else
        ((passed++))
        echo "✅ $rel_path - PASSED"
    fi
done

# Update summary
jq --arg passed "$passed" --arg failed "$failed" --arg violations "$violations_found" \
   '.summary.passed = ($passed | tonumber) | .summary.failed = ($failed | tonumber) | .summary.violations_found = ($violations | tonumber)' \
   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

echo
echo "Policy Validation Summary:"
echo "📊 Total files: $total_files"
echo "📋 Total policies: $total_policies"
echo "✅ Passed: $passed"
echo "❌ Failed: $failed"
echo "⚠️  Violations found: $violations_found"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 All files passed policy validation!"
else
    echo "💥 Policy validation failed. Check the report at: $VALIDATION_REPORT"
fi

exit $EXIT_CODE