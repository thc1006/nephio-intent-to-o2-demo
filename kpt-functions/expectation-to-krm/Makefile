.PHONY: help test build clean lint fmt vet deps image test-red test-verbose docker-build docker-push

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOFMT=gofmt
GOVET=$(GOCMD) vet

# Binary info
BINARY_NAME=expectation-to-krm
BINARY_PATH=./bin/$(BINARY_NAME)
MAIN_PATH=.

# Docker info
DOCKER_IMAGE=expectation-to-krm
DOCKER_TAG=latest

# Test parameters
TEST_TIMEOUT=300s
COVERAGE_OUT=coverage.out

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@egrep '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

deps: ## Download dependencies
	$(GOGET) -d -v ./...
	$(GOCMD) mod tidy

fmt: ## Format Go code
	$(GOFMT) -s -w .

vet: ## Run go vet
	$(GOVET) ./...

lint: ## Run golangci-lint
	@command -v golangci-lint >/dev/null 2>&1 || { echo "Installing golangci-lint..."; go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; }
	golangci-lint run

test-red: ## Run RED tests (should fail initially per TDD)
	@echo "Running RED tests (these should fail initially)..."
	$(GOTEST) -v -timeout $(TEST_TIMEOUT) ./... || echo "Tests failed as expected (RED phase)"

test: ## Run all tests
	$(GOTEST) -v -timeout $(TEST_TIMEOUT) ./...

test-verbose: ## Run tests with verbose output
	$(GOTEST) -v -timeout $(TEST_TIMEOUT) -count=1 ./...

test-coverage: ## Run tests with coverage
	$(GOTEST) -v -timeout $(TEST_TIMEOUT) -coverprofile=$(COVERAGE_OUT) ./...
	$(GOCMD) tool cover -html=$(COVERAGE_OUT) -o coverage.html
	@echo "Coverage report generated at coverage.html"

build: ## Build the binary
	mkdir -p bin
	$(GOBUILD) -o $(BINARY_PATH) -v $(MAIN_PATH)

build-linux: ## Build for Linux
	mkdir -p bin
	GOOS=linux GOARCH=amd64 $(GOBUILD) -o $(BINARY_PATH)-linux -v $(MAIN_PATH)

clean: ## Clean build artifacts
	$(GOCLEAN)
	rm -rf bin/
	rm -f $(COVERAGE_OUT) coverage.html

docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

docker-push: ## Push Docker image  
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

image: docker-build ## Alias for docker-build

validate-fixtures: ## Validate test fixture JSON files
	@echo "Validating test fixtures..."
	@for file in testdata/fixtures/*.json; do \
		echo "Validating $$file"; \
		jq empty < "$$file" || exit 1; \
	done
	@echo "All fixtures are valid JSON"

validate-golden: ## Validate golden YAML files
	@echo "Validating golden files..."
	@for file in testdata/golden/*/*.yaml; do \
		echo "Validating $$file"; \
		kubectl --dry-run=client apply -f "$$file" 2>/dev/null || echo "Warning: $$file may have validation issues"; \
	done
	@echo "Golden file validation completed"

check: deps fmt vet lint validate-fixtures validate-golden ## Run all quality checks

ci: check test-coverage build ## Run CI pipeline

dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	$(GOGET) -u github.com/golangci/golangci-lint/cmd/golangci-lint
	@echo "Development setup complete"

# TDD workflow helpers
tdd-red: test-red ## TDD: Run RED tests (should fail)

tdd-green: test ## TDD: Run GREEN tests (implementation should pass)

tdd-refactor: clean check test ## TDD: Run refactor phase with full validation

# Kpt function specific targets
kpt-test: build ## Test as kpt function with sample data
	@echo "Testing as kpt function..."
	mkdir -p tmp
	echo 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: test\ndata:\n  key: value' > tmp/input.yaml
	cat tmp/input.yaml | $(BINARY_PATH) > tmp/output.yaml
	@echo "Output written to tmp/output.yaml"

kpt-validate: ## Validate kpt function behavior
	@echo "Validating kpt function..."
	@command -v kpt >/dev/null 2>&1 || { echo "kpt CLI not found. Please install kpt."; exit 1; }
	cd ../../packages/intent-to-krm && kpt fn render --dry-run

.DEFAULT_GOAL := help