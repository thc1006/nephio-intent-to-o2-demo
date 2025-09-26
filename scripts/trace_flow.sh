#!/bin/bash
# Real-time flow tracer - shows exactly what's happening

set -euo pipefail

echo "=== INTENT-TO-O2 FLOW TRACER ==="
echo "Starting real-time monitoring..."
echo

# 1. Monitor LLM Adapter logs
echo "[1] LLM Adapter Activity (VM-1 (Integrated)):"
tail -f llm-adapter/service.log 2>/dev/null &
LLM_PID=$!

# 2. Monitor demo script logs
echo "[2] Orchestrator Activity (VM-1):"
tail -f artifacts/demo-llm/deployment.log 2>/dev/null &
ORCH_PID=$!

# 3. Monitor GitOps commits
echo "[3] GitOps Activity:"
watch -n 2 "git -C gitops log --oneline -5" &
GIT_PID=$!

# 4. Monitor Kubernetes deployments
echo "[4] Kubernetes Deployments:"
kubectl get deployments -A -w &
K8S_PID=$!

trap "kill $LLM_PID $ORCH_PID $GIT_PID $K8S_PID 2>/dev/null" EXIT

echo "Press Ctrl+C to stop monitoring"
wait