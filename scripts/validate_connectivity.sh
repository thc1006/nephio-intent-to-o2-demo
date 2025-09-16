#!/bin/bash

# Service Connectivity Matrix Validator
# Tests all service endpoints and generates connectivity report
# Version: v1.1.2-rc1

set -euo pipefail

# Configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="reports/connectivity-${TIMESTAMP}"
TIMEOUT="${TIMEOUT:-5}"

# Network endpoints from configuration
EDGE1_IP="${EDGE1_IP:-172.16.4.45}"
EDGE2_IP="${EDGE2_IP:-172.16.4.176}"
SMO_IP="${SMO_IP:-172.16.0.78}"

# Service port mappings
declare -A SERVICES=(
    ["edge1-o2ims"]="http://${EDGE1_IP}:31280"
    ["edge1-monitor"]="http://${EDGE1_IP}:30090/metrics"
    ["edge1-http"]="http://${EDGE1_IP}:31080"
    ["edge1-https"]="https://${EDGE1_IP}:31443"
    ["edge2-o2ims"]="http://${EDGE2_IP}:31280"
    ["edge2-monitor"]="http://${EDGE2_IP}:30090/metrics"
    ["edge2-http"]="http://${EDGE2_IP}:31080"
    ["edge2-https"]="https://${EDGE2_IP}:31443"
    ["smo-prometheus"]="http://${SMO_IP}:31090"
    ["smo-grafana"]="http://${SMO_IP}:31300"
)

# Expected responses
declare -A EXPECTED=(
    ["edge1-o2ims"]="operational|status"
    ["edge1-monitor"]="^#|{.*}"
    ["edge2-o2ims"]="operational|nginx|404"
    ["edge2-monitor"]="^#|{.*}"
    ["smo-prometheus"]="Prometheus|Ready"
    ["smo-grafana"]="database|ok"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Results tracking
declare -A RESULTS
declare -A RESPONSE_TIMES
declare -A HTTP_CODES

# Initialize
mkdir -p ${REPORT_DIR}/{responses,metrics}

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Service Connectivity Matrix Test     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

# Log function
log() {
    echo -e "[$(date +'%H:%M:%S')] $*" | tee -a ${REPORT_DIR}/connectivity.log
}

# Test single endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected="${EXPECTED[$name]:-.*}"

    echo -n "Testing ${name}: "

    # Prepare curl command
    local curl_opts="-sS --connect-timeout ${TIMEOUT} --max-time $((TIMEOUT * 2))"

    # Add certificate validation skip for HTTPS
    if [[ $url == https://* ]]; then
        curl_opts="${curl_opts} -k"
    fi

    # Execute test
    local start_time=$(date +%s%N)
    local response=""
    local http_code=""
    local curl_exit=0

    # Capture response and HTTP code
    response=$(curl ${curl_opts} -w "HTTP_CODE:%{http_code}" "${url}" 2>&1) || curl_exit=$?

    # Extract HTTP code
    if [[ $response =~ HTTP_CODE:([0-9]+)$ ]]; then
        http_code="${BASH_REMATCH[1]}"
        response="${response%HTTP_CODE:*}"
    fi

    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))

    # Store metrics
    RESPONSE_TIMES[$name]=$response_time
    HTTP_CODES[$name]="${http_code:-000}"

    # Evaluate result
    if [ $curl_exit -eq 0 ] && [ -n "$response" ]; then
        # Save response
        echo "$response" > "${REPORT_DIR}/responses/${name}.txt"

        # Check expected pattern
        if echo "$response" | grep -qE "${expected}"; then
            RESULTS[$name]="PASS"
            echo -e "${GREEN}✓${NC} (${response_time}ms, HTTP ${http_code})"
            log "PASS" "${name}: Response matched expected pattern"
        else
            RESULTS[$name]="WARN"
            echo -e "${YELLOW}⚠${NC} (${response_time}ms, HTTP ${http_code}) - Unexpected response"
            log "WARN" "${name}: Unexpected response pattern"
        fi
    elif [ $curl_exit -eq 7 ] || [ $curl_exit -eq 28 ]; then
        RESULTS[$name]="TIMEOUT"
        echo -e "${YELLOW}⏱${NC} Connection timeout"
        log "TIMEOUT" "${name}: Connection timeout after ${TIMEOUT}s"
    elif [ "${http_code}" == "404" ] && [[ "${expected}" =~ 404 ]]; then
        RESULTS[$name]="EXPECTED"
        echo -e "${BLUE}◯${NC} (${response_time}ms, HTTP 404) - Expected"
        log "INFO" "${name}: 404 response (expected)"
    else
        RESULTS[$name]="FAIL"
        echo -e "${RED}✗${NC} Connection failed (exit: ${curl_exit})"
        log "FAIL" "${name}: Connection failed with exit code ${curl_exit}"
    fi
}

# Test Kubernetes connectivity
test_kubernetes() {
    echo -e "\n${BLUE}Testing Kubernetes Connectivity${NC}"

    local contexts=("kind-nephio-demo" "edge1" "edge2")

    for context in "${contexts[@]}"; do
        echo -n "  Context ${context}: "

        if kubectl --context ${context} get nodes >/dev/null 2>&1; then
            local node_count=$(kubectl --context ${context} get nodes -o json | jq '.items | length')
            echo -e "${GREEN}✓${NC} Connected (${node_count} nodes)"
            RESULTS["k8s-${context}"]="PASS"
        else
            echo -e "${RED}✗${NC} Not accessible"
            RESULTS["k8s-${context}"]="FAIL"
        fi
    done
}

# Test network connectivity
test_network() {
    echo -e "\n${BLUE}Testing Network Connectivity${NC}"

    local hosts=("${EDGE1_IP}:Edge1" "${EDGE2_IP}:Edge2" "${SMO_IP}:SMO")

    for host_pair in "${hosts[@]}"; do
        IFS=':' read -r ip name <<< "$host_pair"
        echo -n "  Ping ${name} (${ip}): "

        if ping -c 1 -W 2 ${ip} >/dev/null 2>&1; then
            local latency=$(ping -c 1 -W 2 ${ip} | grep 'time=' | sed -E 's/.*time=([0-9.]+).*/\1/')
            echo -e "${GREEN}✓${NC} (${latency}ms)"
            RESULTS["ping-${name}"]="PASS"
        else
            echo -e "${YELLOW}⚠${NC} No response"
            RESULTS["ping-${name}"]="TIMEOUT"
        fi
    done
}

# Test DNS resolution
test_dns() {
    echo -e "\n${BLUE}Testing DNS Resolution${NC}"

    local domains=("github.com" "google.com" "localhost")

    for domain in "${domains[@]}"; do
        echo -n "  Resolve ${domain}: "

        if host ${domain} >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            RESULTS["dns-${domain}"]="PASS"
        else
            echo -e "${RED}✗${NC}"
            RESULTS["dns-${domain}"]="FAIL"
        fi
    done
}

# Generate connectivity matrix
generate_matrix() {
    echo -e "\n${BLUE}Connectivity Matrix${NC}\n"

    # Header
    printf "%-25s %-10s %-10s %-12s %s\n" \
        "SERVICE" "STATUS" "HTTP" "LATENCY" "ENDPOINT"
    echo "─────────────────────────────────────────────────────────────────────────"

    # Service rows
    for name in "${!SERVICES[@]}"; do
        local status="${RESULTS[$name]:-SKIP}"
        local http="${HTTP_CODES[$name]:-N/A}"
        local latency="${RESPONSE_TIMES[$name]:-N/A}"
        [ "$latency" != "N/A" ] && latency="${latency}ms"

        local status_color=""
        case $status in
            "PASS") status_color="${GREEN}" ;;
            "FAIL") status_color="${RED}" ;;
            "WARN"|"TIMEOUT") status_color="${YELLOW}" ;;
            "EXPECTED") status_color="${BLUE}" ;;
            *) status_color="${NC}" ;;
        esac

        printf "%-25s ${status_color}%-10s${NC} %-10s %-12s %s\n" \
            "$name" "$status" "$http" "$latency" "${SERVICES[$name]}"
    done
}

# Generate JSON report
generate_json_report() {
    local json_file="${REPORT_DIR}/connectivity-matrix.json"

    cat > ${json_file} <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "test_timeout": ${TIMEOUT},
  "endpoints": {
EOF

    local first=true
    for name in "${!SERVICES[@]}"; do
        [ "$first" == "true" ] && first=false || echo "," >> ${json_file}

        cat >> ${json_file} <<EOF
    "${name}": {
      "url": "${SERVICES[$name]}",
      "status": "${RESULTS[$name]:-SKIP}",
      "http_code": "${HTTP_CODES[$name]:-null}",
      "response_time_ms": ${RESPONSE_TIMES[$name]:-null},
      "expected_pattern": "${EXPECTED[$name]:-.*}"
    }
EOF
    done

    cat >> ${json_file} <<EOF

  },
  "summary": {
    "total": ${#SERVICES[@]},
    "passed": $(echo ${RESULTS[@]} | grep -o "PASS" | wc -l),
    "failed": $(echo ${RESULTS[@]} | grep -o "FAIL" | wc -l),
    "warnings": $(echo ${RESULTS[@]} | grep -o "WARN" | wc -l),
    "timeouts": $(echo ${RESULTS[@]} | grep -o "TIMEOUT" | wc -l)
  }
}
EOF

    log "INFO" "JSON report saved to: ${json_file}"
}

# Generate HTML dashboard
generate_html_dashboard() {
    local html_file="${REPORT_DIR}/dashboard.html"

    cat > ${html_file} <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Service Connectivity Dashboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background: #f5f5f5;
        }
        h1 {
            color: #2e7d32;
            border-bottom: 2px solid #2e7d32;
            padding-bottom: 10px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .card {
            background: white;
            border-radius: 8px;
            padding: 15px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .status-pass { color: #2e7d32; font-weight: bold; }
        .status-fail { color: #d32f2f; font-weight: bold; }
        .status-warn { color: #f57c00; font-weight: bold; }
        .status-timeout { color: #fbc02d; font-weight: bold; }
        .metric {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            padding: 5px;
            background: #f9f9f9;
            border-radius: 4px;
        }
        .summary {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #2e7d32;
            color: white;
        }
        tr:hover {
            background: #f5f5f5;
        }
    </style>
</head>
<body>
    <h1>Service Connectivity Dashboard</h1>
    <p>Generated:
EOF
    echo "$(date +'%Y-%m-%d %H:%M:%S')</p>" >> ${html_file}

    # Summary section
    local total=${#SERVICES[@]}
    local passed=$(echo ${RESULTS[@]} | grep -o "PASS" | wc -l)
    local failed=$(echo ${RESULTS[@]} | grep -o "FAIL" | wc -l)
    local warnings=$(echo ${RESULTS[@]} | grep -o "WARN" | wc -l)
    local timeouts=$(echo ${RESULTS[@]} | grep -o "TIMEOUT" | wc -l)

    cat >> ${html_file} <<EOF
    <div class="summary">
        <h2>Summary</h2>
        <div class="grid">
            <div class="metric">
                <span>Total Endpoints:</span>
                <strong>${total}</strong>
            </div>
            <div class="metric">
                <span>Passed:</span>
                <span class="status-pass">${passed}</span>
            </div>
            <div class="metric">
                <span>Failed:</span>
                <span class="status-fail">${failed}</span>
            </div>
            <div class="metric">
                <span>Warnings:</span>
                <span class="status-warn">${warnings}</span>
            </div>
            <div class="metric">
                <span>Timeouts:</span>
                <span class="status-timeout">${timeouts}</span>
            </div>
        </div>
    </div>

    <h2>Service Status</h2>
    <table>
        <tr>
            <th>Service</th>
            <th>Status</th>
            <th>HTTP Code</th>
            <th>Response Time</th>
            <th>Endpoint</th>
        </tr>
EOF

    # Add service rows
    for name in "${!SERVICES[@]}"; do
        local status="${RESULTS[$name]:-SKIP}"
        local http="${HTTP_CODES[$name]:-N/A}"
        local latency="${RESPONSE_TIMES[$name]:-N/A}"
        [ "$latency" != "N/A" ] && latency="${latency}ms"

        local status_class="status-${status,,}"

        cat >> ${html_file} <<EOF
        <tr>
            <td>${name}</td>
            <td class="${status_class}">${status}</td>
            <td>${http}</td>
            <td>${latency}</td>
            <td><code>${SERVICES[$name]}</code></td>
        </tr>
EOF
    done

    cat >> ${html_file} <<EOF
    </table>

    <h2>Network Tests</h2>
    <div class="grid">
        <div class="card">
            <h3>Kubernetes Clusters</h3>
EOF

    # Add Kubernetes results
    for context in "kind-nephio-demo" "edge1" "edge2"; do
        local k8s_status="${RESULTS[k8s-${context}]:-SKIP}"
        local k8s_class="status-${k8s_status,,}"
        echo "            <div class=\"metric\"><span>${context}:</span><span class=\"${k8s_class}\">${k8s_status}</span></div>" >> ${html_file}
    done

    cat >> ${html_file} <<EOF
        </div>
        <div class="card">
            <h3>Network Ping</h3>
EOF

    # Add ping results
    for name in "Edge1" "Edge2" "SMO"; do
        local ping_status="${RESULTS[ping-${name}]:-SKIP}"
        local ping_class="status-${ping_status,,}"
        echo "            <div class=\"metric\"><span>${name}:</span><span class=\"${ping_class}\">${ping_status}</span></div>" >> ${html_file}
    done

    cat >> ${html_file} <<EOF
        </div>
    </div>
</body>
</html>
EOF

    log "INFO" "HTML dashboard saved to: ${html_file}"
}

# Main execution
main() {
    log "START" "Service Connectivity Matrix Validation"

    # Run network tests
    test_network
    test_dns
    test_kubernetes

    # Test all service endpoints
    echo -e "\n${BLUE}Testing Service Endpoints${NC}"
    for name in "${!SERVICES[@]}"; do
        test_endpoint "$name" "${SERVICES[$name]}"
    done

    # Generate reports
    generate_matrix
    generate_json_report
    generate_html_dashboard

    # Summary
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN} Connectivity Test Complete${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    local total=${#SERVICES[@]}
    local passed=$(echo ${RESULTS[@]} | grep -o "PASS" | wc -l)
    local failed=$(echo ${RESULTS[@]} | grep -o "FAIL" | wc -l)

    echo "Summary:"
    echo "• Total endpoints tested: ${total}"
    echo "• Passed: ${passed}"
    echo "• Failed: ${failed}"
    echo "• Report directory: ${REPORT_DIR}"
    echo ""
    echo "View results:"
    echo "• Dashboard: file://${PWD}/${REPORT_DIR}/dashboard.html"
    echo "• JSON: ${REPORT_DIR}/connectivity-matrix.json"
    echo "• Logs: ${REPORT_DIR}/connectivity.log"

    # Exit code based on failures
    [ ${failed} -eq 0 ] && exit 0 || exit 1
}

# Run main
main "$@"