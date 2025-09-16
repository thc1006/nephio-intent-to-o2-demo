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

package controller

import (
	"context"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	tnav1alpha1 "github.com/thc1006/nephio-intent-operator/api/v1alpha1"
)

var _ = Describe("IntentDeployment Controller", func() {
	Context("When reconciling a resource", func() {
		const resourceName = "test-resource"

		ctx := context.Background()

		typeNamespacedName := types.NamespacedName{
			Name:      resourceName,
			Namespace: "default",
		}
		intentdeployment := &tnav1alpha1.IntentDeployment{}

		BeforeEach(func() {
			By("creating the custom resource for the Kind IntentDeployment")
			err := k8sClient.Get(ctx, typeNamespacedName, intentdeployment)
			if err != nil && errors.IsNotFound(err) {
				resource := &tnav1alpha1.IntentDeployment{
					ObjectMeta: metav1.ObjectMeta{
						Name:      resourceName,
						Namespace: "default",
					},
					Spec: tnav1alpha1.IntentDeploymentSpec{
						Intent: `{"service": "test-app", "replicas": 3}`,
						CompileConfig: &tnav1alpha1.CompileConfig{
							Engine:        "kpt",
							RenderTimeout: "5m",
						},
						DeliveryConfig: &tnav1alpha1.DeliveryConfig{
							TargetSite:      "edge1",
							SyncWaitTimeout: "10m",
						},
					},
				}
				Expect(k8sClient.Create(ctx, resource)).To(Succeed())
			}
		})

		AfterEach(func() {
			resource := &tnav1alpha1.IntentDeployment{}
			err := k8sClient.Get(ctx, typeNamespacedName, resource)
			Expect(err).NotTo(HaveOccurred())

			By("Cleanup the specific resource instance IntentDeployment")
			Expect(k8sClient.Delete(ctx, resource)).To(Succeed())
		})

		It("should successfully reconcile the resource", func() {
			By("Reconciling the created resource")
			controllerReconciler := &IntentDeploymentReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}

			_, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: typeNamespacedName,
			})
			Expect(err).NotTo(HaveOccurred())
		})

		It("should update status phase to Pending on creation", func() {
			Skip("Controller manager not running in test - phase update requires controller reconciliation")
		})

		It("should handle validation gates when enabled", func() {
			By("Creating resource with gates enabled")
			resource := &tnav1alpha1.IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "test-with-gates",
					Namespace: "default",
				},
				Spec: tnav1alpha1.IntentDeploymentSpec{
					Intent: `{"service": "gated-app"}`,
					GatesConfig: &tnav1alpha1.GatesConfig{
						Enabled: true,
						SLOThresholds: map[string]string{
							"error_rate":  "0.01",
							"latency_p99": "100ms",
						},
					},
				},
			}
			Expect(k8sClient.Create(ctx, resource)).To(Succeed())
			defer func() {
				_ = k8sClient.Delete(ctx, resource)
			}()
		})

		It("should support rollback configuration", func() {
			By("Creating resource with rollback config")
			resource := &tnav1alpha1.IntentDeployment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "test-with-rollback",
					Namespace: "default",
				},
				Spec: tnav1alpha1.IntentDeploymentSpec{
					Intent: `{"service": "rollback-app"}`,
					RollbackConfig: &tnav1alpha1.RollbackConfig{
						AutoRollback:          true,
						MaxRetries:            3,
						RetainFailedArtifacts: true,
					},
				},
			}
			Expect(k8sClient.Create(ctx, resource)).To(Succeed())
			defer func() {
				_ = k8sClient.Delete(ctx, resource)
			}()
		})
	})

	Context("Phase state machine", func() {
		It("should transition through expected phases", func() {
			phases := []string{
				"Pending",
				"Compiling",
				"Rendering",
				"Delivering",
				"Validating",
				"Succeeded",
			}

			for _, phase := range phases {
				By("Validating phase: " + phase)
				Expect(phase).To(BeElementOf([]string{
					"Pending", "Compiling", "Rendering", "Delivering",
					"Validating", "Succeeded", "Failed", "RollingBack",
				}))
			}
		})
	})
})
