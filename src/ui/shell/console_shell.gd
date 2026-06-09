class_name ConsoleShell
extends Control
## The console shell (ADR 0031): hosts the captain's consoles and shows ONE at a
## time, with a persistent console bar (tabs) to switch. Switching is pure UI — no
## state mutation; it emits `console_changed` and ConfigManager remembers the last
## console. A console may own a background stage (the Helm owns the nav views);
## hiding the console hides its stage with it, so the stage shows only while active.
##
## Future domains (Comms / Survey / Crew / Cargo) register the same way.

const HelmConsoleScene := preload("res://src/ui/consoles/helm_console.gd")
const ShipConsoleScene := preload("res://src/ui/consoles/ship_console.gd")

var _consoles: Dictionary = {}     # id:String -> Control
var _titles: Dictionary = {}       # id:String -> tr key
var _order: Array[String] = []     # tab order
var _tabs: Dictionary = {}         # id:String -> TButton
var _active: String = ""
var _host: Control
var _bar: HBoxContainer


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	_register("helm", HelmConsoleScene.new(), "CONSOLE_HELM")
	_register("ship", ShipConsoleScene.new(), "CONSOLE_SHIP")
	_build_bar()  # on top of the consoles

	var last := String(ConfigManager.get_setting("console", "last_id"))
	_activate(last if _consoles.has(last) else _order[0])


func _register(id: String, console: Control, title_key: String) -> void:
	console.set_anchors_preset(Control.PRESET_FULL_RECT)
	console.visible = false
	_host.add_child(console)
	_consoles[id] = console
	_titles[id] = title_key
	_order.append(id)


## A persistent tab bar along the top (centred), diegetic — always shows where you
## are. Click a tab to switch; the active tab is marked (text + highlight, ADR 0012).
func _build_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.anchor_left = 0.0
	_bar.anchor_right = 1.0
	_bar.offset_top = 8.0
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 4)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # empty strip passes clicks; tabs still catch
	add_child(_bar)
	for id: String in _order:
		var tab := TButton.new().setup(_titles[id], _activate.bind(id))
		_bar.add_child(tab)
		_tabs[id] = tab


func _activate(id: String) -> void:
	if not _consoles.has(id):
		return
	_active = id
	for cid: String in _consoles:
		_consoles[cid].visible = (cid == id)
	for tid: String in _tabs:
		# Active tab marked by an arrow prefix + accent (shape + colour, ADR 0012).
		var on := tid == id
		_tabs[tid].modulate = Palette.ACCENT if on else Color.WHITE
		_tabs[tid].text = ("▸ " if on else "") + tr(_titles[tid])
	ConfigManager.set_setting("console", "last_id", id)
	EventBus.console_changed.emit(id)


## Tab cycles to the next console (the debug console keeps the backtick).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_console") and not _order.is_empty():
		var idx := _order.find(_active)
		_activate(_order[(idx + 1) % _order.size()])
		get_viewport().set_input_as_handled()


func active_console() -> String:
	return _active
