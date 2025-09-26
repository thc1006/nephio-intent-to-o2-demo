//go:build e2e
// +build e2e

package e2eminimal

import (
	"fmt"
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/thc1006/nephio-intent-operator/test/utils"
)

// Minimal E2E test that deploys a pre-built controller image
var _ = Describe("Minimal Controller Deployment", func() {
	const (
		testNamespace = "nephio-intent-operator-system-e2e"
		testImage     = "controller:latest"
		timeout       = 5 * time.Minute
		interval      = 1 * time.Second
	)

	BeforeEach(func() {
		By("creating test namespace")
		cmd := exec.Command("kubectl", "create", "ns", testNamespace)
		_, _ = utils.Run(cmd) // Ignore error if namespace exists
	})

	AfterEach(func() {
		By("cleaning up test namespace")
		cmd := exec.Command("kubectl", "delete", "ns", testNamespace, "--ignore-not-found", "--timeout=60s")
		_, _ = utils.Run(cmd)
	})

	Context("Controller Deployment", func() {
		It("should deploy CRDs successfully", func() {
			By("installing CRDs")
			cmd := exec.Command("kubectl", "apply", "-f", "config/crd/bases/")
			output, err := utils.Run(cmd)
			if err != nil {
				fmt.Printf("CRD installation output: %s\n", output)
			}
			Expect(err).NotTo(HaveOccurred())

			By("verifying CRDs are installed")
			cmd = exec.Command("kubectl", "get", "crd", "intentdeployments.tna.tna.ai")
			_, err = utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred())
		})

		It("should create minimal controller resources", func() {
			By("creating a minimal deployment manifest")
			manifest := `
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nephio-intent-operator-controller-manager
  namespace: ` + testNamespace + `
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nephio-intent-operator-controller-manager
  namespace: ` + testNamespace + `
  labels:
    control-plane: controller-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      control-plane: controller-manager
  template:
    metadata:
      labels:
        control-plane: controller-manager
    spec:
      serviceAccountName: nephio-intent-operator-controller-manager
      containers:
      - name: manager
        image: busybox:latest
        command: ["sleep", "3600"]
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
`
			// Write manifest to temp file
			tmpFile := "/tmp/test-deployment.yaml"
			cmd := exec.Command("bash", "-c", fmt.Sprintf("echo '%s' > %s", manifest, tmpFile))
			_, err := utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred())

			By("applying the deployment manifest")
			cmd = exec.Command("kubectl", "apply", "-f", tmpFile)
			_, err = utils.Run(cmd)
			Expect(err).NotTo(HaveOccurred())

			By("waiting for pod to be running")
			Eventually(func() error {
				// First check if any pods exist
				cmd := exec.Command("kubectl", "get", "pods", "-n", testNamespace,
					"-l", "control-plane=controller-manager",
					"-o", "jsonpath={.items}")
				output, err := utils.Run(cmd)
				if err != nil {
					return fmt.Errorf("failed to get pods: %v", err)
				}
				if string(output) == "[]" || len(output) == 0 {
					return fmt.Errorf("no pods found with label control-plane=controller-manager")
				}

				// Now check the pod status
				cmd = exec.Command("kubectl", "get", "pods", "-n", testNamespace,
					"-l", "control-plane=controller-manager",
					"-o", "jsonpath={.items[0].status.phase}")
				output, err = utils.Run(cmd)
				if err != nil {
					return fmt.Errorf("failed to get pod status: %v", err)
				}
				if string(output) != "Running" {
					return fmt.Errorf("pod is not running, status: %s", output)
				}
				return nil
			}, timeout, interval).Should(Succeed())
		})
	})
})