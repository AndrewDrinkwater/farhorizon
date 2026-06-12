class_name ConsoleFrame
extends Control
## The ship-OS layout frame (ADR 0034). The frame OWNS five fixed-size boxes; a
## console only sets each box's title and pours content into it — the boxes never
## change size or position, so every console reads identically and the console-select
## bar above the control panel never shifts. Empty boxes (e.g. Ship's bottom row)
## still render at full size.
##
##   ┌──────────── top bar (shell) ────────────┐
##   │            · notification toast ·         │
##   │ LEFT ▏                            ▕ RIGHT │   ← collapsible drawers (fixed width)
##   │ draw ▏          main view         ▕ draw  │
##   │            [ console-select tabs ]        │
##   │      [ secondary | control | info ]       │   ← bottom band (fixed boxes)
##   └──────────────────────────────────────────┘
##
## Explicit anchors, not set_anchors_preset (the preset collapsed the frame width in
## this engine). The centre is mouse-transparent so clicks reach the stage behind.

const TOP_PAD: float = 80.0   # clearance below the shell top bar (not tucked under it)
const EDGE: float = 12.0      # outer margin + inter-region gap
const SIDE_WIDTH: float = 360.0   # drawer box width
const HANDLE_W: float = 24.0   # drawer handle thickness (fits a vertical label)
const HANDLE_H: float = 150.0  # drawer handle tab height (a labelled, grabbable pull)
const CONTROL_W: float = 820.0  # centre command box width
const BOX_H: float = 224.0      # fixed height shared by all three bottom boxes

var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _left_box: TPanel
var _right_box: TPanel
var _secondary: TPanel
var _control: TPanel
var _info: TPanel
var _centre: Control
var _toast: VBoxContainer
var _console_select: HBoxContainer
var _left_handle: Button
var _right_handle: Button
var _left_label: Label   # vertical drawer-tab label (arrow + name)
var _right_label: Label
var _left_name: String = ""
var _right_name: String = ""


func _ready() -> void:
	# Explicit anchors, not set_anchors_preset: the preset leaves this at the wrong
	# size in this engine, collapsing the frame width.
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = EDGE
	col.offset_right = -EDGE
	col.offset_top = TOP_PAD
	col.offset_bottom = -EDGE
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", int(EDGE))
	add_child(col)

	# Body row: [left handle][left drawer][centre — stage shows through][right][handle]
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", int(EDGE))
	col.add_child(body)

	_left_handle = _make_handle(true)
	body.add_child(_left_handle)
	_left_col = _make_drawer_column()
	body.add_child(_left_col)
	_left_box = _make_box(Vector2(SIDE_WIDTH, 0.0), true)
	_left_col.add_child(_left_box)

	_centre = Control.new()
	_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE  # stage clicks pass through
	body.add_child(_centre)

	_right_col = _make_drawer_column()
	body.add_child(_right_col)
	_right_box = _make_box(Vector2(SIDE_WIDTH, 0.0), true)
	_right_col.add_child(_right_box)
	_right_handle = _make_handle(false)
	body.add_child(_right_handle)

	# Console-select bar (shell mounts the tabs here): centred, just above the band.
	_console_select = HBoxContainer.new()
	_console_select.alignment = BoxContainer.ALIGNMENT_CENTER
	_console_select.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_console_select.add_theme_constant_override("separation", 4)
	_console_select.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_console_select)

	# Bottom band of three FIXED boxes: secondary (left) · control (centre) · info (right).
	var band := HBoxContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_constant_override("separation", int(EDGE))
	col.add_child(band)
	_secondary = _make_box(Vector2(SIDE_WIDTH, BOX_H), false)
	band.add_child(_secondary)
	band.add_child(_spacer())
	_control = _make_box(Vector2(CONTROL_W, BOX_H), false)
	band.add_child(_control)
	band.add_child(_spacer())
	_info = _make_box(Vector2(SIDE_WIDTH, BOX_H), false)
	band.add_child(_info)

	# Notification toast: floats top-centre over the main view, content-sized.
	_toast = VBoxContainer.new()
	_toast.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.0
	_toast.offset_top = TOP_PAD + EDGE
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_END
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	# Drawers start collapsed (just the handle tab protruding); clicking extends them.
	_left_col.visible = false
	_right_col.visible = false
	_update_handles()


## A collapsible drawer column holding a fixed-width box.
func _make_drawer_column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## A fixed-size titled box (the frame owns these; consoles set title + add content).
## `fill` makes it stretch vertically (drawers); band boxes bottom-align instead.
func _make_box(min_size: Vector2, fill: bool) -> TPanel:
	var panel := TPanel.new("")
	panel.custom_minimum_size = min_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if fill else Control.SIZE_SHRINK_END
	return panel


## An expanding, click-through gap that pins the band's side boxes to the corners.
func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## A thin edge handle (drawer pull) that collapses / expands its drawer; always
## shown (the drawer box always exists). Carries a vertical label naming the drawer
## plus an arrow pointing the way it will move (shape + label, ADR 0012).
func _make_handle(is_left: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(HANDLE_W, HANDLE_H)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.pressed.connect(_toggle_side.bind(is_left))
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.rotation_degrees = -90.0
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Palette.TEXT_DIM)
	b.add_child(lbl)
	b.resized.connect(_recenter_handle.bind(b, lbl))
	lbl.resized.connect(_recenter_handle.bind(b, lbl))
	if is_left:
		_left_label = lbl
	else:
		_right_label = lbl
	return b


## Keep the rotated label centred in its tab as either resizes.
func _recenter_handle(b: Button, lbl: Label) -> void:
	lbl.pivot_offset = lbl.size * 0.5
	lbl.position = (b.size - lbl.size) * 0.5


func _toggle_side(is_left: bool) -> void:
	var column := _left_col if is_left else _right_col
	column.visible = not column.visible
	_update_handles()


## Name + arrow on each tab: the arrow points the way the drawer will move (shape
## channel), the name says what's behind it (ADR 0012/0035).
func _update_handles() -> void:
	_left_label.text = "%s  %s" % ["‹" if _left_col.visible else "›", _left_name]
	_right_label.text = "%s  %s" % ["›" if _right_col.visible else "‹", _right_name]


## A console names its drawers so the tabs read (e.g. "Nav", "Target").
func set_drawer_label(is_left: bool, text: String) -> void:
	if is_left:
		_left_name = text
	else:
		_right_name = text
	_update_handles()


## --- Slots: the fixed boxes. Consoles set_title() + add into content(). ---

func left() -> TPanel:
	return _left_box


func right() -> TPanel:
	return _right_box


## Bottom-left box — secondary / compose controls.
func secondary() -> TPanel:
	return _secondary


## Bottom-centre box — the primary command panel ("where I give orders").
func control() -> TPanel:
	return _control


## Bottom-right box — a compact live-info panel.
func info() -> TPanel:
	return _info


## Top-centre floating notification region (acks, transition indicators).
func toast() -> VBoxContainer:
	return _toast


## The centred bar just above the band — the shell mounts its console tabs here.
func console_select() -> HBoxContainer:
	return _console_select


## The mouse-transparent centre Control over the main view.
func centre() -> Control:
	return _centre
