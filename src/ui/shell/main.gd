extends Node
## Terminal shell root (ADR 0006/0013). Boots the run and assembles the
## persistent shell: the Helm Nav Plot drawn as an orrery (ADR 0016), the shell
## time controls, and the Helm console over it — clock always running and
## visible. System-side logic (flight, sensors, save) are plain nodes that talk
## via EventBus. The debug overlay sits on top.

const TimeControlsScene := preload("res://src/ui/shell/time_controls.gd")
const ConsoleShellScene := preload("res://src/ui/shell/console_shell.gd")
const DebugOverlay := preload("res://src/ui/components/debug_overlay.gd")
const DebugConsoleScene := preload("res://src/ui/components/debug_console.gd")

## Starting system until a save/new-game flow chooses one.
const DEFAULT_SYSTEM_ID: String = "sol"


func _ready() -> void:
	_bootstrap_system()
	add_child(FlightController.new())   # flight, via EventBus
	add_child(SensorController.new())   # sensor detection, via EventBus
	add_child(ZoneController.new())     # zone membership + triggers (ADR 0026)
	add_child(SystemLoader.new())       # runtime system switching (ADR 0024)
	add_child(SaveController.new())     # F5 save / F9 load
	_build_ui()
	add_child(DebugOverlay.new())
	add_child(DebugConsoleScene.new())  # ` to toggle (ADR 0024)

	print("[Far Horizon] boot — v%s, schema %d · system '%s' (Space=pause, [/]=speed, Tab=console, T=tactical, F3=debug, F5/F9=save/load)" % [
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


## UI under a CanvasLayer + themed root Control (screen-fixed, inherits the
## terminal theme). The console shell (ADR 0031) hosts the consoles + their stages;
## the time controls are persistent chrome on top. Root ignores mouse so empty
## clicks reach the active console's stage.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TerminalTheme.build()
	layer.add_child(root)

	root.add_child(ConsoleShellScene.new())  # consoles + console bar (ADR 0031)

	# Persistent terminal chrome: the mission clock + time controls (ADR 0006).
	var time_controls := TimeControlsScene.new()
	time_controls.position = Vector2(16.0, 12.0)
	root.add_child(time_controls)
