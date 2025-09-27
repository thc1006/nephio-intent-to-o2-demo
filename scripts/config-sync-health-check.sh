#!/bin/bash

# Config Sync Health Check Script
# Comprehensive diagnostics for Config Sync on edge sites

set -e

echo "🏥 Config Sync Health Check"
echo "=========================="

# Function to check edge site health
check_edge_health() {
    local edge_name=$1
    local edge_ip=$2
    local ssh_key=$3
    local ssh_user=$4

    echo "🔍 Checking $edge_name ($edge_ip)..."
    echo "-----------------------------------"

    # Network connectivity
    echo "📡 Network Connectivity:"
    if ping -c 1 $edge_ip >/dev/null 2>&1; then
        echo "  ✅ SSH connectivity: OK"
    else
        echo "  ❌ SSH connectivity: FAILED"
        return 1
    fi

    # Gitea connectivity
    echo "🌐 Gitea Connectivity:"
    if ssh -i $ssh_key -o StrictHostKeyChecking=no $ssh_user@$edge_ip 'curl -s -f http://172.16.0.78:8888' >/dev/null; then
        echo "  ✅ Gitea HTTP: OK"
    else
        echo "  ❌ Gitea HTTP: FAILED"
    fi

    # Config Sync pods
    echo "🔄 Config Sync Pods:"
    local pod_status=$(ssh -i $ssh_key -o StrictHostKeyChecking=no $ssh_user@$edge_ip \
        'kubectl get pods -n config-management-system -l app=root-reconciler --no-headers' 2>/dev/null || echo "FAILED")

    if echo "$pod_status" | grep -q "Running"; then
        echo "  ✅ Root reconciler: Running"
    else
        echo "  ❌ Root reconciler: Not running"
        echo "     Status: $pod_status"
    fi

    # RootSync status
    echo "📋 RootSync Status:"
    local rootsync_status=$(ssh -i $ssh_key -o StrictHostKeyChecking=no $ssh_user@$edge_ip \
        'kubectl get rootsync root-sync -n config-management-system -o jsonpath="{.status.conditions[?(@.type==\"Syncing\")].status}"' 2>/dev/null || echo "FAILED")

    if [ "$rootsync_status" = "True" ]; then
        echo "  ✅ RootSync: Syncing successfully"

        # Get commit info
        local commit=$(ssh -i $ssh_key -o StrictHostKeyChecking=no $ssh_user@$edge_ip \
            'kubectl get rootsync root-sync -n config-management-system -o jsonpath="{.status.sync.commit}"' 2>/dev/null || echo "unknown")
        echo "     Last sync commit: $commit"
    else
        echo "  ❌ RootSync: Not syncing"

        # Get error details
        local error_msg=$(ssh -i $ssh_key -o StrictHostKeyChecking=no $ssh_user@$edge_ip \
            'kubectl get rootsync root-sync -n config-management-system -o jsonpath="{.status.conditions[?(@.type==\"Stalled\")].message}"' 2>/dev/null || echo "unknown")
        echo "     Error: $error_msg"
    fi

    # Secret verification
    echo "🔑 Authentication Secret:"
    local secret_keys=$(ssh -i $ssh_key -o StrictHostKeyChecking=no $ssh_user@$edge_ip \
        'kubectl get secret gitea-credentials -n config-management-system -o jsonpath="{.data}" | grep -o "\"[^\"]*\":" | tr -d "\":" | sort' 2>/dev/null || echo "FAILED")

    if echo "$secret_keys" | grep -q "username" && echo "$secret_keys" | grep -q "token"; then
        echo "  ✅ Secret: Contains username and token"
    else
        echo "  ❌ Secret: Missing required fields"
        echo "     Available keys: $secret_keys"
    fi

    echo ""
}

# Check all edge sites
echo "Starting health checks for all edge sites..."
echo ""

# Edge3
check_edge_health "Edge3" "172.16.5.81" "~/.ssh/edge_sites_key" "thc1006"

# Edge4
check_edge_health "Edge4" "172.16.1.252" "~/.ssh/edge_sites_key" "thc1006"

echo "🏁 Health check complete!"
echo ""
echo "📊 Quick Status Summary:"
echo "  Edge3: Check individual components above"
echo "  Edge4: Check individual components above"
echo ""
echo "🔧 Common fixes:"
echo "  - Authentication: Run /home/ubuntu/nephio-intent-to-o2-demo/scripts/fix-config-sync-auth.sh"
echo "  - Network issues: Check edge site connectivity and Gitea service"
echo "  - Pod issues: kubectl rollout restart deployment/root-reconciler -n config-management-system"