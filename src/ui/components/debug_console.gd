extends CanvasLayer
## Dev command console (ADR 0024), toggled by `toggle_console` (backtick). A text
## overlay that submits lines to DebugActions and shows the output; the sim keeps
## running underneath. Separate from the F3 read-only debug overlay. Dev-only —
## see DebugActions for the release-gating TODO. Debug text is exempt from tr().

const MAX_LINES := 14

var _output: Label
var _field: LineEdit
var _lines: PackedStringArray = PackedStringArray([
	"Far Horizon debug console — type 'help'. (` to toggle)",
])


func _ready() -> void:
	layer = 130  # above the F3 overlay (128)
	visible = false

	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 280.0
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	_output = Label.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(_output)

	_field = LineEdit.new()
	_field.placeholder_text = "command…"
	_field.text_submitted.connect(_on_submit)
	box.add_child(_field)

	_render()


## Use _input (pre-GUI) so backtick toggles even while the LineEdit has focus, and
## consume it so the character never lands in the field.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	visible = open
	if open:
		_field.grab_focus()
	else:
		_field.release_focus()


func _on_submit(text: String) -> void:
	var line := text.strip_edges()
	_field.clear()
	if line == "":
		return
	_push("> " + line)
	var out := DebugActions.run(line)
	if out != "":
		_push(out)
	_field.grab_focus()  # keep typing


func _push(line: String) -> void:
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_render()


func _render() -> void:
	_output.text = "\n".join(_lines)
