package llm

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/kobayakawayuu/auditscope/pkg/models"
)

type Client struct {
	APIKey  string
	Model   string
	Timeout time.Duration
}

type LinkSuggestion struct {
	TargetID   string  `json:"target_id"`
	Relation   string  `json:"relation"`
	Confidence float64 `json:"confidence"`
	Reason     string  `json:"reason"`
}

type LinkResponse struct {
	Links []LinkSuggestion `json:"links"`
}

func NewClient(apiKey, model string, timeoutMs int) *Client {
	if model == "" {
		model = "google/gemini-3-flash-preview"
	}
	if timeoutMs == 0 {
		timeoutMs = 30000
	}
	return &Client{
		APIKey:  apiKey,
		Model:   model,
		Timeout: time.Duration(timeoutMs) * time.Millisecond,
	}
}

func (c *Client) GetLinkSuggestions(source *models.Node, candidates []models.Node, maxLinks int) ([]LinkSuggestion, error) {
	if c.APIKey == "" {
		return nil, fmt.Errorf("OPENROUTER_API_KEY not set")
	}

	prompt := c.buildPrompt(source, candidates)

	payload := map[string]any{
		"model": c.Model,
		"messages": []map[string]string{
			{
				"role": "system",
				"content": `You are an audit assistant. Given a source node and a list of candidate nodes, select the best links from the source to candidates.
Only consider candidates that are same-level or higher-level than the source.
Use relation values: supports, refutes, relates.
Respond ONLY with JSON: {"links":[{"target_id":"...","relation":"...","confidence":0.0,"reason":"..."}]}`,
			},
			{
				"role":    "user",
				"content": prompt,
			},
		},
		"temperature": 0.2,
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	client := &http.Client{Timeout: c.Timeout}
	req, err := http.NewRequest("POST", "https://openrouter.ai/api/v1/chat/completions", bytes.NewBuffer(jsonPayload))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("HTTP-Referer", "http://localhost")
	req.Header.Set("X-Title", "AuditScope")

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("OpenRouter API error: %s", string(body))
	}

	var openRouterResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(body, &openRouterResp); err != nil {
		return nil, err
	}

	if len(openRouterResp.Choices) == 0 {
		return nil, fmt.Errorf("no response from LLM")
	}

	content := openRouterResp.Choices[0].Message.Content

	var linkResp LinkResponse
	if err := extractJSON(content, &linkResp); err != nil {
		return nil, fmt.Errorf("failed to parse LLM response: %w", err)
	}

	if maxLinks > 0 && len(linkResp.Links) > maxLinks {
		linkResp.Links = linkResp.Links[:maxLinks]
	}

	return linkResp.Links, nil
}

func (c *Client) buildPrompt(source *models.Node, candidates []models.Node) string {
	var lines []string

	lines = append(lines, "SOURCE NODE:")
	lines = append(lines, fmt.Sprintf("[id=%s] type=%s", source.ID, source.Type))
	lines = append(lines, fmt.Sprintf("title=%s", truncate(source.GetTitle(), 400)))
	if source.Description != "" {
		lines = append(lines, fmt.Sprintf("description=%s", truncate(source.Description, 400)))
	}
	if source.File != "" {
		lines = append(lines, fmt.Sprintf("file=%s lines=%d-%d", source.File, source.StartLine, source.EndLine))
	}
	if len(source.CodeSnippets) > 0 && source.CodeSnippets[0].Text != "" {
		lines = append(lines, fmt.Sprintf("snippet=%s", truncate(source.CodeSnippets[0].Text, 400)))
	}

	lines = append(lines, "", "CANDIDATES:")
	for _, n := range candidates {
		lineRange := ""
		if n.StartLine > 0 {
			lineRange = fmt.Sprintf("%d", n.StartLine)
			if n.EndLine > 0 && n.EndLine != n.StartLine {
				lineRange = fmt.Sprintf("%d-%d", n.StartLine, n.EndLine)
			}
		}
		lines = append(lines, fmt.Sprintf("[id=%s] type=%s title=%s file=%s lines=%s",
			n.ID, n.Type, truncate(n.GetTitle(), 200), n.File, lineRange))
	}

	return fmt.Sprintf("%s\n\nSelect up to 3 best links.", strings.Join(lines, "\n"))
}

func extractJSON(text string, target any) error {
	start := bytes.IndexByte([]byte(text), '{')
	end := bytes.LastIndexByte([]byte(text), '}')
	if start == -1 || end == -1 || end <= start {
		return fmt.Errorf("no JSON object found")
	}
	return json.Unmarshal([]byte(text[start:end+1]), target)
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

func GetAPIKey() string {
	return os.Getenv("OPENROUTER_API_KEY")
}
