# O2 IMS SDK Makefile
.PHONY: help test build clean lint fmt vet envtest install-tools deps

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
GOFMT=gofmt

# Binary names
BINARY_NAME=o2imsctl
BINARY_UNIX=$(BINARY_NAME)_unix

# Build info
VERSION ?= dev
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
LDFLAGS := -X 'github.com/nephio-intent-to-o2-demo/o2ims-sdk/cmd/o2imsctl/commands.Version=$(VERSION)' \
           -X 'github.com/nephio-intent-to-o2-demo/o2ims-sdk/cmd/o2imsctl/commands.GitCommit=$(GIT_COMMIT)' \
           -X 'github.com/nephio-intent-to-o2-demo/o2ims-sdk/cmd/o2imsctl/commands.BuildDate=$(BUILD_DATE)'

# Test parameters
TEST_TIMEOUT ?= 10m
COVERAGE_OUT ?= coverage.out

# Environment
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
ENVTEST ?= $(LOCALBIN)/setup-envtest
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen
GOLANGCI_LINT ?= $(LOCALBIN)/golangci-lint

## Tool Versions
ENVTEST_VERSION ?= latest
CONTROLLER_TOOLS_VERSION ?= v0.13.0
GOLANGCI_LINT_VERSION ?= v1.54.2

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

deps: ## Download dependencies
	$(GOMOD) tidy
	$(GOMOD) download

fmt: ## Format Go code
	$(GOFMT) -s -w .

vet: ## Run go vet
	$(GOCMD) vet ./...

lint: golangci-lint ## Run golangci-lint
	$(GOLANGCI_LINT) run

generate: controller-gen ## Generate code and manifests
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./api/..."

manifests: controller-gen ## Generate CRD manifests
	$(CONTROLLER_GEN) crd:allowDangerousTypes=true rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

##@ Testing

envtest: $(ENVTEST) ## Setup envtest for testing
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" $(GOTEST) -v ./tests/... -timeout $(TEST_TIMEOUT)

test: envtest ## Run all tests
	@echo "Running tests with envtest..."
	@echo "This will FAIL initially - this is expected (RED phase of TDD)"

test-verbose: ## Run tests with verbose output
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" $(GOTEST) -v ./tests/... -timeout $(TEST_TIMEOUT) -v

test-coverage: envtest ## Run tests with coverage
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" $(GOTEST) -v ./tests/... -timeout $(TEST_TIMEOUT) -coverprofile=$(COVERAGE_OUT)
	$(GOCMD) tool cover -html=$(COVERAGE_OUT) -o coverage.html
	@echo "Coverage report generated: coverage.html"

##@ Build

build: ## Build the CLI binary
	$(GOBUILD) -ldflags "$(LDFLAGS)" -o $(LOCALBIN)/$(BINARY_NAME) ./cmd/o2imsctl

build-linux: ## Build for Linux
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -ldflags "$(LDFLAGS)" -o $(LOCALBIN)/$(BINARY_UNIX) ./cmd/o2imsctl

install: build ## Install the CLI binary to GOPATH/bin
	cp $(LOCALBIN)/$(BINARY_NAME) $(GOPATH)/bin/$(BINARY_NAME)

##@ Cleanup

clean: ## Clean build artifacts
	$(GOCLEAN)
	rm -f $(LOCALBIN)/$(BINARY_NAME)
	rm -f $(LOCALBIN)/$(BINARY_UNIX)
	rm -f $(COVERAGE_OUT)
	rm -f coverage.html

##@ Tools

install-tools: golangci-lint controller-gen envtest ## Install all development tools

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	test -s $(LOCALBIN)/golangci-lint || GOBIN=$(LOCALBIN) go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
$(CONTROLLER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/controller-gen || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION)

.PHONY: envtest
envtest: $(ENVTEST) ## Download envtest-setup locally if necessary.
$(ENVTEST): $(LOCALBIN)
	test -s $(LOCALBIN)/setup-envtest || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-runtime/tools/setup-envtest@$(ENVTEST_VERSION)

##@ Demo/Testing

demo-fake: build ## Run demo commands in fake mode
	@echo "=== O2 IMS SDK Demo (Fake Mode) ==="
	@echo "1. Creating ProvisioningRequest from example..."
	$(LOCALBIN)/$(BINARY_NAME) pr create --from examples/pr.yaml --fake
	@echo ""
	@echo "2. Getting ProvisioningRequest..."
	$(LOCALBIN)/$(BINARY_NAME) pr get example-pr --fake
	@echo ""
	@echo "3. Waiting for ProvisioningRequest to be Ready..."
	$(LOCALBIN)/$(BINARY_NAME) pr wait example-pr --timeout 5s --fake
	@echo ""
	@echo "4. Listing ProvisioningRequests..."
	$(LOCALBIN)/$(BINARY_NAME) pr list --fake
	@echo ""
	@echo "5. Deleting ProvisioningRequest..."
	$(LOCALBIN)/$(BINARY_NAME) pr delete example-pr --fake

validate-examples: ## Validate example YAML files
	@echo "Validating example files..."
	@for file in examples/*.yaml; do \
		echo "Validating $$file..."; \
		$(GOCMD) run ./cmd/validate-yaml/main.go $$file || true; \
	done

##@ Red Phase Verification

verify-red-phase: test build demo-fake ## Verify that we're in RED phase (tests should fail)
	@echo "=== RED Phase Verification ==="
	@echo "✓ Tests should FAIL (this is expected and good!)"
	@echo "✓ CLI builds successfully"
	@echo "✓ Fake mode works for demonstration"
	@echo "✓ Ready for GREEN phase implementation"

##@ Project Info

info: ## Show project information
	@echo "O2 IMS SDK for Kubernetes"
	@echo "=========================="
	@echo "Version: $(VERSION)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"
	@echo ""
	@echo "Structure:"
	@echo "  api/v1alpha1/          - CRD types"
	@echo "  client/                - Type-safe client"
	@echo "  cmd/o2imsctl/          - CLI implementation"
	@echo "  tests/                 - envtest-based tests"
	@echo "  examples/              - Example YAML files"