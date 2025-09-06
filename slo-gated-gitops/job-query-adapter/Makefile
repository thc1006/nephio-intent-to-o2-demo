# Job Query Adapter Makefile
# Follows project conventions for Python 3.11 with ruff+black+pytest

.PHONY: help install test lint format run clean dev-setup

# Default target
help:
	@echo "Available targets:"
	@echo "  install     - Install dependencies"
	@echo "  test        - Run tests with coverage"
	@echo "  lint        - Run ruff linting"
	@echo "  format      - Format code with black"
	@echo "  run         - Run the adapter server"
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
	. $(VENV_ACTIVATE) && python -m pytest tests/ -v --cov=adapter --cov-report=term-missing --cov-report=html

# Lint with ruff
lint: install
	. $(VENV_ACTIVATE) && python -m ruff check adapter.py tests/

# Format with black
format: install
	. $(VENV_ACTIVATE) && python -m black adapter.py tests/

# Run the adapter server
run: install
	@echo "Starting job-query-adapter on http://localhost:8080"
	. $(VENV_ACTIVATE) && python adapter.py

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

# Docker targets (future enhancement)
docker-build:
	docker build -t job-query-adapter .

docker-run:
	docker run -p 8080:8080 --env-file=../.env job-query-adapter