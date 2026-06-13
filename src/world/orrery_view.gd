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
const ZOOM_MIN := 0.4
const ZOOM_MAX := 40.0  # true scale needs deep zoom to read the inner system
const LINEAR_DEFAULT_ZOOM := 4.0  # true scale starts magnified, not whole-system tiny
const ZOOM_STEP := 1.15   # per wheel notch
const COURSE_FLATNESS_PX := 1.0  # max chord deviation before a course segment subdivides
const COURSE_MAX_DEPTH := 9      # subdivision cap (≤512 segments) — terminates the recursion
const RING_COLOR := Color(0.35, 0.45, 0.58, 0.30)
const MOON_RING_COLOR := Color(0.35, 0.45, 0.58, 0.18)  # fainter than planet rings (ADR 0022)
const SHIP_TINT := Color(0.9, 0.95, 1.0)
const TIME_COLOR := Palette.STATUS_NOMINAL  # travel-time annotations (ADR 0019); paired with text
const SATELLITE_COLOR := Palette.TEXT_DIM  # "has moons" halo + pips (ADR 0022)
const COURSE_NOGO_COLOR := Palette.STATUS_ALERT    # course crosses a no-go (ADR 0028)
const COURSE_HAZARD_COLOR := Palette.STATUS_CAUTION  # course crosses a hazard
const WAYPOINT_HANDLE_PX := 5.0  # grabbable waypoint handle radius
const GRAB_PX := 12.0  # cursor distance for grabbing a course leg / waypoint handle
const DASH_PX := 9.0    # plotted-course dash length / gap (ADR 0028)
const DASH_GAP_PX := 6.0
const SATELLITE_PIP_CAP := 4              # max moon pips drawn around the halo
const PIP_TICKS := 30   # one course-line pip per this many in-game minutes (tuning)
const PIP_PX := 5.0     # half-length of a pip tick, px

var _system: SystemData
var _params: OrreryParams
var _star_pos: Vector2 = Vector2.ZERO
var _by_id: Dictionary = {}        # id -> BodyData
var _moons_by_parent: Dictionary = {}  # parent id -> Array[BodyData] (ADR 0022)
var _selected_id: String = ""
var _selected_point: Vector2 = Vector2.ZERO
var _has_point_sel: bool = false  # a free-space waypoint is selected (ADR 0020)
var _preview_route: PackedVector2Array = PackedVector2Array()  # compose-time route (ADR 0027)
var _route_laid_in: bool = false  # is the plotted route committed? (solid vs dashed, ADR 0028)
var _drag_wp: int = -1  # waypoint being dragged (ADR 0028), -1 = none
var _drag_wps: PackedVector2Array = PackedVector2Array()  # working waypoint list during a drag
var _burn: int = FlightMath.Burn.STANDARD  # mirrors the Helm burn selector (ADR 0019)
var _scale_mode: int = OrreryParams.ScaleMode.LOG  # schematic ↔ true scale (ADR 0021)
var _zoom: float = 1.0          # wheel zoom about the cursor (ADR 0023)
var _pan: Vector2 = Vector2.ZERO  # drag pan
var _locked: bool = false       # locked on the ship (centre + max zoom + follow, ADR 0035)
var _panning: bool = false
var _pan_last: Vector2 = Vector2.ZERO
# Render interpolation of the per-tick transit position (ADR 0004): draw the ship
# eased between its last two tick positions so it glides instead of stepping.
var _ship_prev: Vector2 = Vector2.ZERO
var _ship_curr: Vector2 = Vector2.ZERO
var _tick_accum: float = 0.0  # speed-scaled seconds since the last tick
var _font: Font
var _view_rect: Rect2 = Rect2()  # plot region between the drawers (ADR 0035); empty = full viewport
var _proj: Dictionary = {}  # body id -> screen pos this frame (moons via project_child)


func build(system: SystemData) -> void:
	_font = ThemeDB.fallback_font
	EventBus.nav_target_selected.connect(_on_target_selected)
	EventBus.nav_point_selected.connect(_on_point_selected)
	EventBus.nav_burn_changed.connect(_on_burn_changed)
	EventBus.nav_scale_changed.connect(_on_scale_changed)
	EventBus.contact_detected.connect(_on_contacts_changed.unbind(1))
	EventBus.contact_lost.connect(_on_contacts_changed.unbind(1))
	EventBus.contact_promoted.connect(_on_contacts_changed.unbind(2))
	EventBus.system_changed.connect(_on_system_changed)
	EventBus.nav_route_changed.connect(_on_route_changed)
	EventBus.sim_tick.connect(_on_ship_tick.unbind(1))
	_init_system(system)


## Snapshot the ship's position each tick for render interpolation (ADR 0004).
func _on_ship_tick() -> void:
	_ship_prev = _ship_curr
	_ship_curr = GameState.ship.position
	_tick_accum = 0.0


## The ship position to draw: eased between the last two ticks while under way in
## space (smooth transit); the live position otherwise (orbit is per-frame, idle
## is static).
func _interp_ship() -> Vector2:
	if bool(GameState.ship.current_order.get("engaged", false)) \
			and GameState.ship.location == Travel.Location.DEEP_SPACE:
		var alpha := clampf(_tick_accum / SimClock.SECONDS_PER_TICK, 0.0, 1.0)
		return _ship_prev.lerp(_ship_curr, alpha)
	_ship_curr = GameState.ship.position
	_ship_prev = _ship_curr
	return _ship_curr


func _on_route_changed(route: PackedVector2Array, laid_in: bool) -> void:
	_preview_route = route
	_route_laid_in = laid_in


func _on_system_changed(system_id: String) -> void:
	_init_system(TypeRegistry.get_system(system_id))


## (Re)load a system into the view (ADR 0024): rebuild lookups, reset selection +
## zoom/pan, reframe. Signals are connected once in build(), not here.
func _init_system(system: SystemData) -> void:
	_system = system
	_by_id.clear()
	_moons_by_parent.clear()
	_star_pos = Vector2.ZERO
	_selected_id = ""
	_has_point_sel = false
	_zoom = 1.0
	_pan = Vector2.ZERO
	_locked = false
	_ship_curr = GameState.ship.position
	_ship_prev = _ship_curr
	_tick_accum = 0.0
	if system != null:
		for body: BodyData in system.bodies:
			_by_id[body.id] = body
			if body.kind == BodyData.Kind.STAR:
				_star_pos = body.position
			if body.kind == BodyData.Kind.MOON and body.parent_id != "":
				if not _moons_by_parent.has(body.parent_id):
					_moons_by_parent[body.parent_id] = []
				_moons_by_parent[body.parent_id].append(body)
	_rebuild_params()
	queue_redraw()


## Bound the plot to a screen region (the area between the drawers, ADR 0035) so it
## reads as a contained central display; empty/zero rect falls back to the viewport.
func set_view_rect(rect: Rect2) -> void:
	_view_rect = rect
	_rebuild_params()
	queue_redraw()


func _region() -> Rect2:
	if _view_rect.size.x > 0.0 and _view_rect.size.y > 0.0:
		return _view_rect
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


func _rebuild_params() -> void:
	var region := _region()
	_params = OrreryParams.new()
	_params.mode = _scale_mode
	_params.center = region.position + region.size * 0.5
	_params.ring_inner = 64.0
	_params.ring_outer = minf(region.size.x, region.size.y) * 0.42


func _process(delta: float) -> void:
	_tick_accum += delta * SimClock.get_speed()  # sub-tick progress for interpolation
	if _locked:
		_update_lock_pan()  # follow the ship while locked on (ADR 0035)
	queue_redraw()  # ship moves; contacts wink; cheap (one instrument)


# --- Map view controls (ADR 0035): lock-on-ship and fit-the-system ---

## Centre on the ship at maximum zoom and follow it as it moves.
func lock_on_ship() -> void:
	_locked = true
	_zoom = ZOOM_MAX
	_update_lock_pan()
	queue_redraw()


## Centre on the star and zoom out so the whole system fits (the default framing).
func fit_system() -> void:
	_locked = false
	_zoom = 1.0
	_pan = Vector2.ZERO
	queue_redraw()


## Pan so the (interpolated) ship sits at the chart centre, at the current zoom.
func _update_lock_pan() -> void:
	var p_ship := OrreryProjection.project(_interp_ship() - _star_pos, _params)
	_pan = -(p_ship - _params.center) * _zoom


func _on_target_selected(target_id: String) -> void:
	_selected_id = target_id
	_has_point_sel = false


func _on_point_selected(point: Vector2) -> void:
	_selected_point = point
	_has_point_sel = true
	_selected_id = ""


func _on_burn_changed(burn: int) -> void:
	_burn = burn  # _process redraws every frame; badges/pips pick this up


func _on_scale_changed(mode: int) -> void:
	_scale_mode = mode
	# True scale starts magnified so the inner system is legible; schematic fits whole.
	_zoom = LINEAR_DEFAULT_ZOOM if mode == OrreryParams.ScaleMode.LINEAR else 1.0
	_pan = Vector2.ZERO
	_locked = false
	_rebuild_params()  # remap radii (log ↔ linear); _process redraws


func _on_contacts_changed() -> void:
	queue_redraw()


# --- Projection ---

## id -> projected screen position for every charted body (moons via the parent).
## Projection is computed unviewed, then the zoom/pan view transform is applied to
## every point together (ADR 0023) so moon clusters scale with the chart.
func _project_bodies() -> Dictionary:
	var raw: Dictionary = {}
	for body: BodyData in _system.bodies:
		if body.kind != BodyData.Kind.MOON:
			raw[body.id] = OrreryProjection.project(body.position - _star_pos, _params)
	for body: BodyData in _system.bodies:
		if body.kind == BodyData.Kind.MOON:
			var parent: BodyData = _by_id.get(body.parent_id, null)
			var parent_raw: Vector2 = raw.get(body.parent_id, _params.center)
			var parent_pos: Vector2 = parent.position if parent != null else _star_pos
			raw[body.id] = OrreryProjection.project_child(body.position - parent_pos, parent_raw, _params)
	var proj: Dictionary = {}
	for id: String in raw:
		proj[id] = _view(raw[id])
	return proj


func _project_real(real_pos: Vector2) -> Vector2:
	return _view(OrreryProjection.project(real_pos - _star_pos, _params))


## Project a point on the course path: in LOG mode it is pulled inward near the
## star (ramp toward the hub) so the course curves in rather than ballooning around
## the inner ring (ADR 0016/0023). View transform applied like everything else.
func _project_course_point(real_pos: Vector2) -> Vector2:
	return _view(OrreryProjection.project_path(real_pos - _star_pos, _params))


# --- View transform: zoom + pan on top of the projection (ADR 0023) ---

## Projected (chart) point → screen point, zoomed about the hub then panned. Only
## positions transform; marker/label sizes stay constant (text never balloons).
func _view(p: Vector2) -> Vector2:
	return _params.center + (p - _params.center) * _zoom + _pan


## Inverse of _view: screen point → projected (chart) point, for input/picking.
func _unview(s: Vector2) -> Vector2:
	return _params.center + (s - _params.center - _pan) / _zoom


# --- Draw ---

func _draw() -> void:
	if _system == null:
		return
	var proj := _project_bodies()
	_proj = proj  # cache for the course endpoint (a moon's marker ≠ its raw projection)
	_draw_zones()  # beneath bodies/contacts (ADR 0026); warped through the projection
	_draw_rings(proj)
	# Proposal (ghost) under the heading (solid) — two distinct layers (ADR 0036).
	if _has_proposal():
		_draw_plotted_course()   # the selection's proposed course — ghosted
	if _under_way():
		_draw_course()           # the engaged heading — solid, over the proposal
	for body: BodyData in _system.bodies:
		_draw_body(body, proj[body.id])
	_draw_contacts()
	if _has_point_sel:
		_draw_waypoint(_project_course_point(_selected_point))
	_draw_ship()


func _draw_rings(proj: Dictionary) -> void:
	var hub := _view(_params.center)  # the star, under the zoom/pan transform (ADR 0023)
	for body: BodyData in _system.bodies:
		if body.kind == BodyData.Kind.STAR:
			continue
		if body.kind == BodyData.Kind.MOON:
			# Moon orbit ring: centred on the parent's projected point (ADR 0022).
			# In true scale moons collapse onto the parent — skip the vanishing ring.
			var parent_proj: Vector2 = proj.get(body.parent_id, hub)
			var moon_radius: float = (proj[body.id] - parent_proj).length()
			if moon_radius >= 2.0:
				draw_arc(parent_proj, moon_radius, 0.0, TAU, 48, MOON_RING_COLOR, 1.0, true)
			continue
		var radius: float = (proj[body.id] - hub).length()
		draw_arc(hub, radius, 0.0, TAU, 96, RING_COLOR, 1.0, true)


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
	if _moons_by_parent.has(body.id):
		_draw_satellite_affordance(at, _marker_px(body.kind), _moons_by_parent[body.id].size())
	var label_at := at + Vector2(_marker_px(body.kind) + 4.0, 4.0)
	_draw_label(label_at, tr(body.name_key), Palette.TEXT)
	# Per-body ETA badge at the selected burn (ADR 0019): the whole-system time
	# glance. Shown only in the overview — suppressed while composing/flying a
	# course so the plan doesn't clutter (ADR 0019 amended). Star is the hub.
	if body.kind != BodyData.Kind.STAR and not _composing():
		var ticks := FlightMath.eta_ticks(GameState.ship.position.distance_to(body.position), _burn)
		_draw_label(label_at + Vector2(0.0, LABEL_SIZE + 1.0), _format_duration(ticks), TIME_COLOR)


## Authored zones (ADR 0026), warped through the projection like everything else —
## outline + a name/category label (shape + label, not colour alone, ADR 0012).
func _draw_zones() -> void:
	for zone: ZoneData in _system.zones:
		var t := zone.tint
		var col := Color(t.r, t.g, t.b, 0.5)
		match zone.shape:
			ZoneData.Shape.CIRCLE:
				_draw_real_loop(Zones.ring_points(Zones.world_center(zone, _system), zone.radius), col)
			ZoneData.Shape.BAND:
				var c := Zones.world_center(zone, _system)
				_draw_real_loop(Zones.ring_points(c, zone.radius), col)
				_draw_real_loop(Zones.ring_points(c, zone.inner_radius), Color(t.r, t.g, t.b, 0.28))
			ZoneData.Shape.POLYGON:
				_draw_real_loop(Zones.world_points(zone, _system), col)
		var label := "%s · %s" % [tr(zone.name_key), tr(_zone_category_key(zone.category))]
		_draw_label(_zone_label_pos(zone), label, Color(t.r, t.g, t.b, 0.9))


## Map real-space loop points through the projection and draw a closed outline.
func _draw_real_loop(real_points: PackedVector2Array, color: Color) -> void:
	if real_points.size() < 2:
		return
	var screen := PackedVector2Array()
	for p: Vector2 in real_points:
		screen.append(_project_real(p))
	screen.append(screen[0])
	draw_polyline(screen, color, 1.0, true)


func _zone_label_pos(zone: ZoneData) -> Vector2:
	if zone.shape == ZoneData.Shape.POLYGON:
		var pts := Zones.world_points(zone, _system)
		if pts.is_empty():
			return _project_real(Zones.world_center(zone, _system))
		var sum := Vector2.ZERO
		for p: Vector2 in pts:
			sum += p
		return _project_real(sum / float(pts.size()))
	return _project_real(Zones.world_center(zone, _system))


func _zone_category_key(category: int) -> String:
	match category:
		ZoneData.Category.HAZARD:
			return "ZONE_CAT_HAZARD"
		ZoneData.Category.NOGO:
			return "ZONE_CAT_NOGO"
		ZoneData.Category.FACILITY:
			return "ZONE_CAT_FACILITY"
		ZoneData.Category.TRIGGER:
			return "ZONE_CAT_TRIGGER"
		_:
			return "ZONE_CAT_FIELD"


## Mark a planet that has moons (ADR 0022): a thin halo ring + one pip per moon
## (capped), so it's evident the planet is focusable — shape + count, not colour.
func _draw_satellite_affordance(at: Vector2, marker_px: float, moon_count: int) -> void:
	var halo_r := marker_px + 3.0
	draw_arc(at, halo_r, 0.0, TAU, 32, SATELLITE_COLOR, 1.0, true)
	var pips: int = mini(moon_count, SATELLITE_PIP_CAP)
	for i in pips:
		var a := TAU * float(i) / float(pips) - PI * 0.5
		draw_circle(at + Vector2.from_angle(a) * (halo_r + 3.0), 1.5, SATELLITE_COLOR)


func _draw_contacts() -> void:
	for contact: ContactData in _system.contacts:
		var tier := GameState.contacts.tier_of(contact.id)
		if tier == Sensors.Tier.UNDETECTED:
			continue
		var identified := tier == Sensors.Tier.IDENTIFIED
		var at := _project_real(contact.position)
		if contact.id == _selected_id:
			draw_arc(at, CONTACT_PX + SELECT_GAP_PX, 0.0, TAU, 32, Palette.ACCENT, 1.5, true)
		# Shape carries identity (ADR 0012): a hollow diamond is an unscanned BLIP;
		# scanning fills it and reveals the name.
		_draw_diamond(at, CONTACT_PX, contact.tint, identified)
		draw_circle(at, 1.5, contact.tint)
		var label := tr(contact.name_key) if identified else tr("NAV_CONTACT_UNKNOWN")
		_draw_label(at + Vector2(CONTACT_PX + 4.0, 4.0), label, Palette.TEXT_DIM)


## A free-space waypoint marker: a small ring + crosshair in the accent colour.
func _draw_waypoint(at: Vector2) -> void:
	draw_arc(at, 6.0, 0.0, TAU, 24, Palette.ACCENT, 1.5, true)
	draw_line(at + Vector2(-9.0, 0.0), at + Vector2(9.0, 0.0), Palette.ACCENT, 1.0, true)
	draw_line(at + Vector2(0.0, -9.0), at + Vector2(0.0, 9.0), Palette.ACCENT, 1.0, true)


func _draw_course() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		return
	# The laid-in route: ship → waypoints → destination (ADR 0027). Each leg is the
	# adaptively-subdivided curve (the log projection bends a straight real path —
	# sharpest near the star — and uniform sampling would kink it).
	var route := _course_route(order)
	var color := _route_color(route, Palette.ACCENT)  # engaged → solid
	var dest := _dest_screen(route[route.size() - 1], String(order.get("target_id", "")))
	_draw_route_legs(route, color, false, dest)
	for i in range(route.size() - 1):
		_draw_course_time(route[i], route[i + 1])  # time pips per leg
	for i in range(1, route.size() - 1):
		draw_circle(_project_course_point(route[i]), 3.0, color)  # waypoint dots
	var target: BodyData = _by_id.get(String(order.get("target_id", "")), null)
	var ring: float = (_marker_px(target.kind) + 5.0) if target != null else 8.0
	draw_arc(dest, ring, 0.0, TAU, 24, color, 1.0, true)


## The editable plotted course (compose route), coloured by obstruction (ADR 0028):
## red through a no-go, amber through a hazard, accent when clear. Waypoint handles
## are drawn fatter so they can be grabbed and dragged.
func _draw_plotted_course() -> void:
	if _preview_route.size() < 2:
		return
	# Anchor the proposal's start to the (interpolated) ship while under way so it
	# shares the heading's apex instead of trailing the last tick (ADR 0036).
	var route := _preview_route
	if _under_way():
		route = route.duplicate()
		route[0] = _interp_ship()
	# Proposal is always GHOSTED (dim) — only the engaged heading draws solid (ADR 0036);
	# obstruction red/amber still applies, dashed until laid in (ADR 0028).
	var base := _route_color(route, Palette.ACCENT)
	var color := Color(base.r, base.g, base.b, 0.45)
	var dest := _dest_screen(route[route.size() - 1], _selected_id)
	_draw_route_legs(route, color, not _route_laid_in, dest)
	for i in range(route.size() - 1):
		_draw_course_time(route[i], route[i + 1])
	for i in range(1, route.size() - 1):
		draw_circle(_project_course_point(route[i]), WAYPOINT_HANDLE_PX, color)
	draw_arc(dest, 8.0, 0.0, TAU, 24, color, 1.0, true)


## Course colour from the worst obstruction along the route (ADR 0028): red for a
## no-go, amber for a hazard, else `clear_color` (which encodes plotted vs laid-in).
func _route_color(route: PackedVector2Array, clear_color: Color) -> Color:
	if _system == null:
		return clear_color
	match Zones.route_block(_system, route):
		Zones.Block.NOGO:
			return COURSE_NOGO_COLOR
		Zones.Block.HAZARD:
			return COURSE_HAZARD_COLOR
		_:
			return clear_color




func _under_way() -> bool:
	return bool(GameState.ship.current_order.get("engaged", false))


## Is there a proposal (plotted course) to draw? Always when one is composed, except
## when it coincides with the active heading (no double-draw) — ADR 0036.
func _has_proposal() -> bool:
	if _preview_route.size() < 2:
		return false
	if not _under_way():
		return true
	var heading := _course_dest(GameState.ship.current_order)
	return _preview_route[_preview_route.size() - 1].distance_to(heading) > 1.0


## The laid-in route as real points: ship → waypoints → destination.
func _course_route(order: Dictionary) -> PackedVector2Array:
	var route := PackedVector2Array([_interp_ship()])
	for wp: Vector2 in order.get("waypoints", []):
		route.append(wp)
	route.append(_course_dest(order))
	return route


## Draw each route leg as the projected, adaptively-flattened curve — solid for a
## committed (laid-in/engaged) course, dashed for a plotted one (ADR 0028). The final
## leg snaps to the destination's MARKER (a moon's cluster ≠ its raw projection in
## Schematic mode) so the course meets the dot you're aiming at (ADR 0021/0022).
func _draw_route_legs(route: PackedVector2Array, color: Color, dashed: bool, dest: Vector2) -> void:
	for i in range(route.size() - 1):
		var pts := PackedVector2Array([_project_course_point(route[i])])
		_subdivide_course(route[i], route[i + 1], 0.0, 1.0, 0, pts)
		if i == route.size() - 2:
			pts[pts.size() - 1] = dest  # last leg ends on the destination marker
		if dashed:
			_draw_dashed(pts, color)
		else:
			draw_polyline(pts, color, 1.5, true)


## The screen point of a route's destination: if `target_id` is a charted body, its
## MARKER (so a moon's cluster position is used, not its raw projection); else the
## plain projection. Each course passes its OWN target — the heading the order's, the
## proposal the selection's — so they never snap to each other's end (ADR 0036).
func _dest_screen(route_last_world: Vector2, target_id: String) -> Vector2:
	if target_id != "" and _proj.has(target_id):
		return _proj[target_id]
	return _project_course_point(route_last_world)


## Dash a polyline (continuous across its segments) — the "plotted, not committed"
## cue for a course (ADR 0028).
func _draw_dashed(points: PackedVector2Array, color: Color) -> void:
	var on := true
	var pen := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var dir := (b - a) / seg
		var pos := 0.0
		while pos < seg:
			var span := (DASH_PX if on else DASH_GAP_PX) - pen
			var step := minf(span, seg - pos)
			if on:
				draw_line(a + dir * pos, a + dir * (pos + step), color, 1.5, true)
			pos += step
			pen += step
			if pen >= (DASH_PX if on else DASH_GAP_PX) - 0.001:
				pen = 0.0
				on = not on


## True while the captain is composing or flying a course (a target/point selected,
## or a course laid in) — the map declutters to names + the course leg then.
func _composing() -> bool:
	return _selected_id != "" or _has_point_sel \
		or String(GameState.ship.current_order.get("type", "")) == "course"


## Destination point of the laid-in course: a charted body's position, or the
## frozen `dest` for a contact / free point (ADR 0020).
func _course_dest(order: Dictionary) -> Vector2:
	var body: BodyData = _by_id.get(String(order.get("target_id", "")), null)
	if body != null:
		return body.position
	return order.get("dest", GameState.ship.position)


## Flatten the projected course curve: keep the projected midpoint within
## COURSE_FLATNESS_PX of the chord, else split. Appends end-points in path order.
func _subdivide_course(s: Vector2, e: Vector2, t0: float, t1: float, depth: int,
		pts: PackedVector2Array) -> void:
	var p0 := _project_course_point(s.lerp(e, t0))
	var p1 := _project_course_point(s.lerp(e, t1))
	var tm := (t0 + t1) * 0.5
	var pm := _project_course_point(s.lerp(e, tm))
	if depth >= COURSE_MAX_DEPTH or pm.distance_to((p0 + p1) * 0.5) <= COURSE_FLATNESS_PX:
		pts.append(p1)
		return
	_subdivide_course(s, e, t0, tm, depth + 1, pts)
	_subdivide_course(s, e, tm, t1, depth + 1, pts)


## Graduate the course line with a pip per fixed time unit and tag it with the
## leg ETA, so leg length reads as duration on the log-compressed chart (ADR 0019).
## Speed is constant per burn, so each pip sits at an even fraction of the real
## path; the projection then warps the spacing exactly as it warps the line.
func _draw_course_time(ship_pos: Vector2, target_pos: Vector2) -> void:
	var total_ticks := FlightMath.eta_ticks(ship_pos.distance_to(target_pos), _burn)
	if total_ticks <= 0:
		return
	var k := 1
	while k * PIP_TICKS < total_ticks:
		var f := float(k * PIP_TICKS) / float(total_ticks)
		var at := _project_course_point(ship_pos.lerp(target_pos, f))
		var ahead := _project_course_point(ship_pos.lerp(target_pos, minf(1.0, f + 0.01)))
		var perp := (ahead - at).normalized().orthogonal()
		if perp.length() < 0.5:
			perp = Vector2.UP
		draw_line(at - perp * PIP_PX, at + perp * PIP_PX, TIME_COLOR, 1.5, true)
		k += 1
	# (No mid-line ETA label — redundant with the Helm panel + the pip legend, and
	# it collided with body names; ADR 0019 amended.)


func _draw_ship() -> void:
	# Project the ship with the PATH map (like the course line), not the raw body map:
	# near the star the raw map clamps to the hub, snapping the marker off its path
	# (ADR 0016/0023). This keeps the ship on the line it's flying.
	var at := _project_course_point(_interp_ship())
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
		var dir := _project_course_point(_course_dest(order)) \
			- _project_course_point(_interp_ship())
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


# --- Input (screen-space pick) ---

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _system == null:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(get_local_mouse_position(), ZOOM_STEP)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(get_local_mouse_position(), 1.0 / ZOOM_STEP)
			return
		# Right- or middle-drag pans (left stays selection/waypoint/focus) — ADR 0023.
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			_pan_last = get_local_mouse_position()
			if event.pressed:
				_locked = false  # manual pan breaks lock-on (ADR 0035)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press(get_local_mouse_position())
			else:
				_drag_wp = -1  # release ends any waypoint drag
	elif event is InputEventMouseMotion:
		var mouse := get_local_mouse_position()
		if _drag_wp >= 0:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_drag_wp = -1  # release happened off the map — end the drag
				return
			_drag_wps[_drag_wp] = _screen_to_real(mouse)  # drag the course around obstacles (ADR 0028)
			EventBus.nav_waypoints_set.emit(_drag_wps)
			queue_redraw()
		elif _panning:
			_pan += mouse - _pan_last
			_pan_last = mouse
			queue_redraw()


func _on_left_press(mouse: Vector2) -> void:
	var target := _pick_at(mouse)
	if target != "":
		# Re-clicking an already-selected moon-bearing planet focuses it (ADR 0022).
		if target == _selected_id and _moons_by_parent.has(target):
			EventBus.nav_focus_requested.emit(target)
		else:
			EventBus.nav_target_selected.emit(target)
		return
	# Grab the plotted course to add / move a waypoint (ADR 0028), while idle.
	if not _under_way() and _preview_route.size() >= 2:
		var handle := _waypoint_handle_at(mouse)
		if handle >= 0:
			_drag_wp = handle
			_drag_wps = _plot_waypoints()
			return
		var leg := _course_leg_at(mouse)
		if leg >= 0:
			_drag_wps = _plot_waypoints()
			_drag_wps.insert(leg, _screen_to_real(mouse))  # new waypoint on this leg
			_drag_wp = leg
			EventBus.nav_waypoints_set.emit(_drag_wps)
			return
	# Empty space → plot a direct course to that free point (ADR 0020/0028).
	EventBus.nav_point_selected.emit(_screen_to_real(mouse))


## Screen → real (wu): inverse projection + inverse zoom/pan (ADR 0023).
func _screen_to_real(screen_pos: Vector2) -> Vector2:
	return _star_pos + OrreryProjection.unproject(_unview(screen_pos), _params)


## The plotted route's waypoints (the route minus its ship + destination ends).
func _plot_waypoints() -> PackedVector2Array:
	var wps := PackedVector2Array()
	for i in range(1, _preview_route.size() - 1):
		wps.append(_preview_route[i])
	return wps


## Waypoint-list index whose handle is under the cursor, or -1.
func _waypoint_handle_at(mouse: Vector2) -> int:
	for i in range(1, _preview_route.size() - 1):
		if mouse.distance_to(_project_course_point(_preview_route[i])) <= GRAB_PX:
			return i - 1
	return -1


## Route-leg index nearest the cursor (within GRAB_PX), or -1. Tested against the
## actual rendered curve (same adaptive subdivision as the draw), not the straight
## chord — on the warped orrery a near-star leg bows far from its chord (ADR 0028).
func _course_leg_at(mouse: Vector2) -> int:
	var best := GRAB_PX
	var best_leg := -1
	for i in range(_preview_route.size() - 1):
		var pts := PackedVector2Array([_project_course_point(_preview_route[i])])
		_subdivide_course(_preview_route[i], _preview_route[i + 1], 0.0, 1.0, 0, pts)
		for j in range(pts.size() - 1):
			var d := mouse.distance_to(Geometry2D.get_closest_point_to_segment(mouse, pts[j], pts[j + 1]))
			if d <= best:
				best = d
				best_leg = i
	return best_leg


## Zoom by `factor` about the cursor, keeping the chart point under it fixed (ADR 0023).
func _zoom_at(cursor: Vector2, factor: float) -> void:
	_locked = false  # manual zoom breaks lock-on (ADR 0035)
	var old_zoom := _zoom
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(_zoom, old_zoom):
		return
	var chart_pt := _params.center + (cursor - _params.center - _pan) / old_zoom
	_pan = cursor - _params.center - (chart_pt - _params.center) * _zoom
	queue_redraw()


## Nearest charted body or detected contact under the cursor ("" if none close).
func _pick_at(screen_pos: Vector2) -> String:
	var nearest_id := ""
	var nearest_px := PICK_PX
	var proj := _project_bodies()
	for id: String in proj:
		var d := screen_pos.distance_to(proj[id])
		if d <= nearest_px:
			nearest_px = d
			nearest_id = id
	for contact: ContactData in _system.contacts:
		if GameState.contacts.tier_of(contact.id) == Sensors.Tier.UNDETECTED:
			continue
		var d := screen_pos.distance_to(_project_real(contact.position))
		if d <= nearest_px:
			nearest_px = d
			nearest_id = contact.id
	return nearest_id
