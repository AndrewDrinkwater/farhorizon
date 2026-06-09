extends GutTest
## Debug command runner (ADR 0024). Dev tool that mutates GameState + emits the
## existing change signals. Snapshots GameState so it leaves no trace.

var _snapshot: Dictionary


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_help_and_systems_list() -> void:
	assert_string_contains(DebugActions.run("help"), "system")
	assert_string_contains(DebugActions.run("systems"), "sol")


func test_system_requests_a_valid_change_and_rejects_unknown() -> void:
	watch_signals(EventBus)
	DebugActions.run("system sol")
	assert_signal_emitted(EventBus, "system_change_requested", "valid id requests a change")
	var out := DebugActions.run("system nope")
	assert_string_contains(out, "no such system")


func test_refuel_fills_the_tank_and_emits() -> void:
	GameState.ship.reaction_mass = 1.0
	watch_signals(EventBus)
	DebugActions.run("refuel")
	assert_eq(GameState.ship.reaction_mass, GameState.ship.max_reaction_mass, "tank filled")
	assert_signal_emitted(EventBus, "fuel_changed")


func test_tp_to_coordinates() -> void:
	watch_signals(EventBus)
	DebugActions.run("tp 1234 -56")
	assert_eq(GameState.ship.position, Vector2(1234.0, -56.0), "teleported to the point")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "drifting after tp")
	assert_eq(GameState.ship.current_order, {}, "course cleared")
	assert_signal_emitted(EventBus, "ship_context_changed")


func test_tp_to_a_body_id() -> void:
	var verdant: BodyData = null
	for b: BodyData in TypeRegistry.get_system("sol").bodies:
		if b.id == "verdant":
			verdant = b
	DebugActions.run("tp verdant")
	assert_eq(GameState.ship.position, verdant.position, "teleported onto the body")


func test_tp_unknown_body_is_reported() -> void:
	assert_string_contains(DebugActions.run("tp nowhere"), "no such body")


func test_unknown_command() -> void:
	assert_string_contains(DebugActions.run("frobnicate"), "unknown command")
