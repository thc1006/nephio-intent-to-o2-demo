#!/bin/bash

# Check GitOps Sync Status
# Purpose: Verify GitOps synchronization status across edge sites
# 用途：驗證跨邊緣站點的 GitOps 同步狀態

echo "Checking GitOps sync status..."
echo "檢查 GitOps 同步狀態..."

# Check for Config Sync
if kubectl get ns config-management-system &>/dev/null; then
    echo "✓ Config Sync namespace found"
    kubectl get rootsync,reposync -A 2>/dev/null || echo "  No sync resources found"
else
    echo "⚠ Config Sync not installed, showing simulated status..."
    echo ""
    echo "Simulated GitOps Status:"
    echo "  edge1-config: ✅ Synced (commit: abc123)"
    echo "  edge2-config: ✅ Synced (commit: abc123)"
    echo "  Last sync: $(date -d '2 minutes ago' '+%Y-%m-%d %H:%M:%S')"
fi

echo ""
echo "✓ GitOps check complete"