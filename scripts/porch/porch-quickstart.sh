#!/bin/bash
# Porch Quick Start Script
# Usage: ./porch-quickstart.sh [command]
# Commands: status, repos, packages, help

set -e

COMMAND=${1:-status}

case "$COMMAND" in
    status)
        echo "=== Porch Status ==="
        echo ""
        echo "API Service:"
        kubectl get apiservices v1alpha1.porch.kpt.dev
        echo ""
        echo "Pods:"
        kubectl get pods -n porch-system
        echo ""
        ;;

    repos|repositories)
        echo "=== Registered Repositories ==="
        kubectl get repositories --all-namespaces
        ;;

    packages)
        echo "=== Available Packages ==="
        kubectl get packages --all-namespaces
        echo ""
        echo "=== Package Revisions ==="
        kubectl get packagerevisions --all-namespaces
        ;;

    register-repo)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 register-repo <name> <repo-url> [namespace] [branch]"
            echo "Example: $0 register-repo blueprints https://github.com/your-org/blueprints.git default main"
            exit 1
        fi

        REPO_NAME=$2
        REPO_URL=$3
        NAMESPACE=${4:-default}
        BRANCH=${5:-main}

        cat <<EOF | kubectl apply -f -
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: ${REPO_NAME}
  namespace: ${NAMESPACE}
spec:
  type: git
  content: Package
  deployment: false
  git:
    repo: ${REPO_URL}
    branch: ${BRANCH}
    directory: /
EOF
        echo "✅ Repository '${REPO_NAME}' registered in namespace '${NAMESPACE}'"
        ;;

    logs)
        COMPONENT=${2:-porch-server}
        echo "=== Logs for ${COMPONENT} ==="
        kubectl logs -n porch-system deployment/${COMPONENT} --tail=50
        ;;

    describe)
        RESOURCE_TYPE=${2:-pods}
        echo "=== Describing ${RESOURCE_TYPE} in porch-system ==="
        kubectl describe ${RESOURCE_TYPE} -n porch-system
        ;;

    help|*)
        cat <<EOF
Porch Quick Start Script

Usage: $0 [command] [args]

Commands:
  status              Show Porch deployment status (default)
  repos               List registered repositories
  packages            List packages and package revisions
  register-repo       Register a new Git repository
                      Usage: $0 register-repo <name> <url> [namespace] [branch]
  logs [component]    Show logs (default: porch-server)
                      Components: porch-server, porch-controllers, function-runner
  describe [type]     Describe resources (default: pods)
  help                Show this help message

Examples:
  $0 status
  $0 repos
  $0 packages
  $0 register-repo blueprints https://github.com/your-org/blueprints.git
  $0 logs porch-controllers
  $0 describe deployments

For more information:
  - Porch docs: https://kpt.dev/book/09-package-orchestration/
  - kpt CLI: kpt alpha repo --help
  - kubectl porch: kubectl get packagerevisions --all-namespaces
EOF
        ;;
esac