#!/bin/bash
#
# Quick demo of multi-site GitOps routing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         MULTI-SITE GITOPS ROUTING DEMO                    ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Step 1: Show GitOps structure
echo -e "${BOLD}${BLUE}1. GitOps Directory Structure:${NC}"
tree -L 2 "$PROJECT_ROOT/gitops" 2>/dev/null || {
    echo "gitops/"
    echo "├── edge1-config/"
    echo "│   ├── baseline/"
    echo "│   ├── services/"
    echo "│   ├── network-functions/"
    echo "│   └── monitoring/"
    echo "└── edge2-config/"
    echo "    ├── baseline/"
    echo "    ├── services/"
    echo "    ├── network-functions/"
    echo "    └── monitoring/"
}
echo

# Step 2: Demo edge1 routing
echo -e "${BOLD}${BLUE}2. Routing Intent to Edge1:${NC}"
cat > /tmp/demo-intent-edge1.json <<EOF
{
  "intentExpectationId": "demo-edge1-$(date +%s)",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "edge1",
  "intent": {
    "serviceType": "eMBB",
    "networkSlice": {"sliceId": "demo-slice-edge1"},
    "qos": {"downlinkThroughput": "1Gbps", "latency": "20ms"}
  }
}
EOF

echo "   Intent: eMBB service for edge1 (1Gbps, 20ms latency)"
"$PROJECT_ROOT/scripts/render_krm.sh" \
    --intent /tmp/demo-intent-edge1.json \
    --output-dir /tmp/demo-gitops \
    --force 2>&1 | grep -E "(Rendering|SUCCESS)" | sed 's/^/   /'
echo

# Step 3: Demo edge2 routing
echo -e "${BOLD}${BLUE}3. Routing Intent to Edge2:${NC}"
cat > /tmp/demo-intent-edge2.json <<EOF
{
  "intentExpectationId": "demo-edge2-$(date +%s)",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "edge2",
  "intent": {
    "serviceType": "URLLC",
    "networkSlice": {"sliceId": "demo-slice-edge2"},
    "qos": {"downlinkThroughput": "500Mbps", "latency": "1ms"}
  }
}
EOF

echo "   Intent: URLLC service for edge2 (500Mbps, 1ms latency)"
"$PROJECT_ROOT/scripts/render_krm.sh" \
    --intent /tmp/demo-intent-edge2.json \
    --output-dir /tmp/demo-gitops \
    --force 2>&1 | grep -E "(Rendering|SUCCESS)" | sed 's/^/   /'
echo

# Step 4: Demo both sites routing
echo -e "${BOLD}${BLUE}4. Routing Intent to Both Sites:${NC}"
cat > /tmp/demo-intent-both.json <<EOF
{
  "intentExpectationId": "demo-both-$(date +%s)",
  "intentExpectationType": "NetworkSliceIntent",
  "targetSite": "both",
  "intent": {
    "serviceType": "mMTC",
    "networkSlice": {"sliceId": "demo-slice-both"},
    "qos": {"downlinkThroughput": "100Mbps", "latency": "100ms"}
  }
}
EOF

echo "   Intent: mMTC service for both sites (100Mbps, 100ms latency)"
"$PROJECT_ROOT/scripts/render_krm.sh" \
    --intent /tmp/demo-intent-both.json \
    --output-dir /tmp/demo-gitops \
    --force 2>&1 | grep -E "(Rendering|SUCCESS|both)" | sed 's/^/   /'
echo

# Step 5: Show generated files
echo -e "${BOLD}${BLUE}5. Generated KRM Manifests:${NC}"
echo "   Edge1 manifests:"
find /tmp/demo-gitops/edge1-config -name "*.yaml" -type f 2>/dev/null | head -3 | while read -r file; do
    echo "   - $(basename "$file")"
done

echo "   Edge2 manifests:"
find /tmp/demo-gitops/edge2-config -name "*.yaml" -type f 2>/dev/null | head -3 | while read -r file; do
    echo "   - $(basename "$file")"
done
echo

# Step 6: Sample manifest content
echo -e "${BOLD}${BLUE}6. Sample Manifest Content (NetworkSlice):${NC}"
manifest=$(find /tmp/demo-gitops/edge1-config/services -name "*.yaml" -type f 2>/dev/null | head -1)
if [[ -f "$manifest" ]]; then
    head -20 "$manifest" | sed 's/^/   /'
fi
echo

# Step 7: demo_llm.sh integration
echo -e "${BOLD}${BLUE}7. demo_llm.sh Integration:${NC}"
echo "   Available commands:"
echo -e "   ${GREEN}./scripts/demo_llm.sh --target edge1${NC}    # Deploy to edge1 only"
echo -e "   ${GREEN}./scripts/demo_llm.sh --target edge2 --vm4-ip <IP>${NC}    # Deploy to edge2"
echo -e "   ${GREEN}./scripts/demo_llm.sh --target both --vm4-ip <IP>${NC}     # Deploy to both"
echo -e "   ${GREEN}./scripts/demo_llm.sh --rollback --target edge1${NC}       # Rollback edge1"
echo

# Cleanup
rm -rf /tmp/demo-intent-*.json /tmp/demo-gitops 2>/dev/null || true

echo -e "${BOLD}${GREEN}✓ Multi-Site GitOps Routing Demo Complete!${NC}"
echo
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Update VM-4 IP in gitops/edge2-config/rootsync.yaml after deployment"
echo "2. Apply RootSync to clusters: kubectl apply -f gitops/<site>-config/rootsync.yaml"
echo "3. Monitor sync status: kubectl get rootsync -n config-management-system"
echo "4. Run full pipeline: ./scripts/demo_llm.sh --target both --vm4-ip <IP>"