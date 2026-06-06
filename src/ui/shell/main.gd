extends Node
## Terminal shell root (ADR 0006/0013). Boots the run and assembles the
## persistent shell: the Nav Plot map (SystemView), the shell time controls, and
## the active console (Helm) laid over it — clock always running and visible. The
## debug overlay sits on top. Consoles are screen-fixed under a themed UI layer;
## the map lives in world space behind it.

const TimeControlsScene := preload("res://src/ui/shell/time_controls.gd")
const HelmConsoleScene := preload("res://src/ui/consoles/helm_console.gd")
const DebugOverlay := preload("res://src/ui/components/debug_overlay.gd")

## Starting system until a save/new-game flow chooses one.
const DEFAULT_SYSTEM_ID: String = "sol"


func _ready() -> void:
	_bootstrap_system()
	add_child(FlightController.new())  # system side of flight; talks via EventBus
	add_child(SaveController.new())    # F5 save / F9 load
	_build_world()
	_build_ui()
	add_child(DebugOverlay.new())

	print("[Far Horizon] boot — v%s, schema %d · system '%s' (Space=pause, [/]=speed, F3=debug, F5/F9=save/load, wheel=zoom, RMB=pan, C=recenter)" % [
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


## UI lives under a CanvasLayer + themed root Control so it stays screen-fixed
## (the world Camera2D would otherwise pan/zoom it) and inherits the terminal
## theme. The root ignores mouse so empty-space clicks reach the Nav Plot map.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TerminalTheme.build()
	layer.add_child(root)

	var time_controls := TimeControlsScene.new()
	time_controls.position = Vector2(16.0, 12.0)
	root.add_child(time_controls)

	root.add_child(HelmConsoleScene.new())
