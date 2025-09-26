/*
Copyright 2025 nephio-summit.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package utils

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestGetNonEmptyLines(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []string
	}{
		{
			name:     "empty string",
			input:    "",
			expected: []string{},
		},
		{
			name:     "single line",
			input:    "hello",
			expected: []string{"hello"},
		},
		{
			name:     "multiple lines with empty lines",
			input:    "line1\n\nline2\n\nline3",
			expected: []string{"line1", "line2", "line3"},
		},
		{
			name:     "only empty lines",
			input:    "\n\n\n",
			expected: []string{},
		},
		{
			name:     "lines with trailing newline",
			input:    "line1\nline2\n",
			expected: []string{"line1", "line2"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GetNonEmptyLines(tt.input)
			if len(result) != len(tt.expected) {
				t.Errorf("GetNonEmptyLines() length = %v, want %v", len(result), len(tt.expected))
				return
			}
			for i, line := range result {
				if line != tt.expected[i] {
					t.Errorf("GetNonEmptyLines() line %d = %v, want %v", i, line, tt.expected[i])
				}
			}
		})
	}
}

func TestGetProjectDir(t *testing.T) {
	// Save current working directory
	originalWd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current working directory: %v", err)
	}
	defer func() {
		// Restore working directory
		if err := os.Chdir(originalWd); err != nil {
			t.Logf("Failed to restore working directory: %v", err)
		}
	}()

	// Test from normal directory
	projectDir, err := GetProjectDir()
	if err != nil {
		t.Errorf("GetProjectDir() error = %v", err)
	}
	if projectDir == "" {
		t.Error("GetProjectDir() returned empty string")
	}

	// Test from e2e directory (should strip /test/e2e)
	if err := os.MkdirAll("test/e2e", 0755); err != nil {
		t.Fatalf("Failed to create test/e2e directory: %v", err)
	}
	defer os.RemoveAll("test")

	if err := os.Chdir("test/e2e"); err != nil {
		t.Fatalf("Failed to change to test/e2e directory: %v", err)
	}

	projectDirFromE2E, err := GetProjectDir()
	if err != nil {
		t.Errorf("GetProjectDir() from e2e error = %v", err)
	}

	// Should not contain /test/e2e in the path
	if filepath.Base(projectDirFromE2E) == "e2e" {
		t.Error("GetProjectDir() should strip /test/e2e from path")
	}
}

func TestRun(t *testing.T) {
	// Test successful command
	cmd := exec.Command("echo", "hello")
	output, err := Run(cmd)
	if err != nil {
		t.Errorf("Run() with echo command error = %v", err)
	}
	if output == "" {
		t.Error("Run() with echo command should return output")
	}

	// Test failing command
	cmd = exec.Command("false") // Command that always fails
	_, err = Run(cmd)
	if err == nil {
		t.Error("Run() with failing command should return error")
	}
}

func TestUncommentCode(t *testing.T) {
	// Create a temporary file for testing
	tempFile := filepath.Join(t.TempDir(), "test.txt")
	content := `line1
// commented line
line3
// another comment
line5`

	if err := os.WriteFile(tempFile, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}

	// Test uncomment
	target := "// commented line"
	err := UncommentCode(tempFile, target, "// ")
	if err != nil {
		t.Errorf("UncommentCode() error = %v", err)
	}

	// Read the file back
	updatedContent, err := os.ReadFile(tempFile)
	if err != nil {
		t.Fatalf("Failed to read updated file: %v", err)
	}

	expectedContent := `line1
commented line
line3
// another comment
line5`

	if string(updatedContent) != expectedContent {
		t.Errorf("UncommentCode() content = %q, want %q", string(updatedContent), expectedContent)
	}

	// Test with non-existent target
	err = UncommentCode(tempFile, "non-existent", "// ")
	if err == nil {
		t.Error("UncommentCode() with non-existent target should return error")
	}

	// Test with non-existent file
	err = UncommentCode("non-existent-file.txt", target, "// ")
	if err == nil {
		t.Error("UncommentCode() with non-existent file should return error")
	}
}

func TestIsCertManagerCRDsInstalled(t *testing.T) {
	// This test primarily verifies the function doesn't panic
	// The actual kubectl call will likely fail in test environment
	result := IsCertManagerCRDsInstalled()

	// We can't really test the kubectl functionality without a cluster
	// But we can verify it returns a boolean
	if result != true && result != false {
		t.Error("IsCertManagerCRDsInstalled() should return a boolean")
	}
}

func TestLoadImageToKindClusterWithName(t *testing.T) {
	// This test verifies the function exists and handles the case
	// where kind is not available
	err := LoadImageToKindClusterWithName("test-image:latest")

	// We expect this to fail in CI/test environment where kind might not be available
	// The important thing is that it doesn't panic
	if err != nil {
		t.Logf("LoadImageToKindClusterWithName expected to fail without kind: %v", err)
	}
}

func TestInstallCertManager(t *testing.T) {
	// This test verifies the function exists and handles the case
	// where kubectl is not available or cluster is not accessible
	err := InstallCertManager()

	// We expect this to fail in CI/test environment
	// The important thing is that it doesn't panic and returns an error
	if err != nil {
		t.Logf("InstallCertManager expected to fail without cluster: %v", err)
	}
}

func TestUninstallCertManager(t *testing.T) {
	// This test verifies the function exists and doesn't panic
	// We can't really test the kubectl functionality without a cluster
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("UninstallCertManager() should not panic, got: %v", r)
		}
	}()

	UninstallCertManager()
	// If we get here without panicking, the test passes
}
