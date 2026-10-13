package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode"

	tea "charm.land/bubbletea/v2"
)

type folderChoice struct{ path, label string }
type projectsMsg struct {
	generation int
	choices    []folderChoice
	err        error
}

// Completion only lists the typed directory, never recursively scans a tree.
// Preserve the user's spelling (including ~, relative paths and spaces).
func completeFolders(value, base string) ([]folderChoice, error) {
	if value == "~" {
		value = "~/"
	}
	split := strings.LastIndex(value, "/") + 1
	prefix, name := value[:split], value[split:]
	directory := prefix
	if directory == "" {
		directory = "."
	}
	if strings.HasPrefix(directory, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, err
		}
		directory = filepath.Join(home, directory[2:])
	}
	if !filepath.IsAbs(directory) {
		if !filepath.IsAbs(base) {
			return nil, fmt.Errorf("절대 경로 또는 ~/로 시작하세요")
		}
		directory = filepath.Join(base, directory)
	}
	entries, err := os.ReadDir(directory)
	if err != nil {
		return nil, err
	}
	// Only the component being completed controls smartcase; /Users or
	// another uppercase parent must not make a lowercase query sensitive.
	sensitive := strings.IndexFunc(name, unicode.IsUpper) >= 0
	pattern := name
	if !sensitive {
		pattern = strings.ToLower(pattern)
	}
	var choices []folderChoice
	for _, entry := range entries {
		candidate := entry.Name()
		if !sensitive {
			candidate = strings.ToLower(candidate)
		}
		if !strings.HasPrefix(candidate, pattern) || (strings.HasPrefix(entry.Name(), ".") && !strings.HasPrefix(name, ".")) {
			continue
		}
		isDir := entry.IsDir()
		if entry.Type()&os.ModeSymlink != 0 {
			info, err := os.Stat(filepath.Join(directory, entry.Name()))
			isDir = err == nil && info.IsDir()
		}
		if isDir {
			choices = append(choices, folderChoice{path: prefix + entry.Name() + "/", label: entry.Name() + "/"})
		}
	}
	return choices, nil
}

func parseProjects(data string) []folderChoice {
	var choices []folderChoice
	seen := map[string]bool{}
	for _, line := range strings.Split(data, "\n") {
		parts := strings.Split(line, "\t")
		if len(parts) < 2 || !filepath.IsAbs(parts[0]) || seen[parts[0]] {
			continue
		}
		seen[parts[0]] = true
		label := parts[1]
		if len(parts) > 2 && parts[2] != "" {
			label += " · " + parts[2]
		}
		choices = append(choices, folderChoice{path: parts[0], label: label})
	}
	return choices
}

func (m *model) openProjects() tea.Cmd {
	m.projectOpen, m.projectLoading = true, true
	m.projectGeneration++
	generation := m.projectGeneration
	m.folderChoices, m.projects = nil, nil
	m.folderChoiceIndex = 0
	m.status = ""
	m.folderInput.Blur()
	m.projectInput.Reset()
	m.projectInput.Prompt = "프로젝트 › "
	m.projectInput.Placeholder = "프로젝트 / worktree 검색"
	focus := m.projectInput.Focus()
	return tea.Batch(focus, func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		command := "workspace"
		// The wrapper exports its own sibling script, independent of PATH.
		if trial := os.Getenv("TUIOS_PICKER_TRIAL"); trial != "" {
			command = filepath.Join(filepath.Dir(trial), "workspace")
		}
		output, err := exec.CommandContext(ctx, command, "_projects").Output()
		return projectsMsg{generation: generation, choices: parseProjects(string(output)), err: err}
	})
}

func (m *model) filterProjects() {
	type scored struct {
		choice folderChoice
		score  int
	}
	var matches []scored
	for _, choice := range m.projects {
		if score, ok := matchQuery(choice.label, m.projectInput.Value()); ok {
			matches = append(matches, scored{choice, score})
		}
	}
	sort.SliceStable(matches, func(i, j int) bool { return matches[i].score > matches[j].score })
	m.folderChoices = nil
	for _, match := range matches {
		m.folderChoices = append(m.folderChoices, match.choice)
	}
	m.folderChoiceIndex = 0
}

func (m *model) updateProjects(msg tea.KeyPressMsg) tea.Cmd {
	switch msg.String() {
	case "esc":
		m.projectOpen = false
		m.folderChoices = nil
		m.projectInput.Blur()
		m.status = ""
		return m.folderInput.Focus()
	case "ctrl+n", "ctrl+l", "ctrl+j", "tab", "ctrl+p", "ctrl+h", "ctrl+k", "shift+tab":
		if len(m.folderChoices) > 0 {
			step := 1
			if msg.String() == "ctrl+p" || msg.String() == "ctrl+h" || msg.String() == "ctrl+k" || msg.String() == "shift+tab" {
				step = -1
			}
			m.folderChoiceIndex = (m.folderChoiceIndex + step + len(m.folderChoices)) % len(m.folderChoices)
		}
		return nil
	case "enter":
		if m.projectLoading || len(m.folderChoices) == 0 {
			return nil
		}
		m.folderInput.SetValue(m.folderChoices[m.folderChoiceIndex].path)
		m.folderInput.CursorEnd()
		m.projectOpen = false
		m.folderChoices = nil
		m.projectInput.Blur()
		m.status = ""
		return m.folderInput.Focus()
	}
	before := m.projectInput.Value()
	var cmd tea.Cmd
	m.projectInput, cmd = m.projectInput.Update(msg)
	if m.projectInput.Value() != before {
		m.filterProjects()
	}
	return cmd
}

// Suggestions never replace typed text or select a different directory implicitly.
// Enter applies the typed path until the user explicitly selects a candidate.
func (m *model) refreshFolderChoices() {
	m.folderChoices = nil
	m.folderChoiceIndex = -1
	m.status = ""
	if m.folderInput.Value() == "" {
		return
	}
	choices, err := completeFolders(m.folderInput.Value(), m.creationBase)
	if err == nil {
		m.folderChoices = choices
	}
}
