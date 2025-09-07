# Makefile for intent-to-krm kpt function

BINARY_NAME := expectation-to-krm
DOCKER_IMAGE := expectation-to-krm:latest
GO_FILES := $(shell find . -name "*.go" -type f)

.DEFAULT_GOAL := help

## test: Run go test with coverage
.PHONY: test
test:
	@echo "Running tests with coverage..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

## test-short: Run tests without coverage
.PHONY: test-short
test-short:
	@echo "Running tests..."
	go test -v ./...

## build: Build the binary
.PHONY: build
build:
	@echo "Building binary..."
	go build -o bin/$(BINARY_NAME) .
	@echo "Binary built: bin/$(BINARY_NAME)"

## render: Execute kpt fn render on test data
.PHONY: render
render: build
	@echo "Rendering test expectations..."
	mkdir -p artifacts
	@for input in testdata/input/*.json; do \
		echo "Processing $$input..."; \
		filename=$$(basename $$input .json); \
		cat $$input | ./bin/$(BINARY_NAME) --standalone > artifacts/$$filename.yaml; \
		echo "Generated artifacts/$$filename.yaml"; \
	done
	@echo "All expectations rendered to artifacts/"

## conform: Validate output with kubeconform
.PHONY: conform
conform: render
	@echo "Validating generated YAML with kubeconform..."
	@if command -v kubeconform >/dev/null 2>&1; then \
		kubeconform -schema-location schemas/ -schema-location default -verbose artifacts/*.yaml; \
		echo "All YAML files are valid"; \
	else \
		echo "Warning: kubeconform not found. Install it with:"; \
		echo "  go install github.com/yannh/kubeconform/cmd/kubeconform@latest"; \
	fi

## golden: Update golden test files
.PHONY: golden
golden: build
	@echo "Updating golden test files..."
	@for input in testdata/input/*.json; do \
		filename=$$(basename $$input .json); \
		echo "Updating testdata/golden/$$filename.yaml..."; \
		cat $$input | ./bin/$(BINARY_NAME) --standalone > testdata/golden/$$filename.yaml; \
	done
	@echo "Golden files updated"

## lint: Run golangci-lint
.PHONY: lint
lint:
	@echo "Running golangci-lint..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "Warning: golangci-lint not found. Install it with:"; \
		echo "  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
	fi

## fmt: Run go fmt
.PHONY: fmt
fmt:
	@echo "Formatting Go code..."
	go fmt ./...
	@echo "Code formatted"

## clean: Remove generated files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -rf bin/ artifacts/ coverage.out coverage.html
	@echo "Cleanup complete"

## deps: Download dependencies
.PHONY: deps
deps:
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy
	@echo "Dependencies updated"

## docker-build: Build Docker image
.PHONY: docker-build
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE) .
	@echo "Docker image built: $(DOCKER_IMAGE)"

## validate: Run full validation pipeline
.PHONY: validate
validate: deps fmt lint test conform
	@echo "Full validation complete"

## integration-test: Run integration tests using kpt
.PHONY: integration-test
integration-test: build
	@echo "Running integration tests..."
	@echo "Note: This requires kpt to be installed"
	@if command -v kpt >/dev/null 2>&1; then \
		echo "Testing kpt function rendering..."; \
		mkdir -p tmp/test-package; \
		cp Kptfile tmp/test-package/; \
		cp testdata/input/ran_performance.json tmp/test-package/expectation.json; \
		echo 'apiVersion: v1' > tmp/test-package/input-cm.yaml; \
		echo 'kind: ConfigMap' >> tmp/test-package/input-cm.yaml; \
		echo 'metadata:' >> tmp/test-package/input-cm.yaml; \
		echo '  name: test-expectation' >> tmp/test-package/input-cm.yaml; \
		echo '  labels:' >> tmp/test-package/input-cm.yaml; \
		echo '    app: expectation-converter' >> tmp/test-package/input-cm.yaml; \
		echo 'data:' >> tmp/test-package/input-cm.yaml; \
		echo '  expectation.json: |' >> tmp/test-package/input-cm.yaml; \
		sed 's/^/    /' tmp/test-package/expectation.json >> tmp/test-package/input-cm.yaml; \
		cd tmp/test-package && kpt fn render .; \
		echo "Integration test completed"; \
		rm -rf tmp/; \
	else \
		echo "Warning: kpt not found. Install it from https://kpt.dev/installation/"; \
	fi

## benchmark: Run benchmarks
.PHONY: benchmark
benchmark:
	@echo "Running benchmarks..."
	go test -bench=. -benchmem ./...

## prepare-edge: Prepare edge overlay with artifacts
.PHONY: prepare-edge
prepare-edge: render
	@echo "Preparing edge1 overlay..."
	mkdir -p dist/edge1
	cp artifacts/*.yaml dist/edge1/
	@echo "Edge overlay prepared with artifacts"

## publish-edge: Publish edge overlay to GitOps repository
.PHONY: publish-edge
publish-edge: prepare-edge
	@echo "Publishing edge1 overlay to GitOps repository..."
	@if [ -z "$(EDGE_REPO_DIR)" ]; then \
		echo "Error: EDGE_REPO_DIR environment variable not set"; \
		echo "Please set it to your edge GitOps repository path"; \
		exit 1; \
	fi
	@if [ ! -d "$(EDGE_REPO_DIR)" ]; then \
		echo "Error: Directory $(EDGE_REPO_DIR) does not exist"; \
		exit 1; \
	fi
	@echo "Creating target directory structure..."
	mkdir -p $(EDGE_REPO_DIR)/apps/intent
	@echo "Copying edge1 overlay..."
	cp -r dist/edge1/* $(EDGE_REPO_DIR)/apps/intent/
	@echo "Generating kustomized YAML for edge deployment..."
	kubectl kustomize dist/edge1 > $(EDGE_REPO_DIR)/apps/intent/rendered.yaml
	@echo "Committing changes to GitOps repository..."
	cd $(EDGE_REPO_DIR) && \
		git add apps/intent/ && \
		git commit -m "feat: update intent-to-krm artifacts for edge1 deployment" \
			-m "Generated from intent expectations via kpt function pipeline" \
			-m "Artifacts: $(shell ls -1 artifacts/ | tr '\n' ', ' | sed 's/,$$//')" \
			-m "" \
			-m "🤖 Generated with Claude Code" \
			-m "Co-Authored-By: Claude <noreply@anthropic.com>" || \
		echo "No changes to commit (artifacts are up to date)"
	@echo "Pushing to remote repository..."
	cd $(EDGE_REPO_DIR) && git push origin main || git push origin master
	@echo "GitOps deployment published successfully"

## help: Show this help message
.PHONY: help
help:
	@echo "Available targets:"
	@grep -E '^## [a-zA-Z_-]+:' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ": "}; {gsub(/^## /, "", $$1); printf "  %-15s %s\n", $$1, $$2}'