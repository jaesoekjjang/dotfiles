package main

import (
	"image/color"

	"charm.land/bubbles/v2/textinput"
	"charm.land/lipgloss/v2"
)

type pickerStyles struct {
	normal, bright, muted, border, green, pointer, amber lipgloss.Style
	accent, selection                                    color.Color
}

// Keep the popup background transparent. Only the selected row has a fill,
// derived from the actual terminal background so light themes retain their hue.
func newPickerStyles(dark bool, background color.Color) pickerStyles {
	text, heading, secondary, frame := "#caced8", "#dcdfe6", "#a7adb7", "#5c626c"
	current, accent, warning := "#9ece6a", "#7dcfff", "#e0af68"
	selection := color.Color(lipgloss.Color("#383c45"))
	if !dark {
		text, heading, secondary, frame = "#3f4b43", "#303b33", "#535f54", "#8b9484"
		current, accent, warning = "#3b602f", "#2d6066", "#75591f"
		selection = lipgloss.Color("#e2e4d8")
	}
	if background != nil {
		r, g, b, _ := background.RGBA()
		blend := func(c uint32) uint8 {
			v := float64(c >> 8)
			if dark {
				return uint8(v + (255-v)*0.10)
			}
			return uint8(v * 0.92)
		}
		selection = color.RGBA{R: blend(r), G: blend(g), B: blend(b), A: 255}
	}
	style := func(hex string) lipgloss.Style { return lipgloss.NewStyle().Foreground(lipgloss.Color(hex)) }
	return pickerStyles{
		normal: style(text), bright: style(heading).Bold(true), muted: style(secondary),
		border: style(frame), green: style(current), pointer: style(accent), amber: style(warning),
		accent: lipgloss.Color(accent), selection: selection,
	}
}

func (m *model) applyPickerStyles(styles pickerStyles) {
	m.styles = styles
	for _, input := range []*textinput.Model{&m.search, &m.prompt, &m.folderInput, &m.projectInput} {
		s := input.Styles()
		s.Focused.Text = styles.normal
		s.Focused.Prompt = styles.bright
		s.Focused.Placeholder = styles.muted
		s.Blurred = s.Focused
		s.Cursor.Color = styles.accent
		input.SetStyles(s)
	}
}
