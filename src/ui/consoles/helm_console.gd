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

# The Helm owns the nav-view stage (ADR 0031): orrery / tactical scope / surface /
# focus inset, drawn behind its panels. The shell shows it only while Helm is active.
const OrreryViewScene := preload("res://src/world/orrery_view.gd")
const TacticalViewScene := preload("res://src/world/tactical_view.gd")
const SurfaceViewScene := preload("res://src/world/surface_view.gd")
const MoonInsetViewScene := preload("res://src/world/moon_inset_view.gd")
const NavBackdropScene := preload("res://src/world/nav_backdrop.gd")

var _frame: ConsoleFrame  # the ship-OS layout (ADR 0034): left / right / deck slots
var _stage: Control  # clip box bounding the nav views to the plot region (ADR 0035)
var _backdrop: NavBackdrop  # idle instrument backdrop behind the nav views (ADR 0035)
var _orrery: OrreryView
var _tactical: TacticalView
var _surface: SurfaceView
var _surface_pick: bool = false  # surface map requested for an Open-Landing pick (ADR 0030)

# Compose state — the Nav Plot selection: a body, a contact, or a free point
# (ADR 0020). `_sel_id` is the body/contact id ("" for a point); `_sel_point` is
# the destination for a free waypoint.
var _sel_kind: int = Travel.TargetKind.NONE
var _sel_id: String = ""
var _sel_point: Vector2 = Vector2.ZERO
var _route_waypoints: Array[Vector2] = []  # intermediate route points (ADR 0027)
var _plot_laid_in: bool = false  # has the current plot been laid in? (solid vs dashed, ADR 0028)
var _surface_target_id: String = ""  # picked surface site — land/move destination ("" = Open Landing/free, ADR 0030)
var _surface_target_pos: Vector2 = Vector2.ZERO  # the target's surface coords (su) — site pos or free point
var _picking_landing: bool = false   # Open Landing selected while orbiting → surface map shown to pick a spot
var _map_shown_requested: bool = false  # last surface_map_requested value (emit only on change)
var _picker_key: String = ""  # cached picker context (body+location), rebuilt when it changes
var _site_picker: HBoxContainer
var _site_buttons: Dictionary = {}  # site id:String -> TButton
var _burn: int = FlightMath.Burn.STANDARD
var _scale: int = OrreryParams.ScaleMode.LOG  # orrery schematic ↔ true scale (ADR 0021)
var _ring_mode: int = TacticalView.RingMode.ISOCHRONE  # scope ETA ↔ distance rings
var _tactical_active: bool = false  # which nav view the mode toggle targets
var _flight_state: int = FlightCore.State.IDLE

# Course Order widgets
var _target_readout: TReadout
var _distance_readout: TReadout
var _eta_readout: TReadout
var _rm_readout: TReadout
var _throttle: ThrottlePill  # 5-tier burn throttle in the Control panel (ADR 0035)
var _scale_switch: CheckButton  # context toggle on the map (orrery scale / scope rings)
var _scale_caption: Label
var _scale_value: Label         # fixed-width mode label so the control never resizes/clips
var _scale_overlay: PanelContainer  # the scale toggle, floated bottom-centre on the map
var _map_controls: Control          # Lock-on-ship / Fit controls, top-left on the map (orrery only)
var _pip_readout: TReadout      # between-pip distance/time legend (ADR 0019)
var _action_buttons: Dictionary = {}  # order id:String -> TButton
var _control_deck: ControlDeck        # the deck of command Sections (ADR 0034)

# Nav contacts directory (ADR 0032): a filterable hierarchy of bodies + contacts.
var _dir_list: VBoxContainer
var _dir_category: int = 0  # 0 all · 1 bodies · 2 contacts
var _dir_tier: int = 0      # 0 all · 1 blip · 2 identified (contacts)
var _dir_in_range: bool = false
var _dir_filter_buttons: Dictionary = {}  # "cat:0" etc. -> Button

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

# Transition indicators (ADR 0033): shown only during a timed transition.
var _transition_panel: TPanel
var _alt_indicator: AltitudeIndicator
var _dock_indicator: DockIndicator
var _tick_accum: float = 0.0  # speed-scaled seconds since the last tick (smooth progress)


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
	_build_stage()        # nav views first → drawn behind the frame (ADR 0031)
	_frame = ConsoleFrame.new()  # ship-OS layout (ADR 0034): fixed boxes, console fills them
	add_child(_frame)
	# Bound the nav plot to the region between the drawers (ADR 0035): re-push on any
	# layout change (drawer toggle, window resize) so it fills/centres that region.
	_frame.centre().resized.connect(_push_view_region)
	# The frame's fixed boxes — the Helm only sets each title and pours content in.
	_build_course_order()   # → secondary box
	_build_controls()       # clustered orders (ADR 0032) → control box
	_build_scale_overlay()  # scale/view toggle floated bottom-centre on the map (ADR 0035)
	_build_map_controls()   # Lock-on-ship / Fit, top-left on the map (ADR 0035)
	_build_directory()      # nav contacts directory (ADR 0032) → left drawer
	_build_flight_status()  # → info box (bottom-right); ack line → toast
	_build_target_info()    # → right drawer
	_build_transition_indicators()  # altitude / dock approach (ADR 0033) → toast
	_build_inset()          # focus inset draws over the panels (ADR 0022)
	_connect_bus()
	_refresh_all()
	_update_nav_views()
	EventBus.nav_burn_changed.emit(_burn)  # sync the nav views to the starting burn (ADR 0019)
	EventBus.nav_scale_changed.emit(_scale)  # sync the orrery to the starting scale (ADR 0021)
	EventBus.nav_ring_mode_changed.emit(_ring_mode)  # sync the scope's ring mode
	_push_view_region.call_deferred()  # bound the plot to the centre region once laid out (ADR 0035)


## The shell mounts the console-select tabs here — just above the control panel (ADR 0034).
func console_select_host() -> Control:
	return _frame.console_select()


# --- Nav-view stage (ADR 0031, moved from the shell root) ---

## Build the nav views as children behind the panels (added before them in _ready).
func _build_stage() -> void:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return
	# A clip Control bounds the stage to the plot region so the map can never be
	# dragged/zoomed past its display box (ADR 0035). Views draw in its local space.
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_backdrop = NavBackdropScene.new()  # idle instrument backdrop, behind all views (ADR 0035)
	_stage.add_child(_backdrop)
	_orrery = OrreryViewScene.new()
	_stage.add_child(_orrery)
	_orrery.build(system)
	_tactical = TacticalViewScene.new()
	_tactical.visible = false
	_stage.add_child(_tactical)
	_tactical.build(system)
	_surface = SurfaceViewScene.new()
	_surface.visible = false
	_stage.add_child(_surface)
	_surface.build(system)


## Focus inset (ADR 0022): drawn over the panels, so added last.
func _build_inset() -> void:
	if _orrery == null:
		return
	var inset := MoonInsetViewScene.new()
	add_child(inset)
	inset.build(TypeRegistry.get_system(GameState.system.system_id))


## Toggle the strategic orrery ↔ the tactical scope (ignored while landed / picking,
## and while another console is active). The surface owns the stage when landed.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tactical") and is_visible_in_tree() and _orrery != null \
			and GameState.ship.location != Travel.Location.LANDED and not _surface_pick:
		EventBus.nav_view_changed.emit(not _tactical_active)  # _on_view_changed applies it


func _on_surface_map_requested(show: bool) -> void:
	_surface_pick = show
	_update_nav_views()


## Show the surface map while LANDED or picking a landing spot, else the orrery or
## scope per the T toggle (ADR 0030/0031).
func _update_nav_views() -> void:
	if _orrery == null:
		return
	var surface_on := GameState.ship.location == Travel.Location.LANDED or _surface_pick
	_surface.visible = surface_on
	_orrery.visible = not surface_on and not _tactical_active
	_tactical.visible = not surface_on and _tactical_active
	if _backdrop != null:
		_backdrop.visible = not surface_on  # the scope/orrery backdrop, not the surface map
	if _map_controls != null:
		_map_controls.visible = _orrery.visible  # lock/fit apply to the orrery only
	if _scale_overlay != null:
		_scale_overlay.visible = not surface_on  # scale (orrery) / rings (scope), not surface


## Push the plot region (the area between the drawers) to every nav view + backdrop
## so they centre/bound to it and grow when a drawer retracts (ADR 0035).
func _push_view_region() -> void:
	if _orrery == null or _frame == null:
		return
	var region := _frame.centre().get_global_rect()
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return
	# Position + size the clip box to the region; the views draw in its local space.
	_stage.global_position = region.position
	_stage.size = region.size
	var local := Rect2(Vector2.ZERO, region.size)
	_orrery.set_view_rect(local)
	_tactical.set_view_rect(local)
	_surface.set_view_rect(local)
	_backdrop.set_view_rect(local)


# --- Course Order region (compose + issue) ---

func _build_course_order() -> void:
	_frame.secondary().set_title("HELM_COURSE_ORDER")
	var c := _frame.secondary().content()

	_target_readout = TReadout.new("HELM_TARGET")
	c.add_child(_target_readout)

	# Burn intensity now lives on the throttle pill in the Control panel (ADR 0035).
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

	# Landing-site picker (ADR 0030): Open Landing + the body's sites; shown only when
	# holding at a landable body or landed. Rebuilt when that context changes.
	_site_picker = HBoxContainer.new()
	_site_picker.add_theme_constant_override("separation", 4)
	_site_picker.visible = false
	c.add_child(_site_picker)

	_refresh_burn_buttons()


## The control deck (ADR 0034): the command Sections — Flight / Docking / Surface
## / Sensors — built from a descriptor and fed into a reusable ControlDeck. A whole
## section hides when it doesn't apply (HelmGroups, ADR 0032); buttons within a
## visible section grey via Travel.available. The deck sizes to its tallest section
## — no fixed band to overhang.
func _build_controls() -> void:
	_frame.control().set_title("HELM_CONTROLS")
	_frame.control().set_role(TPanel.Role.CONTROL)  # raised control bank (ADR 0035)
	# Throttle pill on the left, command clusters filling the rest (ADR 0035).
	var rowbox := HBoxContainer.new()
	rowbox.add_theme_constant_override("separation", 18)
	rowbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.control().content().add_child(rowbox)
	_throttle = ThrottlePill.new().setup(_select_burn)
	rowbox.add_child(_throttle)
	_control_deck = ControlDeck.new()  # the sections row; the frame owns the fixed box
	rowbox.add_child(_control_deck)
	for spec: Dictionary in _deck_sections():
		var section := Section.new(spec["id"], spec["header"])
		for a: Array in spec["actions"]:
			section.add_widget(_make_action(a[0], a[1], a[2]))
		_control_deck.add_section(section)
	# The one commit action per context reads as primary (filled accent, ADR 0035).
	for id: String in ["engage", "land", "dock"]:
		if _action_buttons.has(id):
			(_action_buttons[id] as TButton).make_primary()


## Code-built deck descriptor (ADR 0034): each section's id (for the visibility
## resolver), header, and its order buttons [id, label key, action callable].
func _deck_sections() -> Array[Dictionary]:
	return [
		{"id": "flight", "header": "HELM_GRP_FLIGHT", "actions": [
			["lay_in", "HELM_LAY_IN_COURSE", _lay_in_course], ["engage", "HELM_ENGAGE", _engage],
			["all_stop", "HELM_ALL_STOP", _all_stop],
			["clear_course", "HELM_CLEAR_COURSE", _clear_route],
		]},
		{"id": "docking", "header": "HELM_GRP_DOCKING", "actions": [
			["dock", "HELM_DOCK", _dock], ["undock", "HELM_UNDOCK", _undock],
		]},
		{"id": "surface", "header": "HELM_GRP_SURFACE", "actions": [
			["land", "HELM_LAND", _land], ["take_off", "HELM_TAKE_OFF", _take_off],
			["move", "HELM_MOVE", _move], ["abort_land", "HELM_ABORT_LAND", _abort_landing],
		]},
		{"id": "sensors", "header": "HELM_GRP_SENSORS", "actions": [
			["scan", "HELM_SCAN", _scan], ["focus", "HELM_FOCUS", _focus],
		]},
	]


## The scale/view toggle (ADR 0021/0023) lives ON the map (ADR 0035): a small
## control floated in the top-left of the centre screen — a view control belongs on
## the view it controls, not in the order compose box. A CheckButton showing the
## current orrery scale (or the scope's ring mode when the tactical view is active).
func _build_scale_overlay() -> void:
	_scale_overlay = PanelContainer.new()
	_scale_overlay.add_theme_stylebox_override("panel", TerminalTheme.bank_box())
	_scale_overlay.custom_minimum_size = Vector2(240.0, 0.0)  # fixed — never resizes with the label
	_frame.centre().add_child(_scale_overlay)
	# Bottom-centre of the map, content-sized height, pinned above the band.
	_scale_overlay.anchor_left = 0.5
	_scale_overlay.anchor_right = 0.5
	_scale_overlay.anchor_top = 1.0
	_scale_overlay.anchor_bottom = 1.0
	_scale_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_scale_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_scale_overlay.offset_bottom = -10.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_scale_overlay.add_child(row)
	_scale_caption = Label.new()
	_scale_caption.custom_minimum_size = Vector2(46.0, 0.0)
	_scale_caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(_scale_caption)
	# Fixed-width mode label + a toggle-only switch → the control never resizes or
	# clips its text as the mode changes (ADR 0035).
	_scale_value = Label.new()
	_scale_value.custom_minimum_size = Vector2(100.0, 0.0)
	row.add_child(_scale_value)
	_scale_switch = CheckButton.new()
	_scale_switch.toggled.connect(_on_scale_toggled)
	row.add_child(_scale_switch)
	_refresh_toggle()


## Lock-on-ship / Fit controls floated in the map's top-left (orrery only, ADR 0035).
func _build_map_controls() -> void:
	_map_controls = PanelContainer.new()
	_map_controls.add_theme_stylebox_override("panel", TerminalTheme.bank_box())
	_frame.centre().add_child(_map_controls)
	_map_controls.anchor_left = 0.0
	_map_controls.anchor_top = 0.0
	_map_controls.offset_left = 28.0  # clear of the corner bracket
	_map_controls.offset_top = 10.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_map_controls.add_child(row)
	row.add_child(TButton.new().setup("HELM_MAP_LOCK", _orrery.lock_on_ship))
	row.add_child(TButton.new().setup("HELM_MAP_FIT", _orrery.fit_system))


func _make_action(id: String, label_key: String, on_press: Callable) -> TButton:
	var button := TButton.new().setup(label_key, on_press)
	button.custom_minimum_size = Vector2(132.0, 0.0)  # uniform width → a substantial bar
	_action_buttons[id] = button
	return button


# --- Flight Status region (live readouts) ---

func _build_flight_status() -> void:
	_frame.info().set_title("HELM_FLIGHT_STATUS")  # bottom-right Info box (ADR 0034)
	var c := _frame.info().content()

	_status_light = TLight.new("HELM_STATUS")
	c.add_child(_status_light)
	_status_distance = TReadout.new("HELM_DISTANCE")
	c.add_child(_status_distance)
	_status_eta = TReadout.new("HELM_ETA")
	c.add_child(_status_eta)
	_fuel_gauge = TGauge.new("HUD_REACTION_MASS")
	c.add_child(_fuel_gauge)
	_fuel_gauge.bind(_fuel_data)

	# Transient ship-voice line (ADR 0025): an ack/reject flashes in the top-centre
	# notification toast (ADR 0034), then fades. It needs an explicit width — the
	# toast is content-sized, so autowrap with no width would wrap per character.
	_ack_line = Label.new()
	_ack_line.custom_minimum_size = Vector2(520.0, 0.0)
	_ack_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ack_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ack_line.add_theme_color_override("font_color", Palette.STATUS_INFO)
	_ack_line.modulate.a = 0.0
	_frame.toast().add_child(_ack_line)


# --- Target Information region (ADR 0025): replaces the Order Log ---

func _build_target_info() -> void:
	_frame.right().set_title("HELM_TARGET_INFO")  # right drawer (ADR 0034)
	_frame.set_drawer_label(false, tr("HELM_TI_TAB"))
	var c := _frame.right().content()
	# .fill() so long target values wrap within the drawer rather than widening it —
	# keeps the right drawer the same fixed width as the left (ADR 0035).
	_ti_name = TReadout.new("HELM_TI_NAME").fill()
	c.add_child(_ti_name)
	_ti_type = TReadout.new("HELM_TI_TYPE").fill()
	c.add_child(_ti_type)
	_ti_dist = TReadout.new("HELM_TI_DIST").fill()
	c.add_child(_ti_dist)
	_ti_eta = TReadout.new("HELM_ETA").fill()
	c.add_child(_ti_eta)
	_ti_rm = TReadout.new("HELM_TI_RM").fill()
	c.add_child(_ti_rm)
	_ti_status = TReadout.new("HELM_TI_STATUS").fill()
	c.add_child(_ti_status)
	_ti_route = TReadout.new("HELM_TI_ROUTE").fill()
	c.add_child(_ti_route)


# --- Transition indicators (ADR 0033) ---

## A centred panel holding the altitude gauge (descent/ascent) and the dock approach
## bar (dock/undock); shown only during the matching transition.
func _build_transition_indicators() -> void:
	_transition_panel = TPanel.new("")
	_transition_panel.custom_minimum_size = Vector2(260.0, 0.0)
	_frame.toast().add_child(_transition_panel)  # top-centre notification toast (ADR 0034)
	_transition_panel.visible = false
	var c := _transition_panel.content()
	_alt_indicator = AltitudeIndicator.new()
	c.add_child(_alt_indicator)
	_dock_indicator = DockIndicator.new()
	c.add_child(_dock_indicator)


## Drive the active indicator each frame with smooth (sub-tick) progress; hide the
## panel when no transition is running.
func _process(delta: float) -> void:
	_tick_accum += delta * SimClock.get_speed()
	_update_transition_indicators()


func _update_transition_indicators() -> void:
	if _transition_panel == null:
		return
	var st := _flight_state
	var body := _resolve_body(GameState.ship.location_body_id)
	if st == FlightCore.State.DESCENDING or st == FlightCore.State.ASCENDING:
		_transition_panel.visible = true
		_alt_indicator.visible = true
		_dock_indicator.visible = false
		_alt_indicator.configure(body.atmosphere_atm if body != null else 0.0,
			_transition_progress(), st == FlightCore.State.DESCENDING)
	elif st == FlightCore.State.DOCKING or st == FlightCore.State.UNDOCKING:
		_transition_panel.visible = true
		_alt_indicator.visible = false
		_dock_indicator.visible = true
		_dock_indicator.configure(_transition_progress(), st == FlightCore.State.UNDOCKING)
	else:
		_transition_panel.visible = false


## Fraction through the current timed transition, smoothed by the sub-tick accum.
func _transition_progress() -> float:
	var o: Dictionary = GameState.ship.current_order
	var total := maxf(1.0, float(o.get("ticks_total", 1)))
	var done := total - float(o.get("ticks_left", total))
	return clampf((done + _tick_accum / SimClock.SECONDS_PER_TICK) / total, 0.0, 1.0)


# --- Nav contacts directory (ADR 0032) ---

## A filterable hierarchy of all targets (charted bodies + detected contacts) down
## the left edge; selecting an entry drives nav_target_selected → Target Info + plot.
func _build_directory() -> void:
	_frame.left().set_title("HELM_DIRECTORY")  # left drawer (ADR 0034)
	_frame.set_drawer_label(true, tr("HELM_DIR_TAB"))
	var c := _frame.left().content()

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 4)
	c.add_child(cat_row)
	cat_row.add_child(_dir_filter("cat:0", "HELM_DIR_ALL", _set_category.bind(0)))
	cat_row.add_child(_dir_filter("cat:1", "HELM_DIR_BODIES", _set_category.bind(1)))
	cat_row.add_child(_dir_filter("cat:2", "HELM_DIR_CONTACTS", _set_category.bind(2)))

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 4)
	c.add_child(tier_row)
	tier_row.add_child(_dir_filter("tier:0", "HELM_DIR_TIER_ALL", _set_tier.bind(0)))
	tier_row.add_child(_dir_filter("tier:1", "HELM_DIR_TIER_BLIP", _set_tier.bind(1)))
	tier_row.add_child(_dir_filter("tier:2", "HELM_DIR_TIER_ID", _set_tier.bind(2)))

	var rng := CheckButton.new()
	rng.text = tr("HELM_DIR_IN_RANGE")
	rng.toggled.connect(func(p: bool) -> void: _dir_in_range = p; _refresh_directory())
	c.add_child(rng)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	_dir_list = VBoxContainer.new()
	_dir_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_dir_list)

	_refresh_filter_chips()
	_refresh_directory()


func _dir_filter(key: String, label_key: String, on_press: Callable) -> Button:
	var b := TButton.new().setup(label_key, on_press)
	_dir_filter_buttons[key] = b
	return b


func _set_category(n: int) -> void:
	_dir_category = n
	_refresh_filter_chips()
	_refresh_directory()


func _set_tier(n: int) -> void:
	_dir_tier = n
	_refresh_filter_chips()
	_refresh_directory()


## Highlight the active filter chips (accent + arrow — shape, not colour alone).
func _refresh_filter_chips() -> void:
	for key: String in _dir_filter_buttons:
		var parts := key.split(":")
		var on := (parts[0] == "cat" and int(parts[1]) == _dir_category) \
			or (parts[0] == "tier" and int(parts[1]) == _dir_tier)
		_dir_filter_buttons[key].modulate = Palette.ACCENT if on else Color.WHITE


## Rebuild the directory list from the system + live detection state, filtered.
func _refresh_directory() -> void:
	if _dir_list == null:
		return
	for child: Node in _dir_list.get_children():
		child.queue_free()
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return
	if _dir_category != 2:  # bodies (all / bodies-only)
		_dir_add_bodies(system)
	if _dir_category != 1:  # contacts (all / contacts-only)
		_dir_add_contacts(system)


## Bodies as a hierarchy: star → planets/stations → moons (parent-relative, ADR 0018).
func _dir_add_bodies(system: SystemData) -> void:
	for star: BodyData in system.bodies:
		if star.kind != BodyData.Kind.STAR:
			continue
		_dir_try_entry(star, 0)
	for body: BodyData in system.bodies:
		if body.kind == BodyData.Kind.STAR or body.parent_id != "":
			continue
		_dir_try_entry(body, 1)
		for moon: BodyData in system.bodies:
			if moon.parent_id == body.id:
				_dir_try_entry(moon, 2)


## Add a body row if it passes the in-range filter (bodies are charted → no tier).
func _dir_try_entry(body: BodyData, depth: int) -> void:
	if _dir_in_range and GameState.ship.position.distance_to(body.position) > GameState.ship.sensor_range:
		return
	var glyph := _body_kind_glyph(body.kind)
	_dir_entry(body.id, "%s %s" % [glyph, tr(body.name_key)], depth)


func _dir_add_contacts(system: SystemData) -> void:
	var header := Label.new()
	header.text = tr("HELM_DIR_CONTACTS")
	header.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_dir_list.add_child(header)
	for contact: ContactData in system.contacts:
		var tier := GameState.contacts.tier_of(contact.id)
		if tier == Sensors.Tier.UNDETECTED:
			continue  # only what we're actually picking up
		if _dir_tier == 1 and tier != Sensors.Tier.BLIP:
			continue
		if _dir_tier == 2 and tier != Sensors.Tier.IDENTIFIED:
			continue
		if _dir_in_range and GameState.ship.position.distance_to(contact.position) > GameState.ship.sensor_range:
			continue
		var identified := tier == Sensors.Tier.IDENTIFIED
		var glyph := "◆" if identified else "•?"  # shape channel for tier (ADR 0012)
		var name := tr(contact.name_key) if identified else tr("NAV_CONTACT_UNKNOWN")
		_dir_entry(contact.id, "%s %s" % [glyph, name], 1)


## One selectable row; indents by depth; highlights the current selection.
func _dir_entry(id: String, label: String, depth: int) -> void:
	var b := TButton.new().setup_text("    ".repeat(depth) + label, _on_directory_pick.bind(id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == _sel_id and _sel_kind != Travel.TargetKind.NONE:
		b.modulate = Palette.ACCENT  # selected entry marked
	_dir_list.add_child(b)


## Directory selection drives the same path as a map click (ADR 0032).
func _on_directory_pick(id: String) -> void:
	EventBus.nav_target_selected.emit(id)


func _body_kind_glyph(kind: int) -> String:
	match kind:
		BodyData.Kind.STAR:
			return "★"
		BodyData.Kind.STATION:
			return "⛢"
		BodyData.Kind.MOON:
			return "◖"
		_:
			return "●"


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
	EventBus.nav_view_changed.connect(_on_view_changed)
	EventBus.surface_site_selected.connect(_on_surface_site_selected)
	EventBus.surface_point_selected.connect(_on_surface_point_selected)
	EventBus.surface_map_requested.connect(_on_surface_map_requested)
	EventBus.ship_context_changed.connect(_update_nav_views)
	EventBus.ship_context_changed.connect(_refresh_all)
	EventBus.sim_tick.connect(_on_tick.unbind(1))
	EventBus.fuel_changed.connect(_on_fuel_changed)
	EventBus.order_acknowledged.connect(_on_order_acknowledged)
	EventBus.order_rejected.connect(_on_order_rejected)
	EventBus.game_state_loaded.connect(_refresh_all)
	EventBus.game_state_loaded.connect(_update_nav_views)
	EventBus.system_changed.connect(_on_system_changed)


## A new system loaded (ADR 0024): the old selection is gone — clear it and refresh.
func _on_system_changed(_system_id: String) -> void:
	_sel_kind = Travel.TargetKind.NONE
	_sel_id = ""
	_sel_point = Vector2.ZERO
	_route_waypoints.clear()
	_refresh_all()
	_update_nav_views()
	_emit_route()


func _on_target_selected(target_id: String) -> void:
	_plot_laid_in = false  # a new plot isn't committed until Lay In (ADR 0028)
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
	_plot_laid_in = false
	_sel_kind = Travel.TargetKind.POINT
	_sel_id = ""
	_sel_point = point
	_route_waypoints.clear()
	_refresh_preview()
	_refresh_actions()
	_emit_route()


## A nav view dragged the course (ADR 0028): adopt the new waypoint list.
func _on_waypoints_set(waypoints: PackedVector2Array) -> void:
	_plot_laid_in = false  # editing the route un-commits it (reverts to dashed)
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
## Heading reached — the ship drifts. Keep the selection as a *proposal* (ghost),
## never auto-engaged (ADR 0036): we don't wipe the plot, just refresh. Re-emitting
## the route recomputes it from the arrival position (collapses if we arrived at the
## selected target, leaving no proposal).
func _on_course_completed() -> void:
	_plot_laid_in = false
	_refresh_preview()
	_refresh_status()
	_refresh_actions()
	_emit_route()


## Reset the compose plot (selection + waypoints) and clear the views' highlight.
func _reset_plot() -> void:
	_sel_kind = Travel.TargetKind.NONE
	_sel_id = ""
	_sel_point = Vector2.ZERO
	_route_waypoints.clear()
	_plot_laid_in = false
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
	_tick_accum = 0.0  # restart the sub-tick accumulator (smooth transition progress)
	_refresh_preview()
	_refresh_status()
	# Re-anchor the proposal to the ship so the ghost course tracks it (ADR 0036).
	if _sel_kind != Travel.TargetKind.NONE:
		_emit_route()


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


## The mode toggle drives the orrery scale, or — when the tactical scope is the
## active view — the scope's ring mode (ETA ↔ distance). Same switch, retargeted.
func _on_scale_toggled(pressed: bool) -> void:
	if _tactical_active:
		_select_ring_mode(TacticalView.RingMode.DISTANCE if pressed else TacticalView.RingMode.ISOCHRONE)
	else:
		_select_scale(OrreryParams.ScaleMode.LINEAR if pressed else OrreryParams.ScaleMode.LOG)


func _select_scale(mode: int) -> void:
	_scale = mode
	_refresh_toggle()
	EventBus.nav_scale_changed.emit(_scale)  # orrery remaps radii (ADR 0021)


func _select_ring_mode(mode: int) -> void:
	_ring_mode = mode
	_refresh_toggle()
	EventBus.nav_ring_mode_changed.emit(_ring_mode)  # scope swaps ETA ↔ distance rings


func _on_view_changed(tactical: bool) -> void:
	_tactical_active = tactical
	_update_nav_views()
	_refresh_toggle()


## Point the one toggle at the active view's mode: orrery scale, or scope rings.
func _refresh_toggle() -> void:
	if _scale_switch == null:
		return
	if _tactical_active:
		_scale_caption.text = tr("HELM_RINGS_LABEL")
		_scale_switch.set_pressed_no_signal(_ring_mode == TacticalView.RingMode.DISTANCE)
		_scale_value.text = tr("HELM_RINGS_DIST") if _ring_mode == TacticalView.RingMode.DISTANCE \
			else tr("HELM_RINGS_ETA")
	else:
		_scale_caption.text = tr("HELM_SCALE_LABEL")
		_scale_switch.set_pressed_no_signal(_scale == OrreryParams.ScaleMode.LINEAR)
		_scale_value.text = tr("HELM_SCALE_TRUE") if _scale == OrreryParams.ScaleMode.LINEAR \
			else tr("HELM_SCALE_SCHEMATIC")


func _lay_in_course() -> void:
	if _sel_kind == Travel.TargetKind.NONE:
		return
	EventBus.order_issued.emit({
		"type": "set_course", "target_id": _sel_id, "point": _sel_point,
		"waypoints": _route_waypoints.duplicate(), "burn": _burn,
	})
	_plot_laid_in = true  # the plot is now committed → draws solid (ADR 0028)
	_emit_route()


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
	EventBus.nav_route_changed.emit(_compose_route(), _plot_laid_in)


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


func _all_stop() -> void:
	EventBus.order_issued.emit({"type": "all_stop"})


func _dock() -> void:
	EventBus.order_issued.emit({"type": "dock"})


func _undock() -> void:
	EventBus.order_issued.emit({"type": "undock"})


## Land. A named site descends to its fixed spot at once. Open Landing first opens
## the surface map so the captain picks a touchdown point, then descends on the
## next press (ADR 0030) — so you always choose where you set down.
func _land() -> void:
	if _surface_target_id != "":
		EventBus.order_issued.emit({"type": "land", "site_id": _surface_target_id, "pos": _surface_target_pos})
		return
	if not _picking_landing:
		_picking_landing = true
		_sync_surface_map()  # opens the surface map to pick a spot
		_show_ack(CrewVoice.SHIP_VOICE, "VOICE_PICK_TOUCHDOWN")
		return
	EventBus.order_issued.emit({"type": "land", "site_id": "", "pos": _surface_target_pos})


## Back out of landing-spot selection without committing — return to the orbit view
## (ADR 0030 fix): the captain is no longer forced to land once the map is open.
func _abort_landing() -> void:
	_picking_landing = false
	_sync_surface_map()  # show == false now → hides the surface map, back to the orrery
	_show_ack(CrewVoice.SHIP_VOICE, "VOICE_LANDING_ABORTED")
	_refresh_actions()


func _take_off() -> void:
	EventBus.order_issued.emit({"type": "take_off"})


func _move() -> void:
	EventBus.order_issued.emit({"type": "move", "site_id": _surface_target_id, "pos": _surface_target_pos})


# --- Refresh ---

func _refresh_all() -> void:
	_refresh_preview()
	_refresh_status()
	_refresh_actions()
	_refresh_pip_legend()
	_fuel_gauge.refresh()


func _refresh_burn_buttons() -> void:
	if _throttle != null:
		_throttle.set_burn(_burn)


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
	# Abort Landing is a UI escape from spot-selection, only shown while picking (ADR 0030).
	if _action_buttons.has("abort_land"):
		_action_buttons["abort_land"].visible = _picking_landing
		_action_buttons["abort_land"].disabled = not _picking_landing
	# Hide whole sections that don't apply to the situation (ADR 0032/0034).
	_control_deck.apply_visibility(HelmGroups.visible_groups(_context()))
	_refresh_site_picker()
	_refresh_directory()


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
		"landable_here": location_body != null and location_body.landable,
		"in_transition": _in_transition(),
		"has_other_site": ship.location == Travel.Location.LANDED and _has_other_surface_site(location_body),
		"scanning": ship.scan_contact_id != "",
	}


## A timed transition (land/take-off/move, or dock/undock) is under way — busy.
func _in_transition() -> bool:
	var t := String(GameState.ship.current_order.get("type", ""))
	return t in ["land", "take_off", "surface_move", "dock", "undock"]


## Is there a surface site to Move to other than where we are? Open Landing ("")
## is always an alternative when parked at a named site (ADR 0030).
func _has_other_surface_site(body: BodyData) -> bool:
	if body == null:
		return false
	if GameState.ship.surface_site_id != "":
		return true
	return not body.surface_locations.is_empty()


# --- Surface site picker (ADR 0030) ---

func _on_surface_site_selected(site_id: String) -> void:
	_surface_target_id = site_id
	_surface_target_pos = _surface_pos(_picker_body(), site_id)
	_refresh_site_buttons()
	_refresh_target_info()


## A free point was clicked on the surface map — a free touchdown / move spot.
func _on_surface_point_selected(point: Vector2) -> void:
	_surface_target_id = ""
	_surface_target_pos = point
	_refresh_site_buttons()
	_refresh_target_info()


## A picker button (or the SurfaceView) picked a site — funnel through one signal.
## While orbiting, picking Open Landing opens the surface map to choose a spot; a
## named site closes it (lands at the fixed spot) — ADR 0030.
func _select_site(site_id: String) -> void:
	EventBus.surface_site_selected.emit(site_id)
	if _at_landable_orbit():
		_picking_landing = (site_id == "")
	_sync_surface_map()


func _at_landable_orbit() -> bool:
	var body := _resolve_body(GameState.ship.location_body_id)
	return GameState.ship.location == Travel.Location.HOLDING and body != null and body.landable


## Tell the shell whether to show the surface map for an Open-Landing pick (emit
## only on change). Picking is cleared whenever we're not orbiting a landable body.
func _sync_surface_map() -> void:
	if GameState.ship.location != Travel.Location.HOLDING:
		_picking_landing = false
	var show := _at_landable_orbit() and _picking_landing
	if show != _map_shown_requested:
		_map_shown_requested = show
		EventBus.surface_map_requested.emit(show)


## The body whose sites the picker lists: the landed body, or a landable body we're
## holding at. Null otherwise (picker hidden).
func _picker_body() -> BodyData:
	var ship: ShipState = GameState.ship
	if ship.location == Travel.Location.LANDED:
		return _resolve_body(ship.location_body_id)
	if ship.location == Travel.Location.HOLDING:
		var body := _resolve_body(ship.location_body_id)
		if body != null and body.landable:
			return body
	return null


## Rebuild the picker only when its context (body + location) changes; else just
## re-highlight. Cheap to call from _refresh_actions.
func _refresh_site_picker() -> void:
	if _site_picker == null:
		return
	var body := _picker_body()
	var key := "%s|%d" % ["" if body == null else body.id, GameState.ship.location]
	if key != _picker_key:
		_picker_key = key
		_rebuild_site_picker(body)
		# Default the target to Open Landing for a freshly-entered body.
		if body != null:
			_surface_target_id = ""
			_surface_target_pos = body.wild_touchdown
	_refresh_site_buttons()
	_sync_surface_map()


func _rebuild_site_picker(body: BodyData) -> void:
	for child: Node in _site_picker.get_children():
		child.queue_free()
	_site_buttons.clear()
	_site_picker.visible = body != null
	if body == null:
		return
	var caption := Label.new()
	caption.text = tr("HELM_SITE_LABEL")
	caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_site_picker.add_child(caption)
	_add_site_button("", "HELM_OPEN_LANDING")
	for loc: SurfaceLocationData in body.surface_locations:
		_add_site_button(loc.id, loc.name_key)


func _add_site_button(site_id: String, label_key: String) -> void:
	var button := TButton.new().setup(label_key, _select_site.bind(site_id))
	_site_picker.add_child(button)
	_site_buttons[site_id] = button


func _refresh_site_buttons() -> void:
	for site_id: String in _site_buttons:
		_site_buttons[site_id].modulate = Palette.ACCENT if site_id == _surface_target_id else Color.WHITE


## Surface position (su) of a site id on a body ("" = Open Landing).
func _surface_pos(body: BodyData, site_id: String) -> Vector2:
	if body == null:
		return Vector2.ZERO
	if site_id == "":
		return body.wild_touchdown
	for loc: SurfaceLocationData in body.surface_locations:
		if loc.id == site_id:
			return loc.surface_position
	return body.wild_touchdown


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
	if _in_transition():  # descent / ascent / surface move (ADR 0029/0030)
		var phase := tr("TRAVEL_DESCENDING_TO").format({
			"phase": tr(FlightCore.state_key(_flight_state)), "body": _location_name(),
		})
		return [Palette.STATUS_NOMINAL, "»", phase]
	match ship.location:
		Travel.Location.DOCKED:
			return [Palette.STATUS_INFO, "⚓", tr("TRAVEL_DOCKED_AT").format({"body": _location_name()})]
		Travel.Location.HOLDING:
			return [Palette.STATUS_INFO, "◎", tr("TRAVEL_HOLDING_AT").format({"body": _location_name()})]
		Travel.Location.LANDED:
			return [Palette.STATUS_INFO, "⏷", tr("TRAVEL_LANDED_AT").format({"body": _location_name()})]
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
	# Surface context (ADR 0030): while landed (or holding at a landable body with a
	# site picked) the Target Info describes the surface destination, not a space target.
	if GameState.ship.location == Travel.Location.LANDED:
		_ti_surface()
		_refresh_route_line()
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
	if GameState.ship.scan_contact_id == _sel_id:
		bits.append(tr("HELM_TI_SCANNING").format({"mins": GameState.ship.scan_ticks_left}))
	elif not identified and GameState.ship.position.distance_to(contact.position) <= GameState.ship.sensor_range:
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


## Target Info while landed: where we are, the picked move target + planetary ETA,
## and the body's atmosphere class (ADR 0029/0030). Surface moves cost time only.
func _ti_surface() -> void:
	var body := _resolve_body(GameState.ship.location_body_id)
	_ti_name.set_value(_site_name(body, GameState.ship.surface_site_id))
	_ti_type.set_value(_atmosphere_label(body))
	var from: Vector2 = GameState.ship.surface_position
	var to: Vector2 = _surface_target_pos
	if from.distance_to(to) >= 1.0:
		var ticks := SurfaceMath.surface_ticks(from, to, GameState.ship.surface_speed_su_per_tick)
		_ti_dist.set_value(tr("HELM_SURFACE_DIST_FORMAT").format({"su": "%.0f" % from.distance_to(to)}))
		_ti_eta.set_value(_format_eta(ticks))
		_ti_status.set_value(tr("HELM_MOVE_TO").format({"site": _site_name(body, _surface_target_id)}))
	else:
		_ti_dist.set_value("—")
		_ti_eta.set_value("—")
		_ti_status.set_value(tr("TRAVEL_LANDED"))
	_ti_rm.set_value("—")  # surface moves are time only (ADR 0029)


## Display name of a surface site ("" = Open Landing).
func _site_name(body: BodyData, site_id: String) -> String:
	if site_id == "":
		return tr("HELM_OPEN_LANDING")
	if body != null:
		for loc: SurfaceLocationData in body.surface_locations:
			if loc.id == site_id:
				return tr(loc.name_key)
	return tr("HELM_OPEN_LANDING")


## "Atmosphere: <class>" for the body, or a dash (ADR 0029).
func _atmosphere_label(body: BodyData) -> String:
	if body == null:
		return "—"
	var keys := ["ATMO_NONE", "ATMO_THIN", "ATMO_STANDARD", "ATMO_DENSE", "ATMO_CRUSHING"]
	var cls := LandingMath.atmosphere_class(body.atmosphere_atm)
	return tr("HELM_ATMOSPHERE").format({"class": tr(keys[cls])})


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
