extends GutTest
## FlightController: the order lifecycle + tick-driven execution against the live
## GameState/TypeRegistry/EventBus. Snapshots GameState so it leaves no trace.

var _snapshot: Dictionary
var _fc: FlightController


func before_each() -> void:
	_snapshot = GameState.to_dict()
	# Known start: in Sol, drifting at a fixed point, clock frozen so the live
	# SimClock can't inject real ticks mid-assertion.
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	GameState.ship.position = Vector2.ZERO
	GameState.clock.speed = 0.0
	_fc = FlightController.new()
	add_child_autofree(_fc)


func after_each() -> void:
	GameState.from_dict(_snapshot)


func _find(id: String) -> BodyData:
	for b: BodyData in TypeRegistry.get_system("sol").bodies:
		if b.id == id:
			return b
	return null


func test_set_course_lays_in_and_acknowledges() -> void:
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.STANDARD})
	assert_eq(_fc.get_state(), FlightCore.State.COURSE_SET, "course laid in")
	assert_eq(GameState.ship.current_order.get("target_id"), "verdant", "order stored in ShipState")
	assert_false(GameState.ship.current_order.get("engaged"), "not yet engaged")
	assert_signal_emitted(EventBus, "order_acknowledged", "the helm acknowledges")


func test_set_course_rejects_unknown_target() -> void:
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "set_course", "target_id": "nowhere", "burn": FlightMath.Burn.STANDARD})
	assert_signal_emitted(EventBus, "order_rejected", "unknown target rejected")
	assert_eq(_fc.get_state(), FlightCore.State.IDLE, "no course set")


func test_engage_then_fly_to_arrival() -> void:
	var verdant := _find("verdant")
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.HARD})
	EventBus.order_issued.emit({"type": "engage"})
	assert_eq(_fc.get_state(), FlightCore.State.ENGAGING, "engage starts with the ack beat")

	var start_dist := GameState.ship.position.distance_to(verdant.position)
	# One tick: ship should be closer and out of the ENGAGING beat.
	EventBus.sim_tick.emit(1)
	assert_lt(GameState.ship.position.distance_to(verdant.position), start_dist, "moved toward target")
	assert_ne(_fc.get_state(), FlightCore.State.ENGAGING, "first tick begins the burn")

	# Run the clock out; must arrive and settle into orbit.
	for i in range(200):
		if _fc.get_state() == FlightCore.State.IN_ORBIT:
			break
		EventBus.sim_tick.emit(i + 2)
	assert_eq(_fc.get_state(), FlightCore.State.IN_ORBIT, "reaches orbit")
	assert_true(FlightCore.has_arrived(GameState.ship.position, verdant.position), "parked on the body")


func test_belay_aborts_back_to_course_set() -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.STANDARD})
	EventBus.order_issued.emit({"type": "engage"})
	EventBus.sim_tick.emit(1)
	var pos_at_belay := GameState.ship.position
	EventBus.order_belayed.emit()
	assert_eq(_fc.get_state(), FlightCore.State.COURSE_SET, "abort returns to course-set (ADR 0005)")
	assert_false(GameState.ship.current_order.get("engaged"), "no longer executing")
	# Further ticks must not move the ship while belayed.
	EventBus.sim_tick.emit(2)
	assert_eq(GameState.ship.position, pos_at_belay, "belayed ship holds position")


func test_all_stop_clears_order_and_idles() -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.STANDARD})
	EventBus.order_issued.emit({"type": "all_stop"})
	assert_eq(_fc.get_state(), FlightCore.State.IDLE, "all stop -> idle")
	assert_eq(GameState.ship.current_order, {}, "order cleared")


func test_resync_after_load_resumes_executing() -> void:
	var rubicon := _find("rubicon")
	# Simulate a mid-flight save: an engaged order partway along, then a load.
	GameState.ship.position = (rubicon.position) * 0.5
	GameState.ship.current_order = {
		"type": "course", "target_id": "rubicon",
		"burn": FlightMath.Burn.STANDARD, "engaged": true, "origin": Vector2.ZERO,
	}
	EventBus.game_state_loaded.emit()
	var s := _fc.get_state()
	assert_true(
		s == FlightCore.State.ACCELERATING or s == FlightCore.State.CRUISING or s == FlightCore.State.DECELERATING,
		"resumes mid-flight in an executing phase, not the ack beat"
	)
