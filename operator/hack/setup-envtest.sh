#!/usr/bin/env bash

# Copyright 2025 The Nephio Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o pipefail

# Ensure envtest binaries are installed
ENVTEST_K8S_VERSION=${ENVTEST_K8S_VERSION:-"1.28"}
ENVTEST_ASSETS_DIR=${ENVTEST_ASSETS_DIR:-"$(pwd)/testbin"}

echo "Setting up envtest with Kubernetes ${ENVTEST_K8S_VERSION}..."

# Create testbin directory
mkdir -p ${ENVTEST_ASSETS_DIR}

# Install setup-envtest if not present
if ! command -v setup-envtest &> /dev/null; then
    echo "Installing setup-envtest..."
    go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
fi

# Download and setup envtest assets
setup-envtest use ${ENVTEST_K8S_VERSION} --bin-dir ${ENVTEST_ASSETS_DIR}

# Export paths for testing
export KUBEBUILDER_ASSETS="${ENVTEST_ASSETS_DIR}"

echo "✅ envtest setup complete!"
echo "   KUBEBUILDER_ASSETS=${KUBEBUILDER_ASSETS}"