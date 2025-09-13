#!/bin/bash
# VM-1 → VM-2 Connectivity Health Check (Reference for VM-1)
# This script should be placed on VM-1 to check VM-2 connectivity
# Location: VM-1:~/bin/check-vm2.sh

set -euo pipefail

# Configuration
VM2_IP="172.16.4.45"
VM2_NAME="VM-2 (Edge)"
K8S_API_PORT="6443"
O2IMS_PORT="31280"
HTTP_PORT="31080"
HTTPS_PORT="31443"
PING_COUNT=3
TIMEOUT=5
LOG_FILE="/var/log/vm-connectivity-check.log"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_PING_FAILED=1
EXIT_PORT_FAILED=2
EXIT_MULTIPLE_FAILED=3

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    if [ -t 1 ]; then  # Check if running in terminal
        case $level in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
            SUCCESS) echo -e "${GREEN}[OK]${NC} $message" ;;
            WARNING) echo -e "${YELLOW}[WARN]${NC} $message" ;;
            INFO)    echo -e "[INFO] $message" ;;
        esac
    fi
}

# Initialize
FAILURES=0
CHECKS_PASSED=0
CHECKS_TOTAL=0

log_message "INFO" "=== Starting VM-2 Connectivity Check from VM-1 ==="
log_message "INFO" "Target: $VM2_NAME ($VM2_IP)"

# Check 1: Ping test
echo -n "1. Checking ICMP ping to $VM2_IP... "
((CHECKS_TOTAL++))
if ping -c $PING_COUNT -W $TIMEOUT $VM2_IP > /dev/null 2>&1; then
    log_message "SUCCESS" "Ping to $VM2_IP successful"
    ((CHECKS_PASSED++))
else
    log_message "ERROR" "Ping to $VM2_IP failed"
    ((FAILURES++))
fi

# Check 2: Kubernetes API port
echo -n "2. Checking Kubernetes API on $VM2_IP:$K8S_API_PORT... "
((CHECKS_TOTAL++))
if nc -z -w $TIMEOUT $VM2_IP $K8S_API_PORT 2>/dev/null; then
    log_message "SUCCESS" "Port $K8S_API_PORT (Kubernetes API) is open"
    ((CHECKS_PASSED++))
else
    log_message "ERROR" "Port $K8S_API_PORT (Kubernetes API) is closed or unreachable"
    ((FAILURES++))
fi

# Check 3: O2IMS API port
echo -n "3. Checking O2IMS API on $VM2_IP:$O2IMS_PORT... "
((CHECKS_TOTAL++))
if nc -z -w $TIMEOUT $VM2_IP $O2IMS_PORT 2>/dev/null; then
    log_message "SUCCESS" "Port $O2IMS_PORT (O2IMS API) is open"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "Port $O2IMS_PORT (O2IMS API) is closed or unreachable"
    ((FAILURES++))
fi

# Check 4: HTTP NodePort
echo -n "4. Checking HTTP NodePort on $VM2_IP:$HTTP_PORT... "
((CHECKS_TOTAL++))
if nc -z -w $TIMEOUT $VM2_IP $HTTP_PORT 2>/dev/null; then
    log_message "SUCCESS" "Port $HTTP_PORT (HTTP NodePort) is open"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "Port $HTTP_PORT (HTTP NodePort) is closed or unreachable"
    ((FAILURES++))
fi

# Check 5: HTTPS NodePort
echo -n "5. Checking HTTPS NodePort on $VM2_IP:$HTTPS_PORT... "
((CHECKS_TOTAL++))
if nc -z -w $TIMEOUT $VM2_IP $HTTPS_PORT 2>/dev/null; then
    log_message "SUCCESS" "Port $HTTPS_PORT (HTTPS NodePort) is open"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "Port $HTTPS_PORT (HTTPS NodePort) is closed or unreachable"
    ((FAILURES++))
fi

# Check 6: Kubernetes API health
echo -n "6. Checking Kubernetes API health... "
((CHECKS_TOTAL++))
if curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "https://$VM2_IP:$K8S_API_PORT/healthz" | grep -q "200\|401"; then
    log_message "SUCCESS" "Kubernetes API is responding"
    ((CHECKS_PASSED++))
else
    log_message "ERROR" "Kubernetes API is not responding properly"
    ((FAILURES++))
fi

# Check 7: O2IMS service health
echo -n "7. Checking O2IMS service health... "
((CHECKS_TOTAL++))
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "http://$VM2_IP:$O2IMS_PORT" | grep -q "200\|404"; then
    log_message "SUCCESS" "O2IMS service is responding"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "O2IMS service might not be responding"
    ((FAILURES++))
fi

# Summary
echo ""
log_message "INFO" "=== Connectivity Check Summary ==="
log_message "INFO" "Checks Passed: $CHECKS_PASSED/$CHECKS_TOTAL"

if [ $FAILURES -eq 0 ]; then
    log_message "SUCCESS" "All connectivity checks passed!"
    echo -e "${GREEN}✓ VM-2 connectivity check PASSED${NC}"
    exit $EXIT_SUCCESS
elif [ $FAILURES -eq 1 ]; then
    log_message "WARNING" "1 connectivity check failed"
    echo -e "${YELLOW}⚠ VM-2 connectivity check completed with warnings${NC}"
    exit $EXIT_PORT_FAILED
else
    log_message "ERROR" "$FAILURES connectivity checks failed"
    echo -e "${RED}✗ VM-2 connectivity check FAILED${NC}"
    exit $EXIT_MULTIPLE_FAILED
fi