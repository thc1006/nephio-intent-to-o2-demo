#!/bin/bash
# Quick TDD helper for RED→GREEN→REFACTOR cycle

set -euo pipefail

ACTION="${1:-test}"
MODULE="${2:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    echo "Quick TDD helper for Nephio intent pipeline"
    echo ""
    echo "Usage: $0 [action] [module]"
    echo ""
    echo "Actions:"
    echo "  red       - Write failing test"
    echo "  green     - Implement minimal code"
    echo "  refactor  - Clean up code"
    echo "  test      - Run tests"
    echo "  coverage  - Show test coverage"
    echo ""
    echo "Modules:"
    echo "  intent-gateway"
    echo "  converter"
    echo "  kpt-fn"
    echo "  o2ims"
    echo "  slo-gate"
}

run_tests() {
    local module=$1
    case $module in
        intent-gateway)
            cd tools/intent-gateway
            python3.11 -m pytest tests/ -v --tb=short
            ;;
        converter)
            cd tools/tmf921-to-28312
            python3.11 -m pytest tests/ -v --tb=short
            ;;
        kpt-fn)
            cd kpt-functions/expectation-to-krm
            go test -v ./...
            ;;
        o2ims)
            cd o2ims-sdk
            O2IMS_MODE=fake go test -v ./...
            ;;
        slo-gate)
            cd slo-gated-gitops
            python3.11 -m pytest gate/tests/ -v --tb=short
            ;;
        *)
            echo "Unknown module: $module"
            exit 1
            ;;
    esac
}

case $ACTION in
    red)
        echo -e "${RED}=== RED: Writing failing test ===${NC}"
        echo "Add test to verify new behavior..."
        echo "Test MUST fail initially!"
        ;;
        
    green)
        echo -e "${GREEN}=== GREEN: Implementing minimal code ===${NC}"
        echo "Write just enough code to pass the test..."
        echo "No extra features!"
        ;;
        
    refactor)
        echo -e "${YELLOW}=== REFACTOR: Cleaning up ===${NC}"
        echo "Improve code without changing behavior..."
        echo "Tests must still pass!"
        ;;
        
    test)
        if [[ -z "$MODULE" ]]; then
            echo "Running all tests..."
            make test
        else
            echo "Running tests for $MODULE..."
            run_tests "$MODULE"
        fi
        ;;
        
    coverage)
        if [[ "$MODULE" == "intent-gateway" ]]; then
            cd tools/intent-gateway
            python3.11 -m pytest tests/ --cov=intent_gateway --cov-report=term-missing
        elif [[ "$MODULE" == "converter" ]]; then
            cd tools/tmf921-to-28312
            python3.11 -m pytest tests/ --cov=tmf921_to_28312 --cov-report=term-missing
        else
            echo "Coverage available for: intent-gateway, converter"
        fi
        ;;
        
    *)
        show_help
        ;;
esac