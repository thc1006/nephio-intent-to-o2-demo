#!/bin/bash

# CI/CD Pipeline - Deployment Report Generator
# Generates comprehensive deployment report

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOYMENT_REPORT="${REPO_ROOT}/artifacts/deployment-report.json"
TIMESTAMP=$(date -Iseconds)

echo "::notice::Generating deployment report..."

cd "$REPO_ROOT"

# Collect all CI/CD artifacts
validation_report="${REPO_ROOT}/artifacts/yaml-validation-report.json"
k8s_validation_report="${REPO_ROOT}/artifacts/k8s-validation-report.json"
kpt_validation_report="${REPO_ROOT}/artifacts/kpt-validation-report.json"
policy_validation_report="${REPO_ROOT}/artifacts/policy-validation-report.json"
unit_test_report="${REPO_ROOT}/artifacts/unit-test-report.json"
integration_test_report="${REPO_ROOT}/artifacts/integration-test-report.json"
smoke_test_report="${REPO_ROOT}/artifacts/smoke-test-report.json"
gitops_deploy_report="${REPO_ROOT}/artifacts/gitops-deploy-report.json"
gitops_verify_report="${REPO_ROOT}/artifacts/gitops-verify-report.json"

# Initialize comprehensive report
cat > "$DEPLOYMENT_REPORT" << EOF
{
  "deployment_id": "$(uuidgen 2>/dev/null || echo "deploy-$(date +%s)")",
  "timestamp": "$TIMESTAMP",
  "git_info": {
    "branch": "$(git rev-parse --abbrev-ref HEAD)",
    "commit": "$(git rev-parse HEAD)",
    "commit_message": "$(git log -1 --pretty=format:'%s')",
    "commit_author": "$(git log -1 --pretty=format:'%an <%ae>')",
    "commit_date": "$(git log -1 --pretty=format:'%ci')"
  },
  "pipeline_stages": {},
  "overall_summary": {
    "total_stages": 0,
    "passed_stages": 0,
    "failed_stages": 0,
    "warnings": 0,
    "deployment_successful": false
  },
  "artifacts": [],
  "recommendations": []
}
EOF

# Function to add stage result
add_stage_result() {
    local stage_name="$1"
    local report_file="$2"
    local stage_status="success"

    if [ -f "$report_file" ]; then
        echo "Processing $stage_name report..."

        # Extract summary from each report type
        case "$stage_name" in
            "yaml_validation")
                local failed=$(jq -r '.summary.failed // 0' "$report_file")
                local passed=$(jq -r '.summary.passed // 0' "$report_file")
                [ "$failed" -gt 0 ] && stage_status="failed"
                ;;
            "k8s_validation"|"kpt_validation"|"policy_validation")
                local failed=$(jq -r '.summary.failed // 0' "$report_file")
                [ "$failed" -gt 0 ] && stage_status="failed"
                ;;
            "unit_tests"|"integration_tests"|"smoke_tests")
                local failed=$(jq -r '.summary.failed // 0' "$report_file")
                [ "$failed" -gt 0 ] && stage_status="failed"
                ;;
            "gitops_deploy"|"gitops_verify")
                local failed=$(jq -r '.summary.failed_deploys // .summary.failed_verifications // 0' "$report_file")
                [ "$failed" -gt 0 ] && stage_status="failed"
                ;;
        esac

        # Add stage to report
        jq --arg stage "$stage_name" \
           --arg status "$stage_status" \
           --slurpfile stage_data "$report_file" \
           '.pipeline_stages[$stage] = {"status": $status, "data": $stage_data[0]} |
            .overall_summary.total_stages += 1 |
            if $status == "success" then .overall_summary.passed_stages += 1 else .overall_summary.failed_stages += 1 end' \
           "$DEPLOYMENT_REPORT" > "${DEPLOYMENT_REPORT}.tmp" && mv "${DEPLOYMENT_REPORT}.tmp" "$DEPLOYMENT_REPORT"

        # Add to artifacts list
        jq --arg artifact "$(basename "$report_file")" --arg path "$report_file" \
           '.artifacts += [{"name": $artifact, "path": $path, "stage": "'$stage_name'"}]' \
           "$DEPLOYMENT_REPORT" > "${DEPLOYMENT_REPORT}.tmp" && mv "${DEPLOYMENT_REPORT}.tmp" "$DEPLOYMENT_REPORT"

        echo "✅ Added $stage_name to deployment report"
    else
        echo "⚠️  $stage_name report not found: $report_file"

        # Add missing stage
        jq --arg stage "$stage_name" \
           '.pipeline_stages[$stage] = {"status": "skipped", "data": null} |
            .overall_summary.total_stages += 1' \
           "$DEPLOYMENT_REPORT" > "${DEPLOYMENT_REPORT}.tmp" && mv "${DEPLOYMENT_REPORT}.tmp" "$DEPLOYMENT_REPORT"
    fi
}

# Process all CI/CD reports
echo "=== Processing CI/CD Reports ==="

add_stage_result "yaml_validation" "$validation_report"
add_stage_result "k8s_validation" "$k8s_validation_report"
add_stage_result "kpt_validation" "$kpt_validation_report"
add_stage_result "policy_validation" "$policy_validation_report"
add_stage_result "unit_tests" "$unit_test_report"
add_stage_result "integration_tests" "$integration_test_report"
add_stage_result "smoke_tests" "$smoke_test_report"
add_stage_result "gitops_deploy" "$gitops_deploy_report"
add_stage_result "gitops_verify" "$gitops_verify_report"

# Calculate overall deployment success
failed_stages=$(jq -r '.overall_summary.failed_stages' "$DEPLOYMENT_REPORT")
if [ "$failed_stages" -eq 0 ]; then
    jq '.overall_summary.deployment_successful = true' "$DEPLOYMENT_REPORT" > "${DEPLOYMENT_REPORT}.tmp" && mv "${DEPLOYMENT_REPORT}.tmp" "$DEPLOYMENT_REPORT"
fi

# Add environment information
environment_info=$(jq -n \
    --arg os "$(uname -s)" \
    --arg kernel "$(uname -r)" \
    --arg arch "$(uname -m)" \
    --arg python "$(python3 --version 2>&1)" \
    --arg git "$(git --version)" \
    '{
        "operating_system": $os,
        "kernel_version": $kernel,
        "architecture": $arch,
        "python_version": $python,
        "git_version": $git
    }')

jq --argjson env "$environment_info" '.environment = $env' \
   "$DEPLOYMENT_REPORT" > "${DEPLOYMENT_REPORT}.tmp" && mv "${DEPLOYMENT_REPORT}.tmp" "$DEPLOYMENT_REPORT"

# Generate recommendations based on results
echo "=== Generating Recommendations ==="

recommendations=()

# Check for validation failures
if [ "$(jq -r '.pipeline_stages.yaml_validation.status // "success"' "$DEPLOYMENT_REPORT")" = "failed" ]; then
    recommendations+=("Fix YAML syntax errors before proceeding with future deployments")
fi

if [ "$(jq -r '.pipeline_stages.k8s_validation.status // "success"' "$DEPLOYMENT_REPORT")" = "failed" ]; then
    recommendations+=("Address Kubernetes manifest validation errors")
fi

if [ "$(jq -r '.pipeline_stages.policy_validation.status // "success"' "$DEPLOYMENT_REPORT")" = "failed" ]; then
    recommendations+=("Review and fix policy violations for security compliance")
fi

# Check for test failures
if [ "$(jq -r '.pipeline_stages.unit_tests.status // "success"' "$DEPLOYMENT_REPORT")" = "failed" ]; then
    recommendations+=("Fix failing unit tests to ensure code quality")
fi

if [ "$(jq -r '.pipeline_stages.integration_tests.status // "success"' "$DEPLOYMENT_REPORT")" = "failed" ]; then
    recommendations+=("Address integration test failures for system reliability")
fi

# Check for deployment issues
if [ "$(jq -r '.pipeline_stages.gitops_deploy.status // "success"' "$DEPLOYMENT_REPORT")" = "failed" ]; then
    recommendations+=("Review GitOps deployment configuration and access permissions")
fi

# Add general recommendations for successful deployments
if [ "$failed_stages" -eq 0 ]; then
    recommendations+=("Deployment successful - monitor applications for runtime issues")
    recommendations+=("Consider running post-deployment health checks")
else
    recommendations+=("Review failed stages and implement fixes before retry")
    recommendations+=("Consider implementing additional pre-deployment validations")
fi

# Add recommendations to report
for rec in "${recommendations[@]}"; do
    jq --arg rec "$rec" '.recommendations += [$rec]' \
       "$DEPLOYMENT_REPORT" > "${DEPLOYMENT_REPORT}.tmp" && mv "${DEPLOYMENT_REPORT}.tmp" "$DEPLOYMENT_REPORT"
done

# Generate human-readable summary
cat > "${REPO_ROOT}/artifacts/deployment-summary.txt" << EOF
Deployment Report Summary
========================

Deployment ID: $(jq -r '.deployment_id' "$DEPLOYMENT_REPORT")
Timestamp: $TIMESTAMP
Git Commit: $(jq -r '.git_info.commit' "$DEPLOYMENT_REPORT")
Branch: $(jq -r '.git_info.branch' "$DEPLOYMENT_REPORT")

Pipeline Results:
$(jq -r '.overall_summary | "Total Stages: \(.total_stages)\nPassed: \(.passed_stages)\nFailed: \(.failed_stages)\nDeployment Successful: \(.deployment_successful)"' "$DEPLOYMENT_REPORT")

Stage Status:
$(jq -r '.pipeline_stages | to_entries[] | "- \(.key): \(.value.status)"' "$DEPLOYMENT_REPORT")

Recommendations:
$(jq -r '.recommendations[] | "- \(.)"' "$DEPLOYMENT_REPORT")

Artifacts:
$(jq -r '.artifacts[] | "- \(.name) (\(.stage))"' "$DEPLOYMENT_REPORT")

Full Report: $DEPLOYMENT_REPORT
EOF

echo
echo "Deployment Report Generated:"
echo "📊 Full report: $DEPLOYMENT_REPORT"
echo "📋 Summary: ${REPO_ROOT}/artifacts/deployment-summary.txt"

# Display summary
cat "${REPO_ROOT}/artifacts/deployment-summary.txt"

echo "✅ Deployment report generation completed"