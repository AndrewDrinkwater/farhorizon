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


func test_contacts_state_round_trip() -> void:
	var c := ContactsState.new()
	c.set_tier("kepri_derelict", Sensors.Tier.BLIP)
	c.set_tier("veil_anomaly", Sensors.Tier.IDENTIFIED)
	var back := ContactsState.from_dict(c.to_dict())
	assert_eq(back.tier_of("kepri_derelict"), Sensors.Tier.BLIP)
	assert_eq(back.tier_of("veil_anomaly"), Sensors.Tier.IDENTIFIED)
	assert_eq(back.tier_of("unknown"), Sensors.Tier.UNDETECTED, "absent = undetected")


func test_ship_state_surface_fields_round_trip() -> void:
	var s := ShipState.new()
	s.location = Travel.Location.LANDED
	s.surface_site_id = "verdant_outpost"
	s.surface_speed_su_per_tick = 75.0
	s.base_descent_ticks = 9
	s.current_order = {"type": "surface_move", "site_id": "x", "ticks_left": 2, "ticks_total": 5}
	var back := ShipState.from_dict(s.to_dict())
	assert_eq(back.location, Travel.Location.LANDED, "landed location persists")
	assert_eq(back.surface_site_id, "verdant_outpost", "surface site persists (ADR 0030)")
	assert_almost_eq(back.surface_speed_su_per_tick, 75.0, 0.001)
	assert_eq(back.base_descent_ticks, 9)
	assert_eq(int(back.current_order.get("ticks_left")), 2, "in-progress transition persists")


func test_ship_state_dock_stats_round_trip() -> void:
	var s := ShipState.new()
	s.base_dock_ticks = 7
	s.base_undock_ticks = 5
	var back := ShipState.from_dict(s.to_dict())
	assert_eq(back.base_dock_ticks, 7, "dock-time stat persists (ADR 0033)")
	assert_eq(back.base_undock_ticks, 5)


func test_zones_state_round_trip() -> void:
	var z := ZonesState.new()
	z.mark_fired("drift_signal")
	var back := ZonesState.from_dict(z.to_dict())
	assert_true(back.has_fired("drift_signal"), "fired one-shot trigger remembered")
	assert_false(back.has_fired("calder_corona"), "absent = not fired")


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
