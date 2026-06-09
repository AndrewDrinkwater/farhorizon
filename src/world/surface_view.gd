class_name SurfaceView
extends Node2D
## The surface Nav Plot (ADR 0030): a rectangular geographic map of a landable
## body's surface — its sites/POIs + the generic Open Landing area, the ship's
## surface position (smoothly interpolated across a Move via the sub-tick
## fraction), and a plotted line to the picked destination. Click a site or any
## point to pick a touchdown / move target. Shown while LANDED, or while orbiting
## a landable body in Open-Landing pick mode (the shell swaps to it). Presentation
## only — reads state, emits selection, never mutates.

const SITE_PX := 7.0
const OPEN_PX := 8.0
const SHIP_PX := 9.0
const SELECT_GAP_PX := 7.0
const LABEL_SIZE := 13
const PICK_PX := 22.0
const FRAME_COLOR := Color(0.35, 0.45, 0.58, 0.45)
const GRID_COLOR := Color(0.35, 0.45, 0.58, 0.12)
const SHIP_TINT := Color(0.9, 0.95, 1.0)
const MAP_MARGIN := 0.85  # su box fills this fraction of the frame

var _system: SystemData
var _body: BodyData
var _selected_site: String = ""        # picked named site ("" = Open Landing) for the highlight
var _selected_point: Vector2 = Vector2.ZERO  # picked free point (su)
var _has_point_sel: bool = false       # a free point is the current pick
var _has_selection: bool = false       # the captain has picked something this session
var _rect: Rect2
var _su_origin: Vector2
var _px_per_su: float = 1.0
var _font: Font


func build(system: SystemData) -> void:
	_font = ThemeDB.fallback_font
	EventBus.system_changed.connect(_on_system_changed)
	EventBus.ship_context_changed.connect(_refresh_body)
	EventBus.game_state_loaded.connect(_refresh_body)
	EventBus.surface_site_selected.connect(_on_site_selected)
	EventBus.surface_point_selected.connect(_on_point_selected)
	_init_system(system)


func _on_system_changed(system_id: String) -> void:
	_init_system(TypeRegistry.get_system(system_id))


func _init_system(system: SystemData) -> void:
	_system = system
	_selected_site = ""
	_has_point_sel = false
	_has_selection = false
	_refresh_body()


func _on_site_selected(site_id: String) -> void:
	_selected_site = site_id
	_has_point_sel = false
	_has_selection = true


func _on_point_selected(point: Vector2) -> void:
	_selected_point = point
	_has_point_sel = true
	_selected_site = ""
	_has_selection = true


## The landable body this map shows — the one we're landed at or orbiting.
func _refresh_body() -> void:
	if _system != null and (GameState.ship.location == Travel.Location.LANDED \
			or GameState.ship.location == Travel.Location.HOLDING):
		var body := _resolve_body(GameState.ship.location_body_id)
		_body = body if (body != null and body.landable) else null
	else:
		_body = null
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# --- Rectangular map projection (su → screen, uniform scale, fitted) ---

func _recompute() -> void:
	var vp := get_viewport_rect().size
	# A centred rectangle clear of the corner Helm panels.
	var left := vp.x * 0.22
	var top := 64.0
	_rect = Rect2(left, top, vp.x - left * 2.0, maxf(200.0, vp.y - top - 312.0))
	# Fit the su bounding box of every point into the frame, uniform scale, centred.
	var lo := Vector2(-100.0, -100.0)
	var hi := Vector2(100.0, 100.0)
	for loc: SurfaceLocationData in _body.surface_locations:
		lo = lo.min(loc.surface_position)
		hi = hi.max(loc.surface_position)
	lo = lo.min(_body.wild_touchdown)
	hi = hi.max(_body.wild_touchdown)
	_su_origin = (lo + hi) * 0.5
	var span := (hi - lo)
	var scale_x := _rect.size.x / maxf(1.0, span.x)
	var scale_y := _rect.size.y / maxf(1.0, span.y)
	_px_per_su = minf(scale_x, scale_y) * MAP_MARGIN


func _to_screen(su: Vector2) -> Vector2:
	return _rect.get_center() + (su - _su_origin) * _px_per_su


func _to_su(screen: Vector2) -> Vector2:
	return _su_origin + (screen - _rect.get_center()) / _px_per_su


# --- Draw ---

func _draw() -> void:
	if not visible or _body == null:
		return
	_recompute()
	draw_rect(_rect, GRID_COLOR, true)
	draw_rect(_rect, FRAME_COLOR, false, 1.5)

	# Sites + the generic Open Landing area.
	_draw_open_landing()
	for loc: SurfaceLocationData in _body.surface_locations:
		_draw_site(loc)

	var landed := GameState.ship.location == Travel.Location.LANDED
	if landed:
		# Plotted Move line + the ship, smoothly interpolated across a move.
		var ship_pos := _ship_surface_pos()
		if _has_pick() and not _is_moving():
			draw_line(_to_screen(ship_pos), _to_screen(_pick_pos()), Palette.ACCENT, 1.5, true)
		var at := _to_screen(ship_pos)
		draw_circle(at, SHIP_PX, SHIP_TINT)
		draw_arc(at, SHIP_PX + 3.0, 0.0, TAU, 24, SHIP_TINT, 1.0, true)
	else:
		# Orbiting in pick mode: show a touchdown crosshair at the chosen spot.
		if _has_pick():
			_draw_crosshair(_to_screen(_pick_pos()))


func _draw_open_landing() -> void:
	var at := _to_screen(_body.wild_touchdown)
	if _has_selection and _selected_site == "" and not _has_point_sel:
		draw_arc(at, OPEN_PX + SELECT_GAP_PX, 0.0, TAU, 24, Palette.ACCENT, 1.5, true)
	draw_arc(at, OPEN_PX, 0.0, TAU, 28, Palette.TEXT_DIM, 1.5, true)
	draw_string(_font, at + Vector2(OPEN_PX + 5.0, 4.0), tr("HELM_OPEN_LANDING"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, Palette.TEXT_DIM)


func _draw_site(loc: SurfaceLocationData) -> void:
	var at := _to_screen(loc.surface_position)
	if loc.id == _selected_site:
		draw_arc(at, SITE_PX + SELECT_GAP_PX, 0.0, TAU, 28, Palette.ACCENT, 1.5, true)
	var pts := PackedVector2Array([
		at + Vector2(0, -SITE_PX), at + Vector2(SITE_PX, 0), at + Vector2(0, SITE_PX), at + Vector2(-SITE_PX, 0),
	])
	draw_colored_polygon(pts, Palette.TEXT)
	draw_string(_font, at + Vector2(SITE_PX + 5.0, 4.0), tr(loc.name_key),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, Palette.TEXT)


func _draw_crosshair(at: Vector2) -> void:
	draw_arc(at, 6.0, 0.0, TAU, 24, Palette.ACCENT, 1.5, true)
	draw_line(at + Vector2(-9, 0), at + Vector2(9, 0), Palette.ACCENT, 1.0, true)
	draw_line(at + Vector2(0, -9), at + Vector2(0, 9), Palette.ACCENT, 1.0, true)


# --- Surface position helpers ---

func _has_pick() -> bool:
	return _has_selection


func _pick_pos() -> Vector2:
	if _has_point_sel:
		return _selected_point
	return _site_pos(_selected_site)


func _site_pos(site_id: String) -> Vector2:
	if site_id == "":
		return _body.wild_touchdown
	for loc: SurfaceLocationData in _body.surface_locations:
		if loc.id == site_id:
			return loc.surface_position
	return _body.wild_touchdown


func _is_moving() -> bool:
	return String(GameState.ship.current_order.get("type", "")) == "surface_move"


## Ship surface position — the live field, advanced per-frame during a move by the
## FlightController (smooth, like the holding orbit; ADR 0030).
func _ship_surface_pos() -> Vector2:
	return GameState.ship.surface_position


# --- Input (pick a site or a free point) ---

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _body == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_viewport().get_mouse_position()
		if not _rect.has_point(mouse):
			return
		var site := _site_at(mouse)
		if site == "<none>":
			EventBus.surface_point_selected.emit(_to_su(mouse))  # free touchdown / move point
		else:
			EventBus.surface_site_selected.emit(site)  # a named site or Open Landing ("")


## id of the site/Open-Landing under the cursor, or "<none>" for empty ground.
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
