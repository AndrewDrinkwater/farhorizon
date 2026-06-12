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
const TopBarScene := preload("res://src/ui/shell/top_bar.gd")
const TravelBarScene := preload("res://src/ui/shell/travel_bar.gd")

var _consoles: Dictionary = {}     # id:String -> Control
var _titles: Dictionary = {}       # id:String -> tr key
var _order: Array[String] = []     # tab order
var _tabs: Dictionary = {}         # id:String -> TButton
var _active: String = ""
var _host: Control
var _top_bar: TopBar
var _select_row: HBoxContainer  # the console tabs, mounted into the active console's frame


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
	_build_top_bar()  # shell-global status strip + tabs, on top of the consoles
	add_child(TravelBarScene.new())  # persistent travel indicator, every console (ADR 0035)

	var last := String(ConfigManager.get_setting("console", "last_id"))
	_activate(last if _consoles.has(last) else _order[0])


func _register(id: String, console: Control, title_key: String) -> void:
	console.set_anchors_preset(Control.PRESET_FULL_RECT)
	console.visible = false
	_host.add_child(console)
	_consoles[id] = console
	_titles[id] = title_key
	_order.append(id)


## Shell-global chrome (ADR 0034): the top status strip (clock + watch speed +
## critical resources) and the console-select tabs. The tabs are built once and
## mounted into the active console's frame (a bar just above its control panel),
## so they read as part of that console; the active tab is marked (arrow prefix +
## accent — shape + colour, ADR 0012).
func _build_top_bar() -> void:
	_top_bar = TopBarScene.new()
	add_child(_top_bar)
	_select_row = HBoxContainer.new()
	_select_row.add_theme_constant_override("separation", 4)
	for id: String in _order:
		var tab := TButton.new().setup(_titles[id], _activate.bind(id))
		_select_row.add_child(tab)
		_tabs[id] = tab


## Move the console-select tabs into the active console's frame slot (just above its
## control panel). Consoles that expose console_select_host() get the bar; others
## (none yet) simply don't show it.
func _mount_console_select(id: String) -> void:
	if _select_row == null or not _consoles[id].has_method("console_select_host"):
		return
	var host: Control = _consoles[id].console_select_host()
	if host == null:
		return
	if _select_row.get_parent() != null:
		_select_row.get_parent().remove_child(_select_row)
	host.add_child(_select_row)


func _activate(id: String) -> void:
	if not _consoles.has(id):
		return
	_active = id
	for cid: String in _consoles:
		_consoles[cid].visible = (cid == id)
	_mount_console_select(id)  # tabs ride with the active console's frame (ADR 0034)
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
