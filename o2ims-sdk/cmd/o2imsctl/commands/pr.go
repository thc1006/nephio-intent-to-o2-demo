package commands

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/spf13/cobra"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/yaml"

	o2imsv1alpha1 "github.com/nephio-intent-to-o2-demo/o2ims-sdk/api/v1alpha1"
	o2imsclient "github.com/nephio-intent-to-o2-demo/o2ims-sdk/client"
)

// NewProvisioningRequestCommand creates the 'pr' command
func NewProvisioningRequestCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "pr",
		Aliases: []string{"provisioningrequest", "provisioningrequests"},
		Short:   "Manage ProvisioningRequest resources",
		Long:    "Create, manage, and monitor ProvisioningRequest resources in O2 IMS",
	}

	cmd.AddCommand(
		NewProvisioningRequestCreateCommand(),
		NewProvisioningRequestGetCommand(),
		NewProvisioningRequestListCommand(),
		NewProvisioningRequestDeleteCommand(),
		NewProvisioningRequestWaitCommand(),
	)

	return cmd
}

// NewProvisioningRequestCreateCommand creates the 'pr create' command
func NewProvisioningRequestCreateCommand() *cobra.Command {
	var fromFile string
	var output string

	cmd := &cobra.Command{
		Use:   "create",
		Short: "Create a ProvisioningRequest resource",
		Long:  "Create a new ProvisioningRequest resource from a YAML file or stdin",
		Example: `  # Create from file
  o2imsctl pr create --from examples/pr.yaml

  # Create from stdin
  cat examples/pr.yaml | o2imsctl pr create --from -`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runProvisioningRequestCreate(fromFile, output)
		},
	}

	cmd.Flags().StringVar(&fromFile, "from", "", "File path or - for stdin")
	cmd.Flags().StringVarP(&output, "output", "o", "yaml", "Output format (yaml|json)")
	cmd.MarkFlagRequired("from")

	return cmd
}

// NewProvisioningRequestGetCommand creates the 'pr get' command
func NewProvisioningRequestGetCommand() *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "get [NAME]",
		Short: "Get a ProvisioningRequest resource",
		Long:  "Get details of a ProvisioningRequest resource by name",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runProvisioningRequestGet(args[0], output)
		},
	}

	cmd.Flags().StringVarP(&output, "output", "o", "yaml", "Output format (yaml|json)")

	return cmd
}

// NewProvisioningRequestListCommand creates the 'pr list' command
func NewProvisioningRequestListCommand() *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List ProvisioningRequest resources",
		Long:  "List all ProvisioningRequest resources in the namespace",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runProvisioningRequestList(output)
		},
	}

	cmd.Flags().StringVarP(&output, "output", "o", "table", "Output format (table|yaml|json)")

	return cmd
}

// NewProvisioningRequestDeleteCommand creates the 'pr delete' command
func NewProvisioningRequestDeleteCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "delete [NAME]",
		Short: "Delete a ProvisioningRequest resource",
		Long:  "Delete a ProvisioningRequest resource by name",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return runProvisioningRequestDelete(args[0])
		},
	}

	return cmd
}

// NewProvisioningRequestWaitCommand creates the 'pr wait' command
func NewProvisioningRequestWaitCommand() *cobra.Command {
	var timeout time.Duration
	var condition string

	cmd := &cobra.Command{
		Use:   "wait [NAME]",
		Short: "Wait for a ProvisioningRequest to reach a condition",
		Long:  "Wait for a ProvisioningRequest to reach a specific condition or become Ready",
		Args:  cobra.ExactArgs(1),
		Example: `  # Wait for ProvisioningRequest to become Ready with default timeout
  o2imsctl pr wait my-pr

  # Wait with custom timeout
  o2imsctl pr wait my-pr --timeout 10m

  # Wait for specific condition
  o2imsctl pr wait my-pr --condition Processing --timeout 5m`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runProvisioningRequestWait(args[0], condition, timeout)
		},
	}

	cmd.Flags().DurationVar(&timeout, "timeout", 10*time.Minute, "Timeout for waiting")
	cmd.Flags().StringVar(&condition, "condition", "Ready", "Condition to wait for (Pending|Processing|Ready|Failed)")

	return cmd
}

// Command implementations

func runProvisioningRequestCreate(fromFile, output string) error {
	// Read the ProvisioningRequest from file
	pr, err := readYAMLFromFile(fromFile)
	if err != nil {
		return fmt.Errorf("failed to read ProvisioningRequest: %w", err)
	}

	// Get the appropriate client (fake or real)
	o2imsClient, err := getO2IMSClient()
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}

	// Create the ProvisioningRequest
	prInterface := o2imsClient.ProvisioningRequests(globalOpts.Namespace)
	createdPR, err := prInterface.Create(context.Background(), pr, metav1.CreateOptions{})
	if err != nil {
		return fmt.Errorf("failed to create ProvisioningRequest: %w", err)
	}

	fmt.Printf("ProvisioningRequest %s created successfully\n", createdPR.Name)
	// Output result
	return outputProvisioningRequest(createdPR, output)
}

func runProvisioningRequestGet(name, output string) error {
	// Get the appropriate client (fake or real)
	o2imsClient, err := getO2IMSClient()
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}

	// Get the ProvisioningRequest
	prInterface := o2imsClient.ProvisioningRequests(globalOpts.Namespace)
	pr, err := prInterface.Get(context.Background(), name, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get ProvisioningRequest: %w", err)
	}

	// Output result
	return outputProvisioningRequest(pr, output)
}

func runProvisioningRequestList(output string) error {
	// Get the appropriate client (fake or real)
	o2imsClient, err := getO2IMSClient()
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}

	// List ProvisioningRequests
	prInterface := o2imsClient.ProvisioningRequests(globalOpts.Namespace)
	list, err := prInterface.List(context.Background(), metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list ProvisioningRequests: %w", err)
	}

	// Output result
	return outputProvisioningRequestList(list, output)
}

func runProvisioningRequestDelete(name string) error {
	// Get the appropriate client (fake or real)
	o2imsClient, err := getO2IMSClient()
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}

	// Delete the ProvisioningRequest
	prInterface := o2imsClient.ProvisioningRequests(globalOpts.Namespace)
	if err := prInterface.Delete(context.Background(), name, metav1.DeleteOptions{}); err != nil {
		return fmt.Errorf("failed to delete ProvisioningRequest %s: %w", name, err)
	}

	fmt.Printf("ProvisioningRequest %s deleted successfully\n", name)
	return nil
}

func runProvisioningRequestWait(name, condition string, timeout time.Duration) error {
	// Get the appropriate client (fake or real)
	o2imsClient, err := getO2IMSClient()
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}

	// Convert condition string to condition type
	conditionType, err := parseConditionType(condition)
	if err != nil {
		return fmt.Errorf("invalid condition: %w", err)
	}

	fmt.Printf("Waiting for ProvisioningRequest %s to reach condition %s (timeout: %v)...\n", 
		name, condition, timeout)

	// Wait for the condition
	prInterface := o2imsClient.ProvisioningRequests(globalOpts.Namespace)
	pr, err := prInterface.WaitForCondition(context.Background(), name, conditionType, timeout)
	if err != nil {
		return fmt.Errorf("failed to wait for condition: %w", err)
	}

	fmt.Printf("ProvisioningRequest %s reached condition %s\n", name, condition)
	return outputProvisioningRequest(pr, "yaml")
}

// Helper function to read YAML from file or stdin
func readYAMLFromFile(filename string) (*o2imsv1alpha1.ProvisioningRequest, error) {
	var reader io.Reader

	if filename == "-" {
		reader = os.Stdin
	} else {
		file, err := os.Open(filename)
		if err != nil {
			return nil, fmt.Errorf("failed to open file %s: %w", filename, err)
		}
		defer file.Close()
		reader = file
	}

	data, err := io.ReadAll(reader)
	if err != nil {
		return nil, fmt.Errorf("failed to read input: %w", err)
	}

	var pr o2imsv1alpha1.ProvisioningRequest
	if err := yaml.Unmarshal(data, &pr); err != nil {
		return nil, fmt.Errorf("failed to unmarshal YAML: %w", err)
	}

	return &pr, nil
}

// createO2IMSClient creates an O2 IMS client from REST config
func createO2IMSClient(config *rest.Config) (o2imsclient.O2IMSClient, error) {
	clientConfig := o2imsclient.ClientConfig{
		RestConfig: config,
		Namespace:  globalOpts.Namespace,
	}
	return o2imsclient.NewO2IMSClient(clientConfig)
}

// outputProvisioningRequest outputs a ProvisioningRequest in the specified format
func outputProvisioningRequest(pr *o2imsv1alpha1.ProvisioningRequest, format string) error {
	switch format {
	case "json":
		data, err := json.MarshalIndent(pr, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal JSON: %w", err)
		}
		fmt.Println(string(data))
	case "yaml":
		data, err := yaml.Marshal(pr)
		if err != nil {
			return fmt.Errorf("failed to marshal YAML: %w", err)
		}
		fmt.Print(string(data))
	default:
		return fmt.Errorf("unsupported output format: %s", format)
	}
	return nil
}

// getO2IMSClient creates the appropriate client based on fake mode
func getO2IMSClient() (o2imsclient.O2IMSClient, error) {
	if globalOpts.Fake {
		// Create fake client with proper scheme
		scheme := runtime.NewScheme()
		if err := o2imsv1alpha1.AddToScheme(scheme); err != nil {
			return nil, fmt.Errorf("failed to add scheme: %w", err)
		}
		
		opts := o2imsclient.FakeClientOptions{
			Scheme: scheme,
			InitialObjects: []client.Object{}, // Start with empty objects
		}
		return o2imsclient.NewFakeO2IMSClient(opts), nil
	}
	
	// Get REST config and create real client
	config, err := GetRestConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to get kubeconfig: %w", err)
	}
	
	return createO2IMSClient(config)
}

// parseConditionType converts string condition to condition type
func parseConditionType(condition string) (o2imsv1alpha1.ProvisioningRequestConditionType, error) {
	switch condition {
	case "Pending":
		return o2imsv1alpha1.ConditionTypePending, nil
	case "Processing":
		return o2imsv1alpha1.ConditionTypeProcessing, nil
	case "Ready":
		return o2imsv1alpha1.ConditionTypeReady, nil
	case "Failed":
		return o2imsv1alpha1.ConditionTypeFailed, nil
	default:
		return "", fmt.Errorf("invalid condition type: %s", condition)
	}
}

// outputProvisioningRequestList outputs a list of ProvisioningRequests
func outputProvisioningRequestList(list *o2imsv1alpha1.ProvisioningRequestList, format string) error {
	switch format {
	case "table":
		fmt.Printf("%-20s %-15s %-10s %-10s\n", "NAME", "TARGET", "PHASE", "AGE")
		for _, pr := range list.Items {
			age := "unknown"
			if pr.CreationTimestamp.Time.Unix() > 0 {
				age = time.Since(pr.CreationTimestamp.Time).Round(time.Second).String()
			}
			fmt.Printf("%-20s %-15s %-10s %-10s\n", 
				pr.Name, 
				pr.Spec.TargetCluster, 
				pr.Status.Phase, 
				age)
		}
		return nil
	case "json":
		data, err := json.MarshalIndent(list, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal JSON: %w", err)
		}
		fmt.Println(string(data))
	case "yaml":
		data, err := yaml.Marshal(list)
		if err != nil {
			return fmt.Errorf("failed to marshal YAML: %w", err)
		}
		fmt.Print(string(data))
	default:
		return fmt.Errorf("unsupported output format: %s", format)
	}
	return nil
}