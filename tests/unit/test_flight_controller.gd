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


func _contact(id: String) -> ContactData:
	for c: ContactData in TypeRegistry.get_system("sol").contacts:
		if c.id == id:
			return c
	return null


func test_course_to_a_free_point_flies_there_and_drifts() -> void:
	var dest := Vector2(4000.0, 1500.0)
	GameState.ship.position = Vector2.ZERO
	GameState.ship.reaction_mass = 100.0
	EventBus.order_issued.emit({"type": "set_course", "target_id": "", "point": dest,
		"burn": FlightMath.Burn.HARD})
	assert_eq(GameState.ship.current_order.get("dest"), dest, "free-point destination stored")
	EventBus.order_issued.emit({"type": "engage"})
	for i in range(2000):
		if not bool(GameState.ship.current_order.get("engaged", false)):
			break
		EventBus.sim_tick.emit(i + 1)
	assert_almost_eq(GameState.ship.position.distance_to(dest), 0.0, 1.0, "arrived on the point")
	assert_eq(GameState.ship.current_order, {}, "course consumed on arrival")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "drifts in deep space (no hold)")
	assert_eq(_fc.get_state(), FlightCore.State.IDLE, "idle once arrived")


func test_course_to_a_detected_contact_flies_to_it() -> void:
	var kepri := _contact("kepri_derelict")
	assert_not_null(kepri, "sol has the kepri contact")
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.BLIP)  # detected, so plottable
	GameState.ship.position = Vector2.ZERO
	GameState.ship.reaction_mass = 100.0
	EventBus.order_issued.emit({"type": "set_course", "target_id": "kepri_derelict",
		"burn": FlightMath.Burn.HARD})
	EventBus.order_issued.emit({"type": "engage"})
	for i in range(2000):
		if not bool(GameState.ship.current_order.get("engaged", false)):
			break
		EventBus.sim_tick.emit(i + 1)
	assert_almost_eq(GameState.ship.position.distance_to(kepri.position), 0.0, 1.0, "reached the contact")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "drifts beside the contact")


func test_course_to_an_undetected_contact_is_rejected() -> void:
	watch_signals(EventBus)
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.UNDETECTED)
	EventBus.order_issued.emit({"type": "set_course", "target_id": "kepri_derelict",
		"burn": FlightMath.Burn.STANDARD})
	assert_signal_emitted(EventBus, "order_rejected", "can't plot to a contact you haven't detected")
	assert_eq(GameState.ship.current_order, {}, "no course stored")


func test_scan_in_range_identifies_a_contact() -> void:
	var kepri := _contact("kepri_derelict")
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.BLIP)
	GameState.ship.position = kepri.position  # right on top of it -> in range
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "scan", "contact_id": "kepri_derelict"})
	assert_eq(GameState.contacts.tier_of("kepri_derelict"), Sensors.Tier.IDENTIFIED, "scan identifies")
	assert_signal_emitted(EventBus, "contact_promoted", "promotion announced")


func test_scan_out_of_range_is_rejected() -> void:
	var kepri := _contact("kepri_derelict")
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.BLIP)
	GameState.ship.position = kepri.position + Vector2(GameState.ship.sensor_range + 1000.0, 0.0)
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "scan", "contact_id": "kepri_derelict"})
	assert_signal_emitted(EventBus, "order_rejected", "too far to scan")
	assert_eq(GameState.contacts.tier_of("kepri_derelict"), Sensors.Tier.BLIP, "tier unchanged")


func test_flies_a_route_through_a_waypoint() -> void:
	# sol has no zones; route ZERO → (0,500) → verdant, passing the waypoint.
	var verdant := _find("verdant")
	GameState.ship.reaction_mass = 100.0
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant",
		"waypoints": [Vector2(0.0, 500.0)], "burn": FlightMath.Burn.HARD})
	assert_eq(GameState.ship.current_order.get("waypoints").size(), 1, "waypoint stored")
	EventBus.order_issued.emit({"type": "engage"})
	for i in range(3000):
		if GameState.ship.location == Travel.Location.HOLDING:
			break
		EventBus.sim_tick.emit(i + 1)
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "arrives at the final target")
	assert_eq(GameState.ship.location_body_id, "verdant", "holding at the route's destination")
	assert_eq(GameState.ship.current_order, {}, "route consumed on arrival")


func test_course_through_a_nogo_lays_in_but_engage_is_blocked() -> void:
	GameState.system.system_id = "calder"  # has the corona no-go at the origin
	GameState.ship.position = Vector2(1000.0, 0.0)
	GameState.ship.reaction_mass = 100.0
	# Direct leg across the star crosses the corona — it still LAYS IN now (ADR 0028).
	EventBus.order_issued.emit({"type": "set_course", "target_id": "", "point": Vector2(-1000.0, 0.0),
		"burn": FlightMath.Burn.STANDARD})
	assert_eq(GameState.ship.current_order.get("type"), "course", "course laid in (drawn red, not blocked)")
	# But Engage is refused while a leg crosses the no-go.
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "engage"})
	assert_signal_emitted(EventBus, "order_rejected", "engage blocked by the no-go")
	assert_false(bool(GameState.ship.current_order.get("engaged", false)), "did not depart")
	# Re-laying with a waypoint around the corona clears every leg → engage departs.
	EventBus.order_issued.emit({"type": "set_course", "target_id": "", "point": Vector2(-1000.0, 0.0),
		"waypoints": [Vector2(0.0, 3000.0)], "burn": FlightMath.Burn.STANDARD})
	EventBus.order_issued.emit({"type": "engage"})
	assert_true(bool(GameState.ship.current_order.get("engaged", false)), "departs once routed clear")


func test_clear_course_drops_a_laid_in_course_when_idle() -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": "verdant", "burn": FlightMath.Burn.STANDARD})
	assert_eq(GameState.ship.current_order.get("type"), "course", "laid in")
	EventBus.order_issued.emit({"type": "clear_course"})
	assert_eq(GameState.ship.current_order, {}, "Clear Course removes the plotted course")


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
