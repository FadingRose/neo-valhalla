package db

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/kobayakawayuu/auditscope/pkg/models"
)

const (
	HumanPassword = "maidsamaviria"
)

const base36chars = "0123456789abcdefghijklmnopqrstuvwxyz"

func GenerateID() string {
	now := time.Now().UnixNano()
	r := rand.New(rand.NewSource(now))

	id := ""
	for i := 0; i < 8; i++ {
		id += string(base36chars[r.Intn(36)])
	}
	return id
}

var (
	storageRoot     string
	subjectsDir     string
	reportsDir      string
	stateFile       string
	indexFile       string
	indexCache      *models.Index
	lockedCommits   = make(map[string]string)
	activeSubjectID string
	currentData     *models.SubjectData
)

func Init(storagePath string) error {
	if storagePath == "" {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("failed to get home directory: %w", err)
		}
		storageRoot = filepath.Join(homeDir, ".local", "share", "auditscope")
	} else {
		storageRoot = storagePath
	}

	subjectsDir = filepath.Join(storageRoot, "subjects")
	reportsDir = filepath.Join(storageRoot, "reports")
	stateFile = filepath.Join(storageRoot, "state.json")
	indexFile = filepath.Join(storageRoot, "subjects.json")

	if err := os.MkdirAll(subjectsDir, 0755); err != nil {
		return fmt.Errorf("failed to create subjects directory: %w", err)
	}
	if err := os.MkdirAll(reportsDir, 0755); err != nil {
		return fmt.Errorf("failed to create reports directory: %w", err)
	}

	loadState()
	loadIndex()
	rebuildIndexFromFiles()

	return nil
}

func rebuildIndexFromFiles() {
	entries, err := os.ReadDir(subjectsDir)
	if err != nil {
		return
	}

	existingIDs := make(map[string]bool)
	for _, s := range indexCache.Subjects {
		existingIDs[s.ID] = true
	}

	changed := false
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if filepath.Ext(name) != ".json" {
			continue
		}

		id := name[:len(name)-5]
		if existingIDs[id] {
			continue
		}

		filePath := filepath.Join(subjectsDir, name)
		data, err := os.ReadFile(filePath)
		if err != nil {
			continue
		}

		var sd models.SubjectData
		if err := json.Unmarshal(data, &sd); err != nil {
			continue
		}
		if sd.Subject == nil || sd.Subject.ID == "" {
			continue
		}

		meta := models.SubjectMeta{
			ID:        sd.Subject.ID,
			Title:     sd.Subject.Title,
			Status:    sd.Subject.Status,
			Scope:     sd.Subject.Scope,
			CreatedAt: sd.Subject.CreatedAt,
			UpdatedAt: sd.Subject.UpdatedAt,
		}
		indexCache.Subjects = append(indexCache.Subjects, meta)
		changed = true
	}

	if changed {
		saveIndex(indexCache)
	}
}

func GetStoragePaths() map[string]string {
	return map[string]string{
		"root":         storageRoot,
		"subjects_dir": subjectsDir,
		"reports_dir":  reportsDir,
		"state_file":   stateFile,
		"index_file":   indexFile,
	}
}

func loadState() {
	data, err := os.ReadFile(stateFile)
	if err != nil {
		return
	}
	var state models.State
	if err := json.Unmarshal(data, &state); err == nil {
		activeSubjectID = state.ActiveSubjectID
	}
}

func saveState() error {
	state := models.State{ActiveSubjectID: activeSubjectID}
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(stateFile, data, 0644)
}

func loadIndex() *models.Index {
	if indexCache != nil {
		return indexCache
	}
	data, err := os.ReadFile(indexFile)
	if err != nil {
		indexCache = &models.Index{Subjects: []models.SubjectMeta{}}
		return indexCache
	}
	var idx models.Index
	if err := json.Unmarshal(data, &idx); err != nil {
		indexCache = &models.Index{Subjects: []models.SubjectMeta{}}
		return indexCache
	}
	indexCache = &idx
	return indexCache
}

func saveIndex(idx *models.Index) error {
	data, err := json.MarshalIndent(idx, "", "  ")
	if err != nil {
		return err
	}
	indexCache = idx
	return os.WriteFile(indexFile, data, 0644)
}

func GetSubjects() []models.SubjectMeta {
	idx := loadIndex()
	return idx.Subjects
}

func GetSubjectByID(id string) *models.SubjectMeta {
	idx := loadIndex()
	for i := range idx.Subjects {
		if idx.Subjects[i].ID == id {
			return &idx.Subjects[i]
		}
	}
	return nil
}

func GetActiveSubjectID() string {
	return activeSubjectID
}

func GetActiveSubject() *models.SubjectMeta {
	if activeSubjectID == "" {
		return nil
	}
	return GetSubjectByID(activeSubjectID)
}

func SetActiveSubject(id string) error {
	subjectPath := filepath.Join(subjectsDir, id+".json")
	if _, err := os.Stat(subjectPath); os.IsNotExist(err) {
		return fmt.Errorf("subject not found: %s", id)
	}

	idx := loadIndex()
	for i := range idx.Subjects {
		newStatus := "inactive"
		if idx.Subjects[i].ID == id {
			newStatus = "active"
		}
		if idx.Subjects[i].Status != newStatus {
			idx.Subjects[i].Status = newStatus
			updateSubjectFileStatus(idx.Subjects[i].ID, newStatus)
		}
	}
	saveIndex(idx)

	activeSubjectID = id
	if err := saveState(); err != nil {
		return err
	}

	return LoadSubjectData()
}

func updateSubjectFileStatus(id, status string) {
	filePath := filepath.Join(subjectsDir, id+".json")
	data, err := os.ReadFile(filePath)
	if err != nil {
		return
	}

	var sd models.SubjectData
	if err := json.Unmarshal(data, &sd); err != nil {
		return
	}
	if sd.Subject == nil {
		return
	}

	sd.Subject.Status = status
	updated, err := json.MarshalIndent(&sd, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(filePath, updated, 0644)
}

func LoadSubjectData() error {
	if activeSubjectID == "" {
		currentData = nil
		return nil
	}

	subjectPath := filepath.Join(subjectsDir, activeSubjectID+".json")
	data, err := os.ReadFile(subjectPath)
	if err != nil {
		currentData = nil
		return err
	}

	var sd models.SubjectData
	if err := json.Unmarshal(data, &sd); err != nil {
		return err
	}

	currentData = &sd
	return nil
}

func SaveSubjectData() error {
	if currentData == nil || currentData.Subject == nil {
		return fmt.Errorf("no active subject")
	}

	now := time.Now().Unix()
	currentData.Subject.UpdatedAt = now

	idx := loadIndex()
	for i := range idx.Subjects {
		if idx.Subjects[i].ID == currentData.Subject.ID {
			idx.Subjects[i].Title = currentData.Subject.Title
			idx.Subjects[i].Status = currentData.Subject.Status
			idx.Subjects[i].Scope = currentData.Subject.Scope
			idx.Subjects[i].UpdatedAt = now
			break
		}
	}
	if err := saveIndex(idx); err != nil {
		return err
	}

	subjectPath := filepath.Join(subjectsDir, currentData.Subject.ID+".json")
	data, err := json.MarshalIndent(currentData, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(subjectPath, data, 0644)
}

func CreateSubject(title, id, repoRoot string) (*models.SubjectMeta, error) {
	if id == "" {
		id = GenerateID()
	}

	now := time.Now().Unix()
	meta := models.SubjectMeta{
		ID:        id,
		Title:     title,
		Status:    "active",
		RepoRoot:  repoRoot,
		CreatedAt: now,
		UpdatedAt: now,
	}

	sd := &models.SubjectData{
		Subject: &models.Subject{
			ID:        meta.ID,
			Title:     meta.Title,
			Status:    meta.Status,
			Scope:     meta.Scope,
			RepoRoot:  meta.RepoRoot,
			CreatedAt: meta.CreatedAt,
			UpdatedAt: meta.UpdatedAt,
		},
		Nodes:  []models.Node{},
		Edges:  []models.Edge{},
		Glance: make(models.GlanceData),
	}

	subjectPath := filepath.Join(subjectsDir, id+".json")
	data, err := json.MarshalIndent(sd, "", "  ")
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(subjectPath, data, 0644); err != nil {
		return nil, err
	}

	idx := loadIndex()
	for i := range idx.Subjects {
		if idx.Subjects[i].Status != "inactive" {
			idx.Subjects[i].Status = "inactive"
			updateSubjectFileStatus(idx.Subjects[i].ID, "inactive")
		}
	}
	idx.Subjects = append(idx.Subjects, meta)
	if err := saveIndex(idx); err != nil {
		return nil, err
	}

	activeSubjectID = id
	currentData = sd
	if err := saveState(); err != nil {
		return nil, err
	}

	return &meta, nil
}

func DeleteSubject(id string) error {
	idx := loadIndex()
	found := false
	newSubjects := make([]models.SubjectMeta, 0)
	for _, s := range idx.Subjects {
		if s.ID == id {
			found = true
		} else {
			newSubjects = append(newSubjects, s)
		}
	}
	if !found {
		return fmt.Errorf("subject not found: %s", id)
	}

	idx.Subjects = newSubjects
	if err := saveIndex(idx); err != nil {
		return err
	}

	subjectPath := filepath.Join(subjectsDir, id+".json")
	os.Remove(subjectPath)

	if activeSubjectID == id {
		activeSubjectID = ""
		currentData = nil
		saveState()
	}

	return nil
}

func VerifyPassword(password string) bool {
	return password == HumanPassword
}

func GetCurrentData() *models.SubjectData {
	return currentData
}

func GetNodes() []models.Node {
	if currentData == nil {
		return nil
	}
	return currentData.Nodes
}

func GetNodeByID(id string) *models.Node {
	if currentData == nil {
		return nil
	}
	for i := range currentData.Nodes {
		if currentData.Nodes[i].ID == id {
			return &currentData.Nodes[i]
		}
	}
	return nil
}

func AddNode(node models.Node) error {
	if currentData == nil {
		return fmt.Errorf("no active subject")
	}
	currentData.Nodes = append(currentData.Nodes, node)
	return SaveSubjectData()
}

func UpdateNode(node models.Node) error {
	if currentData == nil {
		return fmt.Errorf("no active subject")
	}
	for i := range currentData.Nodes {
		if currentData.Nodes[i].ID == node.ID {
			currentData.Nodes[i] = node
			return SaveSubjectData()
		}
	}
	return fmt.Errorf("node not found: %s", node.ID)
}

func DeleteNode(id string) error {
	if currentData == nil {
		return fmt.Errorf("no active subject")
	}

	newNodes := make([]models.Node, 0)
	found := false
	for _, n := range currentData.Nodes {
		if n.ID == id {
			found = true
		} else {
			newNodes = append(newNodes, n)
		}
	}
	if !found {
		return fmt.Errorf("node not found: %s", id)
	}
	currentData.Nodes = newNodes

	newEdges := make([]models.Edge, 0)
	for _, e := range currentData.Edges {
		if e.From != id && e.To != id {
			newEdges = append(newEdges, e)
		}
	}
	currentData.Edges = newEdges

	return SaveSubjectData()
}

func GetEdges() []models.Edge {
	if currentData == nil {
		return nil
	}
	return currentData.Edges
}

func AddEdge(from, to, relation string) error {
	if currentData == nil {
		return fmt.Errorf("no active subject")
	}
	edge := models.NewEdge(from, to, relation)
	currentData.Edges = append(currentData.Edges, edge)
	return SaveSubjectData()
}

func DeleteEdge(from, to string) error {
	if currentData == nil {
		return fmt.Errorf("no active subject")
	}

	newEdges := make([]models.Edge, 0)
	found := false
	for _, e := range currentData.Edges {
		if e.From == from && e.To == to {
			found = true
		} else {
			newEdges = append(newEdges, e)
		}
	}
	if !found {
		return fmt.Errorf("edge not found: %s -> %s", from, to)
	}
	currentData.Edges = newEdges
	return SaveSubjectData()
}

func GetSummary() string {
	if currentData == nil || currentData.Subject == nil {
		return ""
	}
	return currentData.Subject.Summary
}

func SetSummary(summary string) error {
	if currentData == nil || currentData.Subject == nil {
		return fmt.Errorf("no active subject")
	}
	currentData.Subject.Summary = summary
	return SaveSubjectData()
}

func LockCommit(root, commit string) {
	lockedCommits[root] = commit
}

func UnlockCommit(root string) {
	delete(lockedCommits, root)
}

func GetLockedCommit(root string) string {
	return lockedCommits[root]
}

func UpdateGlance(file string, line, count int) error {
	if currentData == nil {
		return fmt.Errorf("no active subject")
	}
	if currentData.Glance == nil {
		currentData.Glance = make(models.GlanceData)
	}
	if currentData.Glance[file] == nil {
		currentData.Glance[file] = make(map[string]int)
	}
	lineKey := strconv.Itoa(line)
	if count > 0 {
		currentData.Glance[file][lineKey] = count
	} else {
		delete(currentData.Glance[file], lineKey)
	}
	return SaveSubjectData()
}

func GetGlance(file string) map[string]int {
	if currentData == nil || currentData.Glance == nil {
		return nil
	}
	return currentData.Glance[file]
}
