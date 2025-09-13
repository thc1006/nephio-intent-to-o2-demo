#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="${PROJECT_ROOT}/reports"

echo "=== Creating Latest Reports Symlink ==="

# Find the most recent timestamped report directory
LATEST_REPORT=$(ls -dt "${REPORTS_DIR}"/[0-9]* 2>/dev/null | head -1 || true)

if [ -z "$LATEST_REPORT" ]; then
    echo "No timestamped reports found. Creating placeholder..."
    # Create a placeholder report directory
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p "${REPORTS_DIR}/${TIMESTAMP}"

    # Create placeholder files
    cat > "${REPORTS_DIR}/${TIMESTAMP}/placeholder.json" << EOF
{
  "status": "placeholder",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "message": "No actual reports available yet. Run 'make demo' to generate reports."
}
EOF

    LATEST_REPORT="${REPORTS_DIR}/${TIMESTAMP}"
fi

# Remove old symlink if it exists
if [ -L "${REPORTS_DIR}/latest" ]; then
    rm "${REPORTS_DIR}/latest"
elif [ -d "${REPORTS_DIR}/latest" ]; then
    echo "Warning: ${REPORTS_DIR}/latest exists but is not a symlink. Backing up..."
    mv "${REPORTS_DIR}/latest" "${REPORTS_DIR}/latest.backup.$(date +%s)"
fi

# Create new symlink
ln -s "$(basename "$LATEST_REPORT")" "${REPORTS_DIR}/latest"

echo "✅ Created symlink: reports/latest -> $(basename "$LATEST_REPORT")"

# Verify symlink
if [ -L "${REPORTS_DIR}/latest" ]; then
    echo "✅ Symlink verified successfully"
    ls -la "${REPORTS_DIR}/latest"
else
    echo "❌ Failed to create symlink"
    exit 1
fi

echo "=== Latest reports link created ==="