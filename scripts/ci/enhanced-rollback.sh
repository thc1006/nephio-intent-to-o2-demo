#!/bin/bash

# CI/CD Pipeline - Enhanced Rollback Script
# Advanced rollback mechanism with safety checks and validation

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROLLBACK_REPORT="${REPO_ROOT}/artifacts/rollback-report.json"
EXIT_CODE=0

# Ensure artifacts directory exists
mkdir -p "$(dirname "$ROLLBACK_REPORT")"

echo "::notice::Starting enhanced rollback process..."

cd "$REPO_ROOT"

# Initialize rollback report
cat > "$ROLLBACK_REPORT" << 'EOF'
{
  "rollback_type": "enhanced_automatic",
  "timestamp": "",
  "trigger_reason": "",
  "pre_rollback_snapshot": {},
  "rollback_actions": [],
  "post_rollback_verification": {},
  "errors": [],
  "warnings": [],
  "summary": {
    "total_actions": 0,
    "successful_actions": 0,
    "failed_actions": 0,
    "rollback_successful": false
  }
}
EOF

# Update timestamp
jq --arg ts "$(date -Iseconds)" '.timestamp = $ts' "$ROLLBACK_REPORT" > "${ROLLBACK_REPORT}.tmp" && mv "${ROLLBACK_REPORT}.tmp" "$ROLLBACK_REPORT"

# Function to log rollback action
log_rollback_action() {
    local action="$1"
    local status="$2"
    local details="$3"

    echo "Rollback action: $action - $status"
    if [ "$status" != "success" ]; then
        echo "Details: $details"
    fi

    jq --arg action "$action" --arg status "$status" --arg details "$details" \
       '.rollback_actions += [{"action": $action, "status": $status, "details": $details, "timestamp": now}] |
        .summary.total_actions += 1 |
        if $status == "success" then .summary.successful_actions += 1 else .summary.failed_actions += 1 end' \
       "$ROLLBACK_REPORT" > "${ROLLBACK_REPORT}.tmp" && mv "${ROLLBACK_REPORT}.tmp" "$ROLLBACK_REPORT"
}

# Function to create pre-rollback snapshot
create_snapshot() {
    echo "=== Creating Pre-Rollback Snapshot ==="

    local snapshot={}

    # Capture current Git state
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local current_commit=$(git rev-parse HEAD)
    local current_commit_msg=$(git log -1 --pretty=format:"%s")

    # Capture repository state
    local repo_files_count=$(find . -type f ! -path "./.git/*" | wc -l)
    local modified_files=$(git diff --name-only | wc -l)
    local staged_files=$(git diff --cached --name-only | wc -l)
    local untracked_files=$(git ls-files --others --exclude-standard | wc -l)

    # Capture GitOps repository states (if accessible)
    local gitops_states=()

    if [ -n "${GITEA_TOKEN:-}" ] && [ -n "${GITEA_URL:-}" ]; then
        local gitea_base_url="${GITEA_URL%/*}"
        local gitea_user="admin1"

        for repo in "edge1-config" "edge2-config"; do
            local repo_url="${gitea_base_url}/${gitea_user}/${repo}.git"
            local temp_dir=$(mktemp -d)

            if git clone "https://${gitea_user}:${GITEA_TOKEN}@${repo_url#https://}" "$temp_dir" >/dev/null 2>&1; then
                cd "$temp_dir"
                local gitops_commit=$(git rev-parse HEAD)
                local gitops_commit_msg=$(git log -1 --pretty=format:"%s")
                cd - >/dev/null

                gitops_states+=("{\"repository\": \"$repo\", \"commit\": \"$gitops_commit\", \"message\": \"$gitops_commit_msg\"}")
                rm -rf "$temp_dir"
            else
                gitops_states+=("{\"repository\": \"$repo\", \"commit\": \"unknown\", \"message\": \"failed_to_access\"}")
            fi
        done
    fi

    # Create snapshot object
    snapshot=$(jq -n \
        --arg branch "$current_branch" \
        --arg commit "$current_commit" \
        --arg commit_msg "$current_commit_msg" \
        --arg repo_files "$repo_files_count" \
        --arg modified "$modified_files" \
        --arg staged "$staged_files" \
        --arg untracked "$untracked_files" \
        --argjson gitops_states "[$(IFS=,; echo "${gitops_states[*]}")]" \
        '{
            "local_repository": {
                "branch": $branch,
                "commit": $commit,
                "commit_message": $commit_msg,
                "total_files": ($repo_files | tonumber),
                "modified_files": ($modified | tonumber),
                "staged_files": ($staged | tonumber),
                "untracked_files": ($untracked | tonumber)
            },
            "gitops_repositories": $gitops_states,
            "snapshot_time": now
        }')

    # Update rollback report with snapshot
    jq --argjson snapshot "$snapshot" '.pre_rollback_snapshot = $snapshot' \
       "$ROLLBACK_REPORT" > "${ROLLBACK_REPORT}.tmp" && mv "${ROLLBACK_REPORT}.tmp" "$ROLLBACK_REPORT"

    echo "✅ Pre-rollback snapshot created"
}

# Function to determine rollback strategy
determine_rollback_strategy() {
    local trigger_reason="${1:-automatic_failure}"

    echo "=== Determining Rollback Strategy ==="

    # Update trigger reason in report
    jq --arg reason "$trigger_reason" '.trigger_reason = $reason' \
       "$ROLLBACK_REPORT" > "${ROLLBACK_REPORT}.tmp" && mv "${ROLLBACK_REPORT}.tmp" "$ROLLBACK_REPORT"

    echo "Trigger reason: $trigger_reason"

    case "$trigger_reason" in
        "test_failure")
            echo "Strategy: Revert to last known good commit + clean workspace"
            return 0
            ;;
        "deployment_failure")
            echo "Strategy: Rollback GitOps repositories + revert local changes"
            return 0
            ;;
        "validation_failure")
            echo "Strategy: Discard current changes + reset to main"
            return 0
            ;;
        "automatic_failure"|*)
            echo "Strategy: Comprehensive rollback (local + GitOps)"
            return 0
            ;;
    esac
}

# Function to find last known good commit
find_last_good_commit() {
    echo "=== Finding Last Known Good Commit ==="

    # Look for commits that passed CI (conventional approach)
    local good_commit=""

    # Check if there are any tagged releases
    if git tag -l | grep -E "^v[0-9]" >/dev/null; then
        good_commit=$(git tag -l | grep -E "^v[0-9]" | sort -V | tail -1)
        good_commit=$(git rev-list -n 1 "$good_commit")
        echo "Found good commit from tag: $good_commit"
    else
        # Look for commits with "success" or "pass" in CI messages
        if good_commit=$(git log --oneline --grep="CI.*success\|CI.*pass\|✅" -n 1 --pretty=format:"%H" 2>/dev/null); then
            echo "Found good commit from CI success messages: $good_commit"
        else
            # Fall back to commit before the current one
            good_commit=$(git rev-parse HEAD~1)
            echo "Using previous commit as fallback: $good_commit"
        fi
    fi

    if [ -z "$good_commit" ]; then
        echo "❌ Could not determine last known good commit"
        log_rollback_action "find_last_good_commit" "failed" "Could not determine last known good commit"
        return 1
    fi

    echo "Last known good commit: $good_commit"
    echo "Commit message: $(git log -1 --pretty=format:"%s" "$good_commit")"

    return 0
}

# Function to rollback local repository
rollback_local_repository() {
    local target_commit="$1"

    echo "=== Rolling Back Local Repository ==="

    # Stash any uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo "Stashing uncommitted changes..."
        if git stash push -m "Automatic rollback stash at $(date)"; then
            log_rollback_action "stash_changes" "success" "Uncommitted changes stashed"
        else
            log_rollback_action "stash_changes" "failed" "Failed to stash uncommitted changes"
            EXIT_CODE=1
        fi
    fi

    # Reset to target commit
    echo "Resetting to commit: $target_commit"
    if git reset --hard "$target_commit"; then
        log_rollback_action "reset_to_commit" "success" "Reset to commit $target_commit"
    else
        log_rollback_action "reset_to_commit" "failed" "Failed to reset to commit $target_commit"
        EXIT_CODE=1
        return 1
    fi

    # Clean untracked files
    echo "Cleaning untracked files..."
    if git clean -fd; then
        log_rollback_action "clean_untracked" "success" "Cleaned untracked files"
    else
        log_rollback_action "clean_untracked" "failed" "Failed to clean untracked files"
        EXIT_CODE=1
    fi

    echo "✅ Local repository rollback completed"
}

# Function to rollback GitOps repositories
rollback_gitops_repositories() {
    echo "=== Rolling Back GitOps Repositories ==="

    if [ -z "${GITEA_TOKEN:-}" ] || [ -z "${GITEA_URL:-}" ]; then
        echo "⚠️  GitOps credentials not available, skipping GitOps rollback"
        log_rollback_action "gitops_rollback" "skipped" "GitOps credentials not available"
        return 0
    fi

    local gitea_base_url="${GITEA_URL%/*}"
    local gitea_user="admin1"

    for repo in "edge1-config" "edge2-config"; do
        echo "Rolling back $repo..."

        local repo_url="${gitea_base_url}/${gitea_user}/${repo}.git"
        local temp_dir=$(mktemp -d)
        trap "rm -rf $temp_dir" RETURN

        # Clone repository
        if ! git clone "https://${gitea_user}:${GITEA_TOKEN}@${repo_url#https://}" "$temp_dir" >/dev/null 2>&1; then
            log_rollback_action "clone_gitops_$repo" "failed" "Failed to clone repository for rollback"
            EXIT_CODE=1
            continue
        fi

        cd "$temp_dir"

        # Find last stable commit (look for commits older than 1 hour)
        local stable_commit=""
        local current_time=$(date +%s)

        while IFS= read -r commit_info; do
            local commit_hash=$(echo "$commit_info" | cut -d' ' -f1)
            local commit_time=$(git show -s --format=%ct "$commit_hash")
            local time_diff=$((current_time - commit_time))

            # If commit is older than 1 hour and doesn't contain "CI/CD" (automated), use it
            if [ $time_diff -gt 3600 ]; then
                local commit_msg=$(git log -1 --pretty=format:"%s" "$commit_hash")
                if [[ ! "$commit_msg" =~ "CI/CD" ]]; then
                    stable_commit="$commit_hash"
                    break
                fi
            fi
        done < <(git log --oneline -10)

        if [ -z "$stable_commit" ]; then
            # Fall back to commit before current
            stable_commit=$(git rev-parse HEAD~1)
        fi

        echo "Rolling back $repo to commit: $stable_commit"

        # Reset to stable commit
        if git reset --hard "$stable_commit"; then
            # Push the rollback
            if git push --force-with-lease origin main; then
                log_rollback_action "rollback_gitops_$repo" "success" "Rolled back to commit $stable_commit"
                echo "✅ $repo rolled back successfully"
            else
                log_rollback_action "rollback_gitops_$repo" "failed" "Failed to push rollback"
                EXIT_CODE=1
            fi
        else
            log_rollback_action "rollback_gitops_$repo" "failed" "Failed to reset to stable commit"
            EXIT_CODE=1
        fi

        cd - >/dev/null
    done
}

# Function to verify rollback success
verify_rollback() {
    echo "=== Verifying Rollback Success ==="

    local verification_results={}

    # Verify local repository state
    local current_commit=$(git rev-parse HEAD)
    local is_clean=$(git diff-index --quiet HEAD -- && echo "true" || echo "false")
    local branch=$(git rev-parse --abbrev-ref HEAD)

    # Run basic validation
    local validation_passed="true"

    # Check if essential files exist
    if [ ! -f "scripts/demo_llm.sh" ] || [ ! -f "tools/intent-compiler/translate.py" ]; then
        validation_passed="false"
        log_rollback_action "verify_essential_files" "failed" "Essential files missing after rollback"
        EXIT_CODE=1
    else
        log_rollback_action "verify_essential_files" "success" "Essential files present"
    fi

    # Test basic script functionality
    if bash -n scripts/demo_llm.sh && python3 -m py_compile tools/intent-compiler/translate.py; then
        log_rollback_action "verify_script_syntax" "success" "Scripts have valid syntax"
    else
        validation_passed="false"
        log_rollback_action "verify_script_syntax" "failed" "Scripts have syntax errors"
        EXIT_CODE=1
    fi

    # Create verification results
    verification_results=$(jq -n \
        --arg commit "$current_commit" \
        --arg clean "$is_clean" \
        --arg branch "$branch" \
        --arg validated "$validation_passed" \
        '{
            "current_commit": $commit,
            "repository_clean": ($clean == "true"),
            "current_branch": $branch,
            "validation_passed": ($validated == "true"),
            "verification_time": now
        }')

    # Update rollback report
    jq --argjson verification "$verification_results" '.post_rollback_verification = $verification' \
       "$ROLLBACK_REPORT" > "${ROLLBACK_REPORT}.tmp" && mv "${ROLLBACK_REPORT}.tmp" "$ROLLBACK_REPORT"

    if [ "$validation_passed" = "true" ]; then
        echo "✅ Rollback verification passed"
        jq '.summary.rollback_successful = true' "$ROLLBACK_REPORT" > "${ROLLBACK_REPORT}.tmp" && mv "${ROLLBACK_REPORT}.tmp" "$ROLLBACK_REPORT"
    else
        echo "❌ Rollback verification failed"
        EXIT_CODE=1
    fi
}

# Function to generate rollback summary
generate_rollback_summary() {
    echo "=== Generating Rollback Summary ==="

    local total_actions=$(jq -r '.summary.total_actions' "$ROLLBACK_REPORT")
    local successful_actions=$(jq -r '.summary.successful_actions' "$ROLLBACK_REPORT")
    local failed_actions=$(jq -r '.summary.failed_actions' "$ROLLBACK_REPORT")
    local rollback_successful=$(jq -r '.summary.rollback_successful' "$ROLLBACK_REPORT")

    echo
    echo "Enhanced Rollback Summary:"
    echo "📊 Total actions: $total_actions"
    echo "✅ Successful actions: $successful_actions"
    echo "❌ Failed actions: $failed_actions"
    echo "🔄 Rollback successful: $rollback_successful"

    # Create summary file for CI
    cat > "$REPO_ROOT/artifacts/rollback-summary.txt" << EOF
Enhanced Rollback Report
========================

Timestamp: $(date -Iseconds)
Trigger: $(jq -r '.trigger_reason' "$ROLLBACK_REPORT")
Total Actions: $total_actions
Successful: $successful_actions
Failed: $failed_actions
Rollback Successful: $rollback_successful

Current State:
- Commit: $(git rev-parse HEAD)
- Branch: $(git rev-parse --abbrev-ref HEAD)
- Clean: $(git diff-index --quiet HEAD -- && echo "Yes" || echo "No")

For detailed information, see: $ROLLBACK_REPORT
EOF

    echo "Rollback summary saved to: $REPO_ROOT/artifacts/rollback-summary.txt"
}

# Main rollback execution
main() {
    local trigger_reason="${1:-automatic_failure}"

    echo "Starting enhanced rollback process..."
    echo "Trigger reason: $trigger_reason"

    # Step 1: Create snapshot
    create_snapshot

    # Step 2: Determine strategy
    determine_rollback_strategy "$trigger_reason"

    # Step 3: Find last good commit
    if find_last_good_commit; then
        local target_commit=$(git log --oneline --grep="CI.*success\|CI.*pass\|✅" -n 1 --pretty=format:"%H" 2>/dev/null || git rev-parse HEAD~1)

        # Step 4: Rollback local repository
        rollback_local_repository "$target_commit"

        # Step 5: Rollback GitOps repositories
        rollback_gitops_repositories

        # Step 6: Verify rollback
        verify_rollback

        # Step 7: Generate summary
        generate_rollback_summary
    else
        EXIT_CODE=1
    fi

    if [ $EXIT_CODE -eq 0 ]; then
        echo "🎉 Enhanced rollback completed successfully!"
    else
        echo "💥 Enhanced rollback completed with errors. Check the report at: $ROLLBACK_REPORT"
    fi
}

# Execute main function with provided arguments
main "$@"

exit $EXIT_CODE