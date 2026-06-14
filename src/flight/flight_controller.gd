class_name FlightController
extends Node
## System side of the travel pipeline (ADR 0005/0014/0015). It validates orders
## off EventBus against the ship's situation, applies the location/course/motion
## transitions, drives the ship along its course on SimClock ticks, and announces
## changes. Holds no reference to other systems (ADR 0003) — talks via EventBus,
## reads services (GameState, TypeRegistry).
##
## The situation lives in ShipState (location, location_body_id, current_order) so
## a save restores it; motion is recomputed on load (the ack beat isn't saved).
##
## NOT an autoload (six only) — a plain system node placed in the scene.

## Real seconds for one full holding orbit at 1x (tuning, cosmetic). Per-frame so
## it stays smooth and visible regardless of SECONDS_PER_TICK.
const ORBIT_PERIOD_SECONDS: float = 30.0

var _state: int = FlightCore.State.IDLE


func _ready() -> void:
	EventBus.sim_tick.connect(_on_sim_tick)
	EventBus.order_issued.connect(_on_order_issued)
	EventBus.game_state_loaded.connect(_resync_after_load)
	EventBus.system_changed.connect(_resync_after_load.unbind(1))  # reset motion for the new system
	_resync_after_load()


func get_state() -> int:
	return _state


# --- Order intake (ADR 0014 lifecycle: issue -> acknowledge / reject -> execute) ---

func _on_order_issued(order: Dictionary) -> void:
	match String(order.get("type", "")):
		"set_course":
			_set_course(order)
		"engage":
			_engage()
		"all_stop":
			_all_stop()
		"dock":
			_dock()
		"undock":
			_undock()
		"scan":
			_scan(order)
		"clear_course":
			_clear_course()
		"land":
			_land(order)
		"take_off":
			_take_off()
		"move":
			_move(order)
		_:
			EventBus.order_rejected.emit("ORDER_REJECT_UNKNOWN")


## Lay in a course to a body, a detected contact, or a free point (ADR 0020).
## A body/contact is given by `target_id`; a free point by `point` (target_id "").
func _set_course(order: Dictionary) -> void:
	var target_id := String(order.get("target_id", ""))
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	if _is_under_way():
		EventBus.order_rejected.emit("ORDER_REJECT_UNDERWAY")
		return
	if not FlightMath.is_valid_burn(burn):
		EventBus.order_rejected.emit("ORDER_REJECT_BURN_INVALID")
		return
	# Resolve the destination point from whichever kind of target this is.
	var dest: Vector2
	var body := _resolve_body(target_id)
	if body != null:
		dest = body.position
	elif target_id != "":
		var contact := _resolve_contact(target_id)
		if contact == null or GameState.contacts.tier_of(target_id) == Sensors.Tier.UNDETECTED:
			EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
			return
		dest = contact.position
	else:
		dest = order.get("point", GameState.ship.position)
	# "Already here": the body we're holding/docked at, or a point we're sitting on.
	if body != null and target_id == GameState.ship.location_body_id \
			and GameState.ship.location != Travel.Location.DEEP_SPACE:
		EventBus.order_rejected.emit("ORDER_REJECT_ALREADY_HERE")
		return
	if body == null and FlightCore.has_arrived(GameState.ship.position, dest):
		EventBus.order_rejected.emit("ORDER_REJECT_ALREADY_HERE")
		return
	# A no-go crossing no longer blocks Lay In (ADR 0028) — the course plots (drawn
	# red) and Engage is what's blocked, so the captain can drag it clear first.
	var waypoints: Array = order.get("waypoints", [])
	GameState.ship.current_order = {
		"type": "course",
		"target_id": target_id,
		"dest": dest,
		"waypoints": waypoints.duplicate(),
		"burn": burn,
		"engaged": false,
		"origin": GameState.ship.position,
	}
	_acknowledge("VOICE_SHIP_COURSE_LAID_IN")
	_notify_context()


## Does any leg of ship→waypoints→dest cross a no-go zone (ADR 0027)?
func _route_blocked(waypoints: Array, dest: Vector2) -> bool:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return false
	var route := PackedVector2Array([GameState.ship.position])
	for wp: Vector2 in waypoints:
		route.append(wp)
	route.append(dest)
	return Zones.route_block(system, route) == Zones.Block.NOGO


func _engage() -> void:
	if not _has_course():
		EventBus.order_rejected.emit("ORDER_REJECT_NO_COURSE")
		return
	if _is_under_way():
		EventBus.order_rejected.emit("ORDER_REJECT_UNDERWAY")
		return
	if GameState.ship.location == Travel.Location.DOCKED:
		EventBus.order_rejected.emit("ORDER_REJECT_DOCKED")
		return
	var order: Dictionary = GameState.ship.current_order
	# No-go is a hard boundary at Engage (ADR 0028): refuse to fly a route whose any
	# leg crosses a no-go zone — the captain must drag it clear first.
	if _route_blocked(order.get("waypoints", []), _destination(order)):
		EventBus.order_rejected.emit("ORDER_REJECT_OBSTRUCTION")
		return
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	# Fuel must bite: refuse a route (summed over its legs) the tank can't complete.
	var cost := FlightMath.rm_cost(_route_length(order), burn)
	if cost > GameState.ship.reaction_mass:
		EventBus.order_rejected.emit("ORDER_REJECT_INSUFFICIENT_RM")
		return
	order["engaged"] = true
	order["origin"] = GameState.ship.position
	# Departing the holding area into open space.
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.location_body_id = ""
	# ENGAGING is the brief acknowledgment beat; the first tick starts the burn.
	_set_state(FlightCore.State.ENGAGING)
	_acknowledge("VOICE_SHIP_COURSE_LAID_IN")
	_notify_context()


## Clear the plotted course entirely (ADR 0028). Only when not under way — under
## way the captain uses All Stop. No-op (quietly) if already clear/flying.
func _clear_course() -> void:
	if _is_under_way():
		return
	if _has_course():
		GameState.ship.current_order = {}
		_set_state(FlightCore.State.IDLE)
		_notify_context()


## All Stop: halt under way and drop the course, drifting in open space.
func _all_stop() -> void:
	if not _is_under_way():
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_UNDERWAY")
		return
	GameState.ship.current_order = {}
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.location_body_id = ""
	_set_state(FlightCore.State.IDLE)
	_acknowledge("VOICE_SHIP_ALL_STOP")
	_notify_context()


## Dock at the station we're holding at — a timed approach (ADR 0033). Refuel
## completes on arrival; time only (no RM), like landing.
func _dock() -> void:
	if _is_under_way() or _in_transition():
		EventBus.order_rejected.emit("ORDER_REJECT_UNDERWAY")
		return
	if GameState.ship.location != Travel.Location.HOLDING:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_HOLDING")
		return
	var body := _resolve_body(GameState.ship.location_body_id)
	if body == null or not body.can_dock:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_AT_STATION")
		return
	var ticks: int = LandingMath.modified_ticks(GameState.ship.base_dock_ticks, [])
	GameState.ship.current_order = {"type": "dock", "ticks_total": maxi(1, ticks), "ticks_left": maxi(1, ticks)}
	_set_state(FlightCore.State.DOCKING)
	_acknowledge("VOICE_SHIP_DOCKING")
	_notify_context()


## Begin a timed scan of a contact (ADR 0017): BLIP → IDENTIFIED over base_scan_ticks
## minutes. Runs concurrently with flight (you can scan while moving) and is checked
## each tick (_tick_scan) — out of range interrupts it. Legal in range, on an
## un-identified contact, when not already scanning.
func _scan(order: Dictionary) -> void:
	var contact_id := String(order.get("contact_id", ""))
	var contact := _resolve_contact(contact_id)
	if contact == null:
		EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
		return
	if GameState.ship.position.distance_to(contact.position) > GameState.ship.sensor_range:
		EventBus.order_rejected.emit("ORDER_REJECT_OUT_OF_RANGE")
		return
	if GameState.contacts.tier_of(contact_id) == Sensors.Tier.IDENTIFIED:
		EventBus.order_rejected.emit("ORDER_REJECT_ALREADY_SCANNED")
		return
	if GameState.ship.scan_contact_id != "":
		EventBus.order_rejected.emit("ORDER_REJECT_ALREADY_SCANNING")
		return
	var ticks := _scan_ticks()
	GameState.ship.scan_contact_id = contact_id
	GameState.ship.scan_ticks_total = ticks
	GameState.ship.scan_ticks_left = ticks
	EventBus.scan_started.emit(contact_id, ticks)
	_acknowledge("VOICE_SHIP_SCANNING")
	_notify_context()


## Effective scan duration (in-game minutes). Just the base stat for now; better
## sensors / crew lower it later (modifiable, like the landing/dock stats, ADR 0017).
func _scan_ticks() -> int:
	return maxi(1, GameState.ship.base_scan_ticks)


## Advance an active scan one tick — concurrent with flight (ADR 0017). The contact
## leaving sensor range (or winking out) interrupts it; reaching zero identifies it.
func _tick_scan() -> void:
	var contact_id := GameState.ship.scan_contact_id
	if contact_id == "":
		return
	var contact := _resolve_contact(contact_id)
	if contact == null \
			or GameState.ship.position.distance_to(contact.position) > GameState.ship.sensor_range:
		_clear_scan()
		EventBus.scan_interrupted.emit(contact_id)
		_acknowledge("VOICE_SHIP_SCAN_INTERRUPTED")
		_notify_context()
		return
	GameState.ship.scan_ticks_left -= 1
	if GameState.ship.scan_ticks_left > 0:
		return
	_clear_scan()
	GameState.contacts.set_tier(contact_id, Sensors.Tier.IDENTIFIED)
	EventBus.contact_promoted.emit(contact_id, Sensors.Tier.IDENTIFIED)
	_acknowledge("VOICE_SHIP_SCAN_COMPLETE")
	_notify_context()


func _clear_scan() -> void:
	GameState.ship.scan_contact_id = ""
	GameState.ship.scan_ticks_left = 0
	GameState.ship.scan_ticks_total = 0


## Undock back to the station's holding area — a timed manoeuvre (ADR 0033).
func _undock() -> void:
	if GameState.ship.location != Travel.Location.DOCKED or _in_transition():
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_DOCKED")
		return
	var ticks: int = LandingMath.modified_ticks(GameState.ship.base_undock_ticks, [])
	GameState.ship.current_order = {"type": "undock", "ticks_total": maxi(1, ticks), "ticks_left": maxi(1, ticks)}
	_set_state(FlightCore.State.UNDOCKING)
	_acknowledge("VOICE_SHIP_UNDOCKING")
	_notify_context()


# --- Surface: land / take off / move (ADR 0029/0030), timed transitions ---

## Land at a surface site (or Open Landing, site_id ""). Begins a timed descent;
## duration is the modifiable land stat × atmosphere factor.
func _land(order: Dictionary) -> void:
	if _is_under_way() or _in_transition():
		EventBus.order_rejected.emit("ORDER_REJECT_UNDERWAY")
		return
	if GameState.ship.location != Travel.Location.HOLDING:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_HOLDING")
		return
	var body := _resolve_body(GameState.ship.location_body_id)
	if body == null or not body.landable:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_LANDABLE")
		return
	var site_id := String(order.get("site_id", ""))
	# Touchdown point: a named site's authored spot, else the chosen free point (ADR 0030).
	var touchdown: Vector2 = _surface_pos(body, site_id) if site_id != "" \
		else order.get("pos", body.wild_touchdown)
	var ticks: int = LandingMath.modified_ticks(GameState.ship.base_descent_ticks,
		[LandingMath.atmosphere_factor(body.atmosphere_atm)])
	GameState.ship.current_order = {
		"type": "land", "site_id": site_id, "to": touchdown,
		"ticks_total": maxi(1, ticks), "ticks_left": maxi(1, ticks),
	}
	_set_state(FlightCore.State.DESCENDING)
	_acknowledge("VOICE_SHIP_DESCENDING")
	_notify_context()


## Take off from the surface back to the body's holding orbit (timed ascent).
func _take_off() -> void:
	if GameState.ship.location != Travel.Location.LANDED or _in_transition():
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_LANDED")
		return
	var body := _resolve_body(GameState.ship.location_body_id)
	var atm: float = body.atmosphere_atm if body != null else 0.0
	var ticks: int = LandingMath.modified_ticks(GameState.ship.base_ascent_ticks,
		[LandingMath.atmosphere_factor(atm)])
	GameState.ship.current_order = {"type": "take_off", "ticks_total": maxi(1, ticks), "ticks_left": maxi(1, ticks)}
	_set_state(FlightCore.State.ASCENDING)
	_acknowledge("VOICE_SHIP_ASCENDING")
	_notify_context()


## Move to another surface site (timed planetary flight on the surface map).
func _move(order: Dictionary) -> void:
	if GameState.ship.location != Travel.Location.LANDED or _in_transition():
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_LANDED")
		return
	var body := _resolve_body(GameState.ship.location_body_id)
	if body == null:
		EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
		return
	var dest_site := String(order.get("site_id", ""))
	var to: Vector2 = _surface_pos(body, dest_site) if dest_site != "" \
		else order.get("pos", GameState.ship.surface_position)
	if GameState.ship.surface_position.distance_to(to) < 1.0:
		EventBus.order_rejected.emit("ORDER_REJECT_ALREADY_HERE")
		return
	# Advanced per-frame (like the holding orbit) for smooth motion — completes on
	# arrival, no per-tick countdown (ADR 0030).
	GameState.ship.current_order = {"type": "surface_move", "site_id": dest_site, "to": to}
	_set_state(FlightCore.State.SURFACE_MOVING)
	_acknowledge("VOICE_SHIP_SURFACE_MOVING")
	_notify_context()


## Tick a timed surface transition (land/take-off/move) down; complete at zero.
func _tick_transition(order: Dictionary) -> void:
	var left := int(order.get("ticks_left", 0)) - 1
	if left > 0:
		order["ticks_left"] = left
		return
	match String(order.get("type", "")):
		"land":
			GameState.ship.location = Travel.Location.LANDED
			GameState.ship.surface_site_id = String(order.get("site_id", ""))
			GameState.ship.surface_position = order.get("to", Vector2.ZERO)
			GameState.ship.current_order = {}
			_set_state(FlightCore.State.IDLE)
			_acknowledge("VOICE_SHIP_LANDED")
		"take_off":
			var body := _resolve_body(GameState.ship.location_body_id)
			GameState.ship.location = Travel.Location.HOLDING
			GameState.ship.surface_site_id = ""
			if body != null:
				GameState.ship.position = body.position \
					+ Vector2.from_angle(GameState.ship.orbit_angle) * Travel.holding_radius(body)
			GameState.ship.current_order = {}
			_set_state(FlightCore.State.IDLE)
			_acknowledge("VOICE_SHIP_AIRBORNE")
		"dock":
			var body := _resolve_body(GameState.ship.location_body_id)
			GameState.ship.location = Travel.Location.DOCKED
			GameState.ship.current_order = {}
			if body != null and body.can_refuel:  # refuel completes on dock arrival (ADR 0033)
				GameState.ship.reaction_mass = GameState.ship.max_reaction_mass
				EventBus.fuel_changed.emit(Fuel.Pool.REACTION_MASS, GameState.ship.reaction_mass)
			_set_state(FlightCore.State.IDLE)
			_acknowledge("VOICE_SHIP_DOCKED")
		"undock":
			GameState.ship.location = Travel.Location.HOLDING
			GameState.ship.current_order = {}
			_set_state(FlightCore.State.IDLE)
			_acknowledge("VOICE_SHIP_UNDOCKED")
	_notify_context()


## Advance a surface move per-frame toward its destination (smooth, like the orbit).
## Completes on arrival. `seconds` is speed-scaled real time (0 = paused).
func _advance_surface_move(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var order: Dictionary = GameState.ship.current_order
	var to: Vector2 = order.get("to", GameState.ship.surface_position)
	var step := GameState.ship.surface_speed_su_per_tick * (seconds / SimClock.SECONDS_PER_TICK)
	GameState.ship.surface_position = GameState.ship.surface_position.move_toward(to, step)
	if GameState.ship.surface_position.distance_to(to) < 0.5:
		GameState.ship.surface_position = to
		GameState.ship.surface_site_id = String(order.get("site_id", ""))
		GameState.ship.current_order = {}
		_set_state(FlightCore.State.IDLE)
		_acknowledge("VOICE_SHIP_ARRIVED_SITE")
		_notify_context()


## A timed transition is in progress (busy beat — no new orders): a surface
## transition (ADR 0029/0030) or a dock/undock manoeuvre (ADR 0033).
func _in_transition() -> bool:
	var t := String(GameState.ship.current_order.get("type", ""))
	return t == "land" or t == "take_off" or t == "surface_move" or t == "dock" or t == "undock"


## Surface position (su) of a site id on a body ("" = Open Landing / wild touchdown).
func _surface_pos(body: BodyData, site_id: String) -> Vector2:
	if site_id == "":
		return body.wild_touchdown
	for loc: SurfaceLocationData in body.surface_locations:
		if loc.id == site_id:
			return loc.surface_position
	return body.wild_touchdown


# --- Execution (one step per SimClock tick) ---

## Smooth holding orbit, advanced per-frame (not on ticks) so it stays visible at
## the coarse tick rate; sim-speed scaled, so it freezes when paused.
func _process(delta: float) -> void:
	var seconds := delta * SimClock.get_speed()
	# A surface move glides per-frame toward its destination (smooth, ADR 0030).
	if String(GameState.ship.current_order.get("type", "")) == "surface_move":
		_advance_surface_move(seconds)
		return
	# Orbit only while genuinely holding — paused during a descent (still HOLDING).
	if GameState.ship.location != Travel.Location.HOLDING or _in_transition():
		return
	if seconds > 0.0:
		_advance_holding_orbit(seconds)


func _on_sim_tick(_tick: int) -> void:
	_tick_scan()  # scanning runs concurrently with flight/holding/docked (ADR 0017)
	var order: Dictionary = GameState.ship.current_order
	# Timed countdowns: descent/ascent + dock/undock (a surface move glides per-frame).
	var ttype := String(order.get("type", ""))
	if ttype == "land" or ttype == "take_off" or ttype == "dock" or ttype == "undock":
		_tick_transition(order)
		return
	# Holding orbit is handled per-frame in _process, not on ticks.
	if GameState.ship.location == Travel.Location.HOLDING:
		return

	if not _is_under_way():
		return
	# Multi-leg route (ADR 0027): fly through remaining waypoints first, no stop.
	var waypoints: Array = order.get("waypoints", [])
	if not waypoints.is_empty():
		_step_to_waypoint(order, waypoints)
		return
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
		_step_to_point(order)  # contact or free point — drift to rest on arrival
		return
	var center: Vector2 = body.position
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	var hold_radius := Travel.holding_radius(body)
	var prev_pos: Vector2 = GameState.ship.position

	# Already at/inside the holding ring → settle into orbit.
	if prev_pos.distance_to(center) <= hold_radius:
		_arrive(body)
		return

	GameState.ship.heading = (center - prev_pos).angle()  # face the body on approach
	var new_pos: Vector2 = FlightCore.step_position(prev_pos, center, burn)
	# Stop on the ring (never dive through the body): clamp the crossing step.
	if new_pos.distance_to(center) <= hold_radius:
		new_pos = center + (prev_pos - center).normalized() * hold_radius
	GameState.ship.position = new_pos
	# Spend reaction mass for the distance actually covered this tick.
	_spend_reaction_mass(FlightMath.rm_cost(prev_pos.distance_to(new_pos), burn))

	if new_pos.distance_to(center) <= hold_radius + 0.001:
		_arrive(body)
	else:
		var origin: Vector2 = order.get("origin", new_pos)
		_set_state(FlightCore.executing_state(origin, center, new_pos, burn))


## Fly one tick toward the next waypoint (ADR 0027). On reaching it, pop it and
## continue to the next leg without stopping; the final leg falls through to the
## body/point arrival logic next tick.
func _step_to_waypoint(order: Dictionary, waypoints: Array) -> void:
	var wp: Vector2 = waypoints[0]
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	var prev_pos: Vector2 = GameState.ship.position
	if FlightCore.has_arrived(prev_pos, wp):
		waypoints.remove_at(0)  # reached — advance, no hold
		return
	GameState.ship.heading = (wp - prev_pos).angle()
	var new_pos: Vector2 = FlightCore.step_position(prev_pos, wp, burn)
	GameState.ship.position = new_pos
	_spend_reaction_mass(FlightMath.rm_cost(prev_pos.distance_to(new_pos), burn))
	if FlightCore.has_arrived(new_pos, wp):
		waypoints.remove_at(0)
	var origin: Vector2 = order.get("origin", new_pos)
	_set_state(FlightCore.executing_state(origin, _destination(order), new_pos, burn))


## The full route as points: ship → waypoints → final destination.
func _route_points(order: Dictionary) -> PackedVector2Array:
	var route := PackedVector2Array([GameState.ship.position])
	for wp: Vector2 in order.get("waypoints", []):
		route.append(wp)
	route.append(_destination(order))
	return route


## Total route length over all legs (for fuel gating).
func _route_length(order: Dictionary) -> float:
	var route := _route_points(order)
	var total := 0.0
	for i in range(route.size() - 1):
		total += route[i].distance_to(route[i + 1])
	return total


## Fly one tick toward a contact / free point (no holding ring). On arrival the
## ship drifts: stop on the point, drop the course, go IDLE in deep space (ADR 0020).
func _step_to_point(order: Dictionary) -> void:
	var dest: Vector2 = _destination(order)
	# Hold ~500 m off a contact (ADR 0017); a free point we rest on exactly.
	var hold := Travel.anomaly_hold_radius() if _resolve_contact(String(order.get("target_id", ""))) != null else 0.0
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	var prev_pos: Vector2 = GameState.ship.position
	if prev_pos.distance_to(dest) <= hold or FlightCore.has_arrived(prev_pos, dest):
		_arrive_point(dest, hold, prev_pos)
		return
	GameState.ship.heading = (dest - prev_pos).angle()
	var new_pos: Vector2 = FlightCore.step_position(prev_pos, dest, burn)
	if hold > 0.0 and new_pos.distance_to(dest) <= hold:
		new_pos = dest + (prev_pos - dest).normalized() * hold  # stop on the near side
	GameState.ship.position = new_pos
	_spend_reaction_mass(FlightMath.rm_cost(prev_pos.distance_to(new_pos), burn))
	if new_pos.distance_to(dest) <= hold + 0.001 or FlightCore.has_arrived(new_pos, dest):
		_arrive_point(dest, hold, prev_pos)
	else:
		var origin: Vector2 = order.get("origin", new_pos)
		_set_state(FlightCore.executing_state(origin, dest, new_pos, burn))


## Arrival at a contact / free point: rest ~500 m off a contact (else on the point)
## and drift (no orbit, no body).
func _arrive_point(dest: Vector2, hold: float, approach_from: Vector2) -> void:
	if hold > 0.0:
		var dir := approach_from - dest
		if dir.length() < 0.001:
			dir = Vector2.from_angle(GameState.ship.heading + PI)
		GameState.ship.position = dest + dir.normalized() * hold
	else:
		GameState.ship.position = dest
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.location_body_id = ""
	GameState.ship.current_order = {}
	_set_state(FlightCore.State.IDLE)
	EventBus.course_completed.emit()  # Helm clears the plot (ADR 0028)
	_acknowledge("VOICE_SHIP_ARRIVED")
	_notify_context()


## Arrival: settle onto the body's holding ring (not its centre) at the approach
## angle; the course is complete and the ship begins orbiting.
func _arrive(body: BodyData) -> void:
	var center: Vector2 = body.position
	var to_ship: Vector2 = GameState.ship.position - center
	if to_ship.length() < 0.001:
		to_ship = Vector2.from_angle(GameState.ship.heading + PI)  # arrived dead-centre
	GameState.ship.position = center + to_ship.normalized() * Travel.holding_radius(body)
	GameState.ship.orbit_angle = (GameState.ship.position - center).angle()
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = body.id
	GameState.ship.current_order = {}
	_set_state(FlightCore.State.IDLE)
	EventBus.course_completed.emit()  # Helm clears the plot (ADR 0028)
	_acknowledge("VOICE_SHIP_ARRIVED")
	_notify_context()


## Advance the holding orbit by `seconds` of (speed-scaled) time. Authoritative —
## the rendered position follows it directly while holding (ShipView).
func _advance_holding_orbit(seconds: float) -> void:
	var body := _resolve_body(GameState.ship.location_body_id)
	if body == null:
		return
	GameState.ship.orbit_angle = wrapf(
		GameState.ship.orbit_angle + seconds * (TAU / ORBIT_PERIOD_SECONDS), 0.0, TAU)
	var new_pos: Vector2 = body.position \
		+ Vector2.from_angle(GameState.ship.orbit_angle) * Travel.holding_radius(body)
	GameState.ship.heading = (new_pos - GameState.ship.position).angle()  # tangent to the ring
	GameState.ship.position = new_pos


# --- Fuel ---

func _spend_reaction_mass(amount: float) -> void:
	if amount <= 0.0:
		return
	GameState.ship.reaction_mass = maxf(0.0, GameState.ship.reaction_mass - amount)
	EventBus.fuel_changed.emit(Fuel.Pool.REACTION_MASS, GameState.ship.reaction_mass)


# --- Situation helpers ---

func _is_under_way() -> bool:
	return bool(GameState.ship.current_order.get("engaged", false))


func _has_course() -> bool:
	return String(GameState.ship.current_order.get("type", "")) == "course"


func _set_state(new_state: int) -> void:
	if new_state == _state:
		return
	_state = new_state
	EventBus.flight_state_changed.emit(_state)


func _acknowledge(line_key: String) -> void:
	EventBus.order_acknowledged.emit(CrewVoice.speaker_for("helm"), line_key)


## Tell the UI the ship's situation changed so it re-derives status + orders.
func _notify_context() -> void:
	EventBus.ship_context_changed.emit()


# --- Lifecycle ---

## Recompute motion from the loaded course (location is restored from the save;
## the transient ack beat is not persisted — resume directly in the transit phase).
func _resync_after_load() -> void:
	# An in-progress surface transition resumes from its saved ticks_left (ADR 0029/0030).
	match String(GameState.ship.current_order.get("type", "")):
		"land":
			_set_state(FlightCore.State.DESCENDING)
		"take_off":
			_set_state(FlightCore.State.ASCENDING)
		"surface_move":
			_set_state(FlightCore.State.SURFACE_MOVING)
		"dock":
			_set_state(FlightCore.State.DOCKING)
		"undock":
			_set_state(FlightCore.State.UNDOCKING)
		_:
			if not _is_under_way():
				_set_state(FlightCore.State.IDLE)
			else:
				var order: Dictionary = GameState.ship.current_order
				var origin: Vector2 = order.get("origin", GameState.ship.position)
				_set_state(FlightCore.executing_state(origin, _destination(order),
					GameState.ship.position, int(order.get("burn", FlightMath.Burn.STANDARD))))
	_notify_context()


## The destination point of a course: a body's live position (bodies may move
## later) or the frozen `dest` for a contact / free point (ADR 0020).
func _destination(order: Dictionary) -> Vector2:
	var body := _resolve_body(String(order.get("target_id", "")))
	if body != null:
		return body.position
	return order.get("dest", GameState.ship.position)


func _resolve_body(target_id: String) -> BodyData:
	if target_id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if body.id == target_id:
			return body
	return null


func _resolve_contact(contact_id: String) -> ContactData:
	if contact_id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for contact: ContactData in system.contacts:
		if contact.id == contact_id:
			return contact
	return null
