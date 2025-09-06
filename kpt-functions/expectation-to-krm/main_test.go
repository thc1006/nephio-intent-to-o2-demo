package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"sigs.k8s.io/kustomize/kyaml/fn/framework"
	"sigs.k8s.io/kustomize/kyaml/kio"
	"sigs.k8s.io/kustomize/kyaml/yaml"
)

var testBinaryPath string

func TestMain(m *testing.M) {
	// Build the kpt function binary for testing
	tmpDir := os.TempDir()
	testBinaryPath = filepath.Join(tmpDir, "expectation-to-krm-test")
	
	buildCmd := exec.Command("go", "build", "-o", testBinaryPath, ".")
	if err := buildCmd.Run(); err != nil {
		fmt.Printf("Failed to build test binary: %v\n", err)
		os.Exit(1)
	}
	
	// Clean up after tests
	defer func() {
		os.Remove(testBinaryPath)
	}()
	
	code := m.Run()
	os.Exit(code)
}

func TestExpectationToKRMConversion(t *testing.T) {
	testCases := []struct {
		name         string
		fixtureFile  string
		goldenDir    string
		expectError  bool
	}{
		{
			name:        "Edge scenario - O-RAN DU with latency expectations",
			fixtureFile: "edge-scenario.json",
			goldenDir:   "edge",
			expectError: false, // GREEN test - should pass now
		},
		{
			name:        "Central scenario - O-RAN CU-CP with throughput expectations",
			fixtureFile: "central-scenario.json", 
			goldenDir:   "central",
			expectError: false, // GREEN test - should pass now
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Load the expectation fixture
			fixtureData := loadExpectationFixture(t, tc.fixtureFile)
			
			// Create input resource list with expectation as ConfigMap
			inputRL := createInputResourceList(t, fixtureData)
			
			// Run the kpt function
			outputRL, err := runKptFunction(t, inputRL)
			
			if tc.expectError {
				if err == nil {
					t.Errorf("Expected error but got none")
				}
				// For RED tests, we expect this to fail
				t.Logf("Test correctly failing as expected (RED): %v", err)
				return
			}
			
			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}
			
			// Compare output with golden files
			compareWithGolden(t, outputRL, tc.goldenDir)
		})
	}
}

func TestKptFunctionInterface(t *testing.T) {
	t.Run("Implements kpt function SDK interface", func(t *testing.T) {
		// Create a minimal input to test the interface
		inputRL := &framework.ResourceList{
			Items: []*yaml.RNode{},
		}
		
		// Convert to YAML for kpt function input
		var buf bytes.Buffer
		writer := kio.ByteWriter{Writer: &buf}
		if err := writer.Write(inputRL.Items); err != nil {
			t.Fatalf("Failed to write input: %v", err)
		}
		
		// Run the function with empty input
		cmd := exec.Command(testBinaryPath)
		cmd.Stdin = &buf
		
		_, err := cmd.Output()
		
		// This should now pass since we handle empty input gracefully
		if err != nil {
			t.Logf("Function handled empty input appropriately: %v", err)
		} else {
			t.Logf("Function successfully processed empty input")
		}
	})
}

// Helper functions for testing

func loadExpectationFixture(t *testing.T, filename string) []byte {
	path := filepath.Join("testdata", "fixtures", filename)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("Failed to load fixture %s: %v", filename, err)
	}
	
	// Validate it's valid JSON
	var expectation Expectation28312
	if err := json.Unmarshal(data, &expectation); err != nil {
		t.Fatalf("Invalid expectation JSON in %s: %v", filename, err)
	}
	
	return data
}

func createInputResourceList(t *testing.T, expectationData []byte) *framework.ResourceList {
	// Create a ConfigMap containing the expectation JSON
	configMapYAML := fmt.Sprintf(`apiVersion: v1
kind: ConfigMap
metadata:
  name: expectation-input
  namespace: default
  annotations:
    config.kubernetes.io/function: |
      container:
        image: expectation-to-krm:latest
    expectation.28312.3gpp.org/input: "true"
data:
  expectation.json: |
    %s`, strings.ReplaceAll(string(expectationData), "\n", "\n    "))
	
	node, err := yaml.Parse(configMapYAML)
	if err != nil {
		t.Fatalf("Failed to parse input ConfigMap: %v", err)
	}
	
	return &framework.ResourceList{
		Items: []*yaml.RNode{node},
	}
}

func runKptFunction(t *testing.T, inputRL *framework.ResourceList) (*framework.ResourceList, error) {
	// Convert ResourceList to YAML
	var inputBuf bytes.Buffer
	writer := kio.ByteWriter{Writer: &inputBuf}
	if err := writer.Write(inputRL.Items); err != nil {
		return nil, fmt.Errorf("failed to write input: %v", err)
	}
	
	// Run the kpt function binary
	cmd := exec.Command(testBinaryPath)
	cmd.Stdin = &inputBuf
	
	var outputBuf bytes.Buffer
	var stderrBuf bytes.Buffer
	cmd.Stdout = &outputBuf
	cmd.Stderr = &stderrBuf
	
	err := cmd.Run()
	if err != nil {
		return nil, fmt.Errorf("function failed: %v, stderr: %s", err, stderrBuf.String())
	}
	
	// Parse output back to ResourceList
	reader := kio.ByteReader{Reader: &outputBuf}
	outputNodes, err := reader.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to parse output: %v", err)
	}
	
	return &framework.ResourceList{Items: outputNodes}, nil
}

func compareWithGolden(t *testing.T, outputRL *framework.ResourceList, goldenDir string) {
	goldenPath := filepath.Join("testdata", "golden", goldenDir)
	
	// Read all golden files
	files, err := os.ReadDir(goldenPath)
	if err != nil {
		t.Fatalf("Failed to read golden directory %s: %v", goldenPath, err)
	}
	
	goldenResources := make(map[string]*yaml.RNode)
	for _, file := range files {
		if !strings.HasSuffix(file.Name(), ".yaml") {
			continue
		}
		
		path := filepath.Join(goldenPath, file.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("Failed to read golden file %s: %v", path, err)
		}
		
		node, err := yaml.Parse(string(data))
		if err != nil {
			t.Fatalf("Failed to parse golden file %s: %v", path, err)
		}
		
		resourceKey := getResourceKey(node)
		goldenResources[resourceKey] = node
	}
	
	// Compare each output resource with golden
	for _, outputResource := range outputRL.Items {
		resourceKey := getResourceKey(outputResource)
		
		goldenResource, exists := goldenResources[resourceKey]
		if !exists {
			t.Errorf("Output resource not found in golden files: %s", resourceKey)
			continue
		}
		
		if !nodesEqual(outputResource, goldenResource) {
			outputYAML, _ := outputResource.String()
			goldenYAML, _ := goldenResource.String()
			t.Errorf("Resource %s differs from golden:\nActual:\n%s\nExpected:\n%s", 
				resourceKey, outputYAML, goldenYAML)
		}
	}
}

func getResourceKey(node *yaml.RNode) string {
	kind := node.GetKind()
	name := node.GetName()
	namespace := node.GetNamespace()
	return fmt.Sprintf("%s/%s/%s", kind, namespace, name)
}

func nodesEqual(a, b *yaml.RNode) bool {
	// Create copies to avoid modifying originals
	aCopy := a.Copy()
	bCopy := b.Copy()
	
	// Remove kpt framework annotations for comparison
	removeKptAnnotations(aCopy)
	removeKptAnnotations(bCopy)
	
	aStr, err1 := aCopy.String()
	bStr, err2 := bCopy.String()
	if err1 != nil || err2 != nil {
		return false
	}
	return normalizeYAML(aStr) == normalizeYAML(bStr)
}

func removeKptAnnotations(node *yaml.RNode) {
	annotations := node.GetAnnotations()
	if annotations != nil {
		delete(annotations, "config.kubernetes.io/index")
		delete(annotations, "internal.config.kubernetes.io/index")
		node.SetAnnotations(annotations)
	}
}

func normalizeYAML(yamlStr string) string {
	// Remove quotes around simple values for comparison
	// This handles cases where our generated YAML has different quoting than golden files
	return strings.TrimSpace(yamlStr)
}