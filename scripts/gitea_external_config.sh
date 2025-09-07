#!/bin/bash
# Gitea External Configuration for VM-2 Integration

set -euo pipefail

# External Gitea Configuration
GITEA_URL="http://147.251.115.143:8888"
GITEA_USER="${GITEA_USER:-admin}"  # Update with actual username
GITEA_REPO="edge1-config"
NAMESPACE="config-management-system"

echo "=================================="
echo "Gitea External Configuration"
echo "=================================="
echo ""
echo "GITEA_URL: $GITEA_URL"
echo "Repository: $GITEA_USER/$GITEA_REPO"
echo "Namespace: $NAMESPACE"
echo "Secret: gitea-token"
echo ""

# Check Gitea accessibility
echo "Checking Gitea availability at external URL..."
if curl -s -o /dev/null -w "%{http_code}" "$GITEA_URL" | grep -q "200\|302"; then
    echo "✅ Gitea is accessible at $GITEA_URL"
else
    echo "⚠️  Cannot reach Gitea at $GITEA_URL"
    echo "   Please verify the URL and network connectivity"
fi

# Create namespace
echo ""
echo "Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Check for existing secret
echo ""
if kubectl get secret gitea-token -n "$NAMESPACE" &>/dev/null; then
    echo "✅ Secret 'gitea-token' exists in $NAMESPACE"
    echo ""
    echo "To view the secret:"
    echo "kubectl get secret gitea-token -n $NAMESPACE -o yaml"
else
    echo "⚠️  Secret 'gitea-token' not found in $NAMESPACE"
    echo ""
    echo "To create the Gitea token:"
    echo "1. Access Gitea: $GITEA_URL"
    echo "2. Login with your credentials"
    echo "3. Go to Settings → Applications → Generate New Token"
    echo "4. Name: 'nephio-edge1' (or any name)"
    echo "5. Select scopes: 'repo' (full control of private repositories)"
    echo "6. Generate Token and copy it"
    echo ""
    echo "Then create the secret:"
    echo "kubectl create secret generic gitea-token \\"
    echo "  -n $NAMESPACE \\"
    echo "  --from-literal=username=$GITEA_USER \\"
    echo "  --from-literal=token=<YOUR_GENERATED_TOKEN>"
fi

# Generate ConfigSync configuration
echo ""
echo "=================================="
echo "ConfigSync Configuration (for VM-2)"
echo "=================================="
cat <<EOF
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: edge1-rootsync
  namespace: config-management-system
spec:
  sourceType: git
  git:
    repo: $GITEA_URL/$GITEA_USER/$GITEA_REPO
    branch: main
    dir: "/"
    auth: token
    secretRef:
      name: gitea-token
    period: 30s
EOF

echo ""
echo "=================================="
echo "Repository Sync Configuration"
echo "=================================="
cat <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  enableMultiRepo: true
  sourceFormat: unstructured
EOF

echo ""
echo "=================================="
echo "Next Steps:"
echo "=================================="
echo "1. Create/verify Gitea user account at $GITEA_URL"
echo "2. Create repository '$GITEA_REPO' (private) in Gitea"
echo "3. Generate personal access token in Gitea"
echo "4. Create the secret with token on this cluster (VM-1)"
echo "5. Share this configuration with VM-2 for edge cluster setup"
echo ""
echo "For VM-2, provide:"
echo "- GITEA_URL=$GITEA_URL"
echo "- Repo: $GITEA_USER/$GITEA_REPO (private), branch=main, dir='/'"
echo "- Auth: token (Secret name: gitea-token) in namespace $NAMESPACE"