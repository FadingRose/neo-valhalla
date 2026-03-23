package cmd

import (
	"fmt"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/ontology"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/kobayakawayuu/auditscope/pkg/models"
	"github.com/spf13/cobra"
)

var edgeRelation string

var edgeCmd = &cobra.Command{
	Use:   "edge",
	Short: "Manage edges (links between nodes)",
	Long:  `Manage edges that connect nodes with relationships like supports, refutes, relates.`,
}

var edgeLinkCmd = &cobra.Command{
	Use:   "link <from-id> <to-id>",
	Short: "Create a link between two nodes",
	Long: fmt.Sprintf(`Create a link between two nodes with a specified relation.

Valid relations: %v

Ontology rules:
- Level 0: note, evidence, insight, question, hypothesis, fact, assumption, invariant
- Level 1: finding
- Level 2: decision, risk
- Links must be same-level or upward only

Example:
  auditscope edge link node1 node2 --relation supports`, models.ValidRelations),
	Args: cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		fromID := args[0]
		toID := args[1]

		fromNode := db.GetNodeByID(fromID)
		if fromNode == nil {
			output.PrintError("edge_link", fmt.Sprintf("source node not found: %s", fromID), "Use 'auditscope node list' to see available nodes")
			return
		}

		toNode := db.GetNodeByID(toID)
		if toNode == nil {
			output.PrintError("edge_link", fmt.Sprintf("target node not found: %s", toID), "Use 'auditscope node list' to see available nodes")
			return
		}

		if edgeRelation == "" {
			edgeRelation = models.RelationRelates
		}

		if !models.IsValidRelation(edgeRelation) {
			output.PrintError(
				"edge_link",
				fmt.Sprintf("invalid relation: %s", edgeRelation),
				fmt.Sprintf("Valid relations: %v", models.ValidRelations),
			)
			return
		}

		if !ontology.IsLinkAllowed(fromNode.Type, toNode.Type) {
			output.PrintError(
				"edge_link",
				fmt.Sprintf("link violates ontology rule: %s(L%d) -> %s(L%d)",
					fromNode.Type, ontology.GetLevel(fromNode.Type),
					toNode.Type, ontology.GetLevel(toNode.Type)),
				"Links must be same-level or upward only",
			)
			return
		}

		if err := db.AddEdge(fromID, toID, edgeRelation); err != nil {
			output.PrintError("edge_link", err.Error(), "Check subject is active")
			return
		}

		output.PrintSuccess(
			"edge_link",
			fmt.Sprintf("Linked: %s --[%s]--> %s", fromNode.GetTitle(), edgeRelation, toNode.GetTitle()),
			map[string]any{
				"from_id":   fromID,
				"to_id":     toID,
				"relation":  edgeRelation,
				"from_type": fromNode.Type,
				"to_type":   toNode.Type,
			},
		)
	},
}

var edgeUnlinkCmd = &cobra.Command{
	Use:   "unlink <from-id> <to-id>",
	Short: "Remove a link between two nodes",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		fromID := args[0]
		toID := args[1]

		if err := db.DeleteEdge(fromID, toID); err != nil {
			output.PrintError("edge_unlink", err.Error(), "Use 'auditscope edge list' to see available edges")
			return
		}

		output.PrintSuccess(
			"edge_unlink",
			fmt.Sprintf("Unlinked: %s -> %s", fromID, toID),
			map[string]any{
				"from_id": fromID,
				"to_id":   toID,
			},
		)
	},
}

var edgeListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all edges",
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		edges := db.GetEdges()
		nodes := db.GetNodes()

		nodeMap := make(map[string]*models.Node)
		for i := range nodes {
			nodeMap[nodes[i].ID] = &nodes[i]
		}

		var data []map[string]any
		for _, e := range edges {
			fromNode := nodeMap[e.From]
			toNode := nodeMap[e.To]

			data = append(data, map[string]any{
				"from_id":  e.From,
				"to_id":    e.To,
				"relation": e.Relation,
				"from_title": func() string {
					if fromNode != nil {
						return fromNode.GetTitle()
					}
					return ""
				}(),
				"to_title": func() string {
					if toNode != nil {
						return toNode.GetTitle()
					}
					return ""
				}(),
				"from_type": func() string {
					if fromNode != nil {
						return fromNode.Type
					}
					return ""
				}(),
				"to_type": func() string {
					if toNode != nil {
						return toNode.Type
					}
					return ""
				}(),
			})
		}

		output.PrintSuccess(
			"edge_list",
			fmt.Sprintf("Found %d edges", len(data)),
			map[string]any{
				"edges": data,
				"count": len(data),
			},
		)
	},
}

func init() {
	edgeCmd.AddCommand(edgeLinkCmd, edgeUnlinkCmd, edgeListCmd)

	edgeLinkCmd.Flags().StringVarP(&edgeRelation, "relation", "r", models.RelationRelates, "Relation type (supports, refutes, relates)")

	rootCmd.AddCommand(edgeCmd)
}
