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
	"testing"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestIntentDeployment_ValidateCreate(t *testing.T) {
	tests := []struct {
		name      string
		intent    IntentDeployment
		wantErr   bool
		errString string
	}{
		{
			name: "valid intent with minimal spec",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "test-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
				},
			},
			wantErr: false,
		},
		{
			name: "empty intent should fail",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "empty-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: "",
				},
			},
			wantErr:   true,
			errString: "spec.intent cannot be empty",
		},
		{
			name: "valid target site edge1",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "edge1-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
					DeliveryConfig: &DeliveryConfig{
						TargetSite: "edge1",
					},
				},
			},
			wantErr: false,
		},
		{
			name: "valid target site edge2",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "edge2-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
					DeliveryConfig: &DeliveryConfig{
						TargetSite: "edge2",
					},
				},
			},
			wantErr: false,
		},
		{
			name: "valid target site both",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "both-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
					DeliveryConfig: &DeliveryConfig{
						TargetSite: "both",
					},
				},
			},
			wantErr: false,
		},
		{
			name: "invalid target site should fail",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "invalid-site",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
					DeliveryConfig: &DeliveryConfig{
						TargetSite: "invalid-site",
					},
				},
			},
			wantErr:   true,
			errString: "invalid target site: invalid-site",
		},
		{
			name: "empty target site is valid (will use default)",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "empty-site",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
					DeliveryConfig: &DeliveryConfig{
						TargetSite: "",
					},
				},
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			warnings, err := tt.intent.ValidateCreate()
			if (err != nil) != tt.wantErr {
				t.Errorf("IntentDeployment.ValidateCreate() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr && err != nil && err.Error() != tt.errString {
				t.Errorf("IntentDeployment.ValidateCreate() error = %v, want %v", err.Error(), tt.errString)
			}
			if warnings != nil && len(warnings) > 0 {
				t.Logf("ValidateCreate warnings: %v", warnings)
			}
		})
	}
}

func TestIntentDeployment_ValidateUpdate(t *testing.T) {
	tests := []struct {
		name      string
		old       *IntentDeployment
		new       *IntentDeployment
		wantErr   bool
		errString string
	}{
		{
			name: "can update intent in pending phase",
			old: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "old-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: PhasePending,
				},
			},
			new: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "new-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: PhasePending,
				},
			},
			wantErr: false,
		},
		{
			name: "can update intent when phase is empty",
			old: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "old-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "",
				},
			},
			new: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "new-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "",
				},
			},
			wantErr: false,
		},
		{
			name: "cannot update intent after deployment started",
			old: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "old-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Compiling",
				},
			},
			new: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "new-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Compiling",
				},
			},
			wantErr:   true,
			errString: "cannot modify intent after deployment has started",
		},
		{
			name: "can update other fields after deployment started",
			old: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "app"}`,
					CompileConfig: &CompileConfig{
						Engine: "kpt",
					},
				},
				Status: IntentDeploymentStatus{
					Phase: "Compiling",
				},
			},
			new: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "app"}`, // Same intent
					CompileConfig: &CompileConfig{
						Engine:        "kpt",
						RenderTimeout: "10m", // Different field
					},
				},
				Status: IntentDeploymentStatus{
					Phase: "Compiling",
				},
			},
			wantErr: false,
		},
		{
			name: "cannot update intent in succeeded phase",
			old: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "old-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Succeeded",
				},
			},
			new: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "new-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Succeeded",
				},
			},
			wantErr:   true,
			errString: "cannot modify intent after deployment has started",
		},
		{
			name: "cannot update intent in failed phase",
			old: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "old-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Failed",
				},
			},
			new: &IntentDeployment{
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "new-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Failed",
				},
			},
			wantErr:   true,
			errString: "cannot modify intent after deployment has started",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			warnings, err := tt.new.ValidateUpdate(tt.old)
			if (err != nil) != tt.wantErr {
				t.Errorf("IntentDeployment.ValidateUpdate() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr && err != nil && err.Error() != tt.errString {
				t.Errorf("IntentDeployment.ValidateUpdate() error = %v, want %v", err.Error(), tt.errString)
			}
			if warnings != nil && len(warnings) > 0 {
				t.Logf("ValidateUpdate warnings: %v", warnings)
			}
		})
	}
}

func TestIntentDeployment_ValidateDelete(t *testing.T) {
	tests := []struct {
		name    string
		intent  IntentDeployment
		wantErr bool
	}{
		{
			name: "can delete intent in any phase",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "test-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Succeeded",
				},
			},
			wantErr: false,
		},
		{
			name: "can delete pending intent",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "pending-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: PhasePending,
				},
			},
			wantErr: false,
		},
		{
			name: "can delete failed intent",
			intent: IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "failed-intent",
					Namespace: "default",
				},
				Spec: IntentDeploymentSpec{
					Intent: `{"service": "test-app"}`,
				},
				Status: IntentDeploymentStatus{
					Phase: "Failed",
				},
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			warnings, err := tt.intent.ValidateDelete()
			if (err != nil) != tt.wantErr {
				t.Errorf("IntentDeployment.ValidateDelete() error = %v, wantErr %v", err, tt.wantErr)
			}
			if warnings != nil && len(warnings) > 0 {
				t.Logf("ValidateDelete warnings: %v", warnings)
			}
		})
	}
}

func TestIntentDeployment_SetupWebhookWithManager(t *testing.T) {
	// This test verifies the method exists and can be called
	// In a real test environment, you'd need an actual manager
	intent := &IntentDeployment{}

	// We can't test the actual setup without a manager, but we can verify
	// the method signature and that it has the expected behavior

	// Test with nil manager (should return error, not panic)
	err := intent.SetupWebhookWithManager(nil)
	if err == nil {
		t.Error("SetupWebhookWithManager should return error with nil manager")
	}
}
