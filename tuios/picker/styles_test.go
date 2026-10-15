package main

import (
	"image/color"
	"math"
	"reflect"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

func luminance(c color.Color) float64 {
	r, g, b, _ := c.RGBA()
	linear := func(v uint32) float64 {
		x := float64(v) / 65535
		if x <= 0.04045 {
			return x / 12.92
		}
		return math.Pow((x+0.055)/1.055, 2.4)
	}
	return 0.2126*linear(r) + 0.7152*linear(g) + 0.0722*linear(b)
}

func contrast(a, b color.Color) float64 {
	x, y := luminance(a), luminance(b)
	return (math.Max(x, y) + 0.05) / (math.Min(x, y) + 0.05)
}

func TestLightPickerTextReadsOnEverforestBackgrounds(t *testing.T) {
	for _, bg := range []string{"#fffbef", "#fdf6e3", "#f3ead3"} {
		s := newPickerStyles(false, lipgloss.Color(bg))
		for name, style := range map[string]lipgloss.Style{
			"body": s.normal, "heading": s.bright, "secondary": s.muted,
			"current": s.green, "cursor": s.pointer, "match and warning": s.amber,
		} {
			for _, ground := range []color.Color{lipgloss.Color(bg), s.selection} {
				if ratio := contrast(style.GetForeground(), ground); ratio < 4.5 {
					t.Errorf("%s on %s: contrast %.2f below 4.5", name, bg, ratio)
				}
			}
		}
		if luminance(s.selection) >= luminance(lipgloss.Color(bg)) {
			t.Fatal("light selection should be darker than the popup background")
		}
	}
}

func TestBackgroundReplyRestylesAllInputsWithoutChangingState(t *testing.T) {
	m := ready()
	m.search.SetValue("logs")
	m.prompt.SetValue("draft")
	m.folderInput.SetValue("/tmp")
	m.projectInput.SetValue("project")
	selected := m.selectedID()
	rows := append(m.rows[:0:0], m.rows...)
	other := ready()
	for _, bg := range []string{"#fdf6e3", "#09141b", "#fffbef"} {
		m.Update(tea.BackgroundColorMsg{Color: lipgloss.Color(bg)})
		for _, input := range []struct{ fg color.Color }{
			{m.search.Styles().Focused.Text.GetForeground()}, {m.prompt.Styles().Focused.Text.GetForeground()},
			{m.folderInput.Styles().Focused.Text.GetForeground()}, {m.projectInput.Styles().Focused.Text.GetForeground()},
		} {
			if !reflect.DeepEqual(input.fg, m.styles.normal.GetForeground()) {
				t.Fatal("input did not follow background")
			}
		}
		if m.search.Value() != "logs" || m.prompt.Value() != "draft" || m.folderInput.Value() != "/tmp" || m.projectInput.Value() != "project" || m.selectedID() != selected || !reflect.DeepEqual(m.rows, rows) {
			t.Fatal("background update changed search, drafts or navigation")
		}
	}
	if luminance(m.styles.normal.GetForeground()) >= luminance(other.styles.normal.GetForeground()) {
		t.Fatal("light reply must darken text without changing another model")
	}
}

func TestLightViewRecolorsRowsHelpAndModal(t *testing.T) {
	m := ready()
	before := ansi.Strip(m.View().Content)
	m.Update(tea.BackgroundColorMsg{Color: lipgloss.Color("#fdf6e3")})
	view := m.View().Content
	if ansi.Strip(view) != before {
		t.Fatal("restyling changed displayed content")
	}
	for _, old := range []string{"38;2;202;206;216", "38;2;220;223;230", "38;2;167;173;183", "38;2;125;207;255", "48;2;56;60;69"} {
		if strings.Contains(view, old) {
			t.Errorf("dark style remains in light view: %s", old)
		}
	}
	if !strings.Contains(view, "38;2;63;75;67") {
		t.Fatal("light text style missing from rendered view")
	}
	m.standalone = true
	m.modal = "close"
	m.modalRow = m.visible[0]
	view = m.View().Content
	if !strings.Contains(view, "38;2;48;59;51") {
		t.Fatal("standalone close heading did not use light style")
	}
}
