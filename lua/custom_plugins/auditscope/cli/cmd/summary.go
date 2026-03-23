package cmd

import (
	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/spf13/cobra"
)

var summaryCmd = &cobra.Command{
	Use:   "summary",
	Short: "Manage executive summary",
	Long:  `Manage the executive summary for the active subject.`,
}

var summaryShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show the executive summary",
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		summary := db.GetSummary()
		subject := db.GetActiveSubject()

		output.PrintSuccess(
			"summary_show",
			"Executive summary",
			map[string]any{
				"subject_id": subject.ID,
				"title":      subject.Title,
				"summary":    summary,
			},
		)
	},
}

var summarySetCmd = &cobra.Command{
	Use:   "set <text>",
	Short: "Set the executive summary",
	Args:  cobra.MinimumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		summary := args[0]
		if len(args) > 1 {
			for _, arg := range args[1:] {
				summary += " " + arg
			}
		}

		if err := db.SetSummary(summary); err != nil {
			output.PrintError("summary_set", err.Error(), "Check subject is active")
			return
		}

		output.PrintSuccess(
			"summary_set",
			"Summary updated",
			map[string]any{
				"summary": summary,
			},
		)
	},
}

var summaryClearCmd = &cobra.Command{
	Use:   "clear",
	Short: "Clear the executive summary",
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		if err := db.SetSummary(""); err != nil {
			output.PrintError("summary_clear", err.Error(), "Check subject is active")
			return
		}

		output.PrintSuccess(
			"summary_clear",
			"Summary cleared",
			map[string]any{},
		)
	},
}

func init() {
	summaryCmd.AddCommand(summaryShowCmd, summarySetCmd, summaryClearCmd)
	rootCmd.AddCommand(summaryCmd)
}
