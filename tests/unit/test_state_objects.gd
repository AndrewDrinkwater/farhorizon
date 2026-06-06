extends GutTest
## Per-object to_dict/from_dict round-trips + forgiving rebuild (ADR 0002/0008).
## Pure data classes — no engine state involved.


func test_clock_state_round_trip() -> void:
	var c := ClockState.new()
	c.tick = 99
	c.speed = 4.0
	var back := ClockState.from_dict(c.to_dict())
	assert_eq(back.tick, 99)
	assert_eq(back.speed, 4.0)


func test_ship_state_round_trip() -> void:
	var s := ShipState.new()
	s.hull_id = "courier"
	s.position = Vector2(12.5, -3.0)
	s.heading = 2.0
	s.reaction_mass = 42.0
	s.max_reaction_mass = 120.0
	s.current_order = {"type": "course", "target_id": "station_alpha", "burn": 1}
	var back := ShipState.from_dict(s.to_dict())
	assert_eq(back.hull_id, "courier")
	assert_eq(back.position, Vector2(12.5, -3.0))
	assert_almost_eq(back.heading, 2.0, 0.0001)
	assert_almost_eq(back.reaction_mass, 42.0, 0.0001)
	assert_almost_eq(back.max_reaction_mass, 120.0, 0.0001)
	assert_eq(back.current_order.get("target_id"), "station_alpha")


func test_system_state_round_trip() -> void:
	var sys := SystemState.new()
	sys.system_id = "sol"
	var back := SystemState.from_dict(sys.to_dict())
	assert_eq(back.system_id, "sol")


func test_forgiving_from_dict_uses_defaults() -> void:
	# Empty / partial dicts must not crash and must fall back to defaults.
	var clock := ClockState.from_dict({})
	assert_eq(clock.tick, 0, "missing tick -> default")
	assert_eq(clock.speed, 1.0, "missing speed -> default")

	var ship := ShipState.from_dict({"position": Vector2(1.0, 2.0)})
	assert_eq(ship.position, Vector2(1.0, 2.0), "present key honoured")
	assert_eq(ship.hull_id, "scout", "missing hull_id -> default")
	assert_eq(ship.reaction_mass, 100.0, "missing reaction_mass -> default")
	assert_eq(ship.current_order, {}, "missing order -> empty")
