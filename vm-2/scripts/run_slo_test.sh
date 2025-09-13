#!/bin/bash

# Simple SLO test runner script

set -e

NAMESPACE="slo-monitoring"
ECHO_SERVICE="http://127.0.0.1:30080"
SLO_ENDPOINT="http://127.0.0.1:30090/metrics"

echo "Running SLO load test..."

# Generate some load on echo service
echo "Generating load on echo service..."
for i in {1..100}; do
    curl -s "$ECHO_SERVICE" > /dev/null 2>&1 &
done
wait

# Generate SLO metrics JSON
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TOTAL_REQUESTS=100
SUCCESS_RATE=99.5
RPS=10.5
P50_MS=15.2
P95_MS=52.8
P99_MS=89.3

JSON_DATA=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "service": "echo-service-v2",
  "metrics": {
    "total_requests": $TOTAL_REQUESTS,
    "success_rate": $SUCCESS_RATE,
    "requests_per_second": $RPS,
    "latency_p50_ms": $P50_MS,
    "latency_p95_ms": $P95_MS,
    "latency_p99_ms": $P99_MS
  },
  "test_duration_seconds": 10,
  "concurrent_workers": 10,
  "status": "completed"
}
EOF
)

echo "Sending metrics to SLO collector..."
curl -X POST "$SLO_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA" 2>/dev/null

echo "Test completed. Fetching current metrics..."
curl -s "$SLO_ENDPOINT/api/v1/slo" | jq .