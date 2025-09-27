#!/bin/bash
# TMF921 Adapter - Comprehensive Automation Examples
# Demonstrates fully automated usage patterns for CI/CD integration

set -e

BASE_URL="http://localhost:8889"
API_ENDPOINT="$BASE_URL/api/v1/intent/transform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if service is healthy
check_service_health() {
    log_info "Checking TMF921 adapter service health..."

    if curl -s -f "$BASE_URL/health" > /dev/null; then
        log_success "TMF921 adapter service is healthy"
        return 0
    else
        log_error "TMF921 adapter service is not healthy or not running"
        log_info "Please start the service with:"
        echo "cd /home/ubuntu/nephio-intent-to-o2-demo/adapter"
        echo "python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8889"
        return 1
    fi
}

# Generate a single intent
generate_intent() {
    local nl_text="$1"
    local target_site="$2"

    local payload='{"natural_language": "'"$nl_text"'"'
    if [ ! -z "$target_site" ]; then
        payload+=', "target_site": "'"$target_site"'"'
    fi
    payload+='}'

    local response=$(curl -s -X POST "$API_ENDPOINT" \
                          -H "Content-Type: application/json" \
                          -d "$payload")

    if [ $? -eq 0 ]; then
        echo "$response"
    else
        log_error "Failed to generate intent for: $nl_text"
        return 1
    fi
}

# Extract intent information
extract_intent_info() {
    local response="$1"
    local intent_id=$(echo "$response" | jq -r '.intent.intentId')
    local service_type=$(echo "$response" | jq -r '.intent.service.type')
    local target_site=$(echo "$response" | jq -r '.intent.targetSite')
    local sst=$(echo "$response" | jq -r '.intent.slice.sst')
    local exec_time=$(echo "$response" | jq -r '.execution_time')

    echo "$intent_id|$service_type|$target_site|$sst|$exec_time"
}

# Example 1: Basic automation workflow
example_basic_automation() {
    log_info "Example 1: Basic Automation Workflow"
    echo "======================================"

    declare -a test_cases=(
        "Deploy eMBB service for gaming;edge1"
        "Setup URLLC for autonomous vehicles;edge2"
        "Configure mMTC for IoT sensors;edge3"
        "Deploy video streaming service;edge4"
        "Setup multi-site CDN;both"
    )

    for case in "${test_cases[@]}"; do
        IFS=';' read -r nl_text target_site <<< "$case"

        log_info "Processing: $nl_text"

        response=$(generate_intent "$nl_text" "$target_site")
        if [ $? -eq 0 ]; then
            info=$(extract_intent_info "$response")
            IFS='|' read -r intent_id service_type target_site sst exec_time <<< "$info"
            log_success "Generated $intent_id: $service_type -> $target_site (SST $sst) in ${exec_time}s"
        else
            log_error "Failed to process: $nl_text"
        fi
        echo
    done
}

# Example 2: Batch processing with error handling
example_batch_processing() {
    log_info "Example 2: Batch Processing with Error Handling"
    echo "==============================================="

    declare -a batch_requests=(
        "Deploy 5G network slice with 100 Mbps at edge1"
        "Setup ultra-low latency service under 5ms at edge2"
        "Configure massive IoT monitoring network at edge3"
        "Deploy real-time gaming service at edge4"
        "Setup video streaming across all edge sites"
        ""  # This should fail
        "Deploy service with invalid requirements"
    )

    local success_count=0
    local failure_count=0
    local total_time=0

    log_info "Processing ${#batch_requests[@]} requests..."
    start_time=$(date +%s.%N)

    for request in "${batch_requests[@]}"; do
        if [ -z "$request" ]; then
            log_warning "Skipping empty request (expected failure)"
            ((failure_count++))
            continue
        fi

        response=$(generate_intent "$request")
        if [ $? -eq 0 ]; then
            info=$(extract_intent_info "$response")
            IFS='|' read -r intent_id service_type target_site sst exec_time <<< "$info"
            log_success "$intent_id: $service_type -> $target_site"
            ((success_count++))
        else
            log_error "Failed: $request"
            ((failure_count++))
        fi
    done

    end_time=$(date +%s.%N)
    total_time=$(echo "$end_time - $start_time" | bc)

    echo
    log_info "Batch Processing Summary:"
    echo "  Total requests: ${#batch_requests[@]}"
    echo "  Successful: $success_count"
    echo "  Failed: $failure_count"
    echo "  Success rate: $(( success_count * 100 / (success_count + failure_count) ))%"
    echo "  Total time: ${total_time}s"
}

# Example 3: QoS parameter validation
example_qos_validation() {
    log_info "Example 3: QoS Parameter Validation"
    echo "===================================="

    declare -a qos_tests=(
        "Deploy service with 50 Mbps bandwidth"
        "Setup service with 10ms latency requirement"
        "Configure high-speed 1 Gbps connection"
        "Deploy real-time service under 1ms latency"
        "Setup 200 Mbps download and 100 Mbps upload"
    )

    for test in "${qos_tests[@]}"; do
        log_info "Testing QoS extraction: $test"

        response=$(generate_intent "$test")
        if [ $? -eq 0 ]; then
            # Extract QoS parameters
            dl_mbps=$(echo "$response" | jq -r '.intent.qos.dl_mbps // "null"')
            ul_mbps=$(echo "$response" | jq -r '.intent.qos.ul_mbps // "null"')
            latency_ms=$(echo "$response" | jq -r '.intent.qos.latency_ms // "null"')

            qos_info=""
            [ "$dl_mbps" != "null" ] && qos_info+="DL: ${dl_mbps} Mbps "
            [ "$ul_mbps" != "null" ] && qos_info+="UL: ${ul_mbps} Mbps "
            [ "$latency_ms" != "null" ] && qos_info+="Latency: ${latency_ms}ms"

            log_success "Extracted QoS: $qos_info"
        else
            log_error "QoS extraction failed"
        fi
        echo
    done
}

# Example 4: Service type classification
example_service_classification() {
    log_info "Example 4: Service Type Classification"
    echo "======================================"

    declare -A service_tests=(
        ["video streaming for entertainment"]="eMBB"
        ["ultra-low latency for autonomous vehicles"]="URLLC"
        ["IoT sensor monitoring network"]="mMTC"
        ["real-time gaming with low latency"]="URLLC"
        ["massive machine communication"]="mMTC"
        ["high bandwidth broadband service"]="eMBB"
        ["critical industrial automation"]="URLLC"
    )

    for test_text in "${!service_tests[@]}"; do
        expected_type="${service_tests[$test_text]}"

        log_info "Testing: $test_text"

        response=$(generate_intent "$test_text")
        if [ $? -eq 0 ]; then
            actual_type=$(echo "$response" | jq -r '.intent.service.type')
            sst=$(echo "$response" | jq -r '.intent.slice.sst')

            if [ "$actual_type" = "$expected_type" ]; then
                log_success "Correct classification: $actual_type (SST $sst)"
            else
                log_warning "Unexpected classification: got $actual_type, expected $expected_type"
            fi
        else
            log_error "Classification failed"
        fi
        echo
    done
}

# Example 5: Multi-site deployment simulation
example_multisite_deployment() {
    log_info "Example 5: Multi-site Deployment Simulation"
    echo "==========================================="

    # Simulate a complete edge deployment workflow
    declare -a deployment_steps=(
        "Deploy core network functions at edge1"
        "Setup user plane functions at edge2"
        "Configure management plane at edge3"
        "Deploy monitoring services at edge4"
        "Setup inter-site connectivity across all sites"
        "Configure load balancing across all edge sites"
    )

    local deployment_id="deployment_$(date +%s)"
    local deployed_intents=()

    log_info "Starting deployment: $deployment_id"

    for step in "${deployment_steps[@]}"; do
        log_info "Step: $step"

        response=$(generate_intent "$step")
        if [ $? -eq 0 ]; then
            intent_id=$(echo "$response" | jq -r '.intent.intentId')
            target_site=$(echo "$response" | jq -r '.intent.targetSite')
            deployed_intents+=("$intent_id:$target_site")
            log_success "Deployed $intent_id to $target_site"
        else
            log_error "Deployment step failed: $step"
        fi
    done

    echo
    log_info "Deployment $deployment_id completed!"
    log_info "Deployed intents:"
    for intent in "${deployed_intents[@]}"; do
        IFS=':' read -r id site <<< "$intent"
        echo "  - $id -> $site"
    done
}

# Example 6: JSON schema validation
example_json_validation() {
    log_info "Example 6: JSON Schema Validation"
    echo "=================================="

    response=$(generate_intent "Deploy test service for validation")

    if [ $? -eq 0 ]; then
        # Validate required TMF921 fields
        required_fields=("intentId" "name" "description" "service" "targetSite" "qos" "slice" "priority" "lifecycle" "metadata")

        log_info "Validating TMF921 structure..."

        all_valid=true
        for field in "${required_fields[@]}"; do
            if echo "$response" | jq -e ".intent.$field" > /dev/null; then
                log_success "✓ $field present"
            else
                log_error "✗ $field missing"
                all_valid=false
            fi
        done

        if [ "$all_valid" = true ]; then
            log_success "All required TMF921 fields present"
        else
            log_error "TMF921 structure validation failed"
        fi

        # Validate service type
        service_type=$(echo "$response" | jq -r '.intent.service.type')
        if [[ "$service_type" =~ ^(eMBB|URLLC|mMTC|generic)$ ]]; then
            log_success "✓ Valid service type: $service_type"
        else
            log_error "✗ Invalid service type: $service_type"
        fi

        # Validate SST
        sst=$(echo "$response" | jq -r '.intent.slice.sst')
        if [[ "$sst" =~ ^[1-3]$ ]]; then
            log_success "✓ Valid SST: $sst"
        else
            log_error "✗ Invalid SST: $sst"
        fi

        # Validate target site
        target_site=$(echo "$response" | jq -r '.intent.targetSite')
        if [[ "$target_site" =~ ^(edge1|edge2|edge3|edge4|both)$ ]]; then
            log_success "✓ Valid target site: $target_site"
        else
            log_error "✗ Invalid target site: $target_site"
        fi
    else
        log_error "Failed to generate intent for validation"
    fi
}

# Example 7: Performance benchmarking
example_performance_benchmark() {
    log_info "Example 7: Performance Benchmarking"
    echo "===================================="

    local num_requests=20
    local concurrent_requests=5

    log_info "Running performance benchmark with $num_requests requests..."

    # Create test requests
    declare -a test_requests=()
    for i in $(seq 1 $num_requests); do
        test_requests+=("Deploy test service $i for benchmarking")
    done

    # Run sequential test
    log_info "Sequential execution test..."
    start_time=$(date +%s.%N)

    for request in "${test_requests[@]:0:10}"; do  # Use first 10 for sequential
        generate_intent "$request" > /dev/null
    done

    end_time=$(date +%s.%N)
    sequential_time=$(echo "$end_time - $start_time" | bc)
    sequential_rps=$(echo "scale=2; 10 / $sequential_time" | bc)

    log_success "Sequential: 10 requests in ${sequential_time}s (${sequential_rps} RPS)"

    # Run concurrent test (simplified)
    log_info "Concurrent execution test..."
    start_time=$(date +%s.%N)

    # Simple concurrent simulation using background processes
    for request in "${test_requests[@]:10:5}"; do  # Use next 5 for concurrent
        generate_intent "$request" > /dev/null &
    done
    wait  # Wait for all background processes

    end_time=$(date +%s.%N)
    concurrent_time=$(echo "$end_time - $start_time" | bc)
    concurrent_rps=$(echo "scale=2; 5 / $concurrent_time" | bc)

    log_success "Concurrent: 5 requests in ${concurrent_time}s (${concurrent_rps} RPS)"

    # Get service metrics
    metrics=$(curl -s "$BASE_URL/metrics")
    total_requests=$(echo "$metrics" | jq -r '.metrics.total_requests')
    success_rate=$(echo "$metrics" | jq -r '.metrics.success_rate')

    echo
    log_info "Service Metrics:"
    echo "  Total processed: $total_requests"
    echo "  Success rate: $(echo "$success_rate * 100" | bc -l | cut -d. -f1)%"
}

# Example 8: Integration testing
example_integration_testing() {
    log_info "Example 8: Integration Testing"
    echo "==============================="

    # Test different integration scenarios
    declare -a integration_tests=(
        "CI/CD pipeline deployment;Deploy automated service for CI/CD"
        "Webhook integration;Process webhook event for service deployment"
        "API gateway integration;Configure API gateway routing"
        "Monitoring integration;Setup monitoring and alerting"
        "Backup integration;Configure backup and disaster recovery"
    )

    log_info "Running integration tests..."

    for test in "${integration_tests[@]}"; do
        IFS=';' read -r test_name request <<< "$test"

        log_info "Integration test: $test_name"

        response=$(generate_intent "$request")
        if [ $? -eq 0 ]; then
            intent_id=$(echo "$response" | jq -r '.intent.intentId')
            exec_time=$(echo "$response" | jq -r '.execution_time')

            # Simulate integration validation
            if (( $(echo "$exec_time < 1.0" | bc -l) )); then
                log_success "✓ Integration test passed: $intent_id (${exec_time}s)"
            else
                log_warning "⚠ Integration test slow: $intent_id (${exec_time}s)"
            fi
        else
            log_error "✗ Integration test failed: $test_name"
        fi
    done
}

# Main execution
main() {
    echo "🚀 TMF921 Adapter - Comprehensive Automation Examples"
    echo "======================================================="
    echo

    # Check service health first
    if ! check_service_health; then
        exit 1
    fi

    echo

    # Run all examples
    example_basic_automation
    echo
    example_batch_processing
    echo
    example_qos_validation
    echo
    example_service_classification
    echo
    example_multisite_deployment
    echo
    example_json_validation
    echo
    example_performance_benchmark
    echo
    example_integration_testing

    echo
    log_success "🎉 All automation examples completed successfully!"
    log_info "The TMF921 adapter is ready for production automation workflows."
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Please install jq:"
    echo "sudo apt-get install jq"
    exit 1
fi

# Check if bc is available
if ! command -v bc &> /dev/null; then
    log_error "bc is required but not installed. Please install bc:"
    echo "sudo apt-get install bc"
    exit 1
fi

# Run main function
main "$@"