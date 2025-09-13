#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
IMAGES_FILE="${1:-images.txt}"
POLICY="${POLICY:-warn}"  # warn or block
VERBOSE="${VERBOSE:-false}"
COSIGN_EXPERIMENTAL="${COSIGN_EXPERIMENTAL:-1}"
export COSIGN_EXPERIMENTAL

# Counters
TOTAL_IMAGES=0
VERIFIED_IMAGES=0
UNSIGNED_IMAGES=0
FAILED_IMAGES=0

echo -e "${GREEN}=== Container Image Signature Verification ===${NC}"
echo -e "${YELLOW}Images File: ${IMAGES_FILE}${NC}"
echo -e "${YELLOW}Policy Mode: ${POLICY}${NC}"
echo -e "${YELLOW}Cosign Experimental: ${COSIGN_EXPERIMENTAL}${NC}\n"

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo -e "${YELLOW}⚠ cosign not found. Installing...${NC}"
    
    # Download and install cosign
    COSIGN_VERSION="2.2.2"
    curl -L -o /tmp/cosign \
        "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64"
    
    chmod +x /tmp/cosign
    sudo mv /tmp/cosign /usr/local/bin/
    
    echo -e "${GREEN}✓ cosign installed${NC}\n"
fi

# Check if images file exists
if [ ! -f "$IMAGES_FILE" ]; then
    echo -e "${YELLOW}Images file not found. Creating sample images.txt...${NC}"
    cat > "$IMAGES_FILE" <<EOF
# Sample images.txt file
# Add container images one per line
# Comments start with #
registry.k8s.io/git-sync/git-sync:v4.0.0
bitnami/kubectl:latest
busybox:latest
kindest/node:v1.27.3
EOF
    echo -e "${GREEN}Created sample ${IMAGES_FILE}${NC}\n"
fi

# Function to verify a single image
verify_image() {
    local image="$1"
    local status="UNKNOWN"
    local message=""
    
    echo -e "${BLUE}Verifying:${NC} $image"
    
    # Create temp file for output
    local output_file="/tmp/cosign_verify_$$.txt"
    
    # Try to verify the image
    if cosign verify --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' "$image" &> "$output_file" 2>&1; then
        status="VERIFIED"
        message="Signature verified successfully"
        ((VERIFIED_IMAGES++))
        echo -e "  ${GREEN}✓ PASS${NC} - $message"
        
        if [ "$VERBOSE" == "true" ]; then
            echo -e "  ${CYAN}Certificate Details:${NC}"
            grep -E "(Subject:|Issuer:|Certificate)" "$output_file" | head -5 | sed 's/^/    /'
        fi
    else
        # Check if it's unsigned or verification failed
        if grep -q "no signatures found\|no matching signatures" "$output_file"; then
            status="UNSIGNED"
            message="No signatures found"
            ((UNSIGNED_IMAGES++))
            
            if [ "$POLICY" == "block" ]; then
                echo -e "  ${RED}✗ FAIL${NC} - $message (BLOCKED by policy)"
            else
                echo -e "  ${YELLOW}⚠ WARN${NC} - $message"
            fi
        else
            status="FAILED"
            message="Verification failed"
            ((FAILED_IMAGES++))
            echo -e "  ${RED}✗ FAIL${NC} - $message"
            
            if [ "$VERBOSE" == "true" ]; then
                echo -e "  ${RED}Error Details:${NC}"
                head -5 "$output_file" | sed 's/^/    /'
            fi
        fi
    fi
    
    # Clean up
    rm -f "$output_file"
    
    echo ""
    return 0
}

# Function to extract images from Kubernetes manifests
extract_images_from_yaml() {
    local yaml_path="$1"
    local images_found=0
    
    echo -e "${BLUE}Extracting images from YAML files in: ${yaml_path}${NC}\n"
    
    # Find all YAML files and extract image references
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Extract images using grep and sed
            grep -h "image:" "$file" 2>/dev/null | \
                sed 's/.*image: *//; s/"//g; s/'\''//g' | \
                grep -v "^#" | \
                sort -u | \
                while read -r img; do
                    if [ -n "$img" ]; then
                        echo "$img" >> /tmp/extracted_images.txt
                        ((images_found++))
                    fi
                done
        fi
    done < <(find "$yaml_path" -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)
    
    if [ -f /tmp/extracted_images.txt ]; then
        sort -u /tmp/extracted_images.txt > "$IMAGES_FILE"
        rm /tmp/extracted_images.txt
        echo -e "${GREEN}Extracted $(wc -l < "$IMAGES_FILE") unique images${NC}\n"
    fi
}

# Main verification process
echo -e "${BLUE}Starting image verification...${NC}\n"

# If images.txt doesn't exist but a path is provided, try to extract images
if [ ! -f "$IMAGES_FILE" ] && [ -d "${1:-}" ]; then
    extract_images_from_yaml "${1}"
fi

# Read and verify each image
while IFS= read -r image; do
    # Skip empty lines and comments
    if [ -z "$image" ] || [[ "$image" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Trim whitespace
    image=$(echo "$image" | xargs)
    
    ((TOTAL_IMAGES++))
    verify_image "$image"
done < "$IMAGES_FILE"

# Summary Report
echo -e "${GREEN}=== Verification Summary ===${NC}"
echo -e "Total Images: ${TOTAL_IMAGES}"
echo -e "${GREEN}Verified (Signed): ${VERIFIED_IMAGES}${NC}"
echo -e "${YELLOW}Unsigned: ${UNSIGNED_IMAGES}${NC}"
echo -e "${RED}Failed: ${FAILED_IMAGES}${NC}"

# Policy enforcement
echo -e "\n${BLUE}=== Policy Enforcement ===${NC}"
if [ "$POLICY" == "block" ]; then
    if [ $UNSIGNED_IMAGES -gt 0 ] || [ $FAILED_IMAGES -gt 0 ]; then
        echo -e "${RED}✗ BLOCKED: Found unsigned or unverified images${NC}"
        echo -e "Policy requires all images to be signed and verified"
        exit 1
    else
        echo -e "${GREEN}✓ PASSED: All images are signed and verified${NC}"
    fi
else
    if [ $UNSIGNED_IMAGES -gt 0 ]; then
        echo -e "${YELLOW}⚠ WARNING: Found ${UNSIGNED_IMAGES} unsigned images${NC}"
        echo -e "Consider signing these images for better security"
    fi
    if [ $FAILED_IMAGES -gt 0 ]; then
        echo -e "${RED}⚠ WARNING: ${FAILED_IMAGES} images failed verification${NC}"
    fi
    if [ $VERIFIED_IMAGES -eq $TOTAL_IMAGES ]; then
        echo -e "${GREEN}✓ PASSED: All images are signed and verified${NC}"
    fi
fi

# Recommendations
if [ $UNSIGNED_IMAGES -gt 0 ] || [ $FAILED_IMAGES -gt 0 ]; then
    echo -e "\n${CYAN}=== Recommendations ===${NC}"
    echo -e "1. Sign container images using: cosign sign <image>"
    echo -e "2. Use signed base images from verified registries"
    echo -e "3. Implement admission controllers (e.g., Gatekeeper, OPA)"
    echo -e "4. Set POLICY=block to enforce signature requirements"
fi

exit 0