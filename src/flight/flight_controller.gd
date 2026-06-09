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
	EventBus.order_belayed.connect(_on_belay)
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
## way the captain uses Belay / All Stop. No-op (quietly) if already clear/flying.
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


## Belay = abort under way, but the course stays laid in so it can be re-engaged
## (ADR 0005/0015). Drifts in open space.
func _on_belay() -> void:
	if not _is_under_way():
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_UNDERWAY")
		return
	GameState.ship.current_order["engaged"] = false
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.location_body_id = ""
	_set_state(FlightCore.State.IDLE)
	_acknowledge("VOICE_SHIP_BELAYED")
	_notify_context()


## Dock at the station we're holding at (refuels at a can_refuel body).
func _dock() -> void:
	if GameState.ship.location != Travel.Location.HOLDING:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_HOLDING")
		return
	var body := _resolve_body(GameState.ship.location_body_id)
	if body == null or not body.can_dock:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_AT_STATION")
		return
	GameState.ship.location = Travel.Location.DOCKED
	if body.can_refuel:
		GameState.ship.reaction_mass = GameState.ship.max_reaction_mass
		EventBus.fuel_changed.emit(Fuel.Pool.REACTION_MASS, GameState.ship.reaction_mass)
	_acknowledge("VOICE_SHIP_DOCKED")
	_notify_context()


## Scan a contact to identify it (ADR 0017/0020): BLIP → IDENTIFIED. Legal only
## within sensor range and while it's an un-identified contact.
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
	GameState.contacts.set_tier(contact_id, Sensors.Tier.IDENTIFIED)
	EventBus.contact_promoted.emit(contact_id, Sensors.Tier.IDENTIFIED)
	_acknowledge("VOICE_SHIP_SCAN_COMPLETE")
	_notify_context()


## Undock back to the station's holding area.
func _undock() -> void:
	if GameState.ship.location != Travel.Location.DOCKED:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_DOCKED")
		return
	GameState.ship.location = Travel.Location.HOLDING
	_acknowledge("VOICE_SHIP_UNDOCKED")
	_notify_context()


# --- Execution (one step per SimClock tick) ---

## Smooth holding orbit, advanced per-frame (not on ticks) so it stays visible at
## the coarse tick rate; sim-speed scaled, so it freezes when paused.
func _process(delta: float) -> void:
	if GameState.ship.location != Travel.Location.HOLDING:
		return
	var seconds := delta * SimClock.get_speed()
	if seconds > 0.0:
		_advance_holding_orbit(seconds)


func _on_sim_tick(_tick: int) -> void:
	# Holding orbit is handled per-frame in _process, not on ticks.
	if GameState.ship.location == Travel.Location.HOLDING:
		return

	var order: Dictionary = GameState.ship.current_order
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
	var hold_radius := Travel.holding_radius(body.radius)
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
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	var prev_pos: Vector2 = GameState.ship.position
	if FlightCore.has_arrived(prev_pos, dest):
		_arrive_point(dest)
		return
	GameState.ship.heading = (dest - prev_pos).angle()
	var new_pos: Vector2 = FlightCore.step_position(prev_pos, dest, burn)
	GameState.ship.position = new_pos
	_spend_reaction_mass(FlightMath.rm_cost(prev_pos.distance_to(new_pos), burn))
	if FlightCore.has_arrived(new_pos, dest):
		_arrive_point(dest)
	else:
		var origin: Vector2 = order.get("origin", new_pos)
		_set_state(FlightCore.executing_state(origin, dest, new_pos, burn))


## Arrival at a contact / free point: rest on it and drift (no orbit, no body).
func _arrive_point(dest: Vector2) -> void:
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
	GameState.ship.position = center + to_ship.normalized() * Travel.holding_radius(body.radius)
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
		+ Vector2.from_angle(GameState.ship.orbit_angle) * Travel.holding_radius(body.radius)
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
	if not _is_under_way():
		_set_state(FlightCore.State.IDLE)
	else:
		var order: Dictionary = GameState.ship.current_order
		var origin: Vector2 = order.get("origin", GameState.ship.position)
		_set_state(FlightCore.executing_state(origin, _destination(order), GameState.ship.position,
			int(order.get("burn", FlightMath.Burn.STANDARD))))
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
