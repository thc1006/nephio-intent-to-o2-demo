# TMF921 to 3GPP TS 28.312 Converter Makefile
# Following CLAUDE.md conventions: deterministic CLIs with explicit exit codes

.PHONY: help test test-verbose test-coverage lint format check install clean dev-setup
.DEFAULT_GOAL := help

# Python configuration
PYTHON := python3
PIP := $(PYTHON) -m pip
PROJECT_NAME := tmf921_to_28312
TEST_DIR := tests
SRC_DIR := $(PROJECT_NAME)

help: ## Show this help message
	@echo "TMF921 to 3GPP TS 28.312 Converter"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	$(PIP) install -e .
	$(PIP) install -r requirements-dev.txt
	@echo "Development environment ready!"

install: ## Install package and dependencies
	$(PIP) install -e .

clean: ## Clean up build artifacts and cache files
	@echo "Cleaning up..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name ".coverage" -delete 2>/dev/null || true
	find . -type d -name htmlcov -exec rm -rf {} + 2>/dev/null || true
	rm -rf build/ dist/ artifacts/ 2>/dev/null || true
	@echo "Clean complete!"

test: ## Run tests with pytest
	@echo "Running tests..."
	$(PYTHON) -m pytest $(TEST_DIR) -v --tb=short
	@echo "Tests completed with exit code: $$?"

test-verbose: ## Run tests with verbose output
	@echo "Running tests with verbose output..."
	$(PYTHON) -m pytest $(TEST_DIR) -vvs --tb=long

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	$(PYTHON) -m pytest $(TEST_DIR) \
		--cov=$(SRC_DIR) \
		--cov-report=html:htmlcov \
		--cov-report=term \
		--cov-report=xml:coverage.xml \
		--cov-fail-under=80 \
		-v
	@echo "Coverage report generated in htmlcov/"

test-fast: ## Run tests without coverage (faster)
	@echo "Running fast tests..."
	$(PYTHON) -m pytest $(TEST_DIR) -x --tb=no -q

lint: ## Run linting with ruff
	@echo "Running ruff linter..."
	$(PYTHON) -m ruff check $(SRC_DIR) $(TEST_DIR)
	@echo "Linting completed with exit code: $$?"

lint-fix: ## Run linting with automatic fixes
	@echo "Running ruff linter with fixes..."
	$(PYTHON) -m ruff check $(SRC_DIR) $(TEST_DIR) --fix

format: ## Format code with black and ruff
	@echo "Formatting code..."
	$(PYTHON) -m ruff format $(SRC_DIR) $(TEST_DIR)
	$(PYTHON) -m black $(SRC_DIR) $(TEST_DIR) --line-length=88
	@echo "Code formatting completed!"

format-check: ## Check code formatting without modifying files
	@echo "Checking code formatting..."
	$(PYTHON) -m ruff format $(SRC_DIR) $(TEST_DIR) --check
	$(PYTHON) -m black $(SRC_DIR) $(TEST_DIR) --line-length=88 --check

type-check: ## Run type checking with mypy
	@echo "Running type checking..."
	$(PYTHON) -m mypy $(SRC_DIR) --strict --ignore-missing-imports

check: format-check lint type-check ## Run all code quality checks
	@echo "All quality checks completed!"

# CLI testing targets
cli-test: ## Test CLI commands
	@echo "Testing CLI commands..."
	$(PYTHON) -m $(PROJECT_NAME).cli --help
	@echo "CLI help completed with exit code: $$?"

cli-test-convert: ## Test CLI conversion with sample data
	@echo "Testing CLI conversion..."
	@mkdir -p artifacts/
	$(PYTHON) -m $(PROJECT_NAME).cli convert \
		--input ../../samples/tmf921/valid_01.json \
		--output-dir artifacts/ \
		--format json \
		--validate
	@echo "CLI conversion test completed with exit code: $$?"

# Sample data validation
validate-samples: ## Validate sample TMF921 files
	@echo "Validating TMF921 samples..."
	@for file in ../../samples/tmf921/*.json; do \
		echo "Validating $$file..."; \
		$(PYTHON) -c "import json; json.load(open('$$file'))" && echo "✓ Valid JSON" || (echo "✗ Invalid JSON" && exit 1); \
	done
	@echo "Sample validation completed!"

# Development workflow targets
red: test-fast ## TDD RED phase: run failing tests quickly
	@echo "TDD RED phase completed - tests should be failing!"

green: test ## TDD GREEN phase: implement minimal code to pass tests
	@echo "TDD GREEN phase - implement minimal code to make tests pass!"

refactor: test-coverage lint ## TDD REFACTOR phase: clean up code while maintaining tests
	@echo "TDD REFACTOR phase - clean up code while keeping tests green!"

# CI/CD simulation
ci: clean install check test-coverage ## Simulate CI pipeline
	@echo "CI pipeline simulation completed!"

# Build and package
build: clean ## Build package
	@echo "Building package..."
	$(PYTHON) -m build
	@echo "Package built successfully!"

# Security checks
security-check: ## Run security checks with bandit
	@echo "Running security checks..."
	$(PYTHON) -m bandit -r $(SRC_DIR) -f json -o artifacts/security-report.json || true
	$(PYTHON) -m bandit -r $(SRC_DIR)
	@echo "Security check completed!"

# Documentation targets
docs-serve: ## Serve documentation locally
	@echo "Serving documentation..."
	@echo "Documentation will be available at http://localhost:8000"
	$(PYTHON) -m http.server 8000 --directory docs/

# Artifact management
artifacts: ## Create artifacts directory and generate reports
	@mkdir -p artifacts/
	@echo "Artifacts directory created at: $$(pwd)/artifacts/"

# Quick development cycle
dev: format lint test-fast ## Quick development cycle: format, lint, test
	@echo "Development cycle completed!"

# Version information
version: ## Show version information
	@echo "TMF921 to 28.312 Converter"
	@echo "Python version: $$($(PYTHON) --version)"
	@echo "Project directory: $$(pwd)"
	@echo "Git branch: $$(git branch --show-current 2>/dev/null || echo 'Not a git repository')"
	@echo "Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'Not a git repository')"