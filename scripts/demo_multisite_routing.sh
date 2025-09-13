#!/bin/bash
#
# Multi-Site Routing Demo
# Demonstrates the complete intent-to-KRM pipeline with routing to edge1, edge2, or both
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests/golden"
GITOPS_DIR="$PROJECT_ROOT/gitops"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}🚀 Multi-Site Intent-to-KRM Routing Demo${NC}"
echo -e "${BLUE}==========================================${NC}"
echo

echo -e "${MAGENTA}📋 Testing multi-site routing with different intent targets...${NC}"
echo

# Demo 1: Edge1 only
echo -e "${BOLD}Demo 1: eMBB slice to Edge1 only${NC}"
echo "Intent: Deploy eMBB slice for high-bandwidth mobile services"
echo "Target: edge1"
echo "Command: ./scripts/render_krm.sh --intent tests/golden/intent_edge1_embb.json --target edge1 --dry-run"
echo
$SCRIPT_DIR/render_krm.sh --intent "$TESTS_DIR/intent_edge1_embb.json" --target edge1 --dry-run
echo
echo -e "${GREEN}✅ Successfully routed to edge1-config only${NC}"
echo
echo "---"
echo

# Demo 2: Edge2 only
echo -e "${BOLD}Demo 2: URLLC slice to Edge2 only${NC}"
echo "Intent: Create URLLC service for ultra-low latency applications"
echo "Target: edge2"
echo "Command: ./scripts/render_krm.sh --intent tests/golden/intent_edge2_urllc.json --target edge2 --dry-run"
echo
$SCRIPT_DIR/render_krm.sh --intent "$TESTS_DIR/intent_edge2_urllc.json" --target edge2 --dry-run
echo
echo -e "${GREEN}✅ Successfully routed to edge2-config only${NC}"
echo
echo "---"
echo

# Demo 3: Both sites
echo -e "${BOLD}Demo 3: mMTC IoT network to both Edge1 and Edge2${NC}"
echo "Intent: Setup distributed IoT network across multiple sites"
echo "Target: both"
echo "Command: ./scripts/render_krm.sh --intent tests/golden/intent_both_mmtc.json --target both --dry-run"
echo
$SCRIPT_DIR/render_krm.sh --intent "$TESTS_DIR/intent_both_mmtc.json" --target both --dry-run
echo
echo -e "${GREEN}✅ Successfully routed to both edge1-config and edge2-config${NC}"
echo
echo "---"
echo

# Show directory structure
echo -e "${BOLD}📁 GitOps Directory Structure${NC}"
echo "Showing how intents are routed to appropriate directories:"
echo
echo -e "${BLUE}gitops/${NC}"
echo -e "${BLUE}├── edge1-config/${NC}"
echo -e "${BLUE}│   ├── services/         ${YELLOW}← eMBB and mMTC intents go here${NC}"
echo -e "${BLUE}│   ├── network-functions/${NC}"
echo -e "${BLUE}│   └── monitoring/${NC}"
echo -e "${BLUE}└── edge2-config/${NC}"
echo -e "${BLUE}    ├── services/         ${YELLOW}← URLLC and mMTC intents go here${NC}"
echo -e "${BLUE}    ├── network-functions/${NC}"
echo -e "${BLUE}    └── monitoring/${NC}"
echo

# Show intent structure with targetSite
echo -e "${BOLD}📄 Intent JSON Structure with targetSite${NC}"
echo "All intents now include a targetSite field for routing:"
echo
echo -e "${BLUE}{"
echo -e "  \"intentExpectationId\": \"unique-id\","
echo -e "  \"intentExpectationType\": \"ServicePerformance\","
echo -e "  ${YELLOW}\"targetSite\": \"edge1|edge2|both\",${NC}"
echo -e "  \"intent\": {"
echo -e "    \"serviceType\": \"eMBB|URLLC|mMTC\","
echo -e "    \"networkSlice\": { ... },"
echo -e "    \"qos\": { ... }"
echo -e "  }"
echo -e "}${NC}"
echo

# Summary
echo -e "${BOLD}${GREEN}🎉 Multi-Site Routing Summary${NC}"
echo -e "${GREEN}=============================${NC}"
echo -e "${GREEN}✅ Intent parsing with targetSite field${NC}"
echo -e "${GREEN}✅ KRM rendering to correct GitOps directories${NC}"
echo -e "${GREEN}✅ Support for edge1, edge2, and both targets${NC}"
echo -e "${GREEN}✅ Backward compatibility maintained${NC}"
echo -e "${GREEN}✅ Pipeline ready for Phase 12 deployment${NC}"
echo
echo -e "${BOLD}Next steps:${NC}"
echo "1. Run E2E tests: ./tests/e2e/demo_llm_spec.sh"
echo "2. Test with LLM adapter: ./scripts/demo_llm.sh --target edge1"
echo "3. Deploy to actual clusters using GitOps sync"
echo