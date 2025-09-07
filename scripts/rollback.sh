#!/bin/bash
set -euo pipefail

# rollback.sh - Automated rollback system for failed deployments
# Supports revert (preserve history) and reset (clean rollback) strategies

# Configuration with defaults
ROLLBACK_STRATEGY="${ROLLBACK_STRATEGY:-revert}"  # revert|reset
PUBLISH_BRANCH="${PUBLISH_BRANCH:-feat/slo-gate}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
ROLLBACK_TAG_PREFIX="${ROLLBACK_TAG_PREFIX:-rollback}"
DRY_RUN="${DRY_RUN:-false}"

# Remote configuration
REMOTE_NAME="${REMOTE_NAME:-origin}"
FORCE_PUSH="${FORCE_PUSH:-false}"

# Notification settings
NOTIFY_WEBHOOK="${NOTIFY_WEBHOOK:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Logging configuration
LOG_JSON="${LOG_JSON:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Load configuration file if exists
if [[ -f ".rollback.conf" ]]; then
    source ".rollback.conf"
fi

# Exit codes
EXIT_SUCCESS=0
EXIT_NO_COMMITS_TO_ROLLBACK=1
EXIT_GIT_OPERATION_FAILED=2
EXIT_PUSH_FAILED=3
EXIT_DEPENDENCY_MISSING=4
EXIT_CONFIG_ERROR=5

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    if [[ "$LOG_JSON" == "true" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"rollback\"}"
    else
        echo "[$timestamp] [$level] $message"
    fi
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    for dep in git curl; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit $EXIT_DEPENDENCY_MISSING
    fi
}

# Validate git repository state
validate_git_state() {
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "Not inside a git repository"
        exit $EXIT_CONFIG_ERROR
    fi
    
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "$PUBLISH_BRANCH" ]]; then
        log_warn "Current branch '$current_branch' differs from publish branch '$PUBLISH_BRANCH'"
        log_info "Switching to publish branch '$PUBLISH_BRANCH'"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would switch to branch: $PUBLISH_BRANCH"
        else
            git checkout "$PUBLISH_BRANCH" || {
                log_error "Failed to switch to branch '$PUBLISH_BRANCH'"
                exit $EXIT_GIT_OPERATION_FAILED
            }
        fi
    fi
    
    # Check if we have commits to rollback
    local commit_count=$(git rev-list --count "${MAIN_BRANCH}..HEAD" 2>/dev/null || echo "0")
    if [[ "$commit_count" -eq 0 ]]; then
        log_warn "No commits to rollback on branch '$PUBLISH_BRANCH'"
        return $EXIT_NO_COMMITS_TO_ROLLBACK
    fi
    
    log_info "Found $commit_count commits to potentially rollback"
    return 0
}

# Find the last publish commit
find_last_publish_commit() {
    local last_publish_commit=""
    
    # Look for commits with specific patterns that indicate publish operations
    local publish_patterns=("make publish-edge" "publish:" "deploy:" "release:")
    
    for pattern in "${publish_patterns[@]}"; do
        last_publish_commit=$(git log --oneline --grep="$pattern" -1 --format="%H" || echo "")
        if [[ -n "$last_publish_commit" ]]; then
            log_info "Found last publish commit: $last_publish_commit (pattern: $pattern)"
            break
        fi
    done
    
    # Fallback: use the most recent commit if no publish-specific commit found
    if [[ -z "$last_publish_commit" ]]; then
        last_publish_commit=$(git rev-parse HEAD)
        log_warn "No publish-specific commit found, using HEAD: $last_publish_commit"
    fi
    
    echo "$last_publish_commit"
}

# Create rollback tag for audit trail
create_rollback_tag() {
    local commit_to_rollback="$1"
    local rollback_reason="${2:-SLO-violation}"
    local tag_name="${ROLLBACK_TAG_PREFIX}-$(date +%Y%m%d-%H%M%S)-${rollback_reason}"
    
    log_info "Creating rollback tag: $tag_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create tag: $tag_name for commit $commit_to_rollback"
        return 0
    fi
    
    if ! git tag -a "$tag_name" "$commit_to_rollback" -m "Rollback tag for commit $commit_to_rollback (reason: $rollback_reason)"; then
        log_error "Failed to create rollback tag"
        return $EXIT_GIT_OPERATION_FAILED
    fi
    
    # Push tag to remote
    if ! git push "$REMOTE_NAME" "$tag_name"; then
        log_warn "Failed to push rollback tag to remote (continuing anyway)"
    fi
    
    return 0
}

# Perform revert rollback (preserves git history)
perform_revert_rollback() {
    local commit_to_rollback="$1"
    local rollback_reason="${2:-SLO-violation}"
    
    log_info "Performing revert rollback for commit: $commit_to_rollback"
    log_info "Rollback strategy: revert (preserves git history)"
    
    # Create rollback tag for audit trail
    create_rollback_tag "$commit_to_rollback" "$rollback_reason"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would revert commit: $commit_to_rollback"
        return 0
    fi
    
    # Perform git revert
    if ! git revert --no-edit "$commit_to_rollback"; then
        log_error "Git revert failed for commit: $commit_to_rollback"
        
        # Check if it's a merge conflict
        if git status --porcelain | grep -q "^UU"; then
            log_error "Merge conflicts detected during revert"
            log_info "You may need to resolve conflicts manually and commit"
            git status
        fi
        
        return $EXIT_GIT_OPERATION_FAILED
    fi
    
    log_info "Revert completed successfully"
    return 0
}

# Perform reset rollback (clean rollback to known good state)
perform_reset_rollback() {
    local rollback_reason="${1:-SLO-violation}"
    
    log_info "Performing reset rollback to main branch"
    log_info "Rollback strategy: reset (clean rollback to known good state)"
    
    # Create rollback tag for current HEAD before reset
    create_rollback_tag "HEAD" "$rollback_reason"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would reset to: $MAIN_BRANCH"
        return 0
    fi
    
    # Fetch latest main branch
    if ! git fetch "$REMOTE_NAME" "$MAIN_BRANCH"; then
        log_error "Failed to fetch latest main branch"
        return $EXIT_GIT_OPERATION_FAILED
    fi
    
    # Reset to main branch
    if ! git reset --hard "$REMOTE_NAME/$MAIN_BRANCH"; then
        log_error "Git reset failed"
        return $EXIT_GIT_OPERATION_FAILED
    fi
    
    log_info "Reset completed successfully"
    return 0
}

# Push rollback changes
push_rollback_changes() {
    log_info "Pushing rollback changes to remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would push rollback changes"
        return 0
    fi
    
    local push_args=("$REMOTE_NAME" "$PUBLISH_BRANCH")
    if [[ "$FORCE_PUSH" == "true" ]] && [[ "$ROLLBACK_STRATEGY" == "reset" ]]; then
        push_args+=("--force-with-lease")
        log_warn "Using force push with lease for reset rollback"
    fi
    
    if ! git push "${push_args[@]}"; then
        log_error "Failed to push rollback changes"
        return $EXIT_PUSH_FAILED
    fi
    
    log_info "Rollback changes pushed successfully"
    return 0
}

# Send notifications
send_notifications() {
    local rollback_type="$1"
    local commit_info="$2"
    local rollback_reason="${3:-SLO-violation}"
    
    local message="🔄 Rollback executed: $rollback_type strategy for commit $commit_info (reason: $rollback_reason)"
    
    log_info "Sending rollback notifications"
    
    # Webhook notification
    if [[ -n "$NOTIFY_WEBHOOK" ]]; then
        curl -s -X POST "$NOTIFY_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"$message\",\"type\":\"rollback\",\"commit\":\"$commit_info\",\"strategy\":\"$rollback_type\"}" \
            || log_warn "Failed to send webhook notification"
    fi
    
    # Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$message\"}" \
            || log_warn "Failed to send Slack notification"
    fi
}

# Generate rollback audit report
generate_audit_report() {
    local rollback_type="$1"
    local commit_info="$2"
    local rollback_reason="${3:-SLO-violation}"
    
    local audit_file="./artifacts/rollback-audit-$(date +%Y%m%d-%H%M%S).json"
    mkdir -p "$(dirname "$audit_file")"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would generate audit report: $audit_file"
        return 0
    fi
    
    cat > "$audit_file" <<EOF
{
  "rollback": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "strategy": "$rollback_type",
    "reason": "$rollback_reason",
    "commit": "$commit_info",
    "branch": "$PUBLISH_BRANCH",
    "operator": "$(whoami)",
    "hostname": "$(hostname)"
  },
  "git_state": {
    "before_rollback": "$(git rev-parse HEAD~1 2>/dev/null || echo 'unknown')",
    "after_rollback": "$(git rev-parse HEAD)",
    "remote": "$REMOTE_NAME"
  }
}
EOF
    
    log_info "Audit report generated: $audit_file"
}

# Main rollback execution
main() {
    local rollback_reason="${1:-SLO-violation}"
    
    log_info "Starting rollback process"
    log_info "Rollback strategy: $ROLLBACK_STRATEGY"
    log_info "Publish branch: $PUBLISH_BRANCH"
    log_info "Reason: $rollback_reason"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 DRY-RUN MODE: No changes will be made"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Validate git repository state
    validate_git_state
    local validation_result=$?
    if [[ $validation_result -eq $EXIT_NO_COMMITS_TO_ROLLBACK ]]; then
        log_info "✅ No rollback needed: branch is clean"
        exit $EXIT_SUCCESS
    elif [[ $validation_result -ne 0 ]]; then
        exit $validation_result
    fi
    
    local rollback_success=false
    local commit_info=""
    
    # Execute rollback strategy
    case "$ROLLBACK_STRATEGY" in
        "revert")
            local commit_to_rollback=$(find_last_publish_commit)
            commit_info="$commit_to_rollback"
            if perform_revert_rollback "$commit_to_rollback" "$rollback_reason"; then
                rollback_success=true
            fi
            ;;
        "reset")
            commit_info="$(git rev-parse HEAD)"
            if perform_reset_rollback "$rollback_reason"; then
                rollback_success=true
            fi
            ;;
        *)
            log_error "Unknown rollback strategy: $ROLLBACK_STRATEGY"
            exit $EXIT_CONFIG_ERROR
            ;;
    esac
    
    if [[ "$rollback_success" != "true" ]]; then
        log_error "Rollback failed"
        exit $EXIT_GIT_OPERATION_FAILED
    fi
    
    # Push changes
    if ! push_rollback_changes; then
        log_error "Failed to push rollback changes"
        exit $EXIT_PUSH_FAILED
    fi
    
    # Send notifications and generate audit report
    send_notifications "$ROLLBACK_STRATEGY" "$commit_info" "$rollback_reason"
    generate_audit_report "$ROLLBACK_STRATEGY" "$commit_info" "$rollback_reason"
    
    log_info "Rollback completed successfully"
    log_info "✅ ROLLBACK SUCCESS: $ROLLBACK_STRATEGY strategy executed for $rollback_reason"
    exit $EXIT_SUCCESS
}

# Handle script interruption
trap 'log_error "Rollback interrupted"; exit 130' INT TERM

# Show help
show_help() {
    cat <<EOF
Usage: $0 [REASON]

Automated rollback system for failed deployments.

Arguments:
  REASON    Optional reason for rollback (default: SLO-violation)

Environment Variables:
  ROLLBACK_STRATEGY    Rollback strategy: revert|reset (default: revert)
  PUBLISH_BRANCH      Branch to rollback (default: feat/slo-gate)
  MAIN_BRANCH         Main branch for reset strategy (default: main)
  DRY_RUN            Enable dry-run mode (default: false)
  REMOTE_NAME        Git remote name (default: origin)
  FORCE_PUSH         Allow force push for reset (default: false)

Examples:
  $0                           # Rollback due to SLO violation
  $0 "security-vulnerability"  # Rollback with custom reason
  
  ROLLBACK_STRATEGY=reset DRY_RUN=true $0  # Dry-run reset rollback
EOF
}

# Parse command line arguments
case "${1:-}" in
    "-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main "${1:-SLO-violation}"
        ;;
esac