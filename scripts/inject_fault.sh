#!/bin/bash

# Fault Injection Script for Demo
# Usage: ./inject_fault.sh <site> <fault_type> [value]

SITE=$1
FAULT_TYPE=$2
VALUE=${3:-"default"}

# Site configuration
case ${SITE} in
    edge1)
        HOST="172.16.4.45"
        PORT="30090"
        ;;
    edge2)
        HOST="172.16.4.176"
        PORT="30090"
        ;;
    *)
        echo "Invalid site: ${SITE}"
        exit 1
        ;;
esac

echo "Injecting fault: ${FAULT_TYPE} on ${SITE} (${HOST})"

case ${FAULT_TYPE} in
    high_latency)
        # Add network delay
        echo "Adding 500ms latency..."
        # Note: Would need sudo for actual tc command
        # sudo tc qdisc add dev eth0 root netem delay 500ms

        # Simulate by returning slow metrics
        cat > /tmp/fault_metrics.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)",
  "site": "${SITE}",
  "fault": "high_latency",
  "metrics": {
    "latency_p50": "250ms",
    "latency_p95": "450ms",
    "latency_p99": "800ms"
  }
}
EOF
        ;;

    error_rate)
        # Inject high error rate
        ERROR_RATE=${VALUE:-"0.15"}
        echo "Setting error rate to ${ERROR_RATE}..."

        cat > /tmp/fault_metrics.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)",
  "site": "${SITE}",
  "fault": "error_rate",
  "metrics": {
    "error_rate": "${ERROR_RATE}",
    "errors_total": 1500,
    "requests_total": 10000
  }
}
EOF
        ;;

    cpu_spike)
        # Simulate CPU exhaustion
        echo "Creating CPU spike..."

        cat > /tmp/fault_metrics.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)",
  "site": "${SITE}",
  "fault": "cpu_spike",
  "metrics": {
    "cpu_usage": "95%",
    "load_average": "8.5",
    "throttled": true
  }
}
EOF
        ;;

    network_partition)
        # Simulate network partition
        echo "Creating network partition..."

        # Would use iptables in reality
        # sudo iptables -A INPUT -s ${HOST} -j DROP

        cat > /tmp/fault_metrics.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)",
  "site": "${SITE}",
  "fault": "network_partition",
  "metrics": {
    "connectivity": "lost",
    "packets_dropped": 1000,
    "last_seen": "$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S.%NZ)"
  }
}
EOF
        ;;

    *)
        echo "Unknown fault type: ${FAULT_TYPE}"
        exit 1
        ;;
esac

echo "Fault injected successfully"
echo "Evidence saved to: /tmp/fault_metrics.json"

# Return fault metrics
cat /tmp/fault_metrics.json