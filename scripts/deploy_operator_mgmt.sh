#!/bin/bash
# Deploy Operator α to management cluster with dual-mode support
set -e

# Configuration
OPERATOR_IMG="${OPERATOR_IMG:-intent-operator:v0.1.2-alpha}"
NAMESPACE="${OPERATOR_NS:-intent-operator-system}"
PIPELINE_MODE="${PIPELINE_MODE:-embedded}"
SHELL_ROOT="${SHELL_PIPELINE_ROOT:-$(pwd)}"
ARTIFACTS_ROOT="${ARTIFACTS_ROOT:-/var/run/operator-artifacts}"
MGMT_CONTEXT="${MGMT_CONTEXT:-kind-nephio-demo}"

echo "======================================"
echo "Deploying Operator α to Management Cluster"
echo "======================================"
echo "Image: $OPERATOR_IMG"
echo "Namespace: $NAMESPACE"
echo "Pipeline Mode: $PIPELINE_MODE"
echo "Shell Root: $SHELL_ROOT"
echo "Artifacts: $ARTIFACTS_ROOT"
echo "Context: $MGMT_CONTEXT"
echo ""

# 1. Ensure management cluster exists
echo "Step 1: Checking management cluster..."
if ! kubectl --context "$MGMT_CONTEXT" cluster-info &>/dev/null; then
    echo "Creating kind management cluster..."
    kind create cluster --name nephio-demo --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-role.kubernetes.io/master="
- role: worker
EOF
else
    echo "✓ Management cluster exists"
fi

# 2. Build and load operator image
echo ""
echo "Step 2: Building operator image..."
cd operator
if [ ! -f "Dockerfile" ]; then
    echo "ERROR: Not in correct directory. Run from repo root."
    exit 1
fi

# Build image
docker build -t "$OPERATOR_IMG" .

# Load into kind
echo "Loading image into kind..."
kind load docker-image "$OPERATOR_IMG" --name nephio-demo

cd ..

# 3. Install CRDs
echo ""
echo "Step 3: Installing CRDs..."
kubectl --context "$MGMT_CONTEXT" apply -f operator/config/crd/bases/

# 4. Create namespace
echo ""
echo "Step 4: Creating namespace..."
kubectl --context "$MGMT_CONTEXT" create namespace "$NAMESPACE" --dry-run=client -o yaml | \
    kubectl --context "$MGMT_CONTEXT" apply -f -

# 5. Create ConfigMap for pipeline configuration
echo ""
echo "Step 5: Creating pipeline ConfigMap..."
kubectl --context "$MGMT_CONTEXT" create configmap pipeline-config \
    -n "$NAMESPACE" \
    --from-literal=PIPELINE_MODE="$PIPELINE_MODE" \
    --from-literal=SHELL_PIPELINE_ROOT="$SHELL_ROOT" \
    --from-literal=ARTIFACTS_ROOT="$ARTIFACTS_ROOT" \
    --dry-run=client -o yaml | kubectl --context "$MGMT_CONTEXT" apply -f -

# 6. Deploy operator
echo ""
echo "Step 6: Deploying operator..."
cat <<EOF | kubectl --context "$MGMT_CONTEXT" apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: intent-operator-controller-manager
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      control-plane: controller-manager
  template:
    metadata:
      labels:
        control-plane: controller-manager
    spec:
      containers:
      - name: manager
        image: $OPERATOR_IMG
        imagePullPolicy: IfNotPresent
        command:
        - /manager
        args:
        - --leader-elect
        env:
        - name: PIPELINE_MODE
          valueFrom:
            configMapKeyRef:
              name: pipeline-config
              key: PIPELINE_MODE
        - name: SHELL_PIPELINE_ROOT
          valueFrom:
            configMapKeyRef:
              name: pipeline-config
              key: SHELL_PIPELINE_ROOT
        - name: ARTIFACTS_ROOT
          valueFrom:
            configMapKeyRef:
              name: pipeline-config
              key: ARTIFACTS_ROOT
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: artifacts
          mountPath: /var/run/operator-artifacts
        - name: pipeline-scripts
          mountPath: /opt/nephio-intent-to-o2-demo
          readOnly: true
      serviceAccountName: intent-operator-controller-manager
      terminationGracePeriodSeconds: 10
      volumes:
      - name: artifacts
        emptyDir: {}
      - name: pipeline-scripts
        hostPath:
          path: $SHELL_ROOT
          type: Directory
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: intent-operator-controller-manager
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: intent-operator-manager-role
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["tna.tna.ai"]
  resources: ["intentdeployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["tna.tna.ai"]
  resources: ["intentdeployments/status"]
  verbs: ["get", "update", "patch"]
- apiGroups: ["tna.tna.ai"]
  resources: ["intentdeployments/finalizers"]
  verbs: ["update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: intent-operator-manager-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: intent-operator-manager-role
subjects:
- kind: ServiceAccount
  name: intent-operator-controller-manager
  namespace: $NAMESPACE
EOF

# 7. Wait for operator to be ready
echo ""
echo "Step 7: Waiting for operator to be ready..."
kubectl --context "$MGMT_CONTEXT" wait --for=condition=available \
    --timeout=60s deployment/intent-operator-controller-manager \
    -n "$NAMESPACE"

# 8. Verify operator status
echo ""
echo "Step 8: Verifying operator status..."
kubectl --context "$MGMT_CONTEXT" get pods -n "$NAMESPACE"
kubectl --context "$MGMT_CONTEXT" logs -n "$NAMESPACE" \
    deployment/intent-operator-controller-manager \
    --tail=20

# 9. Apply sample CRs
echo ""
echo "Step 9: Applying sample IntentDeployments..."
for site in edge1 edge2 both; do
    echo "Applying $site deployment..."
    kubectl --context "$MGMT_CONTEXT" apply -f \
        operator/config/samples/tna_v1alpha1_intentdeployment_${site}.yaml
done

# 10. Check CR status
echo ""
echo "Step 10: Checking IntentDeployment status..."
sleep 5
kubectl --context "$MGMT_CONTEXT" get intentdeployments -A \
    -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,MESSAGE:.status.message

echo ""
echo "======================================"
echo "✓ Operator deployment complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Monitor phase transitions:"
echo "   watch 'kubectl --context $MGMT_CONTEXT get intentdeployments -A'"
echo ""
echo "2. Check operator logs:"
echo "   kubectl --context $MGMT_CONTEXT logs -f -n $NAMESPACE deploy/intent-operator-controller-manager"
echo ""
echo "3. Run E2E validation:"
echo "   make -f Makefile.summit summit-operator"
echo ""
echo "4. Switch modes if needed:"
echo "   kubectl --context $MGMT_CONTEXT set env -n $NAMESPACE deploy/intent-operator-controller-manager PIPELINE_MODE=standalone"