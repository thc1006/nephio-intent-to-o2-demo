#!/bin/bash

# CI/CD Pipeline - Smoke Test Environment Setup
# Sets up minimal environment for smoke testing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "::notice::Setting up smoke test environment..."

cd "$REPO_ROOT"

# Ensure required directories exist
mkdir -p artifacts reports

# Install basic dependencies if not present
echo "Installing basic dependencies..."

# Install yamllint if not present
if ! command -v yamllint &> /dev/null; then
    echo "Installing yamllint..."
    pip3 install yamllint
fi

# Install yq if not present (lightweight YAML processor)
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    wget -O /tmp/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /tmp/yq
    sudo mv /tmp/yq /usr/local/bin/yq
fi

# Verify Git configuration
if ! git config user.name >/dev/null 2>&1; then
    git config user.name "CI Smoke Test"
fi

if ! git config user.email >/dev/null 2>&1; then
    git config user.email "ci-smoke-test@nephio-intent-demo.local"
fi

echo "✅ Smoke test environment setup completed"