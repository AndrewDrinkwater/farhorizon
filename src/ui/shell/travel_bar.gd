class_name TravelBar
extends PanelContainer
## A persistent travel indicator (ADR 0035), shell-global so it shows on EVERY
## console: while a course is under way it names the destination, glides a ship
## marker along the course line, and shows a live ETA. Mirrors the dock/altitude
## transition bars, but for space transit and across all screens. Reads state,
## never mutates (ADR 0014). Hidden when not under way.

var _dest: Label
var _track: TravelTrack
var _eta: Label
var _total: float = 0.0      # course distance captured at engage, for the progress fraction
var _active_id: String = ""  # detects a fresh course (new destination)
# Render interpolation (ADR 0004): the marker glides between tick positions instead
# of stepping once per in-game minute.
var _ship_prev: Vector2 = Vector2.ZERO
var _ship_curr: Vector2 = Vector2.ZERO


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_top = 60.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560.0, 0.0)
	add_theme_stylebox_override("panel", TerminalTheme.bank_box())
	_build()
	EventBus.sim_tick.connect(_on_tick)  # snapshot the per-tick position for interpolation
	EventBus.flight_state_changed.connect(_refresh.unbind(1))
	EventBus.ship_context_changed.connect(_refresh)
	EventBus.course_completed.connect(_refresh)
	EventBus.game_state_loaded.connect(_refresh)
	_refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_dest = Label.new()
	_dest.add_theme_color_override("font_color", Palette.TEXT)
	row.add_child(_dest)
	_track = TravelTrack.new()
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_track)
	_eta = Label.new()
	_eta.add_theme_font_override("font", TerminalTheme.mono_font())
	_eta.add_theme_color_override("font_color", Palette.STATUS_INFO)
	row.add_child(_eta)


## State-driven: visibility, destination name, and the per-course total (captured
## once). The smooth progress/ETA update happens every frame in _process.
func _refresh() -> void:
	if _dest == null:
		return
	var ship: ShipState = GameState.ship
	var order: Dictionary = ship.current_order
	var under_way := String(order.get("type", "")) == "course" and bool(order.get("engaged", false))
	visible = under_way
	if not under_way:
		_active_id = ""
		return

	# Capture the total distance once per course so the marker shows real progress.
	var id := String(order.get("target_id", "")) + "@" + str(order.get("dest", Vector2.ZERO))
	if id != _active_id:
		_active_id = id
		_total = maxf(ship.position.distance_to(_dest_pos(order)), 1.0)
		_ship_curr = ship.position
		_ship_prev = ship.position

	_dest.text = tr("TRAVEL_BAR_DEST").format({"dest": _dest_name(order)})
	_update_progress()


func _on_tick(_tick: int) -> void:
	_ship_prev = _ship_curr
	_ship_curr = GameState.ship.position


func _process(_delta: float) -> void:
	if visible:
		_update_progress()  # glide the marker between ticks (ADR 0004)


## The marker / ETA from the interpolated ship position — smooth, not stepped.
func _update_progress() -> void:
	var order: Dictionary = GameState.ship.current_order
	var remaining := _interp_ship().distance_to(_dest_pos(order))
	_track.set_progress(1.0 - remaining / maxf(_total, 1.0))
	var ticks := FlightMath.eta_ticks(remaining, int(order.get("burn", FlightMath.Burn.STANDARD)))
	_eta.text = tr("TRAVEL_BAR_ETA").format({
		"hours": ticks / 60, "mins": "%02d" % (ticks % 60),
	})


## Ship position eased between the last two ticks while under way in deep space
## (ADR 0004); the live position otherwise.
func _interp_ship() -> Vector2:
	var ship: ShipState = GameState.ship
	if bool(ship.current_order.get("engaged", false)) and ship.location == Travel.Location.DEEP_SPACE:
		return _ship_prev.lerp(_ship_curr, SimClock.get_tick_fraction())
	return ship.position


func _dest_pos(order: Dictionary) -> Vector2:
	var body := _body(String(order.get("target_id", "")))
	if body != null:
		return body.position
	return order.get("dest", GameState.ship.position)


func _dest_name(order: Dictionary) -> String:
	var id := String(order.get("target_id", ""))
	var body := _body(id)
	if body != null:
		return tr(body.name_key)
	var contact := _contact(id)
	if contact != null:
		if GameState.contacts.tier_of(id) == Sensors.Tier.IDENTIFIED:
			return tr(contact.name_key)
		return tr("NAV_CONTACT_UNKNOWN")
	return tr("NAV_WAYPOINT")


func _body(id: String) -> BodyData:
	if id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if body.id == id:
			return body
	return null


func _contact(id: String) -> ContactData:
	if id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for contact: ContactData in system.contacts:
		if contact.id == id:
			return contact
	return null
