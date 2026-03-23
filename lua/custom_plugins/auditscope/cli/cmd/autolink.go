package cmd

import (
	"fmt"
	"sort"

	"github.com/kobayakawayuu/auditscope/internal/db"
	"github.com/kobayakawayuu/auditscope/internal/llm"
	"github.com/kobayakawayuu/auditscope/internal/ontology"
	"github.com/kobayakawayuu/auditscope/internal/output"
	"github.com/kobayakawayuu/auditscope/pkg/models"
	"github.com/spf13/cobra"
)

var (
	autolinkMaxLinks      int
	autolinkMinConf       float64
	autolinkMaxCandidates int
)

var autolinkCmd = &cobra.Command{
	Use:   "autolink [node-id]",
	Short: "Auto-link nodes using LLM",
	Long: `Auto-link a node to other nodes using LLM suggestions.

If no node-id is provided, it will pick the most relevant node based on current context.

Requires OPENROUTER_API_KEY environment variable.

Example:
  auditscope autolink node123
  auditscope autolink --max-links 5`,
	Run: func(cmd *cobra.Command, args []string) {
		if !requireActiveSubject() {
			return
		}

		apiKey := llm.GetAPIKey()
		if apiKey == "" {
			output.PrintError("autolink", "OPENROUTER_API_KEY not set", "Set the OPENROUTER_API_KEY environment variable")
			return
		}

		nodes := db.GetNodes()
		if len(nodes) < 2 {
			output.PrintError("autolink", "not enough nodes to link", "Create at least 2 nodes first")
			return
		}

		var source *models.Node
		if len(args) > 0 {
			source = db.GetNodeByID(args[0])
			if source == nil {
				output.PrintError("autolink", fmt.Sprintf("node not found: %s", args[0]), "Use 'auditscope node list' to see available nodes")
				return
			}
		} else {
			source = pickSourceNode(nodes)
		}

		if source == nil {
			output.PrintError("autolink", "could not determine source node", "Specify a node ID")
			return
		}

		var candidates []models.Node
		for _, n := range nodes {
			if n.ID != source.ID {
				if ontology.IsLinkAllowed(source.Type, n.Type) {
					candidates = append(candidates, n)
				}
			}
		}

		if len(candidates) == 0 {
			output.PrintError("autolink", "no eligible candidates (ontology rules)", "Create nodes with compatible types")
			return
		}

		sort.Slice(candidates, func(i, j int) bool {
			return candidates[i].Timestamp > candidates[j].Timestamp
		})

		if autolinkMaxCandidates > 0 && len(candidates) > autolinkMaxCandidates {
			candidates = candidates[:autolinkMaxCandidates]
		}

		client := llm.NewClient(apiKey, "", 30000)
		suggestions, err := client.GetLinkSuggestions(source, candidates, autolinkMaxLinks)
		if err != nil {
			output.PrintError("autolink", err.Error(), "Check OPENROUTER_API_KEY and network connection")
			return
		}

		if len(suggestions) == 0 {
			output.PrintError("autolink", "no link suggestions returned", "Try with different nodes or lower confidence threshold")
			return
		}

		edges := db.GetEdges()
		edgeMap := make(map[string]bool)
		for _, e := range edges {
			key := fmt.Sprintf("%s|%s|%s", e.From, e.To, e.Relation)
			edgeMap[key] = true
		}

		var applied []map[string]any
		for _, s := range suggestions {
			if s.Confidence < autolinkMinConf {
				continue
			}
			if !models.IsValidRelation(s.Relation) {
				s.Relation = models.RelationRelates
			}

			key := fmt.Sprintf("%s|%s|%s", source.ID, s.TargetID, s.Relation)
			if edgeMap[key] {
				continue
			}

			target := db.GetNodeByID(s.TargetID)
			if target == nil {
				continue
			}

			if err := db.AddEdge(source.ID, s.TargetID, s.Relation); err != nil {
				continue
			}

			edgeMap[key] = true
			applied = append(applied, map[string]any{
				"target_id":    s.TargetID,
				"target_title": target.GetTitle(),
				"relation":     s.Relation,
				"confidence":   s.Confidence,
				"reason":       s.Reason,
			})
		}

		output.PrintSuccess(
			"autolink",
			fmt.Sprintf("Auto-linked %d node(s)", len(applied)),
			map[string]any{
				"source_id":    source.ID,
				"source_title": source.GetTitle(),
				"links":        applied,
				"total_links":  len(applied),
			},
		)
	},
}

func pickSourceNode(nodes []models.Node) *models.Node {
	if len(nodes) == 0 {
		return nil
	}

	sort.Slice(nodes, func(i, j int) bool {
		return nodes[i].Timestamp > nodes[j].Timestamp
	})

	return &nodes[0]
}

func init() {
	autolinkCmd.Flags().IntVar(&autolinkMaxLinks, "max-links", 3, "Maximum number of links to create")
	autolinkCmd.Flags().Float64Var(&autolinkMinConf, "min-confidence", 0.35, "Minimum confidence threshold")
	autolinkCmd.Flags().IntVar(&autolinkMaxCandidates, "max-candidates", 40, "Maximum number of candidates to consider")

	rootCmd.AddCommand(autolinkCmd)
}
