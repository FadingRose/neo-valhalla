package cmd

import (
	"fmt"
	"os"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/spf13/cobra"
)

var (
	storagePath string
	humanFlag   bool
	password    string
)

var rootCmd = &cobra.Command{
	Use:   "auditscope",
	Short: "AuditScope CLI - Audit mind management tool for agents",
	Long: `AuditScope CLI is a command-line tool for managing audit thoughts,
notes, and findings. Designed for AI agents with self-describing JSON output.

Human-only operations (subject new/delete, git lock) require --password flag.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		if err := db.Init(storagePath); err != nil {
			output.PrintError("init", err.Error(), "Check storage path permissions")
			os.Exit(1)
		}
		if err := db.LoadSubjectData(); err != nil && db.GetActiveSubjectID() != "" {
		}
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVar(&storagePath, "storage", "", "Custom storage path (default: ~/.local/share/auditscope)")
	rootCmd.PersistentFlags().BoolVar(&humanFlag, "human", false, "Human-readable output format")
}

func requirePassword(cmd *cobra.Command, args []string) bool {
	passwordFlag := cmd.Flag("password")
	if passwordFlag == nil || passwordFlag.Value.String() == "" {
		output.PrintError(
			"auth",
			"password required for this operation",
			"This is a human-only operation. Use --password <password>",
		)
		return false
	}
	if !db.VerifyPassword(passwordFlag.Value.String()) {
		output.PrintError(
			"auth",
			"invalid password",
			"Contact administrator for the correct password",
		)
		return false
	}
	return true
}

func requireActiveSubject() bool {
	if db.GetActiveSubjectID() == "" {
		output.PrintError(
			"subject_required",
			"no active subject",
			"Use 'auditscope subject new <title>' or 'auditscope subject select <id>'",
		)
		return false
	}
	return true
}
