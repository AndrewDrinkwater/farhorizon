extends Node
## Terminal shell root (ADR 0006/0013). Boots the run and assembles the
## persistent shell: the Helm Nav Plot drawn as an orrery (ADR 0016), the shell
## time controls, and the Helm console over it — clock always running and
## visible. System-side logic (flight, sensors, save) are plain nodes that talk
## via EventBus. The debug overlay sits on top.

const TimeControlsScene := preload("res://src/ui/shell/time_controls.gd")
const HelmConsoleScene := preload("res://src/ui/consoles/helm_console.gd")
const OrreryViewScene := preload("res://src/world/orrery_view.gd")
const TacticalViewScene := preload("res://src/world/tactical_view.gd")
const MoonInsetViewScene := preload("res://src/world/moon_inset_view.gd")
const DebugOverlay := preload("res://src/ui/components/debug_overlay.gd")
const DebugConsoleScene := preload("res://src/ui/components/debug_console.gd")

## Starting system until a save/new-game flow chooses one.
const DEFAULT_SYSTEM_ID: String = "sol"

var _orrery: OrreryView
var _tactical: TacticalView


func _ready() -> void:
	_bootstrap_system()
	add_child(FlightController.new())   # flight, via EventBus
	add_child(SensorController.new())   # sensor detection, via EventBus
	add_child(SystemLoader.new())       # runtime system switching (ADR 0024)
	add_child(SaveController.new())     # F5 save / F9 load
	_build_ui()
	add_child(DebugOverlay.new())
	add_child(DebugConsoleScene.new())  # ` to toggle (ADR 0024)

	print("[Far Horizon] boot — v%s, schema %d · system '%s' (Space=pause, [/]=speed, T=tactical, F3=debug, F5/F9=save/load)" % [
		GameVersion.GAME_VERSION, GameVersion.SAVE_SCHEMA_VERSION, GameState.system.system_id,
	])


## Toggle the Nav Plot between the strategic orrery and the tactical scope.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tactical") and _orrery != null and _tactical != null:
		_orrery.visible = not _orrery.visible
		_tactical.visible = not _tactical.visible


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
## terminal theme). The orrery Nav Plot is the back layer; the console + time
## controls draw over it. The root ignores mouse so empty clicks reach the orrery.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TerminalTheme.build()
	layer.add_child(root)

	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system != null:
		_orrery = OrreryViewScene.new()
		root.add_child(_orrery)
		_orrery.build(system)
		_tactical = TacticalViewScene.new()
		_tactical.visible = false  # orrery is the default; T toggles to tactical
		root.add_child(_tactical)
		_tactical.build(system)

	var time_controls := TimeControlsScene.new()
	time_controls.position = Vector2(16.0, 12.0)
	root.add_child(time_controls)

	root.add_child(HelmConsoleScene.new())

	# Focus inset draws over the console (ADR 0022); hidden until a planet is focused.
	if system != null:
		var inset := MoonInsetViewScene.new()
		root.add_child(inset)
		inset.build(system)
