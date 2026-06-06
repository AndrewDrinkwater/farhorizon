class_name FlightController
extends Node
## Drives the ship along its course on SimClock ticks (ADR 0004/0005) and is the
## system side of the Helm order lifecycle (ADR 0014): it validates orders off
## EventBus, executes them over ticks, writes GameState.ship, and announces
## flight_state_changed. It holds no reference to other systems (ADR 0003) — it
## talks via EventBus and reads services (GameState, TypeRegistry).
##
## The authoritative course lives in ShipState.current_order so a mid-flight save
## resumes (ADR 0014); the transient ack beat (ENGAGING) is not saved — on load
## the ship resumes directly in its executing phase.
##
## NOT an autoload (six only) — a plain system node placed in the scene.

var _state: int = FlightCore.State.IDLE


func _ready() -> void:
	EventBus.sim_tick.connect(_on_sim_tick)
	EventBus.order_issued.connect(_on_order_issued)
	EventBus.order_belayed.connect(_on_belay)
	EventBus.game_state_loaded.connect(_resync_after_load)
	_resync_after_load()


func get_state() -> int:
	return _state


func _set_state(new_state: int) -> void:
	if new_state == _state:
		return
	_state = new_state
	EventBus.flight_state_changed.emit(_state)


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
		"establish_orbit":
			_establish_orbit()
		"break_orbit":
			_break_orbit()
		_:
			EventBus.order_rejected.emit("ORDER_REJECT_UNKNOWN")


func _set_course(order: Dictionary) -> void:
	var target_id := String(order.get("target_id", ""))
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	if _resolve_body(target_id) == null:
		EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
		return
	if not FlightMath.is_valid_burn(burn):
		EventBus.order_rejected.emit("ORDER_REJECT_BURN_INVALID")
		return
	GameState.ship.current_order = {
		"type": "course",
		"target_id": target_id,
		"burn": burn,
		"engaged": false,
		"origin": GameState.ship.position,
	}
	_set_state(FlightCore.State.COURSE_SET)
	_acknowledge("VOICE_SHIP_COURSE_LAID_IN")


func _engage() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		EventBus.order_rejected.emit("ORDER_REJECT_NO_COURSE")
		return
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
		EventBus.order_rejected.emit("ORDER_REJECT_TARGET_UNKNOWN")
		return
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))
	# Fuel must bite: refuse a course the tank can't complete (ADR 0005, helm.md).
	var cost := FlightMath.rm_cost(GameState.ship.position.distance_to(body.position), burn)
	if cost > GameState.ship.reaction_mass:
		EventBus.order_rejected.emit("ORDER_REJECT_INSUFFICIENT_RM")
		return
	order["engaged"] = true
	order["origin"] = GameState.ship.position
	# ENGAGING is the brief acknowledgment beat; the first tick starts the burn.
	_set_state(FlightCore.State.ENGAGING)
	_acknowledge("VOICE_SHIP_COURSE_LAID_IN")


func _all_stop() -> void:
	GameState.ship.current_order = {}
	_set_state(FlightCore.State.IDLE)
	_acknowledge("VOICE_SHIP_ALL_STOP")


## Establish orbit at the body the ship is sitting at (α0.1: arrival already
## auto-orbits, so this is mainly explicit confirmation / re-entry from drift).
func _establish_orbit() -> void:
	if _body_at_ship() == null:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_AT_BODY")
		return
	_set_state(FlightCore.State.IN_ORBIT)
	_acknowledge("VOICE_SHIP_ORBIT_ESTABLISHED")


## Break orbit → drift in place (no course). Clears the active order.
func _break_orbit() -> void:
	if _state != FlightCore.State.IN_ORBIT:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_IN_ORBIT")
		return
	GameState.ship.current_order = {}
	_set_state(FlightCore.State.IDLE)
	_acknowledge("VOICE_SHIP_ORBIT_BROKEN")


## Emit an acknowledgment in the voice of whoever holds the Helm post (ADR 0014).
func _acknowledge(line_key: String) -> void:
	EventBus.order_acknowledged.emit(CrewVoice.speaker_for("helm"), line_key)


## Belay = abort. Per ADR 0005, abort returns to CourseSet (the course stays laid
## in, just no longer executing); with no course it drops to Idle.
func _on_belay() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) == "course":
		order["engaged"] = false
		_set_state(FlightCore.State.COURSE_SET)
		_acknowledge("VOICE_SHIP_BELAYED")
	else:
		_set_state(FlightCore.State.IDLE)


# --- Execution (one step per SimClock tick) ---

func _on_sim_tick(_tick: int) -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course" or not bool(order.get("engaged", false)):
		return
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
		return
	var target: Vector2 = body.position
	var burn := int(order.get("burn", FlightMath.Burn.STANDARD))

	if FlightCore.has_arrived(GameState.ship.position, target):
		_arrive(target)
		return

	var prev_pos: Vector2 = GameState.ship.position
	var heading_dir: Vector2 = target - prev_pos
	if heading_dir.length() > 0.0:
		GameState.ship.heading = heading_dir.angle()
	var new_pos: Vector2 = FlightCore.step_position(prev_pos, target, burn)
	GameState.ship.position = new_pos
	# Spend reaction mass for the distance actually covered this tick; summed over
	# the course this equals FlightMath.rm_cost(total_distance, burn).
	_spend_reaction_mass(FlightMath.rm_cost(prev_pos.distance_to(new_pos), burn))

	if FlightCore.has_arrived(new_pos, target):
		_arrive(target)
	else:
		var origin: Vector2 = order.get("origin", new_pos)
		_set_state(FlightCore.executing_state(origin, target, new_pos, burn))


func _arrive(target: Vector2) -> void:
	GameState.ship.position = target
	# Course complete: stop executing but keep the order so we know which body
	# we're holding at (and so a save records the orbit).
	GameState.ship.current_order["engaged"] = false
	_set_state(FlightCore.State.IN_ORBIT)


# --- Fuel (step 7) ---

func _spend_reaction_mass(amount: float) -> void:
	if amount <= 0.0:
		return
	GameState.ship.reaction_mass = maxf(0.0, GameState.ship.reaction_mass - amount)
	EventBus.fuel_changed.emit(Fuel.Pool.REACTION_MASS, GameState.ship.reaction_mass)


## Refuel to capacity when the ship is at a refuel-capable body (helm.md: Dock
## enables refuelling). The full Dock/Undock flow + crew voice land in step 8.
func _dock() -> void:
	var body := _body_at_ship()
	if body == null or not body.can_refuel:
		EventBus.order_rejected.emit("ORDER_REJECT_NOT_AT_STATION")
		return
	GameState.ship.reaction_mass = GameState.ship.max_reaction_mass
	EventBus.fuel_changed.emit(Fuel.Pool.REACTION_MASS, GameState.ship.reaction_mass)
	_acknowledge("VOICE_SHIP_DOCKED")


## The body the ship is currently sitting at (within arrival distance), or null.
func _body_at_ship() -> BodyData:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if FlightCore.has_arrived(GameState.ship.position, body.position):
			return body
	return null


# --- Lifecycle ---

## Recompute the flight state from the loaded order + geometry (transient ack
## beat is not persisted; resume directly in the executing phase).
func _resync_after_load() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		_set_state(FlightCore.State.IDLE)
		return
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
		_set_state(FlightCore.State.IDLE)
		return
	if FlightCore.has_arrived(GameState.ship.position, body.position):
		_set_state(FlightCore.State.IN_ORBIT)
	elif not bool(order.get("engaged", false)):
		_set_state(FlightCore.State.COURSE_SET)
	else:
		var origin: Vector2 = order.get("origin", GameState.ship.position)
		_set_state(FlightCore.executing_state(origin, body.position, GameState.ship.position,
			int(order.get("burn", FlightMath.Burn.STANDARD))))


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
