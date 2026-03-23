package models

import "time"

const (
	NodeTypeNote       = "note"
	NodeTypeEvidence   = "evidence"
	NodeTypeInsight    = "insight"
	NodeTypeQuestion   = "question"
	NodeTypeHypothesis = "hypothesis"
	NodeTypeFact       = "fact"
	NodeTypeAssumption = "assumption"
	NodeTypeInvariant  = "invariant"
	NodeTypeFinding    = "finding"
	NodeTypeDecision   = "decision"
	NodeTypeRisk       = "risk"
)

const (
	RelationSupports = "supports"
	RelationRefutes  = "refutes"
	RelationRelates  = "relates"
)

type Subject struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	Scope     string `json:"scope,omitempty"`
	Summary   string `json:"summary,omitempty"`
	RepoRoot  string `json:"repo_root,omitempty"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

type CodeSnippet struct {
	Text      string `json:"text"`
	File      string `json:"file,omitempty"`
	StartLine int    `json:"start_line,omitempty"`
	EndLine   int    `json:"end_line,omitempty"`
	Timestamp int64  `json:"timestamp,omitempty"`
	Commit    string `json:"commit,omitempty"`
	RepoRoot  string `json:"repo_root,omitempty"`
	RepoName  string `json:"repo_name,omitempty"`
}

type Node struct {
	ID           string        `json:"id"`
	Type         string        `json:"type"`
	Title        string        `json:"title"`
	Description  string        `json:"description,omitempty"`
	File         string        `json:"file,omitempty"`
	StartLine    int           `json:"start_line,omitempty"`
	EndLine      int           `json:"end_line,omitempty"`
	CodeSnippet  string        `json:"code_snippet,omitempty"`
	CodeSnippets []CodeSnippet `json:"codesnippets,omitempty"`
	RepoRoot     string        `json:"repo_root,omitempty"`
	RepoName     string        `json:"repo_name,omitempty"`
	Commit       string        `json:"commit,omitempty"`
	Timestamp    int64         `json:"timestamp"`
}

func (n *Node) GetTitle() string {
	return n.Title
}

func (n *Node) GetDescription() string {
	return n.Description
}

type Edge struct {
	From     string `json:"from"`
	To       string `json:"to"`
	Relation string `json:"relation"`
}

type GlanceData map[string]map[string]int

type SubjectData struct {
	Subject *Subject   `json:"subject,omitempty"`
	Nodes   []Node     `json:"nodes"`
	Edges   []Edge     `json:"edges"`
	Glance  GlanceData `json:"glance,omitempty"`
}

type SubjectMeta struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	Scope     string `json:"scope,omitempty"`
	RepoRoot  string `json:"repo_root,omitempty"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

type Index struct {
	Subjects []SubjectMeta `json:"subjects"`
}

type State struct {
	ActiveSubjectID string `json:"active_subject_id"`
}

func NewSubjectMeta(title, id string) SubjectMeta {
	now := time.Now().Unix()
	return SubjectMeta{
		ID:        id,
		Title:     title,
		Status:    "active",
		CreatedAt: now,
		UpdatedAt: now,
	}
}

func NewNode(id, nodeType, title, description, file string, startLine, endLine int) Node {
	return Node{
		ID:          id,
		Type:        nodeType,
		Title:       title,
		Description: description,
		File:        file,
		StartLine:   startLine,
		EndLine:     endLine,
		Timestamp:   time.Now().Unix(),
	}
}

func NewEdge(from, to, relation string) Edge {
	return Edge{
		From:     from,
		To:       to,
		Relation: relation,
	}
}

var ValidNodeTypes = []string{
	NodeTypeNote, NodeTypeEvidence, NodeTypeInsight, NodeTypeQuestion,
	NodeTypeHypothesis, NodeTypeFact, NodeTypeAssumption, NodeTypeInvariant,
	NodeTypeFinding, NodeTypeDecision, NodeTypeRisk,
}

var ValidRelations = []string{RelationSupports, RelationRefutes, RelationRelates}

func IsValidNodeType(t string) bool {
	for _, vt := range ValidNodeTypes {
		if vt == t {
			return true
		}
	}
	return false
}

func IsValidRelation(r string) bool {
	for _, vr := range ValidRelations {
		if vr == r {
			return true
		}
	}
	return false
}
