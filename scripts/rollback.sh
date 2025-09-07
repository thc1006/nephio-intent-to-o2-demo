#!/bin/bash
# Automated Rollback for SLO-Gated GitOps Pipeline
# Handles both automated and manual rollback scenarios for Nephio Intent-to-O2 demo

set -euo pipefail

# Configuration defaults (can be overridden via environment)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ROLLBACK_CONFIG="${PROJECT_ROOT}/.rollback.conf"

# Load configuration if exists
if [[ -f "${ROLLBACK_CONFIG}" ]]; then
    # shellcheck disable=SC1090
    source "${ROLLBACK_CONFIG}"
fi

# Configuration variables with defaults
readonly EDGE_REPO_DIR="${EDGE_REPO_DIR:-${HOME}/edge1-config}"
readonly ROLLBACK_STRATEGY="${ROLLBACK_STRATEGY:-revert}"
readonly KNOWN_GOOD_TAG="${KNOWN_GOOD_TAG:-stable}"
readonly MAX_ROLLBACK_COMMITS="${MAX_ROLLBACK_COMMITS:-5}"
readonly NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly DRY_RUN="${DRY_RUN:-false}"
readonly AUTO_PUSH="${AUTO_PUSH:-true}"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GIT_ERROR=1
readonly EXIT_CONFIG_ERROR=2
readonly EXIT_DEPENDENCY_MISSING=3
readonly EXIT_ROLLBACK_FAILED=4
readonly EXIT_NOTIFICATION_FAILED=5

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# JSON logging support
log_json() {
    local level="$1"
    local message="$2"
    local extra="${3:-}"
    
    if [[ "${LOG_LEVEL}" == "JSON" ]]; then
        jq -n --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
              --arg level "${level}" \
              --arg message "${message}" \
              --arg extra "${extra}" \
              '{timestamp: $timestamp, level: $level, message: $message, extra: $extra}'
    fi
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
    log_json "INFO" "$1" "${2:-}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
    log_json "WARN" "$1" "${2:-}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    log_json "ERROR" "$1" "${2:-}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    log_json "SUCCESS" "$1" "${2:-}"
}

log_rollback() {
    echo -e "${PURPLE}[ROLLBACK]${NC} $1" >&2
    log_json "ROLLBACK" "$1" "${2:-}"
}

# Dependency checks
check_dependencies() {
    local deps=(
        "git:standard package"
        "jq:standard package"
        "curl:standard package"
    )
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        local cmd="${dep%%:*}"
        local desc="${dep##*:}"
        
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_deps+=("${cmd} (${desc})")
        fi
    done
    
    if [[ "${#missing_deps[@]}" -gt 0 ]]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}"
        done
        return ${EXIT_DEPENDENCY_MISSING}
    fi
    
    # Check if edge repository directory exists
    if [[ ! -d "${EDGE_REPO_DIR}" ]]; then
        log_error "Edge repository directory not found: ${EDGE_REPO_DIR}"
        log_info "Set EDGE_REPO_DIR environment variable to correct path"
        return ${EXIT_CONFIG_ERROR}
    fi
    
    # Check if it's a git repository
    if [[ ! -d "${EDGE_REPO_DIR}/.git" ]]; then
        log_error "Directory is not a git repository: ${EDGE_REPO_DIR}"
        return ${EXIT_CONFIG_ERROR}
    fi
    
    log_success "All required dependencies present"
}

# Get information about the last publish commit
get_publish_commit_info() {
    cd "${EDGE_REPO_DIR}"
    
    # Find the most recent commit with publish-related keywords
    local publish_commit
    publish_commit=$(git log --oneline -n "${MAX_ROLLBACK_COMMITS}" --grep="feat: update intent-to-krm artifacts" --grep="publish" --grep="intent" | head -1 | cut -d' ' -f1 || echo "")
    
    if [[ -z "${publish_commit}" ]]; then
        log_warn "No recent publish commit found, using HEAD as rollback target"
        publish_commit="HEAD"
    else
        local commit_msg
        commit_msg=$(git log --format="%s" -n 1 "${publish_commit}")
        log_info "Found publish commit: ${publish_commit} - ${commit_msg}"
    fi
    
    echo "${publish_commit}"
}

# Perform revert rollback strategy
perform_revert_rollback() {
    local publish_commit="$1"
    
    cd "${EDGE_REPO_DIR}"
    
    log_rollback "Performing revert rollback for commit: ${publish_commit}"
    
    # Check current git status
    if ! git status --porcelain | grep -q '^'; then
        log_info "Working directory is clean, proceeding with revert"
    else
        log_warn "Working directory has uncommitted changes:"
        git status --porcelain
        
        if [[ "${DRY_RUN}" != "true" ]]; then
            log_info "Stashing uncommitted changes"
            git stash push -m "Stashed before rollback at $(date)"
        fi
    fi
    
    # Get commit details before revert
    local commit_details
    commit_details=$(git show --stat "${publish_commit}")
    
    log_info "Commit to be reverted:"
    echo "${commit_details}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY_RUN=true, would revert commit ${publish_commit}"
        return 0
    fi
    
    # Perform the revert
    if git revert --no-edit "${publish_commit}"; then
        local revert_commit
        revert_commit=$(git rev-parse HEAD)
        log_success "Successfully reverted commit ${publish_commit} (new commit: ${revert_commit})"
        
        # Add rollback metadata to commit message
        git commit --amend -m "$(git log --format=%B -n 1 HEAD)"\
"\n\nRollback triggered by SLO violation\nOriginal commit: ${publish_commit}\nRollback timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n\n🔄 Automated rollback by Claude Code\nCo-Authored-By: Claude <noreply@anthropic.com>"
        
        log_rollback "Added rollback metadata to commit message"
        return 0
    else
        log_error "Failed to revert commit ${publish_commit}"
        
        # Check if there are conflicts
        if git status --porcelain | grep -q '^UU'; then
            log_error "Merge conflicts detected during revert:"
            git status --porcelain | grep '^UU'
            log_info "Manual resolution required. Run: git status && git mergetool"
        fi
        
        return ${EXIT_ROLLBACK_FAILED}
    fi
}

# Perform reset rollback strategy
perform_reset_rollback() {
    local target_tag="$1"
    
    cd "${EDGE_REPO_DIR}"
    
    log_rollback "Performing reset rollback to known good tag: ${target_tag}"
    
    # Check if the tag exists
    if ! git tag -l | grep -q "^${target_tag}$"; then
        log_error "Tag '${target_tag}' not found in repository"
        log_info "Available tags:"
        git tag -l | head -10
        return ${EXIT_CONFIG_ERROR}
    fi
    
    # Get tag details
    local tag_commit
    tag_commit=$(git rev-list -n 1 "${target_tag}")
    local tag_date
    tag_date=$(git log -1 --format="%ci" "${target_tag}")
    
    log_info "Target tag details:"
    echo "  Tag: ${target_tag}"
    echo "  Commit: ${tag_commit}"
    echo "  Date: ${tag_date}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY_RUN=true, would reset to tag ${target_tag} (${tag_commit})"
        return 0
    fi
    
    # Perform hard reset to the tag
    if git reset --hard "${target_tag}"; then
        log_success "Successfully reset to tag ${target_tag}"
        
        # Create a new commit to record the rollback
        local current_commit
        current_commit=$(git rev-parse HEAD)
        
        # Create empty commit with rollback message
        git commit --allow-empty -m "rollback: Reset to known good state ${target_tag}" \
                                  -m "Reset from problematic deployment" \
                                  -m "Target tag: ${target_tag}" \
                                  -m "Target commit: ${tag_commit}" \
                                  -m "Rollback timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                                  -m "" \
                                  -m "🔄 Automated rollback by Claude Code" \
                                  -m "Co-Authored-By: Claude <noreply@anthropic.com>"
        
        log_rollback "Created rollback record commit"
        return 0
    else
        log_error "Failed to reset to tag ${target_tag}"
        return ${EXIT_ROLLBACK_FAILED}
    fi
}

# Push changes to trigger GitOps reconciliation
push_rollback_changes() {
    cd "${EDGE_REPO_DIR}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY_RUN=true, would push rollback changes to remote"
        return 0
    fi
    
    if [[ "${AUTO_PUSH}" != "true" ]]; then
        log_info "AUTO_PUSH=false, skipping push (manual push required)"
        log_info "To push manually: cd ${EDGE_REPO_DIR} && git push origin main"
        return 0
    fi
    
    log_info "Pushing rollback changes to remote repository"
    
    # Determine the default branch
    local default_branch
    default_branch=$(git symbolic-ref --short HEAD)
    
    if git push origin "${default_branch}"; then
        log_success "Successfully pushed rollback changes to ${default_branch}"
        log_rollback "GitOps reconciliation will begin shortly"
    else
        log_error "Failed to push rollback changes"
        log_info "You may need to push manually: cd ${EDGE_REPO_DIR} && git push origin ${default_branch}"
        return ${EXIT_GIT_ERROR}
    fi
}

# Send notification about rollback
send_notification() {
    local rollback_type="$1"
    local rollback_target="$2"
    local status="$3"
    
    if [[ -z "${NOTIFICATION_WEBHOOK}" ]]; then
        log_info "No notification webhook configured, skipping notification"
        return 0
    fi
    
    local payload
    payload=$(jq -n --arg type "${rollback_type}" \
                   --arg target "${rollback_target}" \
                   --arg status "${status}" \
                   --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                   --arg repository "${EDGE_REPO_DIR}" \
                   '{
                     "event": "rollback",
                     "rollback_type": $type,
                     "rollback_target": $target,
                     "status": $status,
                     "timestamp": $timestamp,
                     "repository": $repository,
                     "message": "SLO-gated rollback executed"
                   }')
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY_RUN=true, would send notification:"
        echo "${payload}" | jq .
        return 0
    fi
    
    log_info "Sending rollback notification to webhook"
    
    if curl -s -X POST -H "Content-Type: application/json" -d "${payload}" "${NOTIFICATION_WEBHOOK}" >/dev/null; then
        log_success "Notification sent successfully"
    else
        log_error "Failed to send rollback notification"
        return ${EXIT_NOTIFICATION_FAILED}
    fi
}

# Generate rollback summary report
generate_summary() {
    local start_time="$1"
    local exit_code="$2"
    local rollback_strategy="$3"
    local rollback_target="$4"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "==============================================="
    echo "           ROLLBACK SUMMARY REPORT"
    echo "==============================================="
    echo "Duration: ${duration}s"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Strategy: ${rollback_strategy}"
    echo "Target: ${rollback_target}"
    echo "Repository: ${EDGE_REPO_DIR}"
    echo "Exit Code: ${exit_code}"
    
    if [[ ${exit_code} -eq ${EXIT_SUCCESS} ]]; then
        echo "Status: ✅ SUCCESS - Rollback completed"
    else
        echo "Status: ❌ FAILED - Rollback encountered errors"
    fi
    
    # Show git status if repository exists
    if [[ -d "${EDGE_REPO_DIR}/.git" ]]; then
        echo ""
        echo "Current repository state:"
        cd "${EDGE_REPO_DIR}"
        echo "  Branch: $(git branch --show-current)"
        echo "  Commit: $(git rev-parse --short HEAD) - $(git log --format='%s' -n 1)"
        echo "  Status: $(git status --porcelain | wc -l) modified files"
    fi
    
    echo ""
    
    # Create JSON summary if requested
    if [[ "${LOG_LEVEL}" == "JSON" ]]; then
        local current_commit=""
        local current_branch=""
        
        if [[ -d "${EDGE_REPO_DIR}/.git" ]]; then
            cd "${EDGE_REPO_DIR}"
            current_commit=$(git rev-parse HEAD)
            current_branch=$(git branch --show-current)
        fi
        
        jq -n --arg duration "${duration}" \
              --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
              --arg strategy "${rollback_strategy}" \
              --arg target "${rollback_target}" \
              --arg repository "${EDGE_REPO_DIR}" \
              --arg exit_code "${exit_code}" \
              --arg current_commit "${current_commit}" \
              --arg current_branch "${current_branch}" \
              '{
                rollback_summary: {
                  duration: $duration,
                  timestamp: $timestamp,
                  strategy: $strategy,
                  target: $target,
                  repository: $repository,
                  exit_code: ($exit_code | tonumber),
                  status: (if ($exit_code | tonumber) == 0 then "SUCCESS" else "FAILED" end),
                  current_state: {
                    commit: $current_commit,
                    branch: $current_branch
                  }
                }
              }' > "${PROJECT_ROOT}/artifacts/rollback-summary.json"
    fi
}

# Main execution
main() {
    local start_time
    start_time=$(date +%s)
    
    log_rollback "Starting automated rollback for SLO-gated GitOps pipeline"
    log_info "Repository: ${EDGE_REPO_DIR}"
    log_info "Strategy: ${ROLLBACK_STRATEGY}"
    log_info "Dry Run: ${DRY_RUN}"
    
    # Ensure artifacts directory exists
    mkdir -p "${PROJECT_ROOT}/artifacts"
    
    # Run all rollback steps
    local exit_code=0
    local rollback_target="unknown"
    
    check_dependencies || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Dependency check failed"
        generate_summary "${start_time}" "${exit_code}" "${ROLLBACK_STRATEGY}" "${rollback_target}"
        exit ${exit_code}
    fi
    
    case "${ROLLBACK_STRATEGY}" in
        "revert")
            rollback_target=$(get_publish_commit_info)
            perform_revert_rollback "${rollback_target}" || exit_code=$?
            ;;
        "reset")
            rollback_target="${KNOWN_GOOD_TAG}"
            perform_reset_rollback "${rollback_target}" || exit_code=$?
            ;;
        *)
            log_error "Unknown rollback strategy: ${ROLLBACK_STRATEGY}"
            log_info "Supported strategies: revert, reset"
            exit_code=${EXIT_CONFIG_ERROR}
            ;;
    esac
    
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Rollback execution failed"
        send_notification "${ROLLBACK_STRATEGY}" "${rollback_target}" "FAILED" || true
        generate_summary "${start_time}" "${exit_code}" "${ROLLBACK_STRATEGY}" "${rollback_target}"
        exit ${exit_code}
    fi
    
    push_rollback_changes || exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Failed to push rollback changes"
        # Don't exit here - rollback was successful, just push failed
    fi
    
    send_notification "${ROLLBACK_STRATEGY}" "${rollback_target}" "SUCCESS" || log_warn "Notification failed but rollback was successful"
    
    generate_summary "${start_time}" "${EXIT_SUCCESS}" "${ROLLBACK_STRATEGY}" "${rollback_target}"
    log_success "Rollback completed successfully - GitOps reconciliation will restore system to known good state"
    
    return ${EXIT_SUCCESS}
}

# Handle help and version flags
case "${1:-}" in
    -h|--help)
        cat << 'EOF'
Automated Rollback for SLO-Gated GitOps Pipeline

USAGE:
    ./scripts/rollback.sh [OPTIONS]

DESCRIPTION:
    Handles both automated and manual rollback scenarios for Nephio Intent-to-O2 demo.
    Supports revert (undo last publish commit) and reset (return to known good tag)
    strategies. Automatically pushes changes to trigger GitOps reconciliation.

OPTIONS:
    -h, --help      Show this help message
    --version       Show version information

CONFIGURATION:
    Set environment variables or create .rollback.conf in project root:

    EDGE_REPO_DIR=${HOME}/edge1-config    Edge GitOps repository path
    ROLLBACK_STRATEGY=revert               Rollback strategy (revert|reset)
    KNOWN_GOOD_TAG=stable                  Tag to reset to (reset strategy)
    MAX_ROLLBACK_COMMITS=5                 Max commits to search for publish
    NOTIFICATION_WEBHOOK=                  Webhook URL for notifications
    LOG_LEVEL=INFO                         Set to JSON for machine-readable logs
    DRY_RUN=false                         Preview rollback without executing
    AUTO_PUSH=true                        Automatically push rollback changes

ROLLBACK STRATEGIES:
    revert    Git revert the last publish commit (default)
              Preserves git history, creates new commit
              Good for: Single problematic commit

    reset     Git reset --hard to known good tag
              Destructive but clean rollback
              Good for: Multiple problematic commits

EXIT CODES:
    0   Success - Rollback completed
    1   Git operation failed
    2   Configuration error
    3   Missing dependencies
    4   Rollback execution failed
    5   Notification failed (non-fatal)

EXAMPLES:
    # Basic usage (revert strategy)
    ./scripts/rollback.sh

    # Reset to stable tag
    ROLLBACK_STRATEGY=reset KNOWN_GOOD_TAG=v1.0.0 ./scripts/rollback.sh

    # Dry run to preview changes
    DRY_RUN=true ./scripts/rollback.sh

    # Manual push (no auto-push)
    AUTO_PUSH=false ./scripts/rollback.sh

    # With JSON logging
    LOG_LEVEL=JSON ./scripts/rollback.sh > rollback.json
EOF
        exit 0
        ;;
    --version)
        echo "Automated Rollback v1.0.0"
        echo "Part of Nephio Intent-to-O2 Demo Pipeline"
        exit 0
        ;;
esac

# Execute main function
main "$@"