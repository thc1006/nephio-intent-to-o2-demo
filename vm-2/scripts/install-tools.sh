#!/bin/bash

# Tool Installation Script for VM-2 Environment
# Downloads and installs required tools without storing them in git

set -e

INSTALL_DIR="${HOME}/bin"
mkdir -p "$INSTALL_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Installing required tools...${NC}"

# kubectl v1.31.3
install_kubectl() {
    echo "Installing kubectl..."
    if [ ! -f "$INSTALL_DIR/kubectl" ]; then
        curl -LO "https://dl.k8s.io/release/v1.31.3/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv kubectl "$INSTALL_DIR/"
        echo -e "${GREEN}✓ kubectl installed${NC}"
    else
        echo "kubectl already installed"
    fi
}

# kind v0.20.0
install_kind() {
    echo "Installing kind..."
    if [ ! -f "$INSTALL_DIR/kind" ]; then
        curl -Lo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x kind
        mv kind "$INSTALL_DIR/"
        echo -e "${GREEN}✓ kind installed${NC}"
    else
        echo "kind already installed"
    fi
}

# kpt v1.0.0-beta.54
install_kpt() {
    echo "Installing kpt..."
    if [ ! -f "$INSTALL_DIR/kpt" ]; then
        curl -LO https://github.com/kptdev/kpt/releases/download/v1.0.0-beta.54/kpt_linux_amd64
        chmod +x kpt_linux_amd64
        mv kpt_linux_amd64 "$INSTALL_DIR/kpt"
        echo -e "${GREEN}✓ kpt installed${NC}"
    else
        echo "kpt already installed"
    fi
}

# Go 1.23.4
install_go() {
    echo "Installing Go..."
    if [ ! -d "${HOME}/go" ]; then
        curl -LO https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
        tar -C "${HOME}" -xzf go1.23.4.linux-amd64.tar.gz
        rm go1.23.4.linux-amd64.tar.gz
        echo -e "${GREEN}✓ Go installed${NC}"
        echo "Add to PATH: export PATH=\$HOME/go/bin:\$PATH"
    else
        echo "Go already installed"
    fi
}

# hey (load testing tool)
install_hey() {
    echo "Installing hey..."
    if [ ! -f "$INSTALL_DIR/hey" ]; then
        go install github.com/rakyll/hey@latest 2>/dev/null || {
            echo "Installing hey from binary..."
            curl -LO https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
            chmod +x hey_linux_amd64
            mv hey_linux_amd64 "$INSTALL_DIR/hey"
        }
        echo -e "${GREEN}✓ hey installed${NC}"
    else
        echo "hey already installed"
    fi
}

# cosign v2.4.1
install_cosign() {
    echo "Installing cosign..."
    if [ ! -f "$INSTALL_DIR/cosign" ]; then
        curl -LO https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64
        chmod +x cosign-linux-amd64
        mv cosign-linux-amd64 "$INSTALL_DIR/cosign"
        echo -e "${GREEN}✓ cosign installed${NC}"
    else
        echo "cosign already installed"
    fi
}

# Main execution
main() {
    echo "Installing tools to: $INSTALL_DIR"

    install_kubectl
    install_kind
    install_kpt
    install_go
    install_hey
    install_cosign

    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo "Add to your PATH: export PATH=$INSTALL_DIR:\$PATH"
}

# Parse arguments
case "${1:-all}" in
    kubectl) install_kubectl ;;
    kind) install_kind ;;
    kpt) install_kpt ;;
    go) install_go ;;
    hey) install_hey ;;
    cosign) install_cosign ;;
    all) main ;;
    *)
        echo "Usage: $0 [kubectl|kind|kpt|go|hey|cosign|all]"
        echo "  Default: all"
        exit 1
        ;;
esac