class_name ShipConsole
extends Control
## Ship / Engineering console (ADR 0031) — a stub second console proving the shell.
## A few real readouts (hull id, reaction mass, sensor range) bound to GameState,
## plus clearly-marked TBD sections for the systems that land later. No stage, no
## new systems; it reads state and never mutates (ADR 0014).

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
	var panel := TPanel.new("CONSOLE_SHIP")
	add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 16.0
	panel.offset_top = 72.0
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	var c := panel.content()

	var systems := Label.new()
	systems.text = tr("SHIP_GRP_SYSTEMS")
	systems.add_theme_color_override("font_color", Palette.ACCENT)
	c.add_child(systems)
	_hull = TReadout.new("SHIP_HULL")
	c.add_child(_hull)
	_rm = TReadout.new("SHIP_REACTION_MASS")
	c.add_child(_rm)
	_sensor = TReadout.new("SHIP_SENSOR_RANGE")
	c.add_child(_sensor)

	# Clearly-marked placeholders for systems that land later.
	for key: String in ["SHIP_TBD_POWER", "SHIP_TBD_LIFE_SUPPORT", "SHIP_TBD_CREW"]:
		var tbd := Label.new()
		tbd.text = "%s — %s" % [tr(key), tr("SHIP_TBD")]
		tbd.add_theme_color_override("font_color", Palette.TEXT_DIM)
		c.add_child(tbd)


func _on_fuel_changed(_pool: int, _value: float) -> void:
	_refresh()


func _refresh() -> void:
	if _hull == null:
		return
	var ship: ShipState = GameState.ship
	_hull.set_value(ship.hull_id if ship.hull_id != "" else "—")
	_rm.set_value("%.0f / %.0f" % [ship.reaction_mass, ship.max_reaction_mass])
	_sensor.set_value(tr("HELM_DISTANCE_FORMAT").format({"wu": "%.0f" % ship.sensor_range}))
