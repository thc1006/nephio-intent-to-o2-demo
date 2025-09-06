package tests

import (
	"bytes"
	"context"
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("o2imsctl CLI", func() {
	var (
		cliPath string
		err     error
	)

	BeforeEach(func() {
		// Build the CLI binary for testing
		cliPath, err = gexec.Build("github.com/nephio-intent-to-o2-demo/o2ims-sdk/cmd/o2imsctl")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		if cliPath != "" {
			gexec.CleanupBuildArtifacts()
		}
	})

	Context("When running basic commands", func() {
		It("Should show version information", func() {
			cmd := exec.Command(cliPath, "version")
			var out bytes.Buffer
			cmd.Stdout = &out

			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("o2imsctl version"))
			Expect(out.String()).To(ContainSubstring("Go version"))
		})

		It("Should show help message", func() {
			cmd := exec.Command(cliPath, "--help")
			var out bytes.Buffer
			cmd.Stdout = &out

			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("O2 IMS CLI"))
			Expect(out.String()).To(ContainSubstring("pr"))
		})
	})

	Context("When using fake mode", func() {
		It("Should create PR from file in fake mode", func() {
			cmd := exec.Command(cliPath, "pr", "create", "--from", "../examples/pr.yaml", "--fake")
			var out bytes.Buffer
			cmd.Stdout = &out

			// This should work in fake mode
			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("FAKE MODE"))
			Expect(out.String()).To(ContainSubstring("Would create ProvisioningRequest"))
		})

		It("Should wait for condition in fake mode", func() {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()

			cmd := exec.CommandContext(ctx, cliPath, "pr", "wait", "test-pr", "--timeout", "5s", "--fake")
			var out bytes.Buffer
			cmd.Stdout = &out

			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("FAKE MODE"))
			Expect(out.String()).To(ContainSubstring("Would wait for ProvisioningRequest"))
			Expect(out.String()).To(ContainSubstring("reached condition"))
		})

		It("Should get PR in fake mode", func() {
			cmd := exec.Command(cliPath, "pr", "get", "test-pr", "--fake")
			var out bytes.Buffer
			cmd.Stdout = &out

			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("FAKE MODE"))
			Expect(out.String()).To(ContainSubstring("apiVersion: o2ims.provisioning.oran.org/v1alpha1"))
		})

		It("Should list PRs in fake mode", func() {
			cmd := exec.Command(cliPath, "pr", "list", "--fake")
			var out bytes.Buffer
			cmd.Stdout = &out

			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("FAKE MODE"))
		})

		It("Should delete PR in fake mode", func() {
			cmd := exec.Command(cliPath, "pr", "delete", "test-pr", "--fake")
			var out bytes.Buffer
			cmd.Stdout = &out

			err := cmd.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(out.String()).To(ContainSubstring("FAKE MODE"))
			Expect(out.String()).To(ContainSubstring("Would delete"))
		})
	})

	Context("When not using fake mode", func() {
		It("Should fail without proper kubeconfig", func() {
			cmd := exec.Command(cliPath, "pr", "create", "--from", "../examples/pr.yaml")
			var stderr bytes.Buffer
			cmd.Stderr = &stderr

			err := cmd.Run()
			Expect(err).To(HaveOccurred())
			// Should fail because implementation is not complete (RED phase)
			output := stderr.String()
			Expect(output).To(Or(
				ContainSubstring("not implemented"),
				ContainSubstring("kubeconfig"),
			))
		})

		It("Should fail operations without implementation", func() {
			cmd := exec.Command(cliPath, "pr", "list", "--kubeconfig", "/dev/null")
			var stderr bytes.Buffer
			cmd.Stderr = &stderr

			err := cmd.Run()
			Expect(err).To(HaveOccurred())
			// Should fail because implementation is not complete (RED phase)
		})
	})

	Context("When testing command line validation", func() {
		It("Should require --from flag for create command", func() {
			cmd := exec.Command(cliPath, "pr", "create")
			var stderr bytes.Buffer
			cmd.Stderr = &stderr

			err := cmd.Run()
			Expect(err).To(HaveOccurred())
			Expect(stderr.String()).To(ContainSubstring("required flag(s) \"from\" not set"))
		})

		It("Should require name argument for get command", func() {
			cmd := exec.Command(cliPath, "pr", "get", "--fake")
			var stderr bytes.Buffer
			cmd.Stderr = &stderr

			err := cmd.Run()
			Expect(err).To(HaveOccurred())
			Expect(stderr.String()).To(ContainSubstring("accepts 1 arg(s), received 0"))
		})

		It("Should require name argument for wait command", func() {
			cmd := exec.Command(cliPath, "pr", "wait", "--fake")
			var stderr bytes.Buffer
			cmd.Stderr = &stderr

			err := cmd.Run()
			Expect(err).To(HaveOccurred())
			Expect(stderr.String()).To(ContainSubstring("accepts 1 arg(s), received 0"))
		})
	})
})