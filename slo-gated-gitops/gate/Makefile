# SLO Gate Makefile  
# Follows project conventions for Python 3.11 with ruff+black+pytest

.PHONY: help install test lint format run clean dev-setup

# Default target
help:
	@echo "Available targets:"
	@echo "  install     - Install dependencies"
	@echo "  test        - Run tests with coverage"
	@echo "  lint        - Run ruff linting"
	@echo "  format      - Format code with black"
	@echo "  run         - Run gate CLI (requires --slo and --url args)"
	@echo "  clean       - Clean up generated files"
	@echo "  dev-setup   - Set up development environment"
	@echo "  check       - Run all checks (lint + test)"

# Python and pip executables
PYTHON ?= python3
PIP ?= pip3

# Virtual environment
VENV_DIR = .venv
VENV_ACTIVATE = $(VENV_DIR)/bin/activate

# Create virtual environment
$(VENV_ACTIVATE):
	$(PYTHON) -m venv $(VENV_DIR)
	. $(VENV_ACTIVATE) && $(PIP) install --upgrade pip

# Install dependencies
install: $(VENV_ACTIVATE)
	. $(VENV_ACTIVATE) && $(PIP) install -r requirements.txt

# Development setup
dev-setup: install
	@echo "Development environment ready"
	@echo "Activate with: source $(VENV_ACTIVATE)"

# Run tests with coverage
test: install
	. $(VENV_ACTIVATE) && python -m pytest tests/ -v --cov=gate --cov-report=term-missing --cov-report=html

# Lint with ruff
lint: install
	. $(VENV_ACTIVATE) && python -m ruff check gate.py tests/

# Format with black
format: install
	. $(VENV_ACTIVATE) && python -m black gate.py tests/

# Run the gate CLI (example usage)
run: install
	@echo "Example usage:"
	@echo "  make run ARGS='--slo \"latency_p95_ms<=15\" --url http://localhost:8080/metrics'"
	@if [ -n "$(ARGS)" ]; then \
		. $(VENV_ACTIVATE) && python gate.py $(ARGS); \
	else \
		. $(VENV_ACTIVATE) && python gate.py --help; \
	fi

# Test gate with example SLO (requires adapter running)
test-gate: install
	@echo "Testing gate with sample SLO (requires adapter at localhost:8080)"
	. $(VENV_ACTIVATE) && python gate.py --slo "latency_p95_ms<=15,success_rate>=0.995" --url http://localhost:8080/metrics

# Run all checks
check: lint test
	@echo "All checks passed ✓"

# Clean up
clean:
	rm -rf $(VENV_DIR)
	rm -rf __pycache__/
	rm -rf tests/__pycache__/
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	rm -rf .coverage
	find . -name "*.pyc" -delete
	find . -name "*.pyo" -delete

# Install gate CLI globally (development)
install-cli: install
	. $(VENV_ACTIVATE) && pip install -e .