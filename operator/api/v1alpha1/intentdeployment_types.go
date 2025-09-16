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
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// IntentDeploymentSpec defines the desired state of IntentDeployment
type IntentDeploymentSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Intent represents the original natural language or JSON intent
	// +kubebuilder:validation:Required
	Intent string `json:"intent"`

	// CompileConfig contains settings for the intent compilation process
	// +optional
	CompileConfig *CompileConfig `json:"compileConfig,omitempty"`

	// DeliveryConfig contains settings for resource delivery
	// +optional
	DeliveryConfig *DeliveryConfig `json:"deliveryConfig,omitempty"`

	// GatesConfig contains SLO/validation gate configurations
	// +optional
	GatesConfig *GatesConfig `json:"gatesConfig,omitempty"`

	// RollbackConfig contains rollback policies and triggers
	// +optional
	RollbackConfig *RollbackConfig `json:"rollbackConfig,omitempty"`
}

// CompileConfig defines intent compilation settings
type CompileConfig struct {
	// Engine specifies the compilation engine to use
	// +kubebuilder:validation:Enum=kpt;kustomize;helm
	// +kubebuilder:default=kpt
	Engine string `json:"engine,omitempty"`

	// RenderTimeout is the maximum time allowed for rendering
	// +kubebuilder:default="5m"
	// +optional
	RenderTimeout string `json:"renderTimeout,omitempty"`
}

// DeliveryConfig defines resource delivery settings
type DeliveryConfig struct {
	// TargetSite specifies where to deploy (edge1|edge2|both)
	// +kubebuilder:validation:Enum=edge1;edge2;both
	// +kubebuilder:default=both
	TargetSite string `json:"targetSite,omitempty"`

	// GitOpsRepo is the repository URL for GitOps sync
	// +optional
	GitOpsRepo string `json:"gitOpsRepo,omitempty"`

	// SyncWaitTimeout is how long to wait for sync completion
	// +kubebuilder:default="10m"
	// +optional
	SyncWaitTimeout string `json:"syncWaitTimeout,omitempty"`
}

// GatesConfig defines validation gates
type GatesConfig struct {
	// Enabled determines if gates are active
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// SLOThresholds contains minimum acceptable metrics
	// +optional
	SLOThresholds map[string]string `json:"sloThresholds,omitempty"`

	// PostCheckScript is a custom validation script path
	// +optional
	PostCheckScript string `json:"postCheckScript,omitempty"`
}

// RollbackConfig defines rollback policies
type RollbackConfig struct {
	// AutoRollback enables automatic rollback on failure
	// +kubebuilder:default=true
	AutoRollback bool `json:"autoRollback,omitempty"`

	// MaxRetries before giving up
	// +kubebuilder:default=3
	MaxRetries int `json:"maxRetries,omitempty"`

	// RetainFailedArtifacts keeps debug information
	// +kubebuilder:default=true
	RetainFailedArtifacts bool `json:"retainFailedArtifacts,omitempty"`
}

// IntentDeploymentStatus defines the observed state of IntentDeployment.
type IntentDeploymentStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Phase represents the current lifecycle phase
	// +kubebuilder:validation:Enum=Pending;Compiling;Rendering;Delivering;Reconciling;Verifying;Succeeded;Failed;RollingBack
	Phase string `json:"phase,omitempty"`

	// Message provides human-readable status information
	// +optional
	Message string `json:"message,omitempty"`

	// CompiledManifests contains the generated KRM manifests
	// +optional
	CompiledManifests string `json:"compiledManifests,omitempty"`

	// DeliveryStatus tracks GitOps sync state
	// +optional
	DeliveryStatus *DeliveryStatus `json:"deliveryStatus,omitempty"`

	// ValidationResults contains gate check outcomes
	// +optional
	ValidationResults []ValidationResult `json:"validationResults,omitempty"`

	// RollbackStatus tracks rollback operations
	// +optional
	RollbackStatus *RollbackStatus `json:"rollbackStatus,omitempty"`

	// conditions represent the current state of the IntentDeployment resource
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// LastUpdateTime is the last time the status was updated
	// +optional
	LastUpdateTime *metav1.Time `json:"lastUpdateTime,omitempty"`

	// ObservedGeneration reflects the generation of the most recently observed IntentDeployment
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`
}

// DeliveryStatus tracks GitOps delivery state
type DeliveryStatus struct {
	// GitCommit is the commit SHA for this deployment
	GitCommit string `json:"gitCommit,omitempty"`

	// SyncState represents the GitOps sync status
	// +kubebuilder:validation:Enum=Pending;Syncing;Synced;Failed
	SyncState string `json:"syncState,omitempty"`

	// Sites contains per-site deployment status
	Sites map[string]SiteStatus `json:"sites,omitempty"`
}

// SiteStatus represents deployment status for a single site
type SiteStatus struct {
	// State of deployment at this site
	// +kubebuilder:validation:Enum=Pending;Deploying;Deployed;Failed
	State string `json:"state,omitempty"`

	// Message provides human-readable status
	Message string `json:"message,omitempty"`

	// LastSyncTime when resources were last synced
	LastSyncTime *metav1.Time `json:"lastSyncTime,omitempty"`
}

// ValidationResult represents a single validation outcome
type ValidationResult struct {
	// Name of the validation check
	Name string `json:"name"`

	// Passed indicates if the check succeeded
	Passed bool `json:"passed"`

	// Message provides details about the result
	Message string `json:"message,omitempty"`

	// Metrics contains numerical results
	Metrics map[string]string `json:"metrics,omitempty"`
}

// RollbackStatus tracks rollback operations
type RollbackStatus struct {
	// Active indicates if rollback is in progress
	Active bool `json:"active,omitempty"`

	// Reason for the rollback
	Reason string `json:"reason,omitempty"`

	// PreviousCommit being restored
	PreviousCommit string `json:"previousCommit,omitempty"`

	// Attempts made so far
	Attempts int `json:"attempts,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// IntentDeployment is the Schema for the intentdeployments API
type IntentDeployment struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty,omitzero"`

	// spec defines the desired state of IntentDeployment
	// +required
	Spec IntentDeploymentSpec `json:"spec"`

	// status defines the observed state of IntentDeployment
	// +optional
	Status IntentDeploymentStatus `json:"status,omitempty,omitzero"`
}

// +kubebuilder:object:root=true

// IntentDeploymentList contains a list of IntentDeployment
type IntentDeploymentList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []IntentDeployment `json:"items"`
}

func init() {
	SchemeBuilder.Register(&IntentDeployment{}, &IntentDeploymentList{})
}
