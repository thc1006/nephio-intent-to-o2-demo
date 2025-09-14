#!/bin/bash
set -euo pipefail

# rollback.sh - Enhanced Automated Rollback System for Failed Deployments
# Version: 2.0 - Production Summit Demo Ready
# Features: Evidence collection, root cause analysis, multi-site support,
#          safe rollback snapshots, comprehensive reporting, and idempotency

# Script metadata
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"
EXECUTION_ID="$(date +%Y%m%d_%H%M%S)_$$"

# Configuration with defaults
ROLLBACK_STRATEGY="${ROLLBACK_STRATEGY:-revert}"  # revert|reset|selective
PUBLISH_BRANCH="${PUBLISH_BRANCH:-feat/slo-gate}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
ROLLBACK_TAG_PREFIX="${ROLLBACK_TAG_PREFIX:-rollback}"
DRY_RUN="${DRY_RUN:-false}"

# Multi-site configuration
TARGET_SITE="${TARGET_SITE:-both}"  # edge1|edge2|both|auto-detect
PARTIAL_ROLLBACK="${PARTIAL_ROLLBACK:-false}"
SITE_SPECIFIC_BRANCHES="${SITE_SPECIFIC_BRANCHES:-false}"

# Remote configuration
REMOTE_NAME="${REMOTE_NAME:-origin}"
FORCE_PUSH="${FORCE_PUSH:-false}"
BACKUP_REMOTE="${BACKUP_REMOTE:-backup}"

# Evidence and snapshot configuration
COLLECT_EVIDENCE="${COLLECT_EVIDENCE:-true}"
CREATE_SNAPSHOTS="${CREATE_SNAPSHOTS:-true}"
PRESERVE_ARTIFACTS="${PRESERVE_ARTIFACTS:-true}"
EVIDENCE_RETENTION_DAYS="${EVIDENCE_RETENTION_DAYS:-30}"

# Root cause analysis configuration
ENABLE_RCA="${ENABLE_RCA:-true}"
RCA_DEPTH="${RCA_DEPTH:-10}"  # Number of commits to analyze
ANALYZE_POSTCHECK_REPORT="${ANALYZE_POSTCHECK_REPORT:-true}"

# Notification settings
NOTIFY_WEBHOOK="${NOTIFY_WEBHOOK:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
EMAIL_RECIPIENTS="${EMAIL_RECIPIENTS:-}"
TEAMS_WEBHOOK="${TEAMS_WEBHOOK:-}"

# Logging and reporting configuration
LOG_JSON="${LOG_JSON:-false}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
GENERATE_DETAILED_REPORT="${GENERATE_DETAILED_REPORT:-true}"

# Directory configuration
TIMESTAMP="${TIMESTAMP:-$EXECUTION_ID}"
ROLLBACK_DIR="${ROLLBACK_DIR:-reports/${TIMESTAMP}/rollback}"
EVIDENCE_DIR="${ROLLBACK_DIR}/evidence"
SNAPSHOTS_DIR="${ROLLBACK_DIR}/snapshots"
RCA_DIR="${ROLLBACK_DIR}/root-cause-analysis"
REPORT_FILE="${ROLLBACK_DIR}/rollback_report.json"
MANIFEST_FILE="${ROLLBACK_DIR}/manifest.json"

# Load configuration file if exists
CONFIG_FILES=(
    "./config/rollback.conf"
    "./.rollback.conf"
    "$HOME/.nephio/rollback.conf"
    "/etc/nephio/rollback.conf"
)


# Exit codes
EXIT_SUCCESS=0
EXIT_NO_COMMITS_TO_ROLLBACK=1
EXIT_GIT_OPERATION_FAILED=2
EXIT_PUSH_FAILED=3
EXIT_DEPENDENCY_MISSING=4
EXIT_CONFIG_ERROR=5
EXIT_EVIDENCE_COLLECTION_FAILED=6
EXIT_SNAPSHOT_FAILED=7
EXIT_RCA_FAILED=8
EXIT_MULTI_SITE_FAILURE=9
EXIT_PARTIAL_ROLLBACK_FAILED=10

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local component="rollback"

    if [[ "$LOG_JSON" == "true" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"$component\",\"execution_id\":\"$EXECUTION_ID\"}"
    else
        echo "[$timestamp] [$level] [$component] $message"
    fi
}

log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && log "DEBUG" "$1"; }

# Enhanced dependency check
check_dependencies() {
    local missing_deps=()
    local optional_deps=()

    # Required dependencies
    for dep in git curl jq mkdir sha256sum; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    # Optional but recommended dependencies
    for dep in yq bc python3 kubectl helm; do
        if ! command -v "$dep" &> /dev/null; then
            optional_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit $EXIT_DEPENDENCY_MISSING
    fi

    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        log_warn "Missing optional dependencies (reduced functionality): ${optional_deps[*]}"
    fi

    log_info "Dependencies check passed"
}

# Initialize rollback environment
initialize_rollback_environment() {
    log_info "Initializing rollback environment for execution: $EXECUTION_ID"

    # Create directory structure
    mkdir -p "$ROLLBACK_DIR" "$EVIDENCE_DIR" "$SNAPSHOTS_DIR" "$RCA_DIR"

    # Create manifest
    cat > "$MANIFEST_FILE" <<EOF
{
  "rollback": {
    "execution_id": "$EXECUTION_ID",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "script_version": "$SCRIPT_VERSION",
    "strategy": "$ROLLBACK_STRATEGY",
    "target_site": "$TARGET_SITE",
    "dry_run": $([[ "$DRY_RUN" == "true" ]] && echo "true" || echo "false")
  },
  "configuration": {
    "publish_branch": "$PUBLISH_BRANCH",
    "main_branch": "$MAIN_BRANCH",
    "remote_name": "$REMOTE_NAME",
    "collect_evidence": $([[ "$COLLECT_EVIDENCE" == "true" ]] && echo "true" || echo "false"),
    "create_snapshots": $([[ "$CREATE_SNAPSHOTS" == "true" ]] && echo "true" || echo "false"),
    "enable_rca": $([[ "$ENABLE_RCA" == "true" ]] && echo "true" || echo "false")
  },
  "directories": {
    "rollback_dir": "$ROLLBACK_DIR",
    "evidence_dir": "$EVIDENCE_DIR",
    "snapshots_dir": "$SNAPSHOTS_DIR",
    "rca_dir": "$RCA_DIR"
  }
}
EOF

    log_info "Rollback environment initialized - manifest: $MANIFEST_FILE"
}

# Collect comprehensive pre-rollback evidence
collect_pre_rollback_evidence() {
    if [[ "$COLLECT_EVIDENCE" != "true" ]]; then
        log_info "Evidence collection disabled"
        return 0
    fi

    log_info "Collecting comprehensive pre-rollback evidence"

    # Git repository state
    log_info "Collecting git repository state"
    git status --porcelain > "$EVIDENCE_DIR/git-status.txt" 2>/dev/null || true
    git log --oneline -10 > "$EVIDENCE_DIR/recent-commits.txt" 2>/dev/null || true
    git branch -a > "$EVIDENCE_DIR/all-branches.txt" 2>/dev/null || true
    git remote -v > "$EVIDENCE_DIR/remotes.txt" 2>/dev/null || true
    git diff HEAD~1 HEAD > "$EVIDENCE_DIR/last-commit-diff.patch" 2>/dev/null || true

    # Current deployment state
    if command -v kubectl &> /dev/null; then
        log_info "Collecting Kubernetes deployment state"
        kubectl get deployments -A -o yaml > "$EVIDENCE_DIR/deployments.yaml" 2>/dev/null || true
        kubectl get configmaps -A -o yaml > "$EVIDENCE_DIR/configmaps.yaml" 2>/dev/null || true
        kubectl get rootsyncs -A -o yaml > "$EVIDENCE_DIR/rootsyncs.yaml" 2>/dev/null || true
        kubectl get pods -A --show-labels > "$EVIDENCE_DIR/pods-with-labels.txt" 2>/dev/null || true

        # Events for troubleshooting
        kubectl get events -A --sort-by='.lastTimestamp' > "$EVIDENCE_DIR/k8s-events.txt" 2>/dev/null || true
    fi

    # System environment
    log_info "Collecting system environment"
    env | grep -E '^(NEPHIO|O2|TARGET|VM[0-9])' > "$EVIDENCE_DIR/environment-vars.txt" 2>/dev/null || true
    whoami > "$EVIDENCE_DIR/operator-info.txt" 2>/dev/null
    hostname >> "$EVIDENCE_DIR/operator-info.txt" 2>/dev/null
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" >> "$EVIDENCE_DIR/operator-info.txt" 2>/dev/null

    # Network connectivity tests
    log_info "Testing network connectivity to sites"
    if [[ -n "${VM2_IP:-}" ]]; then
        echo "Testing VM2 (edge1): $VM2_IP" >> "$EVIDENCE_DIR/network-tests.txt"
        ping -c 3 "$VM2_IP" >> "$EVIDENCE_DIR/network-tests.txt" 2>&1 || true
        echo "---" >> "$EVIDENCE_DIR/network-tests.txt"
    fi

    if [[ -n "${VM4_IP:-}" ]]; then
        echo "Testing VM4 (edge2): $VM4_IP" >> "$EVIDENCE_DIR/network-tests.txt"
        ping -c 3 "$VM4_IP" >> "$EVIDENCE_DIR/network-tests.txt" 2>&1 || true
        echo "---" >> "$EVIDENCE_DIR/network-tests.txt"
    fi

    log_info "Pre-rollback evidence collection completed"
}

# Create comprehensive rollback snapshots
create_rollback_snapshots() {
    if [[ "$CREATE_SNAPSHOTS" != "true" ]]; then
        log_info "Snapshot creation disabled"
        return 0
    fi

    log_info "Creating comprehensive rollback snapshots"

    local snapshot_timestamp=$(date +%Y%m%d_%H%M%S)

    # Git repository snapshot
    log_info "Creating git repository snapshot"
    git bundle create "$SNAPSHOTS_DIR/repo-snapshot-${snapshot_timestamp}.bundle" --all 2>/dev/null || {
        log_warn "Failed to create git bundle, using tar archive"
        tar -czf "$SNAPSHOTS_DIR/repo-snapshot-${snapshot_timestamp}.tar.gz" \
            --exclude='.git/objects/pack/*.pack' \
            --exclude='node_modules' \
            --exclude='*.log' \
            .git/ 2>/dev/null || true
    }

    # Configuration snapshots
    if [[ -d "./config" ]]; then
        log_info "Creating configuration snapshot"
        tar -czf "$SNAPSHOTS_DIR/config-snapshot-${snapshot_timestamp}.tar.gz" ./config/ 2>/dev/null || true
    fi

    if [[ -d "./gitops" ]]; then
        log_info "Creating GitOps configuration snapshot"
        tar -czf "$SNAPSHOTS_DIR/gitops-snapshot-${snapshot_timestamp}.tar.gz" ./gitops/ 2>/dev/null || true
    fi

    # Kubernetes resources snapshot
    if command -v kubectl &> /dev/null; then
        log_info "Creating Kubernetes resources snapshot"
        kubectl get all -A -o yaml > "$SNAPSHOTS_DIR/k8s-resources-${snapshot_timestamp}.yaml" 2>/dev/null || true

        # Custom resources
        if kubectl get crd &> /dev/null; then
            kubectl get crd -o yaml > "$SNAPSHOTS_DIR/k8s-crds-${snapshot_timestamp}.yaml" 2>/dev/null || true
        fi
    fi

    # Generate snapshot manifest
    cat > "$SNAPSHOTS_DIR/snapshot-manifest.json" <<EOF
{
  "snapshot": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "execution_id": "$EXECUTION_ID",
    "branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
    "commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "reason": "pre-rollback-snapshot"
  },
  "files": [
$(ls -la "$SNAPSHOTS_DIR"/*.{bundle,tar.gz,yaml} 2>/dev/null | awk '{print "    {\"name\": \"" $9 "\", \"size\": \"" $5 "\", \"modified\": \"" $6 " " $7 " " $8 "\"}"}' | sed 's/.*\///' | paste -sd ',' -)
  ]
}
EOF

    log_info "Rollback snapshots created successfully"
}

# Enhanced root cause analysis
perform_root_cause_analysis() {
    if [[ "$ENABLE_RCA" != "true" ]]; then
        log_info "Root cause analysis disabled"
        return 0
    fi

    log_info "Performing comprehensive root cause analysis"

    local rca_report="$RCA_DIR/root_cause_analysis.json"
    local rca_summary="$RCA_DIR/rca_summary.md"

    # Initialize RCA report
    cat > "$rca_report" <<EOF
{
  "rca": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")",
    "execution_id": "$EXECUTION_ID",
    "analysis_depth": $RCA_DEPTH,
    "current_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "current_branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')"
  },
  "findings": []
}
EOF

    # Analyze recent commits
    log_info "Analyzing recent commits for potential issues"
    local commit_analysis=()

    for i in $(seq 1 $RCA_DEPTH); do
        local commit_hash=$(git rev-parse "HEAD~$((i-1))" 2>/dev/null || echo "")
        if [[ -n "$commit_hash" ]]; then
            local commit_message=$(git log --format="%s" -n 1 "$commit_hash" 2>/dev/null || echo "unknown")
            local commit_author=$(git log --format="%an" -n 1 "$commit_hash" 2>/dev/null || echo "unknown")
            local commit_date=$(git log --format="%ai" -n 1 "$commit_hash" 2>/dev/null || echo "unknown")
            local files_changed=$(git diff-tree --no-commit-id --name-only -r "$commit_hash" 2>/dev/null | wc -l || echo "0")

            # Analyze commit patterns that might indicate issues
            local risk_factors=()
            if echo "$commit_message" | grep -qi -E "(fix|bug|error|issue|problem|urgent)"; then
                risk_factors+=("emergency_fix")
            fi
            if echo "$commit_message" | grep -qi -E "(config|configuration|settings)"; then
                risk_factors+=("configuration_change")
            fi
            if echo "$commit_message" | grep -qi -E "(deploy|release|publish)"; then
                risk_factors+=("deployment_related")
            fi
            if [[ $files_changed -gt 10 ]]; then
                risk_factors+=("large_changeset")
            fi

            local commit_data=$(jq -n \
                --arg hash "$commit_hash" \
                --arg message "$commit_message" \
                --arg author "$commit_author" \
                --arg date "$commit_date" \
                --arg files_changed "$files_changed" \
                --argjson risk_factors "$(printf '%s\n' "${risk_factors[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')" \
                '{
                    commit: $hash,
                    message: $message,
                    author: $author,
                    date: $date,
                    files_changed: ($files_changed | tonumber),
                    risk_factors: $risk_factors
                }')

            commit_analysis+=("$commit_data")
        fi
    done

    # Analyze postcheck reports if available
    local postcheck_analysis=""
    if [[ "$ANALYZE_POSTCHECK_REPORT" == "true" ]]; then
        log_info "Analyzing recent postcheck reports"

        # Find recent postcheck reports
        local recent_reports=($(find ./reports -name "postcheck_report.json" -mtime -1 2>/dev/null | sort -r | head -3 || true))

        if [[ ${#recent_reports[@]} -gt 0 ]]; then
            local latest_report="${recent_reports[0]}"
            if [[ -f "$latest_report" ]]; then
                log_info "Analyzing postcheck report: $latest_report"

                local postcheck_status=$(jq -r '.validation.overall_status // "unknown"' "$latest_report" 2>/dev/null)
                local failed_sites=$(jq -r '.validation.sites[]? | select(.status == "FAIL") | .site' "$latest_report" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
                local violation_count=$(jq -r '.validation.sites[]? | select(.status == "FAIL") | length' "$latest_report" 2>/dev/null | wc -l)

                postcheck_analysis=$(jq -n \
                    --arg status "$postcheck_status" \
                    --arg failed_sites "$failed_sites" \
                    --arg violation_count "$violation_count" \
                    --arg report_path "$latest_report" \
                    '{
                        overall_status: $status,
                        failed_sites: ($failed_sites | split(",") | map(select(length > 0))),
                        violation_count: ($violation_count | tonumber),
                        report_path: $report_path
                    }')

                # Copy the postcheck report to RCA evidence
                cp "$latest_report" "$RCA_DIR/triggering_postcheck_report.json" 2>/dev/null || true
            fi
        else
            log_warn "No recent postcheck reports found for analysis"
        fi
    fi

    # Build comprehensive RCA findings
    local findings=$(jq -n \
        --argjson commits "$(printf '%s\n' "${commit_analysis[@]}" | jq -s . 2>/dev/null || echo '[]')" \
        --argjson postcheck "${postcheck_analysis:-null}" \
        '{
            commit_analysis: $commits,
            postcheck_analysis: $postcheck,
            analysis_timestamp: (now | strftime("%Y-%m-%dT%H:%M:%S.%3NZ"))
        }')

    # Update RCA report
    jq --argjson findings "$findings" '.findings = $findings' "$rca_report" > "$rca_report.tmp" && mv "$rca_report.tmp" "$rca_report"

    # Generate human-readable RCA summary
    cat > "$rca_summary" <<EOF
# Root Cause Analysis Summary

**Execution ID:** $EXECUTION_ID
**Analysis Time:** $(date)
**Analysis Depth:** $RCA_DEPTH commits

## Recent Commits Analysis

$(for data in "${commit_analysis[@]}"; do
    local hash=$(echo "$data" | jq -r '.commit')
    local message=$(echo "$data" | jq -r '.message')
    local author=$(echo "$data" | jq -r '.author')
    local date=$(echo "$data" | jq -r '.date')
    local risk_factors=$(echo "$data" | jq -r '.risk_factors[]?' 2>/dev/null | tr '\n' ', ' | sed 's/, $//')

    echo "- **${hash:0:8}** by $author on $date"
    echo "  - Message: $message"
    [[ -n "$risk_factors" ]] && echo "  - Risk Factors: $risk_factors"
    echo ""
done)

## Postcheck Analysis

EOF

    if [[ -n "$postcheck_analysis" ]]; then
        local postcheck_status=$(echo "$postcheck_analysis" | jq -r '.overall_status')
        local failed_sites=$(echo "$postcheck_analysis" | jq -r '.failed_sites[]?' 2>/dev/null | tr '\n' ', ' | sed 's/, $//')

        cat >> "$rca_summary" <<EOF
- **Status:** $postcheck_status
- **Failed Sites:** ${failed_sites:-"none"}
- **Violation Count:** $(echo "$postcheck_analysis" | jq -r '.violation_count')

EOF
    else
        echo "- No recent postcheck reports available for analysis" >> "$rca_summary"
    fi

    cat >> "$rca_summary" <<EOF

## Recommended Actions

$(
if echo "$findings" | jq -e '.postcheck_analysis.overall_status == "FAIL"' &>/dev/null; then
    echo "1. **Immediate:** Rollback triggered by SLO violations"
    echo "2. **Investigation:** Review failed site metrics and logs"
    echo "3. **Prevention:** Enhance testing for similar changes"
elif echo "$findings" | jq -e '.commit_analysis[] | .risk_factors[] | select(. == "emergency_fix")' &>/dev/null; then
    echo "1. **Review:** Emergency fixes detected - ensure proper testing"
    echo "2. **Process:** Consider implementing stricter change controls"
else
    echo "1. **Standard:** Following normal rollback procedures"
    echo "2. **Monitor:** Watch for similar patterns in future deployments"
fi
)

## Evidence Location

- Full RCA Report: $rca_report
- Pre-rollback Evidence: $EVIDENCE_DIR
- Rollback Snapshots: $SNAPSHOTS_DIR

EOF

    log_info "✅ Root cause analysis completed"
    log_info "📋 RCA Summary: $rca_summary"
}

# Enhanced Git state validation with multi-site awareness
validate_git_state() {
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "Not inside a git repository"
        exit $EXIT_CONFIG_ERROR
    fi

    local current_branch=$(git branch --show-current)
    log_info "Current branch: $current_branch"
    log_info "Target publish branch: $PUBLISH_BRANCH"

    # Handle site-specific branches
    if [[ "$SITE_SPECIFIC_BRANCHES" == "true" && "$TARGET_SITE" != "both" ]]; then
        local site_branch="${PUBLISH_BRANCH}-${TARGET_SITE}"
        if git show-ref --verify --quiet "refs/heads/$site_branch"; then
            PUBLISH_BRANCH="$site_branch"
            log_info "Using site-specific branch: $PUBLISH_BRANCH"
        fi
    fi

    if [[ "$current_branch" != "$PUBLISH_BRANCH" ]]; then
        log_warn "Current branch '$current_branch' differs from publish branch '$PUBLISH_BRANCH'"

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would switch to branch: $PUBLISH_BRANCH"
        else
            log_info "Switching to publish branch '$PUBLISH_BRANCH'"
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

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warn "Uncommitted changes detected"
        git status --short > "$EVIDENCE_DIR/uncommitted-changes.txt" 2>/dev/null || true
    fi

    return 0
}

# Enhanced commit identification with intelligent pattern matching
find_deployment_commits() {
    local max_commits="${1:-10}"
    local commits_data=()

    log_info "Identifying deployment-related commits (analyzing last $max_commits commits)"

    # Enhanced patterns for identifying deployment commits
    local deployment_patterns=(
        "make publish-edge"
        "publish:"
        "deploy:"
        "release:"
        "feat: publish"
        "chore: deploy"
        "ci: release"
        "gitops:"
        "config: update.*site"
        "krm.*update"
        "intent.*deploy"
    )

    for i in $(seq 1 $max_commits); do
        local commit_hash=$(git rev-parse "HEAD~$((i-1))" 2>/dev/null || echo "")
        if [[ -n "$commit_hash" ]]; then
            local commit_message=$(git log --format="%s" -n 1 "$commit_hash" 2>/dev/null || echo "")
            local commit_author=$(git log --format="%an" -n 1 "$commit_hash" 2>/dev/null || echo "")
            local commit_date=$(git log --format="%ai" -n 1 "$commit_hash" 2>/dev/null || echo "")
            local files_changed=$(git diff-tree --no-commit-id --name-only -r "$commit_hash" 2>/dev/null)

            # Check if this commit matches deployment patterns
            local is_deployment=false
            local matched_pattern=""

            for pattern in "${deployment_patterns[@]}"; do
                if echo "$commit_message" | grep -qi -E "$pattern"; then
                    is_deployment=true
                    matched_pattern="$pattern"
                    break
                fi
            done

            # Also check if gitops files were changed
            if echo "$files_changed" | grep -q -E "(gitops/|krm/|manifests/)"; then
                is_deployment=true
                [[ -z "$matched_pattern" ]] && matched_pattern="gitops_file_changes"
            fi

            local commit_data=$(jq -n \
                --arg hash "$commit_hash" \
                --arg message "$commit_message" \
                --arg author "$commit_author" \
                --arg date "$commit_date" \
                --arg is_deployment "$is_deployment" \
                --arg pattern "$matched_pattern" \
                --arg files_changed "$(echo "$files_changed" | tr '\n' ',')" \
                '{
                    commit: $hash,
                    message: $message,
                    author: $author,
                    date: $date,
                    is_deployment: ($is_deployment | test("true")),
                    matched_pattern: $pattern,
                    files_changed: ($files_changed | split(",") | map(select(length > 0)))
                }')

            commits_data+=("$commit_data")

            if [[ "$is_deployment" == "true" ]]; then
                log_info "Found deployment commit: ${commit_hash:0:8} - $commit_message (pattern: $matched_pattern)"
            fi
        fi
    done

    # Save commit analysis
    printf '%s\n' "${commits_data[@]}" | jq -s . > "$EVIDENCE_DIR/commit-analysis.json"

    # Return the most recent deployment commit
    local deployment_commit=$(printf '%s\n' "${commits_data[@]}" | jq -s -r '.[] | select(.is_deployment) | .commit' | head -1)

    if [[ -n "$deployment_commit" ]]; then
        echo "$deployment_commit"
    else
        # Fallback to HEAD if no deployment-specific commit found
        echo "$(git rev-parse HEAD)"
    fi
}

# Enhanced rollback tag creation with metadata
create_enhanced_rollback_tag() {
    local commit_to_rollback="$1"
    local rollback_reason="${2:-SLO-violation}"
    local tag_name="${ROLLBACK_TAG_PREFIX}-$(date +%Y%m%d-%H%M%S)-${rollback_reason//[^a-zA-Z0-9-]/-}"

    log_info "Creating enhanced rollback tag: $tag_name"

    # Create detailed tag message
    local tag_message="Rollback tag for commit $commit_to_rollback

Reason: $rollback_reason
Strategy: $ROLLBACK_STRATEGY
Target Site: $TARGET_SITE
Execution ID: $EXECUTION_ID
Operator: $(whoami)
Hostname: $(hostname)
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

Evidence: $EVIDENCE_DIR
Snapshots: $SNAPSHOTS_DIR
Report: $REPORT_FILE"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create tag: $tag_name for commit $commit_to_rollback"
        return 0
    fi

    if ! git tag -a "$tag_name" "$commit_to_rollback" -m "$tag_message"; then
        log_error "Failed to create rollback tag"
        return $EXIT_GIT_OPERATION_FAILED
    fi

    # Push tag to remote
    if ! git push "$REMOTE_NAME" "$tag_name"; then
        log_warn "Failed to push rollback tag to remote (continuing anyway)"
    fi

    # Also push to backup remote if configured
    if [[ -n "$BACKUP_REMOTE" ]] && git remote get-url "$BACKUP_REMOTE" &>/dev/null; then
        git push "$BACKUP_REMOTE" "$tag_name" 2>/dev/null || log_warn "Failed to push tag to backup remote"
    fi

    echo "$tag_name"
    return 0
}

# Selective rollback for multi-site deployments
perform_selective_rollback() {
    local commit_to_rollback="$1"
    local rollback_reason="${2:-SLO-violation}"
    local target_sites="${3:-$TARGET_SITE}"

    log_info "Performing selective rollback for sites: $target_sites"
    log_info "Rollback strategy: selective (site-specific rollback)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would perform selective rollback for commit: $commit_to_rollback"
        return 0
    fi

    # Create selective rollback branch
    local selective_branch="rollback-selective-$(date +%Y%m%d-%H%M%S)"
    git checkout -b "$selective_branch" "$commit_to_rollback" || {
        log_error "Failed to create selective rollback branch"
        return $EXIT_GIT_OPERATION_FAILED
    }

    # Apply selective changes based on target sites
    case "$target_sites" in
        "edge1")
            # Rollback only edge1-specific configurations
            if [[ -d "./gitops/edge1-config" ]]; then
                git checkout HEAD~1 -- ./gitops/edge1-config/ 2>/dev/null || true
            fi
            ;;
        "edge2")
            # Rollback only edge2-specific configurations
            if [[ -d "./gitops/edge2-config" ]]; then
                git checkout HEAD~1 -- ./gitops/edge2-config/ 2>/dev/null || true
            fi
            ;;
        "both")
            # Full selective rollback
            if [[ -d "./gitops" ]]; then
                git checkout HEAD~1 -- ./gitops/ 2>/dev/null || true
            fi
            ;;
    esac

    # Commit selective changes
    if git diff --cached --quiet; then
        log_warn "No selective changes to commit"
        git checkout "$PUBLISH_BRANCH"
        git branch -D "$selective_branch" 2>/dev/null || true
        return 0
    fi

    local selective_message="Selective rollback for $target_sites

Original commit: $commit_to_rollback
Reason: $rollback_reason
Execution ID: $EXECUTION_ID
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")"

    git commit -m "$selective_message" || {
        log_error "Failed to commit selective rollback changes"
        return $EXIT_GIT_OPERATION_FAILED
    }

    # Merge back to publish branch
    git checkout "$PUBLISH_BRANCH"
    git merge --no-ff "$selective_branch" -m "Merge selective rollback for $target_sites" || {
        log_error "Failed to merge selective rollback"
        return $EXIT_GIT_OPERATION_FAILED
    }

    # Cleanup selective branch
    git branch -d "$selective_branch" 2>/dev/null || true

    log_info "Selective rollback completed successfully"
    return 0
}

# Enhanced revert rollback with conflict resolution
perform_enhanced_revert_rollback() {
    local commit_to_rollback="$1"
    local rollback_reason="${2:-SLO-violation}"

    log_info "Performing enhanced revert rollback for commit: $commit_to_rollback"
    log_info "Rollback strategy: revert (preserves git history)"

    # Create rollback tag
    local tag_name
    if ! tag_name=$(create_enhanced_rollback_tag "$commit_to_rollback" "$rollback_reason"); then
        log_error "Failed to create rollback tag"
        return $EXIT_GIT_OPERATION_FAILED
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would revert commit: $commit_to_rollback"
        return 0
    fi

    # Perform git revert with enhanced conflict handling
    if ! git revert --no-edit "$commit_to_rollback"; then
        log_error "Git revert failed for commit: $commit_to_rollback"

        # Enhanced conflict resolution
        if git status --porcelain | grep -q "^UU"; then
            log_error "Merge conflicts detected during revert"

            # Save conflict information
            git status --porcelain | grep "^UU" > "$EVIDENCE_DIR/revert-conflicts.txt" || true
            git diff > "$EVIDENCE_DIR/revert-conflict-diff.patch" || true

            log_info "Conflict details saved to evidence directory"
            log_info "Manual resolution required. Conflicts in:"
            git status --porcelain | grep "^UU" | awk '{print "  - " $2}' || true

            # Attempt automatic resolution for common conflicts
            log_info "Attempting automatic conflict resolution..."

            # For gitops configs, prefer the previous version
            local conflicted_files=$(git status --porcelain | grep "^UU" | awk '{print $2}')
            for file in $conflicted_files; do
                if echo "$file" | grep -q -E "(gitops/|config/|manifests/)"; then
                    log_info "Auto-resolving gitops conflict in: $file"
                    git checkout --ours "$file" 2>/dev/null || true
                    git add "$file" 2>/dev/null || true
                fi
            done

            # Check if all conflicts are resolved
            if ! git status --porcelain | grep -q "^UU"; then
                log_info "All conflicts auto-resolved, completing revert"
                git commit --no-edit || {
                    log_error "Failed to commit resolved revert"
                    return $EXIT_GIT_OPERATION_FAILED
                }
            else
                log_error "Manual conflict resolution still required"
                log_info "To complete the rollback manually:"
                log_info "  1. Resolve conflicts in the above files"
                log_info "  2. git add <resolved-files>"
                log_info "  3. git commit"
                log_info "  4. git push $REMOTE_NAME $PUBLISH_BRANCH"
                return $EXIT_GIT_OPERATION_FAILED
            fi
        else
            # Other revert failure
            return $EXIT_GIT_OPERATION_FAILED
        fi
    fi

    log_info "✅ Enhanced revert rollback completed successfully"
    return 0
}

# Enhanced reset rollback with safety checks
perform_enhanced_reset_rollback() {
    local rollback_reason="${1:-SLO-violation}"

    log_info "Performing enhanced reset rollback to main branch"
    log_info "Rollback strategy: reset (clean rollback to known good state)"

    # Create rollback tag for current HEAD before reset
    local current_commit=$(git rev-parse HEAD)
    local tag_name
    if ! tag_name=$(create_enhanced_rollback_tag "HEAD" "$rollback_reason"); then
        log_error "Failed to create pre-reset rollback tag"
        return $EXIT_GIT_OPERATION_FAILED
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would reset to: $MAIN_BRANCH"
        return 0
    fi

    # Safety backup before reset
    local backup_branch="backup-before-reset-$(date +%Y%m%d-%H%M%S)"
    git branch "$backup_branch" HEAD || {
        log_warn "Failed to create backup branch (continuing anyway)"
    }

    # Fetch latest main branch
    log_info "Fetching latest main branch from remote"
    if ! git fetch "$REMOTE_NAME" "$MAIN_BRANCH"; then
        log_error "Failed to fetch latest main branch"
        return $EXIT_GIT_OPERATION_FAILED
    fi

    # Check if main branch has advanced significantly
    local commits_behind=$(git rev-list --count "HEAD..$REMOTE_NAME/$MAIN_BRANCH" 2>/dev/null || echo "0")
    local commits_ahead=$(git rev-list --count "$REMOTE_NAME/$MAIN_BRANCH..HEAD" 2>/dev/null || echo "0")

    log_info "Branch comparison: $commits_ahead commits ahead, $commits_behind commits behind main"

    if [[ $commits_behind -gt 50 ]]; then
        log_warn "Main branch is significantly ahead ($commits_behind commits). Consider reviewing changes."
    fi

    # Perform reset with verification
    local main_commit=$(git rev-parse "$REMOTE_NAME/$MAIN_BRANCH")
    log_info "Resetting to main branch commit: ${main_commit:0:8}"

    if ! git reset --hard "$REMOTE_NAME/$MAIN_BRANCH"; then
        log_error "Git reset failed"

        # Attempt recovery
        log_info "Attempting to restore from backup branch"
        git reset --hard "$backup_branch" 2>/dev/null || {
            log_error "Failed to restore from backup branch"
            return $EXIT_GIT_OPERATION_FAILED
        }

        return $EXIT_GIT_OPERATION_FAILED
    fi

    # Verify reset was successful
    local post_reset_commit=$(git rev-parse HEAD)
    if [[ "$post_reset_commit" == "$main_commit" ]]; then
        log_info "✅ Reset verification passed"
        # Clean up backup branch
        git branch -D "$backup_branch" 2>/dev/null || true
    else
        log_error "Reset verification failed"
        return $EXIT_GIT_OPERATION_FAILED
    fi

    log_info "✅ Enhanced reset rollback completed successfully"
    return 0
}

# Enhanced push with verification and recovery
push_rollback_changes() {
    log_info "Pushing rollback changes to remote with enhanced verification"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would push rollback changes to $REMOTE_NAME/$PUBLISH_BRANCH"
        return 0
    fi

    # Pre-push verification
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "$REMOTE_NAME/$PUBLISH_BRANCH" 2>/dev/null || echo "unknown")

    log_info "Local commit: ${local_commit:0:8}"
    log_info "Remote commit: ${remote_commit:0:8}"

    # Prepare push arguments
    local push_args=("$REMOTE_NAME" "$PUBLISH_BRANCH")

    if [[ "$FORCE_PUSH" == "true" ]] && [[ "$ROLLBACK_STRATEGY" == "reset" ]]; then
        push_args+=("--force-with-lease")
        log_warn "Using force push with lease for reset rollback"
    fi

    # Attempt push with retry logic
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Push attempt $attempt/$max_attempts"

        if git push "${push_args[@]}"; then
            log_info "✅ Push successful on attempt $attempt"
            break
        else
            local push_exit_code=$?
            log_warn "Push attempt $attempt failed (exit code: $push_exit_code)"

            if [[ $attempt -eq $max_attempts ]]; then
                log_error "All push attempts failed"

                # Save push failure evidence
                git status > "$EVIDENCE_DIR/push-failure-status.txt" 2>/dev/null || true
                git log --oneline -5 > "$EVIDENCE_DIR/push-failure-commits.txt" 2>/dev/null || true

                return $EXIT_PUSH_FAILED
            fi

            # Wait before retry
            log_info "Waiting 10 seconds before retry..."
            sleep 10

            # Fetch latest remote changes
            git fetch "$REMOTE_NAME" "$PUBLISH_BRANCH" 2>/dev/null || true

            ((attempt++))
        fi
    done

    # Post-push verification
    if ! git fetch "$REMOTE_NAME" "$PUBLISH_BRANCH"; then
        log_warn "Failed to fetch after push for verification"
    else
        local post_push_remote_commit=$(git rev-parse "$REMOTE_NAME/$PUBLISH_BRANCH")
        if [[ "$local_commit" == "$post_push_remote_commit" ]]; then
            log_info "✅ Post-push verification successful"
        else
            log_error "Post-push verification failed - remote commit mismatch"
            return $EXIT_PUSH_FAILED
        fi
    fi

    # Push to backup remote if configured
    if [[ -n "$BACKUP_REMOTE" ]] && git remote get-url "$BACKUP_REMOTE" &>/dev/null; then
        log_info "Pushing to backup remote: $BACKUP_REMOTE"
        git push "$BACKUP_REMOTE" "$PUBLISH_BRANCH" 2>/dev/null || log_warn "Failed to push to backup remote"
    fi

    log_info "✅ Rollback changes pushed successfully"
    return 0
}

# Enhanced notification system
send_enhanced_notifications() {
    local rollback_type="$1"
    local commit_info="$2"
    local rollback_reason="${3:-SLO-violation}"
    local notification_status="${4:-success}"

    log_info "Sending enhanced rollback notifications"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local status_emoji="🔄"
    local color="warning"

    case "$notification_status" in
        "success")
            status_emoji="✅"
            color="good"
            ;;
        "failure")
            status_emoji="❌"
            color="danger"
            ;;
        "warning")
            status_emoji="⚠️"
            color="warning"
            ;;
    esac

    local base_message="$status_emoji Rollback $notification_status: $rollback_type strategy for commit ${commit_info:0:8}"
    local detailed_message="$base_message

**Details:**
- Reason: $rollback_reason
- Strategy: $rollback_type
- Target Site: $TARGET_SITE
- Execution ID: $EXECUTION_ID
- Timestamp: $timestamp
- Operator: $(whoami)@$(hostname)

**Evidence:**
- Report: $REPORT_FILE
- Evidence: $EVIDENCE_DIR
- Snapshots: $SNAPSHOTS_DIR"

    # Webhook notification
    if [[ -n "$NOTIFY_WEBHOOK" ]]; then
        log_debug "Sending webhook notification"
        local webhook_payload=$(jq -n \
            --arg message "$base_message" \
            --arg detailed_message "$detailed_message" \
            --arg type "rollback" \
            --arg status "$notification_status" \
            --arg commit "$commit_info" \
            --arg strategy "$rollback_type" \
            --arg reason "$rollback_reason" \
            --arg execution_id "$EXECUTION_ID" \
            --arg timestamp "$timestamp" \
            '{
                message: $message,
                detailed_message: $detailed_message,
                type: $type,
                status: $status,
                commit: $commit,
                strategy: $strategy,
                reason: $reason,
                execution_id: $execution_id,
                timestamp: $timestamp
            }')

        curl -s -X POST "$NOTIFY_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$webhook_payload" || log_warn "Failed to send webhook notification"
    fi

    # Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        log_debug "Sending Slack notification"
        local slack_payload=$(jq -n \
            --arg text "$detailed_message" \
            --arg color "$color" \
            '{
                text: $text,
                attachments: [{
                    color: $color,
                    fields: [
                        {title: "Strategy", value: "'"$rollback_type"'", short: true},
                        {title: "Target", value: "'"$TARGET_SITE"'", short: true},
                        {title: "Reason", value: "'"$rollback_reason"'", short: true},
                        {title: "Status", value: "'"$notification_status"'", short: true}
                    ]
                }]
            }')

        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$slack_payload" || log_warn "Failed to send Slack notification"
    fi

    # Microsoft Teams notification
    if [[ -n "$TEAMS_WEBHOOK" ]]; then
        log_debug "Sending Teams notification"
        local teams_payload=$(jq -n \
            --arg text "$base_message" \
            --arg summary "$base_message" \
            --arg color "$color" \
            '{
                "@type": "MessageCard",
                "@context": "https://schema.org/extensions",
                summary: $summary,
                themeColor: (if $color == "good" then "00FF00" elif $color == "danger" then "FF0000" else "FFAA00" end),
                sections: [{
                    activityTitle: $text,
                    facts: [
                        {name: "Strategy", value: "'"$rollback_type"'"},
                        {name: "Target Site", value: "'"$TARGET_SITE"'"},
                        {name: "Reason", value: "'"$rollback_reason"'"},
                        {name: "Execution ID", value: "'"$EXECUTION_ID"'"}
                    ]
                }]
            }')

        curl -s -X POST "$TEAMS_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$teams_payload" || log_warn "Failed to send Teams notification"
    fi

    # Email notification (if configured with sendmail)
    if [[ -n "$EMAIL_RECIPIENTS" ]] && command -v sendmail &> /dev/null; then
        log_debug "Sending email notification"
        local subject="Rollback $notification_status - $rollback_reason"

        cat <<EOF | sendmail "$EMAIL_RECIPIENTS" || log_warn "Failed to send email notification"
Subject: $subject
Content-Type: text/plain

$detailed_message

This is an automated message from the Nephio rollback system.
EOF
    fi

    log_info "✅ Enhanced notifications sent"
}

# Generate comprehensive rollback report
generate_comprehensive_rollback_report() {
    local rollback_status="$1"
    local rollback_type="$2"
    local commit_info="$3"
    local rollback_reason="${4:-SLO-violation}"

    log_info "Generating comprehensive rollback report"

    local end_time=$(date +%s)
    local start_time_file="$ROLLBACK_DIR/.start_time"
    local start_time=$end_time

    if [[ -f "$start_time_file" ]]; then
        start_time=$(cat "$start_time_file")
    fi

    local duration=$((end_time - start_time))

    # Collect git information
    local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local commits_rolled_back=$(git rev-list --count "$current_commit..$commit_info" 2>/dev/null || echo "0")

    # Generate comprehensive report
    local report_data=$(jq -n \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" \
        --arg execution_id "$EXECUTION_ID" \
        --arg script_version "$SCRIPT_VERSION" \
        --arg rollback_status "$rollback_status" \
        --arg rollback_type "$rollback_type" \
        --arg rollback_reason "$rollback_reason" \
        --arg target_site "$TARGET_SITE" \
        --arg original_commit "$commit_info" \
        --arg current_commit "$current_commit" \
        --arg current_branch "$current_branch" \
        --arg commits_rolled_back "$commits_rolled_back" \
        --arg duration "$duration" \
        --arg operator "$(whoami)" \
        --arg hostname "$(hostname)" \
        --argjson dry_run "$([[ "$DRY_RUN" == "true" ]] && echo "true" || echo "false")" \
        '{
            metadata: {
                timestamp: $timestamp,
                execution_id: $execution_id,
                script_version: $script_version,
                operator: $operator,
                hostname: $hostname
            },
            rollback: {
                status: $rollback_status,
                strategy: $rollback_type,
                reason: $rollback_reason,
                target_site: $target_site,
                dry_run: $dry_run,
                duration_seconds: ($duration | tonumber)
            },
            git_state: {
                original_commit: $original_commit,
                current_commit: $current_commit,
                current_branch: $current_branch,
                commits_rolled_back: ($commits_rolled_back | tonumber),
                publish_branch: "'"$PUBLISH_BRANCH"'",
                main_branch: "'"$MAIN_BRANCH"'"
            },
            evidence: {
                evidence_dir: "'"$EVIDENCE_DIR"'",
                snapshots_dir: "'"$SNAPSHOTS_DIR"'",
                rca_dir: "'"$RCA_DIR"'",
                collected_evidence: '$([[ "$COLLECT_EVIDENCE" == "true" ]] && echo "true" || echo "false")',
                created_snapshots: '$([[ "$CREATE_SNAPSHOTS" == "true" ]] && echo "true" || echo "false")',
                performed_rca: '$([[ "$ENABLE_RCA" == "true" ]] && echo "true" || echo "false")'
            }
        }')

    # Save main report
    echo "$report_data" | jq . > "$REPORT_FILE"

    # Generate checksums for integrity
    if command -v sha256sum &> /dev/null; then
        find "$ROLLBACK_DIR" -type f -name "*.json" -exec sha256sum {} \; > "$ROLLBACK_DIR/checksums.sha256"
    fi

    # Create human-readable summary
    cat > "$ROLLBACK_DIR/summary.txt" <<EOF
=== Rollback Summary ===

Execution ID: $EXECUTION_ID
Timestamp: $(date)
Status: $rollback_status
Strategy: $rollback_type
Reason: $rollback_reason
Target Site: $TARGET_SITE
Duration: ${duration}s

Git State:
- Original Commit: $commit_info
- Current Commit: $current_commit
- Branch: $current_branch
- Commits Rolled Back: $commits_rolled_back

Evidence and Artifacts:
- Main Report: $REPORT_FILE
- Evidence Directory: $EVIDENCE_DIR
- Snapshots Directory: $SNAPSHOTS_DIR
- RCA Directory: $RCA_DIR

$(if [[ "$DRY_RUN" == "true" ]]; then
    echo "NOTE: This was a DRY RUN - no actual changes were made"
fi)

EOF

    # Update manifest with final results
    jq --arg status "$rollback_status" --arg report_file "$REPORT_FILE" --arg duration "$duration" \
        '.results = {status: $status, report_file: $report_file, duration_seconds: ($duration | tonumber), completed_at: (now | strftime("%Y-%m-%dT%H:%M:%S.%3NZ"))}' \
        "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

    log_info "✅ Comprehensive rollback report generated: $REPORT_FILE"
    log_info "📊 Summary available at: $ROLLBACK_DIR/summary.txt"
}

# Main rollback execution with enhanced error handling
main() {
    local rollback_reason="${1:-SLO-violation}"
    local start_time=$(date +%s)

    # Store start time for duration calculation
    echo "$start_time" > "$ROLLBACK_DIR/.start_time" 2>/dev/null || true

    log_info "🔄 Starting enhanced rollback process"
    log_info "📋 Execution ID: $EXECUTION_ID"
    log_info "🎯 Target sites: $TARGET_SITE"
    log_info "📊 Script version: $SCRIPT_VERSION"
    log_info "🔧 Strategy: $ROLLBACK_STRATEGY"
    log_info "❓ Reason: $rollback_reason"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🧪 DRY-RUN MODE: No changes will be made"
    fi

    # Initialize environment
    check_dependencies
    initialize_rollback_environment

    # Collect evidence before any changes
    collect_pre_rollback_evidence

    # Create snapshots for safety
    create_rollback_snapshots

    # Perform root cause analysis
    perform_root_cause_analysis

    # Validate git repository state
    local validation_result
    if ! validation_result=$(validate_git_state); then
        if [[ $validation_result -eq $EXIT_NO_COMMITS_TO_ROLLBACK ]]; then
            log_info "✅ No rollback needed: branch is clean"
            generate_comprehensive_rollback_report "not_needed" "none" "none" "$rollback_reason"
            exit $EXIT_SUCCESS
        else
            log_error "❌ Git state validation failed"
            send_enhanced_notifications "validation" "unknown" "$rollback_reason" "failure"
            generate_comprehensive_rollback_report "failed" "validation" "unknown" "$rollback_reason"
            exit $validation_result
        fi
    fi

    # Determine rollback approach
    local rollback_success=false
    local commit_info=""
    local rollback_type_executed=""

    case "$ROLLBACK_STRATEGY" in
        "selective")
            commit_info=$(find_deployment_commits 5)
            rollback_type_executed="selective"
            if perform_selective_rollback "$commit_info" "$rollback_reason" "$TARGET_SITE"; then
                rollback_success=true
            fi
            ;;
        "revert")
            commit_info=$(find_deployment_commits 5)
            rollback_type_executed="revert"
            if perform_enhanced_revert_rollback "$commit_info" "$rollback_reason"; then
                rollback_success=true
            fi
            ;;
        "reset")
            commit_info="$(git rev-parse HEAD)"
            rollback_type_executed="reset"
            if perform_enhanced_reset_rollback "$rollback_reason"; then
                rollback_success=true
            fi
            ;;
        *)
            log_error "Unknown rollback strategy: $ROLLBACK_STRATEGY"
            send_enhanced_notifications "$ROLLBACK_STRATEGY" "unknown" "$rollback_reason" "failure"
            generate_comprehensive_rollback_report "failed" "$ROLLBACK_STRATEGY" "unknown" "$rollback_reason"
            exit $EXIT_CONFIG_ERROR
            ;;
    esac

    # Handle rollback execution results
    if [[ "$rollback_success" != "true" ]]; then
        log_error "❌ Rollback execution failed"
        send_enhanced_notifications "$rollback_type_executed" "$commit_info" "$rollback_reason" "failure"
        generate_comprehensive_rollback_report "failed" "$rollback_type_executed" "$commit_info" "$rollback_reason"
        exit $EXIT_GIT_OPERATION_FAILED
    fi

    # Push changes (if not dry run)
    if [[ "$DRY_RUN" != "true" ]]; then
        if ! push_rollback_changes; then
            log_error "❌ Failed to push rollback changes"
            send_enhanced_notifications "$rollback_type_executed" "$commit_info" "$rollback_reason" "failure"
            generate_comprehensive_rollback_report "failed" "$rollback_type_executed" "$commit_info" "$rollback_reason"
            exit $EXIT_PUSH_FAILED
        fi
    fi

    # Success notifications and reporting
    send_enhanced_notifications "$rollback_type_executed" "$commit_info" "$rollback_reason" "success"
    generate_comprehensive_rollback_report "success" "$rollback_type_executed" "$commit_info" "$rollback_reason"

    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))

    log_info "🎉 Rollback completed successfully!"
    log_info "✅ SUCCESS: $rollback_type_executed strategy executed for $rollback_reason"
    log_info "⏱️  Total execution time: ${total_time}s"
    log_info "📊 Report: $REPORT_FILE"
    log_info "📋 Evidence: $EVIDENCE_DIR"
    log_info "💾 Snapshots: $SNAPSHOTS_DIR"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🧪 DRY-RUN completed - no actual changes were made"
    fi

    exit $EXIT_SUCCESS
}

# Enhanced signal handling
cleanup() {
    local exit_code=$?
    log_warn "🛑 Rollback process interrupted (exit code: $exit_code)"

    # Save partial results if available
    if [[ -n "${ROLLBACK_DIR:-}" && -d "$ROLLBACK_DIR" ]]; then
        echo "Interrupted at $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" > "$ROLLBACK_DIR/interrupted.txt"
        echo "Exit code: $exit_code" >> "$ROLLBACK_DIR/interrupted.txt"
        echo "Execution ID: $EXECUTION_ID" >> "$ROLLBACK_DIR/interrupted.txt"
    fi

    # Send interruption notification
    if [[ -n "${NOTIFY_WEBHOOK:-}" || -n "${SLACK_WEBHOOK:-}" ]]; then
        send_enhanced_notifications "interrupted" "unknown" "user-interruption" "failure" &
    fi

    exit $exit_code
}

trap cleanup INT TERM

# Enhanced help function
show_help() {
    cat <<EOF
Enhanced Rollback System v$SCRIPT_VERSION

Usage: $SCRIPT_NAME [OPTIONS] [REASON]

Arguments:
  REASON                   Optional reason for rollback (default: SLO-violation)

Options:
  -h, --help              Show this help message
  --strategy STRATEGY     Rollback strategy: revert|reset|selective (default: revert)
  --target-site SITE      Target site(s): edge1|edge2|both (default: both)
  --dry-run              Enable dry-run mode - no changes made
  --collect-evidence     Enable comprehensive evidence collection (default: true)
  --create-snapshots     Create rollback snapshots (default: true)
  --enable-rca           Enable root cause analysis (default: true)
  --log-json             Enable JSON logging format

Environment Variables:
  ROLLBACK_STRATEGY       Rollback strategy: revert|reset|selective
  TARGET_SITE            Target site(s): edge1|edge2|both
  PUBLISH_BRANCH         Branch to rollback (default: feat/slo-gate)
  MAIN_BRANCH           Main branch for reset strategy (default: main)
  DRY_RUN               Enable dry-run mode (true/false)
  COLLECT_EVIDENCE      Enable evidence collection (true/false)
  CREATE_SNAPSHOTS      Create safety snapshots (true/false)
  ENABLE_RCA           Enable root cause analysis (true/false)

Notification Variables:
  NOTIFY_WEBHOOK        Generic webhook URL for notifications
  SLACK_WEBHOOK        Slack webhook URL
  TEAMS_WEBHOOK        Microsoft Teams webhook URL
  EMAIL_RECIPIENTS     Email addresses for notifications

Examples:
  $SCRIPT_NAME                                    # Standard SLO rollback
  $SCRIPT_NAME "security-vulnerability"          # Security rollback
  ROLLBACK_STRATEGY=reset DRY_RUN=true $SCRIPT_NAME        # Dry-run reset
  TARGET_SITE=edge1 ROLLBACK_STRATEGY=selective $SCRIPT_NAME  # Selective edge1 rollback
  LOG_JSON=true $SCRIPT_NAME                      # JSON logging

Rollback Strategies:
  revert     - Create revert commit (preserves history, safest)
  reset      - Hard reset to main branch (clean slate, more disruptive)
  selective  - Site-specific rollback (multi-site deployments)

Exit Codes:
  0  - Success: Rollback completed
  1  - No commits to rollback
  2  - Git operation failed
  3  - Push to remote failed
  4  - Missing dependencies
  5  - Configuration error
  6  - Evidence collection failed
  7  - Snapshot creation failed
  8  - Root cause analysis failed
  9  - Multi-site rollback failure
  10 - Partial rollback failed

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --strategy)
            ROLLBACK_STRATEGY="$2"
            shift 2
            ;;
        --target-site)
            TARGET_SITE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --collect-evidence)
            COLLECT_EVIDENCE="true"
            shift
            ;;
        --create-snapshots)
            CREATE_SNAPSHOTS="true"
            shift
            ;;
        --enable-rca)
            ENABLE_RCA="true"
            shift
            ;;
        --log-json)
            LOG_JSON="true"
            shift
            ;;
        --*)
            log_error "Unknown option: $1"
            show_help
            exit $EXIT_CONFIG_ERROR
            ;;
        *)
            # This is the rollback reason
            main "$1"
            exit $?
            ;;
    esac
done

# No reason provided, use default
main "SLO-violation"