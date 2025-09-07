package main

import (
	"fmt"
	"io"
	"os"
)

// For standalone execution (useful for testing and CLI usage)
func main() {
	// If running as standalone CLI tool, process stdin/stdout
	if len(os.Args) > 1 && os.Args[1] == "--standalone" {
		runStandalone()
		return
	}

	// For kpt function mode
	runKptFunction()
}

func runStandalone() {
	processor := NewProcessor()

	// Read JSON from stdin
	inputData, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}

	// Process expectation
	outputYAML, err := processor.ProcessExpectation(inputData)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error processing expectation: %v\n", err)
		os.Exit(1)
	}

	// Write YAML to stdout
	fmt.Print(string(outputYAML))
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func runKptFunction() {
	// TODO: Implement kpt function mode using kyaml framework
	// This is a simplified version for now
	fmt.Fprintf(os.Stderr, "kpt function mode not yet implemented, use --standalone\n")
	os.Exit(1)
}
