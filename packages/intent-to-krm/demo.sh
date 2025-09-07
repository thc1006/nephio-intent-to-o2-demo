#!/bin/bash
set -e

echo "🚀 Intent-to-KRM GitOps Pipeline Demo"
echo "===================================="
echo

echo "📋 Step 1: Building and Testing the kpt Function"
make test-short
echo "✅ Tests passed"
echo

echo "📦 Step 2: Rendering KRM Artifacts from Intent Expectations"
make render
echo "✅ KRM artifacts generated:"
ls -la artifacts/
echo

echo "🔧 Step 3: Preparing Edge Deployment Overlay"
make prepare-edge
echo "✅ Edge overlay prepared:"
ls -la dist/edge1/
echo

echo "🎯 Step 4: Generating Final Kustomized YAML"
kubectl kustomize dist/edge1 > dist/edge1-rendered.yaml
echo "✅ Generated $(wc -l < dist/edge1-rendered.yaml) lines of Kubernetes YAML"
echo

echo "📊 Step 5: Showing Resource Summary"
echo "Resources to be deployed to edge1 namespace:"
kubectl kustomize dist/edge1 | grep -E "^kind:|^  name:" | paste - -
echo

echo "🔍 Step 6: Validating Generated Resources"
if command -v kubeconform >/dev/null 2>&1; then
    kubeconform -summary dist/edge1-rendered.yaml
    echo "✅ All resources are valid Kubernetes manifests"
else
    echo "⚠️  kubeconform not available - skipping validation"
    echo "   Install with: go install github.com/yannh/kubeconform/cmd/kubeconform@latest"
fi
echo

echo "🏁 Pipeline Complete!"
echo "=============================="
echo "To deploy to a GitOps repository:"
echo "  export EDGE_REPO_DIR=/path/to/your/gitops/repo"
echo "  make publish-edge"
echo
echo "Generated files:"
echo "  - artifacts/: Raw KRM from intent expectations" 
echo "  - dist/edge1/: Kustomize overlay for edge deployment"
echo "  - dist/edge1-rendered.yaml: Final Kubernetes manifests ($(wc -l < dist/edge1-rendered.yaml) lines)"
echo
echo "Next steps:"
echo "  1. Review generated manifests in dist/edge1-rendered.yaml"
echo "  2. Set up your GitOps repository with EDGE_REPO_DIR"
echo "  3. Run 'make publish-edge' to deploy via GitOps"
echo "  4. Monitor deployment with O-RAN O2 IMS integration"