package cmd

import (
	"fmt"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/kobayakawayuu/auditscope/internal/report"
	"github.com/spf13/cobra"
)

var reportOutput string

var reportCmd = &cobra.Command{
	Use:   "report",
	Short: "Generate audit report",
	Long:  `Generate a Markdown audit report for the active subject.`,
}

var reportGenerateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate report",
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		subject := db.GetActiveSubject()
		data := db.GetCurrentData()

		gen := report.NewGenerator(
			data.Subject,
			data.Nodes,
			data.Edges,
			db.GetStoragePaths()["reports_dir"],
		)

		reportPath, err := gen.Generate()
		if err != nil {
			output.PrintError("report_generate", err.Error(), "Check storage permissions")
			return
		}

		output.PrintSuccess(
			"report_generate",
			fmt.Sprintf("Report generated: %s", reportPath),
			map[string]any{
				"report_path": reportPath,
				"subject_id":  subject.ID,
				"title":       subject.Title,
				"nodes_count": len(data.Nodes),
				"edges_count": len(data.Edges),
			},
		)
	},
}

func init() {
	reportCmd.AddCommand(reportGenerateCmd)
	reportGenerateCmd.Flags().StringVarP(&reportOutput, "output", "o", "", "Output file path")
	rootCmd.AddCommand(reportCmd)
}
