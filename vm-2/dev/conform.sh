#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET_PATH="${1:-.}"
VERBOSE="${VERBOSE:-false}"
STRICT="${STRICT:-true}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.27.0}"

# Counters
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
SKIPPED_FILES=0

echo -e "${GREEN}=== Kubeconform Validation ===${NC}"
echo -e "${YELLOW}Target Path: ${TARGET_PATH}${NC}"
echo -e "${YELLOW}Kubernetes Version: ${KUBERNETES_VERSION}${NC}"
echo -e "${YELLOW}Strict Mode: ${STRICT}${NC}\n"

# Check if kubeconform is installed
if ! command -v kubeconform &> /dev/null; then
    echo -e "${YELLOW}⚠ kubeconform not found. Installing...${NC}"
    
    # Download and install kubeconform
    KUBECONFORM_VERSION="0.6.3"
    curl -L -o /tmp/kubeconform.tar.gz \
        "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
    
    tar xzf /tmp/kubeconform.tar.gz -C /tmp
    sudo mv /tmp/kubeconform /usr/local/bin/
    rm /tmp/kubeconform.tar.gz
    
    echo -e "${GREEN}✓ kubeconform installed${NC}\n"
fi

# Function to validate a single file
validate_file() {
    local file="$1"
    local relative_path="${file#$TARGET_PATH/}"
    
    # Skip non-YAML files
    if [[ ! "$file" =~ \.(yaml|yml)$ ]]; then
        return
    fi
    
    # Skip kustomization files by default
    if [[ "$(basename "$file")" == "kustomization.yaml" ]] || [[ "$(basename "$file")" == "kustomization.yml" ]]; then
        if [ "$VERBOSE" == "true" ]; then
            echo -e "${BLUE}⊘ Skipping: ${relative_path} (kustomization file)${NC}"
        fi
        ((SKIPPED_FILES++))
        return
    fi
    
    ((TOTAL_FILES++))
    
    # Build kubeconform command
    local cmd="kubeconform"
    cmd="$cmd -kubernetes-version $KUBERNETES_VERSION"
    cmd="$cmd -summary"
    
    if [ "$STRICT" == "true" ]; then
        cmd="$cmd -strict"
    fi
    
    if [ "$VERBOSE" == "true" ]; then
        cmd="$cmd -verbose"
    fi
    
    # Run validation
    if $cmd "$file" &> /tmp/kubeconform_output.txt; then
        echo -e "${GREEN}✓${NC} ${relative_path}"
        ((PASSED_FILES++))
        
        if [ "$VERBOSE" == "true" ]; then
            cat /tmp/kubeconform_output.txt | sed 's/^/  /'
        fi
    else
        echo -e "${RED}✗${NC} ${relative_path}"
        ((FAILED_FILES++))
        
        # Show error details
        cat /tmp/kubeconform_output.txt | sed 's/^/  /' | head -10
        
        # If file has too many errors, indicate there's more
        if [ $(wc -l < /tmp/kubeconform_output.txt) -gt 10 ]; then
            echo -e "  ${YELLOW}... (truncated, use VERBOSE=true for full output)${NC}"
        fi
    fi
}

# Function to recursively find and validate files
validate_directory() {
    local dir="$1"
    
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo -e "${RED}Error: Directory '$dir' does not exist${NC}"
        exit 1
    fi
    
    # Find all YAML files
    while IFS= read -r -d '' file; do
        validate_file "$file"
    done < <(find "$dir" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 | sort -z)
}

# Main validation
echo -e "${BLUE}Validating Kubernetes manifests...${NC}\n"

if [ -f "$TARGET_PATH" ]; then
    # Single file validation
    validate_file "$TARGET_PATH"
else
    # Directory validation
    validate_directory "$TARGET_PATH"
fi

# Summary
echo -e "\n${GREEN}=== Validation Summary ===${NC}"
echo -e "Total files checked: ${TOTAL_FILES}"
echo -e "${GREEN}Passed: ${PASSED_FILES}${NC}"
echo -e "${RED}Failed: ${FAILED_FILES}${NC}"
echo -e "${BLUE}Skipped: ${SKIPPED_FILES}${NC}"

# Exit code based on failures
if [ $FAILED_FILES -gt 0 ]; then
    echo -e "\n${RED}Validation FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}Validation PASSED${NC}"
    exit 0
fi