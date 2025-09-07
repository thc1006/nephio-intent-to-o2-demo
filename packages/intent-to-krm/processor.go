package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// Processor handles the conversion from 3GPP TS 28.312 Expectation JSON to KRM YAML
type Processor struct {
	namespace string
}

// NewProcessor creates a new processor instance
func NewProcessor() *Processor {
	return &Processor{
		namespace: "intent-to-krm",
	}
}

// ProcessExpectation is the main entry point that converts JSON to YAML
func (p *Processor) ProcessExpectation(jsonData []byte) ([]byte, error) {
	// Parse the expectation JSON
	expectation, err := p.ParseExpectation(jsonData)
	if err != nil {
		return nil, fmt.Errorf("failed to parse expectation: %w", err)
	}

	// Generate KRM resources
	krm, err := p.GenerateKRM(expectation)
	if err != nil {
		return nil, fmt.Errorf("failed to generate KRM: %w", err)
	}

	// Convert to YAML
	yamlData, err := p.ConvertToYAML(krm)
	if err != nil {
		return nil, fmt.Errorf("failed to convert to YAML: %w", err)
	}

	return yamlData, nil
}

// ParseExpectation parses JSON data into an Expectation struct
func (p *Processor) ParseExpectation(jsonData []byte) (*Expectation, error) {
	var expectation Expectation
	if err := json.Unmarshal(jsonData, &expectation); err != nil {
		return nil, fmt.Errorf("invalid JSON format: %w", err)
	}

	// Validate the parsed expectation
	if err := expectation.ValidateExpectation(); err != nil {
		return nil, fmt.Errorf("expectation validation failed: %w", err)
	}

	return &expectation, nil
}

// GenerateKRM creates KRM resources from an expectation
func (p *Processor) GenerateKRM(expectation *Expectation) (*KRMResourceSet, error) {
	// Generate ConfigMap
	configMap, err := p.generateConfigMap(expectation)
	if err != nil {
		return nil, fmt.Errorf("failed to generate ConfigMap: %w", err)
	}

	// Generate Custom Resource based on object type
	customResource, err := p.generateCustomResource(expectation)
	if err != nil {
		return nil, fmt.Errorf("failed to generate custom resource: %w", err)
	}

	return &KRMResourceSet{
		ConfigMap:      configMap,
		CustomResource: customResource,
	}, nil
}

// generateConfigMap creates a ConfigMap containing the original expectation
func (p *Processor) generateConfigMap(expectation *Expectation) (*ConfigMap, error) {
	// Convert expectation to JSON string
	expectationJSON, err := expectation.ToJSON()
	if err != nil {
		return nil, err
	}

	// Create sorted labels and annotations for deterministic output
	labels := map[string]string{
		"expectation.nephio.org/id":          expectation.ID,
		"expectation.nephio.org/type":        expectation.Type,
		"expectation.nephio.org/object-type": expectation.Object.Type,
	}

	annotations := map[string]string{
		"expectation.nephio.org/context-attribute": expectation.Context.Attribute,
		"expectation.nephio.org/context-condition": expectation.Context.Condition,
		"expectation.nephio.org/target-attribute":  expectation.Target.Attribute,
		"expectation.nephio.org/target-condition":  expectation.Target.Condition,
		"expectation.nephio.org/target-value":      expectation.Target.Value,
	}

	return &ConfigMap{
		APIVersion: "v1",
		Kind:       "ConfigMap",
		Metadata: ResourceMetadata{
			Name:        expectation.GetResourceName("expectation"),
			Namespace:   p.namespace,
			Labels:      labels,
			Annotations: annotations,
		},
		Data: map[string]string{
			"expectation.json": expectationJSON,
		},
	}, nil
}

// generateCustomResource creates a custom resource based on expectation type
func (p *Processor) generateCustomResource(expectation *Expectation) (*CustomResource, error) {
	apiVersion, kind, err := expectation.GetObjectTypeKind()
	if err != nil {
		return nil, err
	}

	// Generate spec based on object type
	var spec interface{}
	switch expectation.Object.Type {
	case "RANFunction":
		spec = p.generateRANBundleSpec(expectation)
	case "CoreNetwork":
		spec = p.generateCNBundleSpec(expectation)
	case "TransportNetwork":
		spec = p.generateTNBundleSpec(expectation)
	default:
		return nil, fmt.Errorf("unsupported object type: %s", expectation.Object.Type)
	}

	labels := map[string]string{
		"expectation.nephio.org/id":   expectation.ID,
		"expectation.nephio.org/type": expectation.Type,
	}

	bundlePrefix := strings.ToLower(strings.TrimSuffix(kind, "Bundle"))
	resourceName := expectation.GetResourceName(bundlePrefix + "-bundle")

	return &CustomResource{
		APIVersion: apiVersion,
		Kind:       kind,
		Metadata: ResourceMetadata{
			Name:      resourceName,
			Namespace: p.namespace,
			Labels:    labels,
		},
		Spec: spec,
	}, nil
}

// generateRANBundleSpec creates a RAN bundle specification
func (p *Processor) generateRANBundleSpec(expectation *Expectation) *RANBundleSpec {
	spec := &RANBundleSpec{
		ExpectationID:   expectation.ID,
		ExpectationType: expectation.Type,
		ObjectInstance:  expectation.Object.Instance,
	}

	// Map context values to network functions
	if expectation.Context.Attribute == "networkFunction" {
		spec.NetworkFunctions = make([]string, len(expectation.Context.ValueRange))
		copy(spec.NetworkFunctions, expectation.Context.ValueRange)
		sort.Strings(spec.NetworkFunctions) // Ensure deterministic output
	}

	// Map target to performance requirements
	if expectation.Type == "ServicePerformance" {
		spec.Performance = &PerformanceRequirement{}
		switch expectation.Target.Attribute {
		case "throughput":
			spec.Performance.Throughput = &Requirement{
				Condition: expectation.Target.Condition,
				Value:     expectation.Target.Value,
			}
		case "latency":
			spec.Performance.Latency = &Requirement{
				Condition: expectation.Target.Condition,
				Value:     expectation.Target.Value,
			}
		}
	}

	return spec
}

// generateCNBundleSpec creates a Core Network bundle specification
func (p *Processor) generateCNBundleSpec(expectation *Expectation) *CNBundleSpec {
	spec := &CNBundleSpec{
		ExpectationID:   expectation.ID,
		ExpectationType: expectation.Type,
		ObjectInstance:  expectation.Object.Instance,
	}

	// Map context values to network slices
	if expectation.Context.Attribute == "networkSlice" {
		spec.NetworkSlices = make([]string, len(expectation.Context.ValueRange))
		copy(spec.NetworkSlices, expectation.Context.ValueRange)
		sort.Strings(spec.NetworkSlices) // Ensure deterministic output
	}

	// Map target to capacity requirements
	if expectation.Type == "ServiceCapacity" {
		spec.Capacity = &CapacityRequirement{}
		switch expectation.Target.Attribute {
		case "latency":
			spec.Capacity.Latency = &Requirement{
				Condition: expectation.Target.Condition,
				Value:     expectation.Target.Value,
			}
		case "throughput":
			spec.Capacity.Throughput = &Requirement{
				Condition: expectation.Target.Condition,
				Value:     expectation.Target.Value,
			}
		}
	}

	return spec
}

// generateTNBundleSpec creates a Transport Network bundle specification
func (p *Processor) generateTNBundleSpec(expectation *Expectation) *TNBundleSpec {
	spec := &TNBundleSpec{
		ExpectationID:   expectation.ID,
		ExpectationType: expectation.Type,
		ObjectInstance:  expectation.Object.Instance,
	}

	// Map context values to transport networks
	if expectation.Context.Attribute == "transportNetwork" {
		spec.TransportNetworks = make([]string, len(expectation.Context.ValueRange))
		copy(spec.TransportNetworks, expectation.Context.ValueRange)
		sort.Strings(spec.TransportNetworks) // Ensure deterministic output
	}

	// Map target to coverage requirements
	if expectation.Type == "ServiceCoverage" {
		spec.Coverage = &CoverageRequirement{}
		switch expectation.Target.Attribute {
		case "availability":
			spec.Coverage.Availability = &Requirement{
				Condition: expectation.Target.Condition,
				Value:     expectation.Target.Value,
			}
		case "reliability":
			spec.Coverage.Reliability = &Requirement{
				Condition: expectation.Target.Condition,
				Value:     expectation.Target.Value,
			}
		}
	}

	return spec
}

// ConvertToYAML converts KRM resources to YAML format
func (p *Processor) ConvertToYAML(krm *KRMResourceSet) ([]byte, error) {
	var yamlDocs []string

	// Convert ConfigMap to YAML
	configMapYAML, err := p.marshalToYAML(krm.ConfigMap)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal ConfigMap: %w", err)
	}
	yamlDocs = append(yamlDocs, configMapYAML)

	// Convert CustomResource to YAML
	customResourceYAML, err := p.marshalToYAML(krm.CustomResource)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal custom resource: %w", err)
	}
	yamlDocs = append(yamlDocs, customResourceYAML)

	// Join with document separator (note: space after ---)
	result := strings.Join(yamlDocs, "\n---\n")
	return []byte(result), nil
}

// marshalToYAML marshals a struct to YAML with proper formatting
func (p *Processor) marshalToYAML(v interface{}) (string, error) {
	var buffer strings.Builder
	encoder := yaml.NewEncoder(&buffer)
	encoder.SetIndent(2) // Use 2-space indentation to match golden files

	err := encoder.Encode(v)
	if err != nil {
		return "", err
	}
	encoder.Close()

	return strings.TrimSpace(buffer.String()), nil
}
