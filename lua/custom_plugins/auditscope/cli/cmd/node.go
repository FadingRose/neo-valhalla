package cmd

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/git"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/kobayakawayuu/auditscope/pkg/models"
	"github.com/spf13/cobra"
)

var (
	nodeTitle       string
	nodeDescription string
	nodeFile        string
	nodeLine        string
	nodeStartLine   int
	nodeEndLine     int
)

var nodeCmd = &cobra.Command{
	Use:   "node",
	Short: "Manage audit nodes",
	Long:  `Manage audit nodes (notes, findings, questions, etc.)`,
}

var nodeNewCmd = &cobra.Command{
	Use:   "new <type> --title <title>",
	Short: "Create a new node",
	Long: fmt.Sprintf(`Create a new audit node.

Valid node types: %v

Example:
  auditscope node new question --title "Is this function safe?" --description "Need to verify access control"
  auditscope node new finding --title "Reentrancy vulnerability" --file src/contract.sol --line 100-150`, models.ValidNodeTypes),
	Args: cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		nodeType := args[0]
		if !models.IsValidNodeType(nodeType) {
			output.PrintError(
				"node_new",
				fmt.Sprintf("invalid node type: %s", nodeType),
				fmt.Sprintf("Valid types: %v", models.ValidNodeTypes),
			)
			return
		}

		if nodeTitle == "" {
			output.PrintError("node_new", "title is required", "Use --title <title>")
			return
		}

		file := nodeFile
		startLine := nodeStartLine
		endLine := nodeEndLine

		if nodeLine != "" {
			parts := strings.Split(nodeLine, "-")
			if len(parts) == 1 {
				val, err := strconv.Atoi(strings.TrimSpace(parts[0]))
				if err == nil {
					startLine = val
					endLine = val
				}
			} else if len(parts) == 2 {
				start, err1 := strconv.Atoi(strings.TrimSpace(parts[0]))
				end, err2 := strconv.Atoi(strings.TrimSpace(parts[1]))
				if err1 == nil && err2 == nil {
					startLine = start
					endLine = end
				}
			}
		}

		if endLine == 0 {
			endLine = startLine
		}

		repoCtx := git.GetRepoContext()

		id := db.GenerateID()
		node := models.Node{
			ID:          id,
			Type:        nodeType,
			Title:       nodeTitle,
			Description: nodeDescription,
			File:        file,
			StartLine:   startLine,
			EndLine:     endLine,
			Timestamp:   time.Now().Unix(),
			RepoRoot:    repoCtx.Root,
			RepoName:    repoCtx.Name,
			Commit:      repoCtx.Commit,
		}

		if err := db.AddNode(node); err != nil {
			output.PrintError("node_new", err.Error(), "Check subject is active")
			return
		}

		output.PrintSuccess(
			"node_new",
			fmt.Sprintf("Created node: %s", nodeTitle),
			map[string]any{
				"node_id":     id,
				"type":        nodeType,
				"title":       nodeTitle,
				"description": nodeDescription,
				"file":        file,
				"start_line":  startLine,
				"end_line":    endLine,
			},
		)
	},
}

var nodeListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all nodes",
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		nodes := db.GetNodes()

		filterType, _ := cmd.Flags().GetString("type")
		filterFile, _ := cmd.Flags().GetString("file")

		var filtered []models.Node
		for _, n := range nodes {
			if filterType != "" && n.Type != filterType {
				continue
			}
			if filterFile != "" && n.File != filterFile {
				continue
			}
			filtered = append(filtered, n)
		}

		var data []map[string]any
		for _, n := range filtered {
			data = append(data, map[string]any{
				"id":          n.ID,
				"type":        n.Type,
				"title":       n.GetTitle(),
				"description": n.Description,
				"file":        n.File,
				"start_line":  n.StartLine,
				"end_line":    n.EndLine,
				"timestamp":   n.Timestamp,
				"commit":      n.Commit,
			})
		}

		output.PrintSuccess(
			"node_list",
			fmt.Sprintf("Found %d nodes", len(data)),
			map[string]any{
				"nodes": data,
				"count": len(data),
			},
		)
	},
}

var nodeShowCmd = &cobra.Command{
	Use:   "show <id>",
	Short: "Show node details",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		id := args[0]
		node := db.GetNodeByID(id)
		if node == nil {
			output.PrintError("node_show", fmt.Sprintf("node not found: %s", id), "Use 'auditscope node list' to see available nodes")
			return
		}

		edges := db.GetEdges()
		var incoming, outgoing []map[string]any
		for _, e := range edges {
			if e.To == id {
				incoming = append(incoming, map[string]any{
					"from_id":  e.From,
					"relation": e.Relation,
				})
			}
			if e.From == id {
				outgoing = append(outgoing, map[string]any{
					"to_id":    e.To,
					"relation": e.Relation,
				})
			}
		}

		output.PrintSuccess(
			"node_show",
			"Node details",
			map[string]any{
				"node": map[string]any{
					"id":          node.ID,
					"type":        node.Type,
					"title":       node.GetTitle(),
					"description": node.Description,
					"file":        node.File,
					"start_line":  node.StartLine,
					"end_line":    node.EndLine,
					"timestamp":   node.Timestamp,
					"commit":      node.Commit,
					"repo_name":   node.RepoName,
					"repo_root":   node.RepoRoot,
					"snippets":    node.CodeSnippets,
				},
				"incoming_links": incoming,
				"outgoing_links": outgoing,
			},
		)
	},
}

var nodeUpdateCmd = &cobra.Command{
	Use:   "update <id>",
	Short: "Update a node",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		id := args[0]
		node := db.GetNodeByID(id)
		if node == nil {
			output.PrintError("node_update", fmt.Sprintf("node not found: %s", id), "Use 'auditscope node list' to see available nodes")
			return
		}

		if nodeTitle != "" {
			node.Title = nodeTitle
		}
		if nodeDescription != "" {
			node.Description = nodeDescription
		}
		if nodeFile != "" {
			node.File = nodeFile
		}
		if nodeStartLine > 0 {
			node.StartLine = nodeStartLine
		}
		if nodeEndLine > 0 {
			node.EndLine = nodeEndLine
		}

		if err := db.UpdateNode(*node); err != nil {
			output.PrintError("node_update", err.Error(), "Check node ID")
			return
		}

		output.PrintSuccess(
			"node_update",
			fmt.Sprintf("Updated node: %s", id),
			map[string]any{
				"node_id":     id,
				"title":       node.GetTitle(),
				"description": node.Description,
			},
		)
	},
}

var nodeDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete a node",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		id := args[0]
		if err := db.DeleteNode(id); err != nil {
			output.PrintError("node_delete", err.Error(), "Use 'auditscope node list' to see available nodes")
			return
		}

		output.PrintSuccess(
			"node_delete",
			fmt.Sprintf("Deleted node: %s", id),
			map[string]any{
				"node_id": id,
			},
		)
	},
}

var nodeSnippetCmd = &cobra.Command{
	Use:   "snippet",
	Short: "Manage code snippets on nodes",
}

var nodeSnippetAddCmd = &cobra.Command{
	Use:   "add <node-id> --text <snippet>",
	Short: "Add a code snippet to a node",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		nodeID := args[0]
		node := db.GetNodeByID(nodeID)
		if node == nil {
			output.PrintError("node_snippet_add", fmt.Sprintf("node not found: %s", nodeID), "Use 'auditscope node list' to see available nodes")
			return
		}

		snippetText, _ := cmd.Flags().GetString("text")
		snippetFile, _ := cmd.Flags().GetString("file")
		snippetStartLine, _ := cmd.Flags().GetInt("start-line")
		snippetEndLine, _ := cmd.Flags().GetInt("end-line")

		if snippetText == "" {
			output.PrintError("node_snippet_add", "snippet text is required", "Use --text <snippet>")
			return
		}

		repoCtx := git.GetRepoContext()
		snippet := models.CodeSnippet{
			Text:      snippetText,
			File:      snippetFile,
			StartLine: snippetStartLine,
			EndLine:   snippetEndLine,
			Timestamp: time.Now().Unix(),
			Commit:    repoCtx.Commit,
			RepoRoot:  repoCtx.Root,
			RepoName:  repoCtx.Name,
		}

		node.CodeSnippets = append(node.CodeSnippets, snippet)
		if err := db.UpdateNode(*node); err != nil {
			output.PrintError("node_snippet_add", err.Error(), "Check node ID")
			return
		}

		output.PrintSuccess(
			"node_snippet_add",
			fmt.Sprintf("Added snippet to node: %s", nodeID),
			map[string]any{
				"node_id":    nodeID,
				"snippet_id": len(node.CodeSnippets),
			},
		)
	},
}

var nodeSnippetDeleteCmd = &cobra.Command{
	Use:   "delete <node-id> <index>",
	Short: "Delete a code snippet from a node",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		nodeID := args[0]
		indexStr := args[1]

		node := db.GetNodeByID(nodeID)
		if node == nil {
			output.PrintError("node_snippet_delete", fmt.Sprintf("node not found: %s", nodeID), "Use 'auditscope node list' to see available nodes")
			return
		}

		index := 0
		fmt.Sscanf(indexStr, "%d", &index)

		if index < 1 || index > len(node.CodeSnippets) {
			output.PrintError("node_snippet_delete", fmt.Sprintf("invalid snippet index: %d", index), fmt.Sprintf("Valid range: 1-%d", len(node.CodeSnippets)))
			return
		}

		node.CodeSnippets = append(node.CodeSnippets[:index-1], node.CodeSnippets[index:]...)
		if err := db.UpdateNode(*node); err != nil {
			output.PrintError("node_snippet_delete", err.Error(), "Check node ID")
			return
		}

		output.PrintSuccess(
			"node_snippet_delete",
			fmt.Sprintf("Deleted snippet %d from node: %s", index, nodeID),
			map[string]any{
				"node_id":       nodeID,
				"deleted_index": index,
			},
		)
	},
}

func init() {
	nodeCmd.AddCommand(nodeNewCmd, nodeListCmd, nodeShowCmd, nodeUpdateCmd, nodeDeleteCmd, nodeSnippetCmd)
	nodeSnippetCmd.AddCommand(nodeSnippetAddCmd, nodeSnippetDeleteCmd)

	nodeNewCmd.Flags().StringVar(&nodeTitle, "title", "", "Node title")
	nodeNewCmd.Flags().StringVar(&nodeDescription, "description", "", "Node description")
	nodeNewCmd.Flags().StringVar(&nodeFile, "file", "", "Source file path")
	nodeNewCmd.Flags().IntVar(&nodeStartLine, "start-line", 0, "Start line number")
	nodeNewCmd.Flags().IntVar(&nodeEndLine, "end-line", 0, "End line number")
	nodeNewCmd.Flags().StringVarP(&nodeLine, "line", "l", "", "Line range (e.g., '10' or '10-20')")

	nodeListCmd.Flags().String("type", "", "Filter by node type")
	nodeListCmd.Flags().String("file", "", "Filter by file path")

	nodeUpdateCmd.Flags().StringVar(&nodeTitle, "title", "", "New title")
	nodeUpdateCmd.Flags().StringVar(&nodeDescription, "description", "", "New description")
	nodeUpdateCmd.Flags().StringVar(&nodeFile, "file", "", "New file path")
	nodeUpdateCmd.Flags().IntVar(&nodeStartLine, "start-line", 0, "New start line")
	nodeUpdateCmd.Flags().IntVar(&nodeEndLine, "end-line", 0, "New end line")

	nodeSnippetAddCmd.Flags().String("text", "", "Snippet text content")
	nodeSnippetAddCmd.Flags().String("file", "", "Snippet file path")
	nodeSnippetAddCmd.Flags().Int("start-line", 0, "Snippet start line")
	nodeSnippetAddCmd.Flags().Int("end-line", 0, "Snippet end line")

	rootCmd.AddCommand(nodeCmd)
}
