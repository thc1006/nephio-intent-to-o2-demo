#!/bin/bash

# CI/CD Pipeline - GitOps Deployment Script
# Deploys configurations to Gitea repositories

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_REPORT="${REPO_ROOT}/artifacts/gitops-deploy-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$DEPLOY_REPORT")"

echo "::notice::Starting GitOps deployment..."

cd "$REPO_ROOT"

# Initialize deployment report
cat > "$DEPLOY_REPORT" << 'EOF'
{
  "deployment_type": "gitops",
  "timestamp": "",
  "repositories": [],
  "deployments": [],
  "errors": [],
  "summary": {
    "total_repos": 0,
    "successful_deploys": 0,
    "failed_deploys": 0
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"

# Check environment variables
if [ -z "${GITEA_TOKEN:-}" ]; then
    echo "❌ GITEA_TOKEN environment variable not set"
    jq '.errors += ["GITEA_TOKEN environment variable not set"]' "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"
    exit 1
fi

if [ -z "${GITEA_URL:-}" ]; then
    echo "❌ GITEA_URL environment variable not set"
    jq '.errors += ["GITEA_URL environment variable not set"]' "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"
    exit 1
fi

# Parse Gitea URL to extract components
GITEA_BASE_URL="${GITEA_URL%/*}"
GITEA_USER="admin1"

echo "Gitea URL: $GITEA_BASE_URL"
echo "Gitea User: $GITEA_USER"

# Function to deploy to a GitOps repository
deploy_to_repo() {
    local site="$1"
    local source_dir="gitops/${site}-config"
    local repo_name="${site}-config"
    local commit_message="$2"

    echo "=== Deploying to $repo_name ==="

    # Check if source directory exists
    if [ ! -d "$source_dir" ]; then
        echo "⚠️  Source directory $source_dir not found, skipping $site"
        return 0
    fi

    # Create temporary directory for Git operations
    local temp_repo_dir=$(mktemp -d)
    trap "rm -rf $temp_repo_dir" RETURN

    # Clone the target repository
    echo "Cloning repository $repo_name..."
    local repo_url="${GITEA_BASE_URL}/${GITEA_USER}/${repo_name}.git"

    if git clone "https://${GITEA_USER}:${GITEA_TOKEN}@${repo_url#https://}" "$temp_repo_dir" >/dev/null 2>&1; then
        echo "✅ Successfully cloned $repo_name"
    else
        echo "❌ Failed to clone $repo_name"
        jq --arg repo "$repo_name" --arg error "Failed to clone repository" \
           '.errors += ["Failed to clone repository: " + $repo] | .summary.failed_deploys += 1' \
           "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"
        EXIT_CODE=1
        return 1
    fi

    cd "$temp_repo_dir"

    # Sync files from source to repository
    echo "Syncing files to $repo_name..."
    rsync -av --delete --exclude='.git' "$REPO_ROOT/$source_dir/" ./

    # Check if there are changes
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️  No changes detected in $repo_name"

        # Update deployment report
        jq --arg repo "$repo_name" --arg status "no_changes" \
           '.deployments += [{"repository": $repo, "status": $status, "commit": null}]' \
           "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"

        cd - >/dev/null
        return 0
    fi

    # Stage all changes
    git add .

    # Get commit hash for tracking
    local current_commit=$(git rev-parse HEAD)

    # Commit changes
    if git commit -m "$commit_message"; then
        echo "✅ Committed changes to $repo_name"

        # Push changes
        if git push origin main; then
            echo "✅ Successfully pushed to $repo_name"

            # Get new commit hash
            local new_commit=$(git rev-parse HEAD)

            # Update deployment report
            jq --arg repo "$repo_name" --arg status "success" --arg commit "$new_commit" \
               '.deployments += [{"repository": $repo, "status": $status, "commit": $commit}] | .summary.successful_deploys += 1' \
               "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"

        else
            echo "❌ Failed to push to $repo_name"
            jq --arg repo "$repo_name" --arg error "Failed to push changes" \
               '.errors += ["Failed to push to repository: " + $repo] | .summary.failed_deploys += 1' \
               "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"
            EXIT_CODE=1
        fi
    else
        echo "❌ Failed to commit changes to $repo_name"
        jq --arg repo "$repo_name" --arg error "Failed to commit changes" \
           '.errors += ["Failed to commit changes to repository: " + $repo] | .summary.failed_deploys += 1' \
           "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"
        EXIT_CODE=1
    fi

    cd - >/dev/null
}

# Function to validate repository access
validate_repo_access() {
    local repo_name="$1"
    local repo_url="${GITEA_BASE_URL}/${GITEA_USER}/${repo_name}.git"

    echo "Validating access to $repo_name..."

    # Test repository access using git ls-remote
    if git ls-remote "https://${GITEA_USER}:${GITEA_TOKEN}@${repo_url#https://}" >/dev/null 2>&1; then
        echo "✅ Repository $repo_name is accessible"

        # Add to repositories list
        jq --arg repo "$repo_name" --arg url "$repo_url" --arg status "accessible" \
           '.repositories += [{"name": $repo, "url": $url, "status": $status}] | .summary.total_repos += 1' \
           "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"

        return 0
    else
        echo "❌ Repository $repo_name is not accessible"

        # Add to repositories list with error status
        jq --arg repo "$repo_name" --arg url "$repo_url" --arg status "error" \
           '.repositories += [{"name": $repo, "url": $url, "status": $status}] | .summary.total_repos += 1' \
           "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"

        jq --arg repo "$repo_name" --arg error "Repository not accessible" \
           '.errors += ["Repository not accessible: " + $repo]' \
           "$DEPLOY_REPORT" > "${DEPLOY_REPORT}.tmp" && mv "${DEPLOY_REPORT}.tmp" "$DEPLOY_REPORT"

        return 1
    fi
}

# Generate commit message
COMMIT_MESSAGE="CI/CD: Automated deployment from $(git rev-parse --short HEAD) at $(date -Iseconds)"

echo "Commit message: $COMMIT_MESSAGE"

# Validate access to target repositories
echo "=== Validating Repository Access ==="

target_repos=("edge1-config" "edge2-config")
accessible_repos=()

for repo in "${target_repos[@]}"; do
    if validate_repo_access "$repo"; then
        accessible_repos+=("$repo")
    else
        EXIT_CODE=1
    fi
done

if [ ${#accessible_repos[@]} -eq 0 ]; then
    echo "❌ No accessible repositories found"
    exit 1
fi

# Deploy to accessible repositories
echo "=== Deploying to GitOps Repositories ==="

for repo in "${accessible_repos[@]}"; do
    site="${repo%-config}"
    deploy_to_repo "$site" "$COMMIT_MESSAGE"
done

# Trigger Config Sync (if available)
echo "=== Triggering Config Sync ==="

# This is a placeholder for Config Sync triggering
# In a real environment, you might:
# 1. Create/update RootSync or RepoSync resources
# 2. Send webhook notifications
# 3. Update ArgoCD applications

echo "ℹ️  Config Sync triggering would happen here in a real environment"

# Generate deployment summary
echo
echo "GitOps Deployment Summary:"
total_repos=$(jq -r '.summary.total_repos' "$DEPLOY_REPORT")
successful_deploys=$(jq -r '.summary.successful_deploys' "$DEPLOY_REPORT")
failed_deploys=$(jq -r '.summary.failed_deploys' "$DEPLOY_REPORT")

echo "📊 Total repositories: $total_repos"
echo "✅ Successful deployments: $successful_deploys"
echo "❌ Failed deployments: $failed_deploys"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 GitOps deployment completed successfully!"
else
    echo "💥 GitOps deployment failed. Check the report at: $DEPLOY_REPORT"
fi

exit $EXIT_CODE