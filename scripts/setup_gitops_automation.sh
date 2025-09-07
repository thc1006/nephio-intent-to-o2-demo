#!/bin/bash
set -euo pipefail

echo "========================================="
echo "GitOps 自動化設定"
echo "========================================="
echo ""
echo "選擇 GitOps 工具："
echo "1) Flux CD (輕量、Kubernetes 原生)"
echo "2) ArgoCD (功能豐富、有 Web UI)"
echo "3) 手動同步 (使用 kubectl apply)"
echo ""
read -p "選擇 [1-3]: " choice

case $choice in
    1)
        echo "=== 安裝 Flux CD ==="
        # Install Flux CLI
        curl -s https://fluxcd.io/install.sh | sudo bash
        
        # Bootstrap Flux
        export GITEA_URL="http://172.18.0.2:30924"
        export GITEA_USER="admin1"
        export GITEA_TOKEN="admin123"
        
        flux bootstrap git \
          --url=http://172.18.0.2:30924/admin1/edge1-config \
          --username=admin1 \
          --password=admin123 \
          --token-auth=true \
          --path=clusters/edge-cluster-01 \
          --branch=main
        ;;
        
    2)
        echo "=== 安裝 ArgoCD ==="
        # Create namespace
        kubectl create namespace argocd || true
        
        # Install ArgoCD
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        # Wait for ArgoCD to be ready
        kubectl wait --for=condition=ready pod -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s
        
        # Create ArgoCD Application
        cat > /tmp/argocd-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: edge-gitops
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://172.18.0.2:30924/admin1/edge1-config.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: edge
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespaceIfNotSpecified=true
EOF
        kubectl apply -f /tmp/argocd-app.yaml
        
        # Get admin password
        echo ""
        echo "ArgoCD 安裝完成！"
        echo "Admin 密碼："
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
        echo ""
        
        # Port forward ArgoCD UI
        echo "啟動 ArgoCD UI port-forward:"
        echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
        ;;
        
    3)
        echo "=== 手動同步設定 ==="
        # Create sync script
        cat > /home/ubuntu/sync-gitops.sh <<'EOF'
#!/bin/bash
cd /home/ubuntu/repos/edge1-config
git pull
kubectl apply -k clusters/edge-cluster-01/
kubectl apply -k apps/
echo "GitOps sync completed at $(date)"
EOF
        chmod +x /home/ubuntu/sync-gitops.sh
        
        # Create systemd timer for auto sync
        sudo tee /etc/systemd/system/gitops-sync.service <<EOF
[Unit]
Description=GitOps Sync Service
After=network.target

[Service]
Type=oneshot
User=ubuntu
ExecStart=/home/ubuntu/sync-gitops.sh
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

        sudo tee /etc/systemd/system/gitops-sync.timer <<EOF
[Unit]
Description=GitOps Sync Timer
Requires=gitops-sync.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable gitops-sync.timer
        sudo systemctl start gitops-sync.timer
        
        echo "手動同步設定完成！"
        echo "- 立即同步: bash /home/ubuntu/sync-gitops.sh"
        echo "- 自動同步: 每 5 分鐘"
        echo "- 查看狀態: systemctl status gitops-sync.timer"
        ;;
esac

echo ""
echo "========================================="
echo "GitOps 設定完成！"
echo "========================================="
echo ""
echo "現在你可以："
echo "1. 在 Gitea 修改 YAML 檔案"
echo "2. GitOps 會自動同步到 Kubernetes"
echo "3. 查看部署狀態："
echo "   kubectl get all -n edge"