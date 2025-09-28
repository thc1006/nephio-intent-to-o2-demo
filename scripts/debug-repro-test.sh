#!/bin/bash
# Debug version of reproducibility test

set -x
PROJECT_ROOT="/home/ubuntu/nephio-intent-to-o2-demo"
echo "Project root: $PROJECT_ROOT"

echo "Testing documentation file..."
if [[ -f "$PROJECT_ROOT/docs/IEEE_PAPER_SUPPLEMENTARY.md" ]]; then
    echo "✅ IEEE supplementary materials documentation found"
else
    echo "❌ IEEE supplementary materials documentation missing"
fi

echo "Testing installation scripts..."
installation_scripts=0
for script in "install-2025.sh" "install-k3s.sh" "install-config-sync.sh" "install-tmf921-adapter.sh"; do
    echo "Checking: $script"
    if [[ -f "$PROJECT_ROOT/scripts/$script" ]]; then
        echo "  Found: $script"
        ((installation_scripts++))
    else
        echo "  Missing: $script"
    fi
done
echo "Total installation scripts: $installation_scripts"

echo "Testing configuration files..."
if [[ -f "$PROJECT_ROOT/config/edge-sites-config.yaml" ]]; then
    echo "✅ Edge sites configuration documented"
else
    echo "❌ Edge sites configuration missing"
fi

echo "Testing edge sites count..."
edge_sites=$(grep -c "edge[0-9]:" "$PROJECT_ROOT/config/edge-sites-config.yaml" 2>/dev/null || echo 0)
echo "Edge sites found: $edge_sites"

echo "Debug test completed successfully!"