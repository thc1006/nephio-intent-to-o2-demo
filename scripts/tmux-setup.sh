#!/bin/bash
# Setup tmux session for Nephio intent pipeline development

SESSION="nephio"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Kill existing session if exists
tmux kill-session -t $SESSION 2>/dev/null

# Create new session with first window
tmux new-session -d -s $SESSION -n "WF-A"

# WF-A: intent-gateway (TMF921 validation)
tmux send-keys -t $SESSION:WF-A "cd $REPO_ROOT/tools/intent-gateway" C-m
tmux send-keys -t $SESSION:WF-A "# WF-A: TMF921 Intent Validation" C-m
tmux send-keys -t $SESSION:WF-A "# Run: pytest tests/ -v --tb=short" C-m
tmux send-keys -t $SESSION:WF-A "# CLI: python -m intent_gateway validate --file samples/tmf921/intent.json" C-m

# WF-B: tmf921-to-28312 converter
tmux new-window -t $SESSION -n "WF-B"
tmux send-keys -t $SESSION:WF-B "cd $REPO_ROOT/tools/tmf921-to-28312" C-m
tmux send-keys -t $SESSION:WF-B "# WF-B: TMF921 to 3GPP TS 28.312 Converter" C-m
tmux send-keys -t $SESSION:WF-B "# Run: pytest tests/ -v --cov=tmf921_to_28312" C-m
tmux send-keys -t $SESSION:WF-B "# CLI: python -m tmf921_to_28312 convert --input tmf.json --output 28312.json" C-m

# WF-C: expectation-to-krm (kpt function)
tmux new-window -t $SESSION -n "WF-C"
tmux send-keys -t $SESSION:WF-C "cd $REPO_ROOT/kpt-functions/expectation-to-krm" C-m
tmux send-keys -t $SESSION:WF-C "# WF-C: 3GPP Expectation to KRM (kpt function)" C-m
tmux send-keys -t $SESSION:WF-C "# Test: go test -v ./..." C-m
tmux send-keys -t $SESSION:WF-C "# Build: go build -o ../../artifacts/expectation-to-krm" C-m
tmux send-keys -t $SESSION:WF-C "# kpt: kpt fn render ../../packages/intent-to-krm/" C-m

# WF-D: o2ims-sdk (O-RAN O2 IMS)
tmux new-window -t $SESSION -n "WF-D"
tmux send-keys -t $SESSION:WF-D "cd $REPO_ROOT/o2ims-sdk" C-m
tmux send-keys -t $SESSION:WF-D "# WF-D: O-RAN O2 IMS SDK & ProvisioningRequest" C-m
tmux send-keys -t $SESSION:WF-D "# Test: go test -v ./..." C-m
tmux send-keys -t $SESSION:WF-D "# CLI: o2imsctl pr create --from examples/pr.yaml" C-m
tmux send-keys -t $SESSION:WF-D "# Fake: O2IMS_MODE=fake go test ./..." C-m

# WF-E: slo-gated-gitops (SLO gate & metrics)
tmux new-window -t $SESSION -n "WF-E"
tmux send-keys -t $SESSION:WF-E "cd $REPO_ROOT/slo-gated-gitops" C-m
tmux send-keys -t $SESSION:WF-E "# WF-E: SLO-Gated GitOps (Job Query & Gate)" C-m
tmux send-keys -t $SESSION:WF-E "# Test: pytest gate/tests/ -v" C-m
tmux send-keys -t $SESSION:WF-E "# Gate: python gate/gate.py --slo 'latency_p95_ms<=15'" C-m
tmux send-keys -t $SESSION:WF-E "# Query: python job-query-adapter/adapter.py --job-id job-001" C-m

# WF-F: guardrails (security policies)
tmux new-window -t $SESSION -n "WF-F"
tmux send-keys -t $SESSION:WF-F "cd $REPO_ROOT/guardrails" C-m
tmux send-keys -t $SESSION:WF-F "# WF-F: Security Guardrails (Sigstore/Kyverno/cert-manager)" C-m
tmux send-keys -t $SESSION:WF-F "# Sigstore: cosign verify --key cosign.pub image:tag" C-m
tmux send-keys -t $SESSION:WF-F "# Kyverno: kyverno test kyverno/" C-m
tmux send-keys -t $SESSION:WF-F "# Schema: ajv validate -s schemas/tmf921.json -d ../samples/tmf921/*.json" C-m

# WF-G: docs (documentation)
tmux new-window -t $SESSION -n "WF-G"
tmux send-keys -t $SESSION:WF-G "cd $REPO_ROOT/docs" C-m
tmux send-keys -t $SESSION:WF-G "# WF-G: Documentation & Reports" C-m
tmux send-keys -t $SESSION:WF-G "# Edit: vim ARCHITECTURE.md" C-m
tmux send-keys -t $SESSION:WF-G "# Build: pandoc -o nephio-demo.pdf *.md" C-m
tmux send-keys -t $SESSION:WF-G "# Serve: python -m http.server 8080" C-m

# Main: overview window
tmux new-window -t $SESSION -n "Main"
tmux send-keys -t $SESSION:Main "cd $REPO_ROOT" C-m
tmux send-keys -t $SESSION:Main "# Nephio Intent-to-O2 Demo Pipeline" C-m
tmux send-keys -t $SESSION:Main "# Session: $SESSION | Windows: WF-A to WF-G" C-m
tmux send-keys -t $SESSION:Main "# " C-m
tmux send-keys -t $SESSION:Main "# Quick commands:" C-m
tmux send-keys -t $SESSION:Main "#   make test     # Run all tests" C-m
tmux send-keys -t $SESSION:Main "#   make build    # Build artifacts" C-m
tmux send-keys -t $SESSION:Main "#   make e2e      # End-to-end test" C-m
tmux send-keys -t $SESSION:Main "# " C-m
tmux send-keys -t $SESSION:Main "# Navigation:" C-m
tmux send-keys -t $SESSION:Main "#   Ctrl-b n/p    # Next/Previous window" C-m
tmux send-keys -t $SESSION:Main "#   Ctrl-b 1-8    # Jump to window by number" C-m
tmux send-keys -t $SESSION:Main "#   Ctrl-b w      # Window list" C-m

# Select first window
tmux select-window -t $SESSION:Main

# Attach to session
echo "Tmux session '$SESSION' created with windows:"
echo "  Main    - Overview and quick commands"
echo "  WF-A    - Intent Gateway (TMF921 validation)"
echo "  WF-B    - TMF921 to 28.312 converter"
echo "  WF-C    - Expectation to KRM (kpt function)"
echo "  WF-D    - O2 IMS SDK"
echo "  WF-E    - SLO-gated GitOps"
echo "  WF-F    - Security guardrails"
echo "  WF-G    - Documentation"
echo ""
echo "Attach with: tmux attach -t $SESSION"