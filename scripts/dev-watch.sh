#!/bin/bash
# Development watch script for TDD workflow

WORKFLOW="${1:-all}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case $WORKFLOW in
  wf-a|intent-gateway)
    echo "Watching WF-A: Intent Gateway tests..."
    cd "$REPO_ROOT/tools/intent-gateway"
    while true; do
      clear
      echo "=== WF-A: TMF921 Validation [RED→GREEN→REFACTOR] ==="
      python3.11 -m pytest tests/ -v --tb=short --color=yes
      echo ""
      echo "Press Ctrl-C to stop, any key to re-run..."
      read -n 1
    done
    ;;
    
  wf-b|converter)
    echo "Watching WF-B: TMF921→28.312 Converter..."
    cd "$REPO_ROOT/tools/tmf921-to-28312"
    while true; do
      clear
      echo "=== WF-B: Converter Tests & Coverage ==="
      python3.11 -m pytest tests/ -v --cov=tmf921_to_28312 --cov-report=term-missing
      echo ""
      echo "Press Ctrl-C to stop, any key to re-run..."
      read -n 1
    done
    ;;
    
  wf-c|kpt)
    echo "Watching WF-C: Expectation→KRM kpt function..."
    cd "$REPO_ROOT/kpt-functions/expectation-to-krm"
    while true; do
      clear
      echo "=== WF-C: kpt Function Tests ==="
      go test -v ./...
      echo ""
      echo "Press Ctrl-C to stop, any key to re-run..."
      read -n 1
    done
    ;;
    
  wf-d|o2ims)
    echo "Watching WF-D: O2 IMS SDK..."
    cd "$REPO_ROOT/o2ims-sdk"
    while true; do
      clear
      echo "=== WF-D: O2 IMS SDK Tests ==="
      O2IMS_MODE=fake go test -v ./...
      echo ""
      echo "Press Ctrl-C to stop, any key to re-run..."
      read -n 1
    done
    ;;
    
  wf-e|slo)
    echo "Watching WF-E: SLO Gate..."
    cd "$REPO_ROOT/slo-gated-gitops"
    while true; do
      clear
      echo "=== WF-E: SLO Gate Tests ==="
      python3.11 -m pytest gate/tests/ -v --tb=short
      echo ""
      echo "Press Ctrl-C to stop, any key to re-run..."
      read -n 1
    done
    ;;
    
  all)
    echo "Running all workflow tests..."
    cd "$REPO_ROOT"
    make test
    ;;
    
  *)
    echo "Usage: $0 [wf-a|wf-b|wf-c|wf-d|wf-e|all]"
    echo ""
    echo "Workflows:"
    echo "  wf-a, intent-gateway  - TMF921 validation"
    echo "  wf-b, converter       - TMF921 to 28.312"
    echo "  wf-c, kpt            - Expectation to KRM"
    echo "  wf-d, o2ims          - O2 IMS SDK"
    echo "  wf-e, slo            - SLO Gate"
    echo "  all                  - Run all tests"
    exit 1
    ;;
esac