class_name TacticalView
extends Node2D
## The tactical scope (ADR 0017): a ship-centred, TRUE-SCALE local view — the
## radar to the orrery's chart plotter. The sensor range is a real circle here
## (no radial distortion); detected contacts sit inside it. Toggled with the
## orrery (key `toggle_tactical`). Presentation only — reads state, never mutates.

const SHIP_PX := 12.0
const PLANET_PX := 7.0
const MOON_PX := 4.5
const STATION_PX := 7.0
const CONTACT_PX := 6.0
const STAR_PX := 9.0
const SELECT_GAP_PX := 7.0
const LABEL_SIZE := 13
const PICK_PX := 22.0
const SCOPE_FILL := 0.42   # fraction of the half-min screen the sensor circle fills
const SCOPE_MARGIN := 1.18 # show a little beyond sensor range
const RING_COLOR := Color(0.35, 0.45, 0.58, 0.35)
const SHIP_TINT := Color(0.9, 0.95, 1.0)

var _system: SystemData
var _selected_id: String = ""
var _center: Vector2
var _px_per_wu: float = 0.1
var _font: Font


func build(system: SystemData) -> void:
	_system = system
	_font = ThemeDB.fallback_font
	EventBus.nav_target_selected.connect(func(id: String) -> void: _selected_id = id)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# --- Projection (true scale, ship-centred) ---

func _recompute() -> void:
	var vp := get_viewport_rect().size
	_center = vp * 0.5
	var range_wu: float = maxf(1.0, GameState.ship.sensor_range * SCOPE_MARGIN)
	_px_per_wu = (minf(vp.x, vp.y) * SCOPE_FILL) / range_wu


func _to_screen(real_pos: Vector2) -> Vector2:
	return _center + (real_pos - GameState.ship.position) * _px_per_wu


# --- Draw ---

func _draw() -> void:
	if _system == null:
		return
	_recompute()
	# Sensor range ring (the real circle) + a half-range guide.
	var radius := GameState.ship.sensor_range * _px_per_wu
	draw_arc(_center, radius, 0.0, TAU, 96, RING_COLOR, 1.5, true)
	draw_arc(_center, radius * 0.5, 0.0, TAU, 80, Color(RING_COLOR, 0.18), 1.0, true)

	_draw_course()
	for body: BodyData in _system.bodies:
		_draw_body(body, _to_screen(body.position))
	for contact: ContactData in _system.contacts:
		if GameState.contacts.tier_of(contact.id) != Sensors.Tier.UNDETECTED:
			var at := _to_screen(contact.position)
			_diamond(at, CONTACT_PX, contact.tint, false)
			draw_circle(at, 1.5, contact.tint)
			_label(at + Vector2(CONTACT_PX + 4.0, 4.0), tr(contact.name_key), Palette.TEXT_DIM)
	_draw_ship()


func _draw_body(body: BodyData, at: Vector2) -> void:
	if body.id == _selected_id:
		draw_arc(at, _marker_px(body.kind) + SELECT_GAP_PX, 0.0, TAU, 32, Palette.ACCENT, 1.5, true)
	match body.kind:
		BodyData.Kind.STAR:
			draw_circle(at, STAR_PX, body.tint)
		BodyData.Kind.STATION:
			_diamond(at, STATION_PX, body.tint, true)
		BodyData.Kind.MOON:
			draw_circle(at, MOON_PX, body.tint)
		_:
			draw_circle(at, PLANET_PX, body.tint)
	_label(at + Vector2(_marker_px(body.kind) + 4.0, 4.0), tr(body.name_key), Palette.TEXT)


func _draw_course() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		return
	var target: BodyData = _find(String(order.get("target_id", "")))
	if target != null:
		draw_line(_center, _to_screen(target.position), Palette.ACCENT, 1.5, true)


func _draw_ship() -> void:
	var fwd := Vector2.from_angle(GameState.ship.heading)
	var side := fwd.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		_center + fwd * 9.0, _center - fwd * 6.0 + side * 6.0, _center - fwd * 6.0 - side * 6.0,
	]), SHIP_TINT)


# --- Helpers ---

func _diamond(at: Vector2, r: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array([
		at + Vector2(0.0, -r), at + Vector2(r, 0.0), at + Vector2(0.0, r), at + Vector2(-r, 0.0),
	])
	if filled:
		draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([at + Vector2(0.0, -r)]), Color.WHITE if filled else color, 1.0, true)


func _label(at: Vector2, text: String, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, color)


func _marker_px(kind: int) -> float:
	match kind:
		BodyData.Kind.STAR:
			return STAR_PX
		BodyData.Kind.MOON:
			return MOON_PX
		_:
			return PLANET_PX


func _find(id: String) -> BodyData:
	for body: BodyData in _system.bodies:
		if body.id == id:
			return body
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _system == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := get_viewport().get_mouse_position()
		var nearest_id := ""
		var nearest_px := PICK_PX
		for body: BodyData in _system.bodies:
			var d := mouse.distance_to(_to_screen(body.position))
			if d <= nearest_px:
				nearest_px = d
				nearest_id = body.id
		if nearest_id != "":
			EventBus.nav_target_selected.emit(nearest_id)
