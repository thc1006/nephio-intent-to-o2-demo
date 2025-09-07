#!/bin/bash
# Setup Gitea repository and token for edge configuration

set -euo pipefail

# Configuration
GITEA_URL="${GITEA_URL:-http://172.18.0.200:3000}"
GITEA_USER="${GITEA_USER:-admin}"
GITEA_REPO="${GITEA_REPO:-edge1-config}"
NAMESPACE="${NAMESPACE:-config-management-system}"

echo "Gitea Configuration Setup"
echo "========================="
echo "GITEA_URL: $GITEA_URL"
echo "Repository: $GITEA_USER/$GITEA_REPO"
echo "Namespace: $NAMESPACE"
echo ""

# Check if Gitea is accessible
echo "Checking Gitea availability..."
if curl -s -o /dev/null -w "%{http_code}" "$GITEA_URL" | grep -q "200"; then
    echo "✅ Gitea is accessible at $GITEA_URL"
else
    echo "⚠️  Gitea might not be ready. You can access it via:"
    echo "   kubectl port-forward -n gitea-system svc/gitea-service 3000:3000"
    echo "   Then access: http://localhost:3000"
fi

# Create namespace if not exists
echo ""
echo "Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Check for existing secret
if kubectl get secret gitea-token -n "$NAMESPACE" &>/dev/null; then
    echo "✅ Secret gitea-token already exists in $NAMESPACE"
else
    echo ""
    echo "⚠️  Secret gitea-token not found!"
    echo ""
    echo "To create the token:"
    echo "1. Access Gitea UI: $GITEA_URL"
    echo "2. Login as admin (default password might need to be set)"
    echo "3. Go to Settings → Applications"
    echo "4. Generate New Token with 'repo' scope"
    echo "5. Create the secret with:"
    echo ""
    echo "kubectl create secret generic gitea-token \\"
    echo "  -n $NAMESPACE \\"
    echo "  --from-literal=username=$GITEA_USER \\"
    echo "  --from-literal=token=YOUR_TOKEN_HERE"
fi

echo ""
echo "Repository Configuration for ConfigSync:"
echo "========================================="
echo "apiVersion: configsync.gke.io/v1beta1"
echo "kind: RootSync"
echo "metadata:"
echo "  name: edge1-rootsync"
echo "  namespace: config-management-system"
echo "spec:"
echo "  sourceType: git"
echo "  git:"
echo "    repo: $GITEA_URL/$GITEA_USER/$GITEA_REPO"
echo "    branch: main"
echo "    dir: /"
echo "    auth: token"
echo "    secretRef:"
echo "      name: gitea-token"

echo ""
echo "Next Steps:"
echo "1. Create the Gitea token via UI"
echo "2. Create the secret with the token"
echo "3. Create the repository '$GITEA_REPO' in Gitea"
echo "4. Apply the RootSync configuration"