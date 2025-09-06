package main

import (
	"fmt"
	"os"

	"github.com/nephio-intent-to-o2-demo/o2ims-sdk/cmd/o2imsctl/commands"
)

func main() {
	rootCmd := commands.NewRootCommand()
	
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}