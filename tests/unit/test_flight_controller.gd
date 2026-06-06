extends GutTest
## FlightController travel pipeline (ADR 0015): lay-in → engage → fly → hold, plus
## dock/undock, belay, all-stop, and load-resume. Runs against the live
## GameState/TypeRegistry/EventBus; snapshots GameState so it leaves no trace.

var _snapshot: Dictionary
var _fc: FlightController


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	GameState.ship.position = Vector2.ZERO  # deep space
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


func _fly_to(target_id: String, burn: int) -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": target_id, "burn": burn})
	EventBus.order_issued.emit({"type": "engage"})
	for i in range(2000):
		if GameState.ship.location == Travel.Location.HOLDING:
			return
		EventBus.sim_tick.emit(i + 1)


func test_lay_in_stores_course_without_moving() -> void:
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.STANDARD})
	assert_eq(GameState.ship.current_order.get("target_id"), "verdant", "course stored")
	assert_false(GameState.ship.current_order.get("engaged"), "not yet engaged")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "still drifting")
	assert_signal_emitted(EventBus, "order_acknowledged", "the helm acknowledges")


func test_lay_in_rejects_unknown_target() -> void:
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "set_course", "target_id": "nowhere", "burn": FlightMath.Burn.STANDARD})
	assert_signal_emitted(EventBus, "order_rejected")
	assert_eq(GameState.ship.current_order, {}, "no course stored")


func test_engage_then_fly_into_holding() -> void:
	var verdant := _find("verdant")
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.HARD})
	EventBus.order_issued.emit({"type": "engage"})
	assert_eq(_fc.get_state(), FlightCore.State.ENGAGING, "engage starts with the ack beat")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "departed into open space")

	EventBus.sim_tick.emit(1)
	assert_ne(_fc.get_state(), FlightCore.State.ENGAGING, "first tick begins the burn")

	for i in range(2000):
		if GameState.ship.location == Travel.Location.HOLDING:
			break
		EventBus.sim_tick.emit(i + 2)
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "arrives into the holding area")
	assert_eq(GameState.ship.location_body_id, "verdant", "holding at the target")
	assert_eq(GameState.ship.current_order, {}, "course consumed on arrival")
	assert_eq(_fc.get_state(), FlightCore.State.IDLE, "motion idle once arrived")
	assert_almost_eq(GameState.ship.position.distance_to(verdant.position),
		Travel.holding_radius(verdant.radius), 1.0, "holds on the orbit ring, not the body centre")


func test_holding_orbit_advances_on_the_ring() -> void:
	var verdant := _find("verdant")
	_fly_to("verdant", FlightMath.Burn.HARD)
	var p1: Vector2 = GameState.ship.position
	_fc._advance_holding_orbit(2.0)  # 2 (speed-scaled) seconds of orbit
	var p2: Vector2 = GameState.ship.position
	assert_ne(p1, p2, "the ship moves along its orbit over time")
	assert_almost_eq(p2.distance_to(verdant.position), Travel.holding_radius(verdant.radius), 0.5,
		"orbit stays on the holding ring")
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "still holding")


func test_departing_orbit_leaves_from_the_ring_not_the_centre() -> void:
	var verdant := _find("verdant")
	_fly_to("verdant", FlightMath.Burn.STANDARD)
	GameState.ship.reaction_mass = 100.0  # top up so the departure isn't fuel-gated
	var hold_pos: Vector2 = GameState.ship.position
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.STANDARD})
	EventBus.order_issued.emit({"type": "engage"})
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "departed")
	assert_eq(GameState.ship.current_order.get("origin"), hold_pos, "course starts from the orbit point")
	assert_almost_eq(GameState.ship.position.distance_to(verdant.position),
		Travel.holding_radius(verdant.radius), 1.0, "did not jump to the body centre")


func test_belay_keeps_course_for_re_engage() -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.STANDARD})
	EventBus.order_issued.emit({"type": "engage"})
	EventBus.sim_tick.emit(1)
	var pos := GameState.ship.position
	EventBus.order_belayed.emit()
	assert_false(GameState.ship.current_order.get("engaged"), "no longer under way")
	assert_eq(GameState.ship.current_order.get("target_id"), "rubicon", "course stays laid in")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "drifting in open space")
	EventBus.sim_tick.emit(2)
	assert_eq(GameState.ship.position, pos, "belayed ship holds position")


func test_all_stop_drops_the_course() -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.STANDARD})
	EventBus.order_issued.emit({"type": "engage"})
	EventBus.sim_tick.emit(1)
	EventBus.order_issued.emit({"type": "all_stop"})
	assert_eq(GameState.ship.current_order, {}, "course dropped")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "drifting")
	assert_eq(_fc.get_state(), FlightCore.State.IDLE)


func test_dock_then_undock_at_station() -> void:
	_fly_to("anchorage", FlightMath.Burn.STANDARD)
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "holding at the station")
	GameState.ship.reaction_mass = 10.0

	EventBus.order_issued.emit({"type": "dock"})
	assert_eq(GameState.ship.location, Travel.Location.DOCKED, "docked")
	assert_eq(GameState.ship.reaction_mass, GameState.ship.max_reaction_mass, "refuelled on docking")

	EventBus.order_issued.emit({"type": "undock"})
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "undocked back to holding")


func test_engage_refused_while_docked() -> void:
	GameState.ship.location = Travel.Location.DOCKED
	GameState.ship.location_body_id = "anchorage"
	GameState.ship.position = _find("anchorage").position
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.STANDARD})
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "engage"})
	assert_signal_emitted(EventBus, "order_rejected", "must undock before engaging")
	assert_false(GameState.ship.current_order.get("engaged"), "did not depart")


func test_lay_in_rejected_to_current_location() -> void:
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = "verdant"
	GameState.ship.position = _find("verdant").position
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.STANDARD})
	assert_signal_emitted(EventBus, "order_rejected", "can't plot a course to where we already are")


func test_resync_after_load_resumes_transit() -> void:
	var rubicon := _find("rubicon")
	GameState.ship.position = rubicon.position * 0.5
	GameState.ship.current_order = {
		"type": "course", "target_id": "rubicon",
		"burn": FlightMath.Burn.STANDARD, "engaged": true, "origin": Vector2.ZERO,
	}
	EventBus.game_state_loaded.emit()
	var s := _fc.get_state()
	assert_true(
		s == FlightCore.State.ACCELERATING or s == FlightCore.State.CRUISING or s == FlightCore.State.DECELERATING,
		"resumes mid-flight in a transit phase, not the ack beat"
	)
