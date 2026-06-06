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


func test_acknowledgment_is_logged() -> void:
	# An ack on the bus should append to the order log without error.
	EventBus.order_acknowledged.emit(CrewVoice.SHIP_VOICE, "VOICE_SHIP_COURSE_LAID_IN")
	assert_eq(_helm._order_log._box.get_child_count(), 1, "one log line recorded")
