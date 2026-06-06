extends GutTest
## Pure flight FSM logic (ADR 0005). Movement clamping + phase derivation,
## independent of the exact tuning numbers.

const STD := FlightMath.Burn.STANDARD


func test_step_moves_toward_target_by_speed() -> void:
	var sp := FlightMath.speed_wu_per_tick(STD)
	var p := FlightCore.step_position(Vector2.ZERO, Vector2(1000.0, 0.0), STD)
	assert_almost_eq(p.x, sp, 0.0001, "moves one cruise step along x")
	assert_almost_eq(p.y, 0.0, 0.0001, "no drift off-axis")


func test_step_clamps_to_target_no_overshoot() -> void:
	var sp := FlightMath.speed_wu_per_tick(STD)
	# Target closer than one step → land exactly on it.
	var p := FlightCore.step_position(Vector2.ZERO, Vector2(sp * 0.5, 0.0), STD)
	assert_eq(p, Vector2(sp * 0.5, 0.0), "no overshoot on the final step")


func test_has_arrived_within_threshold() -> void:
	assert_true(FlightCore.has_arrived(Vector2(0.5, 0.0), Vector2.ZERO), "within 1 wu = arrived")
	assert_false(FlightCore.has_arrived(Vector2(50.0, 0.0), Vector2.ZERO), "far away = not arrived")


func test_phase_progression_along_course() -> void:
	var origin := Vector2.ZERO
	var target := Vector2(1000.0, 0.0)
	# 10% in → accelerating; 50% → cruising; 90% → decelerating.
	assert_eq(FlightCore.executing_state(origin, target, Vector2(100.0, 0.0), STD),
		FlightCore.State.ACCELERATING, "early course = accelerating")
	assert_eq(FlightCore.executing_state(origin, target, Vector2(500.0, 0.0), STD),
		FlightCore.State.CRUISING, "mid course = cruising")
	assert_eq(FlightCore.executing_state(origin, target, Vector2(820.0, 0.0), STD),
		FlightCore.State.DECELERATING, "late course = decelerating")


func test_phase_arriving_then_in_orbit() -> void:
	var origin := Vector2.ZERO
	var target := Vector2(1000.0, 0.0)
	var sp := FlightMath.speed_wu_per_tick(STD)
	# One step out → arriving.
	assert_eq(FlightCore.executing_state(origin, target, Vector2(1000.0 - sp * 0.5, 0.0), STD),
		FlightCore.State.ARRIVING, "final approach = arriving")
	# On the target → in orbit.
	assert_eq(FlightCore.executing_state(origin, target, target, STD),
		FlightCore.State.IN_ORBIT, "reached target = in orbit")


func test_state_key_maps_to_translation_keys() -> void:
	assert_eq(FlightCore.state_key(FlightCore.State.CRUISING), "FLIGHT_STATE_CRUISING")
	assert_eq(FlightCore.state_key(FlightCore.State.IN_ORBIT), "FLIGHT_STATE_IN_ORBIT")
