package client

import (
	"context"
	"fmt"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
)

// ClientConfig holds configuration for the O2 IMS client
type ClientConfig struct {
	RestConfig *rest.Config
	Namespace  string
}

// o2imsClient implements the O2IMSClient interface
type o2imsClient struct {
	client    client.Client
	namespace string
}

// NewO2IMSClient creates a new O2 IMS client
func NewO2IMSClient(config ClientConfig) (O2IMSClient, error) {
	// Create controller-runtime client from rest config
	scheme := runtime.NewScheme()
	if err := o2imsv1alpha1.AddToScheme(scheme); err != nil {
		return nil, fmt.Errorf("failed to add o2ims scheme: %w", err)
	}
	
	ctrlClient, err := client.New(config.RestConfig, client.Options{Scheme: scheme})
	if err != nil {
		return nil, fmt.Errorf("failed to create controller-runtime client: %w", err)
	}
	
	return &o2imsClient{
		client:    ctrlClient,
		namespace: config.Namespace,
	}, nil
}

// NewO2IMSClientFromControllerRuntime creates a new O2 IMS client from controller-runtime client
func NewO2IMSClientFromControllerRuntime(client client.Client, namespace string) O2IMSClient {
	return &o2imsClient{
		client:    client,
		namespace: namespace,
	}
}

// ProvisioningRequests returns a ProvisioningRequestInterface for the given namespace
func (c *o2imsClient) ProvisioningRequests(namespace string) ProvisioningRequestInterface {
	if namespace == "" {
		namespace = c.namespace
	}
	return &provisioningRequestClient{
		client:    c.client,
		namespace: namespace,
	}
}

// provisioningRequestClient implements ProvisioningRequestInterface
type provisioningRequestClient struct {
	client    client.Client
	namespace string
}

// Create creates a new ProvisioningRequest
func (c *provisioningRequestClient) Create(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.CreateOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	// Set namespace if not specified
	if pr.Namespace == "" {
		pr.Namespace = c.namespace
	}
	
	// Initialize basic status
	now := metav1.Now()
	pr.Status = o2imsv1alpha1.ProvisioningRequestStatus{
		Phase:              "Pending",
		ObservedGeneration: pr.Generation,
		Conditions: []o2imsv1alpha1.ProvisioningRequestCondition{
			{
				Type:               o2imsv1alpha1.ConditionTypePending,
				Status:             metav1.ConditionTrue,
				LastTransitionTime: now,
				Reason:             "Created",
				Message:            "ProvisioningRequest has been created and is pending processing",
			},
		},
	}
	
	// Create the resource
	if err := c.client.Create(ctx, pr); err != nil {
		return nil, fmt.Errorf("failed to create ProvisioningRequest: %w", err)
	}
	
	return pr, nil
}

// Get retrieves a ProvisioningRequest by name
func (c *provisioningRequestClient) Get(ctx context.Context, name string, opts metav1.GetOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	pr := &o2imsv1alpha1.ProvisioningRequest{}
	key := client.ObjectKey{Name: name, Namespace: c.namespace}
	
	if err := c.client.Get(ctx, key, pr); err != nil {
		return nil, fmt.Errorf("failed to get ProvisioningRequest %s: %w", name, err)
	}
	
	return pr, nil
}

// List retrieves a list of ProvisioningRequest objects
func (c *provisioningRequestClient) List(ctx context.Context, opts metav1.ListOptions) (*o2imsv1alpha1.ProvisioningRequestList, error) {
	list := &o2imsv1alpha1.ProvisioningRequestList{}
	listOpts := []client.ListOption{
		client.InNamespace(c.namespace),
	}
	
	if opts.LabelSelector != "" {
		selector, err := metav1.ParseToLabelSelector(opts.LabelSelector)
		if err != nil {
			return nil, fmt.Errorf("invalid label selector: %w", err)
		}
		labelSelector, err := metav1.LabelSelectorAsSelector(selector)
		if err != nil {
			return nil, fmt.Errorf("invalid label selector: %w", err)
		}
		listOpts = append(listOpts, client.MatchingLabelsSelector{Selector: labelSelector})
	}
	
	if err := c.client.List(ctx, list, listOpts...); err != nil {
		return nil, fmt.Errorf("failed to list ProvisioningRequests: %w", err)
	}
	
	return list, nil
}

// Update updates an existing ProvisioningRequest
func (c *provisioningRequestClient) Update(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.UpdateOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	if err := c.client.Update(ctx, pr); err != nil {
		return nil, fmt.Errorf("failed to update ProvisioningRequest: %w", err)
	}
	return pr, nil
}

// UpdateStatus updates the status subresource of a ProvisioningRequest
func (c *provisioningRequestClient) UpdateStatus(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.UpdateOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	if err := c.client.Status().Update(ctx, pr); err != nil {
		return nil, fmt.Errorf("failed to update ProvisioningRequest status: %w", err)
	}
	return pr, nil
}

// Delete deletes a ProvisioningRequest
func (c *provisioningRequestClient) Delete(ctx context.Context, name string, opts metav1.DeleteOptions) error {
	pr := &o2imsv1alpha1.ProvisioningRequest{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: c.namespace,
		},
	}
	
	if err := c.client.Delete(ctx, pr); err != nil {
		return fmt.Errorf("failed to delete ProvisioningRequest %s: %w", name, err)
	}
	
	return nil
}

// DeleteCollection deletes a collection of ProvisioningRequest objects
func (c *provisioningRequestClient) DeleteCollection(ctx context.Context, opts metav1.DeleteOptions, listOpts metav1.ListOptions) error {
	list, err := c.List(ctx, listOpts)
	if err != nil {
		return fmt.Errorf("failed to list ProvisioningRequests for deletion: %w", err)
	}
	
	for _, item := range list.Items {
		if err := c.Delete(ctx, item.Name, opts); err != nil {
			return fmt.Errorf("failed to delete ProvisioningRequest %s: %w", item.Name, err)
		}
	}
	
	return nil
}

// Watch returns a watch.Interface that watches ProvisioningRequest objects
func (c *provisioningRequestClient) Watch(ctx context.Context, opts metav1.ListOptions) (WatchInterface, error) {
	// For real client, this would use controller-runtime's watch capabilities
	// For now, return a basic implementation
	return &watchInterface{ctx: ctx, client: c.client, namespace: c.namespace}, nil
}

// Patch applies a patch to a ProvisioningRequest
func (c *provisioningRequestClient) Patch(ctx context.Context, name string, pt PatchType, data []byte, opts metav1.PatchOptions, subresources ...string) (*o2imsv1alpha1.ProvisioningRequest, error) {
	pr := &o2imsv1alpha1.ProvisioningRequest{}
	key := client.ObjectKey{Name: name, Namespace: c.namespace}
	
	if err := c.client.Get(ctx, key, pr); err != nil {
		return nil, fmt.Errorf("failed to get ProvisioningRequest for patch: %w", err)
	}
	
	// For real implementation, this would apply the patch
	// For now, just return the object
	return pr, nil
}

// WaitForCondition waits for a specific condition on a ProvisioningRequest
func (c *provisioningRequestClient) WaitForCondition(ctx context.Context, name string, conditionType o2imsv1alpha1.ProvisioningRequestConditionType, timeout time.Duration) (*o2imsv1alpha1.ProvisioningRequest, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	
	for {
		select {
		case <-timeoutCtx.Done():
			return nil, fmt.Errorf("timeout waiting for condition %s on ProvisioningRequest %s", conditionType, name)
		case <-ticker.C:
			pr, err := c.Get(ctx, name, metav1.GetOptions{})
			if err != nil {
				continue
			}
			
			for _, condition := range pr.Status.Conditions {
				if condition.Type == conditionType && condition.Status == metav1.ConditionTrue {
					return pr, nil
				}
			}
		}
	}
}

// WaitForReady waits for a ProvisioningRequest to become Ready
func (c *provisioningRequestClient) WaitForReady(ctx context.Context, name string, timeout time.Duration) (*o2imsv1alpha1.ProvisioningRequest, error) {
	return c.WaitForCondition(ctx, name, o2imsv1alpha1.ConditionTypeReady, timeout)
}

// watchInterface implements WatchInterface for real client
type watchInterface struct {
	ctx       context.Context
	client    client.Client
	namespace string
	ch        chan WatchEvent
}

func (w *watchInterface) Stop() {
	if w.ch != nil {
		close(w.ch)
	}
}

func (w *watchInterface) ResultChan() <-chan WatchEvent {
	if w.ch == nil {
		w.ch = make(chan WatchEvent, 10)
	}
	return w.ch
}