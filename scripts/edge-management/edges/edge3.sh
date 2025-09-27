#!/bin/bash
# Management script for edge3
# Generated: 2025-09-27

EDGE_NAME="edge3"
EDGE_IP="172.16.5.81"
EDGE_USER="thc1006"
SSH_KEY="~/.ssh/edge_sites_key"

# Execute command on edge site
exec_on_edge() {
    echo "→ Executing on ${EDGE_NAME} (${EDGE_IP}): $*"
    ssh ${EDGE_NAME} "$@"
}

# Copy file to edge site
copy_to_edge() {
    local src="$1"
    local dest="$2"
    echo "→ Copying ${src} to ${EDGE_NAME}:${dest}"
    scp "${src}" ${EDGE_NAME}:"${dest}"
}

# Execute script on edge site
run_script_on_edge() {
    local script="$1"
    echo "→ Running script ${script} on ${EDGE_NAME}"
    ssh ${EDGE_NAME} 'bash -s' < "${script}"
}

# Main command dispatcher
case "${1:-}" in
    exec|run)
        shift
        exec_on_edge "$@"
        ;;
    copy|scp)
        shift
        copy_to_edge "$@"
        ;;
    script)
        shift
        run_script_on_edge "$@"
        ;;
    shell|ssh)
        ssh ${EDGE_NAME}
        ;;
    status)
        echo "Edge Site Status: ${EDGE_NAME}"
        echo "═══════════════════════════════════════"
        exec_on_edge "
            echo 'Hostname:    \$(hostname)'
            echo 'Uptime:      \$(uptime -p)'
            echo 'Kernel:      \$(uname -r)'
            echo 'Memory:      \$(free -h | grep Mem | awk \"{print \\\$3\\\"/\\\"\\\$2}\")'
            echo 'Disk:        \$(df -h / | tail -1 | awk \"{print \\\$3\\\"/\\\"\\\$2\\\" (\\\"\\\$5\\\")}\")'"
        ;;
    k8s)
        echo "Kubernetes Status on ${EDGE_NAME}"
        echo "═══════════════════════════════════════"
        exec_on_edge "kubectl get nodes && echo '---' && kubectl get pods -A | head -20"
        ;;
    prometheus)
        echo "Prometheus Status on ${EDGE_NAME}"
        echo "═══════════════════════════════════════"
        exec_on_edge "kubectl get pods -n monitoring && kubectl get svc -n monitoring"
        echo ""
        echo "Prometheus URL: http://${EDGE_IP}:30090"
        ;;
    *)
        cat << EOF
Usage: $0 <command> [args...]

Commands:
  exec|run <cmd>        Execute command on edge site
  copy|scp <src> <dst>  Copy file to edge site
  script <file>         Run local script on edge site
  shell|ssh             Open SSH shell to edge site
  status                Display edge site status
  k8s                   Display Kubernetes status
  prometheus            Display Prometheus status

Examples:
  $0 exec "df -h"
  $0 copy ./config.yaml /tmp/config.yaml
  $0 script ./setup.sh
  $0 shell
  $0 status
  $0 k8s
  $0 prometheus
EOF
        exit 1
        ;;
esac
