class_name TerminalTheme
extends RefCounted
## Builds the minimal terminal Theme (ADR 0006/0007): palette colours + panel and
## button styleboxes, applied once at the shell root so every child Control
## inherits it. Deliberately small — Orbitron/Share Tech Mono fonts are a later
## drop-in (no font files yet); this gives the look and a consistent base now.


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_DIM)

	theme.set_stylebox("panel", "PanelContainer", _panel_box())

	theme.set_stylebox("normal", "Button", _button_box(Palette.PANEL))
	theme.set_stylebox("hover", "Button", _button_box(Palette.PANEL_BORDER))
	theme.set_stylebox("pressed", "Button", _button_box(Palette.ACCENT.darkened(0.4)))
	theme.set_stylebox("disabled", "Button", _button_box(Palette.PANEL.darkened(0.3)))
	return theme


static func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PANEL
	box.border_color = Palette.PANEL_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func _button_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Palette.PANEL_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box
