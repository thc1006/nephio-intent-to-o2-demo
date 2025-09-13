#!/bin/bash
set -euo pipefail

echo "=== Testing Summit Outputs ==="

# Test if all required files exist
REQUIRED_FILES=(
    "slides/SLIDES.md"
    "slides/kpi.png"
    "slides/kpi_summary.png"
    "runbook/POCKET_QA.md"
    "reports/latest/executive_summary.md"
    "artifacts/summit-bundle/MANIFEST.json"
    "artifacts/summit-bundle/QUICKSTART.md"
)

FAILED=0

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        FAILED=1
    fi
done

# Check if slides have content
if [ -f "slides/SLIDES.md" ]; then
    LINE_COUNT=$(wc -l < slides/SLIDES.md)
    if [ "$LINE_COUNT" -gt 100 ]; then
        echo "✅ SLIDES.md has $LINE_COUNT lines"
    else
        echo "❌ SLIDES.md too short ($LINE_COUNT lines)"
        FAILED=1
    fi
fi

# Check if images are valid
for img in slides/kpi.png slides/kpi_summary.png; do
    if [ -f "$img" ]; then
        SIZE=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img" 2>/dev/null || echo 0)
        if [ "$SIZE" -gt 1000 ]; then
            echo "✅ $img is valid (${SIZE} bytes)"
        else
            echo "❌ $img is too small (${SIZE} bytes)"
            FAILED=1
        fi
    fi
done

# Check symlink
if [ -L "reports/latest" ]; then
    echo "✅ reports/latest symlink exists"
else
    echo "❌ reports/latest symlink missing"
    FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then
    echo ""
    echo "=== ✅ ALL SUMMIT OUTPUTS VALIDATED ==="
else
    echo ""
    echo "=== ❌ SOME SUMMIT OUTPUTS FAILED ==="
    exit 1
fi