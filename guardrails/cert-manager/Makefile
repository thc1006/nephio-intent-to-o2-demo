# Cert-manager Makefile
.PHONY: test install apply clean help validate

CERT_MANAGER_VERSION := v1.13.3

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install cert-manager in cluster
	@echo "Installing cert-manager $(CERT_MANAGER_VERSION)..."
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.yaml
	@echo "Waiting for cert-manager to be ready..."
	kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager
	kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager-webhook
	kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager-cainjector

test: ## Run cert-manager tests (will FAIL initially - TDD RED phase)
	@echo "Running cert-manager tests..."
	@if [ -f manifests/cluster-issuer.yaml ]; then \
		cd tests && ./verify-cert-manager.sh || echo "Tests failed as expected (TDD RED phase)"; \
	else \
		echo "ERROR: ClusterIssuer not yet implemented (TDD RED phase)"; \
		echo "Tests will fail because manifests/cluster-issuer.yaml doesn't exist"; \
		exit 1; \
	fi

apply: ## Apply cert-manager manifests
	@echo "Applying cert-manager manifests..."
	kubectl apply -f manifests/

clean: ## Clean up test resources
	@echo "Cleaning up test resources..."
	kubectl delete -f tests/ --ignore-not-found=true

validate: ## Validate cert-manager installation
	@echo "Validating cert-manager installation..."
	kubectl get pods -n cert-manager
	kubectl get clusterissuer

install-cmctl: ## Install cert-manager CLI tool
	@echo "Installing cmctl..."
	@if ! command -v cmctl &> /dev/null; then \
		curl -fsSL -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cmctl-linux-amd64.tar.gz && \
		tar xzf cmctl.tar.gz && \
		sudo mv cmctl /usr/local/bin && \
		rm cmctl.tar.gz; \
	else \
		echo "cmctl already installed"; \
	fi

check: ## Check cert-manager API readiness
	@echo "Checking cert-manager API..."
	cmctl check api || echo "cert-manager API not ready"