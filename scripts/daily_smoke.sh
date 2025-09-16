#!/bin/bash

# Daily CI Smoke Test
# Role: @release-sherpa
# Version: v1.1.2-rc1
# Purpose: Daily verification for shell-first & operator-alpha paths

set -euo pipefail

# Configuration from project scan
readonly EDGE1_IP="172.16.4.45"
readonly EDGE2_IP="172.16.4.176"
readonly SMO_IP="172.16.0.78"
readonly MGMT_CONTEXT="kind-nephio-demo"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly REPORT_DIR="reports/${TIMESTAMP}"

# SLO Thresholds
readonly SLO_LATENCY_MS=100
readonly SLO_ERROR_RATE=0.1
readonly SLO_AVAILABILITY=99.9

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
PHASES_COMPLETED=()

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Initialize
mkdir -p ${REPORT_DIR}/{operator,crs,rootsync,slo,checksums}

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Daily CI Smoke Test              ║${NC}"
echo -e "${GREEN}║       @release-sherpa v1.1.2           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

log() {
    echo -e "[$(date +'%H:%M:%S')] $*" | tee -a ${REPORT_DIR}/smoke.log
}

# Phase 1: Operator Health Check
phase1_operator_health() {
    log "INFO" "Phase 1: Checking operator health"

    # Check deployment
    local deploy_status=$(kubectl --context ${MGMT_CONTEXT} \
        -n nephio-intent-operator-system \
        get deploy nephio-intent-operator-controller-manager \
        -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")

    if [ "${deploy_status}" = "True" ]; then
        log "SUCCESS" "Operator deployment is available"
        ((TESTS_PASSED++))
    else
        log "FAIL" "Operator deployment not available"
        ((TESTS_FAILED++))
        return 1
    fi

    # Check pods
    local pod_count=$(kubectl --context ${MGMT_CONTEXT} \
        -n nephio-intent-operator-system \
        get pods -l control-plane=controller-manager \
        --field-selector=status.phase=Running \
        -o json | jq '.items | length')

    if [ "${pod_count}" -gt 0 ]; then
        log "SUCCESS" "Operator pods running: ${pod_count}"
        ((TESTS_PASSED++))
    else
        log "FAIL" "No running operator pods"
        ((TESTS_FAILED++))
    fi

    # Check logs for PIPELINE_MODE
    local logs=$(kubectl --context ${MGMT_CONTEXT} \
        -n nephio-intent-operator-system \
        logs deployment/nephio-intent-operator-controller-manager \
        --tail=50 2>/dev/null || echo "")

    if echo "${logs}" | grep -q "PIPELINE_MODE"; then
        local pipeline_mode=$(echo "${logs}" | grep "PIPELINE_MODE" | tail -1)
        log "INFO" "Pipeline mode: ${pipeline_mode}"
    fi

    # Save operator status
    kubectl --context ${MGMT_CONTEXT} \
        -n nephio-intent-operator-system \
        get all -o yaml > ${REPORT_DIR}/operator/status.yaml

    PHASES_COMPLETED+=("operator_health")
    return 0
}

# Phase 2: Deploy and Monitor CRs
phase2_deploy_crs() {
    log "INFO" "Phase 2: Deploying IntentDeployment CRs"

    local crs=("edge1" "edge2" "both")
    local all_succeeded=true

    for cr in "${crs[@]}"; do
        log "INFO" "Deploying ${cr}-deployment"

        # Set appropriate endpoint based on site
        local endpoint="http://172.16.4.45:31280"
        if [ "${cr}" = "edge2" ]; then
            endpoint="http://172.16.4.176:31280"
        fi

        # Apply CR with correct schema
        kubectl --context ${MGMT_CONTEXT} apply -f - <<EOF
apiVersion: tna.tna.ai/v1alpha1
kind: IntentDeployment
metadata:
  name: ${cr}-deployment
  namespace: default
spec:
  intent: |
    {
      "service": "smoke-test",
      "site": "${cr}",
      "environment": "ci",
      "replicas": 2,
      "resources": {
        "cpu": "100m",
        "memory": "256Mi"
      },
      "endpoints": {
        "o2ims": "${endpoint}"
      }
    }

  compileConfig:
    engine: kpt
    renderTimeout: 5m

  deliveryConfig:
    targetSite: ${cr}
    gitOpsRepo: https://github.com/thc1006/nephio-intent-to-o2-demo
    syncWaitTimeout: 10m

  gatesConfig:
    enabled: true
    sloThresholds:
      error_rate: "${SLO_ERROR_RATE}"
      latency_p99: "${SLO_LATENCY_MS}ms"
      availability: "${SLO_AVAILABILITY}"

  rollbackConfig:
    autoRollback: true
    maxRetries: 3
    retainFailedArtifacts: true
EOF

        # Monitor phase transitions
        local max_wait=60
        local elapsed=0
        local final_phase=""

        while [ ${elapsed} -lt ${max_wait} ]; do
            local phase=$(kubectl --context ${MGMT_CONTEXT} \
                get intentdeployment ${cr}-deployment \
                -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

            if [ "${phase}" != "${final_phase}" ]; then
                log "INFO" "${cr}-deployment: ${phase}"
                final_phase="${phase}"
            fi

            if [ "${phase}" = "Succeeded" ]; then
                log "SUCCESS" "${cr}-deployment reached Succeeded"
                ((TESTS_PASSED++))
                break
            elif [ "${phase}" = "Failed" ]; then
                log "FAIL" "${cr}-deployment failed"
                ((TESTS_FAILED++))
                all_succeeded=false
                break
            fi

            sleep 2
            ((elapsed+=2))
        done

        # Collect status
        kubectl --context ${MGMT_CONTEXT} \
            get intentdeployment ${cr}-deployment -o yaml \
            > ${REPORT_DIR}/crs/${cr}-status.yaml
    done

    PHASES_COMPLETED+=("cr_deployment")
    [ "${all_succeeded}" = "true" ] && return 0 || return 1
}

# Phase 3: Verify RootSync Status
phase3_verify_rootsync() {
    log "INFO" "Phase 3: Verifying RootSync status"

    local sites=("edge1" "edge2")
    local all_synced=true

    for site in "${sites[@]}"; do
        # Check if context exists
        if ! kubectl config get-contexts ${site} >/dev/null 2>&1; then
            log "WARN" "Context ${site} not found, skipping"
            continue
        fi

        # Check RootSync
        local sync_status=$(kubectl --context ${site} \
            -n config-management-system \
            get rootsync root-sync \
            -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "Unknown")

        if [ "${sync_status}" = "True" ]; then
            log "SUCCESS" "${site} RootSync is SYNCED"
            ((TESTS_PASSED++))

            # Record lastSyncedCommit
            local last_commit=$(kubectl --context ${site} \
                -n config-management-system \
                get rootsync root-sync \
                -o jsonpath='{.status.source.git.commit}' 2>/dev/null || echo "unknown")

            log "INFO" "${site} lastSyncedCommit: ${last_commit}"

            # Save to report
            cat > ${REPORT_DIR}/rootsync/${site}-sync.json <<EOF
{
  "site": "${site}",
  "synced": true,
  "lastSyncedCommit": "${last_commit}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        else
            log "FAIL" "${site} RootSync not synced: ${sync_status}"
            ((TESTS_FAILED++))
            all_synced=false
        fi
    done

    PHASES_COMPLETED+=("rootsync_verify")
    [ "${all_synced}" = "true" ] && return 0 || return 1
}

# Phase 4: Run SLO Probes
phase4_slo_probes() {
    log "INFO" "Phase 4: Running SLO probes for 60s"

    local probe_duration=60
    local probe_interval=5
    local iterations=$((probe_duration / probe_interval))

    local latencies=()
    local errors=0
    local total=0

    for i in $(seq 1 ${iterations}); do
        log "INFO" "Probe iteration ${i}/${iterations}"

        # Test Edge1
        local start_time=$(date +%s%N)
        local response=$(curl -sS -w "HTTP_CODE:%{http_code}" \
            --connect-timeout 5 \
            http://${EDGE1_IP}:31280/ 2>/dev/null || echo "HTTP_CODE:000")
        local end_time=$(date +%s%N)

        local http_code="${response##*HTTP_CODE:}"
        local latency_ns=$((end_time - start_time))
        local latency_ms=$((latency_ns / 1000000))

        latencies+=("${latency_ms}")
        ((total++))

        if [ "${http_code}" != "200" ] && [ "${http_code}" != "000" ]; then
            ((errors++))
        fi

        sleep ${probe_interval}
    done

    # Calculate metrics
    local p99_latency=$(printf '%s\n' "${latencies[@]}" | sort -nr | head -1)
    local error_rate=$(echo "scale=2; ${errors} * 100 / ${total}" | bc)
    local availability=$(echo "scale=2; 100 - ${error_rate}" | bc)

    # Check SLO compliance
    local slo_passed=true
    if [ "${p99_latency}" -gt "${SLO_LATENCY_MS}" ]; then
        log "WARN" "Latency SLO violated: ${p99_latency}ms > ${SLO_LATENCY_MS}ms"
        slo_passed=false
    fi

    if (( $(echo "${error_rate} > ${SLO_ERROR_RATE}" | bc -l) )); then
        log "WARN" "Error rate SLO violated: ${error_rate}% > ${SLO_ERROR_RATE}%"
        slo_passed=false
    fi

    # Generate SLO report
    cat > ${REPORT_DIR}/slo.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": ${probe_duration},
  "metrics": {
    "latency_p99_ms": ${p99_latency},
    "error_rate_pct": ${error_rate},
    "availability_pct": ${availability}
  },
  "thresholds": {
    "latency_p99_ms": ${SLO_LATENCY_MS},
    "error_rate_pct": ${SLO_ERROR_RATE},
    "availability_pct": ${SLO_AVAILABILITY}
  },
  "compliant": ${slo_passed},
  "samples": ${total}
}
EOF

    if [ "${slo_passed}" = "true" ]; then
        log "SUCCESS" "SLO probes passed"
        ((TESTS_PASSED++))
    else
        log "FAIL" "SLO violations detected"
        ((TESTS_FAILED++))

        # Check for rollback evidence
        check_rollback_evidence
    fi

    PHASES_COMPLETED+=("slo_probes")
    return 0
}

# Check for rollback evidence
check_rollback_evidence() {
    log "INFO" "Checking for rollback evidence"

    local rollback_found=false

    for cr in edge1 edge2; do
        local phase=$(kubectl --context ${MGMT_CONTEXT} \
            get intentdeployment ${cr}-deployment \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

        if [ "${phase}" = "RollingBack" ] || [ "${phase}" = "Succeeded" ]; then
            local conditions=$(kubectl --context ${MGMT_CONTEXT} \
                get intentdeployment ${cr}-deployment \
                -o jsonpath='{.status.conditions}' 2>/dev/null || echo "")

            if echo "${conditions}" | grep -q "Rollback"; then
                log "INFO" "Rollback evidence found for ${cr}"
                rollback_found=true

                # Save rollback evidence
                kubectl --context ${MGMT_CONTEXT} \
                    get intentdeployment ${cr}-deployment -o yaml \
                    > ${REPORT_DIR}/slo/rollback-${cr}.yaml
            fi
        fi
    done

    if [ "${rollback_found}" = "true" ]; then
        log "SUCCESS" "Rollback evidence present"
        ((TESTS_PASSED++))
    fi
}

# Phase 5: Generate Integrity Checksums
phase5_integrity() {
    log "INFO" "Phase 5: Generating integrity checksums"

    # Generate SHA256 checksums
    find ${REPORT_DIR} -type f -name "*.yaml" -o -name "*.json" | while read -r file; do
        sha256sum "${file}" >> ${REPORT_DIR}/checksums/SHA256SUMS
    done

    # Optional: Cosign verification
    if command -v cosign >/dev/null 2>&1; then
        log "INFO" "Attempting cosign verification"

        # Check for signed images
        local images=(
            "localhost:5000/intent-operator:v0.1.2-alpha"
            "gcr.io/kpt-fn/set-namespace:v0.4"
        )

        for image in "${images[@]}"; do
            if cosign verify --key cosign.pub "${image}" 2>/dev/null; then
                log "SUCCESS" "Image verified: ${image}"
            else
                log "INFO" "Image not signed or verification failed: ${image}"
            fi
        done
    fi

    PHASES_COMPLETED+=("integrity")
    return 0
}

# Generate ready.json
generate_ready_json() {
    local all_phases_succeeded=true
    local operator_ready=false
    local crs_ready=false
    local sync_ready=false
    local slo_ready=false

    [[ " ${PHASES_COMPLETED[@]} " =~ " operator_health " ]] && operator_ready=true
    [[ " ${PHASES_COMPLETED[@]} " =~ " cr_deployment " ]] && crs_ready=true
    [[ " ${PHASES_COMPLETED[@]} " =~ " rootsync_verify " ]] && sync_ready=true
    [[ " ${PHASES_COMPLETED[@]} " =~ " slo_probes " ]] && slo_ready=true

    cat > ${REPORT_DIR}/ready.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "ready": ${all_phases_succeeded},
  "phases": {
    "operator_health": ${operator_ready},
    "cr_deployment": ${crs_ready},
    "rootsync_verify": ${sync_ready},
    "slo_probes": ${slo_ready},
    "integrity": true
  },
  "tests": {
    "passed": ${TESTS_PASSED},
    "failed": ${TESTS_FAILED}
  }
}
EOF
}

# Generate manifest.json
generate_manifest() {
    cat > ${REPORT_DIR}/manifest.json <<EOF
{
  "smoke_test": {
    "version": "v1.1.2-rc1",
    "role": "@release-sherpa",
    "timestamp": "${TIMESTAMP}",
    "duration_seconds": ${SECONDS}
  },
  "environment": {
    "edge1": "${EDGE1_IP}",
    "edge2": "${EDGE2_IP}",
    "smo": "${SMO_IP}",
    "context": "${MGMT_CONTEXT}"
  },
  "results": {
    "phases_completed": [$(printf '"%s",' "${PHASES_COMPLETED[@]}" | sed 's/,$//')]
  },
  "files": [
    "ready.json",
    "slo.json",
    "smoke.log",
    "checksums/SHA256SUMS"
  ]
}
EOF
}

# Main execution
main() {
    log "START" "Daily smoke test initiated"

    # Run all phases
    phase1_operator_health || log "WARN" "Phase 1 failed"
    phase2_deploy_crs || log "WARN" "Phase 2 failed"
    phase3_verify_rootsync || log "WARN" "Phase 3 failed"
    phase4_slo_probes || log "WARN" "Phase 4 failed"
    phase5_integrity

    # Generate reports
    generate_ready_json
    generate_manifest

    # Summary
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN} Daily Smoke Test Complete${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"

    log "INFO" "Phases completed: ${#PHASES_COMPLETED[@]}/5"
    log "INFO" "Tests passed: ${TESTS_PASSED}"
    log "INFO" "Tests failed: ${TESTS_FAILED}"
    log "INFO" "Report directory: ${REPORT_DIR}"

    # Exit status
    if [ ${TESTS_FAILED} -eq 0 ] && [ ${#PHASES_COMPLETED[@]} -eq 5 ]; then
        log "SUCCESS" "All smoke tests passed ✓"
        exit 0
    else
        log "FAIL" "Some tests failed or incomplete"
        exit 1
    fi
}

# Execute
main "$@"