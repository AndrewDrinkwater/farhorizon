extends Node
## Main entry scene (the terminal shell root).
##
## Interim shell — boots the run: loads the hardcoded system into GameState,
## builds the spatial SystemView (bodies + ship + camera, step 4), and overlays
## the screen-fixed HUD (clock readout + debug overlay). The persistent terminal
## shell + Helm console replace this in build-order step 8.

const ClockReadout := preload("res://src/ui/shell/clock_readout.gd")
const FuelReadout := preload("res://src/ui/shell/fuel_readout.gd")
const DebugOverlay := preload("res://src/ui/components/debug_overlay.gd")

## Starting system until a save/new-game flow chooses one (step 3+ wiring).
const DEFAULT_SYSTEM_ID: String = "sol"


func _ready() -> void:
	_bootstrap_system()
	add_child(FlightController.new())  # system side of flight; talks via EventBus
	_build_world()
	_build_hud()
	add_child(DebugOverlay.new())

	print("[Far Horizon] boot — v%s, schema %d · system '%s' (Space=pause, [/]=speed, F1=debug)" % [
		GameVersion.GAME_VERSION, GameVersion.SAVE_SCHEMA_VERSION, GameState.system.system_id,
	])


## Pick a starting system if none is loaded yet (fresh run). A loaded save will
## already have system_id + ship position set, so this is a no-op then.
func _bootstrap_system() -> void:
	if GameState.system.system_id != "":
		return
	var system := TypeRegistry.get_system(DEFAULT_SYSTEM_ID)
	if system == null:
		push_error("Main: default system '%s' not found in TypeRegistry" % DEFAULT_SYSTEM_ID)
		return
	GameState.system.system_id = system.id
	GameState.ship.position = system.ship_start


func _build_world() -> void:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return
	var view := SystemView.new()
	add_child(view)
	view.build(system)


## HUD lives under a CanvasLayer so it stays screen-fixed (the world Camera2D
## would otherwise pan/zoom these Controls with it).
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.position = Vector2(40.0, 40.0)
	title.text = "FAR HORIZON  v%s" % GameVersion.GAME_VERSION
	layer.add_child(title)

	var clock: Label = ClockReadout.new()
	clock.position = Vector2(40.0, 72.0)
	layer.add_child(clock)

	var fuel: Label = FuelReadout.new()
	fuel.position = Vector2(40.0, 96.0)
	layer.add_child(fuel)
