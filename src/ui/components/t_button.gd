class_name TButton
extends Button
## Command button (ADR 0007): on press it invokes the supplied callable, which
## emits an intent/order on EventBus. The button never mutates state itself.

var _on_press: Callable


## Configure with a tr() label key and the callable to run on press. Returns self
## for fluent construction.
func setup(label_key: String, on_press: Callable) -> TButton:
	text = tr(label_key)
	_on_press = on_press
	pressed.connect(_emit)
	return self


## Like setup() but with already-resolved/dynamic text (e.g. a composed directory
## row), not a tr() key. The caller localizes the text.
func setup_text(label: String, on_press: Callable) -> TButton:
	text = label
	_on_press = on_press
	pressed.connect(_emit)
	return self


## Mark this as the primary / commit action (ADR 0035): a filled-accent, heavier
## button — used for the one commit per context (Engage; Land / Dock). Dark text on
## the accent fill; a muted fill when disabled so it doesn't read as live.
func make_primary() -> TButton:
	add_theme_stylebox_override("normal", TerminalTheme.primary_button_box(Palette.ACCENT.darkened(0.15)))
	add_theme_stylebox_override("hover", TerminalTheme.primary_button_box(Palette.ACCENT))
	add_theme_stylebox_override("pressed", TerminalTheme.primary_button_box(Palette.ACCENT.darkened(0.35)))
	add_theme_stylebox_override("disabled", TerminalTheme.primary_button_box(Palette.PANEL.darkened(0.2)))
	add_theme_color_override("font_color", Palette.BG)
	add_theme_color_override("font_hover_color", Palette.BG)
	add_theme_color_override("font_pressed_color", Palette.BG)
	add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
	return self


func _emit() -> void:
	if _on_press.is_valid():
		_on_press.call()
