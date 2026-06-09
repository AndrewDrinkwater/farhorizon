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

# Compose state — the Nav Plot selection: a body, a contact, or a free point
# (ADR 0020). `_sel_id` is the body/contact id ("" for a point); `_sel_point` is
# the destination for a free waypoint.
var _sel_kind: int = Travel.TargetKind.NONE
var _sel_id: String = ""
var _sel_point: Vector2 = Vector2.ZERO
var _route_waypoints: Array[Vector2] = []  # intermediate route points (ADR 0027)
var _burn: int = FlightMath.Burn.STANDARD
var _scale: int = OrreryParams.ScaleMode.LOG  # orrery schematic ↔ true scale (ADR 0021)
var _flight_state: int = FlightCore.State.IDLE

# Course Order widgets
var _target_readout: TReadout
var _distance_readout: TReadout
var _eta_readout: TReadout
var _rm_readout: TReadout
var _burn_buttons: Dictionary = {}  # burn:int -> TButton
var _scale_switch: CheckButton  # orrery scale toggle, above the Course Order box (ADR 0021/0023)
var _pip_readout: TReadout      # between-pip distance/time legend (ADR 0019)
var _action_buttons: Dictionary = {}  # order id:String -> TButton

# Flight Status widgets
var _status_light: TLight
var _status_distance: TReadout
var _status_eta: TReadout
var _fuel_gauge: TGauge
var _ack_line: Label    # transient ship-voice acknowledgments (ADR 0025)
var _ack_tween: Tween

# Target Information panel (ADR 0025) — burn-aware details for the selection
var _ti_name: TReadout
var _ti_type: TReadout
var _ti_dist: TReadout
var _ti_eta: TReadout
var _ti_rm: TReadout
var _ti_status: TReadout
var _ti_route: TReadout


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
	_build_scale_toggle()
	_build_flight_status()
	_build_target_info()
	_connect_bus()
	_refresh_all()
	EventBus.nav_burn_changed.emit(_burn)  # sync the nav views to the starting burn (ADR 0019)
	EventBus.nav_scale_changed.emit(_scale)  # sync the orrery to the starting scale (ADR 0021)


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
	# Between-pip legend (ADR 0019 feel pass): what one course-line pip spans at the
	# selected burn — distance per fixed time, so the pips read as a scale.
	_pip_readout = TReadout.new("HELM_PIP")
	c.add_child(_pip_readout)

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
	row2.add_child(_make_action("scan", "HELM_SCAN", _scan))
	row2.add_child(_make_action("focus", "HELM_FOCUS", _focus))
	row2.add_child(_make_action("clear_course", "HELM_CLEAR_COURSE", _clear_route))

	_refresh_burn_buttons()


## A toggle switch above the Course Order box that flips the orrery scale mode
## (ADR 0021/0023) — a CheckButton (slide switch) showing the current mode.
func _build_scale_toggle() -> void:
	var box := PanelContainer.new()
	add_child(box)
	_place(box, 0.0, 1.0, 0.0, 1.0, 16.0, -342.0, 380.0, -306.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var caption := Label.new()
	caption.text = tr("HELM_SCALE_LABEL")
	caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(caption)
	_scale_switch = CheckButton.new()
	_scale_switch.set_pressed_no_signal(_scale == OrreryParams.ScaleMode.LINEAR)
	_scale_switch.text = _scale_mode_label()
	_scale_switch.toggled.connect(_on_scale_toggled)
	row.add_child(_scale_switch)


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

	# Transient ship-voice line (ADR 0025): an ack/reject shows here then fades.
	_ack_line = Label.new()
	_ack_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ack_line.add_theme_color_override("font_color", Palette.STATUS_INFO)
	_ack_line.modulate.a = 0.0
	c.add_child(_ack_line)


# --- Target Information region (ADR 0025): replaces the Order Log ---

func _build_target_info() -> void:
	var panel := TPanel.new("HELM_TARGET_INFO")
	add_child(panel)
	_place(panel, 1.0, 1.0, 1.0, 1.0, -380.0, -300.0, -16.0, -16.0)
	var c := panel.content()
	_ti_name = TReadout.new("HELM_TI_NAME")
	c.add_child(_ti_name)
	_ti_type = TReadout.new("HELM_TI_TYPE")
	c.add_child(_ti_type)
	_ti_dist = TReadout.new("HELM_TI_DIST")
	c.add_child(_ti_dist)
	_ti_eta = TReadout.new("HELM_ETA")
	c.add_child(_ti_eta)
	_ti_rm = TReadout.new("HELM_TI_RM")
	c.add_child(_ti_rm)
	_ti_status = TReadout.new("HELM_TI_STATUS")
	c.add_child(_ti_status)
	_ti_route = TReadout.new("HELM_TI_ROUTE")
	c.add_child(_ti_route)


# --- Bus wiring ---

func _connect_bus() -> void:
	EventBus.nav_target_selected.connect(_on_target_selected)
	EventBus.nav_point_selected.connect(_on_point_selected)
	EventBus.nav_waypoints_set.connect(_on_waypoints_set)
	EventBus.contact_detected.connect(_on_contacts_changed.unbind(1))
	EventBus.contact_lost.connect(_on_contacts_changed.unbind(1))
	EventBus.contact_promoted.connect(_on_contacts_changed.unbind(2))
	EventBus.flight_state_changed.connect(_on_flight_state_changed)
	EventBus.course_completed.connect(_on_course_completed)
	EventBus.ship_context_changed.connect(_refresh_all)
	EventBus.sim_tick.connect(_on_tick.unbind(1))
	EventBus.fuel_changed.connect(_on_fuel_changed)
	EventBus.order_acknowledged.connect(_on_order_acknowledged)
	EventBus.order_rejected.connect(_on_order_rejected)
	EventBus.game_state_loaded.connect(_refresh_all)
	EventBus.system_changed.connect(_on_system_changed)


## A new system loaded (ADR 0024): the old selection is gone — clear it and refresh.
func _on_system_changed(_system_id: String) -> void:
	_sel_kind = Travel.TargetKind.NONE
	_sel_id = ""
	_sel_point = Vector2.ZERO
	_route_waypoints.clear()
	_refresh_all()
	_emit_route()


func _on_target_selected(target_id: String) -> void:
	_sel_id = target_id
	_sel_point = Vector2.ZERO
	_route_waypoints.clear()  # fresh route to the new target (ADR 0027)
	if _resolve_body(target_id) != null:
		_sel_kind = Travel.TargetKind.BODY
	elif _resolve_contact(target_id) != null:
		_sel_kind = Travel.TargetKind.CONTACT
	else:
		_sel_kind = Travel.TargetKind.NONE
	_refresh_preview()
	_refresh_actions()
	_emit_route()


## An empty-space click (ADR 0020/0028) plots a direct course to that free point.
## Route waypoints are now added by dragging the course line (nav_waypoints_set).
func _on_point_selected(point: Vector2) -> void:
	_sel_kind = Travel.TargetKind.POINT
	_sel_id = ""
	_sel_point = point
	_route_waypoints.clear()
	_refresh_preview()
	_refresh_actions()
	_emit_route()


## A nav view dragged the course (ADR 0028): adopt the new waypoint list.
func _on_waypoints_set(waypoints: PackedVector2Array) -> void:
	_route_waypoints.assign(waypoints)
	_refresh_preview()
	_refresh_actions()
	_emit_route()


## Clear Course (ADR 0028): wipe the plotted course entirely — selection,
## waypoints, and any not-engaged laid-in order.
func _clear_route() -> void:
	EventBus.order_issued.emit({"type": "clear_course"})
	_reset_plot()


## On arrival the course is done — wipe the plot so it doesn't linger (ADR 0028).
func _on_course_completed() -> void:
	_reset_plot()


## Reset the compose plot (selection + waypoints) and clear the views' highlight.
func _reset_plot() -> void:
	_sel_kind = Travel.TargetKind.NONE
	_sel_id = ""
	_sel_point = Vector2.ZERO
	_route_waypoints.clear()
	EventBus.nav_target_selected.emit("")  # clear the views' selection highlight
	_refresh_preview()
	_refresh_actions()
	_emit_route()


## A contact winked in/out or was identified — the preview name + Scan
## availability may change.
func _on_contacts_changed() -> void:
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
	_show_ack(speaker_key, line_key)


func _on_order_rejected(reason_key: String) -> void:
	_show_ack(CrewVoice.SHIP_VOICE, reason_key)


## Flash a ship-voice line in Flight Status, then fade it (ADR 0025) — keeps the
## captain-voice beat (ADR 0014) without a persistent log panel.
func _show_ack(speaker_key: String, line_key: String) -> void:
	if _ack_line == null:
		return
	_ack_line.text = tr("LOG_LINE_FORMAT").format({"speaker": tr(speaker_key), "line": tr(line_key)})
	_ack_line.modulate.a = 1.0
	if _ack_tween != null and _ack_tween.is_valid():
		_ack_tween.kill()
	_ack_tween = create_tween()
	_ack_tween.tween_interval(3.0)
	_ack_tween.tween_property(_ack_line, "modulate:a", 0.0, 2.0)


# --- Compose actions (burn + order buttons) ---

func _select_burn(burn: int) -> void:
	_burn = burn
	_refresh_burn_buttons()
	_refresh_preview()
	_refresh_pip_legend()
	EventBus.nav_burn_changed.emit(_burn)  # nav views recompute time annotations (ADR 0019)


func _select_scale(mode: int) -> void:
	_scale = mode
	if _scale_switch != null:
		_scale_switch.set_pressed_no_signal(_scale == OrreryParams.ScaleMode.LINEAR)
		_scale_switch.text = _scale_mode_label()
	EventBus.nav_scale_changed.emit(_scale)  # orrery remaps radii (ADR 0021)


func _on_scale_toggled(pressed: bool) -> void:
	_select_scale(OrreryParams.ScaleMode.LINEAR if pressed else OrreryParams.ScaleMode.LOG)


func _scale_mode_label() -> String:
	return tr("HELM_SCALE_TRUE") if _scale == OrreryParams.ScaleMode.LINEAR else tr("HELM_SCALE_SCHEMATIC")


func _lay_in_course() -> void:
	if _sel_kind == Travel.TargetKind.NONE:
		return
	EventBus.order_issued.emit({
		"type": "set_course", "target_id": _sel_id, "point": _sel_point,
		"waypoints": _route_waypoints.duplicate(), "burn": _burn,
	})


## The composed route as points: ship → waypoints → destination (empty if nothing
## selected). Used for the no-go check, the Target Info line, and the preview.
func _compose_route() -> PackedVector2Array:
	if _sel_kind == Travel.TargetKind.NONE:
		return PackedVector2Array()
	var route := PackedVector2Array([GameState.ship.position])
	for wp: Vector2 in _route_waypoints:
		route.append(wp)
	route.append(_selected_position())
	return route


func _route_block_level() -> int:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null or _sel_kind == Travel.TargetKind.NONE:
		return Zones.Block.CLEAR
	return Zones.route_block(system, _compose_route())


func _emit_route() -> void:
	EventBus.nav_route_changed.emit(_compose_route())


func _scan() -> void:
	if _sel_kind != Travel.TargetKind.CONTACT:
		return
	EventBus.order_issued.emit({"type": "scan", "contact_id": _sel_id})


## Open the focus inset for the selected moon-bearing planet (ADR 0022). Not a
## travel order — a view request on the bus.
func _focus() -> void:
	if _selection_has_moons():
		EventBus.nav_focus_requested.emit(_sel_id)


func _engage() -> void:
	if _sel_kind != Travel.TargetKind.NONE:
		_lay_in_course()  # (re)issue the plotted route so what flies is the live plot (ADR 0028)
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
	_refresh_pip_legend()
	_fuel_gauge.refresh()


func _refresh_burn_buttons() -> void:
	for burn: int in _burn_buttons:
		_burn_buttons[burn].modulate = Palette.ACCENT if burn == _burn else Color.WHITE


## Between-pip legend: one course-line pip spans PIP_TICKS minutes; show the
## distance that covers at the selected burn (ADR 0019 feel pass).
func _refresh_pip_legend() -> void:
	if _pip_readout == null:
		return
	var wu := FlightMath.reach_wu(_burn, OrreryView.PIP_TICKS)
	_pip_readout.set_value(tr("HELM_PIP_FORMAT").format({
		"mins": OrreryView.PIP_TICKS, "wu": "%.0f" % wu,
	}))


## Enable only the orders that are legal right now (ADR 0015).
func _refresh_actions() -> void:
	var available := Travel.available(_context())
	for id: String in _action_buttons:
		_action_buttons[id].disabled = not bool(available.get(id, false))
	# Focus is a view request, not a travel order — gate it on "selection has moons".
	if _action_buttons.has("focus"):
		_action_buttons["focus"].disabled = not _selection_has_moons()
	if _action_buttons.has("clear_course"):
		_action_buttons["clear_course"].disabled = _sel_kind == Travel.TargetKind.NONE \
			and _route_waypoints.is_empty() and not _has_course()


## Does the current selection (a body) have any moons? (ADR 0022)
func _selection_has_moons() -> bool:
	if _sel_kind != Travel.TargetKind.BODY:
		return false
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return false
	for body: BodyData in system.bodies:
		if body.kind == BodyData.Kind.MOON and body.parent_id == _sel_id:
			return true
	return false


func _context() -> Dictionary:
	var ship: ShipState = GameState.ship
	var location_body := _resolve_body(ship.location_body_id)
	var is_contact := _sel_kind == Travel.TargetKind.CONTACT
	var contact := _resolve_contact(_sel_id) if is_contact else null
	return {
		"location": ship.location,
		"location_can_dock": location_body != null and location_body.can_dock,
		"in_transit": _in_transit(),
		"has_course": _has_course(),
		"nav_target_id": _sel_id,
		"nav_target_is_here": _sel_kind == Travel.TargetKind.BODY and _sel_id == ship.location_body_id \
			and ship.location != Travel.Location.DEEP_SPACE,
		"has_nav_selection": _sel_kind != Travel.TargetKind.NONE,
		"nav_target_is_contact": is_contact,
		"nav_target_in_range": contact != null \
			and ship.position.distance_to(contact.position) <= ship.sensor_range,
		"nav_target_tier": GameState.contacts.tier_of(_sel_id) if is_contact else Sensors.Tier.UNDETECTED,
		"route_nogo": _route_block_level() == Zones.Block.NOGO,
	}


func _refresh_preview() -> void:
	_refresh_target_info()  # the Target Info panel updates on the same triggers (ADR 0025)
	if _sel_kind == Travel.TargetKind.NONE:
		_target_readout.set_value(tr("HELM_NO_TARGET"))
		_distance_readout.set_value("—")
		_eta_readout.set_value("—")
		_rm_readout.set_value("—")
		return
	# Over the whole plotted route (ship → waypoints → target), not the direct leg —
	# so dragging waypoints updates the distance/ETA/RM the captain sees (ADR 0028).
	var dist := _plotted_distance()
	var cost := FlightMath.rm_cost(dist, _burn)
	_target_readout.set_value(_selected_name())
	_distance_readout.set_value(_format_distance(dist))
	_eta_readout.set_value(_format_eta(FlightMath.eta_ticks(dist, _burn)))
	var rm_text := _format_rm(cost)
	if cost > GameState.ship.reaction_mass:
		rm_text = "⚠ " + rm_text  # non-colour cue for "can't afford" (ADR 0012)
	_rm_readout.set_value(rm_text)


## Total travel distance over the plotted route's legs (ship → waypoints → target).
func _plotted_distance() -> float:
	var route := _compose_route()
	var total := 0.0
	for i in range(route.size() - 1):
		total += route[i].distance_to(route[i + 1])
	return total


func _refresh_status() -> void:
	var visual := _status_visual()
	_status_light.set_state(visual[0], visual[1], visual[2])

	if not _has_course():
		_status_distance.set_value("—")
		_status_eta.set_value("—")
		return
	var dist: float = GameState.ship.position.distance_to(_order_destination())
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
		var bound := tr("TRAVEL_BOUND_FOR").format({
			"phase": tr(FlightCore.state_key(_flight_state)),
			"body": _order_destination_name(),
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


## Destination point of the laid-in course (body position or frozen dest, ADR 0020).
func _order_destination() -> Vector2:
	var order: Dictionary = GameState.ship.current_order
	var body := _resolve_body(String(order.get("target_id", "")))
	if body != null:
		return body.position
	return order.get("dest", GameState.ship.position)


## Display name of the laid-in course destination (body / contact / waypoint).
func _order_destination_name() -> String:
	var id := String(GameState.ship.current_order.get("target_id", ""))
	var body := _resolve_body(id)
	if body != null:
		return tr(body.name_key)
	var contact := _resolve_contact(id)
	if contact != null:
		if GameState.contacts.tier_of(id) == Sensors.Tier.IDENTIFIED:
			return tr(contact.name_key)
		return tr("NAV_CONTACT_UNKNOWN")
	return tr("NAV_WAYPOINT")


func _location_name() -> String:
	var body := _resolve_body(GameState.ship.location_body_id)
	return tr(body.name_key) if body != null else ""


# --- Target Information (ADR 0025) ---

## Populate the Target Info panel for the current selection, burn-aware.
func _refresh_target_info() -> void:
	if _ti_name == null:
		return
	match _sel_kind:
		Travel.TargetKind.BODY:
			_ti_body()
		Travel.TargetKind.CONTACT:
			_ti_contact()
		Travel.TargetKind.POINT:
			_ti_point()
		_:
			_ti_none()
	_refresh_route_line()


## Route obstruction + waypoint count (ADR 0027). Clear / hazard-warned / no-go.
func _refresh_route_line() -> void:
	if _sel_kind == Travel.TargetKind.NONE:
		_ti_route.set_value("—")
		return
	var status: String
	match _route_block_level():
		Zones.Block.NOGO:
			status = "⚠ " + tr("HELM_TI_ROUTE_NOGO")
		Zones.Block.HAZARD:
			status = "⚠ " + tr("HELM_TI_ROUTE_HAZARD")
		_:
			status = tr("HELM_TI_ROUTE_CLEAR")
	if not _route_waypoints.is_empty():
		status += " · " + tr("HELM_TI_ROUTE_WP").format({"n": _route_waypoints.size()})
	_ti_route.set_value(status)


func _ti_body() -> void:
	var body := _resolve_body(_sel_id)
	if body == null:
		_ti_none()
		return
	_ti_name.set_value(tr(body.name_key))
	_ti_type.set_value(_body_kind_label(body.kind))
	_set_route_dist_eta_rm()
	var bits: Array[String] = []
	if body.parent_id != "":
		var parent := _resolve_body(body.parent_id)
		if parent != null:
			bits.append(tr("HELM_TI_ORBITS").format({"parent": tr(parent.name_key)}))
	if body.can_dock and body.can_refuel:
		bits.append(tr("HELM_TI_DOCK_REFUEL"))
	elif body.can_dock:
		bits.append(tr("HELM_TI_DOCK"))
	if _selection_has_moons():
		bits.append(tr("HELM_TI_HAS_MOONS"))
	_ti_status.set_value(" · ".join(bits) if not bits.is_empty() else "—")


func _ti_contact() -> void:
	var contact := _resolve_contact(_sel_id)
	if contact == null:
		_ti_none()
		return
	var identified := GameState.contacts.tier_of(_sel_id) == Sensors.Tier.IDENTIFIED
	_ti_name.set_value(tr(contact.name_key) if identified else tr("NAV_CONTACT_UNKNOWN"))
	_ti_type.set_value(_contact_kind_label(contact.kind) if identified else tr("NAV_CONTACT_UNKNOWN"))
	_set_route_dist_eta_rm()
	var bits: Array[String] = [tr("HELM_TI_TIER_IDENTIFIED") if identified else tr("HELM_TI_TIER_BLIP")]
	if not identified and GameState.ship.position.distance_to(contact.position) <= GameState.ship.sensor_range:
		bits.append(tr("HELM_TI_SCAN_READY"))
	_ti_status.set_value(" · ".join(bits))


func _ti_point() -> void:
	_ti_name.set_value(tr("NAV_WAYPOINT"))
	_ti_type.set_value(tr("NAV_WAYPOINT"))
	var rel := _sel_point - GameState.ship.position
	var deg := int(roundf(rad_to_deg(rel.angle())))
	deg = ((deg % 360) + 360) % 360
	var dist := _plotted_distance()
	_ti_dist.set_value(tr("HELM_TI_BEARING_FORMAT").format({"deg": deg, "wu": "%.0f" % dist}))
	var cost := FlightMath.rm_cost(dist, _burn)
	_ti_eta.set_value(_format_eta(FlightMath.eta_ticks(dist, _burn)))
	_ti_rm.set_value("%s — %s" % [_format_rm(cost), _reach_label(cost)])
	_ti_status.set_value("—")


func _ti_none() -> void:
	_ti_name.set_value(tr("HELM_NO_TARGET"))
	_ti_type.set_value("—")
	_ti_dist.set_value("—")
	_ti_eta.set_value("—")
	_ti_rm.set_value("—")
	_ti_status.set_value(_overview_text())


## Route distance (AU + wu), ETA, and RM-cost-with-reachability over the whole
## plotted route (ship → waypoints → target), so waypoint drags update it (ADR 0028).
func _set_route_dist_eta_rm() -> void:
	var d := _plotted_distance()
	_ti_dist.set_value(tr("HELM_TI_DIST_FORMAT").format({
		"au": "%.2f" % (d / Travel.WU_PER_AU), "wu": "%.0f" % d,
	}))
	_ti_eta.set_value(_format_eta(FlightMath.eta_ticks(d, _burn)))
	var cost := FlightMath.rm_cost(d, _burn)
	_ti_rm.set_value("%s — %s" % [_format_rm(cost), _reach_label(cost)])


## Can the current tank reach there and back / one-way / not at all (ADR 0025)?
func _reach_label(cost: float) -> String:
	var rm := GameState.ship.reaction_mass
	if cost * 2.0 <= rm:
		return tr("HELM_TI_REACH_ROUNDTRIP")
	if cost <= rm:
		return tr("HELM_TI_REACH_ONEWAY")
	return tr("HELM_TI_REACH_NONE")


## "Nothing selected" overview: body count, contacts seen, nearest unscanned blip.
func _overview_text() -> String:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return "—"
	var seen := 0
	var nearest_blip := INF
	for contact: ContactData in system.contacts:
		var tier := GameState.contacts.tier_of(contact.id)
		if tier != Sensors.Tier.UNDETECTED:
			seen += 1
		if tier == Sensors.Tier.BLIP:
			nearest_blip = minf(nearest_blip, GameState.ship.position.distance_to(contact.position))
	var text := tr("HELM_TI_OVERVIEW").format({
		"bodies": system.bodies.size(), "seen": seen, "total": system.contacts.size(),
	})
	if nearest_blip < INF:
		text += " · " + tr("HELM_TI_NEAREST").format({"wu": "%.0f" % nearest_blip})
	return text


func _body_kind_label(kind: int) -> String:
	match kind:
		BodyData.Kind.STAR:
			return tr("HELM_TYPE_STAR")
		BodyData.Kind.STATION:
			return tr("HELM_TYPE_STATION")
		BodyData.Kind.MOON:
			return tr("HELM_TYPE_MOON")
		_:
			return tr("HELM_TYPE_PLANET")


func _contact_kind_label(kind: int) -> String:
	match kind:
		ContactData.Kind.SHIP:
			return tr("HELM_KIND_SHIP")
		ContactData.Kind.DERELICT:
			return tr("HELM_KIND_DERELICT")
		ContactData.Kind.ANOMALY:
			return tr("HELM_KIND_ANOMALY")
		ContactData.Kind.PROBE:
			return tr("HELM_KIND_PROBE")
		ContactData.Kind.DEBRIS:
			return tr("HELM_KIND_DEBRIS")
		_:
			return tr("HELM_KIND_SIGNAL")


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


func _resolve_contact(contact_id: String) -> ContactData:
	if contact_id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for contact: ContactData in system.contacts:
		if contact.id == contact_id:
			return contact
	return null


## Destination point of the current selection (body/contact position or the point).
func _selected_position() -> Vector2:
	match _sel_kind:
		Travel.TargetKind.BODY:
			var body := _resolve_body(_sel_id)
			return body.position if body != null else GameState.ship.position
		Travel.TargetKind.CONTACT:
			var contact := _resolve_contact(_sel_id)
			return contact.position if contact != null else GameState.ship.position
		Travel.TargetKind.POINT:
			return _sel_point
	return GameState.ship.position


## Display name of the current selection. An un-identified contact reads as
## "unknown" until scanned; a free point is a "Waypoint" (ADR 0012/0020).
func _selected_name() -> String:
	match _sel_kind:
		Travel.TargetKind.BODY:
			var body := _resolve_body(_sel_id)
			return tr(body.name_key) if body != null else tr("HELM_NO_TARGET")
		Travel.TargetKind.CONTACT:
			var contact := _resolve_contact(_sel_id)
			if contact == null:
				return tr("HELM_NO_TARGET")
			if GameState.contacts.tier_of(_sel_id) == Sensors.Tier.IDENTIFIED:
				return tr(contact.name_key)
			return tr("NAV_CONTACT_UNKNOWN")
		Travel.TargetKind.POINT:
			return tr("NAV_WAYPOINT")
	return tr("HELM_NO_TARGET")
