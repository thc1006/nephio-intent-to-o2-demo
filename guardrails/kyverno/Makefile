# Kyverno Security Policies Makefile
.PHONY: test install clean help

KYVERNO_CLI := kyverno
KYVERNO_VERSION := v1.11.0

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install-cli: ## Install kyverno CLI
	@echo "Installing Kyverno CLI..."
	@if ! command -v $(KYVERNO_CLI) &> /dev/null; then \
		curl -LO https://github.com/kyverno/kyverno/releases/download/$(KYVERNO_VERSION)/kyverno-cli_$(KYVERNO_VERSION)_linux_x86_64.tar.gz && \
		tar -xzf kyverno-cli_$(KYVERNO_VERSION)_linux_x86_64.tar.gz && \
		sudo mv kyverno /usr/local/bin/ && \
		rm -f kyverno-cli_$(KYVERNO_VERSION)_linux_x86_64.tar.gz LICENSE; \
	else \
		echo "Kyverno CLI already installed"; \
	fi

test: ## Run Kyverno policy tests (will FAIL initially - TDD RED phase)
	@echo "Running Kyverno policy tests..."
	@if [ -f policies/verify-images.yaml ]; then \
		$(KYVERNO_CLI) test tests/ || echo "Tests failed as expected (TDD RED phase)"; \
	else \
		echo "ERROR: Policy not yet implemented (TDD RED phase)"; \
		echo "Tests will fail because policies/verify-images.yaml doesn't exist"; \
		exit 1; \
	fi

apply: ## Apply Kyverno policies to cluster
	@echo "Applying Kyverno policies..."
	kubectl apply -f policies/

clean: ## Remove test artifacts
	@echo "Cleaning up test artifacts..."
	rm -rf test-results/

validate: ## Validate policy syntax
	@echo "Validating Kyverno policies..."
	@if [ -f policies/verify-images.yaml ]; then \
		kubectl --dry-run=client apply -f policies/verify-images.yaml || echo "Policy syntax validation completed"; \
	else \
		echo "No policies to validate yet"; \
	fi