package tests

import (
	"context"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
	"github.com/nephio-intent-to-o2-demo/o2ims-sdk/client"
)

var _ = Describe("O2 IMS Client", func() {
	Context("When creating a new client", func() {
		It("Should fail with unimplemented error", func() {
			By("Attempting to create a new O2 IMS client")
			config := client.ClientConfig{
				RestConfig: cfg,
				Namespace:  "default",
			}

			// This should fail with "not implemented" error in RED phase
			_, err := client.NewO2IMSClient(config)
			Expect(err).Should(HaveOccurred())
			Expect(err.Error()).Should(ContainSubstring("not implemented"))
		})
	})

	Context("When using controller-runtime client wrapper", func() {
		It("Should create client but fail operations", func() {
			By("Creating client from controller-runtime")
			o2imsClient := client.NewO2IMSClientFromControllerRuntime(k8sClient, "default")
			Expect(o2imsClient).NotTo(BeNil())

			By("Attempting to get ProvisioningRequests interface")
			prInterface := o2imsClient.ProvisioningRequests("default")
			Expect(prInterface).NotTo(BeNil())

			By("Attempting to create a ProvisioningRequest - should succeed with real client")
			ctx := context.Background()
			
			// Create a test PR
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
			
			_, err := prInterface.Create(ctx, testPR, metav1.CreateOptions{})
			Expect(err).ShouldNot(HaveOccurred())

			By("Attempting to get a ProvisioningRequest - should succeed")
			_, err = prInterface.Get(ctx, "test-pr", metav1.GetOptions{})
			Expect(err).ShouldNot(HaveOccurred())

			By("Attempting to list ProvisioningRequests - should succeed")
			_, err = prInterface.List(ctx, metav1.ListOptions{})
			Expect(err).ShouldNot(HaveOccurred())
		})
	})

	Context("When testing client methods", func() {
		var o2imsClient client.O2IMSClient
		var prInterface client.ProvisioningRequestInterface

		BeforeEach(func() {
			o2imsClient = client.NewO2IMSClientFromControllerRuntime(k8sClient, "default")
			prInterface = o2imsClient.ProvisioningRequests("default")
		})

		It("Should handle all CRUD operations", func() {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()

			// Create a test PR
			testPR := &o2imsv1alpha1.ProvisioningRequest{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "test-crud-pr",
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

			By("Testing Create operation")
			_, err := prInterface.Create(ctx, testPR, metav1.CreateOptions{})
			Expect(err).ShouldNot(HaveOccurred())

			By("Testing Update operation")
			testPR.Spec.Description = "Updated description"
			_, err = prInterface.Update(ctx, testPR, metav1.UpdateOptions{})
			Expect(err).ShouldNot(HaveOccurred())

			By("Testing Delete operation")
			err = prInterface.Delete(ctx, "test-crud-pr", metav1.DeleteOptions{})
			Expect(err).ShouldNot(HaveOccurred())

			By("Testing Watch operation")
			_, err = prInterface.Watch(ctx, metav1.ListOptions{})
			Expect(err).ShouldNot(HaveOccurred())
		})
	})
})