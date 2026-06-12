class_name ShipConsole
extends Control
## Ship / Engineering console (ADR 0031) — a stub second console proving the shell.
## A few real readouts (hull id, reaction mass, sensor range) bound to GameState,
## plus clearly-marked TBD sections for the systems that land later. No stage, no
## new systems; it reads state and never mutates (ADR 0014).

var _frame: ConsoleFrame
var _hull: TReadout
var _rm: TReadout
var _sensor: TReadout


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.fuel_changed.connect(_on_fuel_changed)
	EventBus.ship_context_changed.connect(_refresh)
	EventBus.game_state_loaded.connect(_refresh)
	EventBus.system_changed.connect(_refresh.unbind(1))
	_refresh()


func _build() -> void:
	# Same ship-OS frame as the Helm (ADR 0034): identical fixed boxes — the Ship just
	# fills the left/right drawers. The bottom band's boxes stay empty (no data yet)
	# but render at the same fixed sizes, so the consoles read identically.
	_frame = ConsoleFrame.new()
	add_child(_frame)

	_frame.left().set_title("SHIP_GRP_SYSTEMS")
	_frame.set_drawer_label(true, tr("SHIP_GRP_SYSTEMS"))
	var c := _frame.left().content()
	_hull = TReadout.new("SHIP_HULL")
	c.add_child(_hull)
	_rm = TReadout.new("SHIP_REACTION_MASS")
	c.add_child(_rm)
	_sensor = TReadout.new("SHIP_SENSOR_RANGE")
	c.add_child(_sensor)

	# Clearly-marked placeholders for the subsystems that land later (right drawer).
	_frame.right().set_title("SHIP_SUBSYSTEMS")
	_frame.set_drawer_label(false, tr("SHIP_SUBSYSTEMS"))
	var s := _frame.right().content()
	for key: String in ["SHIP_TBD_POWER", "SHIP_TBD_LIFE_SUPPORT", "SHIP_TBD_CREW"]:
		var tbd := Label.new()
		tbd.text = "%s — %s" % [tr(key), tr("SHIP_TBD")]
		tbd.add_theme_color_override("font_color", Palette.TEXT_DIM)
		s.add_child(tbd)

	# Honest placeholder instruments for the not-yet-built bottom band (ADR 0035):
	# an explicit "offline / no data" state with a dim lamp, not blank boxes.
	for box: TPanel in [_frame.secondary(), _frame.control(), _frame.info()]:
		_offline(box)


## Mark a fixed box as an offline instrument: a centred, dim "○ OFFLINE — NO DATA"
## so an empty stub reads as honestly powered-down, not broken (ADR 0035).
func _offline(box: TPanel) -> void:
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.content().add_child(centre)
	var label := Label.new()
	label.text = "○ %s" % tr("SHIP_OFFLINE")
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	centre.add_child(label)


## The shell mounts the console-select tabs here — just above the control panel (ADR 0034).
func console_select_host() -> Control:
	return _frame.console_select()


func _on_fuel_changed(_pool: int, _value: float) -> void:
	_refresh()


func _refresh() -> void:
	if _hull == null:
		return
	var ship: ShipState = GameState.ship
	_hull.set_value(ship.hull_id if ship.hull_id != "" else "—")
	_rm.set_value("%.0f / %.0f" % [ship.reaction_mass, ship.max_reaction_mass])
	_sensor.set_value(tr("HELM_DISTANCE_FORMAT").format({"wu": "%.0f" % ship.sensor_range}))
