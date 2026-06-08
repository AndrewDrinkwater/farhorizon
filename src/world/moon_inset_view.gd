class_name MoonInsetView
extends Control
## Focus inset (ADR 0022): a picture-in-picture panel that opens on a moon-bearing
## planet (EventBus.nav_focus_requested) and shows its moons spread out — the room
## the compressed orrery can't give them — each on its own orbit ring and clickable
## to target (re-using the body course/scan pipeline). Closed with the ✕ or by
## focusing nothing. Presentation only: reads state, emits selection, never mutates.

const SIZE := Vector2(320.0, 300.0)
const TOP_MARGIN := 70.0   # below the shell time controls
const TITLE_SIZE := 15
const LABEL_SIZE := 12
const PLANET_PX := 10.0
const MOON_PX := 6.0
const SELECT_GAP_PX := 6.0
const PICK_PX := 20.0
const RING_COLOR := Color(0.35, 0.45, 0.58, 0.30)

var _system: SystemData
var _planet: BodyData
var _moons: Array[BodyData] = []
var _selected_id: String = ""
var _center: Vector2          # content centre, local coords
var _inset_radius: float = 1.0
var _max_offset: float = 1.0
var _close_rect: Rect2
var _font: Font


func build(system: SystemData) -> void:
	_system = system
	_font = ThemeDB.fallback_font
	# Top-centre, anchored over the Nav Plot; mouse_filter STOP eats clicks so the
	# orrery beneath doesn't also treat them as picks/waypoints.
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -SIZE.x * 0.5
	offset_right = SIZE.x * 0.5
	offset_top = TOP_MARGIN
	offset_bottom = TOP_MARGIN + SIZE.y
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	EventBus.nav_focus_requested.connect(_on_focus_requested)
	EventBus.nav_target_selected.connect(func(id: String) -> void: _selected_id = id)


func _on_focus_requested(body_id: String) -> void:
	_planet = _find_body(body_id)
	_moons = _moons_of(body_id)
	if _planet == null or _moons.is_empty():
		return
	_max_offset = 1.0
	for moon: BodyData in _moons:
		_max_offset = maxf(_max_offset, (moon.position - _planet.position).length())
	visible = true
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# --- Draw (local coords) ---

func _draw() -> void:
	if not visible or _planet == null:
		return
	_inset_radius = minf(SIZE.x, SIZE.y) * 0.5 - 34.0
	_center = Vector2(SIZE.x * 0.5, SIZE.y * 0.5 + 12.0)

	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PANEL, true)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PANEL_BORDER, false, 1.0)
	draw_string(_font, Vector2(10.0, 22.0), tr(_planet.name_key),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TITLE_SIZE, Palette.TEXT)

	# Close control (✕) top-right.
	_close_rect = Rect2(SIZE.x - 24.0, 6.0, 18.0, 18.0)
	draw_string(_font, _close_rect.position + Vector2(4.0, 14.0), "✕",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TITLE_SIZE, Palette.TEXT_DIM)

	# Moon orbit rings + the parent + the moons.
	draw_circle(_center, PLANET_PX, _planet.tint)
	for moon: BodyData in _moons:
		var at := _place(moon)
		draw_arc(_center, _center.distance_to(at), 0.0, TAU, 48, RING_COLOR, 1.0, true)
		if moon.id == _selected_id:
			draw_arc(at, MOON_PX + SELECT_GAP_PX, 0.0, TAU, 24, Palette.ACCENT, 1.5, true)
		draw_circle(at, MOON_PX, moon.tint)
		draw_string(_font, at + Vector2(MOON_PX + 4.0, 4.0), tr(moon.name_key),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, Palette.TEXT)


func _place(moon: BodyData) -> Vector2:
	return OrreryProjection.project_satellite(
		moon.position - _planet.position, _center, _inset_radius, _max_offset)


# --- Input (local coords via _gui_input; the panel consumes the click) ---

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if _close_rect.has_point(p):
		_close()
		accept_event()
		return
	var picked := _moon_at(p)
	if picked != "":
		EventBus.nav_target_selected.emit(picked)  # moons are bodies — normal targeting
	accept_event()


func _moon_at(local_pos: Vector2) -> String:
	var nearest_id := ""
	var nearest_px := PICK_PX
	for moon: BodyData in _moons:
		var d := local_pos.distance_to(_place(moon))
		if d <= nearest_px:
			nearest_px = d
			nearest_id = moon.id
	return nearest_id


func _close() -> void:
	visible = false
	EventBus.nav_focus_closed.emit()


# --- Lookups ---

func _find_body(id: String) -> BodyData:
	for body: BodyData in _system.bodies:
		if body.id == id:
			return body
	return null


func _moons_of(parent_id: String) -> Array[BodyData]:
	var out: Array[BodyData] = []
	for body: BodyData in _system.bodies:
		if body.kind == BodyData.Kind.MOON and body.parent_id == parent_id:
			out.append(body)
	return out
