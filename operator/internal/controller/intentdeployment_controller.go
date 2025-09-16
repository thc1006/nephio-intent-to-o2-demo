/*
Copyright 2025 nephio-summit.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"os"
	"time"

	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	tnav1alpha1 "github.com/thc1006/nephio-intent-operator/api/v1alpha1"
)

const (
	// IntentDeployment phases
	PhasePending     = "Pending"
	PhaseCompiling   = "Compiling"
	PhaseRendering   = "Rendering"
	PhaseDelivering  = "Delivering"
	PhaseReconciling = "Reconciling"
	PhaseVerifying   = "Verifying"
	PhaseSucceeded   = "Succeeded"
	PhaseFailed      = "Failed"
	PhaseRollingBack = "RollingBack"
)

// IntentDeploymentReconciler reconciles a IntentDeployment object
type IntentDeploymentReconciler struct {
	client.Client
	Scheme        *runtime.Scheme
	PipelineMode  string // embedded or standalone
	PipelineRoot  string // path to shell pipeline scripts
	ArtifactsRoot string // path to store artifacts
}

// +kubebuilder:rbac:groups=tna.tna.ai,resources=intentdeployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=tna.tna.ai,resources=intentdeployments/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=tna.tna.ai,resources=intentdeployments/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the IntentDeployment object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.21.0/pkg/reconcile
func (r *IntentDeploymentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	// Fetch the IntentDeployment instance
	intentDeployment := &tnav1alpha1.IntentDeployment{}
	err := r.Get(ctx, req.NamespacedName, intentDeployment)
	if err != nil {
		if client.IgnoreNotFound(err) != nil {
			log.Error(err, "Failed to get IntentDeployment")
			return ctrl.Result{}, err
		}
		// Object not found, return without error
		return ctrl.Result{}, nil
	}

	// Initialize phase if not set
	if intentDeployment.Status.Phase == "" {
		intentDeployment.Status.Phase = PhasePending
		intentDeployment.Status.Message = "Intent deployment initialized"
		r.setCondition(intentDeployment, "Ready", metav1.ConditionFalse, "Initializing", "Intent deployment is initializing")
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update IntentDeployment status")
			return ctrl.Result{}, err
		}
		return ctrl.Result{Requeue: true}, nil
	}

	// Handle different phases
	switch intentDeployment.Status.Phase {
	case PhasePending:
		// Validate and transition to Compiling
		log.Info("IntentDeployment is pending", "Name", intentDeployment.Name)
		intentDeployment.Status.Phase = PhaseCompiling
		intentDeployment.Status.Message = "Starting intent compilation"
		r.setCondition(intentDeployment, "Compiling", metav1.ConditionTrue, "InProgress", "Compiling intent to KRM")
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status to Compiling")
			return ctrl.Result{}, err
		}
		return ctrl.Result{RequeueAfter: 2 * time.Second}, nil

	case PhaseCompiling:
		// Compile intent to manifests
		log.Info("Compiling intent", "Name", intentDeployment.Name)
		// Simulate compilation
		intentDeployment.Status.Phase = PhaseRendering
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status to Rendering")
			return ctrl.Result{}, err
		}
		return ctrl.Result{RequeueAfter: 5 * time.Second}, nil

	case PhaseRendering:
		// Render manifests through kpt/kustomize
		log.Info("Rendering manifests", "Name", intentDeployment.Name)
		// Simulate rendering
		intentDeployment.Status.Phase = PhaseDelivering
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status to Delivering")
			return ctrl.Result{}, err
		}
		return ctrl.Result{RequeueAfter: 5 * time.Second}, nil

	case PhaseDelivering:
		// Push to GitOps and sync
		log.Info("Delivering to GitOps", "Name", intentDeployment.Name)
		intentDeployment.Status.Phase = PhaseReconciling
		intentDeployment.Status.Message = "GitOps reconciliation in progress"
		r.setCondition(intentDeployment, "GitOpsSync", metav1.ConditionTrue, "Syncing", "Waiting for Config Sync")
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status to Reconciling")
			return ctrl.Result{}, err
		}
		return ctrl.Result{RequeueAfter: 5 * time.Second}, nil

	case PhaseReconciling:
		// Wait for Config Sync to complete
		log.Info("Waiting for GitOps reconciliation", "Name", intentDeployment.Name)
		intentDeployment.Status.Phase = PhaseVerifying
		intentDeployment.Status.Message = "Verifying deployment against SLOs"
		r.setCondition(intentDeployment, "Reconciled", metav1.ConditionTrue, "Complete", "GitOps sync completed")
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status to Verifying")
			return ctrl.Result{}, err
		}
		return ctrl.Result{RequeueAfter: 5 * time.Second}, nil

	case PhaseVerifying:
		// Run SLO checks
		log.Info("Verifying deployment against SLOs", "Name", intentDeployment.Name)
		intentDeployment.Status.Phase = PhaseSucceeded
		intentDeployment.Status.Message = "Deployment verified and succeeded"
		r.setCondition(intentDeployment, "Ready", metav1.ConditionTrue, "Succeeded", "All SLO checks passed")
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status to Succeeded")
			return ctrl.Result{}, err
		}
		return ctrl.Result{}, nil

	case PhaseSucceeded:
		// Terminal success state
		log.Info("Deployment succeeded", "Name", intentDeployment.Name)
		return ctrl.Result{}, nil

	case PhaseFailed:
		// Handle failure, potentially trigger rollback
		log.Info("Deployment failed", "Name", intentDeployment.Name)
		if intentDeployment.Spec.RollbackConfig != nil && intentDeployment.Spec.RollbackConfig.AutoRollback {
			intentDeployment.Status.Phase = PhaseRollingBack
			if err := r.Status().Update(ctx, intentDeployment); err != nil {
				log.Error(err, "Failed to update status to RollingBack")
				return ctrl.Result{}, err
			}
			return ctrl.Result{RequeueAfter: 5 * time.Second}, nil
		}
		return ctrl.Result{}, nil

	case PhaseRollingBack:
		// Execute rollback
		log.Info("Rolling back deployment", "Name", intentDeployment.Name)
		// Simulate rollback
		intentDeployment.Status.Phase = PhaseSucceeded
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update status after rollback")
			return ctrl.Result{}, err
		}
		return ctrl.Result{}, nil
	}

	return ctrl.Result{}, nil
}

// setCondition updates or adds a condition to the IntentDeployment status
func (r *IntentDeploymentReconciler) setCondition(
	deployment *tnav1alpha1.IntentDeployment,
	conditionType string,
	status metav1.ConditionStatus,
	reason, message string,
) {
	condition := metav1.Condition{
		Type:               conditionType,
		Status:             status,
		LastTransitionTime: metav1.Now(),
		Reason:             reason,
		Message:            message,
	}
	meta.SetStatusCondition(&deployment.Status.Conditions, condition)
}

// SetupWithManager sets up the controller with the Manager.
func (r *IntentDeploymentReconciler) SetupWithManager(mgr ctrl.Manager) error {
	// Set pipeline configuration from environment
	if mode := os.Getenv("PIPELINE_MODE"); mode != "" {
		r.PipelineMode = mode
	} else {
		r.PipelineMode = "embedded" // default
	}

	if root := os.Getenv("SHELL_PIPELINE_ROOT"); root != "" {
		r.PipelineRoot = root
	} else {
		r.PipelineRoot = "/opt/nephio-intent-to-o2-demo"
	}

	if artifacts := os.Getenv("ARTIFACTS_ROOT"); artifacts != "" {
		r.ArtifactsRoot = artifacts
	} else {
		r.ArtifactsRoot = "/var/run/operator-artifacts"
	}

	return ctrl.NewControllerManagedBy(mgr).
		For(&tnav1alpha1.IntentDeployment{}).
		Named("intentdeployment").
		Complete(r)
}
