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

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	tnav1alpha1 "github.com/thc1006/nephio-intent-operator/api/v1alpha1"
)

// IntentDeploymentReconciler reconciles a IntentDeployment object
type IntentDeploymentReconciler struct {
	client.Client
	Scheme *runtime.Scheme
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
		intentDeployment.Status.Phase = "Pending"
		if err := r.Status().Update(ctx, intentDeployment); err != nil {
			log.Error(err, "Failed to update IntentDeployment status")
			return ctrl.Result{}, err
		}
		return ctrl.Result{Requeue: true}, nil
	}

	// Handle different phases
	switch intentDeployment.Status.Phase {
	case "Pending":
		// Validate and transition to Compiling
		log.Info("IntentDeployment is pending", "Name", intentDeployment.Name)
	case "Compiling":
		// Compile intent to manifests
		log.Info("Compiling intent", "Name", intentDeployment.Name)
	case "Rendering":
		// Render manifests through kpt/kustomize
		log.Info("Rendering manifests", "Name", intentDeployment.Name)
	case "Delivering":
		// Push to GitOps and sync
		log.Info("Delivering to GitOps", "Name", intentDeployment.Name)
	case "Validating":
		// Run SLO checks
		log.Info("Validating deployment", "Name", intentDeployment.Name)
	case "Succeeded":
		// Terminal success state
		log.Info("Deployment succeeded", "Name", intentDeployment.Name)
	case "Failed":
		// Handle failure, potentially trigger rollback
		log.Info("Deployment failed", "Name", intentDeployment.Name)
	case "RollingBack":
		// Execute rollback
		log.Info("Rolling back deployment", "Name", intentDeployment.Name)
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *IntentDeploymentReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&tnav1alpha1.IntentDeployment{}).
		Named("intentdeployment").
		Complete(r)
}
