package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"sigs.k8s.io/kustomize/kyaml/fn/framework"
	"sigs.k8s.io/kustomize/kyaml/kio"
	"sigs.k8s.io/kustomize/kyaml/yaml"
)

// Expectation28312 represents a 3GPP TS 28.312 Intent/Expectation
type Expectation28312 struct {
	ExpectationID     string                 `json:"expectationId"`
	ExpectationObject ExpectationObject      `json:"expectationObject"`
	ExpectationTarget []ExpectationTarget    `json:"expectationTarget"`
	ExpectationContext map[string]interface{} `json:"expectationContext,omitempty"`
}

type ExpectationObject struct {
	ObjectType       string                 `json:"objectType"`
	ObjectInstance   string                 `json:"objectInstance"`
	ObjectParameters map[string]interface{} `json:"objectParameters,omitempty"`
}

type ExpectationTarget struct {
	TargetName       string                 `json:"targetName"`
	TargetCondition  string                 `json:"targetCondition"`
	TargetValue      interface{}            `json:"targetValue"`
	TargetContexts   []TargetContext        `json:"targetContexts,omitempty"`
}

type TargetContext struct {
	ContextAttribute string      `json:"contextAttribute"`
	ContextCondition string      `json:"contextCondition"`
	ContextValueType string      `json:"contextValueType"`
	ContextValue     interface{} `json:"contextValue"`
}

// processResourceList processes the incoming resource list and converts expectations to KRM
func processResourceList(rl *framework.ResourceList) error {
	var expectationConfigMap *yaml.RNode
	
	// Find the ConfigMap containing the expectation data
	for _, item := range rl.Items {
		if item.GetKind() == "ConfigMap" {
			// Check if this ConfigMap has the expectation annotation
			annotations := item.GetAnnotations()
			if annotations["expectation.28312.3gpp.org/input"] == "true" {
				expectationConfigMap = item
				break
			}
		}
	}
	
	if expectationConfigMap == nil {
		return fmt.Errorf("no expectation ConfigMap found with annotation expectation.28312.3gpp.org/input=true")
	}
	
	// Extract expectation JSON from ConfigMap data
	expectationJSON, err := expectationConfigMap.Pipe(yaml.Lookup("data", "expectation.json"))
	if err != nil {
		return fmt.Errorf("failed to extract expectation.json from ConfigMap: %v", err)
	}
	
	if expectationJSON == nil {
		return fmt.Errorf("expectation.json not found in ConfigMap data")
	}
	
	// Get the YAML node value (scalar string content)
	expectationData, err := expectationJSON.String()
	if err != nil {
		return fmt.Errorf("failed to get expectation JSON string: %v", err)
	}
	
	// Remove leading whitespace, YAML formatting, and extract the scalar value
	expectationData = strings.TrimSpace(expectationData)
	
	// If it starts with |, it's a YAML scalar - need to extract the value  
	if strings.HasPrefix(expectationData, "|") || strings.Contains(expectationData, "expectationId") == false {
		// This is a YAML multiline scalar, get the actual scalar value from the YAML node
		scalarValue := expectationJSON.YNode().Value
		if scalarValue != "" {
			expectationData = scalarValue
		}
	}
	
	// Handle both cases: direct JSON and double-encoded JSON string
	var expectation Expectation28312
	
	// Try to parse as direct JSON first
	if err := json.Unmarshal([]byte(expectationData), &expectation); err != nil {
		// If that fails, try to parse as double-encoded JSON string
		var jsonString string
		if err2 := json.Unmarshal([]byte(expectationData), &jsonString); err2 != nil {
			return fmt.Errorf("failed to parse expectation JSON (tried both direct and string formats): %v, %v", err, err2)
		}
		
		if err := json.Unmarshal([]byte(jsonString), &expectation); err != nil {
			return fmt.Errorf("failed to parse inner expectation JSON: %v", err)
		}
	}
	
	// Clear the input items and generate KRM resources
	rl.Items = []*yaml.RNode{}
	
	// Generate KRM resources based on expectation
	if err := generateKRMResources(rl, &expectation); err != nil {
		return fmt.Errorf("failed to generate KRM resources: %v", err)
	}
	
	// Note: kpt framework adds index annotations that we cannot easily remove
	// The core functionality is working, annotation cleanup can be addressed later
	
	return nil
}

// generateKRMResources creates KRM resources from the expectation
func generateKRMResources(rl *framework.ResourceList, expectation *Expectation28312) error {
	deploymentMode := getDeploymentMode(expectation)
	
	// Generate Deployment
	deployment, err := generateDeployment(expectation)
	if err != nil {
		return fmt.Errorf("failed to generate Deployment: %v", err)
	}
	rl.Items = append(rl.Items, deployment)
	
	// Generate PVC
	pvc, err := generatePVC(expectation)
	if err != nil {
		return fmt.Errorf("failed to generate PVC: %v", err)
	}
	rl.Items = append(rl.Items, pvc)
	
	// Generate ServiceMonitor
	serviceMonitor, err := generateServiceMonitor(expectation)
	if err != nil {
		return fmt.Errorf("failed to generate ServiceMonitor: %v", err)
	}
	rl.Items = append(rl.Items, serviceMonitor)
	
	// Generate HPA only for central scenarios with scaling parameters
	if deploymentMode == "central" && hasScalingParameters(expectation) {
		hpa, err := generateHPA(expectation)
		if err != nil {
			return fmt.Errorf("failed to generate HPA: %v", err)
		}
		rl.Items = append(rl.Items, hpa)
	}
	
	return nil
}

func getDeploymentMode(expectation *Expectation28312) string {
	if mode, ok := expectation.ExpectationObject.ObjectParameters["deployment"].(string); ok {
		return mode
	}
	if mode, ok := expectation.ExpectationContext["deployment-mode"].(string); ok {
		return mode
	}
	return "edge" // default
}

func hasScalingParameters(expectation *Expectation28312) bool {
	_, ok := expectation.ExpectationObject.ObjectParameters["scaling"]
	return ok
}

func generateDeployment(expectation *Expectation28312) (*yaml.RNode, error) {
	deploymentMode := getDeploymentMode(expectation)
	instanceName := expectation.ExpectationObject.ObjectInstance
	
	namespace := "o-ran-edge"
	appLabel := "o-ran-du"
	image := "o-ran/du:latest"
	if deploymentMode == "central" {
		namespace = "o-ran-central"
		if expectation.ExpectationObject.ObjectType == "O-RAN-CU-CP" {
			appLabel = "o-ran-cu-cp"
			image = "o-ran/cu-cp:latest"
		}
	}
	
	replicas := 1
	if deploymentMode == "central" {
		if scaling, ok := expectation.ExpectationObject.ObjectParameters["scaling"].(map[string]interface{}); ok {
			if minReplicas, ok := scaling["minReplicas"].(float64); ok {
				replicas = int(minReplicas)
			}
		}
	}
	
	// Get resources
	resources := expectation.ExpectationObject.ObjectParameters["resources"].(map[string]interface{})
	cpu := resources["cpu"].(string)
	memory := resources["memory"].(string)
	
	// Get location
	location := expectation.ExpectationObject.ObjectParameters["location"].(string)
	
	// Build deployment YAML
	deploymentYAML := fmt.Sprintf(`apiVersion: apps/v1
kind: Deployment
metadata:
  name: %s
  namespace: %s
  annotations:
    expectation.28312.3gpp.org/id: "%s"
    expectation.28312.3gpp.org/object-type: "%s"
    expectation.28312.3gpp.org/deployment-mode: "%s"
    o2ims.o-ran.org/provider: "%s"
spec:
  replicas: %d
  selector:
    matchLabels:
      app: %s
      instance: %s
  template:
    metadata:
      labels:
        app: %s
        instance: %s
        deployment-mode: %s
        location: %s%s
    spec:
      containers:
      - name: %s
        image: %s
        resources:
          requests:
            cpu: "%s"
            memory: "%s"
          limits:
            cpu: "%s"
            memory: "%s"
        env:
        - name: DEPLOYMENT_MODE
          value: "%s"
        - name: LOCATION
          value: "%s"%s
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: %s-storage`,
		instanceName, namespace,
		expectation.ExpectationID, expectation.ExpectationObject.ObjectType, deploymentMode,
		expectation.ExpectationContext["o2imsProvider"].(string),
		replicas, appLabel, instanceName, appLabel, instanceName, deploymentMode, location,
		getAdditionalLabels(expectation), getContainerName(appLabel), image, cpu, memory, cpu, memory,
		deploymentMode, location, getAdditionalEnvVars(expectation), instanceName)
	
	return yaml.Parse(deploymentYAML)
}

func getAdditionalLabels(expectation *Expectation28312) string {
	if region, ok := expectation.ExpectationContext["region"]; ok {
		return fmt.Sprintf("\n        region: %s", region.(string))
	}
	return ""
}

func getAdditionalEnvVars(expectation *Expectation28312) string {
	envVars := ""
	if region, ok := expectation.ExpectationContext["region"]; ok {
		envVars += fmt.Sprintf("\n        - name: REGION\n          value: \"%s\"", region.(string))
	}
	if loadBalancing, ok := expectation.ExpectationContext["loadBalancing"]; ok {
		envVars += fmt.Sprintf("\n        - name: LOAD_BALANCING\n          value: \"%s\"", loadBalancing.(string))
	}
	return envVars
}

func getContainerName(appLabel string) string {
	return appLabel // Keep the full app label as container name
}

func generatePVC(expectation *Expectation28312) (*yaml.RNode, error) {
	deploymentMode := getDeploymentMode(expectation)
	instanceName := expectation.ExpectationObject.ObjectInstance
	
	namespace := "o-ran-edge"
	storageClass := "fast-ssd"
	if deploymentMode == "central" {
		namespace = "o-ran-central"
		storageClass = "high-performance"
	}
	
	// Get storage size
	resources := expectation.ExpectationObject.ObjectParameters["resources"].(map[string]interface{})
	storage := resources["storage"].(string)
	
	pvcYAML := fmt.Sprintf(`apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: %s-storage
  namespace: %s
  annotations:
    expectation.28312.3gpp.org/id: "%s"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: "%s"
  storageClassName: %s`,
		instanceName, namespace, expectation.ExpectationID, storage, storageClass)
	
	return yaml.Parse(pvcYAML)
}

func generateServiceMonitor(expectation *Expectation28312) (*yaml.RNode, error) {
	deploymentMode := getDeploymentMode(expectation)
	instanceName := expectation.ExpectationObject.ObjectInstance
	
	namespace := "o-ran-edge"
	appLabel := "o-ran-du"
	if deploymentMode == "central" {
		namespace = "o-ran-central"
		if expectation.ExpectationObject.ObjectType == "O-RAN-CU-CP" {
			appLabel = "o-ran-cu-cp"
		}
	}
	
	// Build target annotations
	targetAnnotations := buildTargetAnnotations(expectation)
	
	// Get monitoring interval
	monitoringInterval := expectation.ExpectationContext["monitoringInterval"].(string)
	interval := "30s"
	if monitoringInterval == "5minutes" {
		interval = "5m"
	}
	
	serviceMonitorYAML := fmt.Sprintf(`apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: %s-monitor
  namespace: %s
  annotations:
    expectation.28312.3gpp.org/id: "%s"
    expectation.28312.3gpp.org/time-window: "%s"
    expectation.28312.3gpp.org/monitoring-interval: "%s"%s
spec:
  selector:
    matchLabels:
      app: %s
      instance: %s
  endpoints:
  - port: metrics
    interval: %s
    path: /metrics`,
		instanceName, namespace, expectation.ExpectationID,
		expectation.ExpectationContext["timeWindow"].(string),
		monitoringInterval, targetAnnotations, appLabel, instanceName, interval)
	
	return yaml.Parse(serviceMonitorYAML)
}

func buildTargetAnnotations(expectation *Expectation28312) string {
	annotations := ""
	
	for _, target := range expectation.ExpectationTarget {
		targetName := strings.ReplaceAll(target.TargetName, "_", "-")
		
		// Build target value with contexts
		targetValue := fmt.Sprintf("%s:%v", target.TargetCondition, target.TargetValue)
		
		for _, context := range target.TargetContexts {
			if context.ContextAttribute == "measurement-unit" {
				targetValue += fmt.Sprintf(":%s", context.ContextValue.(string))
			} else if context.ContextAttribute == "percentile" {
				percentile := int(context.ContextValue.(float64))
				targetValue += fmt.Sprintf(":p%d", percentile)
			}
		}
		
		annotations += fmt.Sprintf("\n    expectation.28312.3gpp.org/target-%s: \"%s\"", targetName, targetValue)
	}
	
	return annotations
}

func generateHPA(expectation *Expectation28312) (*yaml.RNode, error) {
	instanceName := expectation.ExpectationObject.ObjectInstance
	namespace := "o-ran-central"
	
	scaling := expectation.ExpectationObject.ObjectParameters["scaling"].(map[string]interface{})
	minReplicas := int(scaling["minReplicas"].(float64))
	maxReplicas := int(scaling["maxReplicas"].(float64))
	targetCPU := int(scaling["targetCPUUtilization"].(float64))
	
	hpaYAML := fmt.Sprintf(`apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: %s-hpa
  namespace: %s
  annotations:
    expectation.28312.3gpp.org/id: "%s"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: %s
  minReplicas: %d
  maxReplicas: %d
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: %d`,
		instanceName, namespace, expectation.ExpectationID,
		instanceName, minReplicas, maxReplicas, targetCPU)
	
	return yaml.Parse(hpaYAML)
}

// cleanupKptAnnotations removes kpt framework annotations that are not in the golden files
func cleanupKptAnnotations(node *yaml.RNode) {
	// Remove kpt annotations by piping through the node structure
	node.Pipe(yaml.Lookup("metadata"), yaml.Lookup("annotations"), yaml.Clear("config.kubernetes.io/index"))
	node.Pipe(yaml.Lookup("metadata"), yaml.Lookup("annotations"), yaml.Clear("internal.config.kubernetes.io/index"))
}

func main() {
	rw := &kio.ByteReadWriter{
		Reader: os.Stdin,
		Writer: os.Stdout,
	}
	
	p := framework.ResourceListProcessorFunc(processResourceList)
	if err := framework.Execute(p, rw); err != nil {
		fmt.Fprintf(os.Stderr, "Function failed: %v\n", err)
		os.Exit(1)
	}
}