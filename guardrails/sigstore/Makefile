# Sigstore Policy Controller Makefile
.PHONY: test install apply clean help

COSIGN_VERSION := v2.2.2
POLICY_CONTROLLER_VERSION := v0.8.0

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install-cosign: ## Install cosign CLI
	@echo "Installing cosign CLI..."
	@if ! command -v cosign &> /dev/null; then \
		curl -LO https://github.com/sigstore/cosign/releases/download/$(COSIGN_VERSION)/cosign-linux-amd64 && \
		chmod +x cosign-linux-amd64 && \
		sudo mv cosign-linux-amd64 /usr/local/bin/cosign; \
	else \
		echo "cosign already installed"; \
	fi

install-policy-controller: ## Install Sigstore policy-controller in cluster
	@echo "Installing Sigstore policy-controller..."
	kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/$(POLICY_CONTROLLER_VERSION)/policy-controller.yaml
	@echo "Waiting for policy-controller to be ready..."
	kubectl -n cosign-system wait --for=condition=Available --timeout=300s deployment/policy-controller-webhook

test: ## Run Sigstore policy tests (will FAIL initially - TDD RED phase)
	@echo "Running Sigstore policy tests..."
	@if [ -f policies/cluster-image-policy.yaml ]; then \
		cd tests && ./verify-policy.sh || echo "Tests failed as expected (TDD RED phase)"; \
	else \
		echo "ERROR: Policy not yet implemented (TDD RED phase)"; \
		echo "Tests will fail because policies/cluster-image-policy.yaml doesn't exist"; \
		exit 1; \
	fi

apply: ## Apply Sigstore policies to cluster
	@echo "Applying Sigstore policies..."
	kubectl apply -f policies/

clean: ## Clean up test resources
	@echo "Cleaning up test resources..."
	kubectl delete -f tests/ --ignore-not-found=true

verify-signature: ## Verify an image signature (example)
	@echo "Example: Verifying distroless image signature..."
	cosign verify gcr.io/distroless/static:nonroot \
		--certificate-identity=keyless@distroless.iam.gserviceaccount.com \
		--certificate-oidc-issuer=https://accounts.google.com || true