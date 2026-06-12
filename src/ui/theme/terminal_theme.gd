class_name TerminalTheme
extends RefCounted
## Builds the terminal Theme (ADR 0006/0007/0035): palette colours, panel + button
## styleboxes, applied once at the shell root so every child Control inherits it.
## ADR 0035 adds panel ROLES (screen vs control-bank), a primary button variant,
## and a mono face for numerics — without a drawn cockpit (ADR 0006 amended).

# Mono face for numeric readouts (ADR 0019/0035). No font ships in-repo, so this is
# a SystemFont preferring Share Tech Mono with graceful monospace fallbacks.
static var _mono: SystemFont


static func mono_font() -> SystemFont:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray([
			"Share Tech Mono", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace",
		])
	return _mono


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_DIM)

	theme.set_stylebox("panel", "PanelContainer", _panel_box())

	theme.set_stylebox("normal", "Button", _button_box(Palette.BANK_BG))
	theme.set_stylebox("hover", "Button", _button_box(Palette.PANEL_BORDER))
	theme.set_stylebox("pressed", "Button", _button_box(Palette.ACCENT.darkened(0.4)))
	theme.set_stylebox("disabled", "Button", _button_box(Palette.PANEL.darkened(0.3)))
	return theme


static func _panel_box() -> StyleBoxFlat:
	return screen_box()


## A recessed "screen" surface (readouts, the nav plot) — darker inset (ADR 0035).
static func screen_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.SCREEN_BG
	box.border_color = Palette.PANEL_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


## A raised "control bank" surface (the command clusters) — lighter, accented edge.
static func bank_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.BANK_BG
	box.border_color = Palette.ACCENT.darkened(0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


## The header strip behind a panel title — a tinted band with an accent underline.
static func header_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.HEADER_BG
	box.border_color = Palette.ACCENT.darkened(0.2)
	box.border_width_bottom = 1
	box.set_corner_radius_all(0)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	return box


## The filled-accent stylebox for a primary / commit button (ADR 0035).
static func primary_button_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Palette.ACCENT
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
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
