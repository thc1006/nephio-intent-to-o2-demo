#!/bin/bash
"""
ACC-18 Contract Test Runner
Executes TDD methodology for Intent→KRM translation contract testing
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 ACC-18 Intent→KRM Contract Testing with TDD${NC}"
echo -e "${BLUE}=================================================${NC}"

# Set up environment
PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
cd "$PROJECT_ROOT"

# Ensure artifacts directory exists
mkdir -p "$PROJECT_ROOT/artifacts/acc18"

echo -e "\n${YELLOW}📦 Checking dependencies...${NC}"

# Check if kubeconform is available
if ! command -v kubeconform &> /dev/null; then
    echo -e "${RED}❌ kubeconform not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubeconform available${NC}"

# Check if Python dependencies are available
if ! python3 -c "import yaml, deepdiff" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Installing Python dependencies...${NC}"
    pip3 install PyYAML deepdiff || true
fi

echo -e "\n${YELLOW}🔄 Running ACC-18 Contract Tests...${NC}"

# Run the contract tests
python3 "$PROJECT_ROOT/tests/acc18_contract_test.py"

echo -e "\n${YELLOW}📋 Contract Test Results:${NC}"

# Display summary if contract report exists
REPORT_FILE="$PROJECT_ROOT/artifacts/acc18/contract_report.json"
if [ -f "$REPORT_FILE" ]; then
    echo -e "${GREEN}📄 Contract report generated: $REPORT_FILE${NC}"

    # Extract summary metrics using Python
    python3 -c "
import json
try:
    with open('$REPORT_FILE', 'r') as f:
        report = json.load(f)

    metrics = report.get('metrics', {})
    print(f'📊 Total Tests: {metrics.get(\"total_tests\", 0)}')
    print(f'✅ Passed: {metrics.get(\"passed\", 0)}')
    print(f'❌ Failed: {metrics.get(\"failed\", 0)}')
    print(f'📈 Coverage: {metrics.get(\"coverage_percentage\", 0):.1f}%')

    # Display TMF921 compliance
    tmf921 = report.get('tmf921_compliance', {})
    schema_validation = tmf921.get('schema_validation', {})

    print(f'\\n🔍 TMF921 v5.0/921A Compliance:')
    for intent_name, validation in schema_validation.items():
        status = '✅' if validation.get('valid', False) else '❌'
        print(f'  {status} {intent_name}: {\"Valid\" if validation.get(\"valid\", False) else \"Invalid\"}')

    # Display kubeconform results
    test_results = report.get('test_results', {})
    golden_intents = test_results.get('golden_intents', {})

    print(f'\\n🛠️  Kubeconform Validation:')
    for intent_name, result in golden_intents.items():
        kubeconf_results = result.get('kubeconform_results', {})
        valid_count = sum(1 for r in kubeconf_results.values() if r.get('valid', False))
        total_count = len(kubeconf_results)
        print(f'  📁 {intent_name}: {valid_count}/{total_count} files valid')

except Exception as e:
    print(f'Error reading report: {e}')
"
else
    echo -e "${RED}❌ Contract report not found${NC}"
    exit 1
fi

echo -e "\n${BLUE}🎯 ACC-18 Contract Testing Complete${NC}"