package cmd

import (
	"fmt"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/git"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/spf13/cobra"
)

var gitCmd = &cobra.Command{
	Use:   "git",
	Short: "Git context and commit locking",
	Long:  `Manage git context and commit locking for audit sessions.`,
}

var gitContextCmd = &cobra.Command{
	Use:   "context",
	Short: "Show git context",
	Run: func(cmd *cobra.Command, args []string) {
		ctx := git.GetRepoContext()

		lockedCommit := ""
		if ctx.Root != "" {
			lockedCommit = db.GetLockedCommit(ctx.Root)
		}

		output.PrintSuccess(
			"git_context",
			"Git context",
			map[string]any{
				"root":           ctx.Root,
				"name":           ctx.Name,
				"current_commit": ctx.Commit,
				"locked_commit":  lockedCommit,
			},
		)
	},
}

var gitLockCmd = &cobra.Command{
	Use:   "lock [commit-hash]",
	Short: "Lock to a specific commit (Human-only)",
	Long: `Lock the audit session to a specific commit.
If no commit hash is provided, locks to the current HEAD.
This is a human-only operation requiring password.`,
	Run: func(cmd *cobra.Command, args []string) {
		if !requirePassword(cmd, args) {
			return
		}

		ctx := git.GetRepoContext()
		if ctx.Root == "" {
			output.PrintError("git_lock", "not in a git repository", "Run this command inside a git repository")
			return
		}

		commit := ""
		if len(args) > 0 {
			commit = args[0]
		} else {
			commit = ctx.Commit
		}

		if commit == "" {
			output.PrintError("git_lock", "no commit available to lock", "Provide a commit hash or ensure you're in a git repo")
			return
		}

		db.LockCommit(ctx.Root, commit)

		output.PrintSuccess(
			"git_lock",
			fmt.Sprintf("Locked to commit: %s", commit),
			map[string]any{
				"repo_root": ctx.Root,
				"commit":    commit,
			},
		)
	},
}

var gitUnlockCmd = &cobra.Command{
	Use:   "unlock",
	Short: "Unlock commit",
	Run: func(cmd *cobra.Command, args []string) {
		ctx := git.GetRepoContext()
		if ctx.Root == "" {
			output.PrintError("git_unlock", "not in a git repository", "Run this command inside a git repository")
			return
		}

		db.UnlockCommit(ctx.Root)

		output.PrintSuccess(
			"git_unlock",
			"Commit lock released",
			map[string]any{
				"repo_root": ctx.Root,
			},
		)
	},
}

func init() {
	gitCmd.AddCommand(gitContextCmd, gitLockCmd, gitUnlockCmd)

	gitLockCmd.Flags().String("password", "", "Password for human-only operations")

	rootCmd.AddCommand(gitCmd)
}
