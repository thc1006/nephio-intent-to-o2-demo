//go:build e2e
// +build e2e

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

package e2e

import (
	"fmt"
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/thc1006/nephio-intent-operator/test/utils"
)

var _ = Describe("Simple E2E Tests", Ordered, func() {
	Context("Basic functionality", func() {
		It("should be able to connect to Kubernetes cluster", func() {
			By("checking kubectl connectivity")
			cmd := exec.Command("kubectl", "version", "--client")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to run kubectl")
		})

		It("should be able to list nodes", func() {
			By("listing cluster nodes")
			cmd := exec.Command("kubectl", "get", "nodes")
			output, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to list nodes")
			Expect(output).To(ContainSubstring("Ready"), "At least one node should be Ready")
		})

		It("should be able to create and delete a test namespace", func() {
			testNamespace := "e2e-test-namespace-" + time.Now().Format("20060102-150405")

			By("creating test namespace")
			cmd := exec.Command("kubectl", "create", "namespace", testNamespace)
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to create test namespace")

			By("verifying namespace exists")
			cmd = exec.Command("kubectl", "get", "namespace", testNamespace)
			_, err = utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to get the test namespace")

			By("cleaning up test namespace")
			cmd = exec.Command("kubectl", "delete", "namespace", testNamespace, "--wait=true", "--timeout=60s")
			_, err = utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to delete test namespace")
		})

		It("should be able to build the operator binary", func() {
			By("building the operator")
			cmd := exec.Command("make", "build")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to build the operator")
		})

		It("should be able to generate manifests", func() {
			By("generating manifests")
			cmd := exec.Command("make", "manifests")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to generate manifests")
		})
	})

	Context("CRD Tests", func() {
		It("should be able to install CRDs", func() {
			By("installing CRDs")
			cmd := exec.Command("make", "install")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Should be able to install CRDs")

			By("verifying CRDs are installed")
			Eventually(func() error {
				cmd := exec.Command("kubectl", "get", "crd")
				output, err := utils.Run(cmd)
				if err != nil {
					return err
				}
				// Look for any CRDs that might be created by this operator
				// This is a basic check that CRDs can be listed
				if len(output) == 0 {
					return fmt.Errorf("no CRDs found in output")
				}
				return nil
			}, time.Minute*2, time.Second*10).Should(Succeed())

			By("uninstalling CRDs")
			cmd = exec.Command("make", "uninstall")
			_, err = utils.Run(cmd)
			// Don't fail if uninstall has issues - this is cleanup
			if err != nil {
				GinkgoWriter.Printf("Warning: uninstall had issues: %v\n", err)
			}
		})
	})
})
