extends GutTest
## Save/load round-trip on the live GameState autoload (ADR 0008). Snapshots and
## restores GameState around each test, and removes the save artifact, so it
## leaves no trace for other suites.

var _snapshot: Dictionary


func before_each() -> void:
	_snapshot = GameState.to_dict()
	# Freeze the live clock so background _process ticks can't perturb assertions.
	GameState.clock.speed = 0.0
	_remove_save()


func after_each() -> void:
	GameState.from_dict(_snapshot)
	_remove_save()


func _remove_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save_0.sav"):
		dir.remove("save_0.sav")


func test_round_trip_restores_every_field() -> void:
	GameState.clock.tick = 42
	GameState.clock.speed = 2.0
	GameState.ship.hull_id = "scout"
	GameState.ship.position = Vector2(123.5, -67.0)
	GameState.ship.heading = 1.25
	GameState.ship.reaction_mass = 73.5
	GameState.ship.current_order = {"type": "course", "target_id": "mars", "burn": 2}
	GameState.system.system_id = "sol"

	assert_true(SaveManager.save_game(), "save succeeds")

	# Wipe in-memory state to prove load actually restores it.
	GameState.new_game()
	assert_eq(GameState.clock.tick, 0, "state cleared before load")

	assert_true(SaveManager.load_game(), "load succeeds")
	assert_eq(GameState.clock.tick, 42, "tick restored")
	assert_eq(GameState.clock.speed, 2.0, "speed restored")
	assert_eq(GameState.ship.hull_id, "scout", "hull id restored")
	assert_eq(GameState.ship.position, Vector2(123.5, -67.0), "Vector2 position restored")
	assert_almost_eq(GameState.ship.heading, 1.25, 0.0001, "heading restored")
	assert_almost_eq(GameState.ship.reaction_mass, 73.5, 0.0001, "reaction mass restored")
	assert_eq(GameState.ship.current_order.get("target_id"), "mars", "active order restored")
	assert_eq(GameState.system.system_id, "sol", "system id restored")


func test_save_stamps_game_and_schema_version() -> void:
	assert_true(SaveManager.save_game(), "save succeeds")
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	assert_not_null(file, "save file exists")
	var payload: Dictionary = str_to_var(file.get_as_text())
	file.close()
	assert_eq(payload.get("game_version"), GameVersion.GAME_VERSION, "game version stamped")
	assert_eq(payload.get("schema_version"), GameVersion.SAVE_SCHEMA_VERSION, "schema version stamped")
	assert_true(payload.has("state"), "state tree present under 'state'")


func test_load_emits_game_state_loaded() -> void:
	SaveManager.save_game()
	watch_signals(EventBus)
	assert_true(SaveManager.load_game(), "load succeeds")
	assert_signal_emitted(EventBus, "game_state_loaded", "load announces on the bus")


func test_load_returns_false_without_a_save() -> void:
	_remove_save()
	assert_false(SaveManager.has_save(), "no save present")
	assert_false(SaveManager.load_game(), "load is a no-op without a save")


func test_load_tolerates_partial_save() -> void:
	# A save missing whole branches (e.g. an older schema) must still load,
	# filling the gaps with defaults (ADR 0008 forgiving load).
	var partial := {
		"game_version": "0.0.1",
		"schema_version": GameVersion.SAVE_SCHEMA_VERSION,
		"state": {"clock": {"tick": 7}},
	}
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(var_to_str(partial))
	file.close()

	GameState.new_game()
	assert_true(SaveManager.load_game(), "partial save still loads")
	assert_eq(GameState.clock.tick, 7, "present value honoured")
	assert_eq(GameState.clock.speed, 1.0, "missing speed -> default")
	assert_eq(GameState.ship.hull_id, "scout", "missing ship branch -> defaults")
	assert_eq(GameState.system.system_id, "", "missing system branch -> default")
