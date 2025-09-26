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

package v1alpha1

import (
	"fmt"

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	// "sigs.k8s.io/controller-runtime/pkg/webhook"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

const (
	// IntentDeployment phases
	PhasePending = "Pending"
)

// log is for logging in this package.
var intentdeploymentlog = logf.Log.WithName("intentdeployment-resource")

func (r *IntentDeployment) SetupWebhookWithManager(mgr ctrl.Manager) error {
	if mgr == nil {
		return fmt.Errorf("manager cannot be nil")
	}
	return ctrl.NewWebhookManagedBy(mgr).
		For(r).
		Complete()
}

// +kubebuilder:webhook:path=/validate-tna-tna-ai-v1alpha1-intentdeployment,mutating=false,failurePolicy=fail,sideEffects=None,groups=tna.tna.ai,resources=intentdeployments,verbs=create;update,versions=v1alpha1,name=vintentdeployment.kb.io,admissionReviewVersions=v1

// Webhook temporarily disabled for compatibility
// var _ webhook.Validator = &IntentDeployment{}

// ValidateCreate implements webhook.Validator so a webhook will be registered for the type
func (r *IntentDeployment) ValidateCreate() (admission.Warnings, error) {
	intentdeploymentlog.Info("validate create", "name", r.ObjectMeta.Name)

	// Validate intent is not empty
	if r.Spec.Intent == "" {
		return nil, fmt.Errorf("spec.intent cannot be empty")
	}

	// Validate target site
	if r.Spec.DeliveryConfig != nil && r.Spec.DeliveryConfig.TargetSite != "" {
		switch r.Spec.DeliveryConfig.TargetSite {
		case "edge1", "edge2", "both":
			// Valid sites
		default:
			return nil, fmt.Errorf("invalid target site: %s", r.Spec.DeliveryConfig.TargetSite)
		}
	}

	return nil, nil
}

// ValidateUpdate implements webhook.Validator so a webhook will be registered for the type
func (r *IntentDeployment) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
	intentdeploymentlog.Info("validate update", "name", r.ObjectMeta.Name)

	// Cannot change intent once deployment has started
	oldID, ok := old.(*IntentDeployment)
	if !ok {
		return nil, fmt.Errorf("expected old object to be IntentDeployment")
	}
	if oldID.Status.Phase != "" && oldID.Status.Phase != PhasePending {
		if r.Spec.Intent != oldID.Spec.Intent {
			return nil, fmt.Errorf("cannot modify intent after deployment has started")
		}
	}

	return nil, nil
}

// ValidateDelete implements webhook.Validator so a webhook will be registered for the type
func (r *IntentDeployment) ValidateDelete() (admission.Warnings, error) {
	intentdeploymentlog.Info("validate delete", "name", r.ObjectMeta.Name)

	// Add cleanup validation if needed
	return nil, nil
}
