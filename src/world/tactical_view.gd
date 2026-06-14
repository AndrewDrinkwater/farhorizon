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
const SENSOR_RING_COLOR := Color(0.25, 0.95, 0.5, 0.9)  # bright green — the "Sensor Range" (ADR 0017)
const SHIP_TINT := Color(0.9, 0.95, 1.0)
const COURSE_NOGO_COLOR := Palette.STATUS_ALERT     # course crosses a no-go (ADR 0028)
const COURSE_HAZARD_COLOR := Palette.STATUS_CAUTION  # course crosses a hazard
const WAYPOINT_HANDLE_PX := 5.0  # grabbable waypoint handle radius
const GRAB_PX := 12.0  # cursor distance for grabbing a course leg / waypoint handle
const DASH_PX := 9.0    # plotted-course dash length / gap (ADR 0028)
const DASH_GAP_PX := 6.0
const TIME_COLOR := Palette.STATUS_NOMINAL  # isochrone rings (ADR 0019); paired with a label
const ISOCHRONE_RING_COLOR := Color(Palette.STATUS_NOMINAL, 0.30)
## Durations (in-game minutes) drawn as isochrone rings for the selected burn.
## Rings that fall outside the visible scope are skipped — at a fast burn only
## the near ones show, at a slow burn more do. Tuning (step-10 feel pass).
const ISOCHRONE_TICKS: Array[int] = [10, 20, 30, 60, 120]

## Range-ring radii in AU for the flat-distance mode (ADR 0021 toggle reuse).
const DISTANCE_RING_AU: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0, 20.0]

## Close-range scale rings (km), always drawn — each appears only at the scope where
## it's a readable size, so the close scopes get 1 km / 100 km references (ADR 0017).
const SCALE_RING_KM: Array[float] = [1.0, 100.0, 1.0e4, 1.0e6]

## What the concentric rings mean: ETA (isochrones, burn-aware) or flat distance.
enum RingMode { ISOCHRONE, DISTANCE }

## Scope range ladder (ADR 0017): the scope zooms across discrete ranges from a
## 15-AU sweep down to the immediate vicinity. The left-edge slider shows them and
## which one is active; the wheel steps through. Contacts still only resolve within
## actual sensor range — the close scopes just frame the area around the ship.
const LONG_RANGE_AU: float = 15.0
const KM_PER_AU: float = 149597870.7
const SCOPE_SENSOR_INDEX: int = 1  # the default scope = the sensor range

var _system: SystemData
var _selected_id: String = ""
var _selected_point: Vector2 = Vector2.ZERO
var _has_point_sel: bool = false  # a free-space waypoint is selected (ADR 0020)
var _preview_route: PackedVector2Array = PackedVector2Array()  # compose-time route (ADR 0027)
var _route_laid_in: bool = false  # is the plotted route committed? (solid vs dashed, ADR 0028)
var _drag_wp: int = -1  # waypoint being dragged (ADR 0028), -1 = none
var _drag_wps: PackedVector2Array = PackedVector2Array()
var _center: Vector2
var _view_rect: Rect2 = Rect2()  # plot region between the drawers (ADR 0035); empty = full viewport
var _range_index: int = SCOPE_SENSOR_INDEX  # index into _ranges (0 = widest)
var _ranges: Array[Dictionary] = []  # {key, wu}; wu < 0 = use the live sensor range
var _px_per_wu: float = 0.1
var _burn: int = FlightMath.Burn.STANDARD  # mirrors the Helm burn selector (ADR 0019)
var _ring_mode: int = RingMode.ISOCHRONE   # ETA rings ↔ distance rings (Helm toggle)
var _max_ring_px: float = 0.0
# Render interpolation of the per-tick transit position (ADR 0004): the scope is
# ship-centred, so easing the ship reference glides the whole world between ticks.
var _ship_prev: Vector2 = Vector2.ZERO
var _ship_curr: Vector2 = Vector2.ZERO
var _tick_accum: float = 0.0
var _font: Font


func build(system: SystemData) -> void:
	_font = ThemeDB.fallback_font
	_build_ranges()
	EventBus.nav_target_selected.connect(_on_target_selected)
	EventBus.nav_point_selected.connect(_on_point_selected)
	EventBus.nav_burn_changed.connect(func(burn: int) -> void: _burn = burn)
	EventBus.system_changed.connect(_on_system_changed)
	EventBus.nav_route_changed.connect(_on_route_changed)
	EventBus.nav_ring_mode_changed.connect(func(mode: int) -> void: _ring_mode = mode)
	EventBus.sim_tick.connect(_on_ship_tick.unbind(1))
	_init_system(system)


## Snapshot the ship position each tick for render interpolation (ADR 0004).
func _on_ship_tick() -> void:
	_ship_prev = _ship_curr
	_ship_curr = GameState.ship.position
	_tick_accum = 0.0


## The ship reference for the ship-centred projection: eased between the last two
## ticks while under way in space; the live position otherwise.
func _interp_ship() -> Vector2:
	if bool(GameState.ship.current_order.get("engaged", false)) \
			and GameState.ship.location == Travel.Location.DEEP_SPACE:
		var alpha := clampf(_tick_accum / SimClock.SECONDS_PER_TICK, 0.0, 1.0)
		return _ship_prev.lerp(_ship_curr, alpha)
	_ship_curr = GameState.ship.position
	_ship_prev = _ship_curr
	return _ship_curr


func _on_system_changed(system_id: String) -> void:
	_init_system(TypeRegistry.get_system(system_id))


## (Re)load a system into the scope (ADR 0024): reset the system + selection.
func _init_system(system: SystemData) -> void:
	_system = system
	_selected_id = ""
	_has_point_sel = false
	_range_index = SCOPE_SENSOR_INDEX  # back to the sensor-range scope on a new system
	_ship_curr = GameState.ship.position
	_ship_prev = _ship_curr
	_tick_accum = 0.0
	queue_redraw()


func _on_route_changed(route: PackedVector2Array, laid_in: bool) -> void:
	_preview_route = route
	_route_laid_in = laid_in


func _on_target_selected(id: String) -> void:
	_selected_id = id
	_has_point_sel = false


func _on_point_selected(point: Vector2) -> void:
	_selected_point = point
	_has_point_sel = true
	_selected_id = ""


func _process(delta: float) -> void:
	if visible:
		_tick_accum += delta * SimClock.get_speed()  # sub-tick progress for interpolation
		queue_redraw()


# --- Projection (true scale, ship-centred) ---

## Bound the scope to a screen region (the area between the drawers, ADR 0035);
## empty/zero rect falls back to the viewport.
func set_view_rect(rect: Rect2) -> void:
	_view_rect = rect
	_recompute()
	queue_redraw()


func _region() -> Rect2:
	if _view_rect.size.x > 0.0 and _view_rect.size.y > 0.0:
		return _view_rect
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


func _recompute() -> void:
	var region := _region()
	var vp := region.size
	_center = region.position + vp * 0.5
	_px_per_wu = (minf(vp.x, vp.y) * SCOPE_FILL) / _range_wu()
	_max_ring_px = minf(vp.x, vp.y) * 0.5 - 12.0  # keep a ring + its label on-screen


## The scope range ladder, widest → narrowest (ADR 0017). wu < 0 = the live sensor
## range. Built at runtime so it tracks WU_PER_AU.
func _build_ranges() -> void:
	_ranges = [
		{"key": "SCOPE_R_LONG", "wu": LONG_RANGE_AU * Travel.WU_PER_AU},  # 15 AU sweep
		{"key": "SCOPE_R_SENSOR", "wu": -1.0},                            # sensor range
		{"key": "SCOPE_R_5M", "wu": _km_to_wu(5.0e6)},                    # 5,000,000 km
		{"key": "SCOPE_R_100K", "wu": _km_to_wu(1.0e5)},                  # 100,000 km
		{"key": "SCOPE_R_1KM", "wu": _km_to_wu(1.0)},                     # 1 km — immediate vicinity
	]


func _km_to_wu(km: float) -> float:
	return km / KM_PER_AU * Travel.WU_PER_AU


## The active scope range in wu (resolving the sensor-range sentinel).
func _range_wu() -> float:
	if _ranges.is_empty():
		return maxf(1.0, GameState.ship.sensor_range * SCOPE_MARGIN)
	var w: float = _ranges[_range_index]["wu"]
	return maxf(1.0, GameState.ship.sensor_range * SCOPE_MARGIN) if w < 0.0 else w


## Step the scope range (clamped). Lower index = wider; higher = closer.
func _set_range_index(index: int) -> void:
	var clamped := clampi(index, 0, _ranges.size() - 1)
	if clamped == _range_index:
		return
	_range_index = clamped
	_recompute()
	queue_redraw()


func _to_screen(real_pos: Vector2) -> Vector2:
	return _center + (real_pos - _interp_ship()) * _px_per_wu


## Is a screen point within the scope region (plus a label margin)? Cull off-scope
## markers — at close ranges their coords are enormous and would collapse a filled
## polygon to zero area (triangulation crash).
func _on_scope(at: Vector2) -> bool:
	return _region().grow(80.0).has_point(at)


## The scope-range slider down the left edge (ADR 0017): a notch per range, widest at
## top → closest at bottom, the active one lit; a title above. Click a notch (or the
## wheel) to change scope. Drawn in the plot region's local space.
func _draw_range_slider() -> void:
	var geom := _slider_geometry()
	var x: float = geom["x"]
	draw_string(_font, Vector2(x - 6.0, geom["top"] - 14.0), tr("SCOPE_RANGE_TITLE"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.TEXT_DIM)
	draw_line(Vector2(x, geom["top"]), Vector2(x, geom["bottom"]), Color(Palette.TEXT_DIM, 0.5), 1.0)
	for i in _ranges.size():
		var y: float = geom["ys"][i]
		var active := i == _range_index
		var col := SENSOR_RING_COLOR if active else Color(Palette.TEXT_DIM, 0.8)
		draw_line(Vector2(x - 5.0, y), Vector2(x + 5.0, y), col, 2.0 if active else 1.0)
		if active:
			draw_circle(Vector2(x, y), 5.0, SENSOR_RING_COLOR)
		draw_string(_font, Vector2(x + 12.0, y + 4.0), tr(_ranges[i]["key"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


## Slider layout (local coords): x line, top/bottom, and the y of each notch.
func _slider_geometry() -> Dictionary:
	var region := _region()
	var top := region.position.y + 44.0
	var bottom := region.end.y - 44.0
	var ys := PackedFloat32Array()
	var n := _ranges.size()
	for i in n:
		ys.append(lerpf(top, bottom, float(i) / float(maxi(1, n - 1))))
	return {"x": region.position.x + 22.0, "top": top, "bottom": bottom, "ys": ys}


## Pick a range notch near the mouse (the slider band on the left), else -1.
func _range_slider_pick(mouse: Vector2) -> int:
	var geom := _slider_geometry()
	if mouse.x < geom["x"] - 12.0 or mouse.x > geom["x"] + 90.0:
		return -1
	var best := -1
	var best_d := 16.0
	for i in _ranges.size():
		var d: float = absf(mouse.y - geom["ys"][i])
		if d < best_d:
			best_d = d
			best = i
	return best


# --- Draw ---

func _draw() -> void:
	if _system == null:
		return
	_recompute()
	# Sensor range — a prominent bright-green circle (the headline of the scope) with a
	# label + a faint half-range guide inside it. Drawn only when it fits the scope:
	# at the close ranges you're far inside it, so it's off-screen (and a huge arc).
	var radius := GameState.ship.sensor_range * _px_per_wu
	if radius <= _max_ring_px:
		draw_arc(_center, radius * 0.5, 0.0, TAU, 80, Color(RING_COLOR, 0.18), 1.0, true)
		draw_arc(_center, radius, 0.0, TAU, 128, SENSOR_RING_COLOR, 2.5, true)
		var sensor_label := tr("SCOPE_SENSOR_RANGE")
		var lsz := _font.get_string_size(sensor_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		draw_string(_font, _center + Vector2(-lsz.x * 0.5, radius - 8.0), sensor_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, SENSOR_RING_COLOR)
	_draw_range_slider()  # the scope-range ladder on the left (ADR 0017)

	_draw_zones()  # beneath bodies/contacts (ADR 0026); true shapes at this scale
	if _ring_mode == RingMode.DISTANCE:
		_draw_distance_rings()
	else:
		_draw_isochrones()
	_draw_scale_rings()  # close-range km references (1 km / 100 km on the close scopes)
	# Proposal (ghost) under the heading (solid) — two distinct layers (ADR 0036).
	if _has_proposal():
		_draw_plotted_course()
	if _under_way():
		_draw_course()
	for body: BodyData in _system.bodies:
		var bat := _to_screen(body.position)
		if not _on_scope(bat):
			continue  # off the (possibly very close) scope — cull (also avoids huge-coord polys)
		_draw_body(body, bat)
	for contact: ContactData in _system.contacts:
		var tier := GameState.contacts.tier_of(contact.id)
		if tier == Sensors.Tier.UNDETECTED:
			continue
		var identified := tier == Sensors.Tier.IDENTIFIED
		var at := _to_screen(contact.position)
		if not _on_scope(at):
			continue
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


## Authored zones (ADR 0026): true shapes at this scale — outline + name/category
## label (shape + label, not colour alone, ADR 0012).
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
		_label(_zone_label_pos(zone), "%s · %s" % [tr(zone.name_key), tr(_zone_category_key(zone.category))],
			Color(t.r, t.g, t.b, 0.9))


func _draw_real_loop(real_points: PackedVector2Array, color: Color) -> void:
	if real_points.size() < 2:
		return
	var screen := PackedVector2Array()
	for p: Vector2 in real_points:
		screen.append(_to_screen(p))
	screen.append(screen[0])
	draw_polyline(screen, color, 1.0, true)


func _zone_label_pos(zone: ZoneData) -> Vector2:
	if zone.shape == ZoneData.Shape.POLYGON:
		var pts := Zones.world_points(zone, _system)
		if pts.is_empty():
			return _to_screen(Zones.world_center(zone, _system))
		var sum := Vector2.ZERO
		for p: Vector2 in pts:
			sum += p
		return _to_screen(sum / float(pts.size()))
	return _to_screen(Zones.world_center(zone, _system))


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


## Flat range rings (the Helm toggle's tactical use): concentric circles at fixed
## real distances (AU), each labelled — "how far", not "how long" (not burn-aware).
func _draw_distance_rings() -> void:
	for au: float in DISTANCE_RING_AU:
		var ring_px := au * Travel.WU_PER_AU * _px_per_wu
		if ring_px < 6.0 or ring_px > _max_ring_px:
			continue
		draw_arc(_center, ring_px, 0.0, TAU, 96, RING_COLOR, 1.0, true)
		var at := _center + Vector2(0.7071, -0.7071) * ring_px
		_label(at + Vector2(2.0, -2.0), tr("NAV_DISTANCE_AU").format({"au": _format_au(au)}), Palette.TEXT_DIM)


## Close-range km scale rings — each shows only at the scope where it reads (so the
## 1 km / 100 km close scopes get a scale), independent of the ETA/distance toggle.
func _draw_scale_rings() -> void:
	for km: float in SCALE_RING_KM:
		var ring_px := _km_to_wu(km) * _px_per_wu
		if ring_px < 6.0 or ring_px > _max_ring_px:
			continue
		draw_arc(_center, ring_px, 0.0, TAU, 96, Color(RING_COLOR, 0.5), 1.0, true)
		var at := _center + Vector2(-0.7071, -0.7071) * ring_px  # up-left, off the distance labels
		_label(at + Vector2(-2.0, -2.0), _km_label(km), Palette.TEXT_DIM)


func _km_label(km: float) -> String:
	if km >= 1.0e6:
		return "%dM km" % int(round(km / 1.0e6))
	if km >= 1.0e3:
		return "%dk km" % int(round(km / 1.0e3))
	return "%d km" % int(round(km))


func _format_au(au: float) -> String:
	return "%.0f" % au if au == floorf(au) else "%.1f" % au


func _draw_course() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		return
	# True scale → straight legs through the route's waypoints to the destination
	# (ADR 0020/0027). Ship maps to the scope centre. Heading → solid (ADR 0036).
	_draw_route(_course_route(order), 3.0, false, false)


## The selection's proposed course — always ghosted (ADR 0036); dashed until laid in.
func _draw_plotted_course() -> void:
	if _preview_route.size() >= 2:
		_draw_route(_preview_route, WAYPOINT_HANDLE_PX, not _route_laid_in, true)


## True while there is a proposal to draw, except when it coincides with the engaged
## heading (no double-draw) — ADR 0036.
func _has_proposal() -> bool:
	if _preview_route.size() < 2:
		return false
	if not _under_way():
		return true
	var heading := _course_route(GameState.ship.current_order)
	return _preview_route[_preview_route.size() - 1].distance_to(heading[heading.size() - 1]) > 1.0


## Draw a true-scale route (straight legs) coloured by its worst obstruction; dashed
## for a plotted course, solid for a committed one (ADR 0028). `ghost` dims it to mark
## a proposal vs the solid heading (ADR 0036).
func _draw_route(route: PackedVector2Array, handle_px: float, dashed: bool, ghost: bool) -> void:
	if route.size() < 2:
		return
	var color := _route_color(route, Palette.ACCENT)
	if ghost:
		color = Color(color.r, color.g, color.b, 0.45)
	var screen := PackedVector2Array()
	for p: Vector2 in route:
		screen.append(_to_screen(p))
	if dashed:
		_draw_dashed(screen, color)
	else:
		draw_polyline(screen, color, 1.5, true)
	for i in range(1, route.size() - 1):
		draw_circle(_to_screen(route[i]), handle_px, color)


## Dash a polyline continuously across its segments (the plotted-course cue).
func _draw_dashed(points: PackedVector2Array, color: Color) -> void:
	var on := true
	var pen := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		# Guard against zoomed-in segments billions of px long (the dash loop would
		# iterate effectively forever and hang): just draw them solid.
		if seg > 20000.0:
			draw_line(a, b, color, 1.5, true)
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


## The laid-in route as real points: ship → waypoints → destination.
func _course_route(order: Dictionary) -> PackedVector2Array:
	var target := _find(String(order.get("target_id", "")))
	var dest: Vector2 = target.position if target != null else order.get("dest", GameState.ship.position)
	var route := PackedVector2Array([_interp_ship()])
	for wp: Vector2 in order.get("waypoints", []):
		route.append(wp)
	route.append(dest)
	return route


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
	if not is_visible_in_tree() or _system == null:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_range_index(_range_index - 1)  # scroll out → wider scope
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_range_index(_range_index + 1)  # scroll in → closer scope
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var notch := _range_slider_pick(get_local_mouse_position())
			if notch >= 0:
				_set_range_index(notch)  # the range slider takes the click first
				return
			_on_left_press(get_local_mouse_position())
		else:
			_drag_wp = -1  # release ends any waypoint drag
	elif event is InputEventMouseMotion and _drag_wp >= 0:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_wp = -1  # release happened off the map — end the drag
			return
		_drag_wps[_drag_wp] = _screen_to_real(get_local_mouse_position())
		EventBus.nav_waypoints_set.emit(_drag_wps)
		queue_redraw()


func _on_left_press(mouse: Vector2) -> void:
	var target := _pick_at(mouse)
	if target != "":
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
			_drag_wps.insert(leg, _screen_to_real(mouse))
			_drag_wp = leg
			EventBus.nav_waypoints_set.emit(_drag_wps)
			return
	EventBus.nav_point_selected.emit(_screen_to_real(mouse))  # free-point destination


func _pick_at(mouse: Vector2) -> String:
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
	return nearest_id


func _screen_to_real(mouse: Vector2) -> Vector2:
	return GameState.ship.position + (mouse - _center) / _px_per_wu


func _plot_waypoints() -> PackedVector2Array:
	var wps := PackedVector2Array()
	for i in range(1, _preview_route.size() - 1):
		wps.append(_preview_route[i])
	return wps


func _waypoint_handle_at(mouse: Vector2) -> int:
	for i in range(1, _preview_route.size() - 1):
		if mouse.distance_to(_to_screen(_preview_route[i])) <= GRAB_PX:
			return i - 1
	return -1


func _course_leg_at(mouse: Vector2) -> int:
	var best := GRAB_PX
	var best_leg := -1
	for i in range(_preview_route.size() - 1):
		var a := _to_screen(_preview_route[i])
		var b := _to_screen(_preview_route[i + 1])
		var d := mouse.distance_to(Geometry2D.get_closest_point_to_segment(mouse, a, b))
		if d <= best:
			best = d
			best_leg = i
	return best_leg
