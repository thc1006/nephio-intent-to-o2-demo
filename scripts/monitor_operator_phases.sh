#!/bin/bash

# Monitor Operator Phase Transitions
# Purpose: Monitor IntentDeployment CRD phase transitions in real-time
# 用途：即時監控 IntentDeployment CRD 的階段轉換

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     Operator Phase Monitoring Dashboard${NC}"
echo -e "${BLUE}     操作器階段監控儀表板${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if CRD exists
if ! kubectl get crd intentdeployments.tna.tna.ai &>/dev/null; then
    echo -e "${YELLOW}[Warning] IntentDeployment CRD not found. Creating mock data...${NC}"
    # Create mock status for demo
    echo -e "${GREEN}Mock Status:${NC}"
    echo "  edge1-deployment: Phase=Provisioning → Active"
    echo "  edge2-deployment: Phase=Provisioning → Active"
    echo "  both-sites-deployment: Phase=Provisioning → Active"
    sleep 2
    exit 0
fi

# Monitor function
monitor_phases() {
    local DURATION=${1:-30}
    local INTERVAL=2
    local COUNT=0
    local MAX_COUNT=$((DURATION / INTERVAL))

    echo -e "${GREEN}Monitoring IntentDeployment phases for ${DURATION} seconds...${NC}"
    echo -e "${GREEN}監控 IntentDeployment 階段 ${DURATION} 秒...${NC}"
    echo ""

    while [ $COUNT -lt $MAX_COUNT ]; do
        clear
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}     Phase Status @ $(date +%H:%M:%S)${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo ""

        # Get all IntentDeployments
        DEPLOYMENTS=$(kubectl get intentdeployments -o json 2>/dev/null | jq -r '.items[]?.metadata.name' || echo "")

        if [ -z "$DEPLOYMENTS" ]; then
            echo -e "${YELLOW}No IntentDeployments found. Showing simulated data...${NC}"

            # Simulate phase transitions
            if [ $COUNT -lt 3 ]; then
                PHASE="Initializing"
                STATUS="🔄"
            elif [ $COUNT -lt 6 ]; then
                PHASE="Provisioning"
                STATUS="⚙️"
            elif [ $COUNT -lt 9 ]; then
                PHASE="Configuring"
                STATUS="🔧"
            else
                PHASE="Active"
                STATUS="✅"
            fi

            echo -e "┌────────────────────────┬──────────────┬─────────┐"
            echo -e "│ Deployment             │ Phase        │ Status  │"
            echo -e "├────────────────────────┼──────────────┼─────────┤"
            echo -e "│ edge1-deployment       │ $PHASE       │ $STATUS │"
            echo -e "│ edge2-deployment       │ $PHASE       │ $STATUS │"
            echo -e "│ both-sites-deployment  │ $PHASE       │ $STATUS │"
            echo -e "└────────────────────────┴──────────────┴─────────┘"
        else
            echo -e "┌────────────────────────┬──────────────┬─────────┬────────────┐"
            echo -e "│ Deployment             │ Phase        │ Ready   │ Message    │"
            echo -e "├────────────────────────┼──────────────┼─────────┼────────────┤"

            for DEPLOYMENT in $DEPLOYMENTS; do
                # Get phase and status
                PHASE=$(kubectl get intentdeployment $DEPLOYMENT -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
                READY=$(kubectl get intentdeployment $DEPLOYMENT -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
                MESSAGE=$(kubectl get intentdeployment $DEPLOYMENT -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "-")

                # Determine status icon
                case $PHASE in
                    "Active"|"Ready")
                        STATUS_ICON="✅"
                        ;;
                    "Failed"|"Error")
                        STATUS_ICON="❌"
                        ;;
                    "Provisioning"|"Configuring")
                        STATUS_ICON="⚙️"
                        ;;
                    *)
                        STATUS_ICON="🔄"
                        ;;
                esac

                printf "│ %-22s │ %-12s │ %-7s │ %-10s │\n" \
                    "$DEPLOYMENT" "$PHASE $STATUS_ICON" "$READY" "${MESSAGE:0:10}"
            done

            echo -e "└────────────────────────┴──────────────┴─────────┴────────────┘"
        fi

        echo ""
        echo -e "${BLUE}Phase Transitions:${NC}"
        echo "  🔄 Initializing → ⚙️ Provisioning → 🔧 Configuring → ✅ Active"
        echo ""
        echo -e "${YELLOW}Progress: [$((COUNT+1))/$MAX_COUNT]${NC}"

        COUNT=$((COUNT + 1))
        sleep $INTERVAL
    done

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     Monitoring Complete / 監控完成${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

# Main execution
monitor_phases 30

# Final status check
echo ""
echo -e "${BLUE}Final Status Summary:${NC}"
echo -e "${BLUE}最終狀態摘要:${NC}"
echo ""

kubectl get intentdeployments -o wide 2>/dev/null || {
    echo -e "${GREEN}Simulated Final Status:${NC}"
    echo "  ✅ edge1-deployment: Active (Ready)"
    echo "  ✅ edge2-deployment: Active (Ready)"
    echo "  ✅ both-sites-deployment: Active (Ready)"
}