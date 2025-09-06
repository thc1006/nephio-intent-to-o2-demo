# TMF921 Intent Gateway Makefile
# Provides build, test, and quality targets for the intent-gateway module

.PHONY: help install install-dev test test-intent-gateway lint format clean build check-types coverage

# Default target
help:
	@echo "Available targets:"
	@echo "  install        - Install package dependencies"
	@echo "  install-dev    - Install package with development dependencies"
	@echo "  test           - Run all tests"
	@echo "  test-intent-gateway - Run intent-gateway specific tests"
	@echo "  lint           - Run code linting with ruff"
	@echo "  format         - Format code with black and ruff"
	@echo "  check-types    - Run type checking with mypy"
	@echo "  coverage       - Run tests with coverage report"
	@echo "  clean          - Clean build artifacts"
	@echo "  build          - Build distribution packages"
	@echo "  all            - Run full quality checks (lint, format, test, types)"

# Installation targets
install:
	pip install -r requirements.txt

install-dev:
	pip install -e ".[dev]"

# Test targets
test:
	pytest tests/ -v

test-intent-gateway:
	pytest tests/test_schema.py tests/test_cli.py -v --tb=short

# Code quality targets
lint:
	ruff check intent_gateway/ tests/
	@echo "✓ Linting passed"

format:
	black intent_gateway/ tests/
	ruff check --fix intent_gateway/ tests/
	@echo "✓ Code formatting applied"

check-types:
	mypy intent_gateway/
	@echo "✓ Type checking passed"

# Coverage target
coverage:
	pytest tests/ --cov=intent_gateway --cov-report=html --cov-report=term-missing
	@echo "✓ Coverage report generated"

# Build targets
clean:
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -rf .pytest_cache/
	rm -rf .coverage
	rm -rf htmlcov/
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	@echo "✓ Cleaned build artifacts"

build: clean
	python -m build
	@echo "✓ Distribution packages built"

# Combined quality check
all: lint check-types test
	@echo "✓ All quality checks passed"

# Development workflow
dev-setup: install-dev
	@echo "✓ Development environment ready"

# CI-friendly targets
ci-test: lint check-types coverage
	@echo "✓ CI tests completed"