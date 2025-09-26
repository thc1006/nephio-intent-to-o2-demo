package tests

import (
	"context"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
)

var _ = Describe("ProvisioningRequest Controller", func() {
	Context("When creating a ProvisioningRequest", func() {
		const (
			ProvisioningRequestName      = "test-provisioningrequest"
			ProvisioningRequestNamespace = "default"
			timeout                      = time.Second * 10
			duration                     = time.Second * 10
			interval                     = time.Millisecond * 250
		)

		It("Should create ProvisioningRequest successfully", func() {
			By("Creating a new ProvisioningRequest")
			ctx := context.Background()
			provisioningRequest := &o2imsv1alpha1.ProvisioningRequest{
				TypeMeta: metav1.TypeMeta{
					APIVersion: "o2ims.provisioning.oran.org/v1alpha1",
					Kind:       "ProvisioningRequest",
				},
				ObjectMeta: metav1.ObjectMeta{
					Name:      ProvisioningRequestName,
					Namespace: ProvisioningRequestNamespace,
				},
				Spec: o2imsv1alpha1.ProvisioningRequestSpec{
					TargetCluster: "test-cluster",
					ResourceRequirements: o2imsv1alpha1.ResourceRequirements{
						CPU:     "2000m",
						Memory:  "4Gi",
						Storage: "10Gi",
					},
					NetworkConfig: &o2imsv1alpha1.NetworkConfig{
						VLAN:    func() *int32 { v := int32(100); return &v }(),
						Subnet:  "192.168.1.0/24",
						Gateway: "192.168.1.1",
					},
					Description: "Test provisioning request",
				},
			}

			// This will fail initially because the CRD is not installed in envtest
			Expect(k8sClient.Create(ctx, provisioningRequest)).Should(Succeed())

			provisioningRequestLookupKey := types.NamespacedName{Name: ProvisioningRequestName, Namespace: ProvisioningRequestNamespace}
			createdProvisioningRequest := &o2imsv1alpha1.ProvisioningRequest{}

			// We'll need to retry getting this newly created ProvisioningRequest, given that creation may not immediately happen.
			Eventually(func() bool {
				err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
				return err == nil
			}, timeout, interval).Should(BeTrue())

			// Let's make sure our ProvisioningRequest's Spec matches what we expect
			Expect(createdProvisioningRequest.Spec.TargetCluster).Should(Equal("test-cluster"))
			Expect(createdProvisioningRequest.Spec.ResourceRequirements.CPU).Should(Equal("2000m"))
			Expect(createdProvisioningRequest.Spec.ResourceRequirements.Memory).Should(Equal("4Gi"))
			Expect(createdProvisioningRequest.Spec.NetworkConfig.Subnet).Should(Equal("192.168.1.0/24"))
		})

		It("Should update ProvisioningRequest status", func() {
			By("Updating the status of an existing ProvisioningRequest")
			ctx := context.Background()
			provisioningRequestLookupKey := types.NamespacedName{Name: ProvisioningRequestName, Namespace: ProvisioningRequestNamespace}
			createdProvisioningRequest := &o2imsv1alpha1.ProvisioningRequest{}

			// Get the ProvisioningRequest
			err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
			Expect(err).Should(BeNil())

			// Update the status
			createdProvisioningRequest.Status.Phase = "Processing"
			createdProvisioningRequest.Status.ObservedGeneration = createdProvisioningRequest.Generation
			createdProvisioningRequest.Status.Conditions = []o2imsv1alpha1.ProvisioningRequestCondition{
				{
					Type:               o2imsv1alpha1.ConditionTypeProcessing,
					Status:             metav1.ConditionTrue,
					LastTransitionTime: metav1.Now(),
					Reason:             "StartedProcessing",
					Message:            "Started processing provisioning request",
				},
			}

			// This will fail initially because controller is not implemented
			Expect(k8sClient.Status().Update(ctx, createdProvisioningRequest)).Should(Succeed())

			// Verify the status update
			Eventually(func() string {
				err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
				if err != nil {
					return ""
				}
				return createdProvisioningRequest.Status.Phase
			}, timeout, interval).Should(Equal("Processing"))
		})

		It("Should transition to Ready state", func() {
			By("Simulating controller transition to Ready state")
			ctx := context.Background()
			provisioningRequestLookupKey := types.NamespacedName{Name: ProvisioningRequestName, Namespace: ProvisioningRequestNamespace}
			createdProvisioningRequest := &o2imsv1alpha1.ProvisioningRequest{}

			// Get the ProvisioningRequest
			err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
			Expect(err).Should(BeNil())

			// Simulate controller updating to Ready state
			createdProvisioningRequest.Status.Phase = "Ready"
			createdProvisioningRequest.Status.Conditions = []o2imsv1alpha1.ProvisioningRequestCondition{
				{
					Type:               o2imsv1alpha1.ConditionTypeReady,
					Status:             metav1.ConditionTrue,
					LastTransitionTime: metav1.Now(),
					Reason:             "ProvisioningCompleted",
					Message:            "Provisioning completed successfully",
				},
			}
			createdProvisioningRequest.Status.ProvisionedResources = map[string]string{
				"node-1": "worker-node-1",
				"node-2": "worker-node-2",
			}

			// This will fail initially because controller is not implemented
			Expect(k8sClient.Status().Update(ctx, createdProvisioningRequest)).Should(Succeed())

			// Verify the Ready state
			Eventually(func() string {
				err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
				if err != nil {
					return ""
				}
				return createdProvisioningRequest.Status.Phase
			}, timeout, interval).Should(Equal("Ready"))
		})

		It("Should delete ProvisioningRequest", func() {
			By("Deleting the created ProvisioningRequest")
			ctx := context.Background()
			provisioningRequestLookupKey := types.NamespacedName{Name: ProvisioningRequestName, Namespace: ProvisioningRequestNamespace}
			createdProvisioningRequest := &o2imsv1alpha1.ProvisioningRequest{}

			err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
			Expect(err).Should(BeNil())

			Expect(k8sClient.Delete(ctx, createdProvisioningRequest)).Should(Succeed())

			// Verify deletion
			Eventually(func() bool {
				err := k8sClient.Get(ctx, provisioningRequestLookupKey, createdProvisioningRequest)
				return err != nil
			}, timeout, interval).Should(BeTrue())
		})
	})

	Context("When validating ProvisioningRequest fields", func() {
		It("Should reject invalid CPU format", func() {
			By("Creating ProvisioningRequest with invalid CPU")
			ctx := context.Background()
			invalidPR := &o2imsv1alpha1.ProvisioningRequest{
				TypeMeta: metav1.TypeMeta{
					APIVersion: "o2ims.provisioning.oran.org/v1alpha1",
					Kind:       "ProvisioningRequest",
				},
				ObjectMeta: metav1.ObjectMeta{
					Name:      "invalid-cpu-pr",
					Namespace: "default",
				},
				Spec: o2imsv1alpha1.ProvisioningRequestSpec{
					TargetCluster: "test-cluster",
					ResourceRequirements: o2imsv1alpha1.ResourceRequirements{
						CPU:    "", // Invalid: empty CPU
						Memory: "4Gi",
					},
				},
			}

			// This should fail due to validation - but will fail for different reason initially
			err := k8sClient.Create(ctx, invalidPR)
			Expect(err).Should(HaveOccurred())
		})

		It("Should reject invalid network configuration", func() {
			By("Creating ProvisioningRequest with invalid network config")
			ctx := context.Background()
			invalidNetworkPR := &o2imsv1alpha1.ProvisioningRequest{
				TypeMeta: metav1.TypeMeta{
					APIVersion: "o2ims.provisioning.oran.org/v1alpha1",
					Kind:       "ProvisioningRequest",
				},
				ObjectMeta: metav1.ObjectMeta{
					Name:      "invalid-network-pr",
					Namespace: "default",
				},
				Spec: o2imsv1alpha1.ProvisioningRequestSpec{
					TargetCluster: "test-cluster",
					ResourceRequirements: o2imsv1alpha1.ResourceRequirements{
						CPU:    "2000m",
						Memory: "4Gi",
					},
					NetworkConfig: &o2imsv1alpha1.NetworkConfig{
						VLAN:    func() *int32 { v := int32(5000); return &v }(), // Invalid: VLAN > 4094
						Subnet:  "invalid-subnet",                                  // Invalid format
						Gateway: "999.999.999.999",                                // Invalid IP
					},
				},
			}

			// This should fail due to validation - but will fail for different reason initially
			err := k8sClient.Create(ctx, invalidNetworkPR)
			Expect(err).Should(HaveOccurred())
		})
	})
})