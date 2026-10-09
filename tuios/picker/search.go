package main

import (
	"sort"
	"strings"
	"unicode"

	"dotfiles/tuios-picker/internal/tuios"
	"github.com/junegunn/fzf/src/algo"
	"github.com/junegunn/fzf/src/util"
)

func init() { algo.Init("default") }

func searchText(row tuios.Row, sessionLabel string) string {
	if row.Kind == "workspace" {
		label := strings.TrimSpace(workspaceLabel(row))
		if row.Parent != "" {
			label = sessionLabel + " › " + label
		}
		return label
	}
	return row.Label // Commands and paths deliberately do not affect matching.
}

type match struct {
	row   tuios.Row
	score int
}

// Terms are ANDed; a standalone | joins alternatives. Smart case and fzf's
// exact/prefix/suffix/inverse operators use the same matching algorithms as fzf.
func termMatch(text, term string) (int, bool) {
	inverse := strings.HasPrefix(term, "!")
	if inverse {
		term = strings.TrimPrefix(term, "!")
	}
	fn := algo.FuzzyMatchV2
	if inverse {
		fn = algo.ExactMatchNaive
	}
	if strings.HasPrefix(term, "'") {
		term = strings.TrimPrefix(term, "'")
		fn = algo.ExactMatchNaive
		if inverse {
			fn = algo.FuzzyMatchV2
		}
	}
	prefix, suffix := strings.HasPrefix(term, "^"), strings.HasSuffix(term, "$")
	if prefix {
		term = strings.TrimPrefix(term, "^")
		fn = algo.PrefixMatch
	}
	if suffix {
		term = strings.TrimSuffix(term, "$")
		fn = algo.SuffixMatch
	}
	if prefix && suffix {
		fn = algo.EqualMatch
	}
	if term == "" {
		return 0, !inverse
	}
	caseSensitive := strings.IndexFunc(term, unicode.IsUpper) >= 0
	pattern := []rune(term)
	if !caseSensitive {
		pattern = []rune(strings.ToLower(term))
	}
	chars := util.ToChars([]byte(text))
	result, _ := fn(caseSensitive, true, true, &chars, pattern, false, nil)
	ok := result.Start >= 0
	if inverse {
		return 0, !ok
	}
	return result.Score, ok
}

func matchQuery(text, query string) (int, bool) {
	terms := strings.Fields(query)
	total := 0
	for i := 0; i < len(terms); {
		best, ok := termMatch(text, terms[i])
		i++
		for i+1 < len(terms) && terms[i] == "|" {
			score, hit := termMatch(text, terms[i+1])
			if hit && (!ok || score > best) {
				best = score
			}
			ok = ok || hit
			i += 2
		}
		if !ok {
			return 0, false
		}
		total += best
	}
	return total, true
}

func filterRows(rows []tuios.Row, expanded map[string]bool, query string) []tuios.Row {
	var matches []match
	searching := strings.TrimSpace(query) != ""
	labels := map[string]string{}
	for _, row := range rows {
		if row.Parent == "" {
			labels[row.ID] = row.Label
		}
	}
	for _, row := range rows {
		// Session search spans its workspaces even when their tree is folded.
		if row.Parent != "" && !expanded[row.Parent] && !(searching && row.Kind == "workspace") {
			continue
		}
		if score, ok := matchQuery(searchText(row, labels[row.Parent]), query); ok {
			matches = append(matches, match{row, score})
		}
	}
	if searching {
		sort.SliceStable(matches, func(i, j int) bool { return matches[i].score > matches[j].score })
	}
	result := make([]tuios.Row, len(matches))
	for i, item := range matches {
		result[i] = item.row
	}
	return result
}
