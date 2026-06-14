extends GutTest
## FlightController travel pipeline (ADR 0015): lay-in → engage → fly → hold, plus
## dock/undock, all-stop, and load-resume. Runs against the live
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
		Travel.holding_radius(verdant), 1.0, "holds on the orbit ring, not the body centre")


func test_holding_orbit_advances_on_the_ring() -> void:
	var verdant := _find("verdant")
	_fly_to("verdant", FlightMath.Burn.HARD)
	var p1: Vector2 = GameState.ship.position
	_fc._advance_holding_orbit(2.0)  # 2 (speed-scaled) seconds of orbit
	var p2: Vector2 = GameState.ship.position
	assert_ne(p1, p2, "the ship moves along its orbit over time")
	assert_almost_eq(p2.distance_to(verdant.position), Travel.holding_radius(verdant), 0.5,
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
		Travel.holding_radius(verdant), 1.0, "did not jump to the body centre")


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

	# Dock is now a timed approach (ADR 0033): begins DOCKING, completes after the ticks.
	EventBus.order_issued.emit({"type": "dock"})
	assert_eq(_fc.get_state(), FlightCore.State.DOCKING, "docking begins, not instant")
	assert_ne(GameState.ship.location, Travel.Location.DOCKED, "not docked yet")
	for i in range(20):
		if GameState.ship.location == Travel.Location.DOCKED:
			break
		EventBus.sim_tick.emit(i + 1)
	assert_eq(GameState.ship.location, Travel.Location.DOCKED, "docked after the timed approach")
	assert_eq(GameState.ship.reaction_mass, GameState.ship.max_reaction_mass, "refuelled on arrival")

	EventBus.order_issued.emit({"type": "undock"})
	assert_eq(_fc.get_state(), FlightCore.State.UNDOCKING, "undocking begins")
	for i in range(20):
		if GameState.ship.location == Travel.Location.HOLDING:
			break
		EventBus.sim_tick.emit(i + 50)
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "undocked back to holding")


func test_dock_takes_base_dock_ticks() -> void:
	_hold_at("anchorage")
	GameState.ship.base_dock_ticks = 3
	EventBus.order_issued.emit({"type": "dock"})
	EventBus.sim_tick.emit(1)
	EventBus.sim_tick.emit(2)
	assert_ne(GameState.ship.location, Travel.Location.DOCKED, "still approaching at tick 2 of 3")
	EventBus.sim_tick.emit(3)
	assert_eq(GameState.ship.location, Travel.Location.DOCKED, "docked exactly at base_dock_ticks")


func test_dock_resync_resumes_an_in_progress_approach() -> void:
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = "anchorage"
	GameState.ship.current_order = {"type": "dock", "ticks_total": 4, "ticks_left": 2}
	EventBus.game_state_loaded.emit()
	assert_eq(_fc.get_state(), FlightCore.State.DOCKING, "resumes the dock approach on load")


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


func test_scan_identifies_after_its_timed_duration() -> void:
	# ADR 0017: scan is timed, not instant — identifies only after base_scan_ticks.
	var kepri := _contact("kepri_derelict")
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.BLIP)
	GameState.ship.position = kepri.position  # right on top of it -> in range
	GameState.ship.base_scan_ticks = 3
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "scan", "contact_id": "kepri_derelict"})
	assert_signal_emitted(EventBus, "scan_started", "scan begins")
	assert_eq(GameState.contacts.tier_of("kepri_derelict"), Sensors.Tier.BLIP, "not identified until it completes")
	for i in range(3):
		EventBus.sim_tick.emit(i + 1)
	assert_eq(GameState.contacts.tier_of("kepri_derelict"), Sensors.Tier.IDENTIFIED, "identified after its duration")
	assert_signal_emitted(EventBus, "contact_promoted", "promotion announced")


func test_scan_interrupted_when_the_contact_leaves_range() -> void:
	var kepri := _contact("kepri_derelict")
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.BLIP)
	GameState.ship.position = kepri.position
	GameState.ship.base_scan_ticks = 5
	EventBus.order_issued.emit({"type": "scan", "contact_id": "kepri_derelict"})
	EventBus.sim_tick.emit(1)  # one tick of progress
	GameState.ship.position = kepri.position + Vector2(GameState.ship.sensor_range + 1000.0, 0.0)
	watch_signals(EventBus)
	EventBus.sim_tick.emit(2)  # now out of range -> interrupted
	assert_signal_emitted(EventBus, "scan_interrupted", "leaving range interrupts the scan")
	assert_eq(GameState.contacts.tier_of("kepri_derelict"), Sensors.Tier.BLIP, "stays a blip")
	assert_eq(GameState.ship.scan_contact_id, "", "scan cleared")


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


func _hold_at(body_id: String) -> void:
	var b := _find(body_id)
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = body_id
	GameState.ship.position = b.position + Vector2(Travel.holding_radius(b), 0.0)


func test_land_then_take_off() -> void:
	_hold_at("verdant")  # Sol Verdant is landable (0.9 atm)
	EventBus.order_issued.emit({"type": "land", "site_id": ""})
	assert_eq(_fc.get_state(), FlightCore.State.DESCENDING, "descent begins")
	for i in range(50):
		if GameState.ship.location == Travel.Location.LANDED:
			break
		EventBus.sim_tick.emit(i + 1)
	assert_eq(GameState.ship.location, Travel.Location.LANDED, "landed after the descent")
	assert_eq(GameState.ship.surface_site_id, "", "Open Landing")

	EventBus.order_issued.emit({"type": "take_off"})
	assert_eq(_fc.get_state(), FlightCore.State.ASCENDING, "ascent begins")
	for i in range(50):
		if GameState.ship.location == Travel.Location.HOLDING:
			break
		EventBus.sim_tick.emit(i + 100)
	assert_eq(GameState.ship.location, Travel.Location.HOLDING, "back in orbit after take-off")


func test_land_rejected_on_a_non_landable_body() -> void:
	_hold_at("anchorage")  # a station, not landable
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "land", "site_id": ""})
	assert_signal_emitted(EventBus, "order_rejected", "can't land on a non-landable body")
	assert_ne(GameState.ship.location, Travel.Location.LANDED)


func test_surface_move_changes_site() -> void:
	_hold_at("verdant")
	EventBus.order_issued.emit({"type": "land", "site_id": ""})  # Open Landing
	for i in range(50):
		if GameState.ship.location == Travel.Location.LANDED:
			break
		EventBus.sim_tick.emit(i + 1)
	EventBus.order_issued.emit({"type": "move", "site_id": "verdant_outpost"})
	assert_eq(_fc.get_state(), FlightCore.State.SURFACE_MOVING, "surface move begins")
	var outpost_pos: Vector2 = GameState.ship.current_order.get("to")
	# Per-frame glide: a small advance moves partway, not all the way (smooth).
	_fc._advance_surface_move(0.02 * GameState.ship.surface_speed_su_per_tick)
	assert_gt(GameState.ship.surface_position.length(), 0.0, "moved off the start")
	assert_ne(GameState.ship.surface_site_id, "verdant_outpost", "not arrived after one frame")
	# Plenty of time → arrives.
	_fc._advance_surface_move(1000.0)
	assert_eq(GameState.ship.surface_site_id, "verdant_outpost", "arrived at the site")
	assert_eq(GameState.ship.surface_position, outpost_pos, "ship rests at the site position")
	assert_eq(GameState.ship.location, Travel.Location.LANDED, "still landed after the move")


func test_resync_resumes_an_in_progress_descent() -> void:
	# As if a save was loaded mid-descent (ADR 0029 persistence).
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = "verdant"
	GameState.ship.current_order = {"type": "land", "site_id": "", "ticks_total": 8, "ticks_left": 3}
	EventBus.game_state_loaded.emit()
	assert_eq(_fc.get_state(), FlightCore.State.DESCENDING, "resumes the descent phase on load")
	for i in range(10):
		if GameState.ship.location == Travel.Location.LANDED:
			break
		EventBus.sim_tick.emit(i + 1)
	assert_eq(GameState.ship.location, Travel.Location.LANDED, "descent completes from the saved ticks")


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
