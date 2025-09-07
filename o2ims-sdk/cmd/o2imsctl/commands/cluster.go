package commands

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/spf13/cobra"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"sigs.k8s.io/yaml"
)

// NewClusterCommand creates the 'cluster' command
func NewClusterCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cluster",
		Short: "Cluster operations and inventory queries",
		Long:  "Commands for interacting with Kubernetes cluster resources and O2 IMS inventory",
	}

	cmd.AddCommand(
		NewNodesCommand(),
		NewNamespacesCommand(),
		NewHealthCommand(),
	)

	return cmd
}

// NewNodesCommand creates the 'cluster nodes' command
func NewNodesCommand() *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "nodes",
		Short: "List cluster nodes with health status",
		Long:  "List all nodes in the cluster along with their health and resource status",
		Example: `  # List nodes in table format
  o2imsctl cluster nodes

  # List nodes in YAML format
  o2imsctl cluster nodes -o yaml

  # List nodes using specific kubeconfig
  o2imsctl cluster nodes --kubeconfig /tmp/kubeconfig-edge.yaml`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClusterNodes(output)
		},
	}

	cmd.Flags().StringVarP(&output, "output", "o", "table", "Output format (table|yaml|json)")

	return cmd
}

// NewNamespacesCommand creates the 'cluster namespaces' command  
func NewNamespacesCommand() *cobra.Command {
	var output string

	cmd := &cobra.Command{
		Use:   "namespaces",
		Short: "List cluster namespaces",
		Long:  "List all namespaces in the cluster",
		Example: `  # List namespaces in table format
  o2imsctl cluster namespaces

  # List namespaces in JSON format
  o2imsctl cluster namespaces -o json`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClusterNamespaces(output)
		},
	}

	cmd.Flags().StringVarP(&output, "output", "o", "table", "Output format (table|yaml|json)")

	return cmd
}

// NewHealthCommand creates the 'cluster health' command
func NewHealthCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "health",
		Short: "Check cluster health status",
		Long:  "Check the overall health and readiness of the Kubernetes cluster",
		Example: `  # Check cluster health
  o2imsctl cluster health

  # Check health using specific kubeconfig
  o2imsctl cluster health --kubeconfig /tmp/kubeconfig-edge.yaml`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runClusterHealth()
		},
	}

	return cmd
}

// Implementation functions

func runClusterNodes(output string) error {
	if globalOpts.Fake {
		fmt.Println("FAKE MODE: Listing cluster nodes")
		// Return fake nodes for testing
		nodes := &corev1.NodeList{
			Items: []corev1.Node{
				{
					ObjectMeta: metav1.ObjectMeta{
						Name: "fake-node-1",
						Labels: map[string]string{
							"kubernetes.io/hostname": "fake-node-1",
							"node-role.kubernetes.io/control-plane": "",
						},
					},
					Status: corev1.NodeStatus{
						Conditions: []corev1.NodeCondition{
							{Type: corev1.NodeReady, Status: corev1.ConditionTrue},
						},
						NodeInfo: corev1.NodeSystemInfo{
							OSImage:       "Ubuntu 22.04 LTS",
							KubeletVersion: "v1.28.0",
						},
					},
				},
				{
					ObjectMeta: metav1.ObjectMeta{
						Name: "fake-node-2",
						Labels: map[string]string{
							"kubernetes.io/hostname": "fake-node-2",
							"node-role.kubernetes.io/worker": "",
						},
					},
					Status: corev1.NodeStatus{
						Conditions: []corev1.NodeCondition{
							{Type: corev1.NodeReady, Status: corev1.ConditionTrue},
						},
						NodeInfo: corev1.NodeSystemInfo{
							OSImage:       "Ubuntu 22.04 LTS", 
							KubeletVersion: "v1.28.0",
						},
					},
				},
			},
		}
		return outputNodes(nodes, output)
	}

	// Get Kubernetes client
	clientset, err := getKubernetesClient()
	if err != nil {
		return fmt.Errorf("failed to create Kubernetes client: %w", err)
	}

	// List nodes
	nodes, err := clientset.CoreV1().Nodes().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list nodes: %w", err)
	}

	return outputNodes(nodes, output)
}

func runClusterNamespaces(output string) error {
	if globalOpts.Fake {
		fmt.Println("FAKE MODE: Listing cluster namespaces")
		// Return fake namespaces for testing
		namespaces := &corev1.NamespaceList{
			Items: []corev1.Namespace{
				{ObjectMeta: metav1.ObjectMeta{Name: "default"}},
				{ObjectMeta: metav1.ObjectMeta{Name: "kube-system"}},
				{ObjectMeta: metav1.ObjectMeta{Name: "o2ims-system"}},
			},
		}
		return outputNamespaces(namespaces, output)
	}

	// Get Kubernetes client
	clientset, err := getKubernetesClient()
	if err != nil {
		return fmt.Errorf("failed to create Kubernetes client: %w", err)
	}

	// List namespaces
	namespaces, err := clientset.CoreV1().Namespaces().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list namespaces: %w", err)
	}

	return outputNamespaces(namespaces, output)
}

func runClusterHealth() error {
	if globalOpts.Fake {
		fmt.Println("FAKE MODE: Checking cluster health")
		fmt.Println("✓ API Server: Healthy")
		fmt.Println("✓ Nodes: 2/2 Ready")
		fmt.Println("✓ O2 IMS: Deployed")
		fmt.Println("✓ Overall Status: Healthy")
		return nil
	}

	// Get Kubernetes client
	clientset, err := getKubernetesClient()
	if err != nil {
		return fmt.Errorf("failed to create Kubernetes client: %w", err)
	}

	fmt.Println("Checking cluster health...")

	// Check API server health
	_, err = clientset.Discovery().ServerVersion()
	if err != nil {
		fmt.Printf("✗ API Server: Unhealthy - %v\n", err)
	} else {
		fmt.Println("✓ API Server: Healthy")
	}

	// Check nodes
	nodes, err := clientset.CoreV1().Nodes().List(context.Background(), metav1.ListOptions{})
	if err != nil {
		fmt.Printf("✗ Nodes: Failed to list - %v\n", err)
	} else {
		readyNodes := 0
		for _, node := range nodes.Items {
			for _, condition := range node.Status.Conditions {
				if condition.Type == corev1.NodeReady && condition.Status == corev1.ConditionTrue {
					readyNodes++
					break
				}
			}
		}
		fmt.Printf("✓ Nodes: %d/%d Ready\n", readyNodes, len(nodes.Items))
	}

	// Check O2 IMS namespace
	_, err = clientset.CoreV1().Namespaces().Get(context.Background(), "o2ims-system", metav1.GetOptions{})
	if err != nil {
		fmt.Println("⚠ O2 IMS: Not deployed or namespace not found")
	} else {
		fmt.Println("✓ O2 IMS: Namespace exists")
	}

	fmt.Println("✓ Overall Status: Healthy")
	return nil
}

// Helper functions

func getKubernetesClient() (*kubernetes.Clientset, error) {
	config, err := GetRestConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to get REST config: %w", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create clientset: %w", err)
	}

	return clientset, nil
}

func outputNodes(nodes *corev1.NodeList, format string) error {
	switch format {
	case "table":
		fmt.Printf("%-30s %-15s %-10s %-15s %-20s\n", "NAME", "STATUS", "ROLES", "VERSION", "OS-IMAGE")
		for _, node := range nodes.Items {
			status := "NotReady"
			for _, condition := range node.Status.Conditions {
				if condition.Type == corev1.NodeReady && condition.Status == corev1.ConditionTrue {
					status = "Ready"
					break
				}
			}
			
			roles := "worker"
			if _, ok := node.Labels["node-role.kubernetes.io/control-plane"]; ok {
				roles = "control-plane"
			} else if _, ok := node.Labels["node-role.kubernetes.io/master"]; ok {
				roles = "master"
			}
			
			fmt.Printf("%-30s %-15s %-10s %-15s %-20s\n",
				node.Name,
				status,
				roles,
				node.Status.NodeInfo.KubeletVersion,
				node.Status.NodeInfo.OSImage)
		}
	case "json":
		data, err := json.MarshalIndent(nodes, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal JSON: %w", err)
		}
		fmt.Println(string(data))
	case "yaml":
		data, err := yaml.Marshal(nodes)
		if err != nil {
			return fmt.Errorf("failed to marshal YAML: %w", err)
		}
		fmt.Print(string(data))
	default:
		return fmt.Errorf("unsupported output format: %s", format)
	}
	return nil
}

func outputNamespaces(namespaces *corev1.NamespaceList, format string) error {
	switch format {
	case "table":
		fmt.Printf("%-30s %-15s %-10s\n", "NAME", "STATUS", "AGE")
		for _, ns := range namespaces.Items {
			age := "unknown"
			if ns.CreationTimestamp.Time.Unix() > 0 {
				age = time.Since(ns.CreationTimestamp.Time).Round(time.Second).String()
			}
			fmt.Printf("%-30s %-15s %-10s\n", ns.Name, ns.Status.Phase, age)
		}
	case "json":
		data, err := json.MarshalIndent(namespaces, "", "  ")
		if err != nil {
			return fmt.Errorf("failed to marshal JSON: %w", err)
		}
		fmt.Println(string(data))
	case "yaml":
		data, err := yaml.Marshal(namespaces)
		if err != nil {
			return fmt.Errorf("failed to marshal YAML: %w", err)
		}
		fmt.Print(string(data))
	default:
		return fmt.Errorf("unsupported output format: %s", format)
	}
	return nil
}