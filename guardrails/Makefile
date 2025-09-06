.PHONY: help install install-all test test-all clean demo apply-policies uninstall lint

# Default target
help: ## Show this help message
	@echo "Guardrails Security Components"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Installation targets
install-cert-manager: ## Install cert-manager
	@echo "Installing cert-manager..."
	@cd cert-manager && ./install.sh

install-sigstore: ## Install Sigstore policy-controller  
	@echo "Installing Sigstore policy-controller..."
	@cd sigstore && ./install.sh

install-kyverno: ## Install Kyverno
	@echo "Installing Kyverno..."
	@cd kyverno && ./install.sh

install-all: install-cert-manager install-sigstore install-kyverno ## Install all security components
	@echo "All security components installed successfully!"

install: install-all ## Alias for install-all

# Policy management
apply-policies: ## Apply all security policies
	@echo "Applying Sigstore ClusterImagePolicy..."
	@kubectl apply -f sigstore/policies/cluster-image-policy.yaml
	@echo "Applying Kyverno image verification policy..."
	@kubectl apply -f kyverno/policies/verify-images.yaml
	@echo "Applying cert-manager ClusterIssuer..."
	@kubectl apply -f cert-manager/manifests/cluster-issuer.yaml
	@echo "All policies applied successfully!"

# Testing targets
test-sigstore: ## Test Sigstore components
	@echo "Testing Sigstore..."
	@cd sigstore && make test

test-kyverno: ## Test Kyverno components
	@echo "Testing Kyverno..."
	@cd kyverno && make test

test-cert-manager: ## Test cert-manager components
	@echo "Testing cert-manager..."
	@cd cert-manager && make test

test-all: ## Run comprehensive test suite
	@echo "Running comprehensive test suite..."
	@./test-all.sh

test: test-all ## Alias for test-all

# Demo and validation
demo: ## Run signed/unsigned image demonstration
	@echo "Running security demonstration..."
	@./demo-signed-unsigned.sh

validate: test-all ## Validate all components (alias for test-all)

# Linting and formatting
lint: ## Lint YAML files and policies
	@echo "Linting YAML files..."
	@if command -v yamllint >/dev/null 2>&1; then \
		find . -name "*.yaml" -o -name "*.yml" | xargs yamllint -d relaxed; \
	else \
		echo "yamllint not found, skipping YAML linting"; \
	fi
	@echo "Validating Kubernetes resources..."
	@for file in $$(find . -name "*.yaml" -o -name "*.yml"); do \
		echo "Validating $$file..."; \
		kubectl apply -f $$file --dry-run=client > /dev/null || echo "❌ $$file failed validation"; \
	done
	@echo "Linting complete!"

# Cleanup targets
clean-test-resources: ## Clean up test resources
	@echo "Cleaning up test resources..."
	@kubectl delete namespace production-test dev-test cert-test guardrails-test 2>/dev/null || true
	@echo "Test resources cleaned up!"

uninstall-policies: ## Remove all security policies
	@echo "Removing security policies..."
	@kubectl delete clusterimageepolicy --all 2>/dev/null || true
	@kubectl delete clusterpolicy verify-images 2>/dev/null || true
	@kubectl delete clusterissuer selfsigned-cluster-issuer ca-cluster-issuer 2>/dev/null || true
	@echo "Policies removed!"

uninstall-components: ## Uninstall all security components (DESTRUCTIVE)
	@echo "⚠️  This will remove all security components. Are you sure? [y/N]" && read ans && [ $${ans:-N} = y ]
	@echo "Uninstalling Kyverno..."
	@kubectl delete -f https://github.com/kyverno/kyverno/releases/download/v1.12.0/install.yaml 2>/dev/null || true
	@echo "Uninstalling Sigstore policy-controller..."
	@helm uninstall policy-controller -n cosign-system 2>/dev/null || true
	@kubectl delete namespace cosign-system 2>/dev/null || true
	@echo "Uninstalling cert-manager..."
	@kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml 2>/dev/null || true
	@echo "All components uninstalled!"

clean: clean-test-resources ## Clean up test resources (safe)

uninstall: uninstall-policies uninstall-components ## Complete uninstall (DESTRUCTIVE)

# Status and monitoring
status: ## Show status of all security components
	@echo "=== Security Components Status ==="
	@echo ""
	@echo "Cert-manager:"
	@kubectl get pods -n cert-manager 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Sigstore Policy Controller:"
	@kubectl get pods -n cosign-system 2>/dev/null || echo "  Not installed" 
	@echo ""
	@echo "Kyverno:"
	@kubectl get pods -n kyverno 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Policies:"
	@kubectl get clusterimageepolicy 2>/dev/null || echo "  No Sigstore policies"
	@kubectl get clusterpolicy 2>/dev/null || echo "  No Kyverno policies"
	@kubectl get clusterissuer 2>/dev/null || echo "  No ClusterIssuers"

logs: ## Show logs from security components
	@echo "=== Policy Controller Logs ==="
	@kubectl logs -n cosign-system deployment/policy-controller-webhook --tail=20 2>/dev/null || echo "Policy controller not running"
	@echo ""
	@echo "=== Kyverno Admission Controller Logs ==="
	@kubectl logs -n kyverno deployment/kyverno-admission-controller --tail=20 2>/dev/null || echo "Kyverno not running"
	@echo ""
	@echo "=== Cert-manager Logs ==="
	@kubectl logs -n cert-manager deployment/cert-manager --tail=20 2>/dev/null || echo "cert-manager not running"

# Development helpers
dev-setup: ## Setup development environment
	@echo "Setting up development environment..."
	@kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
	@kubectl label namespace dev environment=dev --overwrite
	@kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
	@kubectl label namespace staging environment=staging --overwrite
	@echo "Development namespaces created!"

quick-test: ## Quick validation without full test suite
	@echo "Running quick validation..."
	@kubectl cluster-info > /dev/null && echo "✓ Cluster reachable"
	@kubectl get nodes > /dev/null && echo "✓ Nodes available"  
	@kubectl auth can-i create pods && echo "✓ Permissions OK"
	@echo "Quick test complete!"

# Documentation
docs: ## Generate documentation
	@echo "Security documentation available at: docs/SECURITY.md"
	@echo ""
	@echo "Component READMEs:"
	@find . -name "README.md" -not -path "./docs/*" | sort

# Aliases for convenience
i: install ## Short alias for install
t: test ## Short alias for test
d: demo ## Short alias for demo
s: status ## Short alias for status
c: clean ## Short alias for clean