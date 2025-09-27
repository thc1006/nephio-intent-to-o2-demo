#!/bin/bash
# Porch Deployment Verification Script
# Usage: ./verify-porch.sh

set -e

echo "========================================"
echo "Porch Deployment Verification"
echo "========================================"
echo ""

# Check namespaces
echo "1. Checking Porch namespaces..."
kubectl get namespaces | grep porch || echo "❌ Porch namespaces not found"
echo ""

# Check pods
echo "2. Checking Porch pods..."
kubectl get pods -n porch-system
echo ""

# Check deployments
echo "3. Checking Porch deployments..."
kubectl get deployments -n porch-system
echo ""

# Check services
echo "4. Checking Porch services..."
kubectl get services -n porch-system
echo ""

# Check API service
echo "5. Checking Porch API service..."
kubectl get apiservices v1alpha1.porch.kpt.dev
echo ""

# Check CRDs
echo "6. Checking Porch CRDs..."
kubectl get crds | grep porch || echo "No Porch CRDs found"
echo ""

# Check API resources
echo "7. Checking Porch API resources..."
kubectl api-resources | grep -E "porch|package|repository"
echo ""

# Test PackageRevision API
echo "8. Testing PackageRevision API..."
kubectl get packagerevisions --all-namespaces 2>&1
echo ""

# Test Repository API
echo "9. Testing Repository API..."
kubectl get repositories --all-namespaces 2>&1
echo ""

# Check pod health
echo "10. Checking pod health..."
TOTAL_PODS=$(kubectl get pods -n porch-system --no-headers | wc -l)
READY_PODS=$(kubectl get pods -n porch-system --field-selector=status.phase=Running --no-headers | wc -l)

if [ "$TOTAL_PODS" -eq "$READY_PODS" ]; then
    echo "✅ All $READY_PODS/$TOTAL_PODS pods are Running"
else
    echo "⚠️  Only $READY_PODS/$TOTAL_PODS pods are Running"
    kubectl get pods -n porch-system | grep -v Running || true
fi
echo ""

# Overall status
echo "========================================"
echo "Deployment Status Summary"
echo "========================================"

API_STATUS=$(kubectl get apiservices v1alpha1.porch.kpt.dev -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

if [ "$API_STATUS" = "True" ] && [ "$TOTAL_PODS" -eq "$READY_PODS" ]; then
    echo "✅ Porch is FULLY OPERATIONAL"
    exit 0
else
    echo "⚠️  Porch has issues - please investigate"
    exit 1
fi