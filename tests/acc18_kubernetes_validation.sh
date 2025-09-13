#!/bin/bash
"""
ACC-18 Kubernetes Validation
Validates generated KRM files can be applied to Kubernetes cluster (dry-run)
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 ACC-18 Kubernetes Validation${NC}"
echo -e "${BLUE}================================${NC}"

PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
RENDERED_DIR="$PROJECT_ROOT/rendered/krm"

# Check if kubectl is available (mock or real)
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠️  kubectl not available - skipping Kubernetes validation${NC}"
    exit 0
fi

echo -e "\n${YELLOW}🔍 Validating KRM files for Kubernetes compliance...${NC}"

# Validation results
total_files=0
valid_files=0
invalid_files=0

# Function to validate a single file
validate_krm_file() {
    local file_path="$1"
    local file_name=$(basename "$file_path")

    echo -e "  📄 Validating: $file_name"

    # Perform dry-run validation
    if kubectl apply --dry-run=client -f "$file_path" &>/dev/null; then
        echo -e "    ✅ Valid Kubernetes resource"
        ((valid_files++))
    else
        echo -e "    ❌ Invalid Kubernetes resource"
        ((invalid_files++))
    fi

    ((total_files++))
}

# Validate all generated golden intent KRM files
echo -e "\n${YELLOW}📁 Edge1 Site Validation:${NC}"
if [ -d "$RENDERED_DIR/edge1" ]; then
    for file in "$RENDERED_DIR/edge1"/golden-*.yaml; do
        if [ -f "$file" ]; then
            validate_krm_file "$file"
        fi
    done

    # Validate kustomization
    if [ -f "$RENDERED_DIR/edge1/kustomization.yaml" ]; then
        validate_krm_file "$RENDERED_DIR/edge1/kustomization.yaml"
    fi
fi

echo -e "\n${YELLOW}📁 Edge2 Site Validation:${NC}"
if [ -d "$RENDERED_DIR/edge2" ]; then
    for file in "$RENDERED_DIR/edge2"/golden-*.yaml; do
        if [ -f "$file" ]; then
            validate_krm_file "$file"
        fi
    done

    # Validate kustomization
    if [ -f "$RENDERED_DIR/edge2/kustomization.yaml" ]; then
        validate_krm_file "$RENDERED_DIR/edge2/kustomization.yaml"
    fi
fi

# Generate validation summary
echo -e "\n${BLUE}📊 Kubernetes Validation Summary:${NC}"
echo -e "📄 Total Files Validated: $total_files"
echo -e "✅ Valid Resources: $valid_files"
echo -e "❌ Invalid Resources: $invalid_files"

if [ $invalid_files -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All KRM files are Kubernetes compliant!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  $invalid_files file(s) failed Kubernetes validation${NC}"
    exit 1
fi