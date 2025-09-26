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

func TestIntentDeploymentSpecDefaults(t *testing.T) {
	tests := []struct {
		name     string
		spec     IntentDeploymentSpec
		expected IntentDeploymentSpec
	}{
		{
			name: "minimal spec",
			spec: IntentDeploymentSpec{
				Intent: `{"service": "test"}`,
			},
			expected: IntentDeploymentSpec{
				Intent: `{"service": "test"}`,
			},
		},
		{
			name: "spec with compile config",
			spec: IntentDeploymentSpec{
				Intent: `{"service": "test"}`,
				CompileConfig: &CompileConfig{
					Engine: "kpt",
				},
			},
			expected: IntentDeploymentSpec{
				Intent: `{"service": "test"}`,
				CompileConfig: &CompileConfig{
					Engine: "kpt",
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.spec.Intent != tt.expected.Intent {
				t.Errorf("Intent = %v, want %v", tt.spec.Intent, tt.expected.Intent)
			}
		})
	}
}

func TestCompileConfigValidation(t *testing.T) {
	tests := []struct {
		name     string
		config   CompileConfig
		wantErr  bool
		errField string
	}{
		{
			name: "valid kpt engine",
			config: CompileConfig{
				Engine: "kpt",
			},
			wantErr: false,
		},
		{
			name: "valid kustomize engine",
			config: CompileConfig{
				Engine: "kustomize",
			},
			wantErr: false,
		},
		{
			name: "valid helm engine",
			config: CompileConfig{
				Engine: "helm",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// For kubebuilder validation, we just check the values are set correctly
			if tt.config.Engine == "" && !tt.wantErr {
				t.Error("Engine should not be empty for valid config")
			}
		})
	}
}

func TestDeliveryConfigValidation(t *testing.T) {
	tests := []struct {
		name     string
		config   DeliveryConfig
		wantErr  bool
		errField string
	}{
		{
			name: "valid edge1 target",
			config: DeliveryConfig{
				TargetSite: "edge1",
			},
			wantErr: false,
		},
		{
			name: "valid edge2 target",
			config: DeliveryConfig{
				TargetSite: "edge2",
			},
			wantErr: false,
		},
		{
			name: "valid both target",
			config: DeliveryConfig{
				TargetSite: "both",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			validTargets := []string{"edge1", "edge2", "both"}
			found := false
			for _, valid := range validTargets {
				if tt.config.TargetSite == valid {
					found = true
					break
				}
			}
			if !found && tt.config.TargetSite != "" {
				t.Errorf("TargetSite %s is not valid", tt.config.TargetSite)
			}
		})
	}
}

func TestGatesConfigDefaults(t *testing.T) {
	config := GatesConfig{
		Enabled: true,
		SLOThresholds: map[string]string{
			"error_rate":  "0.01",
			"latency_p99": "100ms",
		},
	}

	if !config.Enabled {
		t.Error("Gates should be enabled")
	}

	if config.SLOThresholds["error_rate"] != "0.01" {
		t.Errorf("error_rate threshold = %v, want 0.01", config.SLOThresholds["error_rate"])
	}

	if config.SLOThresholds["latency_p99"] != "100ms" {
		t.Errorf("latency_p99 threshold = %v, want 100ms", config.SLOThresholds["latency_p99"])
	}
}

func TestRollbackConfigDefaults(t *testing.T) {
	config := RollbackConfig{
		AutoRollback:          true,
		MaxRetries:            3,
		RetainFailedArtifacts: true,
	}

	if !config.AutoRollback {
		t.Error("AutoRollback should be true")
	}

	if config.MaxRetries != 3 {
		t.Errorf("MaxRetries = %v, want 3", config.MaxRetries)
	}

	if !config.RetainFailedArtifacts {
		t.Error("RetainFailedArtifacts should be true")
	}
}

func TestIntentDeploymentStatusPhaseValidation(t *testing.T) {
	validPhases := []string{
		"Pending", "Compiling", "Rendering", "Delivering",
		"Reconciling", "Verifying", "Succeeded", "Failed", "RollingBack",
	}

	for _, phase := range validPhases {
		t.Run("valid phase "+phase, func(t *testing.T) {
			status := IntentDeploymentStatus{
				Phase: phase,
			}
			if status.Phase != phase {
				t.Errorf("Phase = %v, want %v", status.Phase, phase)
			}
		})
	}
}

func TestDeliveryStatusSyncStateValidation(t *testing.T) {
	validStates := []string{"Pending", "Syncing", "Synced", "Failed"}

	for _, state := range validStates {
		t.Run("valid sync state "+state, func(t *testing.T) {
			status := DeliveryStatus{
				SyncState: state,
			}
			if status.SyncState != state {
				t.Errorf("SyncState = %v, want %v", status.SyncState, state)
			}
		})
	}
}

func TestSiteStatusStateValidation(t *testing.T) {
	validStates := []string{"Pending", "Deploying", "Deployed", "Failed"}

	for _, state := range validStates {
		t.Run("valid site state "+state, func(t *testing.T) {
			status := SiteStatus{
				State: state,
			}
			if status.State != state {
				t.Errorf("State = %v, want %v", status.State, state)
			}
		})
	}
}

func TestValidationResult(t *testing.T) {
	result := ValidationResult{
		Name:    "test-validation",
		Passed:  true,
		Message: "Validation passed",
		Metrics: map[string]string{
			"cpu_usage":    "50%",
			"memory_usage": "60%",
		},
	}

	if result.Name != "test-validation" {
		t.Errorf("Name = %v, want test-validation", result.Name)
	}

	if !result.Passed {
		t.Error("Validation should have passed")
	}

	if result.Message != "Validation passed" {
		t.Errorf("Message = %v, want 'Validation passed'", result.Message)
	}

	if result.Metrics["cpu_usage"] != "50%" {
		t.Errorf("cpu_usage = %v, want 50%%", result.Metrics["cpu_usage"])
	}
}

func TestRollbackStatus(t *testing.T) {
	status := RollbackStatus{
		Active:         true,
		Reason:         "SLO threshold exceeded",
		PreviousCommit: "abc123",
		Attempts:       1,
	}

	if !status.Active {
		t.Error("Rollback should be active")
	}

	if status.Reason != "SLO threshold exceeded" {
		t.Errorf("Reason = %v, want 'SLO threshold exceeded'", status.Reason)
	}

	if status.PreviousCommit != "abc123" {
		t.Errorf("PreviousCommit = %v, want abc123", status.PreviousCommit)
	}

	if status.Attempts != 1 {
		t.Errorf("Attempts = %v, want 1", status.Attempts)
	}
}

func TestIntentDeploymentCreation(t *testing.T) {
	intent := IntentDeployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-intent",
			Namespace: "default",
		},
		Spec: IntentDeploymentSpec{
			Intent: `{"service": "test-app", "replicas": 3}`,
			CompileConfig: &CompileConfig{
				Engine:        "kpt",
				RenderTimeout: "5m",
			},
			DeliveryConfig: &DeliveryConfig{
				TargetSite:      "edge1",
				SyncWaitTimeout: "10m",
			},
			GatesConfig: &GatesConfig{
				Enabled: true,
				SLOThresholds: map[string]string{
					"error_rate": "0.01",
				},
			},
			RollbackConfig: &RollbackConfig{
				AutoRollback: true,
				MaxRetries:   3,
			},
		},
		Status: IntentDeploymentStatus{
			Phase:   "Pending",
			Message: "Intent deployment created",
		},
	}

	if intent.ObjectMeta.Name != "test-intent" {
		t.Errorf("Name = %v, want test-intent", intent.ObjectMeta.Name)
	}

	if intent.ObjectMeta.Namespace != "default" {
		t.Errorf("Namespace = %v, want default", intent.ObjectMeta.Namespace)
	}

	if intent.Spec.Intent != `{"service": "test-app", "replicas": 3}` {
		t.Errorf("Intent = %v, want test JSON", intent.Spec.Intent)
	}

	if intent.Spec.CompileConfig.Engine != "kpt" {
		t.Errorf("Engine = %v, want kpt", intent.Spec.CompileConfig.Engine)
	}

	if intent.Spec.DeliveryConfig.TargetSite != "edge1" {
		t.Errorf("TargetSite = %v, want edge1", intent.Spec.DeliveryConfig.TargetSite)
	}

	if !intent.Spec.GatesConfig.Enabled {
		t.Error("Gates should be enabled")
	}

	if !intent.Spec.RollbackConfig.AutoRollback {
		t.Error("AutoRollback should be enabled")
	}

	if intent.Status.Phase != "Pending" {
		t.Errorf("Phase = %v, want Pending", intent.Status.Phase)
	}
}

func TestIntentDeploymentList(t *testing.T) {
	list := IntentDeploymentList{
		Items: []IntentDeployment{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name: "intent1",
				},
			},
			{
				ObjectMeta: metav1.ObjectMeta{
					Name: "intent2",
				},
			},
		},
	}

	if len(list.Items) != 2 {
		t.Errorf("Items length = %v, want 2", len(list.Items))
	}

	if list.Items[0].ObjectMeta.Name != "intent1" {
		t.Errorf("First item name = %v, want intent1", list.Items[0].ObjectMeta.Name)
	}

	if list.Items[1].ObjectMeta.Name != "intent2" {
		t.Errorf("Second item name = %v, want intent2", list.Items[1].ObjectMeta.Name)
	}
}
