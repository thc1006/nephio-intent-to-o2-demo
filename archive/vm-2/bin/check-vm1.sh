#!/bin/bash
# VM-2 → VM-1 Connectivity Health Check
# Checks connectivity from VM-2 (Edge) to VM-1 (SMO)

set -euo pipefail

# Configuration
VM1_IP="172.16.0.78"
VM1_NAME="VM-1 (SMO)"
GITEA_PORT_1="3000"
GITEA_PORT_2="8888"
GITEA_EXTERNAL="147.251.115.143"
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

log_message "INFO" "=== Starting VM-1 Connectivity Check from VM-2 ==="
log_message "INFO" "Target: $VM1_NAME ($VM1_IP)"

# Check 1: Ping test
echo -n "1. Checking ICMP ping to $VM1_IP... "
((CHECKS_TOTAL++))
if ping -c $PING_COUNT -W $TIMEOUT $VM1_IP > /dev/null 2>&1; then
    log_message "SUCCESS" "Ping to $VM1_IP successful"
    ((CHECKS_PASSED++))
else
    log_message "ERROR" "Ping to $VM1_IP failed"
    ((FAILURES++))
fi

# Check 2: Gitea on port 3000
echo -n "2. Checking Gitea on $VM1_IP:$GITEA_PORT_1... "
((CHECKS_TOTAL++))
if nc -z -w $TIMEOUT $VM1_IP $GITEA_PORT_1 2>/dev/null; then
    log_message "SUCCESS" "Port $GITEA_PORT_1 (Gitea internal) is open"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "Port $GITEA_PORT_1 (Gitea internal) is closed or unreachable"
    ((FAILURES++))
fi

# Check 3: External Gitea access
echo -n "3. Checking external Gitea on $GITEA_EXTERNAL:$GITEA_PORT_2... "
((CHECKS_TOTAL++))
if nc -z -w $TIMEOUT $GITEA_EXTERNAL $GITEA_PORT_2 2>/dev/null; then
    log_message "SUCCESS" "Port $GITEA_PORT_2 (Gitea external) is open"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "Port $GITEA_PORT_2 (Gitea external) is closed or unreachable"
    ((FAILURES++))
fi

# Check 4: HTTP connectivity to Gitea
echo -n "4. Checking HTTP response from Gitea... "
((CHECKS_TOTAL++))
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "http://$GITEA_EXTERNAL:$GITEA_PORT_2" | grep -q "200\|301\|302"; then
    log_message "SUCCESS" "Gitea HTTP service is responding"
    ((CHECKS_PASSED++))
else
    log_message "ERROR" "Gitea HTTP service is not responding properly"
    ((FAILURES++))
fi

# Check 5: GitOps repository accessibility
echo -n "5. Checking GitOps repository access... "
((CHECKS_TOTAL++))
REPO_URL="http://$GITEA_EXTERNAL:$GITEA_PORT_2/admin1/edge1-config"
if curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "$REPO_URL" | grep -q "200\|301\|302"; then
    log_message "SUCCESS" "GitOps repository is accessible"
    ((CHECKS_PASSED++))
else
    log_message "WARNING" "GitOps repository might not be accessible"
    ((FAILURES++))
fi

# Summary
echo ""
log_message "INFO" "=== Connectivity Check Summary ==="
log_message "INFO" "Checks Passed: $CHECKS_PASSED/$CHECKS_TOTAL"

if [ $FAILURES -eq 0 ]; then
    log_message "SUCCESS" "All connectivity checks passed!"
    echo -e "${GREEN}✓ VM-1 connectivity check PASSED${NC}"
    exit $EXIT_SUCCESS
elif [ $FAILURES -eq 1 ]; then
    log_message "WARNING" "1 connectivity check failed"
    echo -e "${YELLOW}⚠ VM-1 connectivity check completed with warnings${NC}"
    exit $EXIT_PORT_FAILED
else
    log_message "ERROR" "$FAILURES connectivity checks failed"
    echo -e "${RED}✗ VM-1 connectivity check FAILED${NC}"
    exit $EXIT_MULTIPLE_FAILED
fi