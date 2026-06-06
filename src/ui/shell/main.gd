extends Node
## Main entry scene (the terminal shell root).
##
## Interim shell — proves the project boots and now hosts the live SimClock
## readout + debug overlay (build-order step 2). The persistent terminal shell +
## Helm console replace this in build-order step 8. See docs/consoles/helm.md.

const ClockReadout := preload("res://src/ui/shell/clock_readout.gd")
const DebugOverlay := preload("res://src/ui/components/debug_overlay.gd")


func _ready() -> void:
	var title := Label.new()
	title.position = Vector2(40.0, 40.0)
	title.text = "FAR HORIZON  v%s" % GameVersion.GAME_VERSION
	add_child(title)

	var clock: Label = ClockReadout.new()
	clock.position = Vector2(40.0, 72.0)
	add_child(clock)

	add_child(DebugOverlay.new())

	print("[Far Horizon] boot — v%s, schema %d · SimClock live (Space=pause, [/]=speed, F1=debug)" % [
		GameVersion.GAME_VERSION, GameVersion.SAVE_SCHEMA_VERSION,
	])
