class_name OrreryView
extends Node2D
## The Helm Nav Plot, drawn as an orrery (ADR 0016/0018): a screen-space
## instrument that projects the system's real positions through OrreryProjection
## — radius log-compressed onto rings, bearing exact — so the whole system reads
## on one screen. Charted bodies (incl. moons) always shown; transient contacts
## shown only while detected (ADR 0017). Clicking a charted body targets it
## (emits nav_target_selected). Presentation only — reads state, never mutates.

const STAR_PX := 11.0
const PLANET_PX := 7.0
const MOON_PX := 4.5
const STATION_PX := 7.0
const CONTACT_PX := 6.0
const SELECT_GAP_PX := 7.0
const LABEL_SIZE := 13
const PICK_PX := 22.0
const COURSE_SAMPLES := 20
const RING_COLOR := Color(0.35, 0.45, 0.58, 0.30)
const SHIP_TINT := Color(0.9, 0.95, 1.0)

var _system: SystemData
var _params: OrreryParams
var _star_pos: Vector2 = Vector2.ZERO
var _by_id: Dictionary = {}        # id -> BodyData
var _selected_id: String = ""
var _font: Font


func build(system: SystemData) -> void:
	_system = system
	_font = ThemeDB.fallback_font
	for body: BodyData in system.bodies:
		_by_id[body.id] = body
		if body.kind == BodyData.Kind.STAR:
			_star_pos = body.position
	_rebuild_params()
	EventBus.nav_target_selected.connect(_on_target_selected)
	EventBus.contact_detected.connect(_on_contacts_changed.unbind(1))
	EventBus.contact_lost.connect(_on_contacts_changed.unbind(1))


func _rebuild_params() -> void:
	var vp := get_viewport_rect().size
	_params = OrreryParams.new()
	_params.center = vp * 0.5
	_params.ring_inner = 64.0
	_params.ring_outer = minf(vp.x, vp.y) * 0.42


func _process(_delta: float) -> void:
	queue_redraw()  # ship moves; contacts wink; cheap (one instrument)


func _on_target_selected(target_id: String) -> void:
	_selected_id = target_id


func _on_contacts_changed() -> void:
	queue_redraw()


# --- Projection ---

## id -> projected screen position for every charted body (moons via the parent).
func _project_bodies() -> Dictionary:
	var proj: Dictionary = {}
	for body: BodyData in _system.bodies:
		if body.kind != BodyData.Kind.MOON:
			proj[body.id] = OrreryProjection.project(body.position - _star_pos, _params)
	for body: BodyData in _system.bodies:
		if body.kind == BodyData.Kind.MOON:
			var parent: BodyData = _by_id.get(body.parent_id, null)
			var parent_proj: Vector2 = proj.get(body.parent_id, _params.center)
			var parent_pos: Vector2 = parent.position if parent != null else _star_pos
			proj[body.id] = OrreryProjection.project_child(body.position - parent_pos, parent_proj, _params)
	return proj


func _project_real(real_pos: Vector2) -> Vector2:
	return OrreryProjection.project(real_pos - _star_pos, _params)


# --- Draw ---

func _draw() -> void:
	if _system == null:
		return
	var proj := _project_bodies()
	_draw_rings(proj)
	_draw_course()
	for body: BodyData in _system.bodies:
		_draw_body(body, proj[body.id])
	_draw_contacts()
	_draw_ship()


func _draw_rings(proj: Dictionary) -> void:
	for body: BodyData in _system.bodies:
		if body.kind == BodyData.Kind.STAR or body.kind == BodyData.Kind.MOON:
			continue
		var radius: float = (proj[body.id] - _params.center).length()
		draw_arc(_params.center, radius, 0.0, TAU, 96, RING_COLOR, 1.0, true)


func _draw_body(body: BodyData, at: Vector2) -> void:
	if body.id == _selected_id:
		draw_arc(at, _marker_px(body.kind) + SELECT_GAP_PX, 0.0, TAU, 32, Palette.ACCENT, 1.5, true)
	match body.kind:
		BodyData.Kind.STAR:
			draw_circle(at, STAR_PX, body.tint)
			draw_arc(at, STAR_PX + 4.0, 0.0, TAU, 40, body.tint, 1.5, true)
		BodyData.Kind.STATION:
			_draw_diamond(at, STATION_PX, body.tint, true)
		BodyData.Kind.MOON:
			draw_circle(at, MOON_PX, body.tint)
		_:
			draw_circle(at, PLANET_PX, body.tint)
	_draw_label(at + Vector2(_marker_px(body.kind) + 4.0, 4.0), tr(body.name_key), Palette.TEXT)


func _draw_contacts() -> void:
	for contact: ContactData in _system.contacts:
		if GameState.contacts.tier_of(contact.id) == Sensors.Tier.UNDETECTED:
			continue
		var at := _project_real(contact.position)
		# Distinct from bodies: a hollow diamond with a centre dot (shape, not colour).
		_draw_diamond(at, CONTACT_PX, contact.tint, false)
		draw_circle(at, 1.5, contact.tint)
		_draw_label(at + Vector2(CONTACT_PX + 4.0, 4.0), tr(contact.name_key), Palette.TEXT_DIM)


func _draw_course() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		return
	var target: BodyData = _by_id.get(String(order.get("target_id", "")), null)
	if target == null:
		return
	var prev := _project_real(GameState.ship.position)
	for i in range(1, COURSE_SAMPLES + 1):
		var t := float(i) / float(COURSE_SAMPLES)
		var p := _project_real(GameState.ship.position.lerp(target.position, t))
		draw_line(prev, p, Palette.ACCENT, 1.5, true)
		prev = p
	draw_arc(_project_real(target.position), _marker_px(target.kind) + 5.0, 0.0, TAU, 24,
		Palette.ACCENT, 1.0, true)


func _draw_ship() -> void:
	var at := _project_real(GameState.ship.position)
	var facing := _ship_facing()
	var fwd := Vector2.from_angle(facing)
	var side := fwd.orthogonal()
	var tri := PackedVector2Array([
		at + fwd * 9.0, at - fwd * 6.0 + side * 6.0, at - fwd * 6.0 - side * 6.0,
	])
	draw_colored_polygon(tri, SHIP_TINT)


func _ship_facing() -> float:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) == "course":
		var target: BodyData = _by_id.get(String(order.get("target_id", "")), null)
		if target != null:
			var dir := _project_real(target.position) - _project_real(GameState.ship.position)
			if dir.length() > 0.5:
				return dir.angle()
	return GameState.ship.heading


# --- Helpers ---

func _draw_diamond(at: Vector2, r: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array([
		at + Vector2(0.0, -r), at + Vector2(r, 0.0), at + Vector2(0.0, r), at + Vector2(-r, 0.0),
	])
	if filled:
		draw_colored_polygon(pts, color)
	var outline := pts + PackedVector2Array([at + Vector2(0.0, -r)])
	draw_polyline(outline, Color.WHITE if filled else color, 1.0, true)


func _draw_label(at: Vector2, text: String, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE, color)


func _marker_px(kind: int) -> float:
	match kind:
		BodyData.Kind.STAR:
			return STAR_PX
		BodyData.Kind.MOON:
			return MOON_PX
		_:
			return PLANET_PX


# --- Input (screen-space pick) ---

func _unhandled_input(event: InputEvent) -> void:
	if _system == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _body_at(get_viewport().get_mouse_position())
		if target != "":
			EventBus.nav_target_selected.emit(target)


func _body_at(screen_pos: Vector2) -> String:
	var proj := _project_bodies()
	var nearest_id := ""
	var nearest_px := PICK_PX
	for id: String in proj:
		var d := screen_pos.distance_to(proj[id])
		if d <= nearest_px:
			nearest_px = d
			nearest_id = id
	return nearest_id
