extends Node
## SaveManager — schema-versioned serialize/deserialize of GameState (ADR 0008).
##
## Walks the one GameState tree; no system serializes itself. Load is forgiving
## about missing keys, and migrates older schema versions forward.
##
## SCAFFOLD STUB — real save/load + migration land in build-order step 3.

const SAVE_PATH: String = "user://save_0.tres"


func save_game() -> void:
	# TODO(step 3): write GameState.to_dict() + GameVersion stamps to SAVE_PATH.
	pass


func load_game() -> bool:
	# TODO(step 3): read SAVE_PATH, migrate by schema_version, GameState.from_dict().
	# Returns true on success.
	return false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
