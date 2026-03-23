package cmd

import (
	"fmt"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/git"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/spf13/cobra"
)

var subjectScope string

var subjectCmd = &cobra.Command{
	Use:   "subject",
	Short: "Manage audit subjects",
	Long:  `Manage audit subjects (projects/audit sessions).`,
}

var subjectNewCmd = &cobra.Command{
	Use:   "new <title>",
	Short: "Create a new audit subject (Human-only)",
	Long:  `Create a new audit subject. This is a human-only operation requiring password.`,
	Args:  cobra.MinimumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requirePassword(cmd, args) {
			return
		}

		title := args[0]
		repoCtx := git.GetRepoContext()
		repoRoot := ""
		if repoCtx != nil {
			repoRoot = repoCtx.Root
		}

		meta, err := db.CreateSubject(title, "", repoRoot)
		if err != nil {
			output.PrintError("subject_new", err.Error(), "Check storage permissions")
			return
		}

		output.PrintSuccess(
			"subject_new",
			fmt.Sprintf("Created subject: %s", title),
			map[string]any{
				"subject_id": meta.ID,
				"title":      meta.Title,
				"status":     meta.Status,
				"repo_root":  meta.RepoRoot,
			},
		)
	},
}

var subjectListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all subjects",
	Run: func(cmd *cobra.Command, args []string) {
		subjects := db.GetSubjects()

		var data []map[string]any
		for _, s := range subjects {
			data = append(data, map[string]any{
				"id":         s.ID,
				"title":      s.Title,
				"status":     s.Status,
				"scope":      s.Scope,
				"created_at": s.CreatedAt,
				"updated_at": s.UpdatedAt,
			})
		}

		output.PrintSuccess(
			"subject_list",
			fmt.Sprintf("Found %d subjects", len(data)),
			map[string]any{
				"subjects": data,
				"count":    len(data),
			},
		)
	},
}

var subjectSelectCmd = &cobra.Command{
	Use:   "select <id>",
	Short: "Select an active subject (Human-only)",
	Long:  `Select an active subject. This is a human-only operation requiring password.`,
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requirePassword(cmd, args) {
			return
		}

		id := args[0]
		if err := db.SetActiveSubject(id); err != nil {
			output.PrintError("subject_select", err.Error(), "Use 'auditscope subject list' to see available subjects")
			return
		}

		subject := db.GetActiveSubject()
		output.PrintSuccess(
			"subject_select",
			fmt.Sprintf("Selected subject: %s", id),
			map[string]any{
				"subject_id": id,
				"title":      subject.Title,
				"status":     subject.Status,
			},
		)
	},
}

var subjectShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show active subject details",
	Run: func(cmd *cobra.Command, args []string) {
		subject := db.GetActiveSubject()
		if subject == nil {
			output.PrintError("subject_show", "no active subject", "Use 'auditscope subject select <id>'")
			return
		}

		data := db.GetCurrentData()
		output.PrintSuccess(
			"subject_show",
			"Active subject details",
			map[string]any{
				"subject": map[string]any{
					"id":         subject.ID,
					"title":      subject.Title,
					"status":     subject.Status,
					"scope":      subject.Scope,
					"summary":    data.Subject.Summary,
					"created_at": subject.CreatedAt,
					"updated_at": subject.UpdatedAt,
				},
				"nodes_count": len(data.Nodes),
				"edges_count": len(data.Edges),
			},
		)
	},
}

var subjectDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete a subject (Human-only)",
	Long:  `Delete a subject and all its data. This is a human-only operation requiring password.`,
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requirePassword(cmd, args) {
			return
		}

		id := args[0]
		if err := db.DeleteSubject(id); err != nil {
			output.PrintError("subject_delete", err.Error(), "Use 'auditscope subject list' to see available subjects")
			return
		}

		output.PrintSuccess(
			"subject_delete",
			fmt.Sprintf("Deleted subject: %s", id),
			map[string]any{
				"subject_id": id,
			},
		)
	},
}

func init() {
	subjectCmd.AddCommand(subjectNewCmd, subjectListCmd, subjectSelectCmd, subjectShowCmd, subjectDeleteCmd)

	subjectNewCmd.Flags().StringVarP(&subjectScope, "scope", "s", "", "Scope of the subject")
	subjectNewCmd.Flags().String("password", "", "Password for human-only operations")

	subjectSelectCmd.Flags().String("password", "", "Password for human-only operations")

	subjectDeleteCmd.Flags().String("password", "", "Password for human-only operations")

	rootCmd.AddCommand(subjectCmd)
}
