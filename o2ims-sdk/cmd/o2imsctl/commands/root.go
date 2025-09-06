package commands

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
)

// GlobalOptions holds global CLI options
type GlobalOptions struct {
	Kubeconfig string
	Context    string
	Namespace  string
	Fake       bool
	Verbose    bool
}

var globalOpts = &GlobalOptions{}

// NewRootCommand creates the root command for o2imsctl
func NewRootCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "o2imsctl",
		Short: "O2 IMS CLI for managing ProvisioningRequest resources",
		Long: `O2 IMS CLI (o2imsctl) is a tool for interacting with O2 IMS resources in Kubernetes clusters.
It provides commands to create, manage, and monitor ProvisioningRequest resources following
O-RAN O2 IMS specifications.`,
		SilenceUsage:  true,
		SilenceErrors: true,
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			return setupKubeconfig()
		},
	}

	// Global flags
	cmd.PersistentFlags().StringVar(&globalOpts.Kubeconfig, "kubeconfig", "", "Path to kubeconfig file (default: $HOME/.kube/config)")
	cmd.PersistentFlags().StringVar(&globalOpts.Context, "context", "", "Kubernetes context to use")
	cmd.PersistentFlags().StringVarP(&globalOpts.Namespace, "namespace", "n", "default", "Kubernetes namespace")
	cmd.PersistentFlags().BoolVar(&globalOpts.Fake, "fake", false, "Use fake/mock client for testing")
	cmd.PersistentFlags().BoolVarP(&globalOpts.Verbose, "verbose", "v", false, "Enable verbose output")

	// Add subcommands
	cmd.AddCommand(NewProvisioningRequestCommand())
	cmd.AddCommand(NewVersionCommand())

	return cmd
}

// setupKubeconfig sets up the kubeconfig for the CLI
func setupKubeconfig() error {
	if globalOpts.Kubeconfig == "" {
		if home := homedir.HomeDir(); home != "" {
			globalOpts.Kubeconfig = filepath.Join(home, ".kube", "config")
		}
	}

	// In fake mode, we don't need a real kubeconfig
	if globalOpts.Fake {
		return nil
	}

	// Check if kubeconfig file exists
	if _, err := os.Stat(globalOpts.Kubeconfig); os.IsNotExist(err) {
		return fmt.Errorf("kubeconfig file does not exist: %s", globalOpts.Kubeconfig)
	}

	return nil
}

// GetRestConfig returns the REST config based on global options
func GetRestConfig() (*rest.Config, error) {
	if globalOpts.Fake {
		// Return a mock config for fake mode
		return &rest.Config{}, nil
	}

	// Build config from kubeconfig file
	config, err := clientcmd.BuildConfigFromFlags("", globalOpts.Kubeconfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create Kubernetes config: %w", err)
	}

	return config, nil
}