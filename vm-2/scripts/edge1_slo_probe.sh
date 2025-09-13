#!/bin/bash

# edge1_slo_probe.sh - Helper script for SLO monitoring probe

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Edge1 SLO Probe Script ===${NC}"

# Configuration
NAMESPACE="slo-monitoring"
SLO_ENDPOINT="http://127.0.0.1:30090/metrics/api/v1/slo"
ECHO_ENDPOINT="http://127.0.0.1:30080"

# Function to check if service is available
check_service() {
    local service_name=$1
    local port=$2
    local endpoint=$3

    echo -e "\n${YELLOW}Checking $service_name...${NC}"

    if curl -s --max-time 2 "$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service_name is accessible at $endpoint${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not accessible at $endpoint${NC}"
        return 1
    fi
}

# Function to deploy SLO workload
deploy_slo() {
    echo -e "\n${YELLOW}Deploying SLO workload...${NC}"

    for yaml in /home/ubuntu/k8s/edge1/slo/*.yaml; do
        if [ -f "$yaml" ]; then
            echo "Applying $yaml..."
            kubectl apply -f "$yaml"
        fi
    done

    echo -e "${GREEN}✓ SLO workload deployed${NC}"
}

# Function to check deployment status
check_deployment() {
    echo -e "\n${YELLOW}Checking deployment status...${NC}"

    kubectl get namespace $NAMESPACE > /dev/null 2>&1 || {
        echo -e "${RED}Namespace $NAMESPACE does not exist${NC}"
        return 1
    }

    echo "Pods in $NAMESPACE namespace:"
    kubectl get pods -n $NAMESPACE

    echo -e "\nServices in $NAMESPACE namespace:"
    kubectl get svc -n $NAMESPACE

    echo -e "\nJobs in $NAMESPACE namespace:"
    kubectl get jobs -n $NAMESPACE
}

# Function to fetch SLO metrics
fetch_metrics() {
    echo -e "\n${YELLOW}Fetching SLO metrics...${NC}"

    if response=$(curl -s --max-time 5 "$SLO_ENDPOINT" 2>/dev/null); then
        echo -e "${GREEN}✓ Successfully fetched SLO metrics:${NC}"
        echo "$response" | jq . 2>/dev/null || echo "$response"
    else
        echo -e "${RED}✗ Failed to fetch SLO metrics from $SLO_ENDPOINT${NC}"
        echo "Checking if NodePort service is available..."
        kubectl get svc -n $NAMESPACE slo-exporter-service
    fi
}

# Function to generate load
generate_load() {
    echo -e "\n${YELLOW}Generating test load...${NC}"

    # Trigger the job manually
    kubectl delete job load-generator-manual -n $NAMESPACE 2>/dev/null || true

    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: load-generator-manual
  namespace: $NAMESPACE
spec:
  template:
    spec:
      containers:
      - name: load-generator
        image: curlimages/curl:latest
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Generating load for 10 seconds..."
          for i in \$(seq 1 100); do
            curl -s http://echo-service.$NAMESPACE.svc.cluster.local:8080 > /dev/null 2>&1
            curl -s http://slo-exporter-service.$NAMESPACE.svc.cluster.local:8090/update > /dev/null 2>&1
            sleep 0.1
          done
          echo "Load generation complete"
      restartPolicy: Never
EOF

    echo "Waiting for load generation to complete..."
    kubectl wait --for=condition=complete --timeout=30s job/load-generator-manual -n $NAMESPACE 2>/dev/null || true

    echo -e "${GREEN}✓ Load generation triggered${NC}"
}

# Function to clean up
cleanup() {
    echo -e "\n${YELLOW}Cleaning up SLO workload...${NC}"

    kubectl delete namespace $NAMESPACE --ignore-not-found=true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main menu
show_menu() {
    echo -e "\n${YELLOW}Select an option:${NC}"
    echo "1) Deploy SLO workload"
    echo "2) Check deployment status"
    echo "3) Fetch SLO metrics"
    echo "4) Generate test load"
    echo "5) Full test (deploy, load, fetch)"
    echo "6) Cleanup"
    echo "7) Exit"
}

# Main execution
case "${1:-}" in
    deploy)
        deploy_slo
        ;;
    status)
        check_deployment
        ;;
    metrics)
        fetch_metrics
        ;;
    load)
        generate_load
        ;;
    test)
        deploy_slo
        sleep 10
        check_deployment
        generate_load
        sleep 5
        fetch_metrics
        ;;
    cleanup)
        cleanup
        ;;
    *)
        if [ -n "${1:-}" ]; then
            echo "Unknown command: $1"
        fi

        while true; do
            show_menu
            read -p "Enter choice [1-7]: " choice

            case $choice in
                1) deploy_slo ;;
                2) check_deployment ;;
                3) fetch_metrics ;;
                4) generate_load ;;
                5)
                    deploy_slo
                    sleep 10
                    check_deployment
                    generate_load
                    sleep 5
                    fetch_metrics
                    ;;
                6) cleanup ;;
                7) exit 0 ;;
                *) echo -e "${RED}Invalid option${NC}" ;;
            esac
        done
        ;;
esac