# Supply Chain Security Makefile
# Provides CI-like local validation and verification

# Configuration
MANIFESTS_PATH ?= .
IMAGES_FILE ?= images.txt
POLICY ?= warn
VERBOSE ?= false
STRICT ?= true
KUBERNETES_VERSION ?= 1.27.0

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.PHONY: all
all: conform verify

# Help target
.PHONY: help
help:
	@echo "$(GREEN)Supply Chain Security Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@echo "  make conform       - Validate Kubernetes manifests with kubeconform"
	@echo "  make verify        - Verify container image signatures with cosign"
	@echo "  make extract       - Extract images from YAML files"
	@echo "  make all          - Run both conform and verify"
	@echo "  make install-tools - Install required tools (kubeconform, cosign)"
	@echo "  make clean        - Clean temporary files"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  MANIFESTS_PATH    - Path to manifests (default: .)"
	@echo "  IMAGES_FILE       - Images list file (default: images.txt)"
	@echo "  POLICY           - Verification policy: warn|block (default: warn)"
	@echo "  VERBOSE          - Verbose output: true|false (default: false)"
	@echo "  STRICT           - Strict validation: true|false (default: true)"
	@echo "  KUBERNETES_VERSION - Target K8s version (default: 1.27.0)"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make conform MANIFESTS_PATH=/path/to/manifests"
	@echo "  make verify POLICY=block"
	@echo "  make all VERBOSE=true"

# Validate Kubernetes manifests
.PHONY: conform
conform:
	@echo "$(GREEN)=== Running Kubeconform Validation ===$(NC)"
	@chmod +x ~/dev/conform.sh
	@VERBOSE=$(VERBOSE) STRICT=$(STRICT) KUBERNETES_VERSION=$(KUBERNETES_VERSION) \
		~/dev/conform.sh $(MANIFESTS_PATH)

# Verify container image signatures
.PHONY: verify
verify:
	@echo "$(GREEN)=== Running Image Signature Verification ===$(NC)"
	@chmod +x ~/dev/verify-images.sh
	@POLICY=$(POLICY) VERBOSE=$(VERBOSE) \
		~/dev/verify-images.sh $(IMAGES_FILE)

# Extract images from YAML manifests
.PHONY: extract
extract:
	@echo "$(GREEN)=== Extracting Images from Manifests ===$(NC)"
	@echo "# Container images extracted from $(MANIFESTS_PATH)" > $(IMAGES_FILE)
	@echo "# Generated: $$(date)" >> $(IMAGES_FILE)
	@echo "" >> $(IMAGES_FILE)
	@find $(MANIFESTS_PATH) -type f \( -name "*.yaml" -o -name "*.yml" \) -exec grep -h "image:" {} \; | \
		sed 's/.*image: *//; s/"//g; s/'\''//g' | \
		grep -v "^#" | \
		sort -u >> $(IMAGES_FILE)
	@echo "$(GREEN)✓ Extracted $$(grep -v '^#' $(IMAGES_FILE) | wc -l) unique images to $(IMAGES_FILE)$(NC)"

# Install required tools
.PHONY: install-tools
install-tools:
	@echo "$(GREEN)=== Installing Required Tools ===$(NC)"
	@echo "$(YELLOW)Installing kubeconform...$(NC)"
	@if ! command -v kubeconform &> /dev/null; then \
		curl -L -o /tmp/kubeconform.tar.gz \
			"https://github.com/yannh/kubeconform/releases/download/v0.6.3/kubeconform-linux-amd64.tar.gz" && \
		tar xzf /tmp/kubeconform.tar.gz -C /tmp && \
		sudo mv /tmp/kubeconform /usr/local/bin/ && \
		rm /tmp/kubeconform.tar.gz && \
		echo "$(GREEN)✓ kubeconform installed$(NC)"; \
	else \
		echo "$(BLUE)✓ kubeconform already installed$(NC)"; \
	fi
	@echo "$(YELLOW)Installing cosign...$(NC)"
	@if ! command -v cosign &> /dev/null; then \
		curl -L -o /tmp/cosign \
			"https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64" && \
		chmod +x /tmp/cosign && \
		sudo mv /tmp/cosign /usr/local/bin/ && \
		echo "$(GREEN)✓ cosign installed$(NC)"; \
	else \
		echo "$(BLUE)✓ cosign already installed$(NC)"; \
	fi
	@echo "$(GREEN)✓ All tools installed$(NC)"

# Clean temporary files
.PHONY: clean
clean:
	@echo "$(YELLOW)Cleaning temporary files...$(NC)"
	@rm -f /tmp/kubeconform_output.txt
	@rm -f /tmp/cosign_verify_*.txt
	@rm -f /tmp/extracted_images.txt
	@echo "$(GREEN)✓ Cleaned$(NC)"

# Run security checks on GitOps repository
.PHONY: check-gitops
check-gitops:
	@echo "$(GREEN)=== Checking GitOps Repository ===$(NC)"
	@if [ -d "/repo/current" ]; then \
		echo "$(YELLOW)Checking /repo/current/apps/intent...$(NC)"; \
		$(MAKE) conform MANIFESTS_PATH=/repo/current/apps/intent; \
		echo ""; \
		echo "$(YELLOW)Extracting images from repository...$(NC)"; \
		$(MAKE) extract MANIFESTS_PATH=/repo/current; \
		echo ""; \
		$(MAKE) verify; \
	else \
		kubectl exec -n config-management-system deploy/root-reconciler -c git-sync -- \
			ls -la /repo/current/apps/intent/ 2>/dev/null && \
		echo "$(YELLOW)Note: Run from within the cluster to check synced content$(NC)"; \
	fi

# Test the current cluster's workloads
.PHONY: audit-cluster
audit-cluster:
	@echo "$(GREEN)=== Auditing Current Cluster ===$(NC)"
	@echo "$(YELLOW)Extracting images from running workloads...$(NC)"
	@kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" | \
		tr ' ' '\n' | sort -u > cluster-images.txt
	@echo "$(GREEN)✓ Found $$(wc -l < cluster-images.txt) unique images in cluster$(NC)"
	@echo ""
	@POLICY=$(POLICY) VERBOSE=$(VERBOSE) ~/dev/verify-images.sh cluster-images.txt

# CI/CD simulation
.PHONY: ci
ci:
	@echo "$(GREEN)=== Running CI Pipeline Simulation ===$(NC)"
	@echo "$(BLUE)[Step 1/3] Validating manifests...$(NC)"
	@$(MAKE) conform STRICT=true
	@echo ""
	@echo "$(BLUE)[Step 2/3] Extracting images...$(NC)"
	@$(MAKE) extract
	@echo ""
	@echo "$(BLUE)[Step 3/3] Verifying signatures (blocking mode)...$(NC)"
	@$(MAKE) verify POLICY=block
	@echo ""
	@echo "$(GREEN)✅ CI Pipeline PASSED$(NC)"

# Quick security check
.PHONY: quick-check
quick-check:
	@echo "$(GREEN)=== Quick Security Check ===$(NC)"
	@$(MAKE) conform VERBOSE=false 2>/dev/null && echo "$(GREEN)✓ Manifests valid$(NC)" || echo "$(RED)✗ Manifest issues found$(NC)"
	@$(MAKE) verify POLICY=warn VERBOSE=false 2>/dev/null && echo "$(GREEN)✓ Images checked$(NC)" || echo "$(YELLOW)⚠ Image issues found$(NC)"

.PHONY: test
test:
	@echo "$(GREEN)=== Testing Supply Chain Tools ===$(NC)"
	@echo "$(YELLOW)Creating test files...$(NC)"
	@mkdir -p test-manifests
	@echo "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: test\ndata:\n  key: value" > test-manifests/valid.yaml
	@echo "invalid yaml content" > test-manifests/invalid.yaml
	@echo "busybox:latest\nregistry.k8s.io/pause:3.9" > test-images.txt
	@echo ""
	@echo "$(YELLOW)Testing conform.sh...$(NC)"
	@-$(MAKE) conform MANIFESTS_PATH=test-manifests
	@echo ""
	@echo "$(YELLOW)Testing verify-images.sh...$(NC)"
	@$(MAKE) verify IMAGES_FILE=test-images.txt
	@echo ""
	@echo "$(YELLOW)Cleaning up test files...$(NC)"
	@rm -rf test-manifests test-images.txt
	@echo "$(GREEN)✓ Tests complete$(NC)"