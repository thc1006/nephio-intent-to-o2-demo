#!/bin/bash

# CI/CD Pipeline Setup Validation Script
# Validates that all CI/CD components are properly configured

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION_REPORT="${REPO_ROOT}/artifacts/cicd-setup-validation.json"

echo "🔍 Validating CI/CD Pipeline Setup..."

# Ensure artifacts directory exists
mkdir -p "$(dirname "$VALIDATION_REPORT")"

# Initialize validation report
cat > "$VALIDATION_REPORT" << 'EOF'
{
  "validation_type": "cicd_setup",
  "timestamp": "",
  "components": {},
  "summary": {
    "total_components": 0,
    "valid_components": 0,
    "issues_found": 0,
    "setup_complete": false
  },
  "issues": [],
  "recommendations": []
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

# Component validation results
components_valid=0
components_total=0
issues_found=0

# Function to validate component
validate_component() {
    local component="$1"
    local check_type="$2"
    local path_or_command="$3"
    local expected="$4"

    ((components_total++))

    echo "Checking $component..."

    case "$check_type" in
        "file_exists")
            if [ -f "$path_or_command" ]; then
                echo "✅ $component: File exists"
                ((components_valid++))
                jq --arg comp "$component" --arg status "valid" --arg detail "File exists at $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail}' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            else
                echo "❌ $component: File missing ($path_or_command)"
                ((issues_found++))
                jq --arg comp "$component" --arg status "invalid" --arg detail "File missing: $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail} | .issues += ["Missing file: " + $path_or_command]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
            ;;
        "executable")
            if [ -x "$path_or_command" ]; then
                echo "✅ $component: Executable"
                ((components_valid++))
                jq --arg comp "$component" --arg status "valid" --arg detail "Executable script at $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail}' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            else
                echo "❌ $component: Not executable ($path_or_command)"
                ((issues_found++))
                jq --arg comp "$component" --arg status "invalid" --arg detail "Script not executable: $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail} | .issues += ["Script not executable: " + $path_or_command]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
            ;;
        "command")
            if command -v "$path_or_command" &> /dev/null; then
                echo "✅ $component: Command available"
                ((components_valid++))
                jq --arg comp "$component" --arg status "valid" --arg detail "Command available: $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail}' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            else
                echo "❌ $component: Command not found ($path_or_command)"
                ((issues_found++))
                jq --arg comp "$component" --arg status "invalid" --arg detail "Command not found: $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail} | .issues += ["Command not found: " + $path_or_command]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
            ;;
        "directory")
            if [ -d "$path_or_command" ]; then
                echo "✅ $component: Directory exists"
                ((components_valid++))
                jq --arg comp "$component" --arg status "valid" --arg detail "Directory exists at $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail}' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            else
                echo "❌ $component: Directory missing ($path_or_command)"
                ((issues_found++))
                jq --arg comp "$component" --arg status "invalid" --arg detail "Directory missing: $path_or_command" \
                   '.components[$comp] = {"status": $status, "detail": $detail} | .issues += ["Directory missing: " + $path_or_command]' \
                   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
            fi
            ;;
    esac
}

echo "=== Validating GitHub Actions Workflows ==="
validate_component "Main CI Workflow" "file_exists" ".github/workflows/ci.yml" ""
validate_component "Nightly Workflow" "file_exists" ".github/workflows/nightly.yml" ""

echo "=== Validating CI Scripts Directory ==="
validate_component "CI Scripts Directory" "directory" "scripts/ci" ""

echo "=== Validating Validation Scripts ==="
validate_component "YAML Validation" "executable" "scripts/ci/validate-yaml.sh" ""
validate_component "K8s Validation" "executable" "scripts/ci/validate-k8s-manifests.sh" ""
validate_component "KPT Validation" "executable" "scripts/ci/validate-kpt-packages.sh" ""
validate_component "Policy Validation" "executable" "scripts/ci/validate-policies.sh" ""

echo "=== Validating Test Scripts ==="
validate_component "Unit Tests" "executable" "scripts/ci/run-unit-tests.sh" ""
validate_component "Integration Tests" "executable" "scripts/ci/run-integration-tests.sh" ""
validate_component "Smoke Tests" "executable" "scripts/ci/run-smoke-tests.sh" ""

echo "=== Validating GitOps Scripts ==="
validate_component "GitOps Deploy" "executable" "scripts/ci/deploy-to-gitops.sh" ""
validate_component "GitOps Verify" "executable" "scripts/ci/verify-gitops-deployment.sh" ""

echo "=== Validating Rollback Scripts ==="
validate_component "Enhanced Rollback" "executable" "scripts/ci/enhanced-rollback.sh" ""

echo "=== Validating Support Scripts ==="
validate_component "Smoke Test Setup" "executable" "scripts/ci/setup-smoke-test-env.sh" ""
validate_component "Deployment Report" "executable" "scripts/ci/generate-deployment-report.sh" ""

echo "=== Validating Dependencies ==="
validate_component "Git" "command" "git" ""
validate_component "Python3" "command" "python3" ""
validate_component "JQ" "command" "jq" ""

echo "=== Validating Project Structure ==="
validate_component "GitOps Directory" "directory" "gitops" ""
validate_component "Artifacts Directory" "directory" "artifacts" ""
validate_component "Tools Directory" "directory" "tools" ""
validate_component "Intent Compiler" "file_exists" "tools/intent-compiler/translate.py" ""

# Update summary
jq --arg total "$components_total" --arg valid "$components_valid" --arg issues "$issues_found" \
   '.summary.total_components = ($total | tonumber) |
    .summary.valid_components = ($valid | tonumber) |
    .summary.issues_found = ($issues | tonumber) |
    .summary.setup_complete = (($issues | tonumber) == 0)' \
   "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"

# Generate recommendations
recommendations=()

if [ $issues_found -gt 0 ]; then
    recommendations+=("Fix the identified issues before running CI/CD pipeline")
    recommendations+=("Ensure all scripts have proper execute permissions: chmod +x scripts/ci/*.sh")
    recommendations+=("Install missing dependencies using package manager")
else
    recommendations+=("CI/CD setup is complete and ready for use")
    recommendations+=("Consider running a test deployment to verify end-to-end functionality")
    recommendations+=("Setup GitHub repository secrets for GITEA_TOKEN and GITEA_URL")
fi

recommendations+=("Regularly update dependencies and review security settings")
recommendations+=("Monitor CI/CD pipeline performance and optimize as needed")

# Add recommendations to report
for rec in "${recommendations[@]}"; do
    jq --arg rec "$rec" '.recommendations += [$rec]' \
       "$VALIDATION_REPORT" > "${VALIDATION_REPORT}.tmp" && mv "${VALIDATION_REPORT}.tmp" "$VALIDATION_REPORT"
done

# Generate summary
echo
echo "🎯 CI/CD Pipeline Setup Validation Summary"
echo "============================================"
echo "📊 Total Components: $components_total"
echo "✅ Valid Components: $components_valid"
echo "❌ Issues Found: $issues_found"

if [ $issues_found -eq 0 ]; then
    echo "🎉 Setup Complete: YES"
    echo
    echo "🚀 Your CI/CD pipeline is ready!"
    echo "   • All workflows and scripts are in place"
    echo "   • Dependencies are available"
    echo "   • Project structure is correct"
    echo
    echo "📋 Next Steps:"
    echo "   1. Set up GitHub repository secrets (GITEA_TOKEN, GITEA_URL)"
    echo "   2. Test the pipeline with a small change"
    echo "   3. Monitor the first few CI/CD runs"
else
    echo "⚠️  Setup Complete: NO"
    echo
    echo "🔧 Issues to Fix:"
    jq -r '.issues[]' "$VALIDATION_REPORT" | sed 's/^/   • /'
    echo
    echo "📋 Recommendations:"
    jq -r '.recommendations[]' "$VALIDATION_REPORT" | sed 's/^/   • /'
fi

echo
echo "📄 Detailed report: $VALIDATION_REPORT"

# Create quick reference guide
cat > "${REPO_ROOT}/CI_CD_QUICK_START.md" << 'EOF'
# CI/CD Quick Start Guide

## Prerequisites

1. Set up GitHub repository secrets:
   ```
   GITEA_TOKEN=<your-gitea-access-token>
   GITEA_URL=http://172.18.0.2:30924/admin1/edge2-config
   ```

2. Ensure all dependencies are installed:
   ```bash
   pip install yamllint jsonschema kubernetes pyyaml pytest pytest-cov
   ```

## Quick Test

Run local validation:
```bash
./scripts/ci/validate-yaml.sh
./scripts/ci/run-smoke-tests.sh
```

## Trigger CI/CD

1. Make a change to `gitops/`, `k8s/`, `packages/`, `tools/`, or `scripts/`
2. Commit and push to `main` or `develop` branch
3. Create pull request to `main` branch

## Manual Operations

Deploy to GitOps:
```bash
export GITEA_TOKEN="your-token"
export GITEA_URL="http://172.18.0.2:30924/admin1/edge2-config"
./scripts/ci/deploy-to-gitops.sh
```

Trigger rollback:
```bash
./scripts/ci/enhanced-rollback.sh deployment_failure
```

## Monitoring

- Check GitHub Actions tab for pipeline status
- Review artifacts in `artifacts/` directory
- Monitor GitOps repositories for sync status

## Documentation

- Full documentation: `docs/CI_CD_Pipeline.md`
- Validation report: `artifacts/cicd-setup-validation.json`
EOF

echo "💡 Quick start guide created: CI_CD_QUICK_START.md"

exit $issues_found