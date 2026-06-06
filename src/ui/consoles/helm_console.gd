class_name HelmConsole
extends Control
## The Helm console (ADR 0013, docs/consoles/helm.md): flight + navigation from
## the captain's chair. Assembled from config-driven components (ADR 0007) laid
## over the persistent Nav Plot map. It composes orders and issues them on
## EventBus (ADR 0014) — it never mutates state; it reads GameState for display.
##
## Available orders are derived from the ship's situation (ADR 0015): the buttons
## enable/disable via Travel.available, so only context-appropriate orders can be
## given. Status reads location + course + motion.

const POST: String = "helm"

# Compose state
var _target_id: String = ""
var _burn: int = FlightMath.Burn.STANDARD
var _flight_state: int = FlightCore.State.IDLE

# Course Order widgets
var _target_readout: TReadout
var _distance_readout: TReadout
var _eta_readout: TReadout
var _rm_readout: TReadout
var _burn_buttons: Dictionary = {}  # burn:int -> TButton
var _action_buttons: Dictionary = {}  # order id:String -> TButton

# Flight Status widgets
var _status_light: TLight
var _status_distance: TReadout
var _status_eta: TReadout
var _fuel_gauge: TGauge

# Order Log
var _order_log: TList


func _ready() -> void:
	# Fill the parent explicitly: a plain-Control parent doesn't lay us out, and
	# set_anchors_preset alone left this at size 0 (panels then anchor off-screen).
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # let map clicks through; panels still catch theirs
	_build_course_order()
	_build_flight_status()
	_build_order_log()
	_connect_bus()
	_refresh_all()


# --- Layout helpers ---

func _place(ctrl: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, oright: float, ob: float) -> void:
	ctrl.anchor_left = al
	ctrl.anchor_top = at
	ctrl.anchor_right = ar
	ctrl.anchor_bottom = ab
	ctrl.offset_left = ol
	ctrl.offset_top = ot
	ctrl.offset_right = oright
	ctrl.offset_bottom = ob


# --- Course Order region (compose + issue) ---

func _build_course_order() -> void:
	var panel := TPanel.new("HELM_COURSE_ORDER")
	add_child(panel)
	_place(panel, 0.0, 1.0, 0.0, 1.0, 16.0, -300.0, 380.0, -16.0)
	var c := panel.content()

	_target_readout = TReadout.new("HELM_TARGET")
	c.add_child(_target_readout)

	var burn_row := HBoxContainer.new()
	burn_row.add_theme_constant_override("separation", 4)
	c.add_child(burn_row)
	var burn_caption := Label.new()
	burn_caption.text = tr("HELM_BURN_LABEL")
	burn_caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
	burn_caption.custom_minimum_size = Vector2(110.0, 0.0)
	burn_row.add_child(burn_caption)
	for entry: Array in [
		[FlightMath.Burn.ECONOMY, "HELM_BURN_ECONOMY"],
		[FlightMath.Burn.STANDARD, "HELM_BURN_STANDARD"],
		[FlightMath.Burn.HARD, "HELM_BURN_HARD"],
	]:
		var burn: int = entry[0]
		var button := TButton.new()
		button.setup(entry[1], _select_burn.bind(burn))
		burn_row.add_child(button)
		_burn_buttons[burn] = button

	_distance_readout = TReadout.new("HELM_DISTANCE")
	c.add_child(_distance_readout)
	_eta_readout = TReadout.new("HELM_ETA")
	c.add_child(_eta_readout)
	_rm_readout = TReadout.new("HELM_RM_COST")
	c.add_child(_rm_readout)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	c.add_child(row1)
	row1.add_child(_make_action("lay_in", "HELM_LAY_IN_COURSE", _lay_in_course))
	row1.add_child(_make_action("engage", "HELM_ENGAGE", _engage))
	row1.add_child(_make_action("belay", "HELM_BELAY", _belay))

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	c.add_child(row2)
	row2.add_child(_make_action("all_stop", "HELM_ALL_STOP", _all_stop))
	row2.add_child(_make_action("dock", "HELM_DOCK", _dock))
	row2.add_child(_make_action("undock", "HELM_UNDOCK", _undock))

	_refresh_burn_buttons()


func _make_action(id: String, label_key: String, on_press: Callable) -> TButton:
	var button := TButton.new().setup(label_key, on_press)
	_action_buttons[id] = button
	return button


# --- Flight Status region (live readouts) ---

func _build_flight_status() -> void:
	var panel := TPanel.new("HELM_FLIGHT_STATUS")
	add_child(panel)
	_place(panel, 1.0, 0.0, 1.0, 0.0, -380.0, 16.0, -16.0, 220.0)
	var c := panel.content()

	_status_light = TLight.new("HELM_STATUS")
	c.add_child(_status_light)
	_status_distance = TReadout.new("HELM_DISTANCE")
	c.add_child(_status_distance)
	_status_eta = TReadout.new("HELM_ETA")
	c.add_child(_status_eta)
	_fuel_gauge = TGauge.new("HUD_REACTION_MASS")
	c.add_child(_fuel_gauge)
	_fuel_gauge.bind(_fuel_data)


# --- Order Log region ---

func _build_order_log() -> void:
	var panel := TPanel.new("HELM_ORDER_LOG")
	add_child(panel)
	_place(panel, 1.0, 1.0, 1.0, 1.0, -380.0, -300.0, -16.0, -16.0)
	_order_log = TList.new()
	_order_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.content().add_child(_order_log)


# --- Bus wiring ---

func _connect_bus() -> void:
	EventBus.nav_target_selected.connect(_on_target_selected)
	EventBus.flight_state_changed.connect(_on_flight_state_changed)
	EventBus.ship_context_changed.connect(_refresh_all)
	EventBus.sim_tick.connect(_on_tick.unbind(1))
	EventBus.fuel_changed.connect(_on_fuel_changed)
	EventBus.order_acknowledged.connect(_on_order_acknowledged)
	EventBus.order_rejected.connect(_on_order_rejected)
	EventBus.game_state_loaded.connect(_refresh_all)


func _on_target_selected(target_id: String) -> void:
	_target_id = target_id
	_refresh_preview()
	_refresh_actions()


func _on_flight_state_changed(state: int) -> void:
	_flight_state = state
	_refresh_status()


func _on_tick() -> void:
	# Geometry changes as the ship moves: keep preview + status current.
	_refresh_preview()
	_refresh_status()


func _on_fuel_changed(_pool: int, _value: float) -> void:
	_fuel_gauge.refresh()
	_refresh_preview()  # affordability may flip


func _on_order_acknowledged(speaker_key: String, line_key: String) -> void:
	_log(speaker_key, line_key)


func _on_order_rejected(reason_key: String) -> void:
	_log(CrewVoice.SHIP_VOICE, reason_key)


# --- Compose actions (burn + order buttons) ---

func _select_burn(burn: int) -> void:
	_burn = burn
	_refresh_burn_buttons()
	_refresh_preview()


func _lay_in_course() -> void:
	if _target_id == "":
		return
	EventBus.order_issued.emit({"type": "set_course", "target_id": _target_id, "burn": _burn})


func _engage() -> void:
	EventBus.order_issued.emit({"type": "engage"})


func _belay() -> void:
	EventBus.order_belayed.emit()


func _all_stop() -> void:
	EventBus.order_issued.emit({"type": "all_stop"})


func _dock() -> void:
	EventBus.order_issued.emit({"type": "dock"})


func _undock() -> void:
	EventBus.order_issued.emit({"type": "undock"})


# --- Refresh ---

func _refresh_all() -> void:
	_refresh_preview()
	_refresh_status()
	_refresh_actions()
	_fuel_gauge.refresh()


func _refresh_burn_buttons() -> void:
	for burn: int in _burn_buttons:
		_burn_buttons[burn].modulate = Palette.ACCENT if burn == _burn else Color.WHITE


## Enable only the orders that are legal right now (ADR 0015).
func _refresh_actions() -> void:
	var available := Travel.available(_context())
	for id: String in _action_buttons:
		_action_buttons[id].disabled = not bool(available.get(id, false))


func _context() -> Dictionary:
	var ship: ShipState = GameState.ship
	var location_body := _resolve_body(ship.location_body_id)
	return {
		"location": ship.location,
		"location_can_dock": location_body != null and location_body.can_dock,
		"in_transit": _in_transit(),
		"has_course": _has_course(),
		"nav_target_id": _target_id,
		"nav_target_is_here": _target_id != "" and _target_id == ship.location_body_id \
			and ship.location != Travel.Location.DEEP_SPACE,
	}


func _refresh_preview() -> void:
	var body := _resolve_body(_target_id)
	if body == null:
		_target_readout.set_value(tr("HELM_NO_TARGET"))
		_distance_readout.set_value("—")
		_eta_readout.set_value("—")
		_rm_readout.set_value("—")
		return
	var preview := FlightMath.preview(GameState.ship.position, body.position, _burn,
		GameState.ship.reaction_mass)
	_target_readout.set_value(tr(body.name_key))
	_distance_readout.set_value(_format_distance(preview["distance"]))
	_eta_readout.set_value(_format_eta(preview["eta_ticks"]))
	var rm_text := _format_rm(preview["rm_cost"])
	if not bool(preview["affordable"]):
		rm_text = "⚠ " + rm_text  # non-colour cue for "can't afford" (ADR 0012)
	_rm_readout.set_value(rm_text)


func _refresh_status() -> void:
	var visual := _status_visual()
	_status_light.set_state(visual[0], visual[1], visual[2])

	var body := _resolve_body(String(GameState.ship.current_order.get("target_id", "")))
	if body == null:
		_status_distance.set_value("—")
		_status_eta.set_value("—")
		return
	var dist: float = GameState.ship.position.distance_to(body.position)
	_status_distance.set_value(_format_distance(dist))
	if _in_transit():
		_status_eta.set_value(_format_eta(FlightMath.eta_ticks(dist,
			int(GameState.ship.current_order.get("burn", _burn)))))
	else:
		_status_eta.set_value("—")


## [colour, glyph, text] for the current situation. Glyph + text are the
## non-colour channels (ADR 0012).
func _status_visual() -> Array:
	var ship: ShipState = GameState.ship
	if _in_transit():
		var body := _resolve_body(String(ship.current_order.get("target_id", "")))
		var bound := tr("TRAVEL_BOUND_FOR").format({
			"phase": tr(FlightCore.state_key(_flight_state)),
			"body": tr(body.name_key) if body != null else "",
		})
		return [Palette.STATUS_NOMINAL, "»", bound]
	match ship.location:
		Travel.Location.DOCKED:
			return [Palette.STATUS_INFO, "⚓", tr("TRAVEL_DOCKED_AT").format({"body": _location_name()})]
		Travel.Location.HOLDING:
			return [Palette.STATUS_INFO, "◎", tr("TRAVEL_HOLDING_AT").format({"body": _location_name()})]
		_:
			if _has_course():
				return [Palette.STATUS_INFO, "▷", tr("TRAVEL_COURSE_LAID_IN")]
			return [Palette.STATUS_IDLE, "○", tr("TRAVEL_DRIFTING")]


func _fuel_data() -> Dictionary:
	var capacity: float = maxf(1.0, GameState.ship.max_reaction_mass)
	return {
		"ratio": GameState.ship.reaction_mass / capacity,
		"text": "%.0f / %.0f RM" % [GameState.ship.reaction_mass, GameState.ship.max_reaction_mass],
	}


# --- Helpers ---

func _in_transit() -> bool:
	return bool(GameState.ship.current_order.get("engaged", false))


func _has_course() -> bool:
	return String(GameState.ship.current_order.get("type", "")) == "course"


func _location_name() -> String:
	var body := _resolve_body(GameState.ship.location_body_id)
	return tr(body.name_key) if body != null else ""


func _log(speaker_key: String, line_key: String) -> void:
	_order_log.add_record(tr("LOG_LINE_FORMAT").format({
		"speaker": tr(speaker_key), "line": tr(line_key),
	}))


func _format_distance(wu: float) -> String:
	return tr("HELM_DISTANCE_FORMAT").format({"wu": "%.0f" % wu})


func _format_eta(ticks: int) -> String:
	# A tick is one in-game minute; show ETA as Hh MMm.
	return tr("HELM_ETA_FORMAT").format({"hours": ticks / 60, "mins": "%02d" % (ticks % 60)})


func _format_rm(rm: float) -> String:
	return tr("HELM_RM_FORMAT").format({"rm": "%.1f" % rm})


func _resolve_body(target_id: String) -> BodyData:
	if target_id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if body.id == target_id:
			return body
	return null
