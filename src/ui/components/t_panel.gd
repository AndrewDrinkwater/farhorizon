class_name TPanel
extends PanelContainer
## Framed container with an optional title (ADR 0007). ADR 0035 gives it a ROLE —
## a recessed SCREEN (readouts / nav plot) or a raised CONTROL bank (button
## clusters) — and a header strip carrying the title plus a small live lamp, so a
## panel reads as a powered instrument. Add content via content(); set title/role/
## lamp after construction. Pure layout — no bindings of its own.

enum Role { SCREEN, CONTROL }

var _content: VBoxContainer
var _header: PanelContainer
var _title: Label
var _lamp: ColorRect


func _init(title_key: String = "") -> void:
	add_theme_stylebox_override("panel", TerminalTheme.screen_box())

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)

	# Header strip: a live lamp + the title (accent), on a tinted band (ADR 0035).
	_header = PanelContainer.new()
	_header.add_theme_stylebox_override("panel", TerminalTheme.header_box())
	outer.add_child(_header)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 6)
	_header.add_child(hrow)
	_lamp = ColorRect.new()
	_lamp.custom_minimum_size = Vector2(8.0, 8.0)
	_lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lamp.color = Palette.STATUS_NOMINAL
	hrow.add_child(_lamp)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Palette.ACCENT)
	hrow.add_child(_title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	# Fill the panel below the header so an expanding child (e.g. the directory's
	# scroll list) gets real height instead of collapsing to nothing.
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_content)

	_apply_title(title_key)


## The container to place child components into.
func content() -> VBoxContainer:
	return _content


## Set (or clear, with "") the panel title — the frame's boxes get their title from
## whichever console fills them (ADR 0034). No title → no header strip.
func set_title(title_key: String) -> void:
	_apply_title(title_key)


## Switch the panel role (ADR 0035): a recessed screen or a raised control bank.
func set_role(role: Role) -> void:
	add_theme_stylebox_override("panel",
		TerminalTheme.bank_box() if role == Role.CONTROL else TerminalTheme.screen_box())


## The header lamp colour — a "powered" cue; meaningful state is also carried in the
## panel content (text), never by this lamp alone (ADR 0012).
func set_lamp(color: Color) -> void:
	_lamp.color = color


func _apply_title(title_key: String) -> void:
	_title.text = tr(title_key) if title_key != "" else ""
	_header.visible = title_key != ""
