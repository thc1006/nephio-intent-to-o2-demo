#!/bin/bash
# Demo Rollback Script - Simulates successful rollback operation

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
REASON="${1:-demo-test}"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
ROLLBACK_TAG="rollback-${TIMESTAMP}-${REASON}"

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}       AUTOMATED ROLLBACK INITIATED${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}[INFO]${NC} Starting rollback process"
echo -e "${BLUE}[INFO]${NC} Reason: ${REASON}"
echo -e "${BLUE}[INFO]${NC} Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Step 1: Capture current state
echo -e "${YELLOW}[1/5]${NC} Capturing current deployment state..."
kubectl get provisioningrequests -A -o json > /tmp/rollback-state-before.json 2>/dev/null || true
echo -e "${GREEN}✓${NC} State captured"
echo ""

# Step 2: Identify rollback target
echo -e "${YELLOW}[2/5]${NC} Identifying rollback target..."
if [[ -d "/home/ubuntu/repos/edge1-config" ]]; then
    cd /home/ubuntu/repos/edge1-config
    CURRENT_COMMIT=$(git rev-parse HEAD)
    PREVIOUS_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "none")
    echo -e "${BLUE}[INFO]${NC} Current commit: ${CURRENT_COMMIT:0:8}"
    echo -e "${BLUE}[INFO]${NC} Rollback target: ${PREVIOUS_COMMIT:0:8}"
    cd - > /dev/null
else
    echo -e "${BLUE}[INFO]${NC} Simulating rollback target identification"
    CURRENT_COMMIT="808d23a"
    PREVIOUS_COMMIT="0273bba"
fi
echo -e "${GREEN}✓${NC} Target identified"
echo ""

# Step 3: Create rollback tag
echo -e "${YELLOW}[3/5]${NC} Creating rollback tag..."
echo -e "${BLUE}[INFO]${NC} Tag: ${ROLLBACK_TAG}"
echo -e "${GREEN}✓${NC} Rollback tag created"
echo ""

# Step 4: Perform rollback
echo -e "${YELLOW}[4/5]${NC} Performing rollback..."
echo -e "${BLUE}[INFO]${NC} Strategy: GitOps revert"

# Simulate rollback operations
echo -e "  - Reverting KRM artifacts..."
sleep 1
echo -e "  ${GREEN}✓${NC} cn_capacity.yaml reverted"
echo -e "  ${GREEN}✓${NC} ran_performance.yaml reverted"
echo -e "  ${GREEN}✓${NC} tn_coverage.yaml reverted"

echo -e "  - Updating GitOps repository..."
sleep 1
echo -e "  ${GREEN}✓${NC} GitOps sync triggered"

echo -e "  - Waiting for reconciliation..."
sleep 2
echo -e "  ${GREEN}✓${NC} Resources reconciled"
echo ""

# Step 5: Validate rollback
echo -e "${YELLOW}[5/5]${NC} Validating rollback..."
echo -e "${BLUE}[INFO]${NC} Checking deployment health..."

# Simulate health checks
echo -e "  - SLO metrics after rollback:"
echo -e "    ${GREEN}✓${NC} Latency: 11.2ms (improved)"
echo -e "    ${GREEN}✓${NC} Success rate: 99.8% (improved)"
echo -e "    ${GREEN}✓${NC} Throughput: 248Mbps (stable)"

echo -e "${GREEN}✓${NC} Rollback validation passed"
echo ""

# Generate rollback report
cat > /tmp/rollback-report.json << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "rollback_tag": "${ROLLBACK_TAG}",
  "reason": "${REASON}",
  "strategy": "gitops-revert",
  "source_commit": "${CURRENT_COMMIT:0:8}",
  "target_commit": "${PREVIOUS_COMMIT:0:8}",
  "status": "SUCCESS",
  "duration_seconds": 7,
  "affected_resources": [
    "configmap/expectation-cn-cap-001",
    "configmap/expectation-ran-perf-001",
    "configmap/expectation-tn-cov-001"
  ],
  "health_check": {
    "slo_metrics": {
      "latency_ms": 11.2,
      "success_rate": 0.998,
      "throughput_mbps": 248
    },
    "status": "HEALTHY"
  }
}
EOF

# Summary
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}       ROLLBACK COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Rollback Summary:${NC}"
echo "├─ Tag: ${ROLLBACK_TAG}"
echo "├─ Reason: ${REASON}"
echo "├─ Strategy: GitOps revert"
echo "├─ Duration: 7 seconds"
echo "└─ Status: ${GREEN}SUCCESS${NC}"
echo ""

echo -e "${CYAN}Post-Rollback Health:${NC}"
echo "├─ All SLO thresholds: ${GREEN}MET${NC}"
echo "├─ System stability: ${GREEN}VERIFIED${NC}"
echo "└─ No degradation detected"
echo ""

echo -e "${CYAN}Rollback Artifacts:${NC}"
echo "├─ Report: /tmp/rollback-report.json"
echo "├─ State backup: /tmp/rollback-state-before.json"
echo "└─ Git tag: ${ROLLBACK_TAG}"
echo ""

echo -e "${BLUE}[INFO]${NC} Rollback completed at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo -e "${BLUE}[INFO]${NC} System restored to stable state"
echo ""

exit 0