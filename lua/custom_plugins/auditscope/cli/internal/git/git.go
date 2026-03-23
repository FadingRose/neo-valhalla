package git

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type RepoContext struct {
	Root   string `json:"root,omitempty"`
	Name   string `json:"name,omitempty"`
	Commit string `json:"commit,omitempty"`
}

func GetRepoContext() *RepoContext {
	ctx := &RepoContext{}

	gitRoot, err := findGitRoot()
	if err != nil {
		return ctx
	}
	ctx.Root = gitRoot
	ctx.Name = filepath.Base(gitRoot)

	commit, err := getHeadCommit(gitRoot)
	if err == nil {
		ctx.Commit = commit
	}

	return ctx
}

func findGitRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		gitDir := filepath.Join(dir, ".git")
		if _, err := os.Stat(gitDir); err == nil {
			return dir, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("not in a git repository")
		}
		dir = parent
	}
}

func getHeadCommit(gitRoot string) (string, error) {
	cmd := exec.Command("git", "-C", gitRoot, "rev-parse", "--short", "HEAD")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func GetCurrentFile() string {
	if len(os.Args) < 1 {
		return ""
	}
	absPath, err := filepath.Abs(os.Args[0])
	if err != nil {
		return os.Args[0]
	}
	return absPath
}
