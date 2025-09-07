package main

import (
	"encoding/json"
	"fmt"
	"strings"
)

// 3GPP TS 28.312 Expectation Types

// Expectation represents a 3GPP TS 28.312 Intent Expectation
type Expectation struct {
	ID      string             `json:"intentExpectationId"`
	Type    string             `json:"intentExpectationType"`
	Context ExpectationContext `json:"intentExpectationContext"`
	Target  ExpectationTarget  `json:"intentExpectationTarget"`
	Object  ExpectationObject  `json:"intentExpectationObject"`
}

// ExpectationContext defines the context conditions for the expectation
type ExpectationContext struct {
	Attribute  string   `json:"contextAttribute"`
	Condition  string   `json:"contextCondition"`
	ValueRange []string `json:"contextValueRange"`
}

// ExpectationTarget defines the target conditions and values
type ExpectationTarget struct {
	Attribute string `json:"targetAttribute"`
	Condition string `json:"targetCondition"`
	Value     string `json:"targetValue"`
}

// ExpectationObject defines the object type and instance
type ExpectationObject struct {
	Type     string `json:"objectType"`
	Instance string `json:"objectInstance"`
}

// KRM (Kubernetes Resource Model) Types

// KRMResourceSet represents a complete set of generated KRM resources
type KRMResourceSet struct {
	ConfigMap      *ConfigMap      `json:"configMap"`
	CustomResource *CustomResource `json:"customResource"`
}

// ConfigMap represents a Kubernetes ConfigMap resource
type ConfigMap struct {
	APIVersion string            `json:"apiVersion" yaml:"apiVersion"`
	Kind       string            `json:"kind" yaml:"kind"`
	Metadata   ResourceMetadata  `json:"metadata" yaml:"metadata"`
	Data       map[string]string `json:"data" yaml:"data"`
}

// CustomResource represents a custom resource (RANBundle, CNBundle, TNBundle)
type CustomResource struct {
	APIVersion string           `json:"apiVersion" yaml:"apiVersion"`
	Kind       string           `json:"kind" yaml:"kind"`
	Metadata   ResourceMetadata `json:"metadata" yaml:"metadata"`
	Spec       interface{}      `json:"spec" yaml:"spec"`
}

// ResourceMetadata represents Kubernetes resource metadata
type ResourceMetadata struct {
	Name        string            `json:"name" yaml:"name"`
	Namespace   string            `json:"namespace" yaml:"namespace"`
	Labels      map[string]string `json:"labels,omitempty" yaml:"labels,omitempty"`
	Annotations map[string]string `json:"annotations,omitempty" yaml:"annotations,omitempty"`
}

// Bundle Specification Types

// RANBundleSpec represents the specification for RAN-related expectations
type RANBundleSpec struct {
	ExpectationID    string                  `json:"expectationId" yaml:"expectationId"`
	ExpectationType  string                  `json:"expectationType" yaml:"expectationType"`
	NetworkFunctions []string                `json:"networkFunctions,omitempty" yaml:"networkFunctions,omitempty"`
	Performance      *PerformanceRequirement `json:"performance,omitempty" yaml:"performance,omitempty"`
	ObjectInstance   string                  `json:"objectInstance" yaml:"objectInstance"`
}

// CNBundleSpec represents the specification for Core Network expectations
type CNBundleSpec struct {
	ExpectationID   string               `json:"expectationId" yaml:"expectationId"`
	ExpectationType string               `json:"expectationType" yaml:"expectationType"`
	NetworkSlices   []string             `json:"networkSlices,omitempty" yaml:"networkSlices,omitempty"`
	Capacity        *CapacityRequirement `json:"capacity,omitempty" yaml:"capacity,omitempty"`
	ObjectInstance  string               `json:"objectInstance" yaml:"objectInstance"`
}

// TNBundleSpec represents the specification for Transport Network expectations
type TNBundleSpec struct {
	ExpectationID     string               `json:"expectationId" yaml:"expectationId"`
	ExpectationType   string               `json:"expectationType" yaml:"expectationType"`
	TransportNetworks []string             `json:"transportNetworks,omitempty" yaml:"transportNetworks,omitempty"`
	Coverage          *CoverageRequirement `json:"coverage,omitempty" yaml:"coverage,omitempty"`
	ObjectInstance    string               `json:"objectInstance" yaml:"objectInstance"`
}

// Requirement Types

// PerformanceRequirement represents performance-related requirements
type PerformanceRequirement struct {
	Throughput *Requirement `json:"throughput,omitempty" yaml:"throughput,omitempty"`
	Latency    *Requirement `json:"latency,omitempty" yaml:"latency,omitempty"`
	Jitter     *Requirement `json:"jitter,omitempty" yaml:"jitter,omitempty"`
}

// CapacityRequirement represents capacity-related requirements
type CapacityRequirement struct {
	Latency     *Requirement `json:"latency,omitempty" yaml:"latency,omitempty"`
	Throughput  *Requirement `json:"throughput,omitempty" yaml:"throughput,omitempty"`
	Connections *Requirement `json:"connections,omitempty" yaml:"connections,omitempty"`
}

// CoverageRequirement represents coverage-related requirements
type CoverageRequirement struct {
	Availability *Requirement `json:"availability,omitempty" yaml:"availability,omitempty"`
	Reliability  *Requirement `json:"reliability,omitempty" yaml:"reliability,omitempty"`
	Coverage     *Requirement `json:"coverage,omitempty" yaml:"coverage,omitempty"`
}

// Requirement represents a generic requirement with condition and value
type Requirement struct {
	Condition string `json:"condition" yaml:"condition"`
	Value     string `json:"value" yaml:"value"`
}

// Helper Functions

// GetObjectTypeKind maps object types to Kubernetes resource kinds
func (e *Expectation) GetObjectTypeKind() (string, string, error) {
	switch e.Object.Type {
	case "RANFunction":
		return "ran.nephio.org/v1alpha1", "RANBundle", nil
	case "CoreNetwork":
		return "cn.nephio.org/v1alpha1", "CNBundle", nil
	case "TransportNetwork":
		return "tn.nephio.org/v1alpha1", "TNBundle", nil
	default:
		return "", "", fmt.Errorf("unsupported object type: %s", e.Object.Type)
	}
}

// GetResourceName generates a deterministic resource name
func (e *Expectation) GetResourceName(prefix string) string {
	return fmt.Sprintf("%s-%s", prefix, e.ID)
}

// ToJSON converts the expectation to JSON string with compact array formatting
func (e *Expectation) ToJSON() (string, error) {
	jsonData, err := json.MarshalIndent(e, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal expectation to JSON: %w", err)
	}

	// Format arrays on single line to match golden files
	jsonStr := string(jsonData)
	jsonStr = compactJSONArrays(jsonStr)
	return jsonStr, nil
}

// compactJSONArrays formats JSON arrays to be on single lines
func compactJSONArrays(jsonStr string) string {
	// Simple array compacting for contextValueRange
	lines := strings.Split(jsonStr, "\n")
	var result []string
	inArray := false
	arrayStartIdx := -1

	for i, line := range lines {
		trimmedLine := strings.TrimSpace(line)

		// Detect array start
		if strings.Contains(trimmedLine, `"contextValueRange": [`) && strings.HasSuffix(trimmedLine, "[") {
			inArray = true
			arrayStartIdx = i
			result = append(result, line)
			continue
		}

		// Detect array end
		if inArray && strings.TrimSpace(line) == "]" {
			// Collect array elements and format on one line
			var elements []string
			for j := arrayStartIdx + 1; j < i; j++ {
				element := strings.TrimSpace(lines[j])
				element = strings.TrimSuffix(element, ",")
				elements = append(elements, element)
			}

			// Replace the array start line with compact format
			indent := strings.Repeat(" ", len(lines[arrayStartIdx])-len(strings.TrimLeft(lines[arrayStartIdx], " ")))
			compactArray := fmt.Sprintf(`%s"contextValueRange": [%s]`, indent, strings.Join(elements, ", "))
			result[len(result)-1] = compactArray

			inArray = false
			arrayStartIdx = -1
			continue
		}

		// Skip lines inside array (they're already processed)
		if inArray {
			continue
		}

		result = append(result, line)
	}

	return strings.Join(result, "\n")
}

// ValidateExpectation performs basic validation on expectation fields
func (e *Expectation) ValidateExpectation() error {
	if e.ID == "" {
		return fmt.Errorf("expectation ID is required")
	}
	if e.Type == "" {
		return fmt.Errorf("expectation type is required")
	}
	if e.Context.Attribute == "" {
		return fmt.Errorf("context attribute is required")
	}
	if e.Target.Attribute == "" {
		return fmt.Errorf("target attribute is required")
	}
	if e.Object.Type == "" {
		return fmt.Errorf("object type is required")
	}
	return nil
}
