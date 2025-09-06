package commands

import (
	"fmt"
	"runtime"

	"github.com/spf13/cobra"
)

var (
	// These will be set by build flags
	Version   = "dev"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

// NewVersionCommand creates the version command
func NewVersionCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Long:  "Print version information for o2imsctl",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("o2imsctl version %s\n", Version)
			fmt.Printf("Git commit: %s\n", GitCommit)
			fmt.Printf("Build date: %s\n", BuildDate)
			fmt.Printf("Go version: %s\n", runtime.Version())
			fmt.Printf("OS/Arch: %s/%s\n", runtime.GOOS, runtime.GOARCH)
		},
	}

	return cmd
}