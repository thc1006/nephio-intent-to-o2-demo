#!/bin/bash
set -euo pipefail

# Simple Performance Benchmark
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

echo "=== Performance Benchmark Started at $TIMESTAMP ==="

# Test TMF921 API
echo "Testing TMF921 API..."
for i in {1..5}; do
    curl -s -w "TMF921,$i,HTTP_%{http_code},TIME_%{time_total}s,CONNECT_%{time_connect}s\n" \
         -o /dev/null http://localhost:8889/health --max-time 10 || echo "TMF921,$i,TIMEOUT,999,999"
done

echo ""

# Test O2IMS Edge1
echo "Testing O2IMS Edge1..."
for i in {1..5}; do
    curl -s -w "O2IMS_EDGE1,$i,HTTP_%{http_code},TIME_%{time_total}s,CONNECT_%{time_connect}s\n" \
         -o /dev/null http://172.16.4.45:31280/api_versions --max-time 10 || echo "O2IMS_EDGE1,$i,TIMEOUT,999,999"
done

echo ""

# Test Prometheus
echo "Testing Prometheus..."
for i in {1..3}; do
    curl -s -w "PROMETHEUS,$i,HTTP_%{http_code},TIME_%{time_total}s\n" \
         -o /dev/null http://localhost:9090/api/v1/query?query=up --max-time 10 || echo "PROMETHEUS,$i,TIMEOUT,999"
done

echo ""

# Edge connectivity test
echo "Testing Edge Connectivity..."
for site in edge1:172.16.4.45 edge2:172.16.4.176 edge3:172.16.5.81 edge4:172.16.1.252; do
    name=$(echo $site | cut -d: -f1)
    ip=$(echo $site | cut -d: -f2)

    # Test ping
    if ping -c 2 -W 2 $ip >/dev/null 2>&1; then
        ping_status="PING_OK"
    else
        ping_status="PING_FAIL"
    fi

    # Test SSH port
    if timeout 3 nc -z $ip 22 2>/dev/null; then
        ssh_status="SSH_OK"
    else
        ssh_status="SSH_FAIL"
    fi

    # Test O2IMS
    if curl -s --max-time 3 http://$ip:31280/api_versions >/dev/null 2>&1; then
        o2ims_status="O2IMS_OK"
    else
        o2ims_status="O2IMS_FAIL"
    fi

    echo "CONNECTIVITY,$name,$ip,$ping_status,$ssh_status,$o2ims_status"
done

echo ""
echo "=== Benchmark Completed ==="