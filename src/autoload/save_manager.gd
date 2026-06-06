extends Node
## SaveManager — schema-versioned serialize/deserialize of GameState (ADR 0008).
##
## Walks the one GameState tree; no system serializes itself. The save is a
## version-stamped payload written with var_to_str (which round-trips Godot types
## like Vector2 cleanly and is human-readable). Load is forgiving about missing
## keys (ADR 0002/0008) and runs migration hooks for older schema versions.

const SAVE_PATH: String = "user://save_0.sav"


## Write GameState + version stamps to disk. Returns true on success.
func save_game() -> bool:
	var payload: Dictionary = {
		"game_version": GameVersion.GAME_VERSION,
		"schema_version": GameVersion.SAVE_SCHEMA_VERSION,
		"state": GameState.to_dict(),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for write (err %d)" % [
			SAVE_PATH, FileAccess.get_open_error(),
		])
		return false
	file.store_string(var_to_str(payload))
	file.close()
	return true


## Read the save, migrate it forward, rebuild GameState, announce on the bus.
## Returns true on success; false if there's no save or it's unreadable/corrupt.
func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot open %s for read (err %d)" % [
			SAVE_PATH, FileAccess.get_open_error(),
		])
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = str_to_var(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: save at %s is not a valid payload" % SAVE_PATH)
		return false
	var payload: Dictionary = parsed

	var from_schema: int = int(payload.get("schema_version", 0))
	var state: Dictionary = payload.get("state", {})
	state = _migrate(state, from_schema)

	GameState.from_dict(state)
	EventBus.game_state_loaded.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Bring an older save's state dict up to the current SCHEMA_VERSION. No
## migrations exist yet (current schema = 1); this is the hook each future bump
## adds a step to. Forgiving from_dict already covers purely additive changes.
func _migrate(state: Dictionary, from_schema: int) -> Dictionary:
	if from_schema == GameVersion.SAVE_SCHEMA_VERSION:
		return state
	# Future: apply ordered migration steps for from_schema < current here.
	return state
