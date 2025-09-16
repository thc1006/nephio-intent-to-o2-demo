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
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/thc1006/nephio-intent-operator/test/utils"
)

var _ = Describe("Minimal E2E Tests", func() {
	Context("Basic connectivity and build tests", func() {
		It("should be able to run basic kubectl commands", func() {
			By("checking kubectl version")
			cmd := exec.Command("kubectl", "version", "--client", "--output=json")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "kubectl should be available")
		})

		It("should be able to compile the operator", func() {
			By("building the operator binary")
			cmd := exec.Command("make", "build")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "operator should compile successfully")
		})

		It("should be able to generate manifests", func() {
			By("generating kubernetes manifests")
			cmd := exec.Command("make", "manifests")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "manifests should generate successfully")
		})

		It("should have valid CRD definitions", func() {
			By("checking CRD files exist")
			cmd := exec.Command("ls", "-la", "config/crd/bases/")
			output, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "CRD directory should exist")
			Expect(output).To(ContainSubstring(".yaml"), "CRD files should exist")
		})

		It("should be able to validate Go syntax", func() {
			By("checking Go files can be parsed")
			cmd := exec.Command("go", "vet", "./api/...", "./internal/...")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "Go syntax should be valid")
		})
	})

	Context("Kubernetes cluster connectivity", func() {
		It("should be able to connect to the cluster", func() {
			By("getting cluster info")
			cmd := exec.Command("kubectl", "cluster-info")
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "should be able to connect to cluster")
		})

		It("should be able to list namespaces", func() {
			By("listing namespaces")
			cmd := exec.Command("kubectl", "get", "namespaces")
			output, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "should be able to list namespaces")
			Expect(output).To(ContainSubstring("default"), "default namespace should exist")
		})

		It("should be able to create and delete test resources", func() {
			testNamespace := "minimal-e2e-test-" + time.Now().Format("20060102-150405")

			By("creating test namespace")
			cmd := exec.Command("kubectl", "create", "namespace", testNamespace)
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "should be able to create namespace")

			By("verifying namespace was created")
			cmd = exec.Command("kubectl", "get", "namespace", testNamespace)
			_, err = utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "namespace should exist after creation")

			By("cleaning up test namespace")
			cmd = exec.Command("kubectl", "delete", "namespace", testNamespace, "--wait=true", "--timeout=30s")
			_, err = utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred(), "should be able to delete test namespace")
		})
	})
})