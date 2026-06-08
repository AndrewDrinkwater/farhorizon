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
const TIME_COLOR := Palette.STATUS_NOMINAL  # isochrone rings (ADR 0019); paired with a label
const ISOCHRONE_RING_COLOR := Color(Palette.STATUS_NOMINAL, 0.30)
## Durations (in-game minutes) drawn as isochrone rings for the selected burn.
## Rings that fall outside the visible scope are skipped — at a fast burn only
## the near ones show, at a slow burn more do. Tuning (step-10 feel pass).
const ISOCHRONE_TICKS: Array[int] = [10, 20, 30, 60, 120]

var _system: SystemData
var _selected_id: String = ""
var _selected_point: Vector2 = Vector2.ZERO
var _has_point_sel: bool = false  # a free-space waypoint is selected (ADR 0020)
var _center: Vector2
var _px_per_wu: float = 0.1
var _burn: int = FlightMath.Burn.STANDARD  # mirrors the Helm burn selector (ADR 0019)
var _max_ring_px: float = 0.0
var _font: Font


func build(system: SystemData) -> void:
	_system = system
	_font = ThemeDB.fallback_font
	EventBus.nav_target_selected.connect(_on_target_selected)
	EventBus.nav_point_selected.connect(_on_point_selected)
	EventBus.nav_burn_changed.connect(func(burn: int) -> void: _burn = burn)


func _on_target_selected(id: String) -> void:
	_selected_id = id
	_has_point_sel = false


func _on_point_selected(point: Vector2) -> void:
	_selected_point = point
	_has_point_sel = true
	_selected_id = ""


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# --- Projection (true scale, ship-centred) ---

func _recompute() -> void:
	var vp := get_viewport_rect().size
	_center = vp * 0.5
	var range_wu: float = maxf(1.0, GameState.ship.sensor_range * SCOPE_MARGIN)
	_px_per_wu = (minf(vp.x, vp.y) * SCOPE_FILL) / range_wu
	_max_ring_px = minf(vp.x, vp.y) * 0.5 - 12.0  # keep a ring + its label on-screen


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

	_draw_isochrones()
	_draw_course()
	for body: BodyData in _system.bodies:
		_draw_body(body, _to_screen(body.position))
	for contact: ContactData in _system.contacts:
		var tier := GameState.contacts.tier_of(contact.id)
		if tier == Sensors.Tier.UNDETECTED:
			continue
		var identified := tier == Sensors.Tier.IDENTIFIED
		var at := _to_screen(contact.position)
		if contact.id == _selected_id:
			draw_arc(at, CONTACT_PX + SELECT_GAP_PX, 0.0, TAU, 32, Palette.ACCENT, 1.5, true)
		# Shape carries identity (ADR 0012): hollow = unscanned BLIP, filled = identified.
		_diamond(at, CONTACT_PX, contact.tint, identified)
		draw_circle(at, 1.5, contact.tint)
		var label := tr(contact.name_key) if identified else tr("NAV_CONTACT_UNKNOWN")
		_label(at + Vector2(CONTACT_PX + 4.0, 4.0), label, Palette.TEXT_DIM)
	if _has_point_sel:
		_draw_waypoint(_to_screen(_selected_point))
	_draw_ship()


## A free-space waypoint marker: a small ring + crosshair in the accent colour.
func _draw_waypoint(at: Vector2) -> void:
	draw_arc(at, 6.0, 0.0, TAU, 24, Palette.ACCENT, 1.5, true)
	draw_line(at + Vector2(-9.0, 0.0), at + Vector2(9.0, 0.0), Palette.ACCENT, 1.0, true)
	draw_line(at + Vector2(0.0, -9.0), at + Vector2(0.0, 9.0), Palette.ACCENT, 1.0, true)


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


## Isochrone rings (ADR 0019): concentric "how long to anything" circles for the
## selected burn. True-scale + ship-centred, so reach is a clean circle here (on
## the star-centred orrery it would warp, like the sensor bubble — hence rings
## live on the scope, labels on the orrery). Each ring carries its duration label,
## so the time channel isn't colour alone (ADR 0012).
func _draw_isochrones() -> void:
	for ticks: int in ISOCHRONE_TICKS:
		var ring_px := FlightMath.reach_wu(_burn, ticks) * _px_per_wu
		if ring_px < 6.0 or ring_px > _max_ring_px:
			continue  # too small to read, or off the scope at this burn
		draw_arc(_center, ring_px, 0.0, TAU, 96, ISOCHRONE_RING_COLOR, 1.0, true)
		# Label up-and-right along the ring (consistent bearing, off the body field).
		var at := _center + Vector2(0.7071, -0.7071) * ring_px
		_label(at + Vector2(2.0, -2.0), _format_duration(ticks), TIME_COLOR)


func _draw_course() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		return
	# True scale → a straight real course is a straight line to the destination
	# (body position, or the frozen dest for a contact / free point — ADR 0020).
	var target: BodyData = _find(String(order.get("target_id", "")))
	var dest: Vector2 = target.position if target != null else order.get("dest", GameState.ship.position)
	draw_line(_center, _to_screen(dest), Palette.ACCENT, 1.5, true)


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


## Compact duration from a tick count (one tick = one in-game minute): "1h 09m"
## above the hour, "45m" below it. tr() so it stays localizable (ADR 0010).
func _format_duration(ticks: int) -> String:
	var h := ticks / 60
	var m := ticks % 60
	if h > 0:
		return tr("NAV_DURATION_HM").format({"hours": h, "mins": "%02d" % m})
	return tr("NAV_DURATION_M").format({"mins": m})


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
		for contact: ContactData in _system.contacts:
			if GameState.contacts.tier_of(contact.id) == Sensors.Tier.UNDETECTED:
				continue
			var d := mouse.distance_to(_to_screen(contact.position))
			if d <= nearest_px:
				nearest_px = d
				nearest_id = contact.id
		if nearest_id != "":
			EventBus.nav_target_selected.emit(nearest_id)
		else:
			# Empty space → drop a free-space waypoint (true-scale inverse, ADR 0020).
			EventBus.nav_point_selected.emit(GameState.ship.position + (mouse - _center) / _px_per_wu)
