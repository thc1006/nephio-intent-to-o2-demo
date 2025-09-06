#!/bin/bash
# SLO-Gated GitOps Demo Script
# Demonstrates the complete TDD implementation

set -e  # Exit on any error

echo "🚀 SLO-Gated GitOps Demo"
echo "========================="
echo ""

# Change to the correct directory
cd "$(dirname "$0")"

echo "📂 Project Structure:"
find . -type f \( -name "*.py" -o -name "Makefile" -o -name "README.md" \) | head -10
echo "   ... (and more)"
echo ""

echo "🏃 Starting job-query-adapter..."
python3 job-query-adapter/adapter.py &
ADAPTER_PID=$!
sleep 3

# Trap to cleanup background process
trap "kill $ADAPTER_PID 2>/dev/null || true" EXIT

echo "✅ Testing SLO PASS scenario..."
if python3 gate/gate.py --slo "latency_p95_ms<=15,success_rate>=0.995,throughput_p95_mbps>=100" --url http://localhost:8080/metrics; then
    echo "✅ SLO validation PASSED (exit code 0) ✓"
else
    echo "❌ SLO validation failed unexpectedly"
    exit 1
fi

echo ""
echo "❌ Testing SLO FAIL scenario..."
if ! python3 gate/gate.py --slo "latency_p95_ms<=5,success_rate>=0.999,throughput_p95_mbps>=1000" --url http://localhost:8080/metrics; then
    echo "✅ SLO validation correctly FAILED (exit code 1) ✓"
else
    echo "❌ SLO validation passed when it should have failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! TDD implementation complete."
echo ""
echo "Summary:"
echo "- ✅ RED phase: Failing tests created"
echo "- ✅ GREEN phase: Minimal implementation passes tests"  
echo "- ✅ Deterministic CLI with exit codes 0/1"
echo "- ✅ JSON logging for machine parsing"
echo "- ✅ No plaintext secrets (.env.example pattern)"
echo "- ✅ Components: job-query-adapter + gate"
echo "- ✅ Makefile + README + requirements for each component"
echo ""
echo "Ready for REFACTOR phase and production deployment! 🚢"