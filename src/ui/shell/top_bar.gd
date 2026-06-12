class_name TopBar
extends PanelContainer
## The shell-global top bar (ADR 0034/0035): a persistent status strip across the
## top — the mission clock + watch speed (TimeControls, ADR 0006), critical resource
## readouts (reaction mass / hull / system), and a row of status lamps
## (FLT / SENS / DOCK / CAUTION). Reads state, never mutates (ADR 0014). The
## console-select tabs live near the control panel (mounted by ConsoleShell).
##
## Each lamp carries state by SHAPE + colour, never colour alone (ADR 0012): a glyph
## (● on · ○ idle · ⚓ docked · ⚠ caution) plus its always-visible code label.

const TimeControlsScene := preload("res://src/ui/shell/time_controls.gd")

var _rm: TReadout
var _hull: TReadout
var _system: TReadout
var _lamps: Dictionary = {}   # code:String -> Label (the glyph)
var _flight_state: int = FlightCore.State.IDLE


func _ready() -> void:
	anchor_right = 1.0
	offset_left = ConsoleFrame.EDGE
	offset_right = -ConsoleFrame.EDGE
	offset_top = 8.0
	_build()
	EventBus.fuel_changed.connect(_on_fuel_changed)
	EventBus.ship_context_changed.connect(_refresh)
	EventBus.flight_state_changed.connect(_on_flight_state_changed)
	EventBus.system_changed.connect(_refresh.unbind(1))
	EventBus.game_state_loaded.connect(_refresh)
	_refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	row.add_child(TimeControlsScene.new())

	# Critical resources (Stellaris-style strip): reaction mass, hull, system.
	_rm = TReadout.new("HUD_REACTION_MASS")
	row.add_child(_rm)
	_hull = TReadout.new("TOPBAR_HULL")
	row.add_child(_hull)
	_system = TReadout.new("TOPBAR_SYSTEM")
	row.add_child(_system)

	# Push the status lamps to the right edge.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var lamps := HBoxContainer.new()
	lamps.add_theme_constant_override("separation", 14)
	row.add_child(lamps)
	for code: String in ["LAMP_FLT", "LAMP_SENS", "LAMP_DOCK", "LAMP_CAUTION"]:
		lamps.add_child(_make_lamp(code))


## A compact lamp: a coloured glyph (shape channel) + its code label (always shown).
func _make_lamp(code_key: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var glyph := Label.new()
	glyph.text = "○"
	glyph.add_theme_color_override("font_color", Palette.STATUS_IDLE)
	box.add_child(glyph)
	var label := Label.new()
	label.text = tr(code_key)
	label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	box.add_child(label)
	_lamps[code_key] = glyph
	return box


func _on_fuel_changed(_pool: int, _value: float) -> void:
	_refresh()


func _on_flight_state_changed(state: int) -> void:
	_flight_state = state
	_refresh()


func _refresh() -> void:
	if _rm == null:
		return
	var ship: ShipState = GameState.ship
	_rm.set_value("%.0f / %.0f" % [ship.reaction_mass, ship.max_reaction_mass])
	_hull.set_value(ship.hull_id if ship.hull_id != "" else "—")
	var system := TypeRegistry.get_system(GameState.system.system_id)
	_system.set_value(tr(system.name_key) if system != null else "—")
	_refresh_lamps(ship)


func _refresh_lamps(ship: ShipState) -> void:
	var under_way := bool(ship.current_order.get("engaged", false)) \
		or _flight_state == FlightCore.State.DESCENDING or _flight_state == FlightCore.State.ASCENDING \
		or _flight_state == FlightCore.State.DOCKING or _flight_state == FlightCore.State.UNDOCKING
	_set_lamp("LAMP_FLT", "●" if under_way else "○",
		Palette.STATUS_NOMINAL if under_way else Palette.STATUS_IDLE)
	_set_lamp("LAMP_SENS", "●", Palette.STATUS_NOMINAL)  # sensors always online
	var docked := ship.location == Travel.Location.DOCKED
	_set_lamp("LAMP_DOCK", "⚓" if docked else "○",
		Palette.STATUS_INFO if docked else Palette.STATUS_IDLE)
	var ratio := ship.reaction_mass / maxf(1.0, ship.max_reaction_mass)
	if ratio <= 0.15:
		_set_lamp("LAMP_CAUTION", "⚠", Palette.STATUS_ALERT)
	elif ratio <= 0.30:
		_set_lamp("LAMP_CAUTION", "⚠", Palette.STATUS_CAUTION)
	else:
		_set_lamp("LAMP_CAUTION", "○", Palette.STATUS_IDLE)


func _set_lamp(code_key: String, glyph: String, color: Color) -> void:
	var label: Label = _lamps[code_key]
	label.text = glyph
	label.add_theme_color_override("font_color", color)
