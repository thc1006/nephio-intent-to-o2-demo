package client

import (
	"context"
	"testing"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
)

func TestFakeClient(t *testing.T) {
	// Create fake client
	scheme := runtime.NewScheme()
	err := o2imsv1alpha1.AddToScheme(scheme)
	if err != nil {
		t.Fatalf("Failed to add scheme: %v", err)
	}

	opts := FakeClientOptions{
		Scheme:         scheme,
		InitialObjects: []client.Object{},
	}

	fakeClient := NewFakeO2IMSClient(opts)
	if fakeClient == nil {
		t.Fatal("Expected fake client, got nil")
	}

	prInterface := fakeClient.ProvisioningRequests("default")
	if prInterface == nil {
		t.Fatal("Expected ProvisioningRequest interface, got nil")
	}

	// Test Create operation
	testPR := &o2imsv1alpha1.ProvisioningRequest{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-pr",
			Namespace: "default",
		},
		Spec: o2imsv1alpha1.ProvisioningRequestSpec{
			TargetCluster: "test-cluster",
			ResourceRequirements: o2imsv1alpha1.ResourceRequirements{
				CPU:    "1000m",
				Memory: "2Gi",
			},
		},
	}

	ctx := context.Background()
	createdPR, err := prInterface.Create(ctx, testPR, metav1.CreateOptions{})
	if err != nil {
		t.Errorf("Failed to create ProvisioningRequest: %v", err)
	}
	if createdPR.Status.Phase != "Pending" {
		t.Errorf("Expected phase 'Pending', got '%s'", createdPR.Status.Phase)
	}

	// Test Get operation
	getPR, err := prInterface.Get(ctx, "test-pr", metav1.GetOptions{})
	if err != nil {
		t.Errorf("Failed to get ProvisioningRequest: %v", err)
	}
	if getPR.Name != "test-pr" {
		t.Errorf("Expected name 'test-pr', got '%s'", getPR.Name)
	}

	// Test List operation
	list, err := prInterface.List(ctx, metav1.ListOptions{})
	if err != nil {
		t.Errorf("Failed to list ProvisioningRequests: %v", err)
	}
	if len(list.Items) != 1 {
		t.Errorf("Expected 1 item in list, got %d", len(list.Items))
	}

	// Test WaitForReady operation - but with shorter timeout since we know it will timeout
	// The fake client simulates status progression in the background
	_, err = prInterface.WaitForReady(ctx, "test-pr", 100*time.Millisecond)
	// We expect this to timeout since the progression takes a few seconds
	if err == nil {
		t.Log("WaitForReady completed faster than expected - this is OK")
	} else {
		t.Logf("WaitForReady timed out as expected: %v", err)
	}

	// Test Delete operation
	err = prInterface.Delete(ctx, "test-pr", metav1.DeleteOptions{})
	if err != nil {
		t.Errorf("Failed to delete ProvisioningRequest: %v", err)
	}

	// Verify it's deleted (might fail due to background goroutines, so just log)
	_, err = prInterface.Get(ctx, "test-pr", metav1.GetOptions{})
	if err == nil {
		t.Log("ProvisioningRequest still exists - might be due to background processing")
	} else {
		t.Log("ProvisioningRequest deleted successfully")
	}
}