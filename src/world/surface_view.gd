class_name SurfaceView
extends Node2D
## The surface Nav Plot (ADR 0030): a true-scale local map of the landed body's
## surface — its sites/POIs + the generic Open Landing, the ship's surface
## position, and a plotted Move line to the selected site. The surface-side analog
## of the orrery (ADR 0016); shown only while LANDED (the shell swaps to it).
## Presentation only — reads state, emits selection, never mutates.

const OPEN_PX := 8.0
const SITE_PX := 7.0
const SHIP_PX := 10.0
const SELECT_GAP_PX := 7.0
const LABEL_SIZE := 13
const PICK_PX := 24.0
const FILL := 0.4  # fraction of the half-min screen the farthest site fills
const RING_COLOR := Color(0.35, 0.45, 0.58, 0.30)
const SHIP_TINT := Color(0.9, 0.95, 1.0)

var _system: SystemData
var _body: BodyData
var _selected_site: String = ""  # surface site picked for a Move ("" = Open Landing)
var _center: Vector2
var _px_per_su: float = 0.1
var _font: Font


func build(system: SystemData) -> void:
	_font = ThemeDB.fallback_font
	EventBus.system_changed.connect(_on_system_changed)
	EventBus.ship_context_changed.connect(_refresh_body)
	EventBus.game_state_loaded.connect(_refresh_body)
	EventBus.surface_site_selected.connect(func(id: String) -> void: _selected_site = id)
	_init_system(system)


func _on_system_changed(system_id: String) -> void:
	_init_system(TypeRegistry.get_system(system_id))


func _init_system(system: SystemData) -> void:
	_system = system
	_selected_site = ""
	_refresh_body()


## The landed body (or null when not landed) — drives the map.
func _refresh_body() -> void:
	if _system != null and GameState.ship.location == Travel.Location.LANDED:
		_body = _resolve_body(GameState.ship.location_body_id)
	else:
		_body = null
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# --- Projection (true scale, surface-centred) ---

func _recompute() -> void:
	var vp := get_viewport_rect().size
	_center = vp * 0.5
	var max_su := 100.0
	for loc: SurfaceLocationData in _body.surface_locations:
		max_su = maxf(max_su, loc.surface_position.length())
	max_su = maxf(max_su, _body.wild_touchdown.length())
	max_su = maxf(max_su, _ship_surface_pos().length())
	_px_per_su = (minf(vp.x, vp.y) * FILL) / max_su


func _to_screen(su: Vector2) -> Vector2:
	return _center + su * _px_per_su


# --- Draw ---

func _draw() -> void:
	if not visible or _body == null:
		return
	_recompute()
	# A faint reference ring at the map edge.
	draw_arc(_center, minf(get_viewport_rect().size.x, get_viewport_rect().size.y) * FILL,
		0.0, TAU, 96, RING_COLOR, 1.0, true)

	var ship_pos := _ship_surface_pos()
	# Plotted Move line to the selected site (while landed, not already moving).
	if _selected_site != _current_site_id() and not _is_moving():
		draw_line(_to_screen(ship_pos), _to_screen(_site_pos(_selected_site)), Palette.ACCENT, 1.5, true)

	_draw_site("", _body.wild_touchdown, tr("HELM_OPEN_LANDING"), true)
	for loc: SurfaceLocationData in _body.surface_locations:
		_draw_site(loc.id, loc.surface_position, tr(loc.name_key), false)

	# Ship marker.
	var at := _to_screen(ship_pos)
	draw_circle(at, SHIP_PX, SHIP_TINT)
	draw_arc(at, SHIP_PX + 3.0, 0.0, TAU, 24, SHIP_TINT, 1.0, true)


func _draw_site(id: String, su: Vector2, label: String, is_open: bool) -> void:
	var at := _to_screen(su)
	if id == _selected_site:
		draw_arc(at, SITE_PX + SELECT_GAP_PX, 0.0, TAU, 28, Palette.ACCENT, 1.5, true)
	# Open Landing is a hollow ring; named sites a filled diamond (shape, ADR 0012).
	if is_open:
		draw_arc(at, OPEN_PX, 0.0, TAU, 28, Palette.TEXT_DIM, 1.5, true)
	else:
		var pts := PackedVector2Array([
			at + Vector2(0, -SITE_PX), at + Vector2(SITE_PX, 0), at + Vector2(0, SITE_PX), at + Vector2(-SITE_PX, 0),
		])
		draw_colored_polygon(pts, Palette.TEXT)
	draw_string(_font, at + Vector2(SITE_PX + 5.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		LABEL_SIZE, Palette.TEXT)


# --- Surface position helpers ---

func _site_pos(site_id: String) -> Vector2:
	if site_id == "":
		return _body.wild_touchdown
	for loc: SurfaceLocationData in _body.surface_locations:
		if loc.id == site_id:
			return loc.surface_position
	return _body.wild_touchdown


func _current_site_id() -> String:
	return GameState.ship.surface_site_id


func _is_moving() -> bool:
	return String(GameState.ship.current_order.get("type", "")) == "surface_move"


## The ship's surface position — its site, or interpolated along an in-progress move.
func _ship_surface_pos() -> Vector2:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) == "surface_move":
		var from := _site_pos(String(order.get("from_site_id", "")))
		var to := _site_pos(String(order.get("site_id", "")))
		var total: float = maxf(1.0, float(order.get("ticks_total", 1)))
		var t := 1.0 - float(order.get("ticks_left", 0)) / total
		return from.lerp(to, clampf(t, 0.0, 1.0))
	return _site_pos(GameState.ship.surface_site_id)


# --- Input (pick a site to Move to) ---

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _body == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_viewport().get_mouse_position()
		var picked := _site_at(mouse)
		if picked != "<none>":
			EventBus.surface_site_selected.emit(picked)


## id of the site under the cursor ("" = Open Landing), or "<none>".
func _site_at(mouse: Vector2) -> String:
	var nearest := "<none>"
	var nearest_px := PICK_PX
	if mouse.distance_to(_to_screen(_body.wild_touchdown)) <= nearest_px:
		nearest_px = mouse.distance_to(_to_screen(_body.wild_touchdown))
		nearest = ""
	for loc: SurfaceLocationData in _body.surface_locations:
		var d := mouse.distance_to(_to_screen(loc.surface_position))
		if d <= nearest_px:
			nearest_px = d
			nearest = loc.id
	return nearest


func _resolve_body(body_id: String) -> BodyData:
	if _system == null:
		return null
	for body: BodyData in _system.bodies:
		if body.id == body_id:
			return body
	return null
