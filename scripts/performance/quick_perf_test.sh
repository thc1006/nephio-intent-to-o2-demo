#!/usr/bin/env bash
# Quick Performance Test for E2E Pipeline Components
# Tests individual components and provides immediate performance feedback

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_perf() { echo -e "${CYAN}[PERF]${NC} $*"; }

# Test component performance
test_component_performance() {
    local component="$1"
    local test_command="$2"
    local iterations=3

    log_info "Testing $component performance ($iterations iterations)"

    local total_time=0
    local success_count=0

    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s.%3N)

        if eval "$test_command" > /dev/null 2>&1; then
            local end_time=$(date +%s.%3N)
            local duration=$(echo "$end_time - $start_time" | bc)
            total_time=$(echo "$total_time + $duration" | bc)
            success_count=$((success_count + 1))
            log_perf "$component iteration $i: ${duration}s"
        else
            log_error "$component iteration $i: FAILED"
        fi
    done

    if [[ $success_count -gt 0 ]]; then
        local avg_time=$(echo "scale=3; $total_time / $success_count" | bc)
        local success_rate=$(echo "scale=1; $success_count * 100 / $iterations" | bc)
        log_success "$component - Avg: ${avg_time}s, Success: ${success_rate}%"
        echo "$component,$avg_time,$success_rate" >> "$RESULTS_FILE"
    else
        log_error "$component - All iterations failed"
        echo "$component,N/A,0" >> "$RESULTS_FILE"
    fi
}

# Test Git operations
test_git_performance() {
    log_info "Testing Git operations performance"

    # Test git status
    test_component_performance "Git Status" "cd '$PROJECT_ROOT' && git status"

    # Test git log
    test_component_performance "Git Log" "cd '$PROJECT_ROOT' && git log --oneline -10"

    # Test git diff
    test_component_performance "Git Diff" "cd '$PROJECT_ROOT' && git diff HEAD~1"
}

# Test kpt operations
test_kpt_performance() {
    log_info "Testing kpt operations performance"

    # Create test package
    local test_pkg_dir="/tmp/perf-test-pkg"
    mkdir -p "$test_pkg_dir"

    cat > "$test_pkg_dir/Kptfile" <<EOF
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: perf-test
info:
  description: Performance test package
pipeline:
  mutators:
  - image: gcr.io/kpt-fn/set-labels:v0.2.0
    configMap:
      environment: test
EOF

    cat > "$test_pkg_dir/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

    # Test kpt function render
    test_component_performance "kpt fn render" "cd '$test_pkg_dir' && kpt fn render"

    # Clean up
    rm -rf "$test_pkg_dir"
}

# Test Prometheus queries
test_prometheus_performance() {
    log_info "Testing Prometheus query performance"

    local prometheus_url="http://localhost:9090"

    # Test basic query
    test_component_performance "Prometheus Simple Query" \
        "curl -s '$prometheus_url/api/v1/query?query=up' | jq -r '.status'"

    # Test complex query
    test_component_performance "Prometheus Complex Query" \
        "curl -s '$prometheus_url/api/v1/query?query=rate(prometheus_http_requests_total[5m])' | jq -r '.status'"
}

# Test edge connectivity
test_edge_connectivity() {
    log_info "Testing edge site connectivity"

    # Read edge configuration
    local config_file="$PROJECT_ROOT/config/edge-sites-config.yaml"

    if [[ ! -f "$config_file" ]]; then
        log_error "Edge sites config not found: $config_file"
        return 1
    fi

    # Test each edge site
    for edge in edge1 edge2 edge3 edge4; do
        local ip=$(grep -A 20 "^  $edge:" "$config_file" | grep "ip:" | awk '{print $2}' | tr -d '"' || echo "")

        if [[ -n "$ip" ]]; then
            test_component_performance "Edge $edge Ping" "ping -c 1 -W 2 '$ip'"
            test_component_performance "Edge $edge SSH" "timeout 5 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no '$ip' 'echo ok'"
        else
            log_warn "No IP found for $edge"
        fi
    done
}

# Test file I/O performance
test_file_io_performance() {
    log_info "Testing file I/O performance"

    local test_dir="/tmp/perf-test-io"
    mkdir -p "$test_dir"

    # Test small file write/read
    test_component_performance "Small File Write" \
        "echo 'test data' > '$test_dir/small.txt'"

    test_component_performance "Small File Read" \
        "cat '$test_dir/small.txt'"

    # Test larger file operations
    test_component_performance "Large File Write" \
        "dd if=/dev/zero of='$test_dir/large.txt' bs=1M count=10 2>/dev/null"

    test_component_performance "Large File Read" \
        "dd if='$test_dir/large.txt' of=/dev/null bs=1M 2>/dev/null"

    # Clean up
    rm -rf "$test_dir"
}

# Generate system resource baseline
generate_resource_baseline() {
    log_info "Generating system resource baseline"

    echo "=== SYSTEM RESOURCE BASELINE ===" > "$BASELINE_FILE"
    echo "Timestamp: $(date)" >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    # CPU information
    echo "CPU Information:" >> "$BASELINE_FILE"
    lscpu | grep -E "(Model name|CPU\(s\)|Thread)" >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    # Memory information
    echo "Memory Information:" >> "$BASELINE_FILE"
    free -h >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    # Disk information
    echo "Disk Information:" >> "$BASELINE_FILE"
    df -h | head -5 >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    # Current load
    echo "Current System Load:" >> "$BASELINE_FILE"
    uptime >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    # Network interfaces
    echo "Network Interfaces:" >> "$BASELINE_FILE"
    ip addr show | grep -E "(inet |mtu)" >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    # Process count
    echo "Process Count:" >> "$BASELINE_FILE"
    ps aux | wc -l >> "$BASELINE_FILE"
    echo "" >> "$BASELINE_FILE"

    log_success "Resource baseline saved to $BASELINE_FILE"
}

# Analyze bottlenecks from results
analyze_bottlenecks() {
    log_info "Analyzing performance bottlenecks"

    if [[ ! -f "$RESULTS_FILE" ]]; then
        log_error "Results file not found: $RESULTS_FILE"
        return 1
    fi

    echo "=== BOTTLENECK ANALYSIS ===" > "$ANALYSIS_FILE"
    echo "Generated: $(date)" >> "$ANALYSIS_FILE"
    echo "" >> "$ANALYSIS_FILE"

    # Find slowest operations
    echo "Slowest Operations:" >> "$ANALYSIS_FILE"
    echo "==================" >> "$ANALYSIS_FILE"
    tail -n +2 "$RESULTS_FILE" | sort -t',' -k2 -nr | head -5 | while IFS=',' read -r component avg_time success_rate; do
        echo "$component: ${avg_time}s (${success_rate}% success)" >> "$ANALYSIS_FILE"
    done
    echo "" >> "$ANALYSIS_FILE"

    # Failed operations
    echo "Failed Operations:" >> "$ANALYSIS_FILE"
    echo "==================" >> "$ANALYSIS_FILE"
    grep ",0$" "$RESULTS_FILE" | while IFS=',' read -r component avg_time success_rate; do
        echo "$component: FAILED" >> "$ANALYSIS_FILE"
    done
    echo "" >> "$ANALYSIS_FILE"

    # Optimization recommendations
    echo "Optimization Recommendations:" >> "$ANALYSIS_FILE"
    echo "============================" >> "$ANALYSIS_FILE"

    # Check for Git performance issues
    local git_avg=$(grep "Git" "$RESULTS_FILE" | head -1 | cut -d',' -f2)
    if [[ -n "$git_avg" ]] && (( $(echo "$git_avg > 1.0" | bc -l) )); then
        echo "- Git operations are slow (${git_avg}s avg). Consider git gc and shallow clones." >> "$ANALYSIS_FILE"
    fi

    # Check for connectivity issues
    if grep -q "Edge.*,0$" "$RESULTS_FILE"; then
        echo "- Edge connectivity issues detected. Check network configuration and SSH keys." >> "$ANALYSIS_FILE"
    fi

    # Check for kpt performance
    local kpt_avg=$(grep "kpt" "$RESULTS_FILE" | head -1 | cut -d',' -f2)
    if [[ -n "$kpt_avg" ]] && (( $(echo "$kpt_avg > 5.0" | bc -l) )); then
        echo "- kpt operations are slow (${kpt_avg}s avg). Consider parallel function execution." >> "$ANALYSIS_FILE"
    fi

    log_success "Bottleneck analysis saved to $ANALYSIS_FILE"
}

# Main function
main() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    RESULTS_FILE="/tmp/quick_perf_results_${timestamp}.csv"
    BASELINE_FILE="/tmp/system_baseline_${timestamp}.txt"
    ANALYSIS_FILE="/tmp/bottleneck_analysis_${timestamp}.txt"

    log_info "Starting Quick Performance Test"
    log_info "Results will be saved to: $RESULTS_FILE"

    # Initialize results file
    echo "component,avg_time_seconds,success_rate_percent" > "$RESULTS_FILE"

    # Generate system baseline
    generate_resource_baseline

    # Run performance tests
    test_git_performance
    test_kpt_performance
    test_prometheus_performance
    test_edge_connectivity
    test_file_io_performance

    # Analyze results
    analyze_bottlenecks

    # Display summary
    echo ""
    log_success "=== QUICK PERFORMANCE TEST SUMMARY ==="
    echo ""
    echo "Results File: $RESULTS_FILE"
    echo "Baseline File: $BASELINE_FILE"
    echo "Analysis File: $ANALYSIS_FILE"
    echo ""

    # Show top 3 slowest operations
    echo "Top 3 Slowest Operations:"
    tail -n +2 "$RESULTS_FILE" | sort -t',' -k2 -nr | head -3 | \
        awk -F',' '{printf "  %s: %.3fs (%.1f%% success)\n", $1, $2, $3}'
    echo ""

    # Copy results to project reports directory
    local reports_dir="$PROJECT_ROOT/reports/performance-benchmarks"
    mkdir -p "$reports_dir"
    cp "$RESULTS_FILE" "$reports_dir/quick_perf_${timestamp}.csv"
    cp "$BASELINE_FILE" "$reports_dir/system_baseline_${timestamp}.txt"
    cp "$ANALYSIS_FILE" "$reports_dir/bottleneck_analysis_${timestamp}.txt"

    log_success "Performance test completed. Results copied to $reports_dir/"

    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi