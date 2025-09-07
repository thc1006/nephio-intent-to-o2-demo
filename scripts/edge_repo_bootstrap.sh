#!/bin/bash

# edge_repo_bootstrap.sh
# Bootstrap a private Gitea repository for edge GitOps configuration
# 
# This script creates and initializes a Gitea repository with proper GitOps structure
# for edge deployments in the Nephio intent-to-o2 pipeline.
#
# Environment Variables:
#   GITEA_URL         - Base URL of the Gitea instance (required)
#   GITEA_TOKEN       - API token for Gitea (optional, falls back to user/pass)
#   GITEA_USER        - Gitea username (required if no token)  
#   GITEA_PASS        - Gitea password (required if no token)
#   EDGE_REPO_DIR     - Local directory for repository (default: ./edge-gitops)
#   EDGE_REPO_NAME    - Repository name in Gitea (default: edge-gitops)
#   EDGE_CLUSTER_NAME - Cluster name for GitOps structure (default: edge-cluster-01)

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script metadata
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_VERSION="1.0.0"

# Default values
readonly DEFAULT_EDGE_REPO_DIR="edge-gitops"
readonly DEFAULT_EDGE_REPO_NAME="edge-gitops"
readonly DEFAULT_CLUSTER_NAME="edge-cluster-01"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_fatal() {
    log_error "$@"
    exit 1
}

# Usage information
show_usage() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

Bootstrap a private Gitea repository for edge GitOps configuration.

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

REQUIRED ENVIRONMENT VARIABLES:
    GITEA_URL         Base URL of the Gitea instance (e.g., https://git.example.com)

AUTHENTICATION (one of):
    GITEA_TOKEN       API token for Gitea authentication (recommended)
    OR
    GITEA_USER        Gitea username
    GITEA_PASS        Gitea password

OPTIONAL ENVIRONMENT VARIABLES:
    EDGE_REPO_DIR     Local directory for repository (default: ${DEFAULT_EDGE_REPO_DIR})
    EDGE_REPO_NAME    Repository name in Gitea (default: ${DEFAULT_EDGE_REPO_NAME})
    EDGE_CLUSTER_NAME Cluster name for GitOps structure (default: ${DEFAULT_CLUSTER_NAME})

OPTIONS:
    -h, --help        Show this help message
    -v, --version     Show version information
    --dry-run         Show what would be done without executing
    --force           Force recreation of existing repository

EXAMPLES:
    # Using API token (recommended)
    export GITEA_URL="https://git.example.com"
    export GITEA_TOKEN="your-api-token"
    ./${SCRIPT_NAME}

    # Using username/password
    export GITEA_URL="https://git.example.com"
    export GITEA_USER="admin"
    export GITEA_PASS="password"
    ./${SCRIPT_NAME}

    # Custom repository name and cluster
    export GITEA_URL="https://git.example.com"
    export GITEA_TOKEN="your-api-token"
    export EDGE_REPO_NAME="my-edge-cluster"
    export EDGE_CLUSTER_NAME="production-edge-01"
    ./${SCRIPT_NAME}
EOF
}

# Version information
show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
}

# Validate required tools
check_dependencies() {
    local missing_tools=()
    
    for tool in curl git jq; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            missing_tools+=("${tool}")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_fatal "Missing required tools: ${missing_tools[*]}"
    fi
}

# Validate environment variables
validate_environment() {
    # Check required variables
    if [[ -z "${GITEA_URL:-}" ]]; then
        log_fatal "GITEA_URL is required"
    fi
    
    # Validate authentication
    if [[ -z "${GITEA_TOKEN:-}" ]]; then
        if [[ -z "${GITEA_USER:-}" || -z "${GITEA_PASS:-}" ]]; then
            log_fatal "Either GITEA_TOKEN or both GITEA_USER and GITEA_PASS must be set"
        fi
        log_warn "Using username/password authentication. API token is recommended for security."
    fi
    
    # Normalize GITEA_URL (remove trailing slash)
    GITEA_URL="${GITEA_URL%/}"
    
    # Set defaults for optional variables
    EDGE_REPO_DIR="${EDGE_REPO_DIR:-${DEFAULT_EDGE_REPO_DIR}}"
    EDGE_REPO_NAME="${EDGE_REPO_NAME:-${DEFAULT_EDGE_REPO_NAME}}"
    EDGE_CLUSTER_NAME="${EDGE_CLUSTER_NAME:-${DEFAULT_CLUSTER_NAME}}"
    
    # Validate repository name (basic validation)
    if [[ ! "${EDGE_REPO_NAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_fatal "Invalid repository name: ${EDGE_REPO_NAME}. Use alphanumeric, dots, dashes, underscores only."
    fi
}

# Test Gitea connectivity and authentication
test_gitea_connection() {
    log_info "Testing Gitea connectivity and authentication..."
    
    local auth_header
    if [[ -n "${GITEA_TOKEN:-}" ]]; then
        auth_header="Authorization: token ${GITEA_TOKEN}"
    else
        # Create basic auth header
        local auth_string="${GITEA_USER}:${GITEA_PASS}"
        local encoded_auth
        encoded_auth=$(echo -n "${auth_string}" | base64 -w 0)
        auth_header="Authorization: Basic ${encoded_auth}"
    fi
    
    local response
    if ! response=$(curl -s -w "%{http_code}" -H "${auth_header}" "${GITEA_URL}/api/v1/user" 2>/dev/null); then
        log_fatal "Failed to connect to Gitea at ${GITEA_URL}"
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    case "${http_code}" in
        200)
            local username
            username=$(echo "${body}" | jq -r '.username // "unknown"')
            log_success "Connected to Gitea as user: ${username}"
            ;;
        401)
            log_fatal "Authentication failed. Check your credentials."
            ;;
        *)
            log_fatal "Unexpected response from Gitea (HTTP ${http_code}): ${body}"
            ;;
    esac
}

# Check if repository exists
check_repository_exists() {
    local auth_header
    if [[ -n "${GITEA_TOKEN:-}" ]]; then
        auth_header="Authorization: token ${GITEA_TOKEN}"
    else
        local auth_string="${GITEA_USER}:${GITEA_PASS}"
        local encoded_auth
        encoded_auth=$(echo -n "${auth_string}" | base64 -w 0)
        auth_header="Authorization: Basic ${encoded_auth}"
    fi
    
    local response
    response=$(curl -s -w "%{http_code}" -H "${auth_header}" "${GITEA_URL}/api/v1/user/repos" 2>/dev/null)
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "${http_code}" == "200" ]]; then
        if echo "${body}" | jq -e ".[] | select(.name == \"${EDGE_REPO_NAME}\")" >/dev/null 2>&1; then
            return 0  # Repository exists
        fi
    fi
    
    return 1  # Repository does not exist
}

# Create repository via Gitea API
create_gitea_repository() {
    log_info "Creating Gitea repository: ${EDGE_REPO_NAME}"
    
    local auth_header
    local curl_auth_option
    if [[ -n "${GITEA_TOKEN:-}" ]]; then
        auth_header="Authorization: token ${GITEA_TOKEN}"
        curl_auth_option=(-H "${auth_header}")
    else
        curl_auth_option=(-u "${GITEA_USER}:${GITEA_PASS}")
    fi
    
    local repo_payload
    repo_payload=$(jq -n \
        --arg name "${EDGE_REPO_NAME}" \
        --arg description "Edge GitOps configuration repository for ${EDGE_CLUSTER_NAME}" \
        '{
            name: $name,
            description: $description,
            private: true,
            auto_init: false,
            default_branch: "main"
        }')
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create repository with payload:"
        echo "${repo_payload}" | jq .
        echo
        log_info "[DRY RUN] curl command:"
        echo "curl -X POST \"${GITEA_URL}/api/v1/user/repos\" \\"
        if [[ -n "${GITEA_TOKEN:-}" ]]; then
            echo "  -H 'Authorization: token \$GITEA_TOKEN' \\"
        else
            echo "  -u '\$GITEA_USER:\$GITEA_PASS' \\"
        fi
        echo "  -H 'Content-Type: application/json' \\"
        echo "  -d '${repo_payload}'"
        return 0
    fi
    
    local response
    response=$(curl -s -w "%{http_code}" \
        "${curl_auth_option[@]}" \
        -H "Content-Type: application/json" \
        -d "${repo_payload}" \
        "${GITEA_URL}/api/v1/user/repos" 2>/dev/null)
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    case "${http_code}" in
        201)
            local clone_url
            clone_url=$(echo "${body}" | jq -r '.clone_url')
            log_success "Repository created successfully"
            log_info "Clone URL: ${clone_url}"
            echo "${clone_url}"
            ;;
        409)
            log_warn "Repository already exists"
            # Get existing repository info
            local existing_repo_response
            existing_repo_response=$(curl -s "${curl_auth_option[@]}" "${GITEA_URL}/api/v1/repos/${GITEA_USER}/${EDGE_REPO_NAME}" 2>/dev/null)
            local existing_clone_url
            existing_clone_url=$(echo "${existing_repo_response}" | jq -r '.clone_url // empty')
            if [[ -n "${existing_clone_url}" ]]; then
                echo "${existing_clone_url}"
            else
                # Fallback to constructed URL
                if [[ -n "${GITEA_TOKEN:-}" ]]; then
                    echo "${GITEA_URL}/${GITEA_USER}/${EDGE_REPO_NAME}.git"
                else
                    echo "${GITEA_URL}/${GITEA_USER}/${EDGE_REPO_NAME}.git"
                fi
            fi
            ;;
        *)
            log_fatal "Failed to create repository (HTTP ${http_code}): ${body}"
            ;;
    esac
}

# Generate GitOps directory structure
create_gitops_structure() {
    local repo_dir="$1"
    
    log_info "Creating GitOps directory structure in ${repo_dir}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would create directory structure:"
        cat << EOF
${repo_dir}/
├── README.md
├── kustomization.yaml
├── clusters/
│   └── ${EDGE_CLUSTER_NAME}/
│       ├── kustomization.yaml
│       └── namespace.yaml
├── apps/
│   └── .gitkeep
├── infrastructure/
│   └── .gitkeep
└── policies/
    └── .gitkeep
EOF
        return 0
    fi
    
    # Create directory structure
    mkdir -p "${repo_dir}"
    mkdir -p "${repo_dir}/clusters/${EDGE_CLUSTER_NAME}"
    mkdir -p "${repo_dir}/apps"
    mkdir -p "${repo_dir}/infrastructure"
    mkdir -p "${repo_dir}/policies"
    
    # Create .gitkeep files for empty directories
    touch "${repo_dir}/apps/.gitkeep"
    touch "${repo_dir}/infrastructure/.gitkeep"
    touch "${repo_dir}/policies/.gitkeep"
    
    # Create root README.md
    cat > "${repo_dir}/README.md" << EOF
# ${EDGE_REPO_NAME}

Edge GitOps configuration repository for **${EDGE_CLUSTER_NAME}**.

This repository follows GitOps principles and is structured for use with Flux or ArgoCD.

## Repository Structure

\`\`\`
.
├── README.md              # This file
├── kustomization.yaml     # Root kustomization
├── clusters/              # Cluster-specific configurations
│   └── ${EDGE_CLUSTER_NAME}/
│       ├── kustomization.yaml
│       └── namespace.yaml
├── apps/                  # Application manifests
├── infrastructure/        # Infrastructure components
└── policies/             # Security policies and governance
\`\`\`

## Usage

This repository is automatically synchronized with the **${EDGE_CLUSTER_NAME}** cluster.

### Adding Applications

1. Place application manifests in the \`apps/\` directory
2. Create or update kustomization.yaml files as needed
3. Commit and push changes

### Infrastructure Components

Place infrastructure-related manifests (operators, CRDs, etc.) in the \`infrastructure/\` directory.

### Security Policies

Security policies (Kyverno, OPA Gatekeeper, etc.) go in the \`policies/\` directory.

## Security

- This repository uses signed commits where possible
- All manifests are validated before deployment
- Supply chain security is enforced via Sigstore/Kyverno policies

## Generated by

This repository was bootstrapped using the Nephio intent-to-o2-demo edge repository bootstrap script.
EOF

    # Create root kustomization.yaml
    cat > "${repo_dir}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: ${EDGE_REPO_NAME}
  annotations:
    config.kubernetes.io/local-config: "true"

resources:
  - clusters/${EDGE_CLUSTER_NAME}
  - apps
  - infrastructure
  - policies

# Common labels applied to all resources
commonLabels:
  app.kubernetes.io/managed-by: gitops
  app.kubernetes.io/part-of: ${EDGE_REPO_NAME}
  cluster.nephio.io/name: ${EDGE_CLUSTER_NAME}

# Namespace for resources that don't specify one
namespace: gitops-system
EOF

    # Create cluster-specific kustomization.yaml
    cat > "${repo_dir}/clusters/${EDGE_CLUSTER_NAME}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: ${EDGE_CLUSTER_NAME}
  annotations:
    config.kubernetes.io/local-config: "true"

resources:
  - namespace.yaml

# Cluster-specific labels
commonLabels:
  cluster.nephio.io/name: ${EDGE_CLUSTER_NAME}
  cluster.nephio.io/type: edge

# Patches can be added here for cluster-specific customizations
patches: []
EOF

    # Create namespace.yaml
    cat > "${repo_dir}/clusters/${EDGE_CLUSTER_NAME}/namespace.yaml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${EDGE_CLUSTER_NAME}-system
  labels:
    cluster.nephio.io/name: ${EDGE_CLUSTER_NAME}
    cluster.nephio.io/type: edge
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Namespace","metadata":{"name":"${EDGE_CLUSTER_NAME}-system"}}
---
apiVersion: v1
kind: Namespace
metadata:
  name: gitops-system
  labels:
    cluster.nephio.io/name: ${EDGE_CLUSTER_NAME}
    app.kubernetes.io/managed-by: gitops
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

    log_success "GitOps structure created successfully"
}

# Initialize git repository
initialize_git_repository() {
    local repo_dir="$1"
    local clone_url="$2"
    
    log_info "Initializing git repository in ${repo_dir}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] Would initialize git repository and push to: ${clone_url}"
        return 0
    fi
    
    # Navigate to repository directory
    cd "${repo_dir}"
    
    # Initialize git repository if not already initialized
    if [[ ! -d ".git" ]]; then
        git init
        git config user.name "${GITEA_USER:-gitops-bot}"
        git config user.email "${GITEA_USER:-gitops-bot}@local"
        
        # Set main as default branch
        git branch -M main
    fi
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
    else
        # Commit initial structure
        git commit -m "Initial GitOps structure for ${EDGE_CLUSTER_NAME}

- Add root kustomization.yaml with common structure
- Create cluster-specific configuration for ${EDGE_CLUSTER_NAME}
- Set up directories for apps, infrastructure, and policies
- Include security-focused namespace configurations

Generated by nephio-intent-to-o2-demo edge bootstrap script"
    fi
    
    # Add remote origin if not already present
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "${clone_url}"
    else
        log_warn "Remote 'origin' already exists, updating URL"
        git remote set-url origin "${clone_url}"
    fi
    
    # Push to remote
    log_info "Pushing to remote repository..."
    
    # Configure git credential helper for this session if using token
    if [[ -n "${GITEA_TOKEN:-}" ]]; then
        # Extract hostname from clone URL for credential helper
        local git_host
        git_host=$(echo "${clone_url}" | sed -E 's|https?://([^/]+)/.*|\1|')
        
        # Configure credential helper to use token
        git config credential.helper cache
        echo "protocol=https
host=${git_host}
username=${GITEA_USER:-token}
password=${GITEA_TOKEN}" | git credential approve
    fi
    
    if git push -u origin main; then
        log_success "Repository pushed successfully"
    else
        log_error "Failed to push to remote repository"
        log_info "You may need to push manually using:"
        echo "  cd ${repo_dir}"
        echo "  git push -u origin main"
        return 1
    fi
}

# Cleanup function
cleanup() {
    # Clear git credentials if we set them
    if [[ -n "${GITEA_TOKEN:-}" ]]; then
        git credential reject <<< "protocol=https
host=${GITEA_URL#*://}
username=${GITEA_USER:-token}" 2>/dev/null || true
    fi
}

# Main function
main() {
    local dry_run=false
    local force=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --dry-run)
                dry_run=true
                export DRY_RUN=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                log_fatal "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Perform validations
    check_dependencies
    validate_environment
    
    log_info "Starting edge repository bootstrap for ${EDGE_CLUSTER_NAME}"
    log_info "Repository: ${EDGE_REPO_NAME}"
    log_info "Directory: ${EDGE_REPO_DIR}"
    log_info "Gitea URL: ${GITEA_URL}"
    
    if [[ "${dry_run}" == "true" ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
    fi
    
    # Test Gitea connection
    test_gitea_connection
    
    # Check if repository already exists
    if check_repository_exists; then
        if [[ "${force}" == "true" ]]; then
            log_warn "Repository exists, but --force specified, continuing..."
        else
            log_warn "Repository ${EDGE_REPO_NAME} already exists in Gitea"
            log_info "Use --force to proceed anyway, or choose a different repository name"
            if [[ "${dry_run}" == "false" ]]; then
                exit 1
            fi
        fi
    fi
    
    # Create or get repository
    local clone_url
    clone_url=$(create_gitea_repository)
    
    # Check if local directory already exists
    if [[ -d "${EDGE_REPO_DIR}" ]]; then
        if [[ "${force}" == "true" ]]; then
            log_warn "Local directory ${EDGE_REPO_DIR} exists, but --force specified"
            if [[ "${dry_run}" == "false" ]]; then
                rm -rf "${EDGE_REPO_DIR}"
            fi
        else
            log_fatal "Local directory ${EDGE_REPO_DIR} already exists. Use --force to overwrite or choose a different directory."
        fi
    fi
    
    # Create GitOps structure
    create_gitops_structure "${EDGE_REPO_DIR}"
    
    # Initialize git repository and push
    initialize_git_repository "${EDGE_REPO_DIR}" "${clone_url}"
    
    # Final success message
    if [[ "${dry_run}" == "true" ]]; then
        log_success "DRY RUN completed successfully"
    else
        log_success "Edge GitOps repository bootstrap completed successfully!"
        echo
        log_info "Repository details:"
        echo "  - Gitea URL: ${GITEA_URL}/$(echo "${clone_url}" | sed -E 's|.*/([^/]+/[^/]+)\.git|\1|')"
        echo "  - Local directory: ${EDGE_REPO_DIR}"
        echo "  - Clone URL: ${clone_url}"
        echo
        log_info "Next steps:"
        echo "  1. Configure your GitOps controller (Flux/ArgoCD) to sync from this repository"
        echo "  2. Add application manifests to the apps/ directory"
        echo "  3. Customize cluster-specific configurations in clusters/${EDGE_CLUSTER_NAME}/"
        echo "  4. Add infrastructure components and security policies as needed"
    fi
}

# Execute main function with all arguments
main "$@"