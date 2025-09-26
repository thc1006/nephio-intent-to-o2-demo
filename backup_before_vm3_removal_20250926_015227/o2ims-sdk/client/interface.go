package client

import (
	"context"
	"time"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// O2IMSClient defines the interface for O2 IMS operations
type O2IMSClient interface {
	// ProvisioningRequests returns a ProvisioningRequestInterface
	ProvisioningRequests(namespace string) ProvisioningRequestInterface
}

// ProvisioningRequestInterface defines operations for ProvisioningRequest resources
type ProvisioningRequestInterface interface {
	// Create creates a new ProvisioningRequest
	Create(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.CreateOptions) (*o2imsv1alpha1.ProvisioningRequest, error)

	// Update updates an existing ProvisioningRequest
	Update(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.UpdateOptions) (*o2imsv1alpha1.ProvisioningRequest, error)

	// UpdateStatus updates the status subresource of a ProvisioningRequest
	UpdateStatus(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.UpdateOptions) (*o2imsv1alpha1.ProvisioningRequest, error)

	// Delete deletes a ProvisioningRequest
	Delete(ctx context.Context, name string, opts metav1.DeleteOptions) error

	// DeleteCollection deletes a collection of ProvisioningRequest objects
	DeleteCollection(ctx context.Context, opts metav1.DeleteOptions, listOpts metav1.ListOptions) error

	// Get retrieves a ProvisioningRequest by name
	Get(ctx context.Context, name string, opts metav1.GetOptions) (*o2imsv1alpha1.ProvisioningRequest, error)

	// List retrieves a list of ProvisioningRequest objects
	List(ctx context.Context, opts metav1.ListOptions) (*o2imsv1alpha1.ProvisioningRequestList, error)

	// Watch returns a watch.Interface that watches ProvisioningRequest objects
	Watch(ctx context.Context, opts metav1.ListOptions) (WatchInterface, error)

	// Patch applies a patch to a ProvisioningRequest
	Patch(ctx context.Context, name string, pt PatchType, data []byte, opts metav1.PatchOptions, subresources ...string) (*o2imsv1alpha1.ProvisioningRequest, error)

	// WaitForCondition waits for a specific condition on a ProvisioningRequest
	WaitForCondition(ctx context.Context, name string, conditionType o2imsv1alpha1.ProvisioningRequestConditionType, timeout time.Duration) (*o2imsv1alpha1.ProvisioningRequest, error)

	// WaitForReady waits for a ProvisioningRequest to become Ready
	WaitForReady(ctx context.Context, name string, timeout time.Duration) (*o2imsv1alpha1.ProvisioningRequest, error)
}

// WatchInterface defines the interface for watching Kubernetes resources
type WatchInterface interface {
	// Stop stops watching. Will close the channel returned by ResultChan().
	Stop()

	// ResultChan returns a channel that will receive all the events.
	ResultChan() <-chan WatchEvent
}

// WatchEvent represents a watch event
type WatchEvent struct {
	Type   WatchEventType
	Object *o2imsv1alpha1.ProvisioningRequest
}

// WatchEventType defines the type of watch event
type WatchEventType string

const (
	// Added represents an added event
	Added WatchEventType = "ADDED"
	// Modified represents a modified event
	Modified WatchEventType = "MODIFIED"
	// Deleted represents a deleted event
	Deleted WatchEventType = "DELETED"
	// Bookmark represents a bookmark event
	Bookmark WatchEventType = "BOOKMARK"
	// Error represents an error event
	Error WatchEventType = "ERROR"
)

// PatchType defines the type of patch operation
type PatchType string

const (
	// JSONPatchType represents a JSON patch
	JSONPatchType PatchType = "application/json-patch+json"
	// MergePatchType represents a merge patch
	MergePatchType PatchType = "application/merge-patch+json"
	// StrategicMergePatchType represents a strategic merge patch
	StrategicMergePatchType PatchType = "application/strategic-merge-patch+json"
)