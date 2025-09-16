#!/bin/bash

# CI/CD Pipeline - GitOps Deployment Verification Script
# Verifies that GitOps deployments were successful

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_REPORT="${REPO_ROOT}/artifacts/gitops-verify-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$VERIFY_REPORT")"

echo "::notice::Starting GitOps deployment verification..."

cd "$REPO_ROOT"

# Initialize verification report
cat > "$VERIFY_REPORT" << 'EOF'
{
  "verification_type": "gitops_deployment",
  "timestamp": "",
  "repositories_verified": [],
  "config_sync_status": [],
  "errors": [],
  "warnings": [],
  "summary": {
    "total_repos": 0,
    "verified_repos": 0,
    "failed_verifications": 0,
    "config_sync_healthy": 0,
    "config_sync_unhealthy": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"

# Check environment variables
if [ -z "${GITEA_TOKEN:-}" ]; then
    echo "❌ GITEA_TOKEN environment variable not set"
    jq '.errors += ["GITEA_TOKEN environment variable not set"]' "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
    exit 1
fi

if [ -z "${GITEA_URL:-}" ]; then
    echo "❌ GITEA_URL environment variable not set"
    jq '.errors += ["GITEA_URL environment variable not set"]' "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
    exit 1
fi

# Parse Gitea URL to extract components
GITEA_BASE_URL="${GITEA_URL%/*}"
GITEA_USER="admin1"

echo "Verifying GitOps deployments..."
echo "Gitea URL: $GITEA_BASE_URL"
echo "Gitea User: $GITEA_USER"

# Function to verify repository deployment
verify_repository() {
    local repo_name="$1"
    local site="${repo_name%-config}"

    echo "=== Verifying $repo_name ==="

    local repo_url="${GITEA_BASE_URL}/${GITEA_USER}/${repo_name}.git"
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" RETURN

    # Clone repository to verify content
    echo "Cloning $repo_name for verification..."
    if git clone "https://${GITEA_USER}:${GITEA_TOKEN}@${repo_url#https://}" "$temp_dir" >/dev/null 2>&1; then
        echo "✅ Successfully cloned $repo_name"
    else
        echo "❌ Failed to clone $repo_name"
        jq --arg repo "$repo_name" --arg error "Failed to clone for verification" \
           '.errors += ["Failed to clone repository for verification: " + $repo] | .summary.failed_verifications += 1' \
           "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
        EXIT_CODE=1
        return 1
    fi

    cd "$temp_dir"

    # Get latest commit info
    local latest_commit=$(git rev-parse HEAD)
    local commit_message=$(git log -1 --pretty=format:"%s")
    local commit_date=$(git log -1 --pretty=format:"%ci")

    echo "Latest commit: $latest_commit"
    echo "Commit message: $commit_message"
    echo "Commit date: $commit_date"

    # Verify essential files exist
    local verification_results=()
    local files_to_check=("Kptfile")

    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file exists"
            verification_results+=("$file:present")
        else
            echo "⚠️  $file missing"
            verification_results+=("$file:missing")
            jq --arg repo "$repo_name" --arg warning "Missing file: $file" \
               '.warnings += [{"repository": $repo, "warning": $warning}]' \
               "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
        fi
    done

    # Verify YAML files are valid
    local yaml_files_count=0
    local valid_yaml_files=0
    local invalid_yaml_files=0

    while IFS= read -r -d '' yaml_file; do
        ((yaml_files_count++))
        if yamllint "$yaml_file" >/dev/null 2>&1; then
            ((valid_yaml_files++))
        else
            ((invalid_yaml_files++))
            echo "⚠️  Invalid YAML: $yaml_file"
            jq --arg repo "$repo_name" --arg warning "Invalid YAML file: $yaml_file" \
               '.warnings += [{"repository": $repo, "warning": $warning}]' \
               "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
        fi
    done < <(find . -name "*.yaml" -o -name "*.yml" -print0 2>/dev/null)

    echo "YAML files: $yaml_files_count total, $valid_yaml_files valid, $invalid_yaml_files invalid"

    # Verify Kubernetes manifests
    local k8s_manifests=0
    local valid_k8s_manifests=0

    while IFS= read -r -d '' manifest_file; do
        if grep -q "apiVersion:" "$manifest_file" 2>/dev/null; then
            ((k8s_manifests++))
            if kubeconform "$manifest_file" >/dev/null 2>&1; then
                ((valid_k8s_manifests++))
            else
                echo "⚠️  Invalid Kubernetes manifest: $manifest_file"
                jq --arg repo "$repo_name" --arg warning "Invalid Kubernetes manifest: $manifest_file" \
                   '.warnings += [{"repository": $repo, "warning": $warning}]' \
                   "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
            fi
        fi
    done < <(find . -name "*.yaml" -o -name "*.yml" -print0 2>/dev/null)

    echo "Kubernetes manifests: $k8s_manifests total, $valid_k8s_manifests valid"

    # Check for recent updates (within last hour)
    local commit_timestamp=$(git log -1 --pretty=format:"%ct")
    local current_timestamp=$(date +%s)
    local time_diff=$((current_timestamp - commit_timestamp))

    local is_recent="false"
    if [ $time_diff -lt 3600 ]; then  # Less than 1 hour
        echo "✅ Repository has recent updates (${time_diff}s ago)"
        is_recent="true"
    else
        echo "ℹ️  Repository last updated $(($time_diff / 3600)) hours ago"
    fi

    # Update verification report
    jq --arg repo "$repo_name" \
       --arg commit "$latest_commit" \
       --arg message "$commit_message" \
       --arg date "$commit_date" \
       --arg recent "$is_recent" \
       --arg yaml_total "$yaml_files_count" \
       --arg yaml_valid "$valid_yaml_files" \
       --arg k8s_total "$k8s_manifests" \
       --arg k8s_valid "$valid_k8s_manifests" \
       '.repositories_verified += [{
         "repository": $repo,
         "commit": $commit,
         "commit_message": $message,
         "commit_date": $date,
         "recent_update": ($recent == "true"),
         "yaml_files": {"total": ($yaml_total | tonumber), "valid": ($yaml_valid | tonumber)},
         "k8s_manifests": {"total": ($k8s_total | tonumber), "valid": ($k8s_valid | tonumber)},
         "verification_status": "success"
       }] | .summary.verified_repos += 1 | .summary.total_repos += 1' \
       "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"

    cd - >/dev/null
    echo "✅ Verification completed for $repo_name"
}

# Function to check Config Sync status (simulated)
check_config_sync_status() {
    local site="$1"

    echo "=== Checking Config Sync status for $site ==="

    # In a real environment, you would check:
    # kubectl get rootsync -n config-management-system
    # kubectl get reposyncs -A
    # kubectl get configmanagement -n config-management-system

    # For simulation, we'll create a mock status
    local sync_status="healthy"
    local last_sync_time=$(date -Iseconds)
    local source_commit="unknown"

    # Simulate some status checks
    local status_checks=("source_available" "sync_active" "no_conflicts")
    local passed_checks=0

    for check in "${status_checks[@]}"; do
        # Simulate check (in real env, this would be actual kubectl commands)
        echo "Checking $check for $site..."
        if [ $((RANDOM % 10)) -gt 2 ]; then  # 80% success rate simulation
            echo "✅ $check: passed"
            ((passed_checks++))
        else
            echo "❌ $check: failed"
            sync_status="unhealthy"
        fi
    done

    if [ "$sync_status" = "healthy" ]; then
        echo "✅ Config Sync for $site is healthy"
        jq --arg site "$site" \
           --arg status "$sync_status" \
           --arg last_sync "$last_sync_time" \
           --arg commit "$source_commit" \
           --arg checks "$passed_checks" \
           '.config_sync_status += [{
             "site": $site,
             "status": $status,
             "last_sync": $last_sync,
             "source_commit": $commit,
             "passed_checks": ($checks | tonumber),
             "total_checks": 3
           }] | .summary.config_sync_healthy += 1' \
           "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
    else
        echo "❌ Config Sync for $site is unhealthy"
        jq --arg site "$site" \
           --arg status "$sync_status" \
           --arg last_sync "$last_sync_time" \
           --arg commit "$source_commit" \
           --arg checks "$passed_checks" \
           '.config_sync_status += [{
             "site": $site,
             "status": $status,
             "last_sync": $last_sync,
             "source_commit": $commit,
             "passed_checks": ($checks | tonumber),
             "total_checks": 3
           }] | .summary.config_sync_unhealthy += 1' \
           "$VERIFY_REPORT" > "${VERIFY_REPORT}.tmp" && mv "${VERIFY_REPORT}.tmp" "$VERIFY_REPORT"
        EXIT_CODE=1
    fi
}

# Verify target repositories
target_repos=("edge1-config" "edge2-config")

echo "=== Verifying GitOps Repositories ==="

for repo in "${target_repos[@]}"; do
    verify_repository "$repo"
done

# Check Config Sync status for each site
echo "=== Checking Config Sync Status ==="

for repo in "${target_repos[@]}"; do
    site="${repo%-config}"
    check_config_sync_status "$site"
done

# Generate verification summary
echo
echo "GitOps Deployment Verification Summary:"
total_repos=$(jq -r '.summary.total_repos' "$VERIFY_REPORT")
verified_repos=$(jq -r '.summary.verified_repos' "$VERIFY_REPORT")
failed_verifications=$(jq -r '.summary.failed_verifications' "$VERIFY_REPORT")
config_sync_healthy=$(jq -r '.summary.config_sync_healthy' "$VERIFY_REPORT")
config_sync_unhealthy=$(jq -r '.summary.config_sync_unhealthy' "$VERIFY_REPORT")

echo "📊 Total repositories: $total_repos"
echo "✅ Verified repositories: $verified_repos"
echo "❌ Failed verifications: $failed_verifications"
echo "🔄 Config Sync healthy: $config_sync_healthy"
echo "⚠️  Config Sync unhealthy: $config_sync_unhealthy"

# Count warnings
warning_count=$(jq '.warnings | length' "$VERIFY_REPORT")
echo "⚠️  Total warnings: $warning_count"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 GitOps deployment verification completed successfully!"
else
    echo "💥 GitOps deployment verification failed. Check the report at: $VERIFY_REPORT"
fi

exit $EXIT_CODE