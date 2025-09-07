#!/bin/bash
set -euo pipefail

echo "========================================="
echo "Gitea Connection Diagnostics"
echo "========================================="

# Check Kubernetes service
echo -e "\n[1] Checking Gitea service in Kubernetes..."
kubectl get svc -n gitea-system gitea-service 2>/dev/null || {
    echo "ERROR: Gitea service not found in gitea-system namespace"
    echo "Checking all namespaces..."
    kubectl get svc -A | grep -i gitea || echo "No Gitea service found"
}

# Get service details
GITEA_SVC=$(kubectl get svc -n gitea-system gitea-service -o json 2>/dev/null || echo "{}")
LB_IP=$(echo "$GITEA_SVC" | jq -r '.status.loadBalancer.ingress[0].ip // "Not assigned"')
NODE_PORT=$(echo "$GITEA_SVC" | jq -r '.spec.ports[] | select(.port==3000) | .nodePort // "Not found"')
CLUSTER_IP=$(echo "$GITEA_SVC" | jq -r '.spec.clusterIP // "Not found"')

echo -e "\n[2] Service Details:"
echo "  LoadBalancer IP: $LB_IP"
echo "  NodePort: $NODE_PORT"
echo "  ClusterIP: $CLUSTER_IP"

# Test connectivity
echo -e "\n[3] Testing connectivity..."

# Test LoadBalancer
if [ "$LB_IP" != "Not assigned" ]; then
    echo -n "  LoadBalancer ($LB_IP:3000): "
    if curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP:3000" 2>/dev/null | grep -q "200"; then
        echo "✓ OK"
        WORKING_URL="http://$LB_IP:3000"
    else
        echo "✗ Failed"
    fi
fi

# Test NodePort
if [ "$NODE_PORT" != "Not found" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo -n "  NodePort ($NODE_IP:$NODE_PORT): "
    if curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$NODE_PORT" 2>/dev/null | grep -q "200"; then
        echo "✓ OK"
        WORKING_URL="http://$NODE_IP:$NODE_PORT"
    else
        echo "✗ Failed"
    fi
fi

# Port forward test
echo -e "\n[4] Alternative: Port-forward method"
echo "  kubectl port-forward -n gitea-system svc/gitea-service 3000:3000 &"
echo "  export GITEA_URL=\"http://localhost:3000\""

# Recommendation
echo -e "\n========================================="
echo "RECOMMENDATION:"
echo "========================================="
if [ -n "${WORKING_URL:-}" ]; then
    echo "Use this in your scripts/env.sh:"
    echo "  export GITEA_URL=\"$WORKING_URL\""
else
    echo "No direct connection available. Use port-forward:"
    echo "  kubectl port-forward -n gitea-system svc/gitea-service 3000:3000 &"
    echo "  export GITEA_URL=\"http://localhost:3000\""
fi

echo -e "\nTo create a token:"
echo "  1. Visit: ${WORKING_URL:-http://localhost:3000}/user/settings/applications"
echo "  2. Generate New Token with 'repo' scope"
echo "  3. export GITEA_TOKEN=\"<your-token>\""