extends GutTest
## Runtime system loading (ADR 0024): GameState.load_system resets the run, and
## SystemLoader validates + announces. Snapshots GameState so it leaves no trace.

var _snapshot: Dictionary


func before_each() -> void:
	_snapshot = GameState.to_dict()


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_load_system_resets_ship_course_and_contacts() -> void:
	# Dirty the state as if mid-run in another system.
	GameState.ship.position = Vector2(99999.0, -99999.0)
	GameState.ship.current_order = {"type": "course", "engaged": true}
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = "verdant"
	GameState.contacts.set_tier("kepri_derelict", Sensors.Tier.IDENTIFIED)
	GameState.zones.mark_fired("some_trigger")

	var sol := TypeRegistry.get_system("sol")
	GameState.load_system(sol)

	assert_eq(GameState.system.system_id, "sol", "system id switched")
	assert_eq(GameState.ship.position, sol.ship_start, "ship reset to the new ship_start")
	assert_eq(GameState.ship.current_order, {}, "course cleared")
	assert_eq(GameState.ship.location, Travel.Location.DEEP_SPACE, "drifting in deep space")
	assert_eq(GameState.ship.location_body_id, "", "not holding/docked anywhere")
	assert_eq(GameState.contacts.tier_of("kepri_derelict"), Sensors.Tier.UNDETECTED,
		"transient discovery reset for the new system")
	assert_false(GameState.zones.has_fired("some_trigger"), "zone triggers re-arm in the new system")


func test_load_system_null_is_a_noop() -> void:
	GameState.system.system_id = "sol"
	GameState.load_system(null)
	assert_eq(GameState.system.system_id, "sol", "null system leaves state untouched")


func test_loader_loads_a_valid_system_and_announces() -> void:
	var loader := SystemLoader.new()
	add_child_autofree(loader)
	GameState.ship.position = Vector2(1.0, 2.0)
	watch_signals(EventBus)
	EventBus.system_change_requested.emit("sol")
	assert_eq(GameState.system.system_id, "sol", "loaded the requested system")
	assert_eq(GameState.ship.position, TypeRegistry.get_system("sol").ship_start, "ship reset")
	assert_signal_emitted(EventBus, "system_changed", "announced the change")


func test_loader_switches_to_calder_reach() -> void:
	var loader := SystemLoader.new()
	add_child_autofree(loader)
	GameState.system.system_id = "sol"
	watch_signals(EventBus)
	EventBus.system_change_requested.emit("calder")
	assert_eq(GameState.system.system_id, "calder", "switched to the second system")
	assert_eq(GameState.ship.position, TypeRegistry.get_system("calder").ship_start,
		"ship reset to Calder's start")
	assert_signal_emitted(EventBus, "system_changed")


func test_loader_ignores_an_unknown_system() -> void:
	var loader := SystemLoader.new()
	add_child_autofree(loader)
	GameState.system.system_id = "sol"
	watch_signals(EventBus)
	EventBus.system_change_requested.emit("does_not_exist")
	assert_signal_not_emitted(EventBus, "system_changed", "no announcement for an unknown id")
	assert_eq(GameState.system.system_id, "sol", "state unchanged")
