#!/bin/bash

# Simplified Daily CI Smoke Test
# Role: @release-sherpa
# Version: v1.1.2-rc1
# Purpose: Quick daily verification for critical paths

set -euo pipefail

# Configuration
readonly EDGE1_IP="172.16.4.45"
readonly EDGE2_IP="172.16.4.176"
readonly SMO_IP="172.16.0.78"
readonly MGMT_CONTEXT="kind-nephio-demo"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly REPORT_DIR="reports/${TIMESTAMP}"

# Initialize
mkdir -p ${REPORT_DIR}

echo "Daily CI Smoke Test - ${TIMESTAMP}"
echo "=================================="

# Phase 1: Operator Health
echo -e "\n[Phase 1] Operator Health Check"
OPERATOR_READY=$(kubectl --context ${MGMT_CONTEXT} \
    -n nephio-intent-operator-system \
    get deploy nephio-intent-operator-controller-manager \
    -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")

echo "Operator Available: ${OPERATOR_READY}"

# Phase 2: Check Existing CRs
echo -e "\n[Phase 2] IntentDeployment Status"
kubectl --context ${MGMT_CONTEXT} get intentdeployments -o json | \
    jq -r '.items[] | "\(.metadata.name): \(.status.phase // "Unknown")"'

# Phase 3: RootSync Check (if contexts exist)
echo -e "\n[Phase 3] RootSync Status"
for site in edge1 edge2; do
    if kubectl config get-contexts ${site} >/dev/null 2>&1; then
        SYNCED=$(kubectl --context ${site} \
            -n config-management-system \
            get rootsync root-sync \
            -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "N/A")
        echo "${site}: ${SYNCED}"
    else
        echo "${site}: Context not found"
    fi
done

# Phase 4: Quick SLO Probe
echo -e "\n[Phase 4] SLO Quick Check (10s)"
PROBE_SUCCESS=0
PROBE_TOTAL=5

for i in {1..5}; do
    if curl -sS --connect-timeout 2 --max-time 3 \
        http://${EDGE1_IP}:31280/ >/dev/null 2>&1; then
        ((PROBE_SUCCESS++))
    fi
    sleep 2
done

AVAILABILITY=$((PROBE_SUCCESS * 100 / PROBE_TOTAL))
echo "Edge1 Availability: ${AVAILABILITY}%"

# Phase 5: Generate Reports
echo -e "\n[Phase 5] Generating Reports"

# ready.json
cat > ${REPORT_DIR}/ready.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "operator_ready": ${OPERATOR_READY},
  "edge1_availability_pct": ${AVAILABILITY},
  "duration_seconds": ${SECONDS}
}
EOF

# slo.json
cat > ${REPORT_DIR}/slo.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "probes": ${PROBE_TOTAL},
  "successful": ${PROBE_SUCCESS},
  "availability_pct": ${AVAILABILITY},
  "slo_target": 99.9,
  "compliant": $([ ${AVAILABILITY} -ge 90 ] && echo "true" || echo "false")
}
EOF

# manifest.json
cat > ${REPORT_DIR}/manifest.json <<EOF
{
  "smoke_test": "simplified",
  "version": "v1.1.2-rc1",
  "timestamp": "${TIMESTAMP}",
  "report_dir": "${REPORT_DIR}",
  "files": ["ready.json", "slo.json"]
}
EOF

# Generate SHA256 checksums
sha256sum ${REPORT_DIR}/*.json > ${REPORT_DIR}/SHA256SUMS

# Summary
echo -e "\n=================================="
echo "Summary:"
echo "- Operator Ready: ${OPERATOR_READY}"
echo "- Edge1 Available: ${AVAILABILITY}%"
echo "- Report: ${REPORT_DIR}"
echo "- Duration: ${SECONDS}s"

# Exit status
if [ "${OPERATOR_READY}" = "True" ] && [ ${AVAILABILITY} -ge 80 ]; then
    echo -e "\n✓ Smoke Test PASSED"
    exit 0
else
    echo -e "\n✗ Smoke Test FAILED"
    exit 1
fi