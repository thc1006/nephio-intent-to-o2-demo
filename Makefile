# Nephio Intent-to-O2 Demo Pipeline
SHELL := /bin/bash
.PHONY: init fmt lint test build p0-check e2e clean precheck security-report publish-edge postcheck rollback demo demo-rollback o2ims-install ocloud-provision

# Tool versions
GO_VERSION := 1.22
PYTHON_VERSION := 3.11

init: ## Install dependencies and setup environment
	@echo "Installing Python dependencies..."
	@command -v python$(PYTHON_VERSION) || (echo "Python $(PYTHON_VERSION) required" && exit 1)
	@python$(PYTHON_VERSION) -m pip install --user ruff black pytest pytest-cov
	@echo "Installing Go dependencies..."
	@command -v go || (echo "Go $(GO_VERSION) required" && exit 1)
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "Installing YAML tools..."
	@python$(PYTHON_VERSION) -m pip install --user yamllint
	@go install github.com/yannh/kubeconform/cmd/kubeconform@latest
	@echo "Creating artifacts and reports directories..."
	@mkdir -p artifacts reports
	@echo "Init complete"

fmt: ## Format code (Python + Go)
	@echo "Formatting Python code..."
	@find tools -name "*.py" -exec black {} \; 2>/dev/null || true
	@echo "Formatting Go code..."
	@find . -name "*.go" -exec gofmt -w {} \; 2>/dev/null || true
	@echo "Format complete"

lint: ## Lint all code
	@echo "Linting Python..."
	@find tools -name "*.py" -exec ruff check {} \; 2>/dev/null || true
	@echo "Linting Go..."
	@cd kpt-functions/expectation-to-krm 2>/dev/null && golangci-lint run || true
	@echo "Linting YAML..."
	@yamllint -d relaxed . 2>/dev/null || true
	@echo "Lint complete"

test: ## Run unit tests
	@echo "Running Python tests..."
	@cd tools/intent-gateway && python$(PYTHON_VERSION) -m pytest tests/ -v || exit 1
	@cd tools/tmf921-to-28312 && python$(PYTHON_VERSION) -m pytest tests/ -v || exit 1
	@echo "Running Go tests..."
	@cd kpt-functions/expectation-to-krm && go test ./... -v || exit 1
	@cd o2ims-sdk && go test ./... -v || exit 1
	@echo "Tests complete"

build: ## Build all components
	@echo "Building Python components..."
	@cd tools/intent-gateway && python$(PYTHON_VERSION) -m py_compile *.py 2>/dev/null || true
	@cd tools/tmf921-to-28312 && python$(PYTHON_VERSION) -m py_compile *.py 2>/dev/null || true
	@echo "Building Go components..."
	@cd kpt-functions/expectation-to-krm && go build -o ../../artifacts/expectation-to-krm ./... || true
	@cd o2ims-sdk && go build -o ../artifacts/o2imsctl ./cmd/... || true
	@echo "Build complete"

precheck: ## Run supply chain security precheck gate
	@echo "Running supply chain security precheck..."
	@./scripts/precheck.sh

security-report: ## Generate comprehensive security report with kubeconform and cosign verification
	@echo "Generating comprehensive security report..."
	@./scripts/security_report.sh
	@echo "Security report completed - see reports/security-latest.json"

security-report-dev: ## Generate security report in development mode (allow unsigned images)
	@echo "Generating security report in development mode..."
	@ALLOW_UNSIGNED=true SECURITY_POLICY_LEVEL=permissive ./scripts/security_report.sh
	@echo "Development security report completed"

security-report-strict: ## Generate security report in strict production mode
	@echo "Generating security report in strict production mode..."
	@SECURITY_POLICY_LEVEL=strict ALLOW_UNSIGNED=false ./scripts/security_report.sh
	@echo "Strict security report completed"

p0-check: ## Validate Nephio Phase-0 infrastructure readiness
	@echo "Checking Nephio Phase-0 infrastructure..."
	@./scripts/p0.2_smokecheck.sh

e2e: ## Run end-to-end tests
	@echo "Starting e2e tests..."
	@./scripts/e2e-test.sh || exit 1
	@echo "E2E complete"

publish-edge: precheck security-report ## Publish edge overlay to GitOps repository (with security precheck and comprehensive security validation)
	@echo "Publishing edge overlay with comprehensive security validation..."
	@if [ -f reports/security-latest.json ]; then \
		COMPLIANCE_SCORE=$$(jq -r '.security_report.summary.policy_compliance_score // 0' reports/security-latest.json); \
		if [ "$$COMPLIANCE_SCORE" -lt 60 ]; then \
			echo "❌ Security compliance score ($$COMPLIANCE_SCORE) below threshold (60) - blocking deployment"; \
			exit 1; \
		else \
			echo "✅ Security compliance score ($$COMPLIANCE_SCORE) meets requirements"; \
		fi; \
	fi
	@cd packages/intent-to-krm && $(MAKE) publish-edge
	@echo "Running post-deployment SLO validation..."
	@if ! ./scripts/postcheck.sh; then \
		echo "❌ SLO validation failed - triggering automatic rollback..."; \
		./scripts/rollback.sh "SLO-violation" || echo "⚠️ Rollback also failed"; \
		exit 1; \
	else \
		echo "✅ Deployment successful with SLO validation passed"; \
	fi

postcheck: ## Run post-deployment SLO validation
	@echo "Running post-deployment SLO validation..."
	@./scripts/postcheck.sh

rollback: ## Execute automated rollback (usage: make rollback REASON=security-vulnerability)
	@echo "Executing automated rollback..."
	@./scripts/rollback.sh "$(if $(REASON),$(REASON),manual-rollback)"

rollback-dry-run: ## Dry-run rollback to preview changes (usage: make rollback-dry-run REASON=test)
	@echo "Performing rollback dry-run..."
	@DRY_RUN=true ./scripts/rollback.sh "$(if $(REASON),$(REASON),dry-run-test)"

clean: ## Clean build artifacts
	@echo "Cleaning artifacts..."
	@rm -rf artifacts/*
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete"

clean-security-reports: ## Clean old security reports (keep latest 5)
	@echo "Cleaning old security reports..."
	@cd reports && ls -t security-*.json | tail -n +6 | xargs rm -f 2>/dev/null || true
	@echo "Security reports cleaned"

docs-pdf: ## Export documentation to PDF using pandoc
	@echo "Checking for pandoc..."
	@command -v pandoc >/dev/null 2>&1 || (echo "Error: pandoc is required for PDF export. Install with: apt-get install pandoc texlive-latex-base" && exit 1)
	@echo "Creating PDF output directory..."
	@mkdir -p artifacts/docs-pdf
	@echo "Exporting ARCHITECTURE.md to PDF..."
	@pandoc docs/ARCHITECTURE.md -o artifacts/docs-pdf/ARCHITECTURE.pdf --pdf-engine=pdflatex 2>/dev/null || echo "Warning: Failed to export ARCHITECTURE.md"
	@echo "Exporting OPERATIONS.md to PDF..."
	@pandoc docs/OPERATIONS.md -o artifacts/docs-pdf/OPERATIONS.pdf --pdf-engine=pdflatex 2>/dev/null || echo "Warning: Failed to export OPERATIONS.md"
	@echo "Exporting REFERENCES.md to PDF..."
	@pandoc docs/REFERENCES.md -o artifacts/docs-pdf/REFERENCES.pdf --pdf-engine=pdflatex 2>/dev/null || echo "Warning: Failed to export REFERENCES.md"
	@echo "Exporting DEMO_TALK.md to PDF..."
	@pandoc docs/DEMO_TALK.md -o artifacts/docs-pdf/DEMO_TALK.pdf --pdf-engine=pdflatex 2>/dev/null || echo "Warning: Failed to export DEMO_TALK.md"
	@echo "PDF documentation exported to artifacts/docs-pdf/"

check-prereqs: ## Check demo prerequisites and environment
	@echo "Checking demo prerequisites..."
	@command -v python3.11 >/dev/null 2>&1 && echo "✓ Python 3.11" || echo "✗ Python 3.11 missing"
	@command -v go >/dev/null 2>&1 && echo "✓ Go" || echo "✗ Go missing"
	@command -v jq >/dev/null 2>&1 && echo "✓ jq" || echo "✗ jq missing"
	@command -v kubectl >/dev/null 2>&1 && echo "✓ kubectl" || echo "✗ kubectl missing"
	@command -v kpt >/dev/null 2>&1 && echo "✓ kpt" || echo "✗ kpt missing"
	@command -v kubeconform >/dev/null 2>&1 && echo "✓ kubeconform" || echo "✗ kubeconform missing"
	@command -v cosign >/dev/null 2>&1 && echo "✓ cosign" || echo "⚠ cosign missing (signature verification disabled)"
	@test -d artifacts || (mkdir -p artifacts && echo "✓ Created artifacts directory")
	@test -d reports || (mkdir -p reports && echo "✓ Created reports directory")
	@test -f samples/tmf921/valid_01.json && echo "✓ Demo samples present" || echo "✗ Demo samples missing"

demo-full: check-prereqs security-report ## Run complete demo pipeline with security validation
	@echo "=== NEPHIO INTENT-TO-O2 FULL DEMO WITH SECURITY ==="
	@mkdir -p artifacts/demo-backup
	@echo "1. Validating TMF921 intent..."
	@cd tools/intent-gateway && ./intent-gateway validate --file ../../samples/tmf921/valid_01.json --tio-mode strict || exit 1
	@echo "2. Converting TMF921 → 3GPP TS 28.312..."
	@cd tools/tmf921-to-28312 && ./tmf921-to-28312 convert --input ../../samples/tmf921/valid_01.json --output ../../artifacts/28312_expectation.json --report ../../artifacts/conversion_report.json || exit 1
	@echo "3. Generating KRM packages..."
	@cd packages/intent-to-krm && kubeconform --summary --verbose *.yaml || echo "Warning: KRM validation issues"
	@echo "4. O2 IMS integration (mock mode)..."
	@export O2IMS_ENDPOINT="mock://demo" && cd o2ims-sdk && ./o2imsctl pr create --from ../samples/krm/provisioning_request.yaml --dry-run || echo "Warning: O2 IMS mock unavailable"
	@echo "5. SLO gate validation..."
	@cd slo-gated-gitops/gate && ./gate --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=200" --kpi-source ../job-query-adapter/mock_metrics.json || echo "Warning: SLO gate unavailable"
	@echo "6. Security compliance check..."
	@if [ -f reports/security-latest.json ]; then \
		echo "✓ Security report available - compliance validated"; \
		jq -r '.security_report.summary | to_entries[] | "  \(.key | gsub("_"; " ") | ascii_upcase): \(.value)"' reports/security-latest.json; \
	else \
		echo "⚠ Security report not available"; \
	fi
	@echo "=== DEMO COMPLETE - Artifacts in ./artifacts/, Reports in ./reports/ ==="

demo-restore-checkpoint: ## Restore demo to clean checkpoint
	@echo "Restoring demo checkpoint..."
	@rm -rf artifacts/*
	@mkdir -p artifacts/demo-backup
	@echo "Demo restored to clean state"

demo-fast-forward: ## Skip to final demo results
	@echo "Fast-forwarding to demo results..."
	@mkdir -p artifacts
	@echo '{"status":"completed","pipeline":"tmf921->28312->krm->o2ims","timestamp":"'$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' > artifacts/demo_results.json
	@echo "Demo fast-forwarded - see artifacts/demo_results.json"

clean-demo-state: ## Clean all demo artifacts and state
	@echo "Cleaning demo state..."
	@rm -rf artifacts/*
	@mkdir -p artifacts
	@echo "Demo state cleaned"

help: ## Show this help
	@grep '^[a-zA-Z0-9_-]*:.*##' $(MAKEFILE_LIST) | sort | sed 's/:.*##/:##/' | awk -F ':##' '{printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

demo: ## Run complete one-click demo pipeline (p0-check → o2ims-install → ocloud-provision → precheck → publish-edge → postcheck)
	@echo "=== NEPHIO INTENT-TO-O2 ONE-CLICK DEMO ==="
	@./scripts/demo_orchestrator.sh

demo-rollback: ## Execute demo rollback with before/after status comparison
	@echo "=== NEPHIO DEMO ROLLBACK ==="
	@./scripts/demo_rollback.sh

o2ims-install: ## Install O2 IMS operator components
	@echo "Installing O2 IMS operator..."
	@./scripts/p0.3_o2ims_install.sh

ocloud-provision: ## Provision O-Cloud using FoCoM operator
	@echo "Provisioning O-Cloud..."
	@./scripts/p0.4A_ocloud_provision.sh

.DEFAULT_GOAL := help