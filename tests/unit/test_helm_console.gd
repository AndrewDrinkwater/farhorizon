extends GutTest
## Helm console wiring (ADR 0013/0014): it builds without error and turns
## compose-time selection + button presses into the right orders on EventBus
## (the system side is FlightController, tested separately). Snapshots GameState.

var _snapshot: Dictionary
var _helm: HelmConsole


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	GameState.clock.speed = 0.0
	_helm = HelmConsole.new()
	add_child_autofree(_helm)  # runs _ready -> builds panels + connects the bus


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_console_builds_without_error() -> void:
	assert_not_null(_helm, "console instantiated")
	assert_true(_helm.get_child_count() > 0, "panels were built")


func test_selecting_target_then_lay_in_issues_set_course() -> void:
	watch_signals(EventBus)
	EventBus.nav_target_selected.emit("verdant")  # map click → console selection
	_helm._lay_in_course()  # the Lay In Course button's action
	assert_signal_emitted(EventBus, "order_issued", "lay-in issues an order")
	var params: Array = get_signal_parameters(EventBus, "order_issued", 0)
	var order: Dictionary = params[0]
	assert_eq(order.get("type"), "set_course")
	assert_eq(order.get("target_id"), "verdant", "issues for the selected target")


func test_lay_in_does_nothing_without_a_target() -> void:
	watch_signals(EventBus)
	_helm._lay_in_course()
	assert_signal_not_emitted(EventBus, "order_issued", "no target -> no order")


func test_burn_selection_carries_into_the_order() -> void:
	watch_signals(EventBus)
	EventBus.nav_target_selected.emit("rubicon")
	_helm._select_burn(FlightMath.Burn.HARD)
	_helm._lay_in_course()
	var order: Dictionary = get_signal_parameters(EventBus, "order_issued", 0)[0]
	assert_eq(order.get("burn"), FlightMath.Burn.HARD, "chosen burn is composed in")


func test_acknowledgment_shows_a_transient_line() -> void:
	# An ack on the bus shows in the Flight Status transient line (ADR 0025).
	EventBus.order_acknowledged.emit(CrewVoice.SHIP_VOICE, "VOICE_SHIP_COURSE_LAID_IN")
	assert_ne(_helm._ack_line.text, "", "the ack line shows the ship voice")
	assert_almost_eq(_helm._ack_line.modulate.a, 1.0, 0.01, "shown at full opacity before fading")


func test_dragged_waypoints_compose_into_the_route_order() -> void:
	watch_signals(EventBus)
	EventBus.nav_target_selected.emit("verdant")
	# Waypoints now arrive from dragging the course line (ADR 0028).
	EventBus.nav_waypoints_set.emit(PackedVector2Array([Vector2(0.0, 500.0), Vector2(500.0, 500.0)]))
	_helm._lay_in_course()
	var order: Dictionary = get_signal_parameters(EventBus, "order_issued", 0)[0]
	assert_eq(order.get("target_id"), "verdant", "still bound for the body")
	assert_eq(order.get("waypoints").size(), 2, "dragged waypoints composed into the route")


func test_plotted_distance_includes_dragged_waypoints() -> void:
	GameState.ship.position = Vector2.ZERO
	EventBus.nav_target_selected.emit("verdant")  # verdant at (1000,0): direct ~1000 wu
	assert_almost_eq(_helm._plotted_distance(), 1000.0, 1.0, "direct route")
	EventBus.nav_waypoints_set.emit(PackedVector2Array([Vector2(0.0, 1000.0)]))  # detour
	assert_gt(_helm._plotted_distance(), 2000.0, "RM/ETA distance includes the waypoint detour")


func test_mode_toggle_drives_scale_in_orrery_view() -> void:
	watch_signals(EventBus)
	_helm._on_scale_toggled(true)
	assert_signal_emitted(EventBus, "nav_scale_changed", "orrery view → toggle drives scale")


func test_mode_toggle_drives_rings_in_tactical_view() -> void:
	EventBus.nav_view_changed.emit(true)  # switch the active view to the scope
	watch_signals(EventBus)
	_helm._on_scale_toggled(true)
	assert_signal_emitted(EventBus, "nav_ring_mode_changed", "scope view → toggle drives rings")
	assert_signal_not_emitted(EventBus, "nav_scale_changed", "and not the orrery scale")


func test_lay_in_commits_and_editing_uncommits_the_plot() -> void:
	EventBus.nav_target_selected.emit("verdant")
	assert_false(_helm._plot_laid_in, "a fresh plot is not committed")
	_helm._lay_in_course()
	assert_true(_helm._plot_laid_in, "Lay In commits it (draws solid)")
	EventBus.nav_target_selected.emit("rubicon")  # re-plot to a new target
	assert_false(_helm._plot_laid_in, "re-plotting un-commits it (back to dashed)")


func test_route_changed_carries_the_laid_in_flag() -> void:
	watch_signals(EventBus)
	EventBus.nav_target_selected.emit("verdant")
	var params: Array = get_signal_parameters(EventBus, "nav_route_changed", 0)
	assert_false(params[1], "a fresh plot broadcasts laid_in = false")


func test_land_open_landing_opens_the_map_then_descends() -> void:
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = "verdant"  # landable
	_helm._refresh_actions()  # builds the picker, default target = Open Landing
	watch_signals(EventBus)
	_helm._land()  # first press: open the surface map to pick, no descent
	assert_signal_emitted(EventBus, "surface_map_requested", "Land opens the surface map to pick a spot")
	assert_signal_not_emitted(EventBus, "order_issued", "no descent until a spot is chosen")
	EventBus.surface_point_selected.emit(Vector2(30.0, 40.0))  # pick a touchdown point
	_helm._land()  # second press: descend there
	var order: Dictionary = get_signal_parameters(EventBus, "order_issued", 0)[0]
	assert_eq(order.get("type"), "land")
	assert_eq(order.get("pos"), Vector2(30.0, 40.0), "descends to the picked point")


func test_arrival_clears_the_plot() -> void:
	EventBus.nav_target_selected.emit("verdant")
	assert_ne(_helm._sel_kind, Travel.TargetKind.NONE, "a course is plotted")
	EventBus.course_completed.emit()
	assert_eq(_helm._sel_kind, Travel.TargetKind.NONE, "plot cleared on arrival")


func test_clear_course_resets_selection_and_emits_clear() -> void:
	EventBus.nav_target_selected.emit("verdant")
	watch_signals(EventBus)
	_helm._clear_route()
	var order: Dictionary = get_signal_parameters(EventBus, "order_issued", 0)[0]
	assert_eq(order.get("type"), "clear_course", "issues a clear_course order")
	assert_eq(_helm._sel_kind, Travel.TargetKind.NONE, "selection wiped")


func test_target_info_reflects_a_selected_body() -> void:
	EventBus.nav_target_selected.emit("verdant")
	assert_eq(_helm._ti_name._value.text, tr("BODY_VERDANT"), "target info names the body")
	assert_eq(_helm._ti_type._value.text, tr("HELM_TYPE_PLANET"), "and gives its type")
	assert_ne(_helm._ti_dist._value.text, "—", "distance populated")
