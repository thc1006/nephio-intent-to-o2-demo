package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestProcessor_ProcessExpectation(t *testing.T) {
	tests := []struct {
		name        string
		inputFile   string
		goldenFile  string
		expectError bool
	}{
		{
			name:        "RAN Performance Expectation",
			inputFile:   "testdata/input/ran_performance.json",
			goldenFile:  "testdata/golden/ran_performance.yaml",
			expectError: false,
		},
		{
			name:        "Core Network Capacity Expectation",
			inputFile:   "testdata/input/cn_capacity.json",
			goldenFile:  "testdata/golden/cn_capacity.yaml",
			expectError: false,
		},
		{
			name:        "Transport Network Coverage Expectation",
			inputFile:   "testdata/input/tn_coverage.json",
			goldenFile:  "testdata/golden/tn_coverage.yaml",
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Read input JSON
			inputData, err := os.ReadFile(tt.inputFile)
			require.NoError(t, err, "Failed to read input file")

			// Read expected golden YAML
			expectedYAML, err := os.ReadFile(tt.goldenFile)
			require.NoError(t, err, "Failed to read golden file")

			// Create processor
			processor := NewProcessor()

			// Process the expectation
			actualYAML, err := processor.ProcessExpectation(inputData)

			if tt.expectError {
				assert.Error(t, err)
				return
			}

			require.NoError(t, err, "ProcessExpectation should not return error")

			// Normalize whitespace for comparison
			expectedNormalized := strings.TrimSpace(string(expectedYAML))
			actualNormalized := strings.TrimSpace(string(actualYAML))

			assert.Equal(t, expectedNormalized, actualNormalized,
				"Generated YAML does not match golden file")
		})
	}
}

func TestProcessor_ParseExpectation(t *testing.T) {
	tests := []struct {
		name        string
		jsonData    string
		expectError bool
	}{
		{
			name: "Valid RAN Expectation",
			jsonData: `{
				"intentExpectationId": "test-001",
				"intentExpectationType": "ServicePerformance",
				"intentExpectationContext": {
					"contextAttribute": "networkFunction",
					"contextCondition": "EQUAL",
					"contextValueRange": ["gNB"]
				},
				"intentExpectationTarget": {
					"targetAttribute": "throughput",
					"targetCondition": "GREATER_THAN", 
					"targetValue": "100Mbps"
				},
				"intentExpectationObject": {
					"objectType": "RANFunction",
					"objectInstance": "test-ran"
				}
			}`,
			expectError: false,
		},
		{
			name: "Invalid JSON",
			jsonData: `{
				"intentExpectationId": "test-001"
				"invalid": json
			}`,
			expectError: true,
		},
		{
			name: "Missing Required Fields",
			jsonData: `{
				"intentExpectationId": "test-001"
			}`,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			processor := NewProcessor()

			expectation, err := processor.ParseExpectation([]byte(tt.jsonData))

			if tt.expectError {
				assert.Error(t, err)
				assert.Nil(t, expectation)
				return
			}

			require.NoError(t, err)
			require.NotNil(t, expectation)
			assert.Equal(t, "test-001", expectation.ID)
		})
	}
}

func TestProcessor_GenerateKRM(t *testing.T) {
	processor := NewProcessor()

	// Create a sample expectation
	expectation := &Expectation{
		ID:   "test-gen-001",
		Type: "ServicePerformance",
		Context: ExpectationContext{
			Attribute:  "networkFunction",
			Condition:  "EQUAL",
			ValueRange: []string{"gNB"},
		},
		Target: ExpectationTarget{
			Attribute: "throughput",
			Condition: "GREATER_THAN",
			Value:     "500Mbps",
		},
		Object: ExpectationObject{
			Type:     "RANFunction",
			Instance: "test-instance",
		},
	}

	krm, err := processor.GenerateKRM(expectation)
	require.NoError(t, err)
	require.NotNil(t, krm)

	// Verify KRM contains expected resources
	assert.Contains(t, krm.ConfigMap.Metadata.Name, "expectation-test-gen-001")
	assert.Contains(t, krm.CustomResource.Metadata.Name, "ran-bundle-test-gen-001")
	assert.Equal(t, "intent-to-krm", krm.ConfigMap.Metadata.Namespace)
}

// updateGoldenFiles is a helper function for updating golden test files during development
func updateGoldenFiles(t *testing.T) {
	if !*updateGoldens {
		t.Skip("Golden file updates disabled. Run with -update-goldens to enable.")
	}

	inputDir := "testdata/input"
	goldenDir := "testdata/golden"

	entries, err := os.ReadDir(inputDir)
	require.NoError(t, err)

	processor := NewProcessor()

	for _, entry := range entries {
		if !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		inputPath := filepath.Join(inputDir, entry.Name())
		goldenPath := filepath.Join(goldenDir, strings.TrimSuffix(entry.Name(), ".json")+".yaml")

		inputData, err := os.ReadFile(inputPath)
		require.NoError(t, err)

		outputYAML, err := processor.ProcessExpectation(inputData)
		require.NoError(t, err)

		err = os.WriteFile(goldenPath, outputYAML, 0644)
		require.NoError(t, err)

		t.Logf("Updated golden file: %s", goldenPath)
	}
}

// Test flag for updating golden files during development
var updateGoldens = func() *bool {
	b := false
	return &b
}()
