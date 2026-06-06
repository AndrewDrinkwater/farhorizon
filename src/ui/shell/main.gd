extends Node
## Main entry scene (the terminal shell root).
##
## SCAFFOLD placeholder — proves the project boots and the autoloads load.
## The persistent terminal shell + Helm console replace this in build-order
## step 8. See docs/consoles/helm.md.


func _ready() -> void:
	var label := Label.new()
	label.position = Vector2(40.0, 40.0)
	label.text = "FAR HORIZON  v%s\nscaffold online — autoloads up, Helm console pending" % GameVersion.GAME_VERSION
	add_child(label)
	print("[Far Horizon] scaffold boot — v%s, schema %d" % [
		GameVersion.GAME_VERSION, GameVersion.SAVE_SCHEMA_VERSION,
	])
