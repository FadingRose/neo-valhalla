package report

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/kobayakawayuu/auditscope/pkg/models"
)

type Generator struct {
	Subject    *models.Subject
	Nodes      []models.Node
	Edges      []models.Edge
	ReportsDir string
}

func NewGenerator(subject *models.Subject, nodes []models.Node, edges []models.Edge, reportsDir string) *Generator {
	return &Generator{
		Subject:    subject,
		Nodes:      nodes,
		Edges:      edges,
		ReportsDir: reportsDir,
	}
}

func (g *Generator) getRepoRoot() string {
	if g.Subject != nil && g.Subject.RepoRoot != "" {
		return g.Subject.RepoRoot
	}
	for _, n := range g.Nodes {
		if n.RepoRoot != "" {
			return n.RepoRoot
		}
	}
	return ""
}

func (g *Generator) resolveFilePath(file string) string {
	if file == "" {
		return ""
	}
	if filepath.IsAbs(file) {
		return file
	}
	repoRoot := g.getRepoRoot()
	if repoRoot != "" {
		return filepath.Join(repoRoot, file)
	}
	return file
}

func (g *Generator) readFileLines(filePath string, startLine, endLine int) []string {
	if filePath == "" || startLine == 0 {
		return nil
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil
	}

	lines := strings.Split(string(data), "\n")
	if startLine < 1 {
		startLine = 1
	}
	if endLine == 0 || endLine > len(lines) {
		endLine = len(lines)
	}
	if startLine > len(lines) {
		return nil
	}

	startIdx := startLine - 1
	endIdx := endLine
	if endIdx > len(lines) {
		endIdx = len(lines)
	}

	return lines[startIdx:endIdx]
}

func (g *Generator) detectLanguage(file string) string {
	if file == "" {
		return ""
	}
	ext := strings.ToLower(filepath.Ext(file))
	langMap := map[string]string{
		".rs":    "rust",
		".sol":   "solidity",
		".go":    "go",
		".ts":    "typescript",
		".tsx":   "typescript",
		".js":    "javascript",
		".jsx":   "javascript",
		".py":    "python",
		".c":     "c",
		".cpp":   "cpp",
		".h":     "c",
		".hpp":   "cpp",
		".java":  "java",
		".kt":    "kotlin",
		".swift": "swift",
		".rb":    "ruby",
		".lua":   "lua",
		".sh":    "bash",
		".yaml":  "yaml",
		".yml":   "yaml",
		".json":  "json",
		".toml":  "toml",
		".md":    "markdown",
	}
	if lang, ok := langMap[ext]; ok {
		return lang
	}
	return ""
}

func (g *Generator) renderCodeBlock(file string, startLine, endLine int) []string {
	filePath := g.resolveFilePath(file)
	lines := g.readFileLines(filePath, startLine, endLine)
	if len(lines) == 0 {
		return nil
	}

	lang := g.detectLanguage(file)
	var result []string
	result = append(result, fmt.Sprintf("```%s", lang))

	lineRange := fmt.Sprintf("%d", startLine)
	if endLine > 0 && endLine != startLine {
		lineRange = fmt.Sprintf("%d-%d", startLine, endLine)
	}
	relPath := file
	repoRoot := g.getRepoRoot()
	if repoRoot != "" && strings.HasPrefix(file, repoRoot) {
		relPath = strings.TrimPrefix(file, repoRoot)
		if relPath[0] == '/' {
			relPath = relPath[1:]
		}
	}
	result = append(result, fmt.Sprintf("/// %s:%s", relPath, lineRange))

	for i, line := range lines {
		lineNum := startLine + i
		result = append(result, fmt.Sprintf("%d| %s", lineNum, line))
	}

	result = append(result, "```")
	return result
}

func (g *Generator) Generate() (string, error) {
	if g.Subject == nil {
		return "", fmt.Errorf("no subject")
	}

	if err := os.MkdirAll(g.ReportsDir, 0o755); err != nil {
		return "", err
	}

	reportName := safeFilename(g.Subject.ID)
	if reportName == "" {
		reportName = safeFilename(g.Subject.Title)
	}
	if reportName == "" {
		reportName = fmt.Sprintf("subject_%d", time.Now().Unix())
	}

	reportPath := filepath.Join(g.ReportsDir, reportName+".md")

	var lines []string

	lines = append(lines, fmt.Sprintf("# %s", g.Subject.Title))
	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("- Status: %s", g.Subject.Status))
	if g.Subject.Scope != "" {
		lines = append(lines, fmt.Sprintf("- Scope: %s", g.Subject.Scope))
	}
	lines = append(lines, fmt.Sprintf("- Created: %s", formatTime(g.Subject.CreatedAt)))
	lines = append(lines, fmt.Sprintf("- Updated: %s", formatTime(g.Subject.UpdatedAt)))
	lines = append(lines, "")

	lines = append(lines, "## Executive Summary")
	lines = append(lines, "")
	if g.Subject.Summary != "" {
		lines = append(lines, sanitizeText(g.Subject.Summary))
	} else {
		lines = append(lines, "_No summary yet._")
	}
	lines = append(lines, "")

	g.addGroupList(&lines, "Evidence", []string{models.NodeTypeEvidence, models.NodeTypeFact}, "E")
	g.addGroupList(&lines, "Notes", []string{models.NodeTypeNote}, "N")
	g.addGroupList(&lines, "Insights", []string{models.NodeTypeInsight}, "I")
	g.addGroupList(&lines, "Assumptions", []string{models.NodeTypeAssumption}, "A")
	g.addGroupList(&lines, "Invariants", []string{models.NodeTypeInvariant}, "V")
	g.addGroupList(&lines, "Open Questions", []string{models.NodeTypeQuestion}, "Q")
	g.addGroupList(&lines, "Hypotheses", []string{models.NodeTypeHypothesis}, "H")
	g.addGroupHeading(&lines, "Findings", []string{models.NodeTypeFinding}, "F")
	g.addGroupHeading(&lines, "Decisions", []string{models.NodeTypeDecision}, "D")
	g.addGroupHeading(&lines, "Risks", []string{models.NodeTypeRisk}, "R")

	content := strings.Join(lines, "\n")
	if err := os.WriteFile(reportPath, []byte(content), 0o644); err != nil {
		return "", err
	}

	return reportPath, nil
}

func (g *Generator) groupNodes() map[string][]models.Node {
	groups := make(map[string][]models.Node)
	for _, n := range g.Nodes {
		t := n.Type
		if t == "" {
			t = models.NodeTypeNote
		}
		groups[t] = append(groups[t], n)
	}
	return groups
}

func (g *Generator) addGroupList(lines *[]string, title string, types []string, prefix string) {
	var items []models.Node
	for _, t := range types {
		items = append(items, g.groupNodes()[t]...)
	}
	if len(items) == 0 {
		return
	}

	*lines = append(*lines, fmt.Sprintf("## %s", title))
	*lines = append(*lines, "")

	for i, n := range items {
		title := sanitizeText(n.GetTitle())
		if title == "" {
			title = "(empty)"
		}
		label := fmt.Sprintf("%s%d", prefix, i)
		*lines = append(*lines, fmt.Sprintf("- [%s] %s", label, title))

		if n.Description != "" {
			*lines = append(*lines, fmt.Sprintf("  %s", sanitizeText(n.Description)))
		}

		var fields []string
		if n.RepoName != "" {
			fields = append(fields, fmt.Sprintf("Repo: %s", n.RepoName))
		}
		if n.File != "" && n.StartLine > 0 {
			ref := formatReference(n)
			if ref != "" {
				fields = append(fields, fmt.Sprintf("Location: %s", ref))
			}
		}
		if len(fields) > 0 {
			*lines = append(*lines, fmt.Sprintf("  %s", strings.Join(fields, " | ")))
		}

		snippets := collectSnippets(n)
		if len(snippets) > 0 {
			*lines = append(*lines, "  Snippets:")
			for _, s := range snippets {
				snippetLines := strings.Split(s.Text, "\n")
				for _, l := range snippetLines {
					*lines = append(*lines, fmt.Sprintf("    %s", l))
				}
				*lines = append(*lines, "  ")
			}
		}
	}
	*lines = append(*lines, "")
}

func (g *Generator) addGroupHeading(lines *[]string, title string, types []string, prefix string) {
	var items []models.Node
	for _, t := range types {
		items = append(items, g.groupNodes()[t]...)
	}
	if len(items) == 0 {
		return
	}

	*lines = append(*lines, fmt.Sprintf("## %s", title))
	*lines = append(*lines, "")

	for i, n := range items {
		title := sanitizeText(n.GetTitle())
		if title == "" {
			title = "(empty)"
		}
		label := fmt.Sprintf("%s%d", prefix, i)
		*lines = append(*lines, fmt.Sprintf("### [%s] %s", label, title))

		if n.Description != "" {
			*lines = append(*lines, sanitizeText(n.Description))
		}

		var fields []string
		fields = append(fields, fmt.Sprintf("\n> "))
		if n.RepoName != "" {
			fields = append(fields, fmt.Sprintf("Repo: %s", n.RepoName))
		}
		if n.File != "" && n.StartLine > 0 {
			ref := formatReference(n)
			if ref != "" {
				fields = append(fields, fmt.Sprintf("Location: %s", ref))
			}
		}
		if len(fields) > 0 {
			*lines = append(*lines, strings.Join(fields, " | "))
		}

		if n.File != "" && n.StartLine > 0 {
			codeLines := g.renderCodeBlock(n.File, n.StartLine, n.EndLine)
			if len(codeLines) > 0 {
				*lines = append(*lines, "")
				*lines = append(*lines, codeLines...)
			}
		}

		snippets := collectSnippets(n)
		if len(snippets) > 0 {
			*lines = append(*lines, "")
			*lines = append(*lines, "**Additional Snippets:**")
			for _, s := range snippets {
				lang := g.detectLanguage(s.File)
				if lang != "" {
					*lines = append(*lines, fmt.Sprintf("```%s", lang))
				} else {
					*lines = append(*lines, "```")
				}
				*lines = append(*lines, strings.Split(s.Text, "\n")...)
				*lines = append(*lines, "```")
			}
		}
		*lines = append(*lines, "")
	}
}

func formatTime(ts int64) string {
	if ts == 0 {
		return "unknown"
	}
	return time.Unix(ts, 0).Format("2006-01-02 15:04")
}

func sanitizeText(text string) string {
	if text == "" {
		return ""
	}
	return text
	// return strings.ReplaceAll(strings.ReplaceAll(text, "\r", " "), "\n", " ")
}

func safeFilename(value string) string {
	if value == "" {
		return ""
	}
	name := value
	name = strings.Map(func(r rune) rune {
		if r == '/' || r == '\\' || r == ' ' {
			return '_'
		}
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' || r == '-' || r == '.' {
			return r
		}
		return '_'
	}, name)
	name = strings.Trim(name, "_.")
	return name
}

func formatReference(n models.Node) string {
	if n.File == "" || n.StartLine == 0 {
		return ""
	}
	rel := n.File
	if n.RepoRoot != "" {
		rel = strings.TrimPrefix(n.File, n.RepoRoot+"/")
	}
	lineRange := fmt.Sprintf("%d", n.StartLine)
	if n.EndLine > 0 && n.EndLine != n.StartLine {
		lineRange = fmt.Sprintf("%d-%d", n.StartLine, n.EndLine)
	}
	commit := ""
	if n.Commit != "" {
		commit = "@" + n.Commit
	}
	return fmt.Sprintf("`%s:%s%s`", rel, lineRange, commit)
}

func collectSnippets(n models.Node) []models.CodeSnippet {
	var snippets []models.CodeSnippet
	if len(n.CodeSnippets) > 0 {
		for _, s := range n.CodeSnippets {
			if s.Text != "" {
				snippets = append(snippets, s)
			}
		}
	}
	if len(snippets) == 0 && n.CodeSnippet != "" {
		snippets = append(snippets, models.CodeSnippet{Text: n.CodeSnippet})
	}
	return snippets
}
