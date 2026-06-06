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

## SimClock ticks for one full holding orbit (tuning). One orbit per in-game day.
const HOLDING_ORBIT_TICKS: int = 24

var _state: int = FlightCore.State.IDLE


func _ready() -> void:
	EventBus.sim_tick.connect(_on_sim_tick)
	EventBus.order_issued.connect(_on_order_issued)
	EventBus.order_belayed.connect(_on_belay)
	EventBus.game_state_loaded.connect(_resync_after_load)
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
		_:
			EventBus.order_rejected.emit("ORDER_REJECT_UNKNOWN")


func _set_course(order: Dictionary) -> void:
	var target_id := String(order.get("target_id", ""))
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	if _is_under_way():
		EventBus.order_rejected.emit("ORDER_REJECT_UNDERWAY")
		return
	if _resolve_body(target_id) == null:
		EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
		return
	if not FlightMath.is_valid_burn(burn):
		EventBus.order_rejected.emit("ORDER_REJECT_BURN_INVALID")
		return
	if target_id == GameState.ship.location_body_id and GameState.ship.location != Travel.Location.DEEP_SPACE:
		EventBus.order_rejected.emit("ORDER_REJECT_ALREADY_HERE")
		return
	GameState.ship.current_order = {
		"type": "course",
		"target_id": target_id,
		"burn": burn,
		"engaged": false,
		"origin": GameState.ship.position,
	}
	_acknowledge("VOICE_SHIP_COURSE_LAID_IN")
	_notify_context()


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
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
		EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
		return
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	# Fuel must bite: refuse a course the tank can't complete (ADR 0005).
	var cost := FlightMath.rm_cost(GameState.ship.position.distance_to(body.position), burn)
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


## Undock back to the station's holding area.
func _undock() -> void:
	if GameState.ship.location != Travel.Location.DOCKED:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_DOCKED")
		return
	GameState.ship.location = Travel.Location.HOLDING
	_acknowledge("VOICE_SHIP_UNDOCKED")
	_notify_context()


# --- Execution (one step per SimClock tick) ---

func _on_sim_tick(_tick: int) -> void:
	# Holding = orbiting: advance the ship around the body's holding ring.
	if GameState.ship.location == Travel.Location.HOLDING:
		_advance_holding_orbit()
		return

	var order: Dictionary = GameState.ship.current_order
	if not _is_under_way():
		return
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
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
	_acknowledge("VOICE_SHIP_ARRIVED")
	_notify_context()


## One orbit step around the holding body (authoritative; the view interpolates).
func _advance_holding_orbit() -> void:
	var body := _resolve_body(GameState.ship.location_body_id)
	if body == null:
		return
	GameState.ship.orbit_angle = wrapf(
		GameState.ship.orbit_angle + TAU / float(HOLDING_ORBIT_TICKS), 0.0, TAU)
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
		var body := _resolve_body(String(order.get("target_id", "")))
		if body == null:
			_set_state(FlightCore.State.IDLE)
		else:
			var origin: Vector2 = order.get("origin", GameState.ship.position)
			_set_state(FlightCore.executing_state(origin, body.position, GameState.ship.position,
				int(order.get("burn", FlightMath.Burn.STANDARD))))
	_notify_context()


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
