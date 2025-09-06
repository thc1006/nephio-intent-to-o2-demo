/*
Copyright 2025 Nephio Intent-to-O2 Demo.

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

package client

import (
	"context"
	"fmt"
	"time"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"
)

// FakeClientOptions holds options for creating fake clients
type FakeClientOptions struct {
	InitialObjects []client.Object
	Scheme         *runtime.Scheme
}

// NewFakeO2IMSClient creates a fake O2 IMS client for testing
func NewFakeO2IMSClient(opts FakeClientOptions) O2IMSClient {
	fakeClient := fake.NewClientBuilder().
		WithScheme(opts.Scheme).
		WithObjects(opts.InitialObjects...).
		WithStatusSubresource(&o2imsv1alpha1.ProvisioningRequest{}).
		Build()
	
	return &o2imsClient{
		client:    fakeClient,
		namespace: "default",
	}
}

// fakeProvisioningRequestClient implements ProvisioningRequestInterface with fake behavior
type fakeProvisioningRequestClient struct {
	client    client.Client
	namespace string
}

// newFakeProvisioningRequestClient creates a fake ProvisioningRequest client
func newFakeProvisioningRequestClient(c client.Client, namespace string) ProvisioningRequestInterface {
	return &fakeProvisioningRequestClient{
		client:    c,
		namespace: namespace,
	}
}

// Create implements the Create method with fake status progression
func (c *fakeProvisioningRequestClient) Create(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.CreateOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	// Set namespace if not specified
	if pr.Namespace == "" {
		pr.Namespace = c.namespace
	}
	
	// Initialize status with Pending condition
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

	// Start fake status progression in background
	go c.simulateStatusProgression(ctx, pr.Name, pr.Namespace)

	return pr, nil
}

// simulateStatusProgression simulates the status progression from Pending -> Processing -> Ready
func (c *fakeProvisioningRequestClient) simulateStatusProgression(ctx context.Context, name, namespace string) {
	// Wait 1 second then transition to Processing
	time.Sleep(1 * time.Second)
	
	pr := &o2imsv1alpha1.ProvisioningRequest{}
	if err := c.client.Get(ctx, client.ObjectKey{Name: name, Namespace: namespace}, pr); err != nil {
		return
	}
	
	// Update to Processing
	now := metav1.Now()
	pr.Status.Phase = "Processing"
	pr.Status.Conditions = []o2imsv1alpha1.ProvisioningRequestCondition{
		{
			Type:               o2imsv1alpha1.ConditionTypeProcessing,
			Status:             metav1.ConditionTrue,
			LastTransitionTime: now,
			Reason:             "Processing",
			Message:            "ProvisioningRequest is being processed",
		},
	}
	
	if err := c.client.Status().Update(ctx, pr); err != nil {
		return
	}
	
	// Wait 2 more seconds then transition to Ready
	time.Sleep(2 * time.Second)
	
	if err := c.client.Get(ctx, client.ObjectKey{Name: name, Namespace: namespace}, pr); err != nil {
		return
	}
	
	// Update to Ready
	now = metav1.Now()
	pr.Status.Phase = "Ready"
	pr.Status.Conditions = []o2imsv1alpha1.ProvisioningRequestCondition{
		{
			Type:               o2imsv1alpha1.ConditionTypeReady,
			Status:             metav1.ConditionTrue,
			LastTransitionTime: now,
			Reason:             "Ready",
			Message:            "ProvisioningRequest has been successfully provisioned",
		},
	}
	pr.Status.ProvisionedResources = map[string]string{
		"deployment": fmt.Sprintf("%s-deployment", name),
		"service":    fmt.Sprintf("%s-service", name),
		"configmap":  fmt.Sprintf("%s-config", name),
	}
	
	c.client.Status().Update(ctx, pr)
}

// Get retrieves a ProvisioningRequest by name
func (c *fakeProvisioningRequestClient) Get(ctx context.Context, name string, opts metav1.GetOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	pr := &o2imsv1alpha1.ProvisioningRequest{}
	key := client.ObjectKey{Name: name, Namespace: c.namespace}
	
	if err := c.client.Get(ctx, key, pr); err != nil {
		return nil, fmt.Errorf("failed to get ProvisioningRequest %s: %w", name, err)
	}
	
	return pr, nil
}

// List retrieves a list of ProvisioningRequest objects
func (c *fakeProvisioningRequestClient) List(ctx context.Context, opts metav1.ListOptions) (*o2imsv1alpha1.ProvisioningRequestList, error) {
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
func (c *fakeProvisioningRequestClient) Update(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.UpdateOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	if err := c.client.Update(ctx, pr); err != nil {
		return nil, fmt.Errorf("failed to update ProvisioningRequest: %w", err)
	}
	return pr, nil
}

// UpdateStatus updates the status subresource of a ProvisioningRequest
func (c *fakeProvisioningRequestClient) UpdateStatus(ctx context.Context, pr *o2imsv1alpha1.ProvisioningRequest, opts metav1.UpdateOptions) (*o2imsv1alpha1.ProvisioningRequest, error) {
	if err := c.client.Status().Update(ctx, pr); err != nil {
		return nil, fmt.Errorf("failed to update ProvisioningRequest status: %w", err)
	}
	return pr, nil
}

// Delete deletes a ProvisioningRequest
func (c *fakeProvisioningRequestClient) Delete(ctx context.Context, name string, opts metav1.DeleteOptions) error {
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
func (c *fakeProvisioningRequestClient) DeleteCollection(ctx context.Context, opts metav1.DeleteOptions, listOpts metav1.ListOptions) error {
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
func (c *fakeProvisioningRequestClient) Watch(ctx context.Context, opts metav1.ListOptions) (WatchInterface, error) {
	// For fake implementation, return a simple watch interface
	// In a real implementation, this would use the controller-runtime client's watch capabilities
	return &fakeWatchInterface{
		ctx:    ctx,
		client: c.client,
	}, nil
}

// Patch applies a patch to a ProvisioningRequest
func (c *fakeProvisioningRequestClient) Patch(ctx context.Context, name string, pt PatchType, data []byte, opts metav1.PatchOptions, subresources ...string) (*o2imsv1alpha1.ProvisioningRequest, error) {
	pr := &o2imsv1alpha1.ProvisioningRequest{}
	key := client.ObjectKey{Name: name, Namespace: c.namespace}
	
	if err := c.client.Get(ctx, key, pr); err != nil {
		return nil, fmt.Errorf("failed to get ProvisioningRequest for patch: %w", err)
	}
	
	// For fake implementation, we'll skip actual patching logic
	// In a real implementation, this would apply the patch
	return pr, nil
}

// WaitForCondition waits for a specific condition on a ProvisioningRequest
func (c *fakeProvisioningRequestClient) WaitForCondition(ctx context.Context, name string, conditionType o2imsv1alpha1.ProvisioningRequestConditionType, timeout time.Duration) (*o2imsv1alpha1.ProvisioningRequest, error) {
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
func (c *fakeProvisioningRequestClient) WaitForReady(ctx context.Context, name string, timeout time.Duration) (*o2imsv1alpha1.ProvisioningRequest, error) {
	return c.WaitForCondition(ctx, name, o2imsv1alpha1.ConditionTypeReady, timeout)
}

// fakeWatchInterface implements WatchInterface for fake testing
type fakeWatchInterface struct {
	ctx    context.Context
	client client.Client
	ch     chan WatchEvent
}

func (w *fakeWatchInterface) Stop() {
	// Implementation for stopping the watch
	if w.ch != nil {
		close(w.ch)
	}
}

func (w *fakeWatchInterface) ResultChan() <-chan WatchEvent {
	if w.ch == nil {
		w.ch = make(chan WatchEvent, 10)
	}
	return w.ch
}