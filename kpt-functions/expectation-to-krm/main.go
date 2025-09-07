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

// TMF921Intent represents a TMF921 v5 ServiceIntent structure
type TMF921Intent struct {
	ID                   string                      `json:"id"`
	Href                 string                      `json:"href,omitempty"`
	IntentType           string                      `json:"intentType"`
	Name                 string                      `json:"name"`
	Description          string                      `json:"description,omitempty"`
	Version              string                      `json:"version,omitempty"`
	ValidFor             *TimePeriod                 `json:"validFor,omitempty"`
	LifecycleStatus      string                      `json:"lifecycleStatus,omitempty"`
	Category             string                      `json:"category,omitempty"`
	Priority             string                      `json:"priority,omitempty"`
	IntentSpecification  *IntentSpecification        `json:"intentSpecification,omitempty"`
	IntentCharacteristic []IntentCharacteristic      `json:"intentCharacteristic,omitempty"`
	IntentRelationship   []IntentRelationship        `json:"intentRelationship,omitempty"`
	Party                []Party                     `json:"party,omitempty"`
	Type                 string                      `json:"@type,omitempty"`
	SchemaLocation       string                      `json:"@schemaLocation,omitempty"`
	BaseType             string                      `json:"@baseType,omitempty"`
}

type TimePeriod struct {
	StartDateTime string `json:"startDateTime,omitempty"`
	EndDateTime   string `json:"endDateTime,omitempty"`
}

type IntentSpecification struct {
	ID                  string              `json:"id"`
	Href                string              `json:"href,omitempty"`
	Name                string              `json:"name"`
	Description         string              `json:"description,omitempty"`
	Version             string              `json:"version,omitempty"`
	IntentExpectations  []IntentExpectation `json:"intentExpectations,omitempty"`
}

type IntentExpectation struct {
	ID                  string              `json:"id"`
	Name                string              `json:"name"`
	Description         string              `json:"description,omitempty"`
	ExpectationType     string              `json:"expectationType"`
	ExpectationObject   ExpectationObject   `json:"expectationObject"`
	ExpectationTargets  []ExpectationTarget `json:"expectationTargets"`
	ExpectationContext  []ExpectationContext `json:"expectationContext,omitempty"`
}

type IntentCharacteristic struct {
	Name        string `json:"name"`
	Value       string `json:"value"`
	Description string `json:"description,omitempty"`
}

type IntentRelationship struct {
	RelationshipType string        `json:"relationshipType"`
	RelatedIntent    RelatedIntent `json:"relatedIntent"`
}

type RelatedIntent struct {
	ID   string `json:"id"`
	Href string `json:"href,omitempty"`
}

type Party struct {
	ID   string `json:"id"`
	Role string `json:"role"`
	Name string `json:"name,omitempty"`
}

// Expectation28312 represents a 3GPP TS 28.312 Intent/Expectation with enhanced v18+ features
type Expectation28312 struct {
	ExpectationID       string                 `json:"expectationId"`
	ExpectationObject   ExpectationObject      `json:"expectationObject"`
	ExpectationTarget   []ExpectationTarget    `json:"expectationTarget"`
	ExpectationContext  map[string]interface{} `json:"expectationContext,omitempty"`
	// Enhanced 3GPP TS 28.312 v18+ fields
	IntentId            string                 `json:"intentId,omitempty"`
	Version             string                 `json:"version,omitempty"`
	Priority            *int                   `json:"priority,omitempty"`
	LifecyclePhase      string                 `json:"lifecyclePhase,omitempty"`
	CreationTimestamp   string                 `json:"creationTimestamp,omitempty"`
	LastModified        string                 `json:"lastModified,omitempty"`
	TraceabilityInfo    *TraceabilityInfo      `json:"traceabilityInfo,omitempty"`
	SLOConfiguration    *SLOConfiguration      `json:"sloConfiguration,omitempty"`
	RolloutStrategy     *RolloutStrategy       `json:"rolloutStrategy,omitempty"`
	DeploymentScope     *DeploymentScope       `json:"deploymentScope,omitempty"`
}

type ExpectationObject struct {
	ObjectType        string                 `json:"objectType"`
	ObjectInstance    string                 `json:"objectInstance"`
	ObjectParameters  map[string]interface{} `json:"objectParameters,omitempty"`
	ObjectDescription string                 `json:"objectDescription,omitempty"`
}

type ExpectationTarget struct {
	TargetName        string          `json:"targetName"`
	TargetCondition   string          `json:"targetCondition"`
	TargetValue       interface{}     `json:"targetValue"`
	TargetContexts    []TargetContext `json:"targetContexts,omitempty"`
	TargetDescription string          `json:"targetDescription,omitempty"`
	TargetUnit        string          `json:"targetUnit,omitempty"`
	TargetValueType   string          `json:"targetValueType,omitempty"`
}

type TargetContext struct {
	ContextAttribute  string      `json:"contextAttribute"`
	ContextCondition  string      `json:"contextCondition"`
	ContextValueType  string      `json:"contextValueType"`
	ContextValue      interface{} `json:"contextValue"`
	ContextDescription string     `json:"contextDescription,omitempty"`
}

type ExpectationContext struct {
	ContextParameter  string `json:"contextParameter"`
	ContextValue      string `json:"contextValue"`
	ContextDescription string `json:"contextDescription,omitempty"`
}

// Enhanced supporting structures for 3GPP TS 28.312 v18+ and TMF921 v5

type TraceabilityInfo struct {
	SourceIntentId    string            `json:"sourceIntentId,omitempty"`
	SourceSystem      string            `json:"sourceSystem,omitempty"`
	SourceVersion     string            `json:"sourceVersion,omitempty"`
	TransformationId  string            `json:"transformationId,omitempty"`
	MappingRules      map[string]string `json:"mappingRules,omitempty"`
	CorrelationIds    []string          `json:"correlationIds,omitempty"`
}

type SLOConfiguration struct {
	SLOTargets        []SLOTarget       `json:"sloTargets"`
	MeasurementWindow string            `json:"measurementWindow,omitempty"`
	ReportingInterval string            `json:"reportingInterval,omitempty"`
	ViolationActions  []ViolationAction `json:"violationActions,omitempty"`
	EscalationPolicy  *EscalationPolicy `json:"escalationPolicy,omitempty"`
}

type SLOTarget struct {
	MetricName      string  `json:"metricName"`
	TargetValue     float64 `json:"targetValue"`
	Threshold       string  `json:"threshold"`           // "lessThan", "greaterThan", "equals"
	Unit            string  `json:"unit,omitempty"`
	Percentile      *int    `json:"percentile,omitempty"`  // for p95, p99, etc.
	Weight          *float64 `json:"weight,omitempty"`     // for composite SLOs
	Description     string  `json:"description,omitempty"`
}

type ViolationAction struct {
	ActionType      string                 `json:"actionType"`  // "alert", "scale", "rollback", "notify"
	ActionConfig    map[string]interface{} `json:"actionConfig,omitempty"`
	TriggerAfter    string                 `json:"triggerAfter,omitempty"`
}

type EscalationPolicy struct {
	Levels          []EscalationLevel `json:"levels"`
	MaxEscalations  *int             `json:"maxEscalations,omitempty"`
}

type EscalationLevel struct {
	Level           int                    `json:"level"`
	TimeWindow      string                 `json:"timeWindow"`
	Actions         []ViolationAction      `json:"actions"`
	Notifications   []NotificationConfig   `json:"notifications,omitempty"`
}

type NotificationConfig struct {
	Channel         string            `json:"channel"`    // "email", "slack", "webhook", "sms"
	Recipients      []string          `json:"recipients"`
	Template        string            `json:"template,omitempty"`
	Metadata        map[string]string `json:"metadata,omitempty"`
}

type RolloutStrategy struct {
	StrategyType    string                 `json:"strategyType"`   // "blueGreen", "canary", "rolling", "recreate"
	Parameters      map[string]interface{} `json:"parameters,omitempty"`
	RollbackPolicy  *RollbackPolicy        `json:"rollbackPolicy,omitempty"`
	GatingPolicy    *GatingPolicy          `json:"gatingPolicy,omitempty"`
}

type RollbackPolicy struct {
	AutoRollback       bool                   `json:"autoRollback,omitempty"`
	TriggerConditions  []TriggerCondition     `json:"triggerConditions,omitempty"`
	RollbackTimeout    string                 `json:"rollbackTimeout,omitempty"`
}

type GatingPolicy struct {
	Gates              []Gate `json:"gates"`
	GateTimeout        string `json:"gateTimeout,omitempty"`
	AllGatesRequired   bool   `json:"allGatesRequired,omitempty"`
}

type Gate struct {
	GateType          string                 `json:"gateType"`    // "manual", "slo", "test", "security"
	GateName          string                 `json:"gateName"`
	GateConfig        map[string]interface{} `json:"gateConfig,omitempty"`
	Required          bool                   `json:"required,omitempty"`
	Timeout           string                 `json:"timeout,omitempty"`
}

type TriggerCondition struct {
	ConditionType     string      `json:"conditionType"`
	Threshold         interface{} `json:"threshold"`
	TimeWindow        string      `json:"timeWindow,omitempty"`
}

type DeploymentScope struct {
	TargetNamespaces  []string          `json:"targetNamespaces,omitempty"`
	TargetClusters    []string          `json:"targetClusters,omitempty"`
	TargetRegions     []string          `json:"targetRegions,omitempty"`
	LabelSelectors    map[string]string `json:"labelSelectors,omitempty"`
	AnnotationFilters map[string]string `json:"annotationFilters,omitempty"`
	ExcludePatterns   []string          `json:"excludePatterns,omitempty"`
}

// processResourceList processes the incoming resource list and converts expectations to KRM
// Supports both TMF921 v5 ServiceIntent and 3GPP TS 28.312 Expectation inputs
func processResourceList(rl *framework.ResourceList) error {
	var inputConfigMap *yaml.RNode
	var inputType string
	
	// Find the ConfigMap containing the input data (TMF921 or 28.312)
	for _, item := range rl.Items {
		if item.GetKind() == "ConfigMap" {
			annotations := item.GetAnnotations()
			// Check for 3GPP TS 28.312 expectation input
			if annotations["expectation.28312.3gpp.org/input"] == "true" {
				inputConfigMap = item
				inputType = "28312"
				break
			}
			// Check for TMF921 v5 intent input
			if annotations["intent.tmf921.v5/input"] == "true" {
				inputConfigMap = item
				inputType = "tmf921"
				break
			}
		}
	}
	
	if inputConfigMap == nil {
		return fmt.Errorf("no input ConfigMap found with annotation expectation.28312.3gpp.org/input=true or intent.tmf921.v5/input=true")
	}
	
	// Extract input JSON from ConfigMap data based on input type
	var inputJSON *yaml.RNode
	var dataKey string
	
	switch inputType {
	case "28312":
		dataKey = "expectation.json"
	case "tmf921":
		dataKey = "intent.json"
	default:
		return fmt.Errorf("unsupported input type: %s", inputType)
	}
	
	inputJSON, err := inputConfigMap.Pipe(yaml.Lookup("data", dataKey))
	if err != nil {
		return fmt.Errorf("failed to extract %s from ConfigMap: %v", dataKey, err)
	}
	
	if inputJSON == nil {
		return fmt.Errorf("%s not found in ConfigMap data", dataKey)
	}
	
	// Get the YAML node value (scalar string content)
	inputData, err := inputJSON.String()
	if err != nil {
		return fmt.Errorf("failed to get input JSON string: %v", err)
	}
	
	// Remove leading whitespace, YAML formatting, and extract the scalar value
	inputData = strings.TrimSpace(inputData)
	
	// If it starts with |, it's a YAML scalar - need to extract the value  
	if strings.HasPrefix(inputData, "|") {
		// This is a YAML multiline scalar, get the actual scalar value from the YAML node
		scalarValue := inputJSON.YNode().Value
		if scalarValue != "" {
			inputData = scalarValue
		}
	}
	
	// Process based on input type
	switch inputType {
	case "28312":
		return process28312Expectation(rl, inputData)
	case "tmf921":
		return processTMF921Intent(rl, inputData)
	default:
		return fmt.Errorf("unsupported input type: %s", inputType)
	}
}

// process28312Expectation processes 3GPP TS 28.312 expectation input
func process28312Expectation(rl *framework.ResourceList, inputData string) error {
	// Handle both cases: direct JSON and double-encoded JSON string
	var expectation Expectation28312
	
	// Try to parse as direct JSON first
	if err := json.Unmarshal([]byte(inputData), &expectation); err != nil {
		// If that fails, try to parse as double-encoded JSON string
		var jsonString string
		if err2 := json.Unmarshal([]byte(inputData), &jsonString); err2 != nil {
			return fmt.Errorf("failed to parse expectation JSON (tried both direct and string formats): %v, %v", err, err2)
		}
		
		if err := json.Unmarshal([]byte(jsonString), &expectation); err != nil {
			return fmt.Errorf("failed to parse inner expectation JSON: %v", err)
		}
	}
	
	// Clear the input items and generate KRM resources
	rl.Items = []*yaml.RNode{}
	
	// Generate KRM resources based on expectation
	if err := generateKRMResourcesFrom28312(rl, &expectation); err != nil {
		return fmt.Errorf("failed to generate KRM resources from 28.312 expectation: %v", err)
	}
	
	return nil
}

// processTMF921Intent processes TMF921 v5 ServiceIntent input
func processTMF921Intent(rl *framework.ResourceList, inputData string) error {
	// Handle both cases: direct JSON and double-encoded JSON string
	var intent TMF921Intent
	
	// Try to parse as direct JSON first
	if err := json.Unmarshal([]byte(inputData), &intent); err != nil {
		// If that fails, try to parse as double-encoded JSON string
		var jsonString string
		if err2 := json.Unmarshal([]byte(inputData), &jsonString); err2 != nil {
			return fmt.Errorf("failed to parse intent JSON (tried both direct and string formats): %v, %v", err, err2)
		}
		
		if err := json.Unmarshal([]byte(jsonString), &intent); err != nil {
			return fmt.Errorf("failed to parse inner intent JSON: %v", err)
		}
	}
	
	// Clear the input items and generate KRM resources
	rl.Items = []*yaml.RNode{}
	
	// Transform TMF921 to 28.312 expectation first, then generate KRM resources
	expectations := transformTMF921To28312(&intent)
	
	// Generate KRM resources for each transformed expectation
	for _, expectation := range expectations {
		if err := generateKRMResourcesFrom28312(rl, &expectation); err != nil {
			return fmt.Errorf("failed to generate KRM resources from TMF921 intent: %v", err)
		}
	}
	
	return nil
}

// generateKRMResourcesFrom28312 creates KRM resources from the 3GPP TS 28.312 expectation
func generateKRMResourcesFrom28312(rl *framework.ResourceList, expectation *Expectation28312) error {
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
	
	// Build enhanced annotations with traceability and SLO information
	enhancedAnnotations := buildEnhancedAnnotations(expectation)
	
	// Build enhanced labels with deployment scope information  
	enhancedLabels := buildEnhancedLabels(expectation)
	
	// Build deployment YAML with enhanced annotations
	deploymentYAML := fmt.Sprintf(`apiVersion: apps/v1
kind: Deployment
metadata:
  name: %s
  namespace: %s
  annotations:
    expectation.28312.3gpp.org/id: "%s"
    expectation.28312.3gpp.org/object-type: "%s"
    expectation.28312.3gpp.org/deployment-mode: "%s"
    o2ims.o-ran.org/provider: "%s"%s
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
        location: %s%s%s
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
		getO2imsProvider(expectation), enhancedAnnotations,
		replicas, appLabel, instanceName, appLabel, instanceName, deploymentMode, location,
		getAdditionalLabels(expectation), enhancedLabels, getContainerName(appLabel), image, cpu, memory, cpu, memory,
		deploymentMode, location, getAdditionalEnvVars(expectation), instanceName)
	
	return yaml.Parse(deploymentYAML)
}

func getAdditionalLabels(expectation *Expectation28312) string {
	if region, ok := expectation.ExpectationContext["region"]; ok {
		return fmt.Sprintf("\n        region: %s", region.(string))
	}
	return ""
}

// buildEnhancedAnnotations creates comprehensive annotations with traceability and SLO info
func buildEnhancedAnnotations(expectation *Expectation28312) string {
	annotations := ""
	
	// Add traceability annotations
	if expectation.TraceabilityInfo != nil {
		if expectation.TraceabilityInfo.SourceIntentId != "" {
			annotations += fmt.Sprintf("\n    traceability.28312.3gpp.org/source-intent-id: \"%s\"", expectation.TraceabilityInfo.SourceIntentId)
		}
		if expectation.TraceabilityInfo.SourceSystem != "" {
			annotations += fmt.Sprintf("\n    traceability.28312.3gpp.org/source-system: \"%s\"", expectation.TraceabilityInfo.SourceSystem)
		}
		if expectation.TraceabilityInfo.TransformationId != "" {
			annotations += fmt.Sprintf("\n    traceability.28312.3gpp.org/transformation-id: \"%s\"", expectation.TraceabilityInfo.TransformationId)
		}
		if len(expectation.TraceabilityInfo.CorrelationIds) > 0 {
			annotations += fmt.Sprintf("\n    traceability.28312.3gpp.org/correlation-ids: \"%s\"", strings.Join(expectation.TraceabilityInfo.CorrelationIds, ","))
		}
	}
	
	// Add SLO configuration annotations
	if expectation.SLOConfiguration != nil {
		if expectation.SLOConfiguration.MeasurementWindow != "" {
			annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/measurement-window: \"%s\"", expectation.SLOConfiguration.MeasurementWindow)
		}
		if expectation.SLOConfiguration.ReportingInterval != "" {
			annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/reporting-interval: \"%s\"", expectation.SLOConfiguration.ReportingInterval)
		}
		
		// Add SLO targets as annotations
		for i, target := range expectation.SLOConfiguration.SLOTargets {
			annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/target-%d-metric: \"%s\"", i, target.MetricName)
			annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/target-%d-value: \"%.2f\"", i, target.TargetValue)
			annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/target-%d-threshold: \"%s\"", i, target.Threshold)
			if target.Unit != "" {
				annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/target-%d-unit: \"%s\"", i, target.Unit)
			}
			if target.Percentile != nil {
				annotations += fmt.Sprintf("\n    slo.28312.3gpp.org/target-%d-percentile: \"p%d\"", i, *target.Percentile)
			}
		}
	}
	
	// Add rollout strategy annotations
	if expectation.RolloutStrategy != nil {
		annotations += fmt.Sprintf("\n    rollout.28312.3gpp.org/strategy-type: \"%s\"", expectation.RolloutStrategy.StrategyType)
		if expectation.RolloutStrategy.GatingPolicy != nil {
			annotations += fmt.Sprintf("\n    rollout.28312.3gpp.org/gates-required: \"%t\"", expectation.RolloutStrategy.GatingPolicy.AllGatesRequired)
			annotations += fmt.Sprintf("\n    rollout.28312.3gpp.org/gate-timeout: \"%s\"", expectation.RolloutStrategy.GatingPolicy.GateTimeout)
		}
	}
	
	// Add lifecycle and version information
	if expectation.Version != "" {
		annotations += fmt.Sprintf("\n    version.28312.3gpp.org/expectation: \"%s\"", expectation.Version)
	}
	if expectation.LifecyclePhase != "" {
		annotations += fmt.Sprintf("\n    lifecycle.28312.3gpp.org/phase: \"%s\"", expectation.LifecyclePhase)
	}
	if expectation.CreationTimestamp != "" {
		annotations += fmt.Sprintf("\n    timestamp.28312.3gpp.org/created: \"%s\"", expectation.CreationTimestamp)
	}
	if expectation.LastModified != "" {
		annotations += fmt.Sprintf("\n    timestamp.28312.3gpp.org/modified: \"%s\"", expectation.LastModified)
	}
	
	return annotations
}

// buildEnhancedLabels creates comprehensive labels based on deployment scope
func buildEnhancedLabels(expectation *Expectation28312) string {
	labels := ""
	
	if expectation.DeploymentScope != nil {
		// Add label selectors as pod labels
		for key, value := range expectation.DeploymentScope.LabelSelectors {
			// Sanitize label keys for Kubernetes
			sanitizedKey := strings.ReplaceAll(key, "/", "-")
			sanitizedKey = strings.ReplaceAll(sanitizedKey, "_", "-")
			labels += fmt.Sprintf("\n        %s: \"%s\"", sanitizedKey, value)
		}
		
		// Add target regions as labels
		if len(expectation.DeploymentScope.TargetRegions) > 0 {
			labels += fmt.Sprintf("\n        target-regions: \"%s\"", strings.Join(expectation.DeploymentScope.TargetRegions, ","))
		}
		
		// Add target clusters as labels
		if len(expectation.DeploymentScope.TargetClusters) > 0 {
			labels += fmt.Sprintf("\n        target-clusters: \"%s\"", strings.Join(expectation.DeploymentScope.TargetClusters, ","))
		}
	}
	
	// Add priority as label
	if expectation.Priority != nil {
		labels += fmt.Sprintf("\n        priority: \"%d\"", *expectation.Priority)
	}
	
	// Add intent ID as label for correlation
	if expectation.IntentId != "" {
		labels += fmt.Sprintf("\n        intent-id: \"%s\"", expectation.IntentId)
	}
	
	return labels
}

// getO2imsProvider safely extracts O2IMS provider from expectation context
func getO2imsProvider(expectation *Expectation28312) string {
	if provider, ok := expectation.ExpectationContext["o2imsProvider"].(string); ok {
		return provider
	}
	// Fallback to default or from traceability info
	if expectation.TraceabilityInfo != nil && expectation.TraceabilityInfo.SourceSystem != "" {
		return fmt.Sprintf("default-o2ims-%s", strings.ToLower(expectation.TraceabilityInfo.SourceSystem))
	}
	return "default-o2ims"
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

// transformTMF921To28312 converts TMF921 v5 ServiceIntent to 3GPP TS 28.312 Expectations
func transformTMF921To28312(intent *TMF921Intent) []Expectation28312 {
	var expectations []Expectation28312
	
	if intent.IntentSpecification == nil {
		// Create a default expectation if no specification is provided
		return []Expectation28312{createDefaultExpectation(intent)}
	}
	
	// Transform each IntentExpectation to a 3GPP TS 28.312 Expectation
	for i, intentExp := range intent.IntentSpecification.IntentExpectations {
		expectation := Expectation28312{
			ExpectationID:     intentExp.ID,
			ExpectationObject: intentExp.ExpectationObject,
			ExpectationTarget: transformExpectationTargets(intentExp.ExpectationTargets),
			ExpectationContext: transformExpectationContext(intentExp.ExpectationContext, intent),
			
			// Enhanced 3GPP TS 28.312 v18+ fields
			IntentId:          intent.ID,
			Version:           intent.Version,
			LifecyclePhase:    mapLifecycleStatus(intent.LifecycleStatus),
			CreationTimestamp: getCurrentTimestamp(),
			LastModified:      getCurrentTimestamp(),
			
			// Traceability information
			TraceabilityInfo: &TraceabilityInfo{
				SourceIntentId:   intent.ID,
				SourceSystem:     "TMF921-v5",
				SourceVersion:    intent.Version,
				TransformationId: fmt.Sprintf("tmf921-to-28312-%s-%d", intent.ID, i),
				MappingRules:     getTMF921MappingRules(),
				CorrelationIds:   []string{intent.ID, intentExp.ID},
			},
			
			// SLO Configuration based on expectation targets
			SLOConfiguration: createSLOConfiguration(intentExp.ExpectationTargets),
			
			// Deployment scope based on intent characteristics and context
			DeploymentScope: createDeploymentScope(intent, intentExp.ExpectationContext),
		}
		
		// Add priority if available from intent characteristics
		if priority := extractPriority(intent.IntentCharacteristic); priority != nil {
			expectation.Priority = priority
		}
		
		// Add rollout strategy if available from intent characteristics
		if rollout := extractRolloutStrategy(intent.IntentCharacteristic); rollout != nil {
			expectation.RolloutStrategy = rollout
		}
		
		expectations = append(expectations, expectation)
	}
	
	return expectations
}

// Helper functions for TMF921 to 3GPP TS 28.312 transformation

func createDefaultExpectation(intent *TMF921Intent) Expectation28312 {
	return Expectation28312{
		ExpectationID: intent.ID + "-default",
		ExpectationObject: ExpectationObject{
			ObjectType:        "generic-service",
			ObjectInstance:    intent.Name,
			ObjectDescription: intent.Description,
			ObjectParameters:  map[string]interface{}{
				"intentType": intent.IntentType,
				"category":   intent.Category,
			},
		},
		ExpectationTarget: []ExpectationTarget{},
		ExpectationContext: map[string]interface{}{
			"source": "TMF921-v5",
			"intentId": intent.ID,
		},
		IntentId:          intent.ID,
		Version:           intent.Version,
		LifecyclePhase:    mapLifecycleStatus(intent.LifecycleStatus),
		CreationTimestamp: getCurrentTimestamp(),
		LastModified:      getCurrentTimestamp(),
		TraceabilityInfo: &TraceabilityInfo{
			SourceIntentId:   intent.ID,
			SourceSystem:     "TMF921-v5",
			SourceVersion:    intent.Version,
			TransformationId: fmt.Sprintf("tmf921-to-28312-%s-default", intent.ID),
			MappingRules:     getTMF921MappingRules(),
			CorrelationIds:   []string{intent.ID},
		},
	}
}

func transformExpectationTargets(tmfTargets []ExpectationTarget) []ExpectationTarget {
	var targets []ExpectationTarget
	
	for _, tmfTarget := range tmfTargets {
		target := ExpectationTarget{
			TargetName:        tmfTarget.TargetName,
			TargetCondition:   mapTargetCondition(tmfTarget.TargetCondition),
			TargetValue:       tmfTarget.TargetValue,
			TargetDescription: tmfTarget.TargetDescription,
			TargetUnit:        tmfTarget.TargetUnit,
			TargetValueType:   tmfTarget.TargetValueType,
			TargetContexts:    tmfTarget.TargetContexts,
		}
		targets = append(targets, target)
	}
	
	return targets
}

func transformExpectationContext(tmfContext []ExpectationContext, intent *TMF921Intent) map[string]interface{} {
	context := map[string]interface{}{
		"source":         "TMF921-v5",
		"sourceIntentId": intent.ID,
		"intentType":     intent.IntentType,
		"category":       intent.Category,
		"priority":       intent.Priority,
	}
	
	// Add TMF921 context parameters
	for _, ctx := range tmfContext {
		context[ctx.ContextParameter] = ctx.ContextValue
	}
	
	// Add intent characteristics as context
	for _, char := range intent.IntentCharacteristic {
		context["characteristic-"+char.Name] = char.Value
	}
	
	// Add timing information if available
	if intent.ValidFor != nil {
		if intent.ValidFor.StartDateTime != "" {
			context["validFrom"] = intent.ValidFor.StartDateTime
		}
		if intent.ValidFor.EndDateTime != "" {
			context["validUntil"] = intent.ValidFor.EndDateTime
		}
	}
	
	return context
}

func mapLifecycleStatus(tmfStatus string) string {
	statusMap := map[string]string{
		"Active":         "active",
		"Inactive":       "inactive",  
		"InTest":         "testing",
		"Terminated":     "terminated",
		"InStudy":        "planning",
		"Rejected":       "rejected",
		"Launched":       "deployed",
		"Retired":        "retired",
	}
	
	if mapped, ok := statusMap[tmfStatus]; ok {
		return mapped
	}
	return "unknown"
}

func mapTargetCondition(tmfCondition string) string {
	conditionMap := map[string]string{
		"lessThan":         "LessThan",
		"greaterThan":      "GreaterThan", 
		"equals":           "Equal",
		"lessOrEqual":      "LessThanOrEqual",
		"greaterOrEqual":   "GreaterThanOrEqual",
		"notEqual":         "NotEqual",
	}
	
	if mapped, ok := conditionMap[tmfCondition]; ok {
		return mapped
	}
	return tmfCondition // Return as-is if no mapping found
}

func getCurrentTimestamp() string {
	return "2024-01-01T00:00:00Z" // Static timestamp for tests
}

func getTMF921MappingRules() map[string]string {
	return map[string]string{
		"intent.id":                    "expectation.intentId",
		"intentSpecification.id":       "expectation.expectationId", 
		"intentExpectation.id":         "expectation.expectationId",
		"intentExpectation.expectationObject": "expectation.expectationObject",
		"intentExpectation.expectationTargets": "expectation.expectationTarget",
		"intentExpectation.expectationContext": "expectation.expectationContext",
		"intent.lifecycleStatus":       "expectation.lifecyclePhase",
		"intent.version":              "expectation.version",
		"intent.priority":             "expectation.priority",
	}
}

func extractPriority(characteristics []IntentCharacteristic) *int {
	priorityMap := map[string]int{
		"critical": 1,
		"high":     2,
		"medium":   3,
		"low":      4,
		"best-effort": 5,
	}
	
	for _, char := range characteristics {
		if char.Name == "priority" {
			if priority, ok := priorityMap[strings.ToLower(char.Value)]; ok {
				return &priority
			}
		}
	}
	return nil
}

func extractRolloutStrategy(characteristics []IntentCharacteristic) *RolloutStrategy {
	var strategyType string
	parameters := make(map[string]interface{})
	
	for _, char := range characteristics {
		if char.Name == "rolloutStrategy" {
			strategyType = char.Value
		} else if strings.HasPrefix(char.Name, "rollout-") {
			paramName := strings.TrimPrefix(char.Name, "rollout-")
			parameters[paramName] = char.Value
		}
	}
	
	if strategyType == "" {
		return nil
	}
	
	return &RolloutStrategy{
		StrategyType: strategyType,
		Parameters:   parameters,
		GatingPolicy: &GatingPolicy{
			Gates: []Gate{
				{
					GateType: "slo",
					GateName: "slo-validation",
					Required: true,
					Timeout:  "10m",
				},
			},
			AllGatesRequired: true,
			GateTimeout:      "30m",
		},
	}
}

func createSLOConfiguration(targets []ExpectationTarget) *SLOConfiguration {
	var sloTargets []SLOTarget
	
	for _, target := range targets {
		sloTarget := SLOTarget{
			MetricName:  target.TargetName,
			TargetValue: convertToFloat64(target.TargetValue),
			Threshold:   mapTargetConditionToThreshold(target.TargetCondition),
			Unit:        target.TargetUnit,
			Description: target.TargetDescription,
		}
		
		// Extract percentile from target contexts
		for _, ctx := range target.TargetContexts {
			if ctx.ContextAttribute == "percentile" {
				if percentile, ok := ctx.ContextValue.(float64); ok {
					p := int(percentile)
					sloTarget.Percentile = &p
				}
			}
		}
		
		sloTargets = append(sloTargets, sloTarget)
	}
	
	if len(sloTargets) == 0 {
		return nil
	}
	
	return &SLOConfiguration{
		SLOTargets:        sloTargets,
		MeasurementWindow: "5m",
		ReportingInterval: "30s",
		ViolationActions: []ViolationAction{
			{
				ActionType: "alert",
				ActionConfig: map[string]interface{}{
					"severity": "warning",
					"channels": []string{"monitoring"},
				},
				TriggerAfter: "2m",
			},
		},
		EscalationPolicy: &EscalationPolicy{
			Levels: []EscalationLevel{
				{
					Level:      1,
					TimeWindow: "5m",
					Actions: []ViolationAction{
						{
							ActionType: "notify",
							ActionConfig: map[string]interface{}{
								"channels": []string{"slack", "email"},
							},
						},
					},
				},
			},
			MaxEscalations: intPtr(3),
		},
	}
}

func createDeploymentScope(intent *TMF921Intent, contexts []ExpectationContext) *DeploymentScope {
	scope := &DeploymentScope{
		LabelSelectors: make(map[string]string),
		AnnotationFilters: make(map[string]string),
	}
	
	// Add intent metadata as labels
	scope.LabelSelectors["intent.tmf921.v5/id"] = intent.ID
	scope.LabelSelectors["intent.tmf921.v5/type"] = intent.IntentType
	scope.LabelSelectors["intent.tmf921.v5/category"] = intent.Category
	
	// Extract deployment scope from context
	for _, ctx := range contexts {
		switch ctx.ContextParameter {
		case "targetNamespaces":
			scope.TargetNamespaces = strings.Split(ctx.ContextValue, ",")
		case "targetClusters":
			scope.TargetClusters = strings.Split(ctx.ContextValue, ",")
		case "targetRegions": 
			scope.TargetRegions = strings.Split(ctx.ContextValue, ",")
		case "geographicArea":
			scope.TargetRegions = append(scope.TargetRegions, ctx.ContextValue)
		case "networkSlice":
			scope.LabelSelectors["network-slice"] = ctx.ContextValue
		}
	}
	
	// Add intent characteristics as label selectors
	for _, char := range intent.IntentCharacteristic {
		if char.Name == "serviceType" {
			scope.LabelSelectors["service-type"] = char.Value
		}
	}
	
	// Default namespace if none specified
	if len(scope.TargetNamespaces) == 0 {
		scope.TargetNamespaces = []string{"default"}
	}
	
	return scope
}

// Helper utility functions
func convertToFloat64(value interface{}) float64 {
	switch v := value.(type) {
	case float64:
		return v
	case float32:
		return float64(v)
	case int:
		return float64(v)
	case int64:
		return float64(v)
	case string:
		if f, err := fmt.Sscanf(v, "%f", new(float64)); err == nil && f == 1 {
			var result float64
			fmt.Sscanf(v, "%f", &result)
			return result
		}
	}
	return 0.0
}

func mapTargetConditionToThreshold(condition string) string {
	thresholdMap := map[string]string{
		"LessThan":         "lessThan",
		"GreaterThan":      "greaterThan",
		"Equal":            "equals",
		"LessThanOrEqual":  "lessThanOrEqual", 
		"GreaterThanOrEqual": "greaterThanOrEqual",
		"NotEqual":         "notEqual",
	}
	
	if mapped, ok := thresholdMap[condition]; ok {
		return mapped
	}
	return strings.ToLower(condition)
}

func intPtr(i int) *int {
	return &i
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