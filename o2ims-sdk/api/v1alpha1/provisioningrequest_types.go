package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// EDIT THIS FILE!  This is scaffolding for you to own.
// NOTE: json tags are required.  Any new fields you add must have json:"-" or json:"fieldName,omitempty" tags for them to be serialized.

// ProvisioningRequestSpec defines the desired state of ProvisioningRequest
type ProvisioningRequestSpec struct {
	// TargetCluster specifies the target cluster for provisioning
	// +kubebuilder:validation:Required
	TargetCluster string `json:"targetCluster"`

	// ResourceRequirements specifies the resource requirements
	// +kubebuilder:validation:Required
	ResourceRequirements ResourceRequirements `json:"resourceRequirements"`

	// NetworkConfig specifies the network configuration
	// +kubebuilder:validation:Optional
	NetworkConfig *NetworkConfig `json:"networkConfig,omitempty"`

	// Description provides a human-readable description of the provisioning request
	// +kubebuilder:validation:Optional
	Description string `json:"description,omitempty"`
}

// ResourceRequirements defines resource requirements for provisioning
type ResourceRequirements struct {
	// CPU specifies CPU requirements (e.g., "2000m")
	// +kubebuilder:validation:Required
	CPU string `json:"cpu"`

	// Memory specifies memory requirements (e.g., "4Gi")
	// +kubebuilder:validation:Required
	Memory string `json:"memory"`

	// Storage specifies storage requirements (e.g., "10Gi")
	// +kubebuilder:validation:Optional
	Storage string `json:"storage,omitempty"`
}

// NetworkConfig defines network configuration
type NetworkConfig struct {
	// VLAN specifies the VLAN ID
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=4094
	VLAN *int32 `json:"vlan,omitempty"`

	// Subnet specifies the subnet CIDR
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Pattern=`^([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$`
	Subnet string `json:"subnet,omitempty"`

	// Gateway specifies the gateway IP
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Pattern=`^([0-9]{1,3}\.){3}[0-9]{1,3}$`
	Gateway string `json:"gateway,omitempty"`
}

// ProvisioningRequestConditionType represents the type of condition
type ProvisioningRequestConditionType string

const (
	// ConditionTypePending indicates the request is pending
	ConditionTypePending ProvisioningRequestConditionType = "Pending"
	// ConditionTypeProcessing indicates the request is being processed
	ConditionTypeProcessing ProvisioningRequestConditionType = "Processing"
	// ConditionTypeReady indicates the request is ready/completed
	ConditionTypeReady ProvisioningRequestConditionType = "Ready"
	// ConditionTypeFailed indicates the request has failed
	ConditionTypeFailed ProvisioningRequestConditionType = "Failed"
)

// ProvisioningRequestCondition represents a condition for ProvisioningRequest
type ProvisioningRequestCondition struct {
	// Type is the type of condition
	Type ProvisioningRequestConditionType `json:"type"`

	// Status is the status of the condition (True, False, Unknown)
	Status metav1.ConditionStatus `json:"status"`

	// LastTransitionTime is the last time the condition transitioned
	LastTransitionTime metav1.Time `json:"lastTransitionTime"`

	// Reason is a brief CamelCase string that describes any failure
	// +kubebuilder:validation:Optional
	Reason string `json:"reason,omitempty"`

	// Message is a human-readable description of the condition
	// +kubebuilder:validation:Optional
	Message string `json:"message,omitempty"`
}

// ProvisioningRequestStatus defines the observed state of ProvisioningRequest
type ProvisioningRequestStatus struct {
	// ObservedGeneration reflects the generation of the most recently observed ProvisioningRequest
	// +kubebuilder:validation:Optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// Conditions represent the current conditions of the ProvisioningRequest
	// +kubebuilder:validation:Optional
	Conditions []ProvisioningRequestCondition `json:"conditions,omitempty"`

	// Phase represents the current phase of the ProvisioningRequest
	// +kubebuilder:validation:Optional
	Phase string `json:"phase,omitempty"`

	// ProvisionedResources contains information about provisioned resources
	// +kubebuilder:validation:Optional
	ProvisionedResources map[string]string `json:"provisionedResources,omitempty"`
}

// ProvisioningRequest is the Schema for the provisioningrequests API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Namespaced,shortName=pr
// +kubebuilder:printcolumn:name="Target",type=string,JSONPath=`.spec.targetCluster`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type ProvisioningRequest struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ProvisioningRequestSpec   `json:"spec,omitempty"`
	Status ProvisioningRequestStatus `json:"status,omitempty"`
}

// ProvisioningRequestList contains a list of ProvisioningRequest
// +kubebuilder:object:root=true
type ProvisioningRequestList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ProvisioningRequest `json:"items"`
}

// DeepCopyObject implements runtime.Object
func (in *ProvisioningRequest) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopyObject implements runtime.Object
func (in *ProvisioningRequestList) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}


// DeepCopy implementations for runtime.Object interface

func (in *ProvisioningRequest) DeepCopy() *ProvisioningRequest {
	if in == nil {
		return nil
	}
	out := new(ProvisioningRequest)
	in.DeepCopyInto(out)
	return out
}

func (in *ProvisioningRequest) DeepCopyInto(out *ProvisioningRequest) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	in.Spec.DeepCopyInto(&out.Spec)
	in.Status.DeepCopyInto(&out.Status)
}

func (in *ProvisioningRequestList) DeepCopy() *ProvisioningRequestList {
	if in == nil {
		return nil
	}
	out := new(ProvisioningRequestList)
	in.DeepCopyInto(out)
	return out
}

func (in *ProvisioningRequestList) DeepCopyInto(out *ProvisioningRequestList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	if in.Items != nil {
		in, out := &in.Items, &out.Items
		*out = make([]ProvisioningRequest, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
}

func (in *ProvisioningRequestSpec) DeepCopy() *ProvisioningRequestSpec {
	if in == nil {
		return nil
	}
	out := new(ProvisioningRequestSpec)
	in.DeepCopyInto(out)
	return out
}

func (in *ProvisioningRequestSpec) DeepCopyInto(out *ProvisioningRequestSpec) {
	*out = *in
	in.ResourceRequirements.DeepCopyInto(&out.ResourceRequirements)
	if in.NetworkConfig != nil {
		in, out := &in.NetworkConfig, &out.NetworkConfig
		*out = new(NetworkConfig)
		(*in).DeepCopyInto(*out)
	}
}

func (in *ProvisioningRequestStatus) DeepCopy() *ProvisioningRequestStatus {
	if in == nil {
		return nil
	}
	out := new(ProvisioningRequestStatus)
	in.DeepCopyInto(out)
	return out
}

func (in *ProvisioningRequestStatus) DeepCopyInto(out *ProvisioningRequestStatus) {
	*out = *in
	if in.Conditions != nil {
		in, out := &in.Conditions, &out.Conditions
		*out = make([]ProvisioningRequestCondition, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
	if in.ProvisionedResources != nil {
		in, out := &in.ProvisionedResources, &out.ProvisionedResources
		*out = make(map[string]string, len(*in))
		for key, val := range *in {
			(*out)[key] = val
		}
	}
}

func (in *ProvisioningRequestCondition) DeepCopy() *ProvisioningRequestCondition {
	if in == nil {
		return nil
	}
	out := new(ProvisioningRequestCondition)
	in.DeepCopyInto(out)
	return out
}

func (in *ProvisioningRequestCondition) DeepCopyInto(out *ProvisioningRequestCondition) {
	*out = *in
	in.LastTransitionTime.DeepCopyInto(&out.LastTransitionTime)
}

func (in *ResourceRequirements) DeepCopy() *ResourceRequirements {
	if in == nil {
		return nil
	}
	out := new(ResourceRequirements)
	in.DeepCopyInto(out)
	return out
}

func (in *ResourceRequirements) DeepCopyInto(out *ResourceRequirements) {
	*out = *in
}

func (in *NetworkConfig) DeepCopy() *NetworkConfig {
	if in == nil {
		return nil
	}
	out := new(NetworkConfig)
	in.DeepCopyInto(out)
	return out
}

func (in *NetworkConfig) DeepCopyInto(out *NetworkConfig) {
	*out = *in
	if in.VLAN != nil {
		in, out := &in.VLAN, &out.VLAN
		*out = new(int32)
		**out = **in
	}
}

func init() {
	SchemeBuilder.Register(&ProvisioningRequest{}, &ProvisioningRequestList{})
}