# Makefile for Nephio Intent to O2 Demo Scripts
# Provides convenient targets for running provisioning scripts

.PHONY: help all bootstrap smokecheck o2ims ocloud clean status logs

# Default target
help:
	@echo "Nephio Intent to O2 Demo - Script Automation"
	@echo "============================================"
	@echo ""
	@echo "Available targets:"
	@echo "  make bootstrap    - Run P0.1 bootstrap script"
	@echo "  make smokecheck   - Run P0.2 smoke check"
	@echo "  make o2ims        - Run P0.3 O2IMS installation"
	@echo "  make ocloud       - Run P0.4A O-Cloud provisioning"
	@echo "  make all          - Run all scripts in sequence"
	@echo ""
	@echo "Utility targets:"
	@echo "  make status       - Check cluster and resource status"
	@echo "  make logs         - Show recent logs from operators"
	@echo "  make clean        - Clean up resources and clusters"
	@echo "  make dry-run      - Run P0.4A in dry-run mode"
	@echo ""
	@echo "Configuration:"
	@echo "  make config       - Display current configuration"
	@echo "  make validate     - Validate prerequisites"
	@echo ""

# Configuration variables
SMO_CLUSTER_NAME ?= focom-smo
SMO_KUBECONFIG ?= /tmp/focom-kubeconfig
EDGE_KUBECONFIG ?= /tmp/kubeconfig-edge.yaml
O2IMS_NAMESPACE ?= o2ims
FOCOM_NAMESPACE ?= focom-system
VM2_IP ?= 172.16.4.45
TIMEOUT ?= 600

# Run all scripts in sequence
all: bootstrap smokecheck o2ims ocloud
	@echo "✅ All provisioning steps completed successfully!"

# P0.1 Bootstrap
bootstrap:
	@echo "🚀 Running P0.1 Bootstrap..."
	@./p0.1_bootstrap.sh

# P0.2 Smoke Check
smokecheck:
	@echo "🔍 Running P0.2 Smoke Check..."
	@./p0.2_smokecheck.sh

# P0.3 O2IMS Installation
o2ims:
	@echo "📦 Running P0.3 O2IMS Installation..."
	@./p0.3_o2ims_install.sh

# P0.4A O-Cloud Provisioning
ocloud:
	@echo "☁️  Running P0.4A O-Cloud Provisioning..."
	@./p0.4A_ocloud_provision.sh

# Dry run mode for testing
dry-run:
	@echo "🧪 Running P0.4A in dry-run mode..."
	@DRY_RUN=true ./p0.4A_ocloud_provision.sh --dry-run

# Check status of clusters and resources
status:
	@echo "📊 Checking cluster and resource status..."
	@echo ""
	@echo "=== KinD Clusters ==="
	@kind get clusters 2>/dev/null || echo "No KinD clusters found"
	@echo ""
	@if [ -f "$(SMO_KUBECONFIG)" ]; then \
		echo "=== SMO Cluster Resources ==="; \
		kubectl --kubeconfig=$(SMO_KUBECONFIG) get nodes 2>/dev/null || true; \
		echo ""; \
		kubectl --kubeconfig=$(SMO_KUBECONFIG) get ocloud,templateinfo,provisioningrequest -n $(O2IMS_NAMESPACE) 2>/dev/null || true; \
		echo ""; \
		kubectl --kubeconfig=$(SMO_KUBECONFIG) get pods -n $(FOCOM_NAMESPACE) 2>/dev/null || true; \
	else \
		echo "SMO kubeconfig not found at $(SMO_KUBECONFIG)"; \
	fi
	@echo ""
	@if [ -f "$(EDGE_KUBECONFIG)" ]; then \
		echo "=== Edge Cluster Resources ==="; \
		kubectl --kubeconfig=$(EDGE_KUBECONFIG) get nodes 2>/dev/null || true; \
		echo ""; \
		kubectl --kubeconfig=$(EDGE_KUBECONFIG) get pods -n ran-workloads 2>/dev/null || true; \
	else \
		echo "Edge kubeconfig not found at $(EDGE_KUBECONFIG)"; \
	fi

# Show logs from operators
logs:
	@echo "📜 Showing recent operator logs..."
	@if [ -f "$(SMO_KUBECONFIG)" ]; then \
		echo "=== FoCoM Operator Logs ==="; \
		kubectl --kubeconfig=$(SMO_KUBECONFIG) logs -n $(FOCOM_NAMESPACE) \
			-l app.kubernetes.io/name=focom-operator --tail=20 2>/dev/null || \
			echo "No FoCoM operator logs found"; \
		echo ""; \
		echo "=== Recent Events ==="; \
		kubectl --kubeconfig=$(SMO_KUBECONFIG) get events -n $(O2IMS_NAMESPACE) \
			--sort-by='.lastTimestamp' | tail -10 2>/dev/null || \
			echo "No recent events"; \
	else \
		echo "SMO kubeconfig not found"; \
	fi

# Clean up resources
clean:
	@echo "🧹 Cleaning up resources..."
	@read -p "Are you sure you want to delete all resources? [y/N] " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "Deleting KinD cluster $(SMO_CLUSTER_NAME)..."; \
		kind delete cluster --name=$(SMO_CLUSTER_NAME) 2>/dev/null || true; \
		echo "Removing kubeconfig files..."; \
		rm -f $(SMO_KUBECONFIG) 2>/dev/null || true; \
		echo "Clean up completed"; \
	else \
		echo "Clean up cancelled"; \
	fi

# Display current configuration
config:
	@echo "📋 Current Configuration:"
	@echo "  SMO_CLUSTER_NAME  = $(SMO_CLUSTER_NAME)"
	@echo "  SMO_KUBECONFIG    = $(SMO_KUBECONFIG)"
	@echo "  EDGE_KUBECONFIG   = $(EDGE_KUBECONFIG)"
	@echo "  O2IMS_NAMESPACE   = $(O2IMS_NAMESPACE)"
	@echo "  FOCOM_NAMESPACE   = $(FOCOM_NAMESPACE)"
	@echo "  VM2_IP            = $(VM2_IP)"
	@echo "  TIMEOUT           = $(TIMEOUT)"

# Validate prerequisites
validate:
	@echo "✔️  Validating prerequisites..."
	@which kubectl >/dev/null 2>&1 && echo "✅ kubectl: found" || echo "❌ kubectl: not found"
	@which kind >/dev/null 2>&1 && echo "✅ kind: found" || echo "❌ kind: not found"
	@which kpt >/dev/null 2>&1 && echo "✅ kpt: found" || echo "❌ kpt: not found"
	@which jq >/dev/null 2>&1 && echo "✅ jq: found" || echo "❌ jq: not found"
	@which yq >/dev/null 2>&1 && echo "✅ yq: found" || echo "❌ yq: not found"
	@test -f $(EDGE_KUBECONFIG) && echo "✅ Edge kubeconfig: found" || echo "❌ Edge kubeconfig: not found"
	@kubectl --kubeconfig=$(EDGE_KUBECONFIG) cluster-info >/dev/null 2>&1 && \
		echo "✅ Edge cluster: reachable" || echo "❌ Edge cluster: not reachable"

# Quick test target
test: dry-run
	@echo "✅ Dry run completed successfully"

# Watch provisioning status
watch:
	@if [ -f "$(SMO_KUBECONFIG)" ]; then \
		watch -n 2 "kubectl --kubeconfig=$(SMO_KUBECONFIG) get ocloud,provisioningrequest,cluster -n $(O2IMS_NAMESPACE)"; \
	else \
		echo "SMO kubeconfig not found"; \
	fi

# Apply sample manifests
apply-samples:
	@echo "📝 Applying sample manifests..."
	@kubectl --kubeconfig=$(SMO_KUBECONFIG) apply -k ../samples/ocloud/

# Port forward to access services
port-forward:
	@echo "🔌 Setting up port forwarding..."
	@if [ -f "$(SMO_KUBECONFIG)" ]; then \
		echo "Forwarding FoCoM webhook on port 9443..."; \
		kubectl --kubeconfig=$(SMO_KUBECONFIG) port-forward -n $(FOCOM_NAMESPACE) \
			service/focom-webhook-service 9443:443 &; \
	else \
		echo "SMO kubeconfig not found"; \
	fi

.SILENT: help config