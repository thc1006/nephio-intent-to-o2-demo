#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUNDLE_DIR="${PROJECT_ROOT}/artifacts/summit-bundle"

echo "=== Packaging Summit Demo Bundle ==="

# Create bundle directory
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"/{slides,reports,scripts,configs}

# Copy presentation materials
if [ -d "${PROJECT_ROOT}/slides" ]; then
    cp -r "${PROJECT_ROOT}/slides"/* "$BUNDLE_DIR/slides/" 2>/dev/null || true
fi

# Copy runbook
if [ -d "${PROJECT_ROOT}/runbook" ]; then
    cp -r "${PROJECT_ROOT}/runbook" "$BUNDLE_DIR/" 2>/dev/null || true
fi

# Copy latest reports
if [ -d "${PROJECT_ROOT}/reports/latest" ]; then
    cp -r "${PROJECT_ROOT}/reports/latest"/* "$BUNDLE_DIR/reports/" 2>/dev/null || true
fi

# Copy key scripts
cp "${SCRIPT_DIR}/demo_llm.sh" "$BUNDLE_DIR/scripts/" 2>/dev/null || true
cp "${SCRIPT_DIR}/demo_orchestrator.sh" "$BUNDLE_DIR/scripts/" 2>/dev/null || true
cp "${SCRIPT_DIR}/postcheck.sh" "$BUNDLE_DIR/scripts/" 2>/dev/null || true
cp "${SCRIPT_DIR}/rollback.sh" "$BUNDLE_DIR/scripts/" 2>/dev/null || true

# Copy golden test files
if [ -d "${PROJECT_ROOT}/tests/golden" ]; then
    mkdir -p "$BUNDLE_DIR/tests/golden"
    cp "${PROJECT_ROOT}/tests/golden"/*.json "$BUNDLE_DIR/tests/golden/" 2>/dev/null || true
fi

# Copy documentation
for doc in RUNBOOK.md OPERATIONS.md SECURITY.md CLAUDE.md; do
    if [ -f "${PROJECT_ROOT}/$doc" ]; then
        cp "${PROJECT_ROOT}/$doc" "$BUNDLE_DIR/" 2>/dev/null || true
    fi
done

# Create bundle metadata
cat > "$BUNDLE_DIR/MANIFEST.json" << EOF
{
  "bundle": "summit-demo",
  "version": "1.0.0",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "contents": {
    "slides": ["SLIDES.md", "kpi.png", "kpi_summary.png"],
    "runbook": ["POCKET_QA.md"],
    "reports": ["executive_summary.md", "kpi_final.json"],
    "scripts": ["demo_llm.sh", "demo_orchestrator.sh", "postcheck.sh", "rollback.sh"],
    "tests": ["golden/*.json"],
    "docs": ["RUNBOOK.md", "OPERATIONS.md", "SECURITY.md", "CLAUDE.md"]
  },
  "requirements": {
    "vm_count": 4,
    "kubernetes": "1.28+",
    "nephio": "R5",
    "o-ran": "L Release"
  }
}
EOF

# Create quick start guide
cat > "$BUNDLE_DIR/QUICKSTART.md" << 'EOF'
# Summit Demo Quick Start

## Prerequisites
- 4 VMs configured (see CLAUDE.md for details)
- Kubernetes 1.28+ on edge clusters
- Network connectivity between VMs

## Quick Demo Commands

### 1. One-Click Demo
```bash
make demo
```

### 2. Step-by-Step Demo
```bash
# Install O2 IMS
make o2ims-install

# Provision O-Cloud
make ocloud-provision

# Deploy to edge
make publish-edge

# Check status
kubectl get rootsync -A
```

### 3. Multi-Site Demo
```bash
./scripts/demo_llm.sh --target=both
```

### 4. Generate Reports
```bash
make summit
```

## Troubleshooting
See RUNBOOK.md and runbook/POCKET_QA.md for common issues.

## Support
GitHub: nephio-intent-to-o2-demo
EOF

# Calculate bundle size
BUNDLE_SIZE=$(du -sh "$BUNDLE_DIR" | cut -f1)

echo "✅ Summit bundle created at: $BUNDLE_DIR"
echo "   Bundle size: $BUNDLE_SIZE"
echo "   Contents:"
find "$BUNDLE_DIR" -type f | head -20
echo "=== Summit bundle packaging complete ==="