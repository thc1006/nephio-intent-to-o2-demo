# Nephio Intent-to-O2 Demo Pipeline
SHELL := /bin/bash
.PHONY: init fmt lint test build e2e clean

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
	@echo "Creating artifacts directory..."
	@mkdir -p artifacts
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

e2e: ## Run end-to-end tests
	@echo "Starting e2e tests..."
	@./scripts/e2e-test.sh || exit 1
	@echo "E2E complete"

clean: ## Clean build artifacts
	@echo "Cleaning artifacts..."
	@rm -rf artifacts/*
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete"

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
	@echo "PDF documentation exported to artifacts/docs-pdf/"
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help